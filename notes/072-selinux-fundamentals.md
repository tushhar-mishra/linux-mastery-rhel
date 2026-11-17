# 072 · SELinux Fundamentals: Modes, Contexts and Type Enforcement (plus AppArmor)

> **You need first:** [071 · firewalld](071-firewalld.md)
> **Next:** [073 · SELinux file contexts](073-selinux-file-contexts.md)

---

## What it is

**SELinux** (Security-Enhanced Linux) is a **MAC** (Mandatory Access Control) system built into the kernel.

- Normal Linux permissions (rwx, owners, ACLs; topic 026) are **DAC** (Discretionary Access Control): the file's **owner** decides who gets in, and **root bypasses everything**.
- SELinux adds a **central policy**, written by the distribution, that every process must obey, **including root's**. If the policy has no rule allowing an access, it's **denied**.

Key words:
- **Label** (or **security context**): every process and every file, directory, port and socket carries one, like `system_u:system_r:httpd_t:s0`.
- **Type**: the third field of the label (`httpd_t`, `httpd_sys_content_t`). **On a process it's called a domain.**
- **Type Enforcement (TE)**: the core rule style: "processes in domain X may do Y to objects of type Z". For example, `httpd_t` may **read** `httpd_sys_content_t`.
- **AVC** (Access Vector Cache): the kernel's cache of SELinux decisions. A **denial** is logged as an `AVC` record in `/var/log/audit/audit.log` (the audit log, topic 077).
- **Targeted policy**: RHEL's default policy. **Services** (web server, SSH, DNS, databases…) are confined in their own domains; normal **users** run **unconfined**.

**Ubuntu/Debian** use **AppArmor** instead (covered at the end): the same goal, done with path-based profiles.

## Why it exists

Imagine your web server has a bug and an attacker gets code running inside it. With DAC alone, the attacker can do anything the web server's user can, and if the service runs as root, anything at all. With SELinux, that process is stuck in the `httpd_t` domain: it can read web content and talk to the network, but it **can't** read `/etc/shadow`, users' home directories or SSH keys, or start a shell on port 4444. **SELinux contains the damage of compromised services.** It's a major reason RHEL servers resist exploits that fully compromise other systems.

## Analogy

DAC is **door locks** that each office owner controls; the building manager (root) has a master key. SELinux is a **security guard posted at every door** with a **central rulebook** from head office: "Kitchen staff (domain `httpd_t`) may enter the kitchen and pantry (types `httpd_sys_content_t`), never the vault (`shadow_t`)". Even someone holding the master key gets stopped if their **badge** (label) says "kitchen staff". The guard also writes every refusal in a logbook (the AVC denials).

## How it works inside

### Two gates, in order

1. **DAC first:** rwx bits, owner, ACLs. If DAC denies → "Permission denied", and SELinux isn't even asked.
2. **Then SELinux:** the kernel looks up (process domain, object type, object class, permission) in the policy. No allow rule → **denied**, and an AVC denial is logged. Allowed decisions are cached in the AVC.

So when "permissions look correct" but you still get "Permission denied", think SELinux.

### The context (label): `user:role:type:level`

```
system_u:object_r:httpd_sys_content_t:s0      /var/www/html/index.html   (a file)
system_u:system_r:httpd_t:s0                  the httpd process
unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023   your login shell
```

| Field | Meaning | Examples |
|---|---|---|
| **user** | SELinux user (Linux users are mapped onto it) | `system_u`, `unconfined_u`, `staff_u` |
| **role** | Role (for role-based access control) | `object_r` (all files), `system_r` (daemons), `unconfined_r` |
| **type** | **The important one**: type for objects, domain for processes | `httpd_t`, `sshd_t`, `user_home_t`, `etc_t`, `shadow_t` |
| **level** | MLS/MCS security level and categories (topic 076) | `s0`, `s0:c12,c34` |

Naming convention: `*_t` = a type; `*_exec_t` = a program file that starts a domain; `*_port_t` = a port type.

**File labels** are stored in the inode's extended attributes (`security.selinux`). **Process labels** are kept by the kernel for each process.

### Where labels come from

- A **new file** normally gets the **type of its parent directory** (create a file in `/var/www/html` → `httpd_sys_content_t`). Policy **type-transition** rules can override this (a file an unconfined user creates in `/tmp` becomes `user_tmp_t`).
- **`cp`** creates a new file → it gets the destination's label. **`mv`** keeps the inode → it **keeps its old label** (topics 007, 073).
- The **policy's file-context database** says what each path *should* be labelled. `restorecon` resets files to it (topic 073).

### Domain transitions: how processes get their domain

