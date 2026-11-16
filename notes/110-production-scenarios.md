# 110 · Production Scenarios: Break-Fix Practice with Solutions

> **You need first:** [109 · Cockpit and Lightspeed](109-cockpit-and-lightspeed.md) (and topic 102, the troubleshooting method)
> **Next:** [111 · Linux foundations of Kubernetes](111-linux-foundations-of-kubernetes.md)

---

## What it is

Twenty-five realistic failures. Each one has:
- a **setup** to reproduce it on a lab VM;
- the **symptom** you'd see;
- a hidden **solution** with the reasoning, the fix, the prevention, and the topic to revisit.

| # | Scenario | Core concept | Topics |
|---|---|---|---|
| 1 | Boots into emergency mode | fstab, systemd mounts | 048, 057 |
| 2 | Web page returns 403 | SELinux labels after `mv` | 073 |
| 3 | httpd won't start on a new port | SELinux port labels | 074 |
| 4 | A new group member still can't write | Session credentials, SGID | 024, 027 |
| 5 | A sudo rule has no effect | sudoers.d file naming | 028 |
| 6 | A timer never runs | daemon-reload, enabling the timer | 039 |
| 7 | Yesterday's logs are gone | Journal persistence | 038 |
| 8 | The LV is bigger but `df` isn't | Filesystem resize | 049 |
| 9 | Disk full, `du` disagrees | Deleted-but-open files | 008, 092 |
| 10 | "No space left" with free space | Inode exhaustion | 008, 047 |
| 11 | Script works by hand, not from cron | cron environment | 039 |
| 12 | Service fails with 203/EXEC | systemd exec, SELinux | 098 |
| 13 | "Too many open files" | fd leak, LimitNOFILE | 092 |
| 14 | Connections pile up in CLOSE_WAIT | Socket lifecycle | 095 |
| 15 | Service killed, exit 137 | cgroup OOM | 093, 097 |
| 16 | Slow responses, CPU mostly idle | CPU quota throttling | 097 |
| 17 | Zombie processes accumulate | wait(), reaping | 092 |
| 18 | Load average 40, CPUs idle | D state, NFS hard mount | 034, 079 |
| 19 | Every command is slow to resolve | DNS resolver timeouts | 063 |
| 20 | Port open locally, unreachable remotely | Bind address, firewall | 071, 095 |
| 21 | Client can't open new connections | Ephemeral port exhaustion | 095 |
| 22 | TLS errors on a healthy server | Clock drift, chrony | 069, 064 |
| 23 | Kernel update fails | /boot space, installonly | 054 |
| 24 | All thin volumes hang | Thin pool exhaustion | 085 |
| 25 | The inherited broken server | Seven faults at once | many |

## Why it exists

Reading about mechanisms isn't the same as recognising them under pressure. Interviews for Linux, DevOps and SRE roles very often ask "this is broken, what do you do?", and real on-call work is exactly that. Practising failures on purpose, **out loud**, using the method from topic 102, builds the reflexes.

## Analogy

Pilots train in **flight simulators**, where engines fail on purpose, so that the real emergency feels familiar. These scenarios are your simulator: a disposable VM where breaking things is the whole point.

## How it works inside

How to use each scenario:
1. **Snapshot** a lab VM (topic 100 or VirtualBox). Never run setups on machines you care about.
2. Run the **setup**. Ideally have a friend do it, so you don't know what broke.
3. Look only at the **symptom**, then follow the loop from topic 102: define → scope → what changed → evidence → hypotheses → test one thing → fix → verify (reboot) → prevent. **Talk through it**; that's interview practice.
4. Only then open the **solution** and compare your reasoning, not just the command.
5. Revert the snapshot.

## Commands

### 1. Boots into emergency mode

