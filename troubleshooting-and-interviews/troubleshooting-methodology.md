# Troubleshooting Methodology

> **Track:** **[Production Practice]** · **[Interview Knowledge]** · applies to RHCSA break-fix tasks and to production incidents
> **Prerequisites:** Phases 1–4 of the [curriculum](../CURRICULUM.md) (you need the mechanisms before a method helps)
> **Next:** [Production scenarios](production-scenarios.md) · [Interview question bank](interview-question-bank.md) · [Performance & observability](../advanced-rhel-and-career-notes/performance-and-observability.md)

## 1. Why a Method

Under pressure, people jump to the first familiar fix: restart the service, reboot, `chmod 777`, `setenforce 0`. Sometimes the symptom goes away; the cause stays, and evidence is destroyed. Interviewers for SRE roles grade **how** you reason far more than whether you know the exact command. A method keeps you fast **and** right.

## 2. The Loop

```
 1. Define     What exactly is broken, for whom, since when? What does "working" look like?
 2. Scope      One host or many? One service or all? All users or some? Always or intermittently?
 3. Timeline   When did it start? What changed just before? (deploy, dnf history, config, reboot, traffic, certificate expiry)
 4. Evidence   Logs, metrics, error messages, exit codes. Capture them BEFORE you change anything
 5. Hypothesize  List 2–3 candidate causes, ordered by likelihood × ease of testing
 6. Test       One change or one observation at a time; predict the outcome first
 7. Fix        The cause, not the symptom (or mitigate first, then fix, and say which you're doing)
 8. Verify     From the user's perspective; after a reboot when persistence matters
 9. Prevent    Monitoring/alert, config management, runbook, test; write it down
```

Two rules: **mitigate before you investigate** when users are impacted (fail over, roll back, add capacity), and **don't destroy evidence** (copy logs, `sos report`, note PIDs before killing).

## 3. Locate the Failing Layer

Most problems can be pinned to one layer quickly by testing **from the inside out** (or bottom up):

| Layer | Fast test | Notes |
|---|---|---|
| Hardware / virtual hardware | `dmesg -T \| tail`, `journalctl -k -p err` | Disks, NICs, memory errors, OOM |
| Kernel resources | `vmstat 1`, PSI, `df -h`, `df -i`, `free -h` | Saturation and exhaustion |
| Storage stack | `lsblk`, `findmnt`, `iostat -xz 1` | Mounts, read-only, latency |
| Network | `ip -br a`, `ip route get X`, `ping`, `ss -tlnp` | Address, route, listener |
| Security | `firewall-cmd --list-all`, `ausearch -m avc -ts recent`, `ls -lZ`, `namei -l` | Firewall, SELinux, permissions |
| Service manager | `systemctl status X`, `journalctl -u X -b`, `systemctl --failed` | Unit state and its logs |
| Application | App logs, config check (`sshd -t`, `apachectl configtest`), `strace -f` | Config, dependencies |
| Name resolution | `getent hosts`, `dig` | DNS vs `/etc/hosts` |
| Client side | `curl -v`, the user's exact command | Reproduce like the user |

## 4. Read the Error Message Literally

