# 027 · Special Permissions (SUID, SGID, Sticky), ACLs and File Attributes

> **You need first:** [026 · File permissions and umask](026-file-permissions-and-umask.md)
> **Next:** [028 · sudo and su](028-sudo-and-su.md)

---

## What it is

Plain `rwx` can't express everything. Linux adds three tools:

1. **Special permission bits**, three extra bits in front of the normal nine:
   - **SUID** (Set User ID): a program runs with the **file owner's** identity, not yours.
   - **SGID** (Set Group ID): a program runs with the **file's group**; on a **directory**, new files **inherit the directory's group**.
   - **Sticky bit**: on a directory, only a file's **owner** (or the directory's owner, or root) may delete or rename it.
2. **ACLs** (Access Control Lists): extra permission entries for **specific named users and groups**, beyond owner/group/other.
3. **File attributes**: low-level flags like **immutable** (nobody, not even root, can change the file) and **append-only**.

## Why it exists

- Users must be able to change their own password, which means writing to root-only `/etc/shadow`. **SUID** on `/usr/bin/passwd` makes that possible for just that one program.
- A team shares a directory: new files should belong to the **team** group, not each person's private group → **SGID directory**.
- Everyone can write in `/tmp`, but you shouldn't be able to delete other people's files there → **sticky bit**.
- "Give Bob read access to this one file without changing its group" → **ACL**.
- "Make sure nobody, even root by accident, can modify this file" → **immutable attribute**.

## Analogy

- **SUID** is a **company car with a special badge on the dashboard**. Whoever drives it gets through the gates as "Facilities Dept", but only along that car's route.
- **SGID directory** is a **team mailbox**: anything dropped in is stamped with the team's name, whoever posted it.
- **Sticky bit** is a **shared fridge**: anyone can put food in, but you can only throw out your own.
- **ACLs** are a **guest list taped to one door**, in addition to the normal key rules.
- **Immutable** is a **document sealed in glass**.

## How it works inside

### The special bits

| Bit | Octal | Symbolic | On an executable file | On a directory | Shown as |
|---|---|---|---|---|---|
| **SUID** | `4000` | `u+s` | Runs with the **file owner's** UID | No effect on Linux | `s`/`S` in the owner's x spot |
| **SGID** | `2000` | `g+s` | Runs with the **file's group** | New entries **inherit the directory's group**; new subdirectories inherit SGID too | `s`/`S` in the group's x spot |
| **Sticky** | `1000` | `+t` | Ignored | Only the file owner, directory owner or root can delete/rename entries | `t`/`T` in the others' x spot |

- Lowercase `s`/`t` = the underlying `x` is also set. Uppercase `S`/`T` = special bit set **without** `x` (on a file, usually a mistake).
- **What happens on SUID:** when a process runs (execve) a file with SUID, the kernel sets the new process's **effective UID** to the file's owner. Permission checks use the effective UID, so `passwd` run by alice acts as root while it runs. Because this is so powerful, the kernel **ignores SUID/SGID on scripts** (`#!/bin/bash`, Python): only compiled programs honour them. It also ignores them on filesystems mounted `nosuid` (topic 048).
- **What happens on an SGID directory:** when a file is created inside it, the kernel gives the file the **directory's group** instead of the creator's primary group.

### ACLs

An ACL is stored as an **extended attribute** (extra metadata) on the inode. When a file has one, the kernel's permission check (topic 026) becomes:

1. Owner → the `user::` entry.
2. A **named user** entry for your UID (`user:alice:r--`) → that entry, limited by the **mask**.
3. Owning group **or** any named group entries you belong to → access if **any** matching group entry allows it (each limited by the mask). If groups matched but none allows it → denied (others are not checked).
4. Otherwise → `other::`.

**The mask** is the **upper limit** for named users, named groups and the owning group. It does not affect the owner or others. When a file has an ACL, the group bits shown by `ls -l` **are the mask**, so `chmod g=…` changes the mask.

**Default ACLs** live on **directories** only. They are copied onto new files and subdirectories created inside, which is how you get inheritance.

XFS and ext4 on RHEL and Ubuntu support ACLs out of the box: nothing needs enabling on the filesystem. The `setfacl`/`getfacl` tools come from the `acl` package, which a minimal install may lack (`sudo dnf install acl`, Ubuntu `sudo apt install acl`).

### File attributes

Attributes are filesystem flags, checked **before** normal permissions, even for root:
- `i` (immutable): can't modify, rename, delete or link it. Not even root, until the flag is removed.
- `a` (append-only): data can only be added at the end (useful for logs).

