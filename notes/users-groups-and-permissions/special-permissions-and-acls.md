# Special Permissions (SUID, SGID, Sticky) & ACLs

> Supports *Diagnose and correct file permission problems* **[RHCSA Core]** · ACL details **[Production Practice]**
> **Related:** [File permissions & umask](file-permissions.md) · [Groups](groups.md) · [Finding files (`-perm`)](../files-and-text-processing/finding-files.md) · [Archiving (`--acls`)](../files-and-text-processing/archiving-and-compression.md)

## 1. Overview

Basic `rwx` can't express "run this program with root's rights", "new files here belong to the team group", "only owners may delete in this shared directory", or "give Bob read access to this one file". The three **special bits** and **POSIX ACLs** solve those problems.

## 2. Special Permission Bits

| Bit | Octal | Symbolic | On an executable file | On a directory | Shown as |
|---|---|---|---|---|---|
| **SUID** | `4000` | `u+s` | Runs with the **file owner's** UID | No effect on Linux | `s`/`S` in the user x slot |
| **SGID** | `2000` | `g+s` | Runs with the **file's group** GID | **New entries inherit the directory's group** (subdirs inherit SGID too) | `s`/`S` in the group x slot |
| **Sticky** | `1000` | `+t` | Ignored on Linux | **Only the file's owner, the directory owner, or root may delete/rename entries** | `t`/`T` in the other x slot |

- Lowercase (`s`, `t`) = the underlying `x` is also set. Uppercase (`S`, `T`) = special bit set **without** `x` (usually a mistake on files).
- **Linux ignores SUID and SGID on interpreted scripts** (`#!/bin/bash`, Python…); only compiled binaries honor them.

```bash
ls -l /usr/bin/passwd     # -rwsr-xr-x. root root  → SUID: users can update /etc/shadow
ls -ld /tmp               # drwxrwxrwt. root root  → sticky
chmod 4755 prog   ; chmod u+s prog    # set SUID
chmod 2775 dir    ; chmod g+s dir     # set SGID
chmod 1777 dir    ; chmod +t dir      # set sticky
chmod 3770 dir                        # SGID + sticky together
chmod u-s,g-s,-t target               # remove
```

> ⚠️ **GNU `chmod` keeps SUID/SGID on directories with plain numeric modes.** `chmod 0775 dir` does **not** clear SGID; use `chmod g-s dir` (or `chmod 00775 dir`). The sticky bit is cleared by `chmod 0777`.

### 2.1 Auditing

```bash
find / -xdev -type f -perm -4000 2>/dev/null     # SUID files
find / -xdev -type f -perm -2000 2>/dev/null     # SGID files
find / -xdev -type d -perm -2000 2>/dev/null     # SGID directories
find / -xdev -type d -perm -1000 2>/dev/null     # sticky directories (/tmp, /var/tmp, /dev/shm…)
rpm -Va | grep '^.M'                             # mode changed vs package database
```

An unexpected SUID-root binary is a classic privilege-escalation backdoor.

## 3. Shared Collaboration Directory (recipe) **[RHCSA Core]**

```bash
groupadd -g 5000 projects
mkdir -p /shared/projects
chgrp projects /shared/projects
chmod 2770 /shared/projects          # SGID: group inherited; no access for others
chmod +t   /shared/projects          # optional: members can't delete each other's files (3770)
usermod -aG projects alice ; usermod -aG projects bob   # they must log in again
ls -ld /shared/projects              # drwxrws--T. root projects   (T: sticky without o+x)
su - alice -c 'touch /shared/projects/a.txt; ls -l /shared/projects/a.txt'   # group = projects
```

With RHEL 10's default umask (`0022`, verified), new files are **not** group-writable, so team members can read but not edit each other's files. To give the group `rw` regardless of each user's umask, add a **default ACL** (§4.4), or set `umask 0002` for the team's users.

## 4. ACLs (POSIX Access Control Lists)

ACLs add entries for **specific users and groups** beyond owner/group/other. RHEL's XFS and ext4 enable them by default; there's nothing to mount. (`mount | grep acl` usually shows nothing, because `acl` is a default.)

### 4.1 Reading ACLs

```bash
$ getfacl report.txt
# file: report.txt
# owner: root
# group: root
user::rw-                 ← owner
user:alice:r--            ← named user
group::r--                ← owning group
group:devs:rw-   #effective:r--   ← named group, limited by the mask
mask::r--                 ← upper limit for named users, named groups AND group::
other::---
```

`ls -l` shows `+` after the mode. On such files, the **group bits shown by `ls -l` are the mask**.

### 4.2 Setting and removing

| Task | Command |
|---|---|
| Give a user read access | `setfacl -m u:alice:r file` |
| Give a group rw | `setfacl -m g:devs:rw file` |
| Deny one user explicitly | `setfacl -m u:charlie:--- file` (named user entry beats "other") |
| Directories recursively | `setfacl -R -m g:devs:rwX dir` (`X` = execute on dirs only) |
| Remove one entry | `setfacl -x u:alice file` |
| Remove all extended entries | `setfacl -b file` |
| Set the mask | `setfacl -m m::rx file` |
| Copy ACL from another file | `getfacl a \| setfacl --set-file=- b` |
| Back up / restore | `getfacl -R /srv > acl.bak` · `setfacl --restore=acl.bak` |

