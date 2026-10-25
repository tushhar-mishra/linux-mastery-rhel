# Linux Auditing with auditd

> **Track:** **[Production Practice]** (compliance, security investigations) · not an RHCSA objective, but SELinux troubleshooting reads its log · **Verification status:** auditd can't run inside the container lab used for this knowledge base; commands follow the RHEL `audit` package documentation and man pages (`auditctl(8)`, `audit.rules(7)`, `ausearch(8)`). Practise on a RHEL VM.
> **Prerequisites:** [SELinux fundamentals](selinux-fundamentals.md) · [System logging](../logs-scheduling-and-packages/system-logging.md) · [Processes & system calls](../processes-and-resource-management/processes-and-system-calls.md) · [sudo](../users-groups-and-permissions/sudo-and-privileged-access.md)
> **Related:** [SELinux troubleshooting (ausearch -m AVC)](selinux-booleans-ports-troubleshooting.md) · [PAM](../users-groups-and-permissions/pam-and-authselect.md)

## 1. Why auditd

Shell history can be edited, and syslog entries can be forged by any process allowed to write to the log socket. The **Linux audit framework** records security-relevant events **in the kernel** (system calls, file access, logins, SELinux denials) and hands them to the `auditd` daemon, which writes `/var/log/audit/audit.log`. It answers: *who* (even after `su`/`sudo`), *did what*, *to which object*, *when*, *with what result*.

## 2. Architecture

```
 kernel audit subsystem ──(netlink)──► auditd ──► /var/log/audit/audit.log
   ▲ rules (auditctl / augenrules)       │
   │                                     └─► audisp plugins (e.g., forward to syslog/remote)
 events: syscalls, file watches, logins (PAM), SELinux AVCs, sudo (USER_CMD)
```

| Component | Role |
|---|---|
| `auditd.service` | Daemon; installed and enabled on RHEL (package `audit`) |
| `/etc/audit/auditd.conf` | Log file, size and rotation (`max_log_file`, `num_logs`, `max_log_file_action`), disk-full actions |
| `/etc/audit/rules.d/*.rules` | **Persistent rules** (you edit these) |
| `augenrules --load` | Merge `rules.d/*` into `/etc/audit/audit.rules` and load them |
| `auditctl` | Show/add rules at runtime, status |
| `ausearch`, `aureport` | Query and summarize the log |

> ⚠️ On RHEL, `auditd.service` refuses manual stop (`RefuseManualStop=yes`), so `systemctl restart auditd` fails. Use `service auditd restart` (the supported wrapper), or reload rules with `augenrules --load`.

## 3. The Audit UID (auid)

`pam_loginuid` records the **login UID** when a user logs in. It is inherited by every process of the session and **not changed by `su` or `sudo`**. An audit record of `rm /etc/important` run through `sudo -i` still shows `auid=alice uid=root`. That's why audit logs give real accountability on systems where admins share root.

## 4. Rules

```bash
auditctl -s                 # status: enabled, failure mode, backlog, lost events
auditctl -l                 # rules currently loaded
```

### 4.1 File watches

```
# /etc/audit/rules.d/50-identity.rules
-w /etc/passwd  -p wa -k identity
-w /etc/shadow  -p wa -k identity
-w /etc/group   -p wa -k identity
-w /etc/sudoers -p wa -k privileged
-w /etc/sudoers.d/ -p wa -k privileged
-w /etc/ssh/sshd_config -p wa -k sshd_config
```

`-p` permissions: `r` read, `w` write, `x` execute, `a` attribute change. `-k` attaches a **key** to search by.

### 4.2 System-call rules

```
# Every command executed with effective UID 0 by a real (logged-in) user
-a always,exit -F arch=b64 -S execve -F euid=0 -F auid>=1000 -F auid!=unset -k root_cmds
-a always,exit -F arch=b32 -S execve -F euid=0 -F auid>=1000 -F auid!=unset -k root_cmds
# Failed file opens due to permissions
-a always,exit -F arch=b64 -S openat -F exit=-EACCES -k access_denied
-a always,exit -F arch=b64 -S openat -F exit=-EPERM  -k access_denied
```

- `-a always,exit` = record at syscall exit; `-F` = field filters; `arch=b64`/`b32` because syscall numbers differ per ABI (include both on x86-64).
- Broad syscall rules (e.g., every `execve`) generate a lot of data: scope them with `-F` filters.

```bash
augenrules --load ; auditctl -l          # apply persistent rules
auditctl -w /tmp/test -p wa -k test      # temporary rule (until reboot/reload)
```

