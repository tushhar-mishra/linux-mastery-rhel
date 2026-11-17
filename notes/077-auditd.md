# 077 · Linux Auditing with auditd

> **You need first:** [076 · SELinux MLS and MCS](076-selinux-mls-mcs.md)
> **Next:** [078 · Web servers: Apache and nginx](078-web-servers-apache-and-nginx.md)

---

## What it is

The **Linux audit framework** records security-relevant events **inside the kernel**: system calls, file accesses, logins, sudo commands, SELinux denials. It hands them to the **`auditd`** daemon, which writes them to **`/var/log/audit/audit.log`**.

| Piece | Role |
|---|---|
| Kernel audit subsystem | Watches events according to **rules** and generates records |
| `auditd.service` | Receives the records and writes the log (package `audit`, enabled on RHEL; `auditd` package on Ubuntu) |
| `/etc/audit/rules.d/*.rules` | Your **permanent** rules |
| `augenrules --load` | Merge and load those rules |
| `auditctl` | Show status and rules, add temporary rules |
| `ausearch`, `aureport` | Search and summarise the log |
| **auid** (audit UID / login UID) | The UID of the person who **originally logged in**. It never changes for that session, even after `su` or `sudo` |

## Why it exists

Shell history can be edited or switched off (topic 015). Ordinary syslog messages can be written by any program. Auditors and incident responders need records that answer **who did what, to which object, when, and whether it succeeded**, and that a user's shell **can't bypass**. Many compliance standards (PCI-DSS for card payments, HIPAA for health data, government STIG baselines) require them.

## Analogy

Normal logs are **notes employees write about themselves**. Audit is the **building's own access-control system**: every badge swipe at a sensitive door is recorded by the door itself. And the record always shows the badge of the **person who walked in that morning** (the auid), even if they later borrowed the manager's master key (sudo).

## How it works inside

```
kernel audit subsystem ──(netlink)──► auditd ──► /var/log/audit/audit.log
   ▲ rules (auditctl / augenrules)       └──► plugins (audisp: e.g. forward to syslog / a remote server)
events: system calls, file watches, logins (PAM), sudo (USER_CMD), SELinux AVC denials
```

- **Rules are evaluated in the kernel** on matching events, so a user can't skip them: no matter which program or shell they use, the system call is seen.
- **The auid:** at login, PAM's `pam_loginuid` (topic 029) writes the user's UID into `/proc/self/loginuid`. Every process in that session inherits it, and **`su`/`sudo` don't change it**. So `sudo rm /etc/important` is logged as `auid=alice uid=0`: real accountability even when admins share root.
- One **event** can produce **several records** (SYSCALL, CWD, PATH, PROCTITLE…) that share the same `msg=audit(TIMESTAMP:SERIAL)` id.
- **SELinux denials** (AVC records) go through audit as well, which is why topic 072 used `ausearch -m AVC`.
- **Immutable mode** (`-e 2` as the last rule) locks the audit configuration until the next reboot, so even an attacker with root can't quietly switch auditing off.
- On RHEL, `auditd.service` refuses a manual `systemctl stop/restart` (`RefuseManualStop=yes`), to protect auditing. Use `service auditd restart`, or just reload the rules.

## Commands

### Status and rules

```bash
sudo auditctl -s
sudo auditctl -l
```
```
enabled 1
failure 1
pid 812
rate_limit 0
backlog_limit 8192
lost 0
backlog 0
-w /etc/passwd -p wa -k identity
...
```
- `enabled 1` = auditing is on (2 = immutable). **`lost`** = events dropped because auditd couldn't keep up: it should stay 0. `backlog_limit` = the kernel's queue size.

### File watches

```
# /etc/audit/rules.d/50-identity.rules
-w /etc/passwd      -p wa -k identity
-w /etc/shadow      -p wa -k identity
-w /etc/group       -p wa -k identity
-w /etc/sudoers     -p wa -k privileged
-w /etc/sudoers.d/  -p wa -k privileged
-w /etc/ssh/sshd_config -p wa -k sshd_config
```
```bash
sudo augenrules --load ; sudo auditctl -l | head -3
```
- With watch rules (`-w`), `augenrules --load` prints `Old style watch rules are slower`. It still works; the faster form is a syscall rule with a path filter, e.g. `-a always,exit -F arch=b64 -F path=/etc/passwd -F perm=wa -k identity`.
- `-w PATH` = watch this file or directory. `-p` = which access: `r` read, `w` write, `x` execute, `a` attribute change. `-k KEY` = a label to search by later.

### System-call rules

```
# Every command run with root privileges by a real, logged-in person
-a always,exit -F arch=b64 -S execve -F euid=0 -F auid>=1000 -F auid!=unset -k root_cmds
-a always,exit -F arch=b32 -S execve -F euid=0 -F auid>=1000 -F auid!=unset -k root_cmds
# File opens refused for lack of permission
-a always,exit -F arch=b64 -S openat -F exit=-EACCES -k access_denied
-a always,exit -F arch=b64 -S openat -F exit=-EPERM  -k access_denied
```
- `-a always,exit` = record when the system call finishes. `-S execve` = the "run a program" call (topic 092). `-F` = filters: `euid=0` = running as root, `auid>=1000` = a human logged in (not a service), `auid!=unset` = there was a real login.
- `arch=b64` and `arch=b32` both, because 32-bit programs use different system-call numbers.
- Broad rules (every `execve`) create a lot of data, so filter them tightly.

```bash
sudo auditctl -w /tmp/secret.txt -p rwa -k test     # temporary rule (gone at reboot or reload)
```

### Search

