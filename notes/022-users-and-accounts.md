# 022 · Users and Accounts: /etc/passwd, useradd, usermod, userdel

> **You need first:** [021 · Archiving and compression](021-archiving-and-compression.md)
> **Next:** [023 · Passwords and aging](023-passwords-and-aging.md)

---

## What it is

A **user account** is an identity the system uses to decide who owns files and who may do what.

- **UID** (User IDentifier): the **number** behind a user name. The kernel only knows numbers; names are just labels for humans.
- **GID** (Group IDentifier): the number behind a group name (topic 024).
- **root**: the all-powerful administrator account. **Any account with UID 0 is root**, whatever its name.
- **System account** (service account): a non-human account that runs a service (like `chrony` or `nginx`). It usually can't log in.
- **Home directory**: a user's personal folder, normally `/home/<name>`.
- **Login shell**: the program started when the user logs in (topic 003).

Local accounts are stored in four text files:

| File | Contents | Who can read it |
|---|---|---|
| `/etc/passwd` | Account details (name, UID, GID, home, shell) | Everyone |
| `/etc/shadow` | Password hashes and password aging (topic 023) | root only |
| `/etc/group` | Groups and their members (topic 024) | Everyone |
| `/etc/gshadow` | Group passwords and group admins | root only |

## Why it exists

Linux is **multi-user**: many people and services share one machine. Accounts give:
- **Separation:** Alice can't read Bob's files or kill his programs.
- **Least privilege:** a web server runs as the unprivileged `nginx` user, so if it's hacked, the attacker doesn't get root.
- **Accountability:** logs record which user did what.

Every running program (process) runs **as** a user. Every file is **owned by** a user. Permissions (topic 026) compare the two.

## Analogy

An account is an **employee badge**. The kernel doesn't read the name printed on it; it reads the **badge number** (UID). Two badges with the same number are the same person to the security system. A badge with number 0 opens every door (root). Service accounts are **badges for robots**: they open only the rooms the robot works in, and you can't log in with them.

## How it works inside

### `/etc/passwd`, field by field

```
alice:x:1001:1001:Alice Admin:/home/alice:/bin/bash
  1   2  3    4       5            6          7
```

| # | Field | Notes |
|---|---|---|
| 1 | User name | Case-sensitive; keep it lowercase |
| 2 | Password placeholder | `x` means "the hash is in `/etc/shadow`" |
| 3 | UID | `0` = root |
| 4 | Primary GID | The group that new files get |
| 5 | GECOS / comment | Usually the full name (the name comes from an old system called GECOS) |
| 6 | Home directory | |
| 7 | Login shell | `/bin/bash`; or `/sbin/nologin` = no interactive login |

`/etc/passwd` must be readable by everyone, because every `ls -l` turns UIDs into names. That's why password hashes moved out into the root-only `/etc/shadow`.

### UID ranges on RHEL (from `/etc/login.defs`)

| Range | Used for |
|---|---|
| `0` | root |
| `1–200` | Fixed system accounts created by packages |
| `201–999` | System accounts created on demand (`useradd -r`) |
| `1000–60000` | Regular human users |
| `65534` | `nobody`: an account with no privileges, used by NFS and some services |

Ubuntu/Debian use the same idea: system accounts below 1000 and humans from 1000.

### How a name becomes a number: NSS

Programs don't open `/etc/passwd` directly. They ask glibc "who is alice?", and glibc follows **NSS** (Name Service Switch). The file `/etc/nsswitch.conf` lists where to look: local files, then maybe a central directory such as LDAP or Active Directory through a service called SSSD (topic 030). `getent passwd alice` asks NSS exactly the way programs do, so it also shows directory users that aren't in `/etc/passwd`.

### What `useradd` does behind the scenes

1. Reads defaults from `/etc/login.defs` (UID ranges, whether to create a home, password aging, hash method) and `/etc/default/useradd` (default shell, home base, skeleton directory).
2. Locks the account files, picks the next free UID, and adds a line to `/etc/passwd` and `/etc/shadow`.
3. On RHEL, creates a **User Private Group** (UPG): a group with the same name and number as the user, which becomes the user's primary group.
4. Creates `/home/<name>` and copies the files from **`/etc/skel/`** into it (default `.bashrc`, `.bash_profile`, …).
5. Leaves the password **locked** (`!` in `/etc/shadow`) until you set one with `passwd`.