**Setup:** `echo 'UUID=11111111-2222-3333-4444-555555555555 /data xfs defaults 0 0' | sudo tee -a /etc/fstab ; sudo reboot`
**Symptom:** "You are in emergency mode…". With root disabled (RHEL 10's default) you see "Cannot open access to console, the root account is locked".

<details><summary>Solution</summary>

- **Diagnose:** a mount unit waits for a device that doesn't exist; `journalctl -xb` shows `Timed out waiting for device`.
- **Fix:** at GRUB press `e`, append `rd.break`, then `Ctrl+X`. Then `mount -o remount,rw /sysroot; chroot /sysroot; vi /etc/fstab` (fix the UUID from `blkid`, or comment out the line); `touch /.autorelabel; exit; exit`. If root has a password, log in at the prompt instead: `mount -o remount,rw /`, fix, `systemctl daemon-reload`, `mount -a`, reboot.
- **Prevent:** `findmnt --verify` and `mount -a` before every reboot; `nofail` (+ `x-systemd.device-timeout=10s`) for non-essential mounts.
- Topics 048, 057.
</details>

### 2. Web page returns 403

**Setup:** `sudo dnf -y install httpd; sudo systemctl enable --now httpd; echo hello > ~/index.html; sudo mv ~/index.html /var/www/html/`
**Symptom:** `curl http://localhost/` → 403 Forbidden, although the permissions look fine (`-rw-r--r--`).

<details><summary>Solution</summary>

- `ls -Z /var/www/html/index.html` → `user_home_t`: `mv` kept the source label. `ausearch -m AVC -ts recent` shows `denied { read } … httpd_t … user_home_t`.
- **Fix:** `restorecon -Rv /var/www/html` → `httpd_sys_content_t`.
- **Prevent:** `cp` rather than `mv` into service directories, or `restorecon` after deploys; custom document roots need a `semanage fcontext` rule.
- Topic 073.
</details>

### 3. httpd won't start on a new port

**Setup:** `sudo sed -i 's/^Listen 80$/Listen 8090/' /etc/httpd/conf/httpd.conf; sudo systemctl restart httpd`
**Symptom:** `Job for httpd.service failed`; the journal says `(13)Permission denied: AH00072: make_sock: could not bind to address [::]:8090`.

<details><summary>Solution</summary>

- "Permission denied" on **bind**, as root, means SELinux: `semanage port -l | grep -w 8090` shows nothing for `http_port_t`.
- **Fix:** `semanage port -a -t http_port_t -p tcp 8090; systemctl restart httpd; firewall-cmd --permanent --add-port=8090/tcp; firewall-cmd --reload`.
- **Verify:** `ss -tlnp | grep 8090` and `curl` from another host.
- Topics 074, 071.
</details>

### 4. A new group member still can't write

**Setup:** `sudo groupadd team; sudo mkdir /srv/team; sudo chgrp team /srv/team; sudo chmod 770 /srv/team; sudo usermod -aG team alice` while alice is already logged in.
**Symptom:** in her existing session, alice gets `Permission denied`; `id alice` (run by root) shows the group. Later, files bob creates there belong to group `bob`, so alice can't edit them.

<details><summary>Solution</summary>

- `id` in alice's own session doesn't list `team`: supplementary groups are fixed at login. She must log in again (or run `newgrp team`).
- Second problem: no SGID, so new files get the creator's primary group. **Fix:** `chmod 2770 /srv/team`, optionally plus a default ACL `setfacl -d -m g:team:rwX /srv/team`.
- Topics 024, 027.
</details>

### 5. A sudo rule has no effect

**Setup:** `echo '%ops ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/ops.conf` (the user is in `ops` and freshly logged in).
**Symptom:** `sudo -n true` → `sudo: a password is required`.

<details><summary>Solution</summary>

- sudo **ignores** drop-in files whose names contain a `.`.
- **Fix:** `mv /etc/sudoers.d/ops.conf /etc/sudoers.d/ops; chmod 0440 /etc/sudoers.d/ops; visudo -c`.
- Topic 028.
</details>

### 6. A timer never runs

**Setup:** create `/etc/systemd/system/report.service` (oneshot) and `report.timer` (`OnCalendar=*:0/5`), then `systemctl enable report.service`.
**Symptom:** `systemctl list-timers` doesn't show it; nothing runs.

<details><summary>Solution</summary>

- There are two mistakes:
  - No `daemon-reload` after creating the files.
  - The **service** was enabled instead of the **timer**.
- **Fix:** `systemctl daemon-reload; systemctl enable --now report.timer; systemctl list-timers report.timer`. Test the job with `systemctl start report.service` and read `journalctl -u report.service`.
- Validate schedules with `systemd-analyze calendar '*:0/5'`.
- Topic 039.
</details>

### 7. Yesterday's logs are gone

**Symptom:** `journalctl -b -1` → `Data from the specified boot is not available`.

<details><summary>Solution</summary>

- The journal is volatile (`/run/log/journal`) because `/var/log/journal` doesn't exist and `Storage=auto`.
- **Fix:** `mkdir -p /var/log/journal; systemd-tmpfiles --create --prefix /var/log/journal; systemctl restart systemd-journald` (or `Storage=persistent` in a drop-in). Verify after the next reboot with `journalctl --list-boots`.
- Topic 038.
</details>

### 8. The LV is bigger but `df` isn't

**Setup:** `sudo lvextend -L +500M /dev/vgdata/lvweb` (without `-r`).
**Symptom:** `lvs` shows the new size; `df -h /web` shows the old one.

<details><summary>Solution</summary>

- The block device grew; the filesystem didn't.
- **Fix:** XFS: `xfs_growfs /web`; ext4: `resize2fs /dev/vgdata/lvweb`. Next time, use `lvextend -r`.
- Topic 049.
</details>

### 9. Disk full, `du` disagrees

**Setup:**
```bash
sudo mkdir -p /mnt/s9 ; sudo mount -t tmpfs -o size=100M tmpfs /mnt/s9
sudo python3 -c 'import time;f=open("/mnt/s9/app.log","w");f.write("x"*60_000_000);f.flush();time.sleep(600)' &
sudo rm /mnt/s9/app.log
```
**Symptom:** `df -h /mnt/s9` → 58M used; `du -sh /mnt/s9` → 0.

<details><summary>Solution</summary>

- `lsof +L1` → `python3 2250 root 3w REG … /mnt/s9/app.log (deleted)`: the name is gone, but a process still holds the inode open.
- **Fix:** restart/stop the holder, or truncate in place: `: > /proc/2250/fd/3`.
- **Prevent:** logrotate with a post-rotate reload (or `copytruncate`); never `rm` live logs; alert when `df` and `du` diverge.
- Topics 008, 092.
</details>

### 10. "No space left on device" with free space

**Setup:** `sudo mkdir -p /mnt/s10; sudo mount -t tmpfs -o size=100M,nr_inodes=200 tmpfs /mnt/s10; for i in $(seq 300); do sudo touch /mnt/s10/f$i; done`
**Symptom:** `touch: cannot touch … No space left on device`, but `df -h` shows almost nothing used.

<details><summary>Solution</summary>

- `df -i /mnt/s10` → `IFree 0`: **inodes** are exhausted, not blocks. In real life the cause is millions of small files (sessions, caches, mail queues).
- **Fix:** find and remove them: `find /path -xdev -type f | cut -d/ -f1-4 | sort | uniq -c | sort -n | tail`. ext4's inode count is fixed at mkfs (`-N` / `-i`); XFS allocates inodes dynamically.
- Topics 008, 047.
</details>

### 11. Script works by hand, not from cron

**Setup:** crontab line `*/5 * * * * backup.sh > /tmp/backup-$(date +%F).log 2>&1`, where `backup.sh` lives in `~/bin` and calls `rsync`.
**Symptom:** no log file appears, although `/var/log/cron` shows the job starting.

<details><summary>Solution</summary>

- There are two cron traps:
  - `%` means newline in a crontab, so the command is cut off at `$(date +`.
  - cron's minimal `PATH=/usr/bin:/bin` doesn't include `~/bin`.
- **Fix:** use the full path, escape `\%` (or move the date logic into the script), set `PATH=` at the top of the crontab, and log the output. Better still: a systemd timer (logs go to the journal).
- Topic 039.
</details>

### 12. Service fails with `status=203/EXEC`

**Setup:** `ExecStart=/home/alice/app/run.sh` in a new unit; the script works when alice runs it.
**Symptom:** `Main process exited, code=exited, status=203/EXEC`.

<details><summary>Solution</summary>

- 203 = systemd couldn't execute the file. Check, in order:
  1. the executable bit;
  2. the `#!` line, including Windows line endings (`bad interpreter: /bin/bash^M`);
  3. a `noexec` mount;
  4. SELinux: `ausearch -m avc -ts recent` shows `init_t` denied `execute` on a `user_home_t` file.
- **Fix:** install under `/usr/local/bin` or `/opt` (`restorecon -Rv`), `chmod 0755`, `sed -i 's/\r$//'`.
- Topic 098.
</details>

### 13. "Too many open files"

**Setup:**
```bash
sudo tee /usr/local/bin/leaky.py >/dev/null <<'EOF'
import time
held = []
while True:
    held.append(open("/etc/hostname"))   # never closed
    time.sleep(0.05)
EOF
printf '[Service]\nExecStart=/usr/bin/python3 /usr/local/bin/leaky.py\nLimitNOFILE=64\n' | sudo tee /etc/systemd/system/leaky.service
sudo systemctl daemon-reload ; sudo systemctl start leaky
```
**Symptom:** after a few seconds the unit is `failed`; the journal shows `OSError: [Errno 24] Too many open files`.

<details><summary>Solution</summary>

- While it runs: `/proc/PID/limits` says 64, and `ls /proc/PID/fd | wc -l` climbs steadily: a **leak**, not a capacity problem.
- **Mitigate:** raise `LimitNOFILE=` via `systemctl edit` (this only buys time). **Fix:** the application must close its files. Alert on the fd count vs the limit.
- Topic 092.
</details>

### 14. Connections pile up in CLOSE_WAIT

**Setup:** a small Python server that accepts connections and never closes them; connect and disconnect clients repeatedly (`for i in $(seq 50); do curl -s -m1 localhost:9000; done`).
**Symptom:** `ss -tan state close-wait | wc -l` keeps growing; eventually the app hits its fd limit.

<details><summary>Solution</summary>

- CLOSE_WAIT means the **peer** closed and **this** application never called `close()`. Only the app can fix it.
- **Mitigate:** restart the service. **Fix:** close sockets on EOF and error paths, use timeouts, and keep connection pools healthy.
- Topic 095.
</details>

### 15. Service killed, exit 137

**Setup:** `sudo systemd-run --unit=memtest -p MemoryMax=50M -p MemorySwapMax=0 --wait python3 -c "b=bytearray(200*1024*1024)"`
**Symptom:** `Main processes terminated with: code=killed, status=9/KILL`; `Finished with result: oom-kill`.

<details><summary>Solution</summary>

- The cgroup reached `memory.max`; the host's free memory doesn't matter. `journalctl -u memtest` says "killed by the OOM killer".
- **Fix:** size the limit from the observed peak (`MemoryPeak`, `memory.peak`), or fix the memory growth; consider `MemoryHigh=` to throttle before killing. It's the same mechanism as a Kubernetes `OOMKilled` pod.
- Topics 093, 097.
</details>

### 16. Slow responses, CPU mostly idle

**Setup:** `sudo systemd-run --unit=busy -p CPUQuota=20% bash -c 'while :; do :; done'`
**Symptom:** the service is slow, yet `top` shows the host 80–90% idle.

<details><summary>Solution</summary>

- `cat /sys/fs/cgroup/system.slice/busy.service/cpu.stat` → `nr_throttled` ≈ `nr_periods`, with `throttled_usec` growing; `cpu.pressure` is non-zero.
- **Fix:** raise or remove the CPU limit (`CPUQuota=`, Kubernetes `limits.cpu`), use weights/requests for fairness instead, or make each request cheaper.
- Topic 097.
</details>

### 17. Zombie processes accumulate

**Setup:** `bash -c 'for i in 1 2 3; do sleep 1 & done; exec sleep 600' &`
**Symptom:** `ps -eo pid,ppid,stat,cmd | awk '$3 ~ /Z/'` shows `[sleep] <defunct>`; `kill -9` on them does nothing.

<details><summary>Solution</summary>

- Zombies are already dead; they wait for their parent to `wait()`. The parent (the PPID column) is `sleep 600`, which never reaps.
- **Fix:** fix or restart the parent; killing it hands the zombies to PID 1, which reaps them. In containers, run an init (`--init`) as PID 1.
- Topic 092.
</details>

### 18. Load average 40, CPUs idle (two VMs)

**Setup:** the NFS client mounts `server:/export` (default `hard`); stop `nfs-server` (or block 2049/tcp); run `ls /mnt/nfs` in several shells.
**Symptom:** commands hang, load climbs, `top` shows idle CPUs, and processes are in `D` state.

<details><summary>Solution</summary>

- `ps -eo pid,stat,wchan:32,cmd | awk '$2 ~ /D/'` shows waits in NFS RPC functions; `dmesg` says `nfs: server … not responding, still trying`. Load average counts D-state tasks.
- **Fix:** restore the server or network. For non-critical mounts, consider autofs and timeouts (with data-safety caveats for `soft`). `umount -f`/`-l` is a last resort.
- Topics 034, 079.
</details>

### 19. Everything is slow to resolve

**Setup:** `sudo nmcli con mod "$(nmcli -g NAME con show --active | head -1)" ipv4.dns "192.0.2.53 8.8.8.8" ipv4.ignore-auto-dns yes` and bring the connection up again (192.0.2.53 is an unreachable documentation address).
**Symptom:** `ssh`, `curl` and `dnf` all pause about 5 s; `curl -w` shows a large `time_namelookup`.

<details><summary>Solution</summary>

- The first resolver never answers; glibc waits `timeout` (5 s) before trying the second. `dig @192.0.2.53 example.com` times out; `dig @8.8.8.8` is instant.
- **Fix:** remove or replace the dead server; consider `options timeout:1 attempts:2`; monitor your resolvers.
- Topic 063.
</details>

### 20. Port open locally, unreachable remotely

**Symptom:** `curl http://localhost:8080` works on the server. From a client, `curl http://server:8080` gives `Connection refused` in one case and a 20-second timeout in another.

<details><summary>Solution</summary>

- `ss -tlnp | grep 8080`:
  - **`127.0.0.1:8080`**: the app listens on loopback only, so remote clients get RST ("refused"). Fix the bind address.
  - **`0.0.0.0:8080`** but clients **time out** (or see "No route to host"): check `firewall-cmd --list-all`, then routing.
- Verify with `tcpdump -nn -i any port 8080` on the server: do the SYNs arrive?
- Topics 071, 095, 096.
</details>

### 21. Client can't open new connections

**Setup (lab only):** `sudo sysctl -w net.ipv4.ip_local_port_range="40000 40009"`, then open 20 connections to the same `IP:port`.
**Symptom:** `[Errno 99] Cannot assign requested address` after 10 connections.

<details><summary>Solution</summary>

- `EADDRNOTAVAIL` = no free source port for that destination. In production, the cause is many short-lived connections sitting in TIME_WAIT (`ss -s`).
- **Fix:** reuse connections first (keep-alive, pools); then widen the range, add destination IPs, or set `tcp_tw_reuse=1`. Restore the default (`32768 60999`) afterwards.
- Topic 095.
</details>

### 22. TLS errors on a healthy server

**Setup:** `sudo systemctl stop chronyd; sudo date -s '2020-01-01'`, then `curl https://www.redhat.com`.
**Symptom:** `SSL certificate problem: certificate is not yet valid`. Kerberos/IdM logins would fail with clock-skew errors too.

<details><summary>Solution</summary>

- `timedatectl` → `System clock synchronized: no`, and the date is wrong.
- **Fix:** `systemctl enable --now chronyd; chronyc makestep; chronyc tracking`.
- **Prevent:** monitor clock offset; never run servers without time sync.
- Topics 069, 064.
</details>

### 23. Kernel update fails

**Symptom:** `dnf update kernel` → errors writing the initramfs, or `At least NMB more space needed on the /boot filesystem`.

<details><summary>Solution</summary>

- `df -h /boot; rpm -q kernel`: too many kernels or rescue images.
- **Fix:** remove old kernels, never the running one (`uname -r`): `dnf remove $(dnf repoquery --installonly --latest-limit=-2 -q)`. Then set `installonly_limit` in `/etc/dnf/dnf.conf`.
- Topic 054.
</details>

### 24. All thin volumes hang

**Setup:** an overprovisioned thin pool (topic 085's lab); write until the pool fills.
**Symptom:** writes to **every** thin LV hang or fail, while `df` still shows free space inside each filesystem.

<details><summary>Solution</summary>

- `lvs -o lv_name,data_percent,metadata_percent` → the pool's `Data%` is 100.
- **Fix:** `vgextend` with a new PV if needed, then `lvextend -L +XG VG/POOL`, and check/repair the filesystems. Enable auto-extend and alerting, and run `fstrim` regularly.
- Topic 085.
</details>

### 25. The inherited broken server (seven faults, 60 minutes)

A colleague left `server3` in a bad state. **Have a friend run these break steps** on a snapshotted VM without showing you, or run them yourself and come back the next day:

```bash
sudo -i
dnf -y install httpd chrony tuned firewalld
systemctl enable --now firewalld
# A: web server on 8085 with three independent problems
sed -i 's/^Listen 80$/Listen 8085/' /etc/httpd/conf/httpd.conf
echo mock3 > /root/index.html ; mv /root/index.html /var/www/html/index.html
systemctl enable httpd
# B: sudo for group ops (ignored file name)
groupadd ops ; useradd -G ops opsuser ; echo 'Ops@2026' | passwd --stdin opsuser
echo '%ops ALL=(ALL) ALL' > /etc/sudoers.d/ops.conf ; chmod 0440 /etc/sudoers.d/ops.conf
# C: deploy user can't log in
useradd -s /sbin/nologin deploy ; echo 'Deploy@2026' | passwd --stdin deploy ; passwd -l deploy
# D: volatile journal
mkdir -p /etc/systemd/journald.conf.d ; printf '[Journal]\nStorage=volatile\n' > /etc/systemd/journald.conf.d/50-lab.conf
rm -rf /var/log/journal
# E: time sync and tuning off
systemctl disable --now chronyd tuned
# F: reports unreadable for analysts
groupadd analysts ; useradd -G analysts ana
mkdir -p /srv/reports ; echo Q3 > /srv/reports/q3.txt
chgrp -R analysts /srv/reports ; chmod 0700 /srv/reports ; chmod 0600 /srv/reports/q3.txt
# G: boot problems and an unknown root password
echo 'UUID=00000000-1111-2222-3333-444444444444 /archive xfs defaults 0 0' >> /etc/fstab
systemctl set-default rescue.target
echo "root:$(openssl rand -base64 18)" | chpasswd
reboot
```

**Task.** Restore it so that, **after a reboot**:
1. It boots unattended into the **multi-user** target, and root's password is `Root@2026`.
2. Apache serves `/var/www/html/index.html` (content `mock3`) on **TCP 8085** to other hosts and starts at boot. SELinux stays **enforcing**.
3. Members of `ops` (e.g. `opsuser`) can run any command with sudo (password required).
4. `deploy` can log in interactively with password `Deploy@2026`.
5. The journal survives reboots.
6. Time sync is active and enabled, and the recommended tuned profile is active.
7. Members of `analysts` (e.g. `ana`) can read `/srv/reports/q3.txt`; other non-root users can't.

<details><summary>Hints</summary>

- **Getting in:** the machine stops in rescue/emergency mode and wants an unknown root password. Which boot-time method gives you a shell without one?
- **Where to look:** `systemctl --failed`, `journalctl -b -p err`, `ausearch -m avc -ts boot`, `firewall-cmd --list-all`, `visudo -c`, `getent passwd deploy`, `passwd -S deploy`, `namei -l /srv/reports/q3.txt`, `systemd-analyze cat-config systemd/journald.conf`.
</details>

<details><summary>Solution</summary>

**G: boot.** The bogus `/archive` fstab line times out, and the default target is `rescue.target`; both ask for the unknown root password.
```text
GRUB → e → append rd.break → Ctrl+X
```
```bash
mount -o remount,rw /sysroot ; chroot /sysroot
passwd root                                   # Root@2026
vi /etc/fstab                                 # delete the /archive line
systemctl set-default multi-user.target       # works in the chroot (it only relinks default.target)
touch /.autorelabel ; exit ; exit
```

**A: web server.** Three mechanisms appear one after another:
1. `systemctl status httpd` → `could not bind … 8085` (the SELinux port label is missing).
2. Then the page gives 403 (`index.html` is labelled `admin_home_t`).
3. Then remote clients time out (the firewall).
```bash
semanage port -a -t http_port_t -p tcp 8085
restorecon -v /var/www/html/index.html
firewall-cmd --permanent --add-port=8085/tcp ; firewall-cmd --reload
systemctl enable --now httpd ; curl http://localhost:8085/
```

**B: sudo.** `ops.conf` is ignored because its name contains a dot.
```bash
mv /etc/sudoers.d/ops.conf /etc/sudoers.d/ops ; visudo -c ; sudo -l -U opsuser
```

**C: deploy.** Its shell is `/sbin/nologin` and its password is locked.
```bash
usermod -s /bin/bash -U deploy ; passwd -S deploy
```

**D: journal.** A drop-in forces `Storage=volatile`, and `/var/log/journal` is gone.
```bash
rm /etc/systemd/journald.conf.d/50-lab.conf
mkdir -p /var/log/journal ; systemd-tmpfiles --create --prefix /var/log/journal
systemctl restart systemd-journald ; journalctl --flush
```

**E: time and tuning.**
```bash
systemctl enable --now chronyd tuned ; tuned-adm profile "$(tuned-adm recommend)" ; tuned-adm active
```

**F: reports.** The directory is `0700` and the file `0600`. The group needs `x` on the directory and `r` on the file.
```bash
namei -l /srv/reports/q3.txt
chmod 0750 /srv/reports ; chmod 0640 /srv/reports/q3.txt
su - ana -c 'cat /srv/reports/q3.txt' ; su - opsuser -c 'cat /srv/reports/q3.txt'   # works / Permission denied
```

**Verify:** reboot, then check each requirement: `systemctl get-default`, `curl http://server3:8085` from another host, `sudo -l -U opsuser`, `ssh deploy@server3`, `journalctl --list-boots`, `chronyc tracking`, `tuned-adm active`, and the two `cat` tests.

**Debrief questions:**
1. Why did the system ask for a root password at boot, and why didn't that help?
2. Which three mechanisms blocked the website, and in which order did they appear?
3. How would you have noticed that `ops.conf` was ignored without knowing the rule?
4. A locked password vs a `nologin` shell: which one stops SSH key logins?
5. Why does `/srv/reports` need `x` for the group when the task only says "read"?
</details>

## Where you'll use it

- **On-call:** most real incidents are variations of these 25: full disks, labels, ports, limits, OOM kills, throttling, DNS, time and certificates.
- **Interviews:** pick five scenarios and practise explaining each in 3–5 minutes without notes: symptom → evidence → reasoning → fix → prevention.
- **Kubernetes:** scenarios 13–17 and 19–21 appear almost unchanged inside pods and on nodes (topic 111).

## When it breaks

| Practice mistake | Better habit |
|---|---|
| Opening the solution after 30 seconds | Spend at least 10 minutes gathering evidence first |
| Fixing without verifying after a reboot | Always reboot-test anything meant to be persistent |
| Turning off SELinux or the firewall "to see if it helps" | Read `ausearch`/`firewall-cmd` output instead; keep protections on |
| Practising only on one VM you never revert | Snapshot, break, fix, revert, and repeat with a different scenario |

## Quick recap

- 25 scenarios cover boot, permissions, SELinux, sudo, scheduling, logs, storage, processes, memory, cgroups, networking, DNS, time, kernels and thin pools.
- Always: snapshot → break → method from topic 102 out loud → fix the cause → verify after a reboot → prevent.
- The "inherited broken server" drill combines seven faults, like a real handover.

**Interview questions**

1. *A web page returns 403 but the file permissions are fine. What do you check?* SELinux: `ls -Z` for the file's label, and `ausearch -m avc -ts recent` for denials. A file moved with `mv` keeps its old label; `restorecon` fixes it. Also check the parent directory permissions and the web server config.
2. *`df` shows a full disk, but `du` shows much less. Why?* A process still holds deleted files open. `lsof +L1` finds them; restarting the process (or truncating via `/proc/PID/fd/N`) frees the space.
3. *A service is slow but the host's CPU is mostly idle. What could it be?* CPU quota throttling in its cgroup (`cpu.stat` `nr_throttled`). Other causes are waiting on I/O, locks or a slow dependency such as DNS, which you can tell apart with PSI, `wchan`/stack and timing tools.
