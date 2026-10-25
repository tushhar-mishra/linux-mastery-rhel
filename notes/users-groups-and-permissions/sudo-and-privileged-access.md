# sudo & Privileged Access

> **Verified:** RHEL 10.2 UBI container, sudo 1.9.17 (Oct 2026) · **Objective:** *Configure privileged access* **[RHCSA Core]**
> **Prerequisites:** [Local users](local-users.md) · [Groups](groups.md) · [File permissions](file-permissions.md) · [vi](../files-and-text-processing/vi-and-vim.md)
> **Related:** [PAM & authselect](pam-and-authselect.md) · [Switching users](../networking-and-ssh/ssh-remote-access.md#4-logging-in-and-switching-users-rhcsa-core) · [SSH hardening](../networking-and-ssh/ssh-server-hardening.md) · [System logging (/var/log/secure)](../logs-scheduling-and-packages/system-logging.md) · [SELinux confined admins](../firewall-and-selinux/selinux-confined-users-and-domains.md)

## 1. Overview

Linux grants privilege by **UID 0** (and, more precisely, by kernel **capabilities**). Running everything as root is dangerous and unauditable, so RHEL gives administrators three controlled ways to act with elevated rights:

| Mechanism | What it does | Authenticates with | Typical use |
|---|---|---|---|
| **`sudo`** | Runs *one command* (or a shell) as another user, according to rules in `/etc/sudoers` | **Your own** password (or none, if the rule says `NOPASSWD`) | Day-to-day administration; least privilege per command |
| **`su`** | Starts a shell as another user | **The target user's** password (root's for `su -`) | Rare on RHEL 10, where root is disabled by default |
| **polkit** | Lets unprivileged programs ask a privileged daemon to act (e.g., `systemctl`, `nmcli`, Cockpit) | Admin identity (members of `wheel`) | Desktop/GUI and D-Bus actions |

On RHEL 10 the installer **disables root by default**. "Make this user administrator" adds the user to **`wheel`**, and `/etc/sudoers` already contains `%wheel ALL=(ALL) ALL`. That rule is the reason admins can use `sudo` at all on a fresh install.

**Why sudo beats a shared root password:** each admin uses their own credentials, rights can be limited per command, every command is logged with the real user's name, and removing someone from a group revokes access without changing a shared secret.

## 2. How sudo Decides (mechanism)

1. `sudo` is a **set-UID root** binary (on RHEL 10: `---s--x--x root root /usr/bin/sudo`, mode 4111), so it starts with root privileges regardless of who runs it.
2. It reads the **policy**: `/etc/sudoers` plus every file pulled in by `#includedir /etc/sudoers.d` (the leading `#` is part of the directive, **not** a comment).
3. It finds the rules that match **(invoking user, host, target user/group, command)**. When several rules match, the **last matching rule wins**.
4. If the rule requires a password, it authenticates **you** through PAM (`/etc/pam.d/sudo`) and caches success in a per-terminal timestamp (default 5 minutes).
5. It logs the request (allowed or denied) to syslog/journal (`/var/log/secure` on RHEL).
6. It sets up the target environment (`env_reset`, `secure_path`) and `execve()`s the command as the target user.

Because the decision is made **per command line**, a rule like `alice ALL=(root) /usr/bin/systemctl restart httpd` allows exactly that command with exactly those arguments.

## 3. The sudoers Grammar **[RHCSA Core]**

```
WHO      WHERE = (AS_USER:AS_GROUP)  [TAGS:]  WHAT
alice    ALL   = (ALL:ALL)                    ALL
%wheel   ALL   = (ALL)                        ALL          ← RHEL default: group members, any host, any user, any command
%ops     ALL   = (root)              NOPASSWD: /usr/bin/systemctl restart httpd, /usr/bin/journalctl
```

