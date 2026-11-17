# 007 · Files and Directories: Paths, ls, cp, mv, rm

> **You need first:** [006 · The filesystem tree](006-the-filesystem-tree.md)
> **Next:** [008 · Inodes and links](008-inodes-and-links.md)

---

## What it is

The everyday commands to move around the tree and manage files:

| Command | Short for | Job |
|---|---|---|
| `pwd` | print working directory | Where am I? |
| `cd` | change directory | Go somewhere |
| `ls` | list | What's here? |
| `mkdir` / `rmdir` | make / remove directory | Create / delete empty folders |
| `touch` | — | Create an empty file (or update its time) |
| `cp` | copy | Copy files and folders |
| `mv` | move | Move or rename |
| `rm` | remove | Delete (permanently) |
| `stat`, `file` | — | Show details / guess the content type |

Two helper ideas:

- **Working directory**: the folder your shell is "standing in". Relative paths start from here.
- **Inode** (index node): the hidden record that describes a file (owner, size, permissions, where its data is on disk). A file's **name** lives in its directory and just *points to* the inode. Topic 008 explains this fully. You need the idea now to understand why `mv` is fast.

## Why it exists

Everything on a Linux server is a file: configs, logs, programs, data. Creating, copying, moving and deleting files safely is the most basic admin skill. Doing it *wrong* (deleting the wrong path, copying without keeping permissions) causes real outages.

## Analogy

A **directory is a phone book**: a list of names, each pointing to a "house" (the inode, where the actual data lives).

- **Renaming** (`mv` on the same disk) just edits the name in the phone book. The house doesn't move, so it's instant.
- **Copying** builds a brand-new house with the same contents.
- **Deleting** removes the name from the phone book. The house is demolished only when no names point to it any more and nobody is inside.

## How it works inside

### Paths

| Path | Meaning | Example |
|---|---|---|
| **Absolute** | Starts at `/`. Works from anywhere | `/home/alice/docs` |
| **Relative** | Starts from your working directory | `docs/report.txt`, `../etc` |
| `.` | This directory | `./script.sh` |
| `..` | The parent directory (one level up) | `cd ..` |
| `~` | Your home directory | `cd ~` |
| `~alice` | Alice's home directory | `cd ~alice` |
| `-` (with `cd`) | The previous directory | `cd -` |

### File names

- **Case-sensitive**: `File`, `file` and `FILE` are three different files.
- Up to 255 bytes. Any character except `/` and the "null" byte is allowed, but avoid spaces, a leading `-`, and special characters like `* ? [ ] $ ; & |`. If a name has them, put it in quotes.
- **Hidden files** start with a dot (`.bashrc`). `ls` hides them unless you add `-a`.
- **Extensions are just a habit.** Linux doesn't care that a file ends in `.txt`. `file` looks at the content to guess the real type.

### Reading `ls -l`, column by column

```
-rw-r--r--. 1 alice alice 4096 Oct 20 11:05 notes.txt
│└───┬───┘│ │   │     │     │        │          └─ name
│    │    │ │   │     │     │        └─ last modified time (mtime)
│    │    │ │   │     │     └─ size in bytes
│    │    │ │   │     └─ group that owns it
│    │    │ │   └─ user who owns it
│    │    │ └─ link count: how many names point to this inode (topic 008)
│    │    └─ "." = has an SELinux label (topic 072); "+" = has extra ACL permissions (topic 027)
│    └─ permissions for owner / group / everyone else: r=read, w=write, x=execute (topic 026)
└─ type: - file, d directory, l symbolic link, b block device, c character device, s socket, p pipe
```

### The three timestamps

| Time | Changes when… | See it with |
|---|---|---|
| **mtime** (modify) | The **content** changes | `ls -l` |
| **ctime** (change) | The **inode** changes: permissions, owner, rename, link count | `ls -lc`, `stat` |
| **atime** (access) | The file is **read**. RHEL limits these updates with the `relatime` mount option, to save disk writes | `ls -lu`, `stat` |
| **birth** | Created (if the filesystem records it; XFS and ext4 do) | `stat` |

Note: "ctime" is **not** "creation time". This is a classic interview trick.

### What really happens on cp, mv and rm

- **`cp a b`**: creates a **new inode**, copies the bytes, and adds the name `b` in the directory. The copy gets *you* as owner and *new* timestamps, unless you ask to preserve them (`-p`, `-a`).
- **`mv a b` on the same filesystem**: only edits directory entries. The inode, data, owner and timestamps all stay. It's **instant**, even for a 100 GB file.
- **`mv` across filesystems** (for example, from `/home` to a USB disk): it must **copy then delete**, so it is slow for big files.
- **`rm a`**: removes the **name**. Data is freed only when the link count reaches 0 **and** no running program still has the file open (topic 008).
- **Deleting or renaming a file changes the *directory*, not the file.** So you need *write* permission on the **directory**. That's why you can sometimes delete a read-only file, or be unable to delete a file you own (topic 026).