A process changes domain when it **executes** a file whose type is an **entry point** for a new domain, and the policy allows that transition. Example: your shell (`unconfined_t`) runs `/usr/bin/passwd` (`passwd_exec_t`) → the new process runs as **`passwd_t`**, which is allowed to write `/etc/shadow` (`shadow_t`). A web server (`httpd_t`) has no such rule, so it can't touch `/etc/shadow`, even if DAC would allow it.

systemd starts services the same way: `/usr/sbin/httpd` is `httpd_exec_t`, so the service runs as `httpd_t`.

### Modes

| Mode | What happens |
|---|---|
| **Enforcing** | The policy is enforced: denials are **blocked** and logged (RHEL default) |
| **Permissive** | Nothing is blocked, but would-be denials are **logged**: for troubleshooting only |
| **Disabled** | No SELinux at all. **Don't.** Files created while disabled get no labels; turning it back on needs a full relabel |

## Commands

### Mode

```bash
getenforce
sestatus
```
```
Enforcing
SELinux status:                 enabled
SELinuxfs mount:                /sys/fs/selinux
SELinux root directory:         /etc/selinux
Loaded policy name:             targeted
Current mode:                   enforcing
Mode from config file:          enforcing
Policy MLS status:              enabled
Policy deny_unknown status:     allowed
Memory protection checking:     actual (secure)
Max kernel policy version:      33
```
- `Current mode` = right now. `Mode from config file` = what will apply after the next boot.

```bash
sudo setenforce 0 ; getenforce       # Permissive (until reboot)
sudo setenforce 1 ; getenforce       # Enforcing
```
Permanent: `/etc/selinux/config`:
```
SELINUX=enforcing
SELINUXTYPE=targeted
```

| Need | How |
|---|---|
| Permissive for one boot | Kernel argument `enforcing=0` (topic 054) |
| Only **one** domain permissive (much safer than the whole system) | `sudo semanage permissive -a httpd_t` (undo: `-d`) |
| Fully disable (not recommended) | `sudo grubby --update-kernel ALL --args selinux=0` |
| Re-enable after disabling | Remove `selinux=0`, set the config, `sudo touch /.autorelabel`, reboot |

`setenforce` can't switch to or from **Disabled**.

### See labels

```bash
ls -Z /var/www/html/index.html /etc/shadow /home/alice/notes.txt
```
```
system_u:object_r:httpd_sys_content_t:s0 /var/www/html/index.html
system_u:object_r:shadow_t:s0 /etc/shadow
unconfined_u:object_r:user_home_t:s0 /home/alice/notes.txt
```
```bash
ls -dZ /var/www/html          # the directory itself
ps -eZ | grep -E 'httpd|sshd'
id -Z
```
```
system_u:system_r:httpd_t:s0      1210 ?        00:00:00 httpd
system_u:system_r:sshd_t:s0-s0:c0.c1023 1050 ?  00:00:00 sshd
system_u:system_r:sshd_session_t:s0-s0:c0.c1023 2370 ? 00:00:00 sshd-session
unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023
```
- RHEL 10's policy runs each SSH login's `sshd-session` process in its own domain, `sshd_session_t`, separate from the listening daemon (`sshd_t`).
- `ls -l` shows a `.` after the permission bits when a file has an SELinux label (topic 007).

### Watch a domain transition

```bash
ls -Z /usr/bin/passwd
passwd &                   # it waits for input
ps -eZ | grep passwd
kill %1
```
```
system_u:object_r:passwd_exec_t:s0 /usr/bin/passwd
unconfined_u:unconfined_r:passwd_t:s0-s0:c0.c1023 5120 pts/0 00:00:00 passwd
```

### First look at denials

```bash
sudo dnf install -y policycoreutils-python-utils setroubleshoot-server   # semanage, sealert
sudo ausearch -m AVC,USER_AVC -ts recent
```
```
type=AVC msg=audit(1763316002.512:412): avc:  denied  { read } for  pid=1210 comm="httpd"
  name="index.html" dev="sda4" ino=144181 scontext=system_u:system_r:httpd_t:s0
  tcontext=unconfined_u:object_r:user_home_t:s0 tclass=file permissive=0
```
- **Who** (`comm="httpd"`, `scontext=…httpd_t`) was denied **what** (`{ read }`) on **which** object (`name="index.html"`, `tcontext=…user_home_t`, `tclass=file`). `permissive=0` = it was really blocked.
- Here the file has the **wrong label** (`user_home_t` instead of `httpd_sys_content_t`), typically from `mv`ing it out of a home directory. Topics 073–074 show the fixes.

```bash
sudo sealert -a /var/log/audit/audit.log | less
```
- Explains each denial in plain English and suggests fixes.

