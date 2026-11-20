# 008 · Inodes, Hard Links and Symbolic Links

> **You need first:** [007 · Files and directories](007-files-and-directories.md)
> **Next:** [009 · Viewing files](009-viewing-files.md)

---

## What it is

- An **inode** (index node) is the record a filesystem keeps for each file. It holds everything **about** the file except its name and its contents: type, permissions, owner, group, size, timestamps, **link count**, and the locations of the data blocks on disk. Each inode has a number, unique within its filesystem.
- A **directory** is just a table of `name → inode number` pairs.
- A **hard link** is an extra **name** for the same inode. Two names, one file.
- A **symbolic link** (symlink, soft link) is a tiny separate file whose content is a **path** to another file, like a shortcut.

## Why it exists

Separating names from files gives useful powers:
- One file can appear in two places without using double space (hard link).
- You can point a stable path at a changing target. For example, `/opt/app/current → /opt/app/v2.3` lets you switch versions by changing one symlink.
- Renames and moves within a filesystem are instant, because only names change.
- It explains real production puzzles: "I deleted a 50 GB log but the disk is still full."

## Analogy

The **inode is a house**. A **name is an entry in a phone book** pointing to the house.
- A **hard link** is a second phone-book entry with the **same address**. Either entry gets you into the same house. The house is demolished only when the **last** entry is removed and **nobody is inside** (no program has it open).
- A **symlink** is a **sticky note** that says "go to 12 Main Street". If that house is demolished, the sticky note still exists, but it leads nowhere (a "dangling" link).

## How it works inside

### What lives where

| In the inode | NOT in the inode |
|---|---|
| Type, permissions, owner, group, size, timestamps, link count, pointers to data blocks | The **name** (it's in the directory) and the **data** (it's in data blocks) |

When you open `/home/alice/a.txt`, the kernel reads the directory `/home/alice`, finds `a.txt → inode 3407937`, reads inode 3407937, checks permissions, then reads the data blocks it points to.

### Link count and when space is really freed

The inode keeps a **link count**: how many names point to it.
- `ln a b` → the count goes from 1 to 2.
- `rm a` → the count goes back to 1. The data is untouched, still reachable as `b`.
- `rm b` → the count reaches 0. **But** the kernel also counts how many programs have the file **open**. Only when both are zero are the data blocks freed.

This is the famous **"deleted but still open" file**. A program (say, a web server) keeps writing to `access.log`. You `rm` it, but the space is not freed until that program closes the file or is restarted. `df` still shows the disk full, while `du` can't see the file any more because it has no name.

### Hard link vs symbolic link

| | Hard link | Symbolic link |
|---|---|---|
| Create | `ln target name` | `ln -s target name` |
| Inode | **Same** as the target | Its **own** inode |
| Contains | Nothing extra: it *is* the file | A **path** (text) |
| Across filesystems | **No** (inode numbers are per filesystem) | Yes |
| Point to a directory | **No** (could create loops) | Yes |
| Target deleted | Data survives while any name remains | Link becomes **dangling** (broken) |
| Permissions | Shared with the file (same inode) | Shows `lrwxrwxrwx`, but the **target's** permissions apply |
| How `ls -l` shows it | Link count > 1 | Type `l` and `name -> target` |

**Relative symlinks** are resolved from the **link's own directory**, not from where you are standing. `ln -s ../shared/data data` means "from the folder that holds this link, go up one level, then into shared/data".

### Inodes can run out