There is **no recycle bin**. `rm` is permanent.

## Commands

```bash
pwd
```
```
/home/alice
```

```bash
cd /etc ; pwd ; cd - ; cd .. ; pwd ; cd
```
```
/etc
/home/alice
/home
```
- `cd -` jumps back to the previous directory and prints it. `cd ..` goes up one level. `cd` alone goes home.

```bash
ls -la ~
```
```
total 24
drwx------. 3 alice alice  95 Nov 16 10:02 .
drwxr-xr-x. 5 root  root   44 Nov 10 09:00 ..
-rw-------. 1 alice alice 812 Nov 16 10:01 .bash_history
-rw-r--r--. 1 alice alice  18 Oct  3 12:00 .bash_logout
-rw-r--r--. 1 alice alice 144 Oct  3 12:00 .bash_profile
-rw-r--r--. 1 alice alice 522 Oct  3 12:00 .bashrc
drwxr-xr-x. 2 alice alice   6 Nov 16 10:02 docs
```
- `-a` shows hidden files, including `.` (this directory) and `..` (the parent).
- The first letter `d` = directory, `-` = regular file.

Useful `ls` options:

| Option | Effect |
|---|---|
| `-l` | Long format (on RHEL, `ll` is an alias for it) |
| `-a` / `-A` | Show hidden files / same, without `.` and `..` |
| `-h` | Human-readable sizes (K, M, G) |
| `-d` | Show the directory itself, not its contents: `ls -ld /tmp` |
| `-R` | Recursive (go into subdirectories) |
| `-t` / `-r` / `-S` | Sort by time / reverse / sort by size. `ls -ltr` = newest at the bottom (great for logs) |
| `-i` | Show inode numbers |
| `-Z` | Show SELinux labels (topic 072) |

```bash
mkdir -p ~/project/src/lib
```
- `-p` = create **parent** directories as needed, with no error if they already exist. Without `-p`, `mkdir` fails because `project` doesn't exist yet.

```bash
mkdir -p ~/proj/{src,docs,tests}
ls ~/proj
```
```
docs  src  tests
```
- `{src,docs,tests}` is **brace expansion**: bash turns it into three words before `mkdir` runs (topic 013).

```bash
touch notes.txt ; stat notes.txt
```
```
  File: notes.txt
  Size: 0         	Blocks: 0          IO Block: 4096   regular empty file
Device: 8,4	Inode: 697072      Links: 1
Access: (0644/-rw-r--r--)  Uid: ( 1000/   alice)   Gid: ( 1000/   alice)
Context: unconfined_u:object_r:user_home_t:s0
Access: 2026-11-16 10:05:11.046819562 +0000
Modify: 2026-11-16 10:05:11.046819562 +0000
Change: 2026-11-16 10:05:11.046819562 +0000
 Birth: 2026-11-16 10:05:11.046819562 +0000
```
- `touch` creates an empty file, or updates the times of an existing one.
- `stat` shows everything in the inode: `Size` and `Blocks` (disk space used), `Inode` (its number), `Links` (link count), `Access (0644…)` (permissions as a number and letters, topic 026), `Uid/Gid` (owner and group), `Context` (SELinux label), and the four timestamps.
- `Device: 8,4` is the device the file lives on, as major,minor numbers (8,4 = `sda4`; `lsblk` shows the same pair). Timestamps are kept to the nanosecond.

```bash
file notes.txt /etc/passwd /usr/bin/ls
```
```
notes.txt:   empty
/etc/passwd: ASCII text
/usr/bin/ls: ELF 64-bit LSB pie executable, x86-64, version 1 (SYSV), dynamically linked ...
```

### Copy

```bash
cp notes.txt notes.bak
cp -v a.txt b.txt /tmp/
```
```
'a.txt' -> '/tmp/a.txt'
'b.txt' -> '/tmp/b.txt'
```
- With several sources, the **last** argument must be a directory. `-v` (verbose) prints each action.

| `cp` option | Effect |
|---|---|
| `-r` / `-R` | Recursive. **Needed to copy a directory** |
| `-i` / `-n` | Ask before overwriting / never overwrite |
| `-p` | Preserve permissions, owner and timestamps |
| `-a` | **Archive**: recursive and preserve everything (links, extra attributes, SELinux labels). Best for backups |
| `-u` | Copy only if the source is newer |
| `--backup=numbered` | Keep numbered backups of anything overwritten |

**`cp -r src dst` gotcha:** if `dst` already exists, you get `dst/src`. If it doesn't exist, `dst` *becomes* the copy.

```bash
sudo cp -a /etc/ssh/sshd_config{,.$(date +%F)}
ls -d /etc/ssh/sshd_config*
```
```
/etc/ssh/sshd_config  /etc/ssh/sshd_config.2026-11-16  /etc/ssh/sshd_config.d
```
- A classic "back up before editing" trick. `{,.$(date +%F)}` expands to two words: the name, and the name plus today's date (topics 013–014). `sudo` is needed because `/etc/ssh` belongs to root (topic 028).
- `ls -d` lists the matching names themselves. Without `-d`, the pattern also matches the `sshd_config.d` **directory**, and `ls` would print everything inside it too.

