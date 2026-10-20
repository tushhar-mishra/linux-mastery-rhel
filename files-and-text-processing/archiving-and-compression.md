# Archiving & Compression

> **Sessions:** S8 · **Objective:** *Archive, compress, unpack, and uncompress files using tar, gzip, and bzip2* **[RHCSA Core]**
> **Related:** [Viewing files](viewing-and-creating-file-contents.md) · [Files & directories](../shell-and-command-line/files-and-directories.md) · [Finding files](finding-files.md) · [I/O redirection](io-redirection-and-pipes.md) · rsync & remote backups (S68) · SELinux contexts (S72–76)

## 1. Overview

- **Archiving** combines many files and directories, with their metadata (paths, permissions, ownership, timestamps), into one file. Tool: **`tar`**.
- **Compression** shrinks a single data stream. Tools: **`gzip`**, **`bzip2`**, **`xz`** (and `zstd`).
- `tar` doesn't compress by default; it pipes the archive through a compressor when you ask (`-z`, `-j`, `-J`). Result: `.tar.gz` / `.tgz`, `.tar.bz2`, `.tar.xz`.
- **`zip`** archives *and* compresses each file individually. It's common for Windows exchange but **not an exam objective**.

## 2. Key Concepts

### 2.1 Compressor comparison

| Tool | Extension | Algorithm | Speed (compress) | Ratio | Notes |
|---|---|---|---|---|---|
| `gzip` | `.gz` | DEFLATE | Fast | Good | Universal default; level `-1`…`-9` (default 6) |
| `bzip2` | `.bz2` | Burrows–Wheeler | Slower | Better | Default block size 900k (`-9`) |
| `xz` | `.xz` | LZMA2 | Slowest | Best | Decompresses faster than bzip2; more memory; `-T0` uses all cores |
| `zstd` | `.zst` | Zstandard | Very fast | Good to very good | Modern choice; `tar --zstd` **[Advanced]** |

### 2.2 Behavior shared by gzip, bzip2 and xz

- They compress **files, not directories** (`gzip: dir is a directory -- ignored`). Use `tar` for directories.
- They **replace** the original by default: `file.txt` → `file.txt.gz`. `-k` keeps it.
- With several files, each is compressed separately (`gzip a b` → `a.gz b.gz`).
- `-d` decompresses; `-c` writes to stdout (original untouched); `-t` tests integrity; `-v` verbose.

### 2.3 tar with compression vs zip

| | `tar.gz` / `tar.xz` | `zip` |
|---|---|---|
| Compression | Whole stream (better ratio) | Per file |
| Extract one file | Must decompress the stream up to it | Random access, fast |
| Unix metadata | Full (owner, mode, links; SELinux/ACL/xattrs with flags) | Limited |
| Typical use | Linux backups, software releases | Cross-platform exchange |

## 3. Commands & Syntax

### 3.1 gzip / bzip2 / xz

| Action | gzip | bzip2 | xz |
|---|---|---|---|
| Compress | `gzip f` | `bzip2 f` | `xz f` |
| Keep original | `gzip -k f` | `bzip2 -k f` | `xz -k f` |
| Decompress | `gunzip f.gz` / `gzip -d` | `bunzip2 f.bz2` / `bzip2 -d` | `unxz f.xz` / `xz -d` |
| To stdout | `gzip -c f > f.gz` | `bzip2 -c f > f.bz2` | `xz -c f > f.xz` |
| View | `zcat` / `zless` / `zmore` | `bzcat` / `bzless` / `bzmore` | `xzcat` / `xzless` / `xzmore` |
| Search inside | `zgrep pat f.gz` | `bzgrep pat f.bz2` | `xzgrep pat f.xz` |
| Info / ratio | `gzip -l f.gz` | — (`ls -l` to compare) | `xz -l f.xz` |
| Test integrity | `gzip -t` | `bzip2 -t` | `xz -t` |
| Level | `-1` fast … `-9` best | `-1` … `-9` | `-0` … `-9` (`-e` extreme) |

