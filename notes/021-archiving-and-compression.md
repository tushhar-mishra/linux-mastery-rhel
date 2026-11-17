# 021 · Archiving and Compression: tar, gzip, bzip2, xz, zstd, zip

> **You need first:** [020 · Finding files](020-finding-files.md)
> **Next:** [022 · Users and accounts](022-users-and-accounts.md)

---

## What it is

Two different jobs that are often done together:

- **Archiving** packs many files and directories, **with their details** (paths, permissions, owners, timestamps, links), into **one file**. The tool is **`tar`** (from "**t**ape **ar**chive", because it was first used for backup tapes).
- **Compression** makes **one stream of data** smaller. Tools: **`gzip`** (`.gz`), **`bzip2`** (`.bz2`), **`xz`** (`.xz`), **`zstd`** (`.zst`).

`tar` can call a compressor for you, giving `.tar.gz` (also `.tgz`), `.tar.bz2`, `.tar.xz` and `.tar.zst`. **`zip`** does both jobs in one tool, compressing each file separately. It is common when swapping files with Windows users.

## Why it exists

- **Backups:** one file is easy to copy, checksum and store.
- **Moving software and data:** releases, logs for a support ticket, a whole directory sent to another server.
- **Saving space and bandwidth:** text logs often shrink by 90%.
- **Containers:** a container image is literally a stack of tar archives (one per layer, topic 097/101).

## Analogy

`tar` is **packing a moving box**: you put many items in, each with a label saying which room it came from. Compression is **vacuum-sealing the box** so it takes less space. You can pack without sealing (`.tar`), and you can only vacuum-seal one thing at a time, which is why you pack first.

## How it works inside

### tar format

A tar file is simple: for each file, a **512-byte header** (name, size, mode, owner, timestamps, type), then the file's data rounded up to 512-byte blocks. At the end come two empty blocks. There is no central table of contents, so to list or find one member, tar must read through the archive from the start.

When you add `-z`, tar starts `gzip` and **pipes** (topic 016) its output through it. The compressor sees one long stream, which gives better compression than compressing each file separately (like zip does). The cost: getting one file out of a `.tar.gz` means decompressing everything before it.

### Compressors compared

| Tool | Extension | Speed | Size | Notes |
|---|---|---|---|---|
| `gzip` | `.gz` | Fast | Good | The universal default. Levels `-1` (fast) to `-9` (small); default 6 |
| `bzip2` | `.bz2` | Slower | Better | Older; mostly replaced by xz |
| `xz` | `.xz` | Slowest to compress | Best | Decompresses quickly. `-T0` uses all CPU cores. Used for kernel and distro packages |
| `zstd` | `.zst` | **Very fast** | Good to very good | The modern choice. Used by Linux kernels, Fedora packages and container layers. `tar --zstd` |

### Shared rules for gzip, bzip2 and xz

- They compress **files, not directories**: `gzip: dir is a directory -- ignored`. Use `tar` for directories.
- They **replace** the original: `file.txt` becomes `file.txt.gz`. Use `-k` to keep it.
- With several files, each is compressed **separately** (`gzip a b` → `a.gz b.gz`).
- `-d` decompresses, `-c` writes to stdout (original untouched), `-t` tests integrity, `-v` shows details.

### The leading `/`

`tar -czf etc.tar.gz /etc` prints `Removing leading '/' from member names`. This is **not an error**. tar stores `etc/passwd`, not `/etc/passwd`, so extracting later puts files **under your current directory** (or `-C DIR`) instead of overwriting the live `/etc`. It's a safety feature.

## Commands

### gzip / bzip2 / xz

| Action | gzip | bzip2 | xz |
|---|---|---|---|
| Compress | `gzip f` | `bzip2 f` | `xz f` |
| Keep the original | `gzip -k f` | `bzip2 -k f` | `xz -k f` |
| Decompress | `gunzip f.gz` | `bunzip2 f.bz2` | `unxz f.xz` |
| View without unpacking | `zcat` / `zless` | `bzcat` / `bzless` | `xzcat` / `xzless` |
| Search inside | `zgrep pat f.gz` | `bzgrep` | `xzgrep` |
| Show ratio | `gzip -l f.gz` | — | `xz -l f.xz` |
| Test | `gzip -t f.gz` | `bzip2 -t` | `xz -t` |

