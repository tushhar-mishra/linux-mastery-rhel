# SELinux Fundamentals: Modes, Contexts & Domain Transitions

> **Sessions:** S71–S72 · **Objectives:** *Set enforcing and permissive modes for SELinux* · *List and identify SELinux file and process context* **[RHCSA Core]**
> **Related:** [firewalld](firewalld.md) · [File permissions (DAC)](../users-groups-and-permissions/file-permissions.md) · [Boot recovery (/.autorelabel)](../boot-systemd-and-kernel/boot-recovery.md) · [Files & directories (cp vs mv contexts)](../shell-and-command-line/files-and-directories.md) · file contexts, booleans, ports (S73–77, planned)

## 1. Overview

**SELinux** (Security-Enhanced Linux) is a **Mandatory Access Control (MAC)** system in the kernel. Standard permissions (**DAC**) let file owners decide access. SELinux adds a **system-wide policy** that even root's processes must obey. A compromised web server, for example, can't read `/etc/shadow` or home directories, even though it runs as a privileged user, because its **domain** isn't allowed to.

- **Subjects** = processes (labeled with a *domain*, e.g., `httpd_t`).
- **Objects** = files, directories, sockets, ports (labeled with a *type*, e.g., `httpd_sys_content_t`).
- **Decision order:** DAC first (rwx, ACLs); if allowed, then SELinux. **No allow rule = denied** (default deny).
- The **Access Vector Cache (AVC)** caches decisions; denials are logged as `AVC` records in `/var/log/audit/audit.log`.
- RHEL uses the **targeted** policy: system services are confined, while interactive users run **unconfined** by default. Alternatives: `minimum`, `mls`.

SELinux complements, and doesn't replace, firewalls, permissions and patching.

## 2. Modes **[RHCSA Core]**

| Mode | Behavior |
|---|---|
| **Enforcing** | Policy enforced; denials blocked and logged (RHEL default) |
| **Permissive** | Nothing blocked; would-be denials logged (troubleshooting) |
| **Disabled** | No SELinux (not recommended; re-enabling requires a full relabel) |

```bash
getenforce                         # Enforcing | Permissive | Disabled
sestatus                           # mode, policy, config-file mode, MLS status …
setenforce 0                       # → Permissive (runtime, until reboot)
setenforce 1                       # → Enforcing  (runtime)
```

**Persistent** (`/etc/selinux/config`, applied at boot):

````
SELINUX=enforcing          # enforcing | permissive | disabled
SELINUXTYPE=targeted
````

| Need | How |
|---|---|
| Permissive for one boot | Kernel argument `enforcing=0` (GRUB `e`) |
| Fully disable (RHEL 9/10 documented method) | `grubby --update-kernel ALL --args selinux=0` ⚠️ |
| Re-enable after disabled | Remove `selinux=0`, set config, `touch /.autorelabel`, reboot (full relabel) |
| One domain permissive **[Advanced]** | `semanage permissive -a httpd_t` |

`setenforce` can't switch to or from **Disabled**.

## 3. Security Contexts **[RHCSA Core]**

````
user  :  role  :  type  :  level
system_u:object_r:httpd_sys_content_t:s0          /var/www/html/index.html
unconfined_u:object_r:user_home_t:s0              /home/alice/notes.txt
system_u:system_r:httpd_t:s0                      httpd process
````

| Field | Meaning | Common values |
|---|---|---|
| **user** | SELinux user (mapped from Linux users) | `system_u`, `unconfined_u`, `staff_u`, `user_u` |
| **role** | RBAC role | `object_r` (files), `system_r` (daemons), `unconfined_r` |
| **type** | **Type** for files / **domain** for processes; the field that matters most (Type Enforcement) | `httpd_t`, `sshd_t`, `user_home_t`, `etc_t`, `shadow_t` |
| **level** | MLS/MCS sensitivity:categories | `s0`, `s0-s0:c0.c1023` |

Naming convention: `*_t` types; `*_exec_t` executables (entry points); `*_port_t` port types.

### Viewing contexts

```bash
ls -Z /var/www/html          # files      (ls -dZ dir: the directory itself)
ls -lZ /etc/shadow           # system_u:object_r:shadow_t:s0
ps -eZ | grep -E 'httpd|sshd'   # processes (ps -efZ, ps axZ)
id -Z                        # your own context (unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023)
stat -c '%C %n' /etc/hosts   # context via stat
```

New files inherit the **type of the parent directory** (e.g., created in `/tmp` → `user_tmp_t`). That's why `cp` into `/var/www/html` gets the right label but `mv` keeps the old one (fixed with `restorecon`, S76).

## 4. Domain Transitions

A process changes domain when it executes a file whose type is an **entry point** for the new domain:

```bash
ls -Z /usr/bin/passwd        # system_u:object_r:passwd_exec_t:s0
ls -Z /etc/shadow            # system_u:object_r:shadow_t:s0
passwd alice &               # (in another terminal while it waits for input)
ps -eZ | grep passwd         # unconfined_u:unconfined_r:passwd_t:s0-s0:c0.c1023 … passwd
```

The policy allows `unconfined_t` → `passwd_t` when executing `passwd_exec_t`, and `passwd_t` may write `shadow_t`. A confined web server (`httpd_t`) has no such rule, so it can't touch `/etc/shadow`.