**Ubuntu/Debian difference:** low-level `useradd` there does **not** create a home directory unless you pass `-m`, and the default shell is `/bin/sh`. Debian/Ubuntu admins usually use the friendlier **`adduser`** script, which asks questions and does everything.

## Commands

### Create

```bash
sudo useradd -c "Diana Prince" diana
sudo passwd diana
getent passwd diana
```
```
New password:
Retype new password:
passwd: password updated successfully
diana:x:1001:1001:Diana Prince:/home/diana:/bin/bash
```

| `useradd` option | Meaning |
|---|---|
| `-u UID` | Choose the UID |
| `-g GROUP` | Primary group (must already exist) |
| `-G g1,g2` | Extra (supplementary) groups |
| `-c "text"` | Comment / full name |
| `-d DIR` | Home directory path |
| `-m` / `-M` | Create / don't create the home directory |
| `-s SHELL` | Login shell |
| `-r` | System account (UID below 1000, no home by default) |
| `-e YYYY-MM-DD` | Account expires on this date |
| `-k DIR` | Use a different skeleton directory |
| `-N` | Don't create a private group |

```bash
sudo useradd -u 2001 -G wheel -c "Clark Kent" clark      # specific UID, admin group (topic 028)
sudo useradd -r -s /sbin/nologin -d /var/lib/myapp myapp  # service account
echo 'Secr3t!Pass' | sudo passwd --stdin clark            # set a password non-interactively (RHEL only)
echo 'clark:Secr3t!Pass' | sudo chpasswd                  # same, works on Ubuntu too
```
- A system account made with `-r` gets a UID below 1000 (here `myapp:x:993:990::/var/lib/myapp:/sbin/nologin`), and **no home directory is created**, even though `-d` names one. Add `-m` if the service needs it, or let its systemd unit create it (`StateDirectory=`, topic 098).

### Inspect

```bash
id clark
```
```
uid=2001(clark) gid=2001(clark) groups=2001(clark),10(wheel)
```
- `uid` and `gid` are the user and primary group. `groups` lists all groups. Here clark is in `wheel`, the admin group.

```bash
id -un ; id -u ; id -Gn
```
```
alice
1000
alice wheel
```

```bash
grep '^clark:' /etc/passwd
sudo grep '^clark:' /etc/shadow
```
- Anchor with `^name:`; plain `grep clark` would also match `clarkson`.

```bash
awk -F: '$3==0 {print $1}' /etc/passwd
```
```
root
```
- **Security check:** any account other than root with UID 0 is a backdoor.

```bash
grep -E '^(SYS_)?(UID|GID)_(MIN|MAX)|^CREATE_HOME|^UMASK' /etc/login.defs
useradd -D
```
```
UID_MIN                  1000
UID_MAX                 60000
SYS_UID_MIN               201
SYS_UID_MAX               999
...
CREATE_HOME     yes
UMASK           022
GROUP=100
GROUPS=
HOME=/home
INACTIVE=-1
EXPIRE=
SHELL=/bin/bash
SKEL=/etc/skel
USRSKEL=/usr/etc/skel
CREATE_MAIL_SPOOL=yes
LOG_INIT=yes
```
- Where the defaults come from.

### Modify

| `usermod` option | Meaning |
|---|---|
| `-aG g1,g2` | **Append** to extra groups. ⚠️ `-G` **without** `-a` **replaces** all extra groups |
| `-g GROUP` | Change the primary group |
| `-s SHELL` | Change the login shell |
| `-c "text"` | Change the comment |
| `-d DIR -m` | Change the home directory and **move** the contents |
| `-l NEWNAME` | Rename the login |
| `-u UID` | Change the UID (files in the home are updated; files elsewhere are not) |
| `-e DATE` / `-e ""` | Set / remove account expiry |
| `-L` / `-U` | Lock / unlock the password (topic 023) |

```bash
sudo usermod -aG wheel diana       # make diana an admin (re-login needed, topic 024)
sudo usermod -s /sbin/nologin svc1 # block interactive login
```

```bash
sudo su - svc1
```
```
This account is currently not available.
```
- That's what `/sbin/nologin` prints.

### Delete

```bash
sudo userdel diana          # remove the account; KEEP the home directory
sudo userdel -r diana       # also delete /home/diana and the mail spool
sudo find / -xdev -nouser 2>/dev/null
```
- `userdel -r` can't be undone. Files **outside** the home keep the old UID number. If a new user later gets that UID, they **inherit** those files. Find and fix them with `find / -nouser`.

