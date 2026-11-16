# 020 · Finding Files: find, locate, xargs and lsof

> **You need first:** [019 · awk](019-awk.md)
> **Next:** [021 · Archiving and compression](021-archiving-and-compression.md)

---

## What it is

| Tool | Job |
|---|---|
| `find` | Walks the directory tree **live** and finds files by name, type, size, age, owner, permissions… then can act on them |
| `locate` | Searches a **pre-built index** of file paths. Very fast, but only as fresh as the last index update. RHEL and Ubuntu use **plocate** |
| `xargs` | Turns a list of names coming in on stdin into **arguments** for another command |
| `lsof` | **L**ist **o**pen **f**iles: which program has which file (or network port) open right now |
| `which`, `type` | Find a **command** in PATH (topic 005) |
| `rpm -qf` / `dpkg -S` | Which package owns a file |

## Why it exists

Servers have hundreds of thousands of files. You constantly need answers like: where is this config? What filled the disk? Which files changed in the last hour? Which files does a deleted user still own? Which programs are setuid root? Which process is holding this deleted log? These tools answer all of them.

## Analogy

- `find` is **walking through every room of a building** checking each item against your list: always accurate, but slow in a big building.
- `locate` is **looking it up in the building's printed directory**: instant, but it doesn't know about anyone who moved in since it was printed.
- `lsof` is **asking reception who is currently using which room**.

## How it works inside

### find

`find` starts at the directories you give it and reads each directory's entries one by one, going down into subdirectories (recursion). For each entry it reads the inode (topic 008) where needed and evaluates your **expression** from **left to right**:

```
find  /etc  -type f  -name '*.conf'  -mtime -7  -print
      start  test     test             test       action
```

- Tests joined with nothing between them mean **AND**. As soon as one test is false, find skips the rest for that file (short-circuit).
- The default start is `.`; the default action is `-print`.
- **Order matters for actions.** `find . -delete -name x` deletes **everything**, because `-delete` runs before `-name` is checked.
- **AND binds tighter than OR.** In `find . -name '*.log' -o -name '*.txt' -delete`, the `-delete` belongs only to the `*.txt` side. Use `\( … \)` to group.

On big trees, find is disk-heavy. That's why `-xdev` (stay on one filesystem) and `-maxdepth` matter, and why you run it at low priority on busy servers.

### locate

A daily systemd timer runs `updatedb`, which walks the whole filesystem once and writes all paths into a compact database (`/var/lib/plocate/plocate.db`). `locate` just searches that file, so it's instant. Files created after the last `updatedb` are invisible, and deleted ones still show up. plocate also checks that **you** are allowed to see a path before printing it.

### xargs

Some commands want file names as **arguments**, not on stdin (like `rm`, `cp`, `chmod`). `xargs` reads names from stdin and builds command lines out of them, packing as many names as fit per run (like `-exec … +`). By default it splits on spaces and newlines, which **breaks on file names with spaces**. The safe pair is `find … -print0 | xargs -0`: names are separated by the NUL byte, which can never appear in a file name.

### lsof

Every process's open files are visible in `/proc/<PID>/fd/` (topic 092). `lsof` reads that for every process and prints a table. Network connections are open "files" too, so `lsof -i :80` finds who is using port 80.

## Commands

### Tests

| Test | Meaning | Example |
|---|---|---|
| `-name` / `-iname` | File name matches a glob (case-sensitive / not) | `-name '*.log'` |
| `-path` | The whole path matches a glob | `-path '*/ssh/*'` |
| `-regex` | The **whole path** matches a regex | `-regex '.*\.sh'` |
| `-type` | `f` file, `d` directory, `l` symlink, `b`/`c` device, `s` socket, `p` pipe | `-type d` |
| `-size` | `c` bytes, `k` KiB, `M` MiB, `G` GiB; `+` more than, `-` less than | `-size +100M` |
| `-mtime` / `-atime` / `-ctime` | Days since modified / accessed / inode changed | `-mtime +30` |
| `-mmin` / `-amin` / `-cmin` | Same, in minutes | `-mmin -60` |
| `-newer FILE` | Modified more recently than FILE | `-newer /etc/passwd` |
| `-user` / `-group` / `-uid` | Owner | `-user alice` |
| `-nouser` / `-nogroup` | The owner or group no longer exists | |
| `-perm MODE` / `-perm -MODE` / `-perm /MODE` | Permissions exactly MODE / **all** these bits set / **any** of these bits set (topic 026) | `-perm -4000` |
| `-empty` | Empty file or directory | |
| `-samefile F` / `-inum N` / `-links N` | Hard links of F / by inode / by link count | |
| `-xtype l` | **Broken** symlinks | |
| `-maxdepth N` / `-mindepth N` | Limit how deep to go (put these first) | `-maxdepth 1` |
| `-xdev` | Don't enter other filesystems | `find / -xdev …` |