## Commands

### Special bits

```bash
ls -l /usr/bin/passwd ; ls -ld /tmp
```
```
-rwsr-xr-x. 1 root root 91424 Feb 23  2026 /usr/bin/passwd
drwxrwxrwt. 10 root root 4096 Nov 16 23:15 /tmp
```
- `rws` for the owner = SUID with execute. `rwt` for others = sticky with execute. `/tmp` is `1777`.

```bash
chmod 4755 prog      # or chmod u+s prog   — SUID
chmod 2775 dir       # or chmod g+s dir    — SGID
chmod 1777 dir       # or chmod +t dir     — sticky
chmod 3770 dir       # SGID + sticky together
chmod u-s,g-s,-t x   # remove them
```

**GNU `chmod` keeps SUID/SGID on directories when you give a plain number.** `chmod 0775 dir` does **not** remove SGID; use `chmod g-s dir`.

### Recipe: a shared team directory

```bash
sudo dnf install -y acl                           # setfacl/getfacl; missing on some minimal images
sudo groupadd -g 5000 projects
sudo mkdir -p /shared/projects
sudo chgrp projects /shared/projects
sudo chmod 2770 /shared/projects                  # SGID, nothing for others
sudo chmod +t /shared/projects                    # optional: can't delete each other's files
sudo setfacl -d -m g:projects:rwX /shared/projects   # new files are group-writable (default ACL)
sudo usermod -aG projects alice ; sudo usermod -aG projects bob   # then they log in again
ls -ld /shared/projects
```
```
drwxrws--T+ 2 root projects 6 Nov 16 12:45 /shared/projects
```
- `s` in the group spot = SGID. `T` = sticky without others' x. `+` = ACL present.

```bash
su - alice -c 'touch /shared/projects/a.txt' ; ls -l /shared/projects/a.txt
```
```
-rw-rw----+ 1 alice projects 0 Nov 16 12:46 /shared/projects/a.txt
```
- The group is `projects` (thanks to SGID), and the group can write (thanks to the default ACL), even though alice's umask is `022`.

### Auditing special bits

```bash
sudo find / -xdev -type f -perm -4000 2>/dev/null     # SUID files
sudo find / -xdev -type f -perm -2000 2>/dev/null     # SGID files
sudo find / -xdev -type d -perm -1000 2>/dev/null     # sticky directories
sudo rpm -Va | grep '^.M'                             # files whose mode changed vs the package
```
An unexpected SUID-root program is a classic backdoor.

### ACLs

```bash
setfacl -m u:alice:r report.txt
setfacl -m g:devs:rw report.txt
getfacl report.txt
```
```
# file: report.txt
# owner: root
# group: root
user::rw-
user:alice:r--
group::r--
group:devs:rw-
mask::rw-
other::---
```
- `user::` = owner, `user:alice:` = named user, `group::` = owning group, `group:devs:` = named group, `mask::` = upper limit, `other::` = everyone else.

```bash
setfacl -m m::r report.txt ; getfacl report.txt | grep devs
```
```
group:devs:rw-			#effective:r--
```
- The mask now caps devs at `r--`. `#effective:` shows what really applies.

| Task | Command |
|---|---|
| Give a user read | `setfacl -m u:alice:r file` |
| Give a group read/write | `setfacl -m g:devs:rw file` |
| Explicitly deny one user | `setfacl -m u:charlie:--- file` |
| Recursive, `X` = execute only on directories | `setfacl -R -m g:devs:rwX dir` |
| Default ACL (inherited by new items) | `setfacl -d -m g:devs:rwX dir` |
| Remove one entry / all entries / the default ACL | `setfacl -x u:alice f` · `setfacl -b f` · `setfacl -k dir` |
| Back up and restore | `getfacl -R /srv > acl.bak` · `setfacl --restore=acl.bak` |

`setfacl -m` **recalculates the mask** automatically (unless `-n`), so a mask you set earlier can silently grow again.

**Keeping ACLs when copying:** `cp -a`/`cp -p`, `tar --acls`, `rsync -aA`. `mv` on the same filesystem always keeps them (same inode).

### Attributes

```bash
sudo chattr +i /etc/resolv.conf ; lsattr /etc/resolv.conf
sudo rm /etc/resolv.conf
```
```
----i----------------- /etc/resolv.conf
rm: cannot remove '/etc/resolv.conf': Operation not permitted
```
- Even root is blocked. `sudo chattr -i /etc/resolv.conf` undoes it.