```bash
gzip -r dir/                   # compresses EACH file inside dir separately (rarely what you want)
gzip -9 -k big.log             # best compression, keep original
xz -T0 -k big.dump             # multi-threaded
```

> ⚠️ **Course corrections:**
> - In the bzip2 section, `cat file.txt.gz` and `bzcat file.txt.gz` should use `.bz2`.
> - `xless` is not a command; it's `xzless`.
> - `gzip -l` works only on `.gz` files; use `xz -l` for `.xz`.

### 3.2 tar

**Syntax:** `tar <mode> [options] -f <archive> [files…]`

| Mode | Meaning |
|---|---|
| `-c` | Create |
| `-x` | Extract |
| `-t` | List contents |
| `-r` / `-u` | Append / update (uncompressed archives only) **[Advanced]** |

| Option | Meaning |
|---|---|
| `-f FILE` | Archive file; **`f` must be immediately followed by the name** |
| `-v` | Verbose (list files processed) |
| `-z` / `-j` / `-J` / `--zstd` | gzip / bzip2 / xz / zstd |
| `-a` | Auto-select compression **from the archive suffix** when creating |
| `-C DIR` | Change to `DIR` first (extract target, or base for creation) |
| `-p` | Preserve permissions on extract (default for root) |
| `--selinux --acls --xattrs` | Store/restore SELinux contexts, ACLs and extended attributes |
| `--exclude=PATTERN` | Skip matching paths |
| `-T FILE` / `-T -` | Read the list of files to archive from a file or stdin |
| `--wildcards` | Allow globs in member names when extracting |
| `--strip-components=N` | Drop N leading path components on extract |
| `-k` | Don't overwrite existing files on extract |

```bash
# Create
tar -cvf  archive.tar      file1 file2 dir/        # no compression
tar -czvf archive.tar.gz   dir/                    # gzip
tar -cjvf archive.tar.bz2  dir/                    # bzip2
tar -cJvf archive.tar.xz   dir/                    # xz
tar -caf  archive.tar.xz   dir/                    # compression chosen from the suffix
tar -czf /root/etc.tar.gz -C / etc                 # store "etc/..." without the leading slash warning

# List (always list before extracting unknown archives)
tar -tvf  archive.tar.gz                           # GNU tar auto-detects compression for reading

# Extract
tar -xf  archive.tar.gz                            # -z optional: auto-detected
tar -xf  archive.tar.bz2 -C /tmp/restore           # into a specific directory (must exist)
tar -xzf backup.tar.gz etc/ssh/sshd_config         # one member: exact stored path
tar -xzf backup.tar.gz --wildcards '*.conf'        # members by pattern
```

**Leading `/`:** `tar -czf x.tar.gz /etc` prints `Removing leading '/' from member names` (informational, not an error). Members are stored as `etc/...`, so extraction lands under the current directory or `-C`. This protects you from overwriting the live `/etc` by accident.

> ⚠️ **Destructive:** Extracting **overwrites** existing files with the same paths, silently. Extract into a scratch directory (`-C /tmp/restore`) or use `-k` when unsure. Never extract an untrusted archive as root into `/`.

### 3.3 Splitting and joining large archives

```bash
tar -czf - /home/alice | split -b 500M - alice.tar.gz.part.    # parts: …part.aa, …part.ab, …
cat alice.tar.gz.part.* | tar -xzf - -C /tmp/restore           # glob order = correct order
```

### 3.4 Safe file lists with `find`

```bash
# Handles spaces/newlines in names
find /home/alice/docs -name '*.txt' -print0 | tar --null -T - -czf textfiles.tar.gz
```

### 3.5 zip / unzip **[Advanced/Optional]**

May need `dnf install zip unzip` on minimal systems.

```bash
zip archive.zip f1 f2                  # create
zip -r site.zip site/ -x '*.log'       # recursive, exclude pattern
unzip -l archive.zip ; zipinfo archive.zip   # list / detailed metadata
unzip archive.zip -d /tmp/out          # extract to a directory
unzip -p archive.zip f1                # print a member to stdout
unzip -n archive.zip                   # never overwrite existing files
unzip -u archive.zip                   # update existing files if newer AND create new ones
unzip -f archive.zip                   # freshen: update existing files only, add none
```