**Time rounding** (whole 24-hour periods, rounded down):

| Expression | Meaning |
|---|---|
| `-mtime -1` | Modified less than 24 hours ago |
| `-mtime 1` | Between 24 and 48 hours ago |
| `-mtime +7` | **8 or more** full days ago (not "more than 7") |

**Size rounding:** sizes round **up** to the unit. `-size -1M` therefore matches only **empty** files. For precision use `-size -1024k`.

### Operators and actions

| Operator | Meaning |
|---|---|
| (nothing) or `-a` | AND |
| `-o` | OR |
| `!` or `-not` | NOT |
| `\( … \)` | Grouping (spaces around the brackets are required) |

| Action | Effect |
|---|---|
| `-print` / `-print0` | Print names (NUL-separated for `xargs -0`) |
| `-ls` | Detailed listing |
| `-printf '%s %p\n'` | Custom format (`%s` size, `%p` path, `%u` user, `%TY-%Tm-%Td` date) |
| `-exec cmd {} \;` | Run cmd **once per file** (`{}` = the file name) |
| `-exec cmd {} +` | Run cmd with **many files at once** (much faster) |
| `-ok cmd {} \;` | Like `-exec`, but asks first |
| `-delete` | Delete matches. **Must be last** |
| `-prune` | Don't go into this directory |

### Examples

```bash
find /etc -name '*.conf' -mtime -1
```
```
/etc/chrony.conf
/etc/resolv.conf
```
- Config files changed in the last 24 hours. A great first question in "what changed?" incidents.

```bash
sudo find /var -xdev -type f -size +100M -exec ls -lh {} + 2>/dev/null
```
```
-rw-r-----. 1 root root 1.2G Nov 16 11:55 /var/log/app/debug.log
-rw-r--r--. 1 root root 340M Nov 10 03:00 /var/cache/dnf/rhel-appstream.solv
```
- Big files on the `/var` filesystem. `{} +` passes them all to one `ls`.

```bash
sudo find / -xdev -type f -size +500M -printf '%s\t%p\n' 2>/dev/null | sort -n | tail
```
- Size in bytes and path, sorted biggest last.

```bash
find . -name '*.log' -o -name '*.txt' -print            # prints only .txt files! (precedence)
find . \( -name '*.log' -o -name '*.txt' \) -print       # ✔ both
```

```bash
sudo find / -xdev -type f -perm -4000 2>/dev/null
```
```
/usr/bin/passwd
/usr/bin/su
/usr/bin/sudo
/usr/bin/mount
...
```
- **SUID** programs: they run with their owner's (root's) rights (topic 027). Any unexpected entry here is a security red flag.

```bash
sudo find / -xdev \( -nouser -o -nogroup \) 2>/dev/null
```
- Files left behind by deleted users.

```bash
sudo mkdir -p /root/found
sudo find / -xdev -user harry -type f -exec cp -a {} /root/found/ \; 2>/dev/null
```
- Copy everything owned by `harry`, keeping attributes. (Files with the same name overwrite each other; `cp --parents` keeps the directory structure.)

```bash
find /tmp -maxdepth 1 -type f -mtime +7 -print     # 1) REVIEW first
find /tmp -maxdepth 1 -type f -mtime +7 -delete    # 2) then delete (‑delete LAST)
```
- **Safe deletion habit:** run with `-print`, check the list, then switch to `-delete`. Prefer `-type f` so directories aren't removed by accident.

```bash
find /var/www -type d -exec chmod 755 {} +
find /var/www -type f -exec chmod 644 {} +
```
- Different permissions for directories and files: a very common fix (topic 026).

```bash
find / -path /proc -prune -o -name 'core.*' -print
```
- Skip `/proc` entirely while searching everything else.

### xargs

```bash
find . -name '*.tmp' -print0 | xargs -0 -r rm -f
```
- `-0` matches `-print0`, which is safe with spaces. `-r` means "don't run at all if there's no input".

```bash
cat hosts.txt | xargs -n1 -I{} ping -c1 -W1 {}
```
- `-n1` = one argument per command; `-I{}` = put the argument where `{}` is.