```bash
sudo cp /var/log/messages /tmp/m ; sudo chown $USER: /tmp/m     # the log is readable only by root
ls -lh /tmp/m ; gzip -k -9 /tmp/m ; gzip -l /tmp/m.gz
```
```
-rw-------. 1 alice alice 527K Nov 16 23:11 /tmp/m
         compressed        uncompressed  ratio uncompressed_name
              84929              538856  84.2% /tmp/m
```
- A text log shrank by about 84%. Logs compress very well because they repeat the same words.

```bash
sudo zgrep -c sshd /var/log/messages-20261110
```
```
37
```
- `zgrep` searches compressed **and** plain files, so the same command works however a log was rotated.
- On RHEL, rotated logs are **not compressed** by default (`#compress` is commented out in `/etc/logrotate.conf`), so you see `messages-20261110` rather than `.gz`. Many sites turn `compress` on; Ubuntu compresses by default (`syslog.2.gz`).

### tar

**Syntax:** `tar MODE [options] -f ARCHIVE [files…]`

| Mode | Meaning |
|---|---|
| `-c` | Create |
| `-x` | Extract |
| `-t` | List contents |
| `-r` / `-u` | Append / update (uncompressed archives only) |

| Option | Meaning |
|---|---|
| `-f FILE` | The archive file. **`f` must come last in a bundle, right before the name** |
| `-v` | Verbose: list each file |
| `-z` / `-j` / `-J` / `--zstd` | gzip / bzip2 / xz / zstd |
| `-a` | Choose compression from the archive name's suffix |
| `-C DIR` | Change to DIR first (where to extract, or where to create from) |
| `-p` | Keep permissions on extract (automatic for root) |
| `--selinux --acls --xattrs` | Also store/restore SELinux labels, ACLs and extended attributes |
| `--exclude=PATTERN` | Skip matching paths |
| `-T FILE` | Read the list of files to archive from a file (`-T -` = stdin) |
| `--one-file-system` | Don't cross into other mounted filesystems |
| `--wildcards` | Allow glob patterns when extracting specific members |
| `--strip-components=N` | Drop the first N directories from each path on extract |
| `-k` | Don't overwrite existing files on extract |

```bash
sudo tar -czvf /root/etc-backup.tar.gz -C / etc
```
```
etc/
etc/fstab
etc/crypttab
...
```
- `-C / etc` = "go to `/`, then archive `etc`". It stores paths as `etc/...` with no warning.

```bash
sudo tar -tvf /root/etc-backup.tar.gz | head -3
```
```
drwxr-xr-x root/root         0 2026-11-16 23:11 etc/
-rw-r--r-- root/root       732 2026-11-16 20:21 etc/fstab
-rw------- root/root         0 2026-09-14 12:44 etc/crypttab
```
- **Always list before extracting an archive you didn't make.** The columns are permissions, owner/group, size, date and stored path.
- `sudo` is needed only because the archive sits in `/root`, which normal users can't enter. The order is the order tar met the files on disk, not alphabetical.

```bash
mkdir -p /tmp/restore
sudo tar -xf /root/etc-backup.tar.gz -C /tmp/restore
ls /tmp/restore/etc | head -3
```
- `-z` isn't needed when reading: GNU tar detects the compression itself.

```bash
sudo tar -xzf /root/etc-backup.tar.gz -C /tmp/restore etc/ssh/sshd_config
tar -xzf app.tar.gz --wildcards '*.conf'
```
- Extract one member, using the **exact stored path** shown by `tar -t`. Or extract by pattern.

```bash
sudo file /root/etc-backup.tar.gz
```
```
/root/etc-backup.tar.gz: gzip compressed data, from Unix, original size modulo 2^32 22200320
```
- Confirms the real compression type, whatever the file name says.

**Extracting overwrites existing files silently.** When unsure, extract into a scratch directory (`-C /tmp/restore`) or use `-k`. Never extract an untrusted archive as root into `/`.

### Backups the right way

```bash
sudo tar --selinux --acls --xattrs -cpzf /backup/etc-$(date +%F).tgz -C / etc
sha256sum /backup/etc-2026-11-16.tgz > /backup/etc-2026-11-16.tgz.sha256
tar -tzf /backup/etc-2026-11-16.tgz > /dev/null && echo "archive readable"
```
```
archive readable
```
- Keep SELinux labels, ACLs and extended attributes; store a checksum; test that the archive can be read. **A backup isn't real until you've tested a restore.**

### Streaming over SSH (no temporary file)