- **ext4** creates a fixed number of inodes when the filesystem is made. Millions of tiny files can use them all up while bytes remain free, and you get "No space left on device".
- **XFS** (RHEL's default) creates inodes as needed, so this is rarer.
- **VFAT** has no real inodes.

### Directory link counts

A directory's link count = 2 + the number of subdirectories. That's its name in its parent, plus its own `.` entry, plus each child's `..` entry.

## Commands

```bash
echo hello > a.txt          # create a file containing "hello" (">" is explained in topic 016)
ln a.txt b.txt
ls -li a.txt b.txt
```
```
17358831 -rw-r--r--. 2 alice alice 6 Nov 16 10:20 a.txt
17358831 -rw-r--r--. 2 alice alice 6 Nov 16 10:20 b.txt
```
- `-i` adds the inode number as the first column. Both names show **the same inode** (`17358831`) and a link count of **2**. They are the same file.

```bash
rm a.txt ; cat b.txt ; ls -li b.txt
```
```
hello
17358831 -rw-r--r--. 1 alice alice 6 Nov 16 10:20 b.txt
```
- The data survived. The link count dropped to 1.

```bash
ln -s /etc/hosts hosts-link
ls -l hosts-link
```
```
lrwxrwxrwx. 1 alice alice 10 Nov 16 10:22 hosts-link -> /etc/hosts
```
- Type `l`. The size `10` is the length of the stored text `/etc/hosts`. The arrow shows the target.

```bash
readlink hosts-link ; readlink -f hosts-link
```
```
/etc/hosts
/etc/hosts
```
- `readlink` prints the stored path. `-f` fully resolves the whole chain of links to the real file. They differ when links point to links.

```bash
ln -s /nope broken ; ls -l broken ; cat broken
```
```
lrwxrwxrwx. 1 alice alice 5 Nov 16 10:23 broken -> /nope
cat: broken: No such file or directory
```
- A **dangling** symlink: the link exists, but its target doesn't.

```bash
ln -sfn /opt/app-2.0 /opt/app-current
```
- `-f` replaces an existing link, and `-n` treats an existing link to a directory as a plain file, not "put the new link inside it". This is the standard "switch release" move in deployments.

```bash
ln -sr /srv/app/current /usr/local/app
```
- `-r` works out a **relative** path for you, so the link keeps working if the whole tree is moved.

```bash
ln /etc/hosts /home/alice/h
```
```
ln: failed to create hard link '/home/alice/h' => '/etc/hosts': Operation not permitted
```
- There are two separate rules, and either one can stop you:
  - **Ownership protection.** RHEL turns on `fs.protected_hardlinks = 1`. A normal user may only hard-link files they own (or can read and write). Otherwise anyone could pin a copy of a sensitive file's inode. That's the error above, seen when `/home` and `/etc` are on the same filesystem.
  - **Filesystem boundary.** If `/home` is a **different filesystem** from `/etc` (common in production), you get `Invalid cross-device link` instead, even as root. Hard links can't cross filesystems because inode numbers only mean something inside one filesystem.

```bash
namei -l /usr/bin/python3
```
```
f: /usr/bin/python3
dr-xr-xr-x root root /
drwxr-xr-x root root usr
dr-xr-xr-x root root bin
lrwxrwxrwx root root python3 -> python3.12
-rwxr-xr-x root root   python3.12
```
- `namei` walks a path step by step, following symlinks and showing permissions at each level. It's great for "why can't I reach this file?"

```bash
find / -xdev -samefile /etc/hosts 2>/dev/null     # all hard links to a file
find ~ -type f -links +1                         # files with more than one name
find / -xdev -xtype l 2>/dev/null                # broken symlinks
```
- `find` is covered in topic 020. `-xdev` = don't leave this filesystem; `-xtype l` = links whose target is missing.

```bash
sudo dnf install -y lsof          # not part of a minimal install
sudo lsof +L1
```
```
COMMAND   PID    USER   FD   TYPE DEVICE SIZE/OFF NLINK     NODE NAME
sleep    5957 vagrant    5w   REG    8,4 52428800     0 16882551 /tmp/big.log (deleted)
```
- `lsof` = **l**ist **o**pen **f**iles. `+L1` shows open files whose link count is **below 1**, i.e. deleted but still open.
- `NLINK 0` and `(deleted)`: a 50 MB file that was `rm`'d while a process still held it open. `FD 5w` means file descriptor 5, open for writing (topic 016). The space only comes back when that process closes the file or exits. In real life this is usually a big log a service is still writing: restart or reload the service to free the space.
- To reproduce it: `(exec 5>/tmp/big.log; dd if=/dev/zero bs=1M count=50 >&5; sleep 300) & sleep 1; rm /tmp/big.log; sudo lsof +L1`.

### Symlinks you'll see on every RHEL system

| Example | Purpose |
|---|---|
| `/bin -> usr/bin` | /usr merge (topic 006) |
| `/etc/localtime -> ../usr/share/zoneinfo/Asia/Kolkata` | The system time zone |
| `/usr/lib64/libz.so.1 -> libz.so.1.3.1` | Library versions: programs ask for `.so.1` and get the current build |
| `/etc/alternatives/*` | Chooses the default `java`, `python` and so on when several versions are installed |
| `/etc/systemd/system/multi-user.target.wants/sshd.service` | "Enabling" a service at boot creates a symlink (topic 037) |

### Copying and deleting links

| Action | What happens |
|---|---|
| `cp link dest` | Copies the **target's contents** (follows the link) |
| `cp -a link dest` or `cp -P` | Copies the **link itself** |
| `tar` | Stores symlinks as links (topic 021) |
| `rm link` | Removes only the link, never the target |
| `rm -rf dirlink/` (with a trailing `/`) | ⚠️ Follows the link and **deletes the target directory's contents** |

Never put a trailing slash when removing a symlink to a directory: `rm dirlink`.

### Try it
1. Create `f`, hard link it as `g`, symlink it as `s`. Run `ls -li f g s` and compare inode numbers and link counts.
2. Delete `f`. Which of `g` and `s` still works? Why?
3. Run `ls -ld /etc ; ls -l /etc | grep -c '^d'` and check the "2 + subdirectories" rule.
4. Run `ls -l /etc/localtime` to see your time zone link.

**Check your work:** on your lab VM, from the notes folder, run `sudo ./checks/check 008` for every step, or `sudo ./checks/check 008 STEP` for one (topic 002 shows how to get the notes there).

## Where you'll use it

- **"Disk full but I deleted the file"**: `lsof +L1`, then restart or reload the process. This is one of the most common production incidents.
- **Release switching**: `/opt/app/current → /opt/app/releases/2026-11-16`. Deploy tools (Capistrano-style, many CI scripts) flip one symlink. Rollback means pointing it back.
- **Kubernetes**: ConfigMaps and Secrets mounted into pods use a symlink trick. Files point to a `..data` symlink, which is swapped atomically when the config changes, so apps never see half-written files.
- **Log rotation**: understanding inodes explains why some apps keep writing to the *old* rotated file until told to reopen it (topic 038).
- **Backups**: hard-link-based snapshots (like `rsync --link-dest`) store unchanged files once across many daily backups.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `Invalid cross-device link` | Hard link across filesystems | Use a symlink, or copy |
| `ln: failed to create hard link … Operation not permitted` | `fs.protected_hardlinks`: you don't own the target | Use a symlink, or copy the file |
| `hard link not allowed for directory` | Directories can't be hard-linked | Use a symlink |
| `No such file or directory` opening a link that `ls` shows | Dangling link, or a relative target computed from the wrong place | `readlink -f link`; fix the target or use an absolute path |
| `Too many levels of symbolic links` | Links point to each other in a loop | `namei -l path` shows the chain |
| Space not freed after `rm` | Another hard link exists, or a process still has the file open | `find / -xdev -samefile` and `lsof +L1` |
| "Permission denied" through a link showing `rwxrwxrwx` | Symlink permissions mean nothing; the **target's** permissions and its parent directories count | `namei -l link` |
| `No space left on device` with free space | Out of inodes (common on ext4 with tiny files) | `df -i`; remove small files |

## Quick recap

- The inode holds metadata and data pointers. The **name** lives in the directory.
- Hard link = another name for the same inode (same filesystem, no directories). Symlink = a file containing a path (anywhere, can dangle).
- Data is freed only when the link count is 0 **and** no process has the file open → `lsof +L1`.
- `ln -s TARGET LINKNAME` (target first). Never `rm -r link/` with a trailing slash.

**Interview questions**

1. *What's an inode?* The structure that holds a file's metadata and pointers to its data blocks: everything except the file name and the data itself.
2. *Hard link vs soft link?* A hard link is another directory entry for the same inode; it can't cross filesystems or point to directories. A soft link is a separate file containing a path; it can go anywhere but breaks if the target is removed.
3. *You deleted a huge log but `df` still shows the disk full. Why and how do you fix it?* A running process still has the file open, so the kernel hasn't freed the blocks. Find it with `lsof +L1` and restart or reload the process (or truncate it through `/proc/PID/fd/N`).

**Scenario question** (answer out loud first, then compare)

> *"You deleted a 20 GB log file to free space, but `df` still shows the disk full. What happened, and how do you fix it without a reboot?"*

**Model answer:**
1. A running process still has the file open. The name is gone, but the inode and its blocks stay allocated until the last open file descriptor closes.
2. Find it: `sudo lsof +L1` lists open files with a link count of 0 (look for `(deleted)`).
3. Best fix: **restart or reload** that service so it reopens a new log file.
4. If you can't restart it, truncate it through `/proc`: `: > /proc/PID/fd/N`, which frees the blocks immediately.
5. Prevention: rotate logs with logrotate (with a reload, or `copytruncate`), and empty a live log with `truncate -s 0` or `: > file`, never `rm`.

**Likely follow-ups:**
- *Would a hard link have changed anything?* Yes. With another hard link the inode still has a name, so `rm` of one name frees nothing at all.
- *Why can't hard links cross filesystems?* A directory entry stores an inode **number**, which only means something inside its own filesystem.
