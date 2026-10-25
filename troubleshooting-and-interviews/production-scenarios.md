# Break-Fix & Production Scenarios (with Solutions)

> **Track:** **[RHCSA Core]** scenarios 1–8 · **[Production Practice]** 9–20 · **[Advanced]** 21–24 · **Verified:** reproduction steps marked ✔ were executed on RHEL 10.2 containers (Oct 2026); the others need a full VM (boot, SELinux, firewalld, NFS) and follow the procedures in the linked notes.
> **How to use:** reproduce each scenario on a **disposable lab VM** (snapshot first), then solve it with the [troubleshooting method](troubleshooting-methodology.md) *before* opening the solution. Say your hypotheses out loud: that's interview practice.
> ⚠️ Setups deliberately break systems. Never run them on machines you care about.

## Index

| # | Scenario | Level | Core concept |
|---|---|---|---|
| 1 | Boots into emergency mode | RHCSA | fstab, systemd mounts |
| 2 | Web page returns 403 | RHCSA | SELinux labels after `mv` |
| 3 | httpd won't start on a new port | RHCSA | SELinux port labels |
| 4 | New group member still can't write | RHCSA | Session credentials, SGID |
| 5 | sudo rule has no effect | RHCSA | sudoers.d naming |
| 6 | Timer never runs | RHCSA | daemon-reload, enable the timer |
| 7 | Yesterday's logs are gone | RHCSA | Journal persistence |
| 8 | LV is bigger but `df` isn't | RHCSA | Filesystem resize |
| 9 | Disk full, `du` disagrees ✔ | Production | Deleted-but-open files |
| 10 | "No space left" with free space ✔ | Production | Inode exhaustion |
| 11 | Script works by hand, not from cron | Production | cron environment |
| 12 | Service fails with 203/EXEC | Production | systemd exec, SELinux |
| 13 | "Too many open files" ✔ | Production | fd leak, LimitNOFILE |
| 14 | Connections pile up in CLOSE_WAIT ✔ | Production | Socket lifecycle |
| 15 | Service killed, exit 137 ✔ | Production | cgroup OOM |
| 16 | Slow responses, CPU mostly idle ✔ | Production | CPU quota throttling |
| 17 | Zombie processes accumulate ✔ | Production | wait(), reaping |
| 18 | Load average 40, CPUs idle | Production | D state, NFS hard mount |
| 19 | Every command is slow to start / resolve | Production | DNS resolver timeouts |
| 20 | Port open locally, unreachable remotely | Production | Bind address, firewall |
| 21 | Client can't open new connections ✔ | Advanced | Ephemeral port exhaustion |
| 22 | TLS errors on a healthy server | Advanced | Clock drift, chrony |
| 23 | Kernel update fails | Advanced | /boot space, installonly |
| 24 | All thin volumes hang | Advanced | Thin pool exhaustion |

---

## 1. Boots into Emergency Mode **[RHCSA]**

**Setup:** `echo 'UUID=11111111-2222-3333-4444-555555555555 /data xfs defaults 0 0' >> /etc/fstab ; reboot`
**Symptom:** "You are in emergency mode… Cannot open access to console, the root account is locked." (RHEL 10 with root disabled) or a maintenance password prompt.
**Task:** Boot normally, without losing the other fstab entries.

<details><summary>Solution</summary>