## 5. SELinux Users & Login Mapping **[Advanced]**

```bash
semanage login -l            # __default__ → unconfined_u ; root → unconfined_u
semanage user -l             # SELinux users and their allowed roles
semanage login -a -s staff_u student      # map Linux user 'student' to staff_u (-m to modify an existing mapping)
ssh student@localhost 'id -Z'             # staff_u:staff_r:staff_t:s0-s0:c0.c1023 (requires a REAL login)
semanage login -d student                 # remove the mapping
```

`su - student` keeps the caller's SELinux context; only real logins (SSH, console) apply the mapping. Confined users (`user_u`, `staff_u`) restrict what users can do, e.g., `user_u` can't use `su`/`sudo`. Test carefully before mapping administrators.

MLS/MCS category names are translated in `/etc/selinux/targeted/setrans.conf` (mcstrans).

## 6. First Steps in Troubleshooting

```bash
dnf install -y policycoreutils-python-utils setroubleshoot-server   # semanage, sealert
ausearch -m AVC,USER_AVC -ts recent      # recent denials (raw)
sealert -a /var/log/audit/audit.log      # human-readable explanations + suggested fixes
journalctl -t setroubleshoot             # setroubleshoot summaries
setenforce 0 ; <retry> ; setenforce 1    # if it works when permissive → SELinux is the cause (diagnosis only!)
```

Typical fixes (detailed in S73–77): **relabel files** (`restorecon`, `semanage fcontext`), **toggle a boolean** (`setsebool -P`), **label a port** (`semanage port -a`). Never "fix" by disabling SELinux.

## 7. RHCSA Exam Focus **[RHCSA Core]**

- "Set SELinux to enforcing persistently": `SELINUX=enforcing` in `/etc/selinux/config` + `setenforce 1` (now), then verify `getenforce` and `sestatus`.
- If the system is booted with `selinux=0` or `enforcing=0`, remove those arguments (`grubby --update-kernel ALL --remove-args="selinux enforcing"`).
- Identify contexts: `ls -Z` (files), `ps -eZ` (processes), `id -Z` (you).
- Leave the system **enforcing** at the end of the exam.

## 8. Production Practices **[Production Practice]**

- Keep SELinux enforcing; use permissive only briefly, ideally per domain.
- Store content in standard locations or define proper file-context rules for custom paths.
- Monitor AVC denials (`ausearch`, setroubleshoot) after deployments.
- Relabel after restoring files from backups that didn't preserve xattrs (`restorecon -Rv`).

## 9. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Service fails with "Permission denied" although rwx is fine | SELinux denial | `ausearch -m avc -ts recent`; correct label/boolean/port |
| `setenforce: SELinux is disabled` | Booted with SELinux disabled | Remove `selinux=0`, relabel, reboot |
| Logins fail after editing files from rescue/`rd.break` | Wrong labels | `touch /.autorelabel`; reboot |
| `semanage: command not found` | Package missing | `dnf install policycoreutils-python-utils` |
| `sealert: command not found` | Package missing | `dnf install setroubleshoot-server` |
| New user mapping not visible after `su -` | `su` keeps the caller's context | Log in via SSH/console |

## 10. Interview Questions

| Question | Answer |
|---|---|
| DAC vs MAC? | DAC: owners set permissions. MAC: a central policy decides, and users (even root processes) can't override it. |
| What field of the context matters most in targeted policy? | The **type** (domain for processes). |
| Enforcing vs permissive? | Enforcing blocks and logs; permissive only logs. |
| How do you disable SELinux on RHEL 9/10? | Kernel argument `selinux=0` (not recommended); permissive is the safer troubleshooting option. |
| What's a domain transition? | A process entering a new domain by executing an entry-point type (e.g., `passwd_exec_t` → `passwd_t`). |
| Where are denials logged? | `/var/log/audit/audit.log` (AVC records); read with `ausearch`/`sealert`. |

## 11. Course Corrections

| Course | Correction |
|---|---|
| Disabled = "edit /etc/selinux/config" | On RHEL 9/10 use the `selinux=0` kernel argument to fully disable; relabel when re-enabling |
| `dnf install selinux-policy … policycoreutils` | Already installed; `semanage` needs `policycoreutils-python-utils`, `sealert` needs `setroubleshoot-server` |
| Staff mapping Step 4 "verify in a new SSH session" using `su - student` | `su` inherits the caller's context; use `ssh student@localhost` |
| "unconfined_t by default on Fedora" | Same on RHEL (targeted policy) |
| `semanage login -m` for a new user | `-a` adds; `-m` modifies an existing mapping |

## 12. Quick Revision

```bash
getenforce · sestatus · setenforce 0|1 · /etc/selinux/config SELINUX=enforcing · enforcing=0 / selinux=0 (kernel args)
user:role:type:level · ls -Z · ls -dZ · ps -eZ · id -Z · new files inherit parent dir type · mv keeps, cp relabels
passwd: unconfined_t --exec passwd_exec_t--> passwd_t --writes--> shadow_t
semanage login -l / -a -s staff_u USER · ausearch -m AVC -ts recent · sealert -a /var/log/audit/audit.log
