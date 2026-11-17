# 102 · A Troubleshooting Method

> **You need first:** [101 · Containers with Podman (and Docker)](101-containers-podman-and-docker.md) (this topic ties together everything before it)
> **Next:** [103 · Performance and observability](103-performance-and-observability.md)

---

## What it is

A repeatable **way of thinking** for fixing broken systems: define the problem, find the failing layer, gather evidence before changing anything, test one hypothesis at a time, fix the cause, verify, and prevent it from happening again.

Words:
- **Incident**: an unplanned interruption or degradation of a service.
- **Mitigation**: reducing user impact quickly (roll back, fail over, add capacity) **before** the root cause is known.
- **Root cause**: the underlying reason; fixing it stops the problem coming back.
- **Postmortem**: a written review after an incident: timeline, causes, and actions. "**Blameless**" means it focuses on systems, not on who made the mistake.
- **SRE** (Site Reliability Engineering): running production with engineering methods: measurement, automation, error budgets, postmortems.

## Why it exists

Under pressure, people grab the first familiar fix: restart the service, reboot, `chmod 777`, `setenforce 0`. Sometimes the symptom goes away, but **the cause stays and the evidence is destroyed**. Interviewers for SRE/DevOps roles grade **how you reason** far more than whether you remember an exact flag. A method keeps you both fast and right.

## Analogy

A good troubleshooter works like a **doctor**:
1. Ask what hurts and since when (define, timeline).
2. Take the vital signs **before** giving any medicine (evidence first).
3. Think of the likely diagnoses (hypotheses).
4. Order the test that best separates them (one test at a time).
5. Treat the disease, not just the fever (root cause).
6. Check the patient is really better (verify).
7. Advise on how not to get ill again (prevent).

If the patient is bleeding, the doctor **stops the bleeding first** (mitigate), then diagnoses.

## How it works inside

### The loop

```
 1. Define       What exactly is broken, for whom, since when? What does "working" look like?
 2. Scope        One host or many? One service or all? All users or some? Always or intermittent?
 3. Timeline     When did it start? What changed just before? (deploy, dnf history, config, reboot, traffic, cert expiry)
 4. Evidence     Logs, metrics, error messages, exit codes. Capture them BEFORE changing anything
 5. Hypothesise  2–3 candidate causes, ordered by likelihood × ease of testing
 6. Test         One change or observation at a time; predict the result first
 7. Fix          The cause, not the symptom (or mitigate first, and say that's what you're doing)
 8. Verify       From the user's point of view; after a reboot when persistence matters
 9. Prevent      Monitoring/alert, config management, runbook, test. Write it down
```

Two rules:
- **Mitigate before you investigate** when users are impacted.
- **Don't destroy evidence**: copy logs, note PIDs and states, take a `sos report` before restarting or rebooting.

### Find the failing layer

Test from the bottom up (or inside out); each check takes seconds:

| Layer | Fast test | Topics |
|---|---|---|
| Hardware / virtual hardware | `dmesg -T \| tail`, `journalctl -k -p err` | 038, 094 |
| Kernel resources | `vmstat 1`, `cat /proc/pressure/*` (RHEL: boot with `psi=1` first), `free -h`, `df -h`, `df -i` | 034, 036, 093 |
| Storage | `lsblk`, `findmnt`, `iostat -xz 1` | 046–052, 094 |
| Network | `ip -br a`, `ip route get X`, `ping`, `ss -tlnp` | 058–063, 095 |
| Security | `firewall-cmd --list-all`, `ausearch -m avc -ts recent`, `ls -lZ`, `namei -l PATH` | 026–027, 071–074 |
| Service manager | `systemctl status X`, `journalctl -u X -b`, `systemctl --failed` | 037, 098 |
| Application | App logs, config tests (`sshd -t`, `nginx -t`, `apachectl configtest`), `strace -f` | 078, 092 |
| Name resolution | `getent hosts NAME`, `dig NAME` | 063 |
| Client side | `curl -v`, the user's exact command | 070 |

### Read the error message literally

| Message | Means | Topics |
|---|---|---|
| `Permission denied` | Permissions/ACL, SELinux, missing capability, `noexec` mount, immutable attribute | 026, 027, 072, 092 |
| `No such file or directory` | Wrong path, missing `#!` interpreter or library, wrong namespace | 092 |
| `No space left on device` | Blocks **or** inodes, deleted-but-open files, thin pool, quota | 006, 089, 085 |
| `Read-only file system` | Mounted `ro`, remounted after errors, `ProtectSystem=` | 094, 098 |
| `Connection refused` / timeout / `No route to host` | RST / drop / ICMP or ARP failure | 095 |
| `Too many open files` | Per-process fd limit, or a leak | 092 |
| `Killed` / exit 137 | SIGKILL: OOM (global or cgroup) or a supervisor | 093, 097 |
| `status=203/EXEC` | systemd couldn't execute ExecStart | 098 |
| `Address already in use` | Another process holds the port | `ss -tlnp 'sport = :PORT'` |
| `Name or service not known` | DNS, nsswitch or search domains | 063 |

### Decision trees

**"The system doesn't boot"** (topics 053–057):
```
No boot device / firmware      → boot order, ESP, efibootmgr
grub> or grub rescue>          → GRUB config/ESP broken → rescue media → reinstall shim/grub2-efi, grub2-mkconfig
Kernel panic "unable to mount root" / dracut timeout → older kernel → dracut -f --kver; check root=, rd.lvm.lv=
Emergency mode ("Give root password for maintenance") → journalctl -xb → fstab (findmnt --verify), failed mounts, LUKS
Reboot loop                    → boot with systemd.unit=multi-user.target → check systemctl get-default
Boots but can't log in         → rd.break → password, /.autorelabel, shell in /etc/passwd, nologin, PAM, sudoers
```