- **Diagnose:** the unit `data.mount` (or `dev-disk-by\x2duuid-….device`) timed out; `journalctl -xb` shows `Timed out waiting for device`. With root locked you can't use the emergency shell.
- **Fix:** GRUB `e` → append `rd.break` → `mount -o remount,rw /sysroot ; chroot /sysroot ; vi /etc/fstab` (correct the UUID from `blkid`, or comment the line) → `touch /.autorelabel ; exit ; exit`. (If root has a password: log in at the prompt, `mount -o remount,rw /`, fix, `systemctl daemon-reload`, `mount -a`, reboot.)
- **Prevention:** `findmnt --verify` and `mount -a` before every reboot; `nofail` (+ `x-systemd.device-timeout=10s`) for non-essential mounts.
- Notes: [mounting & fstab](../storage-and-filesystems/mounting-and-fstab.md) · [boot recovery §5](../boot-systemd-and-kernel/boot-recovery.md#5-fix-a-broken-etcfstab)

</details>

## 2. Web Page Returns 403 **[RHCSA]**

**Setup:** `dnf -y install httpd ; systemctl enable --now httpd ; echo hello > ~/index.html ; mv ~/index.html /var/www/html/`
**Symptom:** `curl http://localhost/` → 403 Forbidden; permissions look fine (`-rw-r--r-- root root`).

<details><summary>Solution</summary>

- `ls -Z /var/www/html/index.html` → `admin_home_t` (or `user_home_t`): `mv` kept the source label. `ausearch -m AVC -ts recent` shows `denied { read } … scontext=…httpd_t tcontext=…admin_home_t`.
- **Fix:** `restorecon -Rv /var/www/html` → `httpd_sys_content_t`; curl returns 200.
- **Prevention:** `cp` (not `mv`) into service directories, or run `restorecon` after deploys; custom document roots need `semanage fcontext -a -t httpd_sys_content_t '/srv/web(/.*)?'`.
- Notes: [SELinux file contexts §5](../firewall-and-selinux/selinux-file-contexts.md#5-how-operations-affect-labels)

</details>

## 3. httpd Won't Start on a New Port **[RHCSA]**

**Setup:** `sed -i 's/^Listen 80$/Listen 8090/' /etc/httpd/conf/httpd.conf ; systemctl restart httpd`
**Symptom:** `Job for httpd.service failed`; the journal says `(13)Permission denied: AH00072: make_sock: could not bind to address [::]:8090`.

<details><summary>Solution</summary>

- "Permission denied" on **bind** as root = SELinux: `semanage port -l | grep -w 8090` shows nothing for `http_port_t`.
- **Fix:** `semanage port -a -t http_port_t -p tcp 8090 ; systemctl restart httpd ; firewall-cmd --permanent --add-port=8090/tcp ; firewall-cmd --reload`.
- **Verify:** `ss -tlnp | grep 8090` and `curl` from another host.
- Notes: [SELinux ports](../firewall-and-selinux/selinux-booleans-ports-troubleshooting.md#3-port-labels-rhcsa-core-supplemented)

</details>

## 4. New Group Member Still Can't Write **[RHCSA]**

**Setup:** `groupadd team ; mkdir /srv/team ; chgrp team /srv/team ; chmod 770 /srv/team ; usermod -aG team alice`, with alice already logged in.
**Symptom:** In her existing session, alice gets `Permission denied` creating files in `/srv/team`; `id alice` (run by root) shows the group. Later, files bob creates there are group `bob`, so alice can't edit them.

<details><summary>Solution</summary>

- `id` (no argument) in alice's session doesn't list `team`: supplementary groups are fixed at login. She must log in again (or `newgrp team`).
- Second problem: no SGID, so new files get the creator's primary group. **Fix:** `chmod 2770 /srv/team` (optionally a default ACL `setfacl -d -m g:team:rwX /srv/team`).
- Notes: [groups §3.1](../users-groups-and-permissions/groups.md#31-membership-takes-effect-at-login-rhcsa-core) · [collaboration directory](../users-groups-and-permissions/special-permissions-and-acls.md#3-shared-collaboration-directory-recipe-rhcsa-core)

</details>

## 5. sudo Rule Has No Effect **[RHCSA]**

**Setup:** `echo '%ops ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/ops.conf` (user in group ops, freshly logged in).
**Symptom:** `sudo -n true` → `sudo: a password is required`.

<details><summary>Solution</summary>

- sudo **ignores** drop-in files whose names contain a `.` (verified). `visudo -c` doesn't even list `ops.conf`.
- **Fix:** `mv /etc/sudoers.d/ops.conf /etc/sudoers.d/ops ; chmod 0440 /etc/sudoers.d/ops ; visudo -c`.
- Notes: [sudo §4.2](../users-groups-and-permissions/sudo-and-privileged-access.md#42-drop-in-files-etcsudoersd)

</details>

## 6. Timer Never Runs **[RHCSA]**

**Setup:** create `/etc/systemd/system/report.service` (oneshot) and `report.timer` (`OnCalendar=*:0/5`), then `systemctl enable report.service`.
**Symptom:** `systemctl list-timers` doesn't show it; nothing runs.

<details><summary>Solution</summary>

- Two mistakes: no `systemctl daemon-reload` after creating files, and the **service** was enabled instead of the **timer** (and a oneshot service without `[Install]` can't really be enabled).
- **Fix:** `systemctl daemon-reload ; systemctl enable --now report.timer ; systemctl list-timers report.timer`; test the job with `systemctl start report.service` and read `journalctl -u report.service`.
- Validate schedules with `systemd-analyze calendar '*:0/5'`.
- Notes: [job scheduling §6](../logs-scheduling-and-packages/job-scheduling.md#6-systemd-timers-supplemented-rhcsa-core)

</details>

## 7. Yesterday's Logs Are Gone **[RHCSA]**

**Symptom:** `journalctl -b -1` → `Specified boot ID … not found` / `Data from the specified boot is not available`.

<details><summary>Solution</summary>

- The journal is volatile (`/run/log/journal`) because `/var/log/journal` doesn't exist and `Storage=auto`.
- **Fix:** `mkdir -p /var/log/journal ; systemd-tmpfiles --create --prefix /var/log/journal ; systemctl restart systemd-journald` (or `Storage=persistent` in a `journald.conf.d` drop-in). Verify after the next reboot with `journalctl --list-boots`.
- Notes: [system logging §4](../logs-scheduling-and-packages/system-logging.md#4-persistent-journal-rhcsa-core)

</details>

## 8. LV Is Bigger but `df` Isn't **[RHCSA]**

**Setup:** `lvextend -L +500M /dev/vgdata/lvweb` (without `-r`).
**Symptom:** `lvs` shows the new size; `df -h /web` the old one.

<details><summary>Solution</summary>

- The block device grew; the filesystem didn't. **Fix:** XFS: `xfs_growfs /web` (mount point); ext4: `resize2fs /dev/vgdata/lvweb`. Next time: `lvextend -r`.
- Notes: [LVM §5](../storage-and-filesystems/lvm-fundamentals.md#5-extending-online-rhcsa-core)

</details>

## 9. Disk Full, `du` Disagrees ✔ **[Production]**

**Setup (verified on tmpfs):**

```bash
mount -t tmpfs -o size=100M tmpfs /mnt/s9
python3 -c 'import time;f=open("/mnt/s9/app.log","w");f.write("x"*60_000_000);f.flush();time.sleep(600)' &
rm /mnt/s9/app.log
```

**Symptom:** `df -h /mnt/s9` → 58M used; `du -sh /mnt/s9` → 0.

<details><summary>Solution</summary>

- `lsof +L1` → `python3 2250 root 3w REG … 60000000 … /mnt/s9/app.log (deleted)`: the name is gone but the process still holds the inode open.
- **Fix:** restart/stop the holder (verified: space freed immediately after killing it), or truncate it in place: `: > /proc/2250/fd/3`.
- **Prevention:** logrotate with `copytruncate` or a post-rotate reload; never `rm` live logs; alert on `df` vs `du` divergence.
- Notes: [processes & syscalls §6.1](../processes-and-resource-management/processes-and-system-calls.md#61-three-layers)

</details>

## 10. "No space left on device" with Free Space ✔ **[Production]**

**Setup (verified):** `mount -t tmpfs -o size=100M,nr_inodes=200 tmpfs /mnt/s10 ; for i in $(seq 300); do touch /mnt/s10/f$i; done`
**Symptom:** `touch: cannot touch '/mnt/s10/x': No space left on device`, but `df -h` shows 0% used.

<details><summary>Solution</summary>

- `df -i /mnt/s10` → `IUsed 200 IFree 0 100%`: inodes, not blocks, are exhausted (millions of small files: sessions, caches, mail queues).
- **Fix:** find and remove the small files (`find /path -xdev -type f | cut -d/ -f1-4 | sort | uniq -c | sort -n | tail`); for ext4 the inode count is fixed at mkfs (`mkfs.ext4 -N` / `-i`); XFS allocates inodes dynamically (`imaxpct`).
- Notes: [links & inodes](../users-groups-and-permissions/links.md#2-inodes) · [FHS troubleshooting](../linux-fundamentals/filesystem-hierarchy.md#7-troubleshooting-production-practice)

</details>

## 11. Script Works by Hand, Not from cron **[Production]**

**Setup:** crontab line `*/5 * * * * backup.sh > /tmp/backup-$(date +%F).log 2>&1`, where `backup.sh` lives in `~/bin` and calls `rsync`.
**Symptom:** No log file appears; `/var/log/cron` shows the job starting.

<details><summary>Solution</summary>

- Two cron traps: `%` is a newline in crontab, so the command is cut at `$(date +`; and cron's minimal environment (`PATH=/usr/bin:/bin`) doesn't include `~/bin`.
- **Fix:** use the full path `/home/alice/bin/backup.sh`, escape `\%`, or better move the logic into the script; set `PATH=` at the top of the crontab; capture output to a log. Better still: a systemd timer (logs in the journal).
- Notes: [job scheduling §3.4](../logs-scheduling-and-packages/job-scheduling.md#34-rules-that-cause-most-cron-bugs)

</details>

## 12. Service Fails with `status=203/EXEC` **[Production]**

**Setup:** `ExecStart=/home/alice/app/run.sh` in a new unit; the script works when alice runs it.
**Symptom:** `Main process exited, code=exited, status=203/EXEC`.

<details><summary>Solution</summary>

- 203 = systemd couldn't `execve()` the file. Check, in order: executable bit, the `#!` line (and CRLF endings: `bad interpreter: /bin/bash^M`), `noexec` mount, and SELinux: `ausearch -m avc -ts recent` typically shows `init_t` denied `execute` on a `user_home_t` file.
- **Fix:** install the program under `/usr/local/bin` or `/opt` (correctly labeled; `restorecon -Rv`), `chmod 0755`, fix line endings (`sed -i 's/\r$//'`).
- Notes: [systemd unit files §15](../boot-systemd-and-kernel/systemd-unit-files.md#15-troubleshooting)

</details>

## 13. "Too many open files" ✔ **[Production]**

**Setup (verified):**

```bash
cat > /usr/local/bin/leaky.py <<'EOF'
import time
held = []
while True:
    held.append(open("/etc/hostname"))   # never closed
    time.sleep(0.05)
EOF
printf '[Service]\nExecStart=/usr/bin/python3 /usr/local/bin/leaky.py\nLimitNOFILE=64\n' > /etc/systemd/system/leaky.service
systemctl daemon-reload ; systemctl start leaky
```

**Symptom:** after a few seconds the unit is `failed`; the journal shows `OSError: [Errno 24] Too many open files: '/etc/hostname'`.

<details><summary>Solution</summary>

- While it runs: `cat /proc/$(systemctl show -p MainPID --value leaky)/limits | grep 'open files'` (64) and `ls /proc/PID/fd | wc -l` climbing steadily: a **leak**, not a capacity problem.
- **Mitigation:** raise `LimitNOFILE=` via `systemctl edit` (buys time). **Fix:** the application must close files/sockets. Alert on fd count vs limit.
- Notes: [processes & syscalls §6.3](../processes-and-resource-management/processes-and-system-calls.md#63-limits-too-many-open-files-emfileenfile)

</details>

## 14. Connections Pile Up in CLOSE_WAIT ✔ **[Production]**

**Setup:** the Python server from [TCP/IP §4](../networking-and-ssh/tcp-ip-for-operators.md#4-tcp-connection-lifecycle) that accepts and never closes; connect and disconnect clients repeatedly.
**Symptom:** `ss -tan state close-wait | wc -l` grows; eventually the app hits its fd limit.

<details><summary>Solution</summary>

- CLOSE_WAIT means the **peer** closed and **this** application never called `close()`. The kernel can't fix it; only the app can.
- **Mitigation:** restart the service; **fix:** close sockets on EOF/error paths, use timeouts, connection-pool hygiene.
- Notes: [TCP/IP §4](../networking-and-ssh/tcp-ip-for-operators.md#4-tcp-connection-lifecycle)

</details>

## 15. Service Killed, Exit 137 ✔ **[Production]**

**Setup (verified):** `systemd-run --unit=memtest -p MemoryMax=50M -p MemorySwapMax=0 --wait python3 -c "b=bytearray(200*1024*1024)"`
**Symptom:** `Main processes terminated with: code=killed, status=9/KILL`; `Failed with result 'oom-kill'`.

<details><summary>Solution</summary>

- `journalctl -u memtest` → `A process of this unit has been killed by the OOM killer.` The cgroup reached `memory.max`; host free memory doesn't matter.
- **Fix:** right-size the limit from observed `MemoryPeak`/`memory.current`, or fix the memory growth; consider `MemoryHigh=` to throttle before killing. Same mechanism as a Kubernetes `OOMKilled` pod.
- Notes: [memory §8](../processes-and-resource-management/memory-management.md#8-the-oom-killer) · [cgroups §3.2](../containers-and-virtualization/namespaces-and-cgroups.md#32-memory-limit-by-hand-verified)

</details>

## 16. Slow Responses, CPU Mostly Idle ✔ **[Production]**

**Setup:** `systemd-run --unit=busy -p CPUQuota=20% bash -c 'while :; do :; done'` (or the manual `cpu.max` demo).
**Symptom:** the service is slow; `top` shows the host 80–90% idle.

<details><summary>Solution</summary>

- `cat /sys/fs/cgroup/system.slice/busy.service/cpu.stat` → `nr_throttled` ≈ `nr_periods`, `throttled_usec` growing (verified: 31/31 periods throttled, 2.4 s throttled in 3 s). `cpu.pressure` is non-zero.
- **Fix:** raise or remove the CPU limit (`CPUQuota=`, Kubernetes `limits.cpu`), use `CPUWeight=`/requests for fairness instead, or reduce per-request CPU.
- Notes: [cgroups §3.3](../containers-and-virtualization/namespaces-and-cgroups.md#33-cpu-quota-and-throttling-verified)

</details>

## 17. Zombie Processes Accumulate ✔ **[Production]**

**Setup (verified):** `bash -c 'for i in 1 2 3; do sleep 1 & done; exec sleep 600' &`
**Symptom:** `ps -eo pid,ppid,stat,cmd | awk '$3 ~ /Z/'` shows `[sleep] <defunct>` entries; `kill -9` on them does nothing.

<details><summary>Solution</summary>

- Zombies are dead; they wait for their parent to `wait()`. The parent (PPID column) is `sleep 600`, which never reaps.
- **Fix:** fix/restart the parent; killing it hands the zombies to PID 1, which reaps them. In containers, run an init (`--init`) as PID 1.
- Notes: [processes & syscalls §4.3](../processes-and-resource-management/processes-and-system-calls.md#43-exit-zombies-wait-and-orphans)

</details>

## 18. Load Average 40, CPUs Idle **[Production]** (2 VMs)

**Setup:** NFS client mounts `server:/export` (default `hard`); stop `nfs-server` on the server (or block 2049/tcp); run `ls /mnt/nfs` in several shells.
**Symptom:** commands hang, `uptime` load climbs, `top` shows idle CPUs and high `wa`, processes in `D` state.

<details><summary>Solution</summary>

- `ps -eo pid,stat,wchan:32,cmd | awk '$2 ~ /D/'` → waits in NFS RPC functions; `cat /proc/PID/stack` confirms; `dmesg` shows `nfs: server … not responding, still trying`. Load counts D-state tasks.
- **Fix:** restore the server/network; for non-critical mounts consider autofs and `soft`/timeouts (with data-safety caveats); `umount -f`/`-l` as a last resort.
- Notes: [top §2](../processes-and-resource-management/top-and-process-monitoring.md#2-the-summary-area) · [NFS & autofs](../system-services-and-shared-storage/nfs-and-autofs.md)

</details>

## 19. Everything Is Slow to Resolve **[Production]**

**Setup:** `nmcli con mod ens160 ipv4.dns "192.0.2.53 8.8.8.8" ipv4.ignore-auto-dns yes ; nmcli con up ens160` (192.0.2.53 is an unreachable documentation address).
**Symptom:** `ssh`, `curl`, `dnf` all pause ~5 s before working; `curl -w` shows a large `time_namelookup`.

<details><summary>Solution</summary>

- The first resolver doesn't answer; glibc waits `timeout` (5 s default) before trying the second. `dig @192.0.2.53 example.com` times out; `dig @8.8.8.8` is instant.
- **Fix:** remove/replace the dead server in the profile; consider `options timeout:1 attempts:2` and redundant resolvers you monitor.
- Notes: [TCP/IP §13](../networking-and-ssh/tcp-ip-for-operators.md#13-dns-troubleshooting)

</details>

## 20. Port Open Locally, Unreachable Remotely **[Production]**

**Symptom:** `curl http://localhost:8080` works on the server; from a client, `curl http://server:8080` → `Connection refused` in one case, a 20 s timeout in another.

<details><summary>Solution</summary>

- `ss -tlnp | grep 8080`: `127.0.0.1:8080` means the app listens only on loopback → remote clients get **RST/refused** (fix the bind address). If it's `0.0.0.0:8080` and the client **times out** or gets `No route to host`, check `firewall-cmd --list-all` (firewalld rejects with ICMP or drops), then routing.
- Verify on the server with `tcpdump -nn -i any port 8080` whether SYNs arrive.
- Notes: [TCP/IP §7, §16](../networking-and-ssh/tcp-ip-for-operators.md#16-troubleshooting-flow-service-x-is-unreachable)

</details>

## 21. Client Can't Open New Connections ✔ **[Advanced]**

**Setup (verified, lab only):** `sysctl -w net.ipv4.ip_local_port_range="40000 40009"`, then open 20 connections to the same `IP:port`.
**Symptom:** `[Errno 99] Cannot assign requested address` after 10 connections.

<details><summary>Solution</summary>

- `EADDRNOTAVAIL` = no free source port for that destination 4-tuple. In production this happens with many short-lived connections in TIME_WAIT (`ss -s`, `ss -tan state time-wait | wc -l`).
- **Fix:** connection reuse (keep-alive/pools) first; then widen `ip_local_port_range`, add destination IPs, consider `tcp_tw_reuse=1` for outgoing connections. Restore the default range afterwards (`32768 60999`).
- Notes: [TCP/IP §6](../networking-and-ssh/tcp-ip-for-operators.md#6-ports-and-ephemeral-port-exhaustion)

</details>

## 22. TLS Errors on a Healthy Server **[Advanced]**

**Setup:** `systemctl stop chronyd ; date -s '2020-01-01'`, then `curl https://www.redhat.com`.
**Symptom:** `SSL certificate problem: certificate is not yet valid`; Kerberos logins would fail with clock skew errors.

<details><summary>Solution</summary>

- `timedatectl` → `System clock synchronized: no`; the date is wrong. **Fix:** `systemctl enable --now chronyd ; chronyc makestep ; chronyc tracking`.
- **Prevention:** monitor clock offset; never run without time sync on servers.
- Notes: [chrony](../system-services-and-shared-storage/chrony-time-sync.md) · [TCP/IP §14](../networking-and-ssh/tcp-ip-for-operators.md#14-tls-troubleshooting)

</details>

## 23. Kernel Update Fails **[Advanced]**

**Symptom:** `dnf update kernel` → errors writing the initramfs or `At least NMB more space needed on the /boot filesystem`.

<details><summary>Solution</summary>

- `df -h /boot ; rpm -q kernel`: too many kernels or rescue images. **Fix:** remove old kernels (never the running one: `uname -r`) with `dnf remove kernel-core-VERSION` or `dnf remove $(dnf repoquery --installonly --latest-limit=-2 -q)`; set `installonly_limit` in `/etc/dnf/dnf.conf`.
- Notes: [GRUB2 & kernels §6](../boot-systemd-and-kernel/grub2-and-kernel-management.md#6-kernel-packages-rhcsa-core-installingupdating)

</details>

## 24. All Thin Volumes Hang **[Advanced]**

**Setup:** overprovisioned thin pool (lab from [thin provisioning](../storage-and-filesystems/lvm-thin-provisioning-and-striping.md)), then write until the pool fills.
**Symptom:** writes to **every** thin LV hang or fail; `df` still shows free space inside each filesystem.

<details><summary>Solution</summary>

- `lvs -o lv_name,data_percent,metadata_percent` → pool `Data%` 100. **Fix:** `vgextend` with a new PV if needed, then `lvextend -L +XG VG/POOL`; check/repair affected filesystems; enable auto-extend and alerting; run `fstrim` regularly.
- Notes: [thin provisioning §2.6](../storage-and-filesystems/lvm-thin-provisioning-and-striping.md#26-when-the-pool-fills-up)

</details>

## Cross-References

- [Troubleshooting methodology](troubleshooting-methodology.md) · [Interview question bank](interview-question-bank.md)
- [Mock exam 3 (RHCSA break-fix)](../rhcsa-exam-labs/mock-exam-3.md) · [Performance & observability](../advanced-rhel-and-career-notes/performance-and-observability.md)