### Switching users

| Command | Environment you get | Whose password |
|---|---|---|
| `su alice` | Keeps your current environment (non-login shell) | alice's (none if you're root) |
| `su - alice` | A fresh **login** environment: alice's home, PATH and startup files | alice's (none if you're root) |
| `sudo -i` | A root login shell | **Your own** (if you're allowed sudo, topic 028) |
| `sudo -u alice cmd` | Run one command as alice | Your own |

On RHEL 10 the root password is disabled by default, so `su -` to root fails. Use `sudo -i`.

### Login records

```bash
last -5
lastlog -u alice
```
```
alice    pts/0        192.168.56.1     Mon Nov 16 09:12   still logged in
reboot   system boot  6.12.0-55.el10.x Mon Nov 16 08:50   still running
...
Username         Port     From             Latest
alice            pts/0    192.168.56.1     Mon Nov 16 09:12:41 +0000 2026
```
- `last` reads `/var/log/wtmp` (the login history); `lastlog` shows each user's most recent login. On newer systems `lastlog2` may replace `lastlog`.

### Try it
1. Create `testuser` with UID 3000 and comment "Test User". Check it with `id` and `getent`.
2. Put a file `welcome.txt` in `/etc/skel`, create `newbie`, and confirm the file appears in `/home/newbie`.
3. Add `testuser` to `wheel` with `-aG`, then (on purpose) run `usermod -G users testuser` and see that `wheel` is gone.
4. Delete both users with `userdel -r` and run `find / -xdev -nouser`.

## Where you'll use it

- **Service accounts:** every daemon you install (nginx, postgres, prometheus) should run as its own `-r -s /sbin/nologin` user. Containers do the same: `USER 1001` in a Dockerfile. Kubernetes `runAsUser: 1001` sets the **UID number**, which is why the number (not the name) is what matters.
- **UID mismatches:** NFS shares (topic 079) and container volumes compare **numbers**. If UID 1001 is `alice` on one host and `bob` on another, files show the wrong owner. Keep UIDs consistent, or use central identity (topic 030).
- **Onboarding/offboarding:** lock or expire accounts on the day someone leaves (topic 023); clean up `-nouser` files.
- **Security audits:** UID-0 accounts, accounts with real shells that shouldn't have them, stale accounts (`lastlog`).

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `useradd: Permission denied` or `cannot lock /etc/passwd` | Not root, or another tool holds the lock | `sudo useradd …`; wait and retry |
| `user 'x' already exists` / `UID … is not unique` | Name or UID is taken | `getent passwd x`; pick another |
| "This account is currently not available." | The shell is `/sbin/nologin` | `usermod -s /bin/bash user`, if that's intended |
| A user suddenly lost group access | `usermod -G` without `-a` | Re-add: `usermod -aG g1,g2 user` |
| No home directory (common on Ubuntu with `useradd`) | Created without `-m` | `mkhomedir_helper user`, or create it, copy `/etc/skel/.`, `chown -R` |
| `ls -l` shows a number instead of a name | The owner was deleted, or the UID isn't known on this host (NFS/containers) | `find / -nouser`; `chown`; align UIDs |
| `su: Authentication failure` | Wrong password, password never set, locked or expired | `sudo passwd -S user`; `sudo chage -l user` (topic 023) |

## Quick recap

- The kernel works with **UIDs**; names come from `/etc/passwd` (or a directory) via NSS. UID 0 = root.
- `/etc/passwd` has 7 fields: name, x, UID, GID, comment, home, shell. Hashes live in root-only `/etc/shadow`.
- `useradd` (defaults from `/etc/login.defs`, `/etc/default/useradd`, `/etc/skel`), `usermod -aG` (never forget `-a`), `userdel -r`.
- Check with `id`, `getent passwd`. Service accounts: `-r -s /sbin/nologin`.

**Interview questions**

1. *What makes an account root?* UID 0, regardless of its name.
2. *`usermod -G` vs `usermod -aG`?* `-G` replaces all supplementary groups with the list given; `-aG` appends to the existing ones.
3. *What happens to a deleted user's files outside their home?* They keep the old numeric UID and show as a number in `ls -l`. A new user given that UID would own them. Find them with `find / -nouser`.