### Try it
1. Build the shared team directory with two test users, and prove that the group is inherited and that the sticky bit stops cross-deletes.
2. Copy `/usr/bin/id` to `/tmp/myid`, make it root-owned SUID (`chown root; chmod 4755`), and run it as a normal user. Look at `euid=0`. Delete it afterwards.
3. Give a single extra user read access to a file with an ACL, then shrink the mask and watch `#effective` change.
4. Make a file immutable and try to edit it as root.

**Check your work:** on your lab VM, from the notes folder, run `sudo ./checks/check 027` for every step, or `sudo ./checks/check 027 STEP` for one (topic 002 shows how to get the notes there).

## Where you'll use it

- **Security audits:** the SUID/SGID inventory is part of every hardening baseline. Mount untrusted filesystems (USB sticks, `/tmp`, container volumes) with `nosuid`.
- **Container security:** Kubernetes `allowPrivilegeEscalation: false` sets a kernel flag (`no_new_privs`) that makes SUID binaries **not** gain privileges inside the container.
- **Shared directories** for teams, CI build directories, upload areas (SGID + default ACL).
- **Log directories:** a default ACL lets a monitoring agent read logs that logrotate keeps recreating.
- **Immutable files** for critical configs, and as a known cause of "root can't delete this file".

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `setfacl: command not found` | The `acl` package isn't installed (some minimal and cloud images) | `sudo dnf install -y acl` |
| Files in a shared directory get the creator's group | SGID not set, or set after the files existed | `chmod g+s dir`; `chgrp -R grp dir` for existing files |
| Team members can't edit each other's files | umask 022 makes files `644` | Default ACL `g:grp:rwX`, or umask 002 for the team |
| Users delete each other's files | No sticky bit | `chmod +t dir` |
| A user has an ACL entry but is still denied | The mask limits it (`#effective:`) | `setfacl -m m::rwx file` |
| `chmod 0775 dir` didn't remove SGID | GNU chmod keeps it | `chmod g-s dir` |
| A SUID script doesn't gain privileges | The kernel ignores SUID on scripts | Use a sudo rule (topic 028) |
| Root gets "Operation not permitted" | Immutable attribute | `lsattr`; `chattr -i` |
| ACLs lost after a restore or copy | Copied without ACL support | `cp -a`, `tar --acls`, `rsync -aA` |

## Quick recap

- SUID 4 (`u+s`) = run as the file's owner. SGID 2 (`g+s`) = run as the file's group / directory group inheritance. Sticky 1 (`+t`) = owner-only delete in shared directories.
- Lowercase `s`/`t` = with x; uppercase = without. Scripts ignore SUID. Audit with `find -perm -4000`.
- ACLs: `getfacl`, `setfacl -m u:x:r`, `-x`, `-b`, `-d` (default/inherited). The mask caps named entries and the group.
- `chattr +i` makes a file immutable even for root; check with `lsattr`.

**Interview questions**

1. *How does `passwd` let a normal user write `/etc/shadow`?* It's owned by root with the SUID bit, so it runs with an effective UID of 0.
2. *What does SGID on a directory do?* New files and subdirectories inherit the directory's group (and subdirectories also get SGID), so team files stay owned by the team group.
3. *What is the ACL mask?* The maximum effective permission for named users, named groups and the owning group. The group bits shown by `ls -l` on a file with an ACL are the mask.

**Scenario question** (answer out loud first, then compare)

> *"Three teams share `/srv/projects`. Files created by one member must be editable by the rest of their team, and nobody may delete another person's files. Design it."*

**Model answer:**
1. A group per team, and a directory per team owned by that group: `chgrp devteam /srv/projects/dev`.
2. **SGID** on the directory (`chmod 2770`): new files inherit the group `devteam` instead of the creator's primary group.
3. **Sticky bit** (`chmod +t`, so `3770`): only a file's owner (or the directory owner, or root) can delete or rename it.
4. Group write on new files needs a suitable **umask** (`002`) or, more reliably, a **default ACL**: `setfacl -d -m g:devteam:rwX /srv/projects/dev`.
5. Extra one-off access (an auditor who may read only) is a named ACL entry: `setfacl -m u:auditor:rX`.
6. Test as two different users before telling the teams it's done.

**Likely follow-ups:**
- *Why does `ls -l` show `rwx` for the group, but a named ACL user still can't write?* The ACL **mask** limits named entries; `getfacl` shows `#effective:`.
- *Why is a SUID shell script ignored?* The kernel ignores SUID on scripts because of race conditions; it only applies to binaries.