**"The service doesn't work":**
```
systemctl status → not running? → journalctl -u SVC -b → config error? 203/EXEC? port bind (SELinux port label / in use)?
running → listening on the right address and port? (ss -tlnp) → does a local curl work?
  no  → app/config, SELinux (ausearch -m avc), file permissions or labels on content
  yes → firewall (firewall-cmd --list-all), client route/DNS, TLS
works now → enabled? (is-enabled) still works after a reboot?
```

**"The server is slow"** → the USE method and the first 60 seconds (topic 103).

### Communicating during an incident

- State **impact** first ("checkout API: 50% errors since 14:02"), then what you know, what you're trying, and when you'll update next.
- Keep a timestamped log of actions; it becomes the postmortem timeline.
- Afterwards, write a blameless postmortem: root cause, contributing factors, why detection was late, and action items (monitoring, tests, automation).

## Commands

### Collect evidence before changing anything

```bash
sudo -i                                    # a root shell: redirections below write as root
D=/root/incident-$(date +%F_%H%M) ; mkdir -p $D
journalctl -b --since "-1h" > $D/journal.txt
top -b -n 1 > $D/top.txt
ps -eo pid,ppid,user,stat,%cpu,%mem,wchan:20,cmd > $D/ps.txt
ss -tanp > $D/ss.txt ; df -h > $D/df.txt ; df -i >> $D/df.txt
dmesg -T > $D/dmesg.txt
exit
```
- Run it as root. With `sudo CMD > /root/...`, the **redirection is done by your own shell**, not by sudo, so it fails with `Permission denied` (topic 028).

### What changed?

```bash
sudo dnf history | head -5
sudo rpm -Va 2>/dev/null | grep -v '^.......T' | head      # checks every file: takes minutes
last -x | head ; journalctl --list-boots | tail -3
find /etc -newermt '-2 hours' -type f 2>/dev/null
```
```
ID     | Command line              | Date and time    | Action(s)      | Altered
--------------------------------------------------------------------------------
    42 | update openssl            | 2026-11-17 13:55 | Upgrade        |    3
S.5....T.  c /etc/ssh/sshd_config
/etc/nginx/conf.d/app.conf
```
- An OpenSSL upgrade five minutes before the incident, and `rpm -Va` shows `sshd_config` was modified (`S` size, `5` checksum). `find` shows a recently edited nginx config. These are your prime suspects.

### Support bundle

```bash
sudo dnf install -y sos ; sudo sos report --batch
```
```
Your sos report has been generated and saved in:
	/var/tmp/sosreport-server1-2026-11-17-abcdefg.tar.xz
```
- This collects logs, configs and command output in one archive for Red Hat support or your own analysis.

### Try it
Break things on a lab VM (or have a friend do it) and fix them **out loud**, following the loop:
1. Put a typo in `/etc/fstab` and reboot.
2. Move a web page out of `/var/www/html` with `mv` from your home directory (it keeps the wrong SELinux label).
3. Set nginx to listen on port 8081 without updating the SELinux port label.
4. Fill `/var` with one big file held open by a process, then delete the file.
5. Remove the default route.

For each, write: the symptom, the evidence, the hypothesis, the test, the fix, the verification, and the prevention.

## Where you'll use it

- **On-call and incident response** in any production team.
- **Interviews:** "walk me through how you'd debug…" questions are graded on structure. Say the loop out loud.
- **Kubernetes:** the same layers apply. Pod → container → node (kubelet, runtime) → network (CNI, Services, DNS) → storage (CSI). `kubectl describe` and events are your `systemctl status` and journal (topic 111).

## When it breaks

| Anti-pattern | Why it hurts | Instead |
|---|---|---|
| Restart or reboot first | Destroys evidence; the problem returns | Capture state, then mitigate |
| `setenforce 0`, `chmod 777`, `firewall-cmd --panic-off` "to test" and then forget | Leaves a security hole | Test with logs (`ausearch`) and narrow fixes; revert test changes |
| Changing several things at once | You don't know which one fixed it | One change at a time; predict the result first |
| Only testing from your own machine | Misses scope (DNS, network path, other users) | Reproduce like the user, from where they are |
| "It works now" without verifying persistence | Breaks again at the next reboot | Check `is-enabled`, fstab, `--permanent`, then reboot-test |
| No write-up | The same incident happens again | A short postmortem with action items |

## Quick recap

- Define → scope → timeline (**what changed?**) → evidence (**before** changes) → hypotheses → test one thing → fix the cause → verify (reboot) → prevent.
- Find the layer: hardware → kernel resources → storage → network → security → systemd → app → DNS → client.
- Read error messages literally; each maps to a mechanism.
- Mitigate before investigating when users hurt; don't destroy evidence (`sos report`). Write blameless postmortems.

**Interview questions**

1. *A website is down. What do you do first?* Confirm and scope it (what fails, for whom, since when), check what changed recently, and gather evidence such as service status, logs and listening ports. If users are impacted, mitigate first (roll back or fail over), then find the root cause layer by layer.
2. *Why not just reboot the server?* It may hide the symptom temporarily but destroys evidence (process state, memory, logs in volatile storage), and the root cause remains, so the problem returns.
3. *What makes a good postmortem?* A factual timeline, the root cause and contributing factors, why it wasn't detected sooner, and concrete owned action items. It's blameless, focusing on systems and processes rather than individuals.