```bash
find /var/log -name '*.log' -print0 | xargs -0 -P4 -n1 gzip
```
- `-P4` runs 4 at a time, in parallel.

### locate

```bash
sudo dnf install -y plocate       # Ubuntu: sudo apt install plocate
sudo updatedb
locate sshd_config
```
```
/etc/ssh/sshd_config
/etc/ssh/sshd_config.d
/usr/share/man/man5/sshd_config.5.gz
```
- A substring match on full paths. `-i` ignores case; `-c` counts; `-l 5` limits results; `-b '\name'` matches the exact base name.
- Quote patterns: `locate '*.conf'`.
- Excluded paths are configured in `/etc/updatedb.conf`.

### lsof

```bash
sudo lsof /var/log/messages
```
```
COMMAND  PID USER FD   TYPE DEVICE SIZE/OFF   NODE NAME
rsyslogd 812 root 7w   REG  253,0  612455 1048630 /var/log/messages
```
- `rsyslogd` (PID 812) has it open on file descriptor 7, for writing (`w`).

```bash
sudo lsof +L1                 # deleted files still held open (topic 008)
sudo lsof -u alice            # everything alice's processes have open
sudo lsof -p 812              # everything one process has open
sudo lsof -i :22              # who is using TCP/UDP port 22
sudo lsof +D /mnt/data        # who is using anything under /mnt/data (why can't I unmount?)
```

`fuser` gives a shorter answer: `sudo fuser -vm /mnt/data` lists processes using a mount.

### Which package owns a file?

```bash
rpm -qf /etc/ssh/sshd_config        # RHEL
dpkg -S /etc/ssh/sshd_config        # Ubuntu/Debian
rpm -ql openssh-server              # list every file a package installed
```

### Try it
1. Find every file in `/etc` changed in the last 2 days.
2. Find the 5 largest files on the root filesystem (`-xdev`, `-printf`, `sort`).
3. List all SUID files and compare the list with a colleague's machine.
4. Create files `a b.txt` and `c.txt` in `/tmp/x`, then delete them using `find -print0 | xargs -0`.
5. Install plocate, run `updatedb`, create a new file, and see that `locate` misses it until you run `updatedb` again.

## Where you'll use it

- **Disk full:** `find / -xdev -size +500M`, then `du` to drill down (topic 006).
- **"What changed?":** `find /etc -mmin -60` after an incident.
- **Security audits:** SUID/SGID files, world-writable files (`-perm -0002`), files with no owner.
- **Cleanup jobs:** `find /data/tmp -type f -mtime +7 -delete` in a cron or systemd timer (topic 039).
- **"Device is busy" when unmounting:** `lsof +D /mnt/x` or `fuser -vm /mnt/x`.
- **"Port already in use":** `lsof -i :8080` (or `ss -ltnp`, topic 095).
- **Kubernetes nodes:** `find /var/lib/containerd -size +1G`, or `lsof +L1` when node disk pressure doesn't go down.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| Screens of `Permission denied` | Directories you can't read | `2>/dev/null`, or run as root |
| `paths must precede expression` | Unquoted glob expanded by the shell | Quote it: `-name '*.conf'` |
| `missing argument to '-exec'` | Forgot `\;` or `+` | End `-exec` correctly |
| `-delete` removed too much | Action before the tests, or OR precedence | Test with `-print`; use `\( \)` |
| `xargs` breaks on spaces | Newline-separated input | `-print0 \| xargs -0` |
| `locate` misses new files or shows deleted ones | Stale index | `sudo updatedb` |
| find makes the server slow | Heavy disk reads | `-xdev`, `-maxdepth`, `nice -n19 ionice -c3 find …` |

## Quick recap

- `find START tests actions`. Quote patterns. AND is the default; group ORs with `\( \)`. `-delete` goes last, after a `-print` dry run.
- Time: `-mtime -1` (< 24 h), `+7` (≥ 8 days). Size: `+100M`. Permissions: `-perm -4000` (all bits) vs `/6000` (any bit).
- `-exec … +` or `-print0 | xargs -0` for many files safely.
- `locate` = fast, index-based, maybe stale. `lsof` = who has a file or port open.

**Interview questions**

1. *`find` vs `locate`?* `find` walks the filesystem live with rich criteria and actions. `locate` searches a pre-built index: much faster but possibly out of date.
2. *`-exec {} \;` vs `-exec {} +`?* `\;` runs the command once per file; `+` passes many files to each run, which is far faster.
3. *How do you find SUID files?* `find / -xdev -type f -perm -4000 2>/dev/null`.