**Immutable mode:** `-e 2` as the **last** rule locks the configuration until reboot (attackers with root can't disable auditing quietly). Rule changes then require a reboot.

## 5. Searching & Reporting

```bash
ausearch -k identity -i                 # by key; -i interprets numeric UIDs, syscalls, etc.
ausearch -k privileged -ts today -i
ausearch -m USER_CMD -i                 # sudo commands
ausearch -m USER_LOGIN,USER_AUTH --success no -ts yesterday -i   # failed logins
ausearch -m AVC,USER_AVC -ts recent     # SELinux denials (see SELinux troubleshooting)
ausearch -ua alice -ts this-week -i     # everything for audit UID alice
aureport --summary ; aureport -au ; aureport -x --summary ; aureport -k
```

Reading a record set (one event = several lines sharing the same `msg=audit(TIME:ID)`):

```
type=SYSCALL msg=audit(1761400000.123:4242): arch=c000003e syscall=257 success=yes exit=3 … auid=1001 uid=0 euid=0 … comm="vi" exe="/usr/bin/vim" key="identity"
type=CWD     msg=audit(1761400000.123:4242): cwd="/root"
type=PATH    msg=audit(1761400000.123:4242): item=0 name="/etc/shadow" inode=… nametype=NORMAL …
```

`ausearch -i` turns `auid=1001` into `auid=alice` and `syscall=257` into `syscall=openat`.

## 6. Production Practices **[Production Practice]**

- Start from a baseline rule set instead of inventing rules: the `audit` package ships sample rule files (find them with `rpm -ql audit | grep -i rules`; the directory name differs between audit 3.x and 4.x), and security profiles such as CIS/STIG are available through `scap-security-guide`.
- Size and rotate the log (`max_log_file`, `num_logs`), and decide what happens when the disk fills (`space_left_action`, `admin_space_left_action`, `disk_full_action`).
- Forward audit events off-host (audisp syslog plugin → central log system), since a compromised host's local log can't be trusted.
- Watch `auditctl -s` for `lost` events and backlog limits (`-b`) on busy systems.

## 7. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `systemctl restart auditd` refused | `RefuseManualStop=yes` | `service auditd restart` |
| New rules in `rules.d` not active | Not loaded | `augenrules --load`; check `auditctl -l` |
| `The audit system is in immutable mode` | `-e 2` loaded | Change rules and reboot |
| `lost` counter rising | Event rate exceeds backlog | Narrow rules; raise `-b`; check disk speed |
| No records for a watched file | Rule on a symlink, wrong path, or edits via rename (editors) | Watch the directory, verify with `auditctl -l` |

## 8. Interview Questions

| Question | Answer |
|---|---|
| Why use auditd instead of shell history or syslog? | It records events in the kernel with the login UID, can't be bypassed by the user's shell, and can be made immutable. |
| What's the auid? | The login UID set at login; it survives `su`/`sudo`, attributing actions to the real person. |
| How do you track changes to `/etc/sudoers`? | `-w /etc/sudoers -p wa -k privileged` (+ `/etc/sudoers.d/`), then `ausearch -k privileged -i`. |
| Where are SELinux denials logged? | `/var/log/audit/audit.log` as AVC records; `ausearch -m AVC`. |
| How do you make rules persistent? | Files in `/etc/audit/rules.d/`, loaded by `augenrules --load` (and at boot). |

## 9. Quick Revision

```
kernel audit → auditd → /var/log/audit/audit.log · auditd.conf (rotation, disk full) · service auditd restart (not systemctl)
rules: /etc/audit/rules.d/*.rules → augenrules --load · auditctl -l / -s · -w PATH -p rwxa -k KEY
-a always,exit -F arch=b64 -S execve -F euid=0 -F auid>=1000 -F auid!=unset -k KEY · -e 2 immutable (last rule)
ausearch -k KEY -i · -m USER_CMD / USER_LOGIN / AVC · -ua USER · -ts today|recent · aureport --summary / -au / -x
auid survives su/sudo (pam_loginuid)
```

## 10. Cross-References

- [SELinux booleans, ports & troubleshooting](selinux-booleans-ports-troubleshooting.md) · [SELinux fundamentals](selinux-fundamentals.md)
- [sudo (logging)](../users-groups-and-permissions/sudo-and-privileged-access.md#7-logging--auditing) · [PAM (pam_loginuid)](../users-groups-and-permissions/pam-and-authselect.md) · [System logging](../logs-scheduling-and-packages/system-logging.md)
- [Command history (why it's not an audit log)](../shell-and-command-line/command-history.md)