## 4. RHCSA Exam Focus **[RHCSA Core]**

**Typical task:** *"Create a bzip2-compressed tar archive of `/usr/local` named `/root/local.tar.bz2`."*

```bash
sudo tar -cjf /root/local.tar.bz2 /usr/local     # as root, so all files are readable
file /root/local.tar.bz2                         # → bzip2 compressed data, block size = 900k
sudo tar -tjf /root/local.tar.bz2 | head         # → usr/local/...
```

| Requirement in the task | Flag | Verify with `file` |
|---|---|---|
| gzip | `-z` | `gzip compressed data` |
| bzip2 | `-j` | `bzip2 compressed data` |
| xz | `-J` | `XZ compressed data` |

**Traps:**

- **Option order:** `tar -cvfz x.tar.gz dir` makes `z` the archive name. Keep `f` **last** in a bundle: `-czvf`.
- **Wrong compression for the requested extension** (e.g., `-z` with `.bz2`). `file` exposes it.
- **Exact archive path and name.** Graders check the exact file.
- **Running as a normal user** gives `Cannot open: Permission denied` and an incomplete archive (`Exiting with failure status due to previous errors`).
- **Unpack and uncompress** are in the objective too: practice `tar -xf … -C dir`, `gunzip`, `bunzip2`.

## 5. Production Practices **[Production Practice]**

- **Back up with metadata:** `tar --selinux --acls --xattrs -cpzf backup.tgz -C / etc home`.
- **Stay on one filesystem** and skip virtual ones: `--one-file-system`, or exclude `/proc`, `/sys`, `/dev`, `/run`.
- **Checksum and test:** `sha256sum backup.tgz > backup.tgz.sha256`; `tar -tzf backup.tgz >/dev/null && echo OK`. **A backup isn't real until a restore is tested.**
- **Stream over SSH without temp files:**

```bash
  tar -czf - /var/www | ssh backup@host 'cat > /backups/www-$(date +%F).tgz'
  ssh host 'tar -czf - /etc' | tar -xzf - -C /tmp/host-etc     # pull and extract locally
```

- **Don't hand-compress files in `/var/log`;** logrotate's `compress` directive manages that (S55).
- Prefer `xz -T0` or `zstd` for large artifacts; gzip for maximum compatibility.

## 6. Troubleshooting

| Message / symptom | Cause | Fix |
|---|---|---|
| `Removing leading '/' from member names` | Absolute paths given | Informational; or use `-C / etc` |
| `tar: z: Cannot open: No such file or directory` | `f` not directly before the archive name | Reorder: `-czf name` |
| `gzip: stdin: not in gzip format` | Wrong flag: archive is xz/bzip2/plain | `file archive`; or let tar auto-detect with `tar -xf` |
| `Not found in archive` | Member path differs (`./etc/x` vs `etc/x`) | `tar -tf` and copy the exact path |
| `Exiting with failure status due to previous errors` | Some files unreadable | Scroll up for `Permission denied`; run as root |
| `file changed as we read it` | Live files (logs, databases) | Snapshot first (LVM, S36), or stop the service, or accept for logs |
| `Unexpected EOF in archive` | Truncated download, missing split part, disk full during creation | Re-transfer; check all parts; `df -h` |
| `gzip: dir is a directory -- ignored` | Compressors don't take directories | `tar -czf dir.tar.gz dir` |
| Extracted files have wrong owner/permissions | Extracted as a normal user | Extract as root (preserves ownership); `-p` |

## 7. Interview Questions