### 4.3 The mask

- The mask caps the **effective** permissions of named users, named groups and the owning group. It doesn't affect the owner or others.
- `setfacl -m` **recalculates the mask** automatically (the union of the group-class entries) unless you pass `-n`. That's why setting a mask and then adding an entry can silently raise it again.
- `chmod g=…` on a file with an ACL changes the **mask**, not the `group::` entry.

### 4.4 Default ACLs (inheritance for directories)

```bash
setfacl -d -m g:projects:rwX /shared/projects    # new files/dirs inherit this entry
getfacl -d /shared/projects                      # show default entries
setfacl -k /shared/projects                      # remove the default ACL
```

Default ACLs apply only to **newly created** items. Existing files need `setfacl -R -m …`.

### 4.5 Preserving ACLs

| Tool | Preserves ACLs with |
|---|---|
| `cp` | `-p` or `-a` |
| `mv` (same filesystem) | Always (same inode) |
| `tar` | `--acls` (create and extract) |
| `rsync` | `-A` (with `-a`) |

## 5. File Attributes **[Advanced]**

```bash
lsattr file
chattr +i file    # immutable: even root can't modify, rename or delete until chattr -i
chattr +a log     # append-only
```

An immutable bit is a common cause of "Operation not permitted" for root.

## 6. RHCSA Exam Focus

- Collaboration directory: correct group, `2770` (SGID), optional sticky; test as two different users.
- Know what `s`/`S`/`t`/`T` mean in `ls -l` output and how to set and clear each.
- ACLs aren't named in the RHEL 10 objectives, but `+` in `ls -l` and the mask often explain "permission problems." Know `getfacl`/`setfacl -m`/`-x`/`-b`.

## 7. Production Practices **[Production Practice]**

- Audit SUID/SGID binaries regularly; mount untrusted filesystems `nosuid`.
- Prefer groups + SGID directories; use ACLs for exceptions, and document them (they're invisible in plain `ls -l` apart from `+`).
- Logs recreated by logrotate lose file ACLs; use a default ACL on the directory or set `create` modes in logrotate.
- Back up ACLs (`getfacl -R`) before mass permission changes.

## 8. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Files in a shared dir get the creator's group | SGID not set (or set after the files were created) | `chmod g+s dir`; `chgrp -R grp dir` for existing files |
| Users delete each other's files | No sticky bit | `chmod +t dir` |
| User has an ACL entry but is still denied | Mask restricts it (`#effective:`) | `setfacl -m m::rwx` |
| `chmod 0775 dir` didn't remove SGID | GNU chmod preserves it | `chmod g-s dir` |
| SUID script doesn't gain privileges | Kernel ignores SUID on scripts | Use sudo rules instead |
| Root gets "Operation not permitted" | `chattr +i` | `lsattr`; `chattr -i` |

## 9. Interview Questions

| Question | Answer |
|---|---|
| How does `passwd` let users edit `/etc/shadow`? | It's SUID-root, so it runs with UID 0. |
| What does SGID on a directory do? | New files and subdirectories inherit the directory's group (and subdirs inherit SGID). |
| Why is `/tmp` mode `1777`? | Everyone can create files, but the sticky bit stops users deleting each other's files. |
| `s` vs `S`? | `S` = SUID/SGID set but the execute bit isn't. |
| What is the ACL mask? | The maximum effective permission for named users, named groups and the owning group. |
| How do you make new files in a directory inherit an ACL? | A default ACL: `setfacl -d -m …`. |
| Why doesn't SUID work on a bash script? | The kernel ignores it to avoid interpreter race conditions. |

## 10. Quick Revision

```bash
SUID 4 u+s (file: run as owner) · SGID 2 g+s (file: run as group; dir: inherit group) · sticky 1 +t (dir: owner-only delete)
s/t = with x · S/T = without x · scripts ignore SUID/SGID · chmod g-s to clear SGID on dirs
find / -xdev -perm -4000|-2000|-1000
getfacl f | setfacl -m u:x:rw f | -m g:g:rwX | -x u:x | -b | -d -m (default) | -k | -R | m::rx (mask)
cp -a / tar --acls / rsync -aA preserve ACLs · lsattr / chattr +i
```

## 11. Cross-References

- [File permissions & umask](file-permissions.md)
- [Groups](groups.md)
- [sudo & privileged access (instead of SUID scripts)](sudo-and-privileged-access.md)
- [Finding files](../files-and-text-processing/finding-files.md)
- [SELinux fundamentals](../firewall-and-selinux/selinux-fundamentals.md) · [SELinux file contexts](../firewall-and-selinux/selinux-file-contexts.md)