```bash
tar -czf - /var/www | ssh backup@host 'cat > /backups/www-$(date +%F).tgz'
ssh web1 'sudo tar -czf - /etc' | tar -xzf - -C /tmp/web1-etc
```
- `-f -` means "the archive is stdout/stdin". The data flows straight through the SSH connection (topic 065).

### Many files from find (safe with spaces)

```bash
find ~/docs -name '*.txt' -print0 | tar --null -T - -czf textfiles.tar.gz
```

### Splitting big archives

```bash
tar -czf - /home/alice | split -b 500M - alice.tgz.part.
cat alice.tgz.part.* | tar -xzf - -C /tmp/restore
```

### zip and unzip

```bash
sudo dnf install -y zip unzip
zip -r site.zip site/ -x '*.log'    # recursive, excluding *.log
unzip -l site.zip                   # list
unzip site.zip -d /tmp/out          # extract into a directory
unzip -n site.zip                   # never overwrite
```

### zstd

```bash
sudo dnf install -y zstd                # not part of a minimal install
tar --zstd -cf logs.tar.zst /var/log/app
zstd -19 -T0 big.dump               # max compression, all cores
```

### Try it
1. Create `/tmp/proj` with a few files. Make `.tar.gz`, `.tar.bz2` and `.tar.xz` versions of it, then compare sizes with `ls -lh`.
2. Run `file` on each archive, then rename one to a wrong extension and run `file` again.
3. List one archive with `tar -tvf`, then extract a single file from it into `/tmp/restore`.
4. Try `tar -cvfz x.tar.gz /tmp/proj` and read the error. Then fix the option order.

## Where you'll use it

- **Config backups before changes:** `tar czf /root/etc-$(date +%F).tgz -C / etc`.
- **Support bundles:** collecting logs to send to a vendor (`sosreport` on RHEL does this for you).
- **Software releases:** `curl -LO …/app-1.2.tar.gz && tar -xzf app-1.2.tar.gz`. `--strip-components=1` drops the top-level folder.
- **Moving data between servers:** `tar | ssh` when rsync isn't available.
- **Containers:** `docker save` / `podman save` output a tar; image layers are tar files (topic 101). `kubectl cp` uses tar under the hood, which is why it fails in containers without `tar`.
- **Logs:** logrotate compresses old logs with gzip automatically (topic 038). Don't compress files in `/var/log` by hand.

## When it breaks

| Message / symptom | Cause | Fix |
|---|---|---|
| `Removing leading '/' from member names` | You gave absolute paths | Informational. Or use `-C / etc` |
| `tar: z: Cannot open: No such file or directory` | `f` wasn't directly before the archive name (`-cvfz`) | Reorder: `-czvf name` |
| `gzip: stdin: not in gzip format` | The archive is xz, bzip2 or plain tar | `file archive`; or just `tar -xf` (auto-detect) |
| `Not found in archive` | The member path differs (`./etc/x` vs `etc/x`) | `tar -tf` and copy the exact path |
| `Exiting with failure status due to previous errors` | Some files couldn't be read | Scroll up for `Permission denied`; run as root |
| `file changed as we read it` | A live file (log, database) changed during the backup | Use a snapshot (topic 052) or stop the service; usually fine for logs |
| `Unexpected EOF in archive` | Truncated download, missing split part, or the disk filled while creating it | Re-download; check all parts; `df -h` |
| Extracted files have the wrong owner | Extracted as a normal user | Extract as root to keep ownership |
| Restored web files give "403 Forbidden" | SELinux labels lost | Archive with `--selinux`, or run `restorecon -R` after restoring (topic 073) |

## Quick recap

- `tar` archives (many files + metadata); `gzip`/`bzip2`/`xz`/`zstd` compress one stream.
- Create `tar -czf x.tgz dir` · list `tar -tf x.tgz` · extract `tar -xf x.tgz -C dest`. `f` goes last in the bundle.
- Compressors replace the original (`-k` keeps it) and can't take directories. `zcat`/`zgrep` read without unpacking.
- For backups: run as root, add `--selinux --acls --xattrs`, store a checksum, and test the restore.

**Interview questions**

1. *Archiving vs compression?* Archiving bundles many files and their metadata into one (tar). Compression shrinks a single stream of data (gzip, xz, zstd).
2. *Why does tar remove the leading `/`?* So extraction is relative to the current directory and can't accidentally overwrite live system files.
3. *How do you copy a directory to another server without a temp file?* `tar -czf - dir | ssh host 'tar -xzf - -C /dest'`.