```bash
sudo ausearch -k identity -i -ts today
```
```
----
type=PROCTITLE msg=audit(11/16/2026 18:05:22.120:4242) : proctitle=vi /etc/passwd
type=PATH msg=audit(11/16/2026 18:05:22.120:4242) : item=0 name=/etc/passwd inode=33554541 ... nametype=NORMAL
type=CWD msg=audit(11/16/2026 18:05:22.120:4242) : cwd=/root
type=SYSCALL msg=audit(11/16/2026 18:05:22.120:4242) : arch=x86_64 syscall=openat success=yes exit=3 ... auid=alice uid=root euid=root ... comm=vi exe=/usr/bin/vim key=identity
```
- One event (id `4242`) made of 4 records. **`auid=alice uid=root`**: alice, working as root (through sudo), opened `/etc/passwd` with vim. `-i` ("interpret") turns numbers into names (`auid=1001` → `alice`, `syscall=257` → `openat`).

| Search | Command |
|---|---|
| By key | `ausearch -k KEY -i` |
| sudo commands | `ausearch -m USER_CMD -i` |
| Failed logins | `ausearch -m USER_LOGIN,USER_AUTH --success no -ts yesterday -i` |
| SELinux denials | `ausearch -m AVC,USER_AVC -ts recent` |
| Everything one person did | `ausearch -ua alice -ts this-week -i` |
| Time filters | `-ts recent` (10 min), `today`, `yesterday`, `this-week`, or `-ts 11/16/2026 09:00:00` |

### Reports

```bash
sudo aureport --summary
sudo aureport -au --failed     # failed authentications
sudo aureport -x --summary     # most-run executables
sudo aureport -k               # events per key
```
```
Summary Report
======================
Range of time in logs: 11/10/2026 08:50:02.120 - 11/16/2026 18:10:44.501
Number of changes in configuration: 14
Number of changes to accounts, groups, or roles: 6
Number of logins: 37
Number of failed logins: 212
Number of authentications: 61
Number of failed authentications: 214
...
```

### Configuration and restarting

```bash
sudo vi /etc/audit/auditd.conf        # max_log_file, num_logs, space_left_action, disk_full_action
sudo service auditd restart           # not systemctl restart (refused on RHEL)
```

### Starting from a good baseline

```bash
rpm -ql audit-rules | grep -i 'rules$' | head    # sample rule files (RHEL 10: in the audit-rules package)
```
Security profiles (CIS, STIG) from the `scap-security-guide` package include complete audit rule sets, applied with OpenSCAP.

### Try it
1. Add the identity watch rules, load them, change a user's shell with `usermod`, and find the event with `ausearch -k identity -i`.
2. Add the `root_cmds` rules, run a command with `sudo`, and find it showing **your** auid.
3. Run `aureport --summary` and `aureport -au --failed`.
4. Check `auditctl -s` for `lost` events.

## Where you'll use it

- **Compliance:** CIS/STIG/PCI rule sets on regulated servers; audit logs shipped off-host to a SIEM (Security Information and Event Management system, such as Splunk or Elastic) where they can't be tampered with.
- **Investigations:** "who changed `/etc/sudoers` last night?", "who ran `rm -rf` as root?"
- **SELinux troubleshooting:** AVC denials live in `audit.log` (topics 072–074).
- **Kubernetes:** the API server has its **own** audit log of API requests (same idea, different layer). Node-level auditd still records what happens on the host.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `ausearch`/`aureport` print `<no matches>` (or an empty report) in a script, cron job or `ssh host 'ausearch …'`, but work at your prompt | Without a terminal on stdin, they read events from **stdin**, not from the log files | Add `--input-logs` (or `-if /var/log/audit/audit.log`) |
| `auditctl: command not found` | On RHEL 10, `auditctl`, `augenrules` and the sample rules are in the separate **`audit-rules`** package | `sudo dnf install -y audit-rules` |
| `systemctl restart auditd` is refused | `RefuseManualStop=yes` | `service auditd restart` |
| New rules in `rules.d` aren't active | Not loaded | `augenrules --load`; check `auditctl -l` |
| `The audit system is in immutable mode` | `-e 2` is loaded | Change the rules, then reboot |
| The `lost` counter is rising | Events arrive faster than auditd can write | Narrow the rules; raise `-b`; check disk speed |
| No records for a watched file | A watch on a symlink, a wrong path, or an editor that saves via rename | Watch the directory; verify with `auditctl -l` |
| The disk filled up with audit logs | Rotation settings | `max_log_file`, `num_logs`, `max_log_file_action = ROTATE` |
| The system halted when the disk filled | `disk_full_action = HALT` (some strict profiles) | Intended by policy; size the log partition properly |

## Quick recap

- Kernel audit → auditd → `/var/log/audit/audit.log`. Rules in `/etc/audit/rules.d/` + `augenrules --load`; `auditctl -l/-s`.
- `-w PATH -p rwxa -k KEY` (file watches); `-a always,exit -F arch=b64 -S SYSCALL -F … -k KEY` (system calls); `-e 2` = immutable.
- **auid** = the original login user, unchanged by su/sudo: true accountability.
- Search with `ausearch -k/-m/-ua -ts -i`; summarise with `aureport`. Restart with `service auditd restart`.

**Interview questions**

1. *Why use auditd rather than shell history or syslog?* It records events in the kernel, so a user's shell can't skip or edit them; it keeps the original login identity (auid); and it can be locked with immutable mode.
2. *What is the auid?* The login UID set by PAM at login. It's inherited by every process in the session and isn't changed by su or sudo, so actions done as root are still attributed to the real person.
3. *How would you track changes to `/etc/sudoers`?* Add `-w /etc/sudoers -p wa -k privileged` (and the same for `/etc/sudoers.d/`) in `/etc/audit/rules.d/`, load with `augenrules --load`, then search with `ausearch -k privileged -i`.
