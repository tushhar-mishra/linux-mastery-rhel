# Local User Accounts

> **Objective:** *Create, delete, and modify local user accounts* · *Log in and switch users* **[RHCSA Core]**
> **Related:** [Passwords & aging](passwords-and-aging.md) · [Groups](groups.md) · [Shell startup files](shell-startup-files.md) · [Login & switching users](../networking-and-ssh/ssh-remote-access.md#4-logging-in-and-switching-users-rhcsa-core) · [sudo & privileged access](sudo-and-privileged-access.md) · [Central identity (NSS/SSSD)](central-identity-nss-sssd.md)

## 1. Overview

Every process runs as a **user** (identified by a numeric **UID**) and a primary **group** (GID). Local accounts live in `/etc/passwd` (account info), `/etc/shadow` (password hashes and aging), `/etc/group` and `/etc/gshadow` (groups). The kernel only cares about numbers. Names are looked up through NSS (`/etc/nsswitch.conf`), so `getent` also shows users from LDAP/IdM (SSSD), not just local files.

## 2. Key Concepts

### 2.1 `/etc/passwd` fields

```
alice:x:1001:1001:Alice Admin:/home/alice:/bin/bash
  1   2  3    4       5            6          7
```

| # | Field | Notes |
|---|---|---|
| 1 | Username | Case-sensitive; keep lowercase |
| 2 | Password placeholder | `x` = hash is in `/etc/shadow` |
| 3 | UID | `0` = root (any account with UID 0 is root) |
| 4 | Primary GID | Group assigned to new files |
| 5 | GECOS / comment | Full name, set with `-c` |
| 6 | Home directory | |
| 7 | Login shell | `/bin/bash`, or `/sbin/nologin` for no interactive login |

File permissions: `/etc/passwd` is `644` (world-readable); `/etc/shadow` is `000` on RHEL (root only, via its capabilities).

### 2.2 UID ranges (RHEL defaults, from `/etc/login.defs`)

| Range | Use |
|---|---|
| `0` | root |
| `1–200` | Static system accounts (assigned by packages) |
| `201–999` | Dynamic system accounts (`useradd -r`) |
| `1000–60000` | Regular users (`UID_MIN`/`UID_MAX`) |
| `65534` | `nobody` |

```bash
grep -E '^(SYS_)?(UID|GID)_(MIN|MAX)' /etc/login.defs
```

### 2.3 User Private Groups (UPG)

On RHEL, `useradd alice` also creates a group `alice` with the same number (`USERGROUPS_ENAB yes`) and makes it alice's **primary group**. Because each user has a private group, a group-writable umask (`0002`) would be safe, and older RHEL releases gave regular users `0002`. **RHEL 10 gives everyone `0022` by default** (verified: `pam_umask` reads `UMASK 022` from `/etc/login.defs`; `/etc/profile` no longer switches users to `002`). Collaboration therefore relies on SGID directories plus default ACLs or an explicit umask (see [file permissions & umask](file-permissions.md#33-umask-default-permissions-rhcsa-core)).

### 2.4 Where `useradd` defaults come from

| Source | Controls |
|---|---|
| `/etc/login.defs` | UID/GID ranges, `CREATE_HOME`, password aging defaults, `UMASK`, `ENCRYPT_METHOD` |
| `/etc/default/useradd` (`useradd -D`) | Default shell (`/bin/bash`), home base (`/home`), `SKEL`, inactive/expire defaults |
| `/etc/skel/` | Files copied into each **new** home directory |

On RHEL `CREATE_HOME yes`, so `-m` is the default and `-s /bin/bash` is redundant. Both are harmless to type.

## 3. Commands & Syntax

### 3.1 Create: `useradd`

| Option | Meaning |
|---|---|
| `-u UID` | Specific UID |
| `-g GROUP` | Primary group (must exist) |
| `-G g1,g2` | Supplementary groups |
| `-c "text"` | Comment (GECOS) |
| `-d DIR` | Home directory path (with `-m` to create it) |
| `-m` / `-M` | Create / don't create the home directory |
| `-s SHELL` | Login shell |
| `-r` | System account (UID < 1000, no home by default) |
| `-e YYYY-MM-DD` | Account expiry date |
| `-k DIR` | Alternative skeleton directory |
| `-N` | Don't create a private group |

```bash
sudo useradd -c "Diana Prince" diana
sudo useradd -u 2001 -G wheel,devs -c "Clark Kent" clark
sudo useradd -s /sbin/nologin svc_backup        # service/FTP-style account, no shell login
sudo useradd -r -s /sbin/nologin -d /var/lib/app appsvc   # system account
sudo passwd diana                               # account is unusable until a password is set (`!` in shadow on RHEL 10; `!!` on RHEL 9)
```

### 3.2 Modify: `usermod`

| Option | Meaning |
|---|---|
| `-aG g1,g2` | **Append** supplementary groups (⚠️ `-G` without `-a` **replaces** them) |
| `-g GROUP` | Change the primary group |
| `-s SHELL` | Change the login shell |
| `-c "text"` | Change the comment |
| `-d DIR -m` | Change the home and **move** its contents |
| `-l NEWNAME` | Rename the login (home dir not renamed unless `-d … -m`) |
| `-u UID` | Change the UID (files in the home dir are updated; files elsewhere are not) |
| `-e YYYY-MM-DD` / `-e ""` | Set / remove account expiry |
| `-L` / `-U` | Lock / unlock the password ([passwords note](passwords-and-aging.md)) |

### 3.3 Delete: `userdel`

```bash
sudo userdel alice          # remove account; KEEP home and mail spool
sudo userdel -r alice       # also remove /home/alice and /var/spool/mail/alice
sudo find / -xdev -nouser 2>/dev/null   # files elsewhere now owned by a bare UID
```

> ⚠️ `userdel -r` is irreversible. Files outside the home directory keep the old UID; a future user given that UID would **inherit** them. Find them with `find / -nouser` and reassign or delete.

### 3.4 Inspect

```bash
id alice                 # uid=1001(alice) gid=1001(alice) groups=1001(alice),10(wheel)
id -un; id -u; id -Gn    # name / UID / group names of the current user
getent passwd alice      # works for local AND directory (SSSD/LDAP) users
grep '^alice:' /etc/passwd          # exact match (plain "grep alice" matches substrings)
sudo grep '^alice:' /etc/shadow     # shadow requires root
whoami; who; w; last; lastlog -u alice
```

### 3.5 Switching users (summary)

| Command | Environment | Password asked |
|---|---|---|
| `su alice` | Keeps the caller's environment (non-login) | alice's (none if you're root) |
| `su - alice` | Clean **login** environment, home dir, profile files | alice's (none if you're root) |
| `sudo -i` | Root login shell | **Your** password (needs sudo rights) |
| `sudo -u alice cmd` | Run one command as alice | Your password |

Details: [login & switching users](../networking-and-ssh/ssh-remote-access.md#4-logging-in-and-switching-users-rhcsa-core) and [sudo & privileged access](sudo-and-privileged-access.md).

## 4. RHCSA Exam Focus **[RHCSA Core]**

Typical tasks and patterns:

```bash
useradd -u 3000 harry                         # specific UID
useradd -G sysadmin natasha                   # supplementary group at creation
usermod -aG sysadmin sarah                    # add to a group later (never forget -a)
useradd -s /sbin/nologin sarah                # "no interactive shell"
echo 'Secr3t!Pass' | passwd --stdin harry     # set a password non-interactively (RHEL)
id harry; getent passwd harry                 # verify UID, groups, shell
```

- Read the task for **exact** UIDs, group names, shells and passwords.
- The account needs a password before anyone can log in with one.
- Verify with `su - user`: right home, right shell, right groups.

## 5. Production Practices **[Production Practice]**

- Prefer central identity (IdM/LDAP via SSSD) for fleets; local accounts are for break-glass and service users.
- Service accounts: `-r -s /sbin/nologin`, no password, own the minimum files.
- Never reuse UIDs of deleted users without cleaning up their files.
- Use `/etc/skel` for standard dotfiles; remember it only affects **new** users.
- Audit regularly: UID-0 accounts (`awk -F: '$3==0' /etc/passwd`), empty passwords, unexpected shells.

## 6. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `useradd: Permission denied` / `cannot lock /etc/passwd` | Not root | `sudo useradd …` |
| `useradd: user 'x' already exists` / `UID … is not unique` | Name or UID in use | `getent passwd x`; choose another |
| User can't log in: "This account is currently not available" | Shell is `/sbin/nologin` | `usermod -s /bin/bash user` if intended |
| User lost supplementary groups | `usermod -G` without `-a` | Re-add: `usermod -aG g1,g2 user` |
| Home dir missing | `-M`, or `CREATE_HOME no` | `mkhomedir_helper user` or create + `cp -a /etc/skel/. ~user`, `chown -R` |
| Files show a number instead of a name | Owner deleted | `find / -nouser`; `chown` |
| `su: Authentication failure` | Wrong password, locked/expired account, or never set (`!`/`!!` in shadow) | `passwd -S user`; `chage -l user` |

## 7. Interview Questions

| Question | Answer |
|---|---|
| What are the 7 fields of `/etc/passwd`? | name, password placeholder, UID, GID, GECOS, home, shell. |
| Why is the hash not in `/etc/passwd`? | `/etc/passwd` must be world-readable for name lookups; hashes live in root-only `/etc/shadow`. |
| What makes an account root? | UID 0, regardless of name. |
| `usermod -G` vs `usermod -aG`? | `-G` replaces all supplementary groups; `-aG` appends. |
| What is a user private group? | A group with the same name as the user, used as their primary group. |
| `getent passwd` vs `cat /etc/passwd`? | `getent` uses NSS, so it includes directory users (SSSD/LDAP). |
| What happens to files when a user is deleted? | They keep the numeric UID; find them with `find / -nouser`. |

## 8. Practice Exercises (with Solutions)

| # | Task | Command | Note |
|---|---|---|---|
| P1-1–3 | Who am I / who's on / activity | `whoami` · `who` · `w` | |
| P1-4 | Name and UID | `id -un; id -u` | `&&` works too |
| P1-5–6 | Switch users | `su jordan` vs `su - jordan` | `-` gives a login environment |
| P2-1 | User with comment | `sudo useradd -c "Diana Prince" diana` | `-m` is default on RHEL |
| P2-2 | User with bash + comment | `sudo useradd -s /bin/bash -c "Clark Kent" clark` | `-s /bin/bash` is the default |
| P2-3 | Verify | `getent passwd diana` · `sudo grep '^clark:' /etc/shadow` · `getent group clark` | Shadow needs root; anchor greps |
| P2-4 | Homes exist | `ls -ld /home/diana /home/clark` | |
| P2-5–6 | Shell `/usr/bin/uptime` | `sudo useradd -s /usr/bin/uptime timer` | After a password is set, login prints uptime and exits. Not in `/etc/shells`, so tools that check it (e.g. `chsh`) reject it; `/sbin/nologin` is the RHEL convention for restricted accounts |
| P2-7–8 | Skeleton file | `sudo cp greeting.txt /etc/skel/` then `useradd testuser; ls -a ~testuser; userdel -r testuser` | Affects only users created afterwards |
| P2-9 | Change shell | `sudo usermod -s /bin/bash diana` | |
| P2-10–11 | Non-root vs sudo | `useradd newbie` fails; `sudo useradd newbie` works | |

## 9. Quick Revision

```bash
useradd [-u UID] [-g pri] [-G g1,g2] [-c "x"] [-s shell] [-d dir -m] [-r] [-e date] user
usermod -aG g user | -s shell | -c | -l new | -d dir -m | -u | -e | -L/-U
userdel [-r] user ; find / -nouser
id / getent passwd / grep '^user:' ; /etc/{passwd,shadow,group,gshadow} ; /etc/skel ; useradd -D
```

## 10. Cross-References

- [Passwords & aging](passwords-and-aging.md)
- [Groups](groups.md)
- [Shell startup files (`/etc/skel` contents)](shell-startup-files.md)
- [File permissions & umask](file-permissions.md)
- [sudo & privileged access](sudo-and-privileged-access.md)
- [Shell basics (`/sbin/nologin`)](../shell-and-command-line/shell-basics-and-command-syntax.md)
- [Finding files (`-nouser`)](../files-and-text-processing/finding-files.md)