**The golden rule:** temporarily switching to permissive (`setenforce 0`, retry, `setenforce 1`) is fine for **diagnosis**: if it works when permissive, SELinux is the cause. **Never "fix" a problem by leaving SELinux off.** The real fix is almost always one of three: **relabel the file** (073), **toggle a boolean** (074), or **label a port** (074).

### SELinux users (a preview; more in topic 075)

```bash
sudo semanage login -l
```
```
Login Name           SELinux User         MLS/MCS Range        Service
__default__          unconfined_u         s0-s0:c0.c1023       *
root                 unconfined_u         s0-s0:c0.c1023       *
```
- In the targeted policy, every Linux user maps to `unconfined_u` by default. That's why your own shell isn't restricted.

### Ubuntu: AppArmor

AppArmor confines programs with **path-based profiles** (rules like "`/usr/sbin/nginx` may read `/var/www/**`") instead of labels.
```bash
sudo aa-status                       # which profiles are loaded, enforce vs complain mode
sudo aa-complain /usr/sbin/nginx     # log only (like permissive, per program)
sudo aa-enforce  /usr/sbin/nginx
sudo journalctl -k | grep -i apparmor   # denials
```
Profiles live in `/etc/apparmor.d/`. Docker and snap packages use AppArmor profiles on Ubuntu.

### Try it
1. `getenforce`, `sestatus`; switch to permissive and back.
2. Compare `ls -Z` on `/etc/shadow`, `/var/www/html` (install httpd first), your home directory and `/tmp`.
3. Watch the `passwd` domain transition with `ps -eZ`.
4. Create `~/index.html`, **`mv`** it to `/var/www/html/`, request it with `curl localhost` (403 Forbidden), then find the AVC denial with `ausearch`. (The fix is in topic 073.)

## Where you'll use it

- **Every RHEL production server runs enforcing.** Teams that disable it to "make things work" lose a major defence, and security audits (CIS, STIG, PCI) flag it.
- **Classic incidents:** a web server returning 403 on correct permissions; a service failing to bind a new port; a daemon unable to write its log in a custom directory. All of these are labels, booleans or ports.
- **Containers:** Podman (and Kubernetes on RHEL/OpenShift) run containers as `container_t` with **unique MCS categories** per container (topic 076), so one container can't read another's files even if both run as the same UID. Volume mounts need the `:Z`/`:z` options to relabel content (topic 101).
- **Interviews:** "SELinux is blocking my app, what do you do?" The expected answer is never "disable it".

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| "Permission denied" although rwx looks fine | An SELinux denial | `ausearch -m avc -ts recent`; fix the label, boolean or port (073/074) |
| `ausearch -m AVC` says `<no matches>`, yet access is clearly denied | (1) `ausearch` was run **without a terminal** (a script, cron, `ssh host 'cmd'`): it then reads events from stdin instead of the log files. (2) The policy has a `dontaudit` rule for this access, so nothing is logged | (1) Add `--input-logs` in scripts and remote commands. (2) `sudo semodule -DB` logs everything; `sudo semodule -B` restores |
| `setenforce: SELinux is disabled` | Booted with SELinux disabled | Remove `selinux=0`, relabel, reboot |
| Nobody can log in after editing files from `rd.break` | Wrong labels on `/etc/shadow` etc. | `touch /.autorelabel`; reboot (topic 057) |
| `semanage: command not found` | Package missing | `dnf install policycoreutils-python-utils` |
| `sealert: command not found` | Package missing | `dnf install setroubleshoot-server` |
| No AVCs logged, but it still fails only when enforcing | A "dontaudit" rule hides the denial | `semodule -DB` temporarily (topic 074) |

## Quick recap

- SELinux = MAC: a central policy that even root's processes obey, checked **after** DAC. No allow rule = denied.
- Labels: `user:role:type:level`. **Type** matters (domain on processes). See them with `ls -Z`, `ps -eZ`, `id -Z`.
- Modes: enforcing / permissive / disabled. `getenforce`, `setenforce 0|1`, `/etc/selinux/config`. Permissive is for diagnosis only.
- Denials: `ausearch -m AVC -ts recent`, `sealert`. Fixes: relabel, boolean, port. Ubuntu uses AppArmor (`aa-status`).

**Interview questions**

1. *DAC vs MAC?* DAC lets the owner decide permissions, and root bypasses them. MAC applies a system-wide policy that users and even root-owned processes can't override.
2. *Which part of the SELinux context matters most in the targeted policy?* The type: the domain for processes and the type for files. Type enforcement rules decide which domain may access which type.
3. *An app works with `setenforce 0` but not enforcing. What next?* Read the AVC denial (`ausearch -m avc`, `sealert`), then fix the cause properly: restore or define the correct file label, enable the right boolean, or label the port. Then return to enforcing.