| Field | Meaning | Examples |
|---|---|---|
| **WHO** | User, `%group`, `#UID`, or a `User_Alias` | `alice`, `%wheel`, `%sysadmin`, `ADMINS` |
| **WHERE** | Host the rule applies to (useful when one sudoers file is shared by many hosts) | `ALL`, `web01`, `Host_Alias` |
| **AS** | Target user (and optionally group) for `-u`/`-g` | `(ALL)`, `(root)`, `(postgres)`, `(ALL:ALL)` |
| **TAGS** | Modifiers | `NOPASSWD:`, `PASSWD:`, `NOEXEC:`, `SETENV:` |
| **WHAT** | Comma-separated commands with **full paths**, or `ALL` | `/usr/bin/systemctl`, `/usr/sbin/useradd`, `ALL` |

**Command matching rules:**

| You write | Allows |
|---|---|
| `/usr/bin/systemctl` | `systemctl` with **any** arguments |
| `/usr/bin/systemctl restart httpd` | Only that exact argument list |
| `/usr/bin/passwd ""` | `passwd` with **no** arguments only |
| `/usr/bin/passwd [a-z]*` | Wildcards in arguments: easy to get wrong, avoid for security-sensitive rules |
| `!/usr/bin/passwd root` | Negation. Weak as a security control (copy the binary, use a shell) |
| `sudoedit /etc/httpd/conf/httpd.conf` | Edit that file safely as root (see §6) |

### Aliases

```
User_Alias  WEBADMINS = alice, bob, %webteam
Runas_Alias DBUSERS   = postgres, mysql
Host_Alias  WEBHOSTS  = web01, web02, 192.168.10.0/24
Cmnd_Alias  WEBCMDS   = /usr/bin/systemctl restart httpd, /usr/bin/systemctl reload httpd, /usr/sbin/apachectl configtest

WEBADMINS   WEBHOSTS = (root) NOPASSWD: WEBCMDS
%dba        ALL      = (DBUSERS) ALL
```

Alias names must be **UPPERCASE** (letters, digits, underscore).

### Defaults

```
Defaults    env_reset                                   # RHEL default: clean environment
Defaults    secure_path = /sbin:/bin:/usr/sbin:/usr/bin # PATH used for commands run via sudo (RHEL default)
Defaults    timestamp_timeout=10                        # minutes a successful authentication is cached
Defaults:alice  !requiretty                            # per-user Defaults
Defaults    logfile=/var/log/sudo.log                   # extra log file (syslog logging continues)
Defaults    use_pty                                     # run commands in a pseudo-terminal (hardening)
```

## 4. Managing the Policy Safely

### 4.1 Always use `visudo`

`visudo` locks the file, edits a temporary copy, and **refuses to save a syntax error**. A broken `/etc/sudoers` disables `sudo` for everyone, which on RHEL 10 (root disabled) can lock you out of the system.

```bash
sudo visudo                                   # edit /etc/sudoers
sudo visudo -f /etc/sudoers.d/sysadmin        # create/edit a drop-in (preferred)
sudo visudo -c                                # check /etc/sudoers AND all included files
sudo visudo -cf /etc/sudoers.d/sysadmin       # check one file
EDITOR=vim sudo -E visudo                     # choose the editor (or set EDITOR/VISUAL)
```

If `visudo` reports an error: press `e` to re-edit, `x` to exit without saving, or `Q` to save anyway (**never**).

### 4.2 Drop-in files: `/etc/sudoers.d/`

Prefer one file per role over editing `/etc/sudoers` (package updates may replace that file; drop-ins are easy to audit and remove).

| Rule | Why |
|---|---|
| Files whose name **contains a `.` or ends in `~`** are **ignored** | Prevents editor backups and `rpmnew` files from being loaded. `sysadmin` works; `sysadmin.conf` is **silently ignored** |
| Owned by root, mode **0440** (visudo does this) | sudo refuses files that are world-writable or not owned by root |
| Files are read in lexical order | Later files can override earlier rules (last match wins) |

Writing a drop-in non-interactively (scripts, exam speed), with validation before it becomes active:

```bash
echo '%sysadmin ALL=(ALL) NOPASSWD: ALL' > /tmp/sysadmin
visudo -cf /tmp/sysadmin && install -m 0440 -o root -g root /tmp/sysadmin /etc/sudoers.d/sysadmin
```

### 4.3 Verifying rules

```bash
sudo -l                        # what may I run? (asks for my password unless NOPASSWD)
sudo -l -U alice               # (as root) what may alice run?
sudo -ll -U alice              # long format: which rule, which options
sudo -u alice sudo -l          # (as root) test from alice's point of view
su - alice -c 'sudo -n true' ; echo $?   # -n: never prompt; 0 = allowed without password
```

Example `sudo -l -U alice` output (abridged):

```
User alice may run the following commands on server1:
    (root) NOPASSWD: /usr/bin/systemctl restart httpd, /usr/bin/journalctl
```

## 5. Using sudo

| Command | Effect |
|---|---|
| `sudo CMD` | Run CMD as root |
| `sudo -u postgres psql` | Run as another user |
| `sudo -g wheel CMD` | Run with a different primary group |
| `sudo -i` | Root **login** shell (root's environment, `/root`, profile files) |
| `sudo -s` | Root shell keeping much of your environment |
| `sudo -e FILE` / `sudoedit FILE` | Edit a root-owned file with your editor, as yourself (§6) |
| `sudo -v` / `sudo -k` | Refresh / discard the cached authentication |
| `sudo !!` | Re-run the previous command with sudo |

**Redirection pitfall:** `sudo echo x > /etc/file` fails, because **your** shell opens `/etc/file` before sudo runs. Use `echo x | sudo tee /etc/file` or `sudo sh -c 'echo x > /etc/file'` (see [redirection](../files-and-text-processing/io-redirection-and-pipes.md)).

### `su` vs `sudo -i`

| | `su -` | `sudo -i` |
|---|---|---|
| Password | Target's (root's) | Yours |
| Works with root disabled (RHEL 10 default)? | **No** | Yes (if sudoers allows) |
| Logging | "su: session opened for root by alice" | Every sudo invocation logged with the real user |
| Restricting who may use it | `pam_wheel` in `/etc/pam.d/su` | sudoers rules |

## 6. Least Privilege & Escape Risks **[Production Practice]**

A rule that allows a program which can **spawn a shell** grants full root, whatever the rule looks like:

| "Harmless-looking" rule | Why it's root | Safer alternative |
|---|---|---|
| `/usr/bin/vi /etc/hosts` | `:!sh` inside vi | `sudoedit /etc/hosts` |
| `/usr/bin/less /var/log/messages` | `!sh` inside less | Add the user to a log-reading group, or `journalctl` with `systemd-journal` group |
| `/usr/bin/find` | `find / -exec /bin/sh \;` | Specific scripted command |
| `/usr/bin/tar`, `/usr/bin/awk`, `/usr/bin/python3`, `/usr/bin/bash` | Command execution built in | Wrap the task in a root-owned script with fixed arguments |
| `/usr/bin/systemctl` (any args) | `systemctl edit` → write any unit → root | List exact subcommands and units |
| `/usr/bin/cp` (any args) | Overwrite `/etc/sudoers.d/x` or `/etc/shadow` | Specific paths only, or a script |

`sudoedit` works differently: sudo copies the file to a temporary file owned by **you**, runs your editor **as you**, then copies it back as root. Your editor never runs with root privileges.

`NOEXEC:` blocks dynamically linked programs from exec'ing children (it uses an `LD_PRELOAD` shim), which defeats many shell escapes but not all. Treat it as a mitigation, not a guarantee.

Wrapper-script pattern for delegated tasks:

```bash
install -m 0755 -o root -g root restart-web.sh /usr/local/sbin/restart-web.sh   # root-owned, not writable by others
echo '%webteam ALL=(root) NOPASSWD: /usr/local/sbin/restart-web.sh' > /tmp/webteam
visudo -cf /tmp/webteam && install -m 0440 /tmp/webteam /etc/sudoers.d/webteam
```