| Message | Translation | Go to |
|---|---|---|
| `Permission denied` | DAC (rwx/ACL), SELinux, capabilities, `noexec`, immutable attribute | [File permissions §4](../users-groups-and-permissions/file-permissions.md#4-diagnosing-permission-problems-rhcsa-core) |
| `No such file or directory` | Path, missing interpreter/library, wrong namespace/chroot | [Processes §10](../processes-and-resource-management/processes-and-system-calls.md#10-troubleshooting) |
| `No space left on device` | Blocks **or** inodes, deleted-but-open files, thin pool/quota | [FHS §7](../linux-fundamentals/filesystem-hierarchy.md#7-troubleshooting-production-practice) |
| `Read-only file system` | Mounted `ro`, remounted after errors, `ProtectSystem=` sandbox | [Storage I/O §9](../storage-and-filesystems/storage-io-path.md#9-failure-modes) |
| `Connection refused` / timeout / `No route to host` | RST / drop / ICMP or ARP failure | [TCP/IP §7](../networking-and-ssh/tcp-ip-for-operators.md#7-failure-signatures-refused-vs-timeout-vs-unreachable) |
| `Too many open files` | Per-process fd limit or leak | [Processes §6.3](../processes-and-resource-management/processes-and-system-calls.md#63-limits-too-many-open-files-emfileenfile) |
| `Killed` / exit 137 | SIGKILL: OOM (global or cgroup) or a supervisor | [Memory §8](../processes-and-resource-management/memory-management.md#8-the-oom-killer) |
| `status=203/EXEC` | systemd couldn't exec ExecStart | [systemd unit files §12](../boot-systemd-and-kernel/systemd-unit-files.md#12-reading-systemctl-status) |
| `Address already in use` | Another process holds the port (or TIME_WAIT without SO_REUSEADDR) | `ss -tlnp 'sport = :PORT'` |
| `Name or service not known` | DNS / nsswitch / search domains | [TCP/IP §13](../networking-and-ssh/tcp-ip-for-operators.md#13-dns-troubleshooting) |

## 5. Decision Trees for Common Situations

### 5.1 "The system doesn't boot"

```
Firmware/no boot device → boot order, ESP, efibootmgr
grub> / grub rescue> → GRUB config/ESP broken → rescue media → reinstall grub2-efi/shim, grub2-mkconfig
Kernel panic "VFS: unable to mount root" / dracut timeout → older/rescue kernel → dracut -f --kver; check root=, rd.lvm.lv=
"Give root password for maintenance" / emergency mode → journalctl -xb → fstab (findmnt --verify), failed mounts, LUKS
Reboot loop → systemd.unit=multi-user.target → systemctl get-default
Boots but can't log in → rd.break → password, /.autorelabel, shell in /etc/passwd, pam/nologin, sudoers
```

Details: [boot process](../boot-systemd-and-kernel/boot-process.md#7-troubleshooting-by-stage) · [boot recovery](../boot-systemd-and-kernel/boot-recovery.md).

### 5.2 "The service doesn't work"

```
systemctl status → not running? → journalctl -u SVC -b → config error? (configtest), 203/EXEC?, port bind (SELinux label / in use)?
running → listening on the right address/port? (ss -tlnp) → local curl works?
  no  → app/config/SELinux (ausearch -m avc), file permissions/labels on content
  yes → firewall (firewall-cmd --list-all), client route/DNS, TLS
works now → enabled? (is-enabled) persists after reboot? (reboot test)
```

### 5.3 "The server is slow"

USE per resource: [performance & observability §2](../advanced-rhel-and-career-notes/performance-and-observability.md#2-the-first-60-seconds-on-a-slow-linux-host).

## 6. Evidence Collection

```bash
journalctl -b --since "-1h" > /root/incident-$(date +%F_%H%M)-journal.txt
top -b -n 1 > /root/incident-top.txt ; ps -eo pid,ppid,user,stat,%cpu,%mem,wchan:20,cmd > /root/incident-ps.txt
ss -tanp > /root/incident-ss.txt ; df -h ; df -i ; dmesg -T > /root/incident-dmesg.txt
dnf history | head ; rpm -Va 2>/dev/null | grep -v '^.......T' | head     # what changed?
sos report --batch                  # Red Hat support bundle (sos package): logs, configs, command output
```

## 7. Communicating During an Incident (SRE practice)

- State **impact** first ("checkout API 50% errors since 14:02"), then what you know, what you're trying, and when you'll update next.
- Keep a timestamped log of actions; it becomes the timeline for the postmortem.
- After resolution: blameless **postmortem** with root cause, contributing factors, detection gaps, and action items (monitoring, tests, automation).

## 8. Practising the Method

- RHCSA level: [mock exam 3 (break-fix)](../rhcsa-exam-labs/mock-exam-3.md).
- Production level: [production scenarios](production-scenarios.md). Do them on a lab VM, out loud, following §2.
- Interview level: explain your reasoning for each scenario in 3–5 minutes without notes ([question bank](interview-question-bank.md)).

## 9. Quick Revision

```
define → scope → timeline (what changed?) → evidence (before changes) → hypotheses → test one thing → fix cause → verify (reboot) → prevent
layers: hardware → kernel resources → storage → network → security (fw/SELinux/DAC) → systemd → app → DNS → client
read errors literally: EACCES EPERM ENOENT ENOSPC EROFS ECONNREFUSED ETIMEDOUT EMFILE 137 203/EXEC EADDRINUSE
mitigate before investigating · don't destroy evidence · sos report · blameless postmortem
```
