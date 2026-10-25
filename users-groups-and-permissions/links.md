# Inodes, Hard Links & Symbolic Links

> **Sessions:** S28 · **Objective:** *Create hard and soft links* **[RHCSA Core]**
> **Related:** [Files & directories](../shell-and-command-line/files-and-directories.md) · [Filesystem hierarchy (UsrMove symlinks)](../linux-fundamentals/filesystem-hierarchy.md) · [Finding files (`-inum`, `-samefile`)](../files-and-text-processing/finding-files.md) · [File permissions](file-permissions.md) · [Processes & system calls (fds, deleted-open files)](../processes-and-resource-management/processes-and-system-calls.md#6-file-descriptors)

## 1. Overview

A file's data and metadata live in an **inode**. A **directory** is a table mapping **names → inode numbers**. A **hard link** is simply another name for the same inode. A **symbolic (soft) link** is a small separate file whose content is a **path** to another file.

## 2. Inodes

| Stored in the inode | Not stored in the inode |
|---|---|
| Type, permissions, owner, group, size, timestamps, link count, pointers to data blocks | The **file name** (it's in the directory entry); the **data** (it's in data blocks) |

```bash
ls -li                   # first column = inode number
stat file                # inode, links, size, perms, all timestamps
df -i                    # inode usage per filesystem
```

- **ext4** creates a fixed number of inodes at `mkfs`; you can run out of inodes with free space left.
- **XFS** (RHEL default) allocates inodes **dynamically**, so exhaustion is rarer.
- FAT/VFAT has no inodes (`df -i` shows blanks or synthetic values).

## 3. Hard vs Symbolic Links

| | Hard link | Symbolic link |
|---|---|---|
| Create | `ln target name` | `ln -s target name` |
| Inode | **Same** as the target | Its **own** inode |
| Contains | — (it *is* the file) | The target **path** |
| Cross filesystems | **No** | Yes |
| Link to directories | **No** (only `.`/`..` by the system) | Yes |
| Target deleted | Data stays until the **last** link is removed | Link becomes **dangling** (broken) |
| Permissions | Shared with the file | Link shows `lrwxrwxrwx`; the **target's** permissions apply |
| `ls -l` | Link count > 1 | `l` type, `name -> target` |

```bash
ln report.txt report-hard.txt          # hard link: link count becomes 2
ln -s /etc/hosts hosts-link            # absolute symlink
ln -s ../shared/data data              # relative symlink: resolved from the LINK's directory
ln -sr /srv/app/current /usr/local/app # -r: compute a relative path automatically
ln -sfn /opt/app-2.0 /opt/app-current  # -f replace, -n treat existing dir-symlink as a file (atomic swap)
readlink hosts-link                    # /etc/hosts (the stored path)
readlink -f hosts-link                 # fully resolved real path
```

## 4. Finding Links

```bash
find / -xdev -samefile /etc/hosts 2>/dev/null   # all hard links to a file
find / -xdev -inum 135794 2>/dev/null           # same, by inode (inode numbers are per filesystem!)
find ~ -type f -links +1                        # files with more than one hard link
find / -xdev -xtype l 2>/dev/null               # broken symlinks
find /etc -maxdepth 1 -type l -ls               # list symlinks with targets
```

Directory link counts are `2 + number of subdirectories` (its own name, its `.`, and each child's `..`).

## 5. Links on RHEL

| Example | Purpose |
|---|---|
| `/bin -> usr/bin`, `/sbin -> usr/sbin`, `/lib64 -> usr/lib64` | UsrMove compatibility |
| `/etc/localtime -> ../usr/share/zoneinfo/Asia/Kolkata` | Time zone (`timedatectl` manages it) |
| `/usr/lib64/libz.so.1 -> libz.so.1.3…` | Shared library versioning |
| `/etc/alternatives/*` | `alternatives` system (e.g., which `java`/`python` is default) |
| `/etc/systemd/system/*.wants/*.service` | Enabled units are symlinks (S50) |

## 6. Copying, Archiving and Deleting

| Operation | Behavior |
|---|---|
| `cp link dest` | Copies the **target's contents** (follows the link) |
| `cp -P` / `cp -a` | Copies the **link itself** |
| `tar` | Stores symlinks as links; hard links stored once |
| `rm link` / `unlink link` | Removes only the link |
| `rm -rf dirlink/` (trailing slash) | ⚠️ Follows the link: **deletes the target directory's contents** |

> ⚠️ When removing a symlink to a directory, **never add a trailing slash**: `rm dirlink`, not `rm -r dirlink/`.

## 7. RHCSA Exam Focus **[RHCSA Core]**

```bash
ln /root/source.txt /root/hard.txt            # "create a hard link"
ln -s /etc/fstab /root/fstab-link             # "create a soft link"
ls -li /root/source.txt /root/hard.txt        # same inode, link count 2
ls -l /root/fstab-link                        # l… -> /etc/fstab
```

- Read carefully which way round the task wants it: `ln -s TARGET LINKNAME`.
- A hard link fails across filesystems (`Invalid cross-device link`); use a symlink there.
- Prefer **absolute** symlink targets unless the task asks for relative ones; relative paths resolve from the link's own directory.

## 8. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `ln: failed to create hard link … Invalid cross-device link` | Different filesystems | Symlink, or copy |
| `ln: … hard link not allowed for directory` | Directories can't be hard-linked | Symlink |
| `No such file or directory` when opening a link that exists | Dangling or wrongly relative target | `readlink -f link`; fix the target or use an absolute path |
| `Too many levels of symbolic links` | Link loop | `namei -l path` to see the chain |
| Space not freed after deleting a file | Another hard link still exists, or the file is open | `find -samefile`; `lsof +L1` |
| Permission denied through a `777` symlink | Target permissions apply | Check the target and its parent dirs |

## 9. Interview Questions

| Question | Answer |
|---|---|
| What's an inode? | The structure holding a file's metadata and data-block pointers, everything except the name and the data. |
| Hard vs soft link? | Hard: another name for the same inode (same FS, no dirs). Soft: a file containing a path (any FS, dirs OK, can dangle). |
| When is file data actually freed? | When the link count reaches 0 **and** no process has it open. |
| Why can't you hard-link directories? | It could create loops and break the tree structure that tools assume. |
| How do you find all names of a file? | `find / -xdev -samefile file` (or `-inum`, on the same filesystem). |
| What do symlink permissions mean? | Nothing; access is checked on the target. |

## 10. Course Practice (S28, corrected where needed)

| # | Task | Command | Note |
|---|---|---|---|
| 1–3 | Files, hard link, compare inodes | `ln autumn.txt hlautumn.txt; ls -li autumn.txt hlautumn.txt spring.txt` | ✔ |
| 4 | Find same inode | `find . -samefile autumn.txt` (or `-inum N`) | `-samefile` avoids looking up the number |
| 5 | Not stored in the inode | File **name** and file **data** | ✔ |
| 6 | Symlink | `ln -s spring.txt slspring.txt` | ✔ (relative target) |
| 7 | `find / -inum 2` | Inode 2 is the root of **ext2/3/4** filesystems | XFS root inode is usually 128; on RHEL results are mostly virtual filesystems |
| 8 | Library symlinks | `ls -l /usr/lib64 \| grep '^l'` | x86_64 libs are in `/usr/lib64`; `libc.so` is a linker script, not a symlink |
| 9 | Files with more than one link | `find ~ -type f -links +1` | `find` can't see deleted-but-open files (they have no name); use `lsof +L1` |

## 11. Quick Revision

```bash
ln target hard | ln -s target soft | ln -sr | ln -sfn | readlink [-f] | ls -li | stat | df -i
find -samefile f | -inum N | -links +1 | -xtype l (broken) | namei -l path
hard: same inode, same FS, no dirs · soft: own inode, path string, can dangle
rm dirlink (no trailing slash!) · cp follows links, cp -a keeps them
```

## 12. Cross-References

- [Files & directories](../shell-and-command-line/files-and-directories.md)
- [Filesystem hierarchy](../linux-fundamentals/filesystem-hierarchy.md)
- [Finding files](../files-and-text-processing/finding-files.md)
- [File permissions](file-permissions.md)
- [systemd services (enable = symlinks)](../boot-systemd-and-kernel/systemd-targets-and-services.md) · [RPM & DNF](../logs-scheduling-and-packages/rpm-and-dnf-package-management.md)