If the script or any directory in its path is writable by the delegated user, they can replace it and become root.

## 7. Logging & Auditing

```bash
sudo grep 'sudo:' /var/log/secure | tail     # alice : TTY=pts/0 ; PWD=/home/alice ; USER=root ; COMMAND=/usr/bin/dnf update
journalctl _COMM=sudo --since today          # same, from the journal
journalctl _COMM=sudo | grep -i 'incorrect password\|NOT in sudoers\|command not allowed'
```

Denied attempts appear as `alice : command not allowed ; … COMMAND=…` or `alice is not in the sudoers file`. For tamper-resistant, kernel-level records of privileged commands, use [auditd](../firewall-and-selinux/auditd.md); for full session recording, `tlog` **[Advanced]**.

## 8. polkit (Brief) **[Interview Knowledge]**

Many admin tools (`systemctl`, `nmcli`, `timedatectl`, `hostnamectl`, Cockpit) talk over **D-Bus** to privileged daemons. Those daemons ask **polkit** whether the caller may perform the action. RHEL's default rules treat members of **`wheel`** as administrators, which is why a wheel user running `systemctl restart httpd` *without* sudo gets a password prompt instead of "Access denied".

```bash
pkaction | head                          # registered actions
ls /usr/share/polkit-1/rules.d/ /etc/polkit-1/rules.d/   # vendor rules / local rules (JavaScript)
pkexec /usr/sbin/visudo                  # run a program as root via polkit (needs an admin identity + agent)
```

## 9. RHCSA Exam Patterns **[RHCSA Core]**

```bash
# "Members of group sysadmin may run any command as root"
groupadd sysadmin 2>/dev/null ; usermod -aG sysadmin natasha
echo '%sysadmin ALL=(ALL) ALL' > /etc/sudoers.d/sysadmin ; chmod 0440 /etc/sudoers.d/sysadmin
visudo -c

# "… without being asked for a password"
echo '%sysadmin ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/sysadmin ; visudo -c

# "User harry may only run useradd and passwd as root"
echo 'harry ALL=(root) /usr/sbin/useradd, /usr/bin/passwd' > /etc/sudoers.d/harry ; visudo -c

# "Make user alice an administrator" (the RHEL way)
usermod -aG wheel alice

# Verify, as the user, in a NEW login (group membership is read at login)
su - natasha -c 'sudo -l'
```

- Find binary paths with `command -v useradd` (`/usr/sbin/useradd`); sudoers needs absolute paths.
- Never name the drop-in with a dot (`sysadmin.conf` is ignored, so the task silently fails).
- `visudo -c` must print `parsed OK` for every file before you move on.

## 10. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `alice is not in the sudoers file. This incident will be reported.` | No matching rule | Add a rule or `usermod -aG wheel alice`, then **re-login** |
| Added to wheel, still denied | Group list fixed at login | Log out/in, `su - alice`, or `newgrp wheel` |
| `Sorry, user alice is not allowed to execute '/usr/bin/vim /etc/hosts' as root` | Command/arguments don't match | `sudo -l`; check paths and argument list |
| Rule in `/etc/sudoers.d/ops.conf` has no effect | Filename contains `.` | Rename to `ops` |
| `/etc/sudoers.d/x is world writable` / `… is owned by uid 1000, should be 0` | Wrong mode/owner | `chown root:root`, `chmod 0440` |
| NOPASSWD rule still asks for a password | A **later** matching rule (e.g., `%wheel ALL=(ALL) ALL`) wins | Move your rule after it (later file name) or adjust order |
| `sudo: command not found` for `/usr/local/bin/x` | `secure_path` doesn't include `/usr/local/bin` | Use the full path, or extend `secure_path` deliberately |
| `>>> /etc/sudoers: syntax error near line N <<<` and nobody can sudo | File edited without visudo | `pkexec visudo` (if polkit agent available), or boot with `rd.break` and fix it ([boot recovery](../boot-systemd-and-kernel/boot-recovery.md)) |
| `sudo: a terminal is required to read the password` | No TTY (scripts, `ssh host sudo …`) | `ssh -t`, or a narrowly scoped `NOPASSWD` rule for automation |