| Question | Answer |
|---|---|
| Archiving vs compression? | Archiving bundles files and metadata (`tar`); compression reduces the size of one stream (`gzip`/`bzip2`/`xz`). |
| Why can't `gzip` compress a directory? | It's a single-stream compressor. Archive with `tar` first. |
| gzip vs bzip2 vs xz? | Speed vs ratio: gzip fastest, xz best ratio and slowest to compress, bzip2 in between. |
| `.tar.gz` vs `.zip`? | tar.gz compresses the whole stream (better ratio) and keeps Unix metadata; zip compresses per file (random access, cross-platform). |
| Why does tar strip the leading `/`? | Safety: extraction is relative, so restoring can't overwrite live system paths unexpectedly. |
| How do you back up and preserve SELinux labels? | `tar --selinux --acls --xattrs -cpf …`, then extract with the same flags. Otherwise run `restorecon` after restoring. |
| How do you extract a single file? | `tar -tf` to find the exact member path, then `tar -xf archive path/in/archive`. |
| How do you copy a directory to another host using tar? | `tar -czf - dir \| ssh host 'tar -xzf - -C /dest'`. |

## 8. Course Practice Questions (corrected)

| # | Task | Command | Note |
|---|---|---|---|
| 1 | gzip, keep original | `gzip -k myfile.txt` | |
| 2 | Extract `backup.tar` | `tar -xvf backup.tar` | |
| 3 | ZIP two files | `zip documents.zip file1.txt file2.txt` | Optional tool |
| 4 | Unzip into a directory | `unzip archive.zip -d /home/user/Documents/` | |
| 5 | tar.gz of the logs directory | `sudo tar -czvf backup.tar.gz /var/log/` | Path is `/var/log/`, not `/var/logs/` |
| 6 | List without extracting | `tar -tzvf data.tar.gz` | |
| 7 | tar.bz2 of `project/` | `tar -cjvf project.tar.bz2 project/` | |
| 8 | Extract tar.xz | `tar -xJvf backup.tar.xz` (or `tar -xf`) | |
| 9 | bzip2 several files | `bzip2 file1.log file2.log file3.log` | Separate `.bz2` per file |
| 10 | Unzip, update if newer | `unzip -u archive.zip` | Also adds new files; `-f` only refreshes |
| 11 | Zip `/etc`, exclude `*.log` | `sudo zip -r etc_backup.zip /etc/ -x '*.log'` | Root needed to read all of `/etc` |
| 12 | Archive found `.txt` files | `find /home/user/docs -name '*.txt' -print0 \| tar --null -T - -czf textfiles.tar.gz` | Safe with spaces |
| 13 | Unzip without overwriting | `unzip -n project.zip` | |
| 14 | Extract one file | `tar -tzf backup.tar.gz \| grep config.cfg` then `tar -xzf backup.tar.gz <exact/path/config.cfg>` | Exact stored path required |
| 15 | xz all logs, keep originals | `xz -k /var/log/*.log` | Works, but let logrotate manage `/var/log` |
| 16 | Compression ratio | `gzip -l report.txt.gz` | |
| 17 | Split into 500 MB parts | `tar -cvf - /home/user/ \| split -b 500M - user_backup.tar.part` | |
| 18 | Join and extract | `cat user_backup.tar.part* \| tar -xvf -` | |

> ⚠️ **Course correction:** `tar -cvf myarchive.tar my_directory/` creates `myarchive.tar`, not `archive.tar` as the notes state.

## 9. Quick Revision

```bash
tar -czf x.tar.gz dir | -cjf x.tar.bz2 | -cJf x.tar.xz | -caf (by suffix)
tar -tf x.tar.* | tar -xf x.tar.* -C /dest | tar -xf x.tar.gz exact/member
gzip -k f | gunzip f.gz | bzip2 -k f | bunzip2 f.bz2 | xz -k f | unxz f.xz
zcat / bzcat / xzcat | zgrep / bzgrep / xzgrep | file archive (verify type)
f LAST in the option bundle | run as root for system dirs | --selinux --acls --xattrs
```

## 10. Cross-References

- [Viewing files](viewing-and-creating-file-contents.md)
- [Finding files (find + tar)](finding-files.md)
- [I/O redirection (streams, split)](io-redirection-and-pipes.md)
- rsync & cron-based backups (S68): `networking-and-ssh/` (planned)
- LVM snapshots for consistent backups (S36): `storage-and-filesystems/` (planned)
- Log rotation & journal (S55): `logs-scheduling-and-packages/` (planned)