### Move and rename

```bash
mv notes.bak old-notes.txt          # rename
mv a.txt b.txt ~/docs/              # move several files into a directory
mv -i x y                           # ask before overwriting
```

### Remove

```bash
rm old-notes.txt
rm -i *.tmp                 # ask for each file (* means "any name", topic 013)
rm -r ~/project             # remove a directory and everything inside
rmdir ~/proj/tests          # only works on EMPTY directories (safe)
rm -- -weird-name           # name that starts with "-"
rm "my file.txt"            # name with a space: quote it
```

`rm -rf dir` (recursive, **f**orce, no questions) is the most dangerous everyday command. Check the path twice. Never run it with an empty variable:

```bash
rm -rf -- "${TARGET_DIR:?not set}/"*
```
- `${VAR:?msg}` makes bash **stop with an error** if `TARGET_DIR` is empty, instead of running `rm -rf /*` (topic 012).

**Root's safety aliases on RHEL:** `/root/.bashrc` makes `rm`, `cp` and `mv` ask before overwriting (`rm -i`, and so on). As root, `cp` will ask "overwrite?". Answer it, or bypass the alias with `\cp`. Ubuntu doesn't set these aliases.

### Downloading a file

```bash
curl -LO https://example.com/file.tar.gz
```
- `curl` fetches a URL (topic 070). `-O` saves it under the remote name, `-L` follows redirects. `wget URL` works too if it's installed.

### Try it
1. `mkdir -p ~/lab/{a,b}` then `touch ~/lab/a/f1` then `cp -a ~/lab/a ~/lab/c` then `ls -R ~/lab`.
2. Run `stat ~/lab/a/f1`, then `mv ~/lab/a/f1 ~/lab/b/`, then `stat ~/lab/b/f1`. The inode number is unchanged.
3. Create a file called `-x` with `touch -- -x`, then delete it.
4. Run `rmdir ~/lab/b` and read the error. Why does it fail?

## Where you'll use it

- **Before editing any config:** `cp -a file file.$(date +%F)`. You can roll back in seconds.
- **Log hunting:** `ls -ltr /var/log/` puts the most recently changed logs at the bottom.
- **Deployments:** `mv` (an atomic rename on the same filesystem) is how many tools switch a new release live. They write `app.new`, then `mv app.new app`. Readers see either the old file or the new one, never a half-written file.
- **SELinux trap:** `cp` gives the new file the label of the destination directory. `mv` **keeps the old label**. Moving web files from your home into `/var/www/html` can cause "403 Forbidden". Fix it with `restorecon -Rv /var/www/html` (topic 073).
- **Big or remote copies:** use `rsync -a` (topic 068). It can resume and only copies changes.

## When it breaks

| Error | Cause | Fix |
|---|---|---|
| `rmdir: failed to remove 'd': Directory not empty` | It has contents, often **hidden** files | `ls -A d`; then `rm -r d` if you're sure |
| `cp: -r not specified; omitting directory` | Copying a directory without `-r` | `cp -r` or `cp -a` |
| `rm: cannot remove 'x': Permission denied` on your own file | Deleting needs write permission on the **directory**; or the sticky bit (`/tmp`); or an "immutable" attribute | `ls -ld .`; `lsattr x` (topic 027) |
| `Argument list too long` | `rm *.log` expanded into too many names | `find . -name '*.log' -delete` (topic 020) |
| `No such file or directory` for a file that exists | A name with spaces wasn't quoted, so it split into words | Use quotes: `"my file"` |
| `Device or resource busy` | The target is a mount point or in use | `findmnt x`; unmount it first (topic 048) |
| `Read-only file system` | The filesystem is mounted read-only (maybe after disk errors) | `findmnt -no OPTIONS /path`; `dmesg` |
| `No space left on device` while copying | Out of space or inodes | `df -h`, `df -i` |

## Quick recap

- Absolute paths start at `/`; relative paths start from `pwd`. `.` `..` `~` `-` are shortcuts.
- `ls -l` shows type, permissions, link count, owner, group, size, mtime and name.
- `cp` makes a new inode; `mv` on the same filesystem just renames (instant); `rm` removes a name. No recycle bin.
- Use `cp -a` to keep everything, `mkdir -p` for nested paths, `rm -- -name` for odd names.

**Interview questions**

1. *Why is `mv` instant on the same filesystem but slow to another disk?* On the same filesystem only the directory entry changes; the inode and data stay put. Across filesystems the data must be copied, then the original deleted.
2. *Why can't you delete a file you own?* Deleting changes the directory, so you need write and execute permission on the directory. The sticky bit or an immutable attribute can also block it.
3. *What is ctime?* The time the inode (metadata) last changed: permissions, owner, rename. It is not the creation time.