## 11. Interview Questions

| Question | Answer |
|---|---|
| How does sudo get root privileges? | It's a set-UID root binary; it evaluates the sudoers policy and authenticates the caller via PAM before exec'ing the command as the target user. |
| sudo vs su? | sudo authenticates **you** and applies per-command policy with per-user logging; su needs the **target's** password and gives a full shell. |
| Two rules match a command; which applies? | The **last** matching rule. |
| Why are `/etc/sudoers.d/*.conf` files ignored? | sudo skips drop-in names containing `.` or ending in `~`. |
| How can a narrow rule still give full root? | If the allowed program can run commands or write arbitrary files (vi, less, find, tar, systemctl edit, cp). Use sudoedit or wrapper scripts. |
| What's sudoedit's advantage? | The editor runs as you on a temporary copy; only the final copy-back runs as root. |
| How do you audit who ran what as root? | `/var/log/secure` / `journalctl _COMM=sudo`; auditd for tamper-resistant logs; tlog for session recording. |
| Why does a wheel user get a password prompt from `systemctl restart` without sudo? | polkit authorizes the D-Bus request and treats wheel members as admins. |

## 12. Lab (verification included)

1. Create `ops` group and users `ann` (in ops) and `ben` (not in ops).
2. Allow `%ops` to restart and check the status of `chronyd` without a password, nothing else.
3. Verify: `su - ann -c 'sudo -n systemctl restart chronyd; echo rc=$?'` → `rc=0`; `su - ann -c 'sudo -n dnf -y install zsh; echo rc=$?'` → `sudo: a password is required`, `rc=1` (`-n` never prompts, so any command outside the NOPASSWD rule fails this way); as root, `sudo -l -U ben` → `User ben is not allowed to run sudo on <host>.`
4. Rename the file to `ops.conf` and repeat step 3. Now even `chronyd` fails with `a password is required`: the file is ignored. Then `chmod 0666` the correctly named file and watch sudo refuse it (`… is world writable`). Restore mode 0440.
5. Read the denials in `/var/log/secure`.

Solution for step 2: `%ops ALL=(root) NOPASSWD: /usr/bin/systemctl restart chronyd, /usr/bin/systemctl status chronyd` in `/etc/sudoers.d/ops`, mode 0440, `visudo -c`.

## 13. Quick Revision

```
WHO WHERE=(AS:ASGROUP) [NOPASSWD:] /full/path/cmd args, …   · %group · ALL · last match wins
visudo · visudo -f /etc/sudoers.d/NAME · visudo -c · visudo -cf FILE · drop-in names: no "." no "~" · 0440 root:root
%wheel ALL=(ALL) ALL (RHEL default) · usermod -aG wheel U (re-login) · sudo -l [-U user] · sudo -i/-s/-u/-e/-k
User_Alias Runas_Alias Host_Alias Cmnd_Alias (UPPERCASE) · Defaults secure_path / timestamp_timeout / logfile
escapes: vi less find tar awk systemctl → sudoedit / wrapper script · logs: /var/log/secure, journalctl _COMM=sudo
```

## 14. Cross-References

- [Local users](local-users.md) · [Groups](groups.md) · [PAM & authselect (pam_wheel for su)](pam-and-authselect.md)
- [Login & switching users](../networking-and-ssh/ssh-remote-access.md#4-logging-in-and-switching-users-rhcsa-core) · [SSH hardening (PermitRootLogin)](../networking-and-ssh/ssh-server-hardening.md)
- [Special permissions (set-UID, which sudo itself uses)](special-permissions-and-acls.md) · [Processes & system calls (credentials, capabilities)](../processes-and-resource-management/processes-and-system-calls.md)
- [auditd](../firewall-and-selinux/auditd.md) · [Boot recovery (fixing a broken sudoers)](../boot-systemd-and-kernel/boot-recovery.md)
