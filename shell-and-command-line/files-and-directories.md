# Working with Files & Directories

> **Sessions:** S6 (practice) · theory supplemented · **Objective:** *Create, delete, copy, and move files and directories* **[RHCSA Core]**
> **Related:** [Filesystem hierarchy](../linux-fundamentals/filesystem-hierarchy.md) · [Shell basics](shell-basics-and-command-syntax.md) · [Expansion & globbing](shell-expansion-and-globbing.md) · [Finding files](../files-and-text-processing/finding-files.md) · [File permissions](../users-groups-and-permissions/file-permissions.md) · [Links & inodes](../users-groups-and-permissions/links.md) · [SELinux file contexts](../firewall-and-selinux/selinux-file-contexts.md)

## 1. Overview

All files live in one tree under `/`. Directories are files that map **names → inodes**; the inode holds the metadata (owner, mode, timestamps, data block locations). Understanding this explains why `mv` is instant within a filesystem, why deleting depends on **directory** permissions, and how [hard and symbolic links](../users-groups-and-permissions/links.md) work.

## 2. Key Concepts

### 2.1 Paths

| Path | Meaning | Example |
|---|---|---|
| Absolute | Starts at `/`; works from anywhere | `/home/alice/docs` |
| Relative | From the current directory | `docs/report.txt`, `../etc` |
| `.` | Current directory | `./script.sh` |
| `..` | Parent directory | `cd ..` |
| `~` / `~alice` | Your home / alice's home | `cd ~alice` |
| `-` (with `cd`) | Previous directory (`$OLDPWD`) | `cd -` |

### 2.2 Filenames

- **Case-sensitive:** `File`, `file` and `FILE` are three different files.
- Up to 255 bytes. Any character except `/` and NUL is allowed.
- Avoid spaces, leading `-` and shell metacharacters (`* ? [ ] $ ; & |`). If you must use them, quote.
- **Hidden files** start with `.` (`.bashrc`). Show them with `ls -a` or `ls -A`.
- **Extensions are only conventions.** `file` identifies type by content ("magic").

### 2.3 Reading `ls -l`

```
-rw-r--r--. 1 alice alice 4096 Oct 20 11:05 notes.txt
│└──┬────┘│ │   │     │     │        │          └ name
│   │     │ │   │     │     │        └ modification time (mtime)
│   │     │ │   │     │     └ size in bytes (device files show "major, minor" instead)
│   │     │ │   │     └ group
│   │     │ │   └ owner
│   │     │ └ hard link count
│   │     └ "." = SELinux context only; "+" = ACL present
│   └ permissions user/group/other
└ type: - file, d directory, l symlink, b block dev, c char dev, s socket, p pipe
```

Details: [file permissions](../users-groups-and-permissions/file-permissions.md) · [special permissions & ACLs](../users-groups-and-permissions/special-permissions-and-acls.md) · [links](../users-groups-and-permissions/links.md).

### 2.4 Timestamps

| Time | Changes when | View |
|---|---|---|
| mtime | Content modified | `ls -l` |
| ctime | Metadata (inode) changed: perms, owner, links, rename | `ls -lc`, `stat` |
| atime | Read (RHEL mounts use `relatime`, so updates are limited) | `ls -lu`, `stat` |
| birth | Creation (if the filesystem supports it, e.g., XFS) | `stat` |

## 3. Commands & Syntax

### 3.1 Navigation and listing

```bash
pwd                      # print working directory (-P resolves symlinks)
cd /etc ; cd ; cd ~ ; cd - ; cd .. ; cd ~alice
```

| `ls` option | Effect |
|---|---|
| `-l` | Long format (RHEL alias: `ll` = `ls -l --color=auto`) |
| `-a` / `-A` | All files incl. hidden / same without `.` and `..` |
| `-h` | Human-readable sizes (with `-l`) |
| `-d` | List the directory itself, not its contents: `ls -ld /tmp` |
| `-R` | Recursive |
| `-t` / `-r` / `-S` | Sort by time / reverse / sort by size (`ls -ltr` = newest last) |
| `-i` | Inode numbers |
| `-Z` | SELinux context |
| `-1` / `-F` | One per line / append type indicator (`/`, `*`, `@`) |

### 3.2 Directories

```bash
mkdir dir1 dir2                       # several at once
mkdir -p ~/testdir/newdir/mydir       # create parents; no error if it exists
mkdir -m 750 /srv/project             # set mode at creation (ignores umask)
mkdir -p proj/{src,docs,tests}        # brace expansion
rmdir dir                             # ONLY removes empty directories
rmdir -p a/b/c                        # remove c, then b, then a, if each is empty
rm -r dir                             # remove a directory and its contents
```

### 3.3 Files

```bash
touch file.txt                        # create if missing, else update timestamps
touch -d "2026-01-01 10:00" file.txt  # set a specific timestamp
file report.pdf /etc/passwd /usr/bin/ls
# report.pdf: PDF document, version 1.7 · /etc/passwd: ASCII text · /usr/bin/ls: ELF 64-bit LSB pie executable…
stat file.txt                         # inode, size, perms, SELinux context, all timestamps
```

### 3.4 Copy

| Form | Result |
|---|---|
| `cp a b` | Copy file `a` to `b` (overwrites `b`) |
| `cp a b c dir/` | Several sources → the last argument **must** be a directory |
| `cp -r src dst` | If `dst` exists: creates `dst/src`. If not: `dst` becomes the copy |

| Option | Effect |
|---|---|
| `-r` / `-R` | Recursive (required for directories) |
| `-i` / `-n` | Prompt before overwrite / never overwrite |
| `-p` | Preserve mode (incl. ACLs), ownership, timestamps |
| `-a` | Archive: `-dR --preserve=all` (incl. links, xattrs, **SELinux context**) |
| `-u` | Copy only if the source is newer |
| `-v` | Verbose |
| `--backup=numbered` | Keep numbered backups of overwritten files |

### 3.5 Move / rename

```bash
mv old.txt new.txt                    # rename
mv file1 file2 /backup/               # move several into a directory
mv -i / -n / -v                       # prompt / no-clobber / verbose
rename .txt .bak *.txt                # util-linux rename: replace first ".txt" with ".bak"
```

- **Same filesystem:** `mv` only changes the directory entry; the inode stays the same and it's instant.
- **Across filesystems:** `mv` copies, then deletes the original; time scales with size.

### 3.6 Remove

```bash
rm file                               # remove a file
rm -i file / rm -I *                  # prompt each / prompt once for >3 files or recursive
rm -r dir                             # recursive
rm -rf dir                            # recursive, no prompts, ignore missing ⚠️
rm -- -weird-name   or   rm ./-weird-name   # names starting with "-"
rm "my file.txt"                      # quote spaces
```

> ⚠️ **Destructive:** There's no recycle bin. `rm -rf` is irreversible. Double-check paths, especially with variables or globs (see §5). When removing a symlink to a directory, never add a trailing slash (`rm dirlink`, not `rm -r dirlink/`).

### 3.7 Download and basic search

```bash
curl -O https://host/path/file.pdf    # save with the remote name (curl is in minimal installs)
curl -L -o out.pdf URL                # follow redirects, choose the name
wget URL                              # if the wget package is installed
find ~ -name newdir                   # search by name from an explicit start point
find ~ -type f -name 'RHCSA10.pdf'    # regular files only
find / -name sshd_config 2>/dev/null  # hide "Permission denied" noise
```

Full `find` coverage: [finding files](../files-and-text-processing/finding-files.md).

## 4. RHCSA Exam Focus **[RHCSA Core]**

- **Exact paths, names and case.** Verify with `ls -ld <path>` and `ls -l`.
- Use `mkdir -p` for nested paths, and when a task's directory may already exist.
- **Root aliases on RHEL:** `/root/.bashrc` defines `rm -i`, `cp -i`, `mv -i`. As root, `cp` prompts before overwriting. Answer, or bypass with `\cp`.
- **SELinux trap** **[RHCSA Core]**:

  | Operation | New file's SELinux context |
  |---|---|
  | `cp` (default) | **Inherits the destination directory's** default context ✔ |
  | `mv` | **Keeps the original** context ✘ (e.g., `user_home_t` in `/var/www/html` → web server gets "Permission denied") |
  | `cp -a` | Preserves the original context |

  After moving files into a service directory, run `restorecon -Rv <dir>` (S76).
- Copying to preserve ownership/permissions (e.g., backups) → `cp -a` as root.

## 5. Production Practices **[Production Practice]**

- For large or remote copies, prefer **`rsync -a`**: it's resumable, incremental and shows progress (S68).
- Use `cp --backup=numbered` or a timestamped copy before editing configs: `cp -a file{,.$(date +%F)}`.
- Use no-clobber (`-n`) in scripts when overwriting would be harmful.
- Never parse `ls` output in scripts. Use globs or `find … -print0 | xargs -0`.
- `rm -rf` hygiene in scripts:

```bash
  rm -rf -- "${TARGET_DIR:?not set}/"*    # aborts if the variable is empty/unset
```

  GNU `rm` refuses to run on `/` itself by default (`--preserve-root`), but `rm -rf /*` or an empty variable still destroys systems.

## 6. Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `rmdir: failed to remove 'd': Directory not empty` | Contents, often **hidden** files | `ls -A d`; then `rm -r d` if intended |
| `cp: -r not specified; omitting directory` | Copying a directory without recursion | `cp -r` / `cp -a` |
| `mv/rm: cannot remove … Permission denied` (on your own file) | Renaming/deleting needs **write + execute on the directory**, not on the file; sticky bit (`/tmp`); immutable attribute | `ls -ld dir`; `lsattr file` (`chattr -i` as root); see [file permissions](../users-groups-and-permissions/file-permissions.md) |
| `Argument list too long` | Glob expanded beyond ARG_MAX | `find dir -name '*.log' -delete` or `find … -exec rm {} +` |
| `No such file or directory` with spaces | Unquoted name split into words | Quote: `"my file"` |
| `rm: cannot remove 'x': Device or resource busy` | Mount point or busy device | `findmnt x`; `umount` first |
| `cannot create regular file: Read-only file system` | FS mounted read-only (maybe after I/O errors) | `findmnt -no OPTIONS /path`; `dmesg` (see FHS note) |
| `No space left on device` while copying | Blocks or inodes exhausted | `df -h`, `df -i` |
| Web or service can't read moved files | SELinux context kept by `mv` | `ls -Z`; `restorecon -Rv dir` |

## 7. Interview Questions

| Question | Answer |
|---|---|
| Absolute vs relative path? | Absolute starts at `/`; relative is resolved from the current directory. |
| Why can't you delete a file you own? | Deleting modifies the **directory**, so you need write+execute on it. Also consider the sticky bit and `chattr +i`. |
| Why is `mv` instant on the same filesystem but slow across filesystems? | Same FS: only the directory entry changes (same inode). Across FS: data must be copied, then the original deleted. |
| `cp` vs `mv` regarding SELinux? | `cp` creates a new file with the destination's default context; `mv` keeps the old one. Fix with `restorecon`. |
| `rmdir` vs `rm -r`? | `rmdir` removes only empty directories (safe); `rm -r` removes trees. |
| How do you delete a file named `-rf`? | `rm -- -rf` or `rm ./-rf`. |
| What does the `.` after the permission bits mean? | The file has an SELinux context and no other alternate access method (a `+` means an ACL). |
| `cp -p` vs `cp -a`? | `-p` preserves mode, ownership, timestamps. `-a` is recursive and preserves everything, including links, xattrs and SELinux context. |

## 8. Course Practice Questions (corrected)

| Task | Command | Note |
|---|---|---|
| Logged-on users / your session | `who` / `who am i` | See [shell basics §3](shell-basics-and-command-syntax.md#3-first-commands-s6-start-using-linux) |
| Current directory / go home | `pwd` / `cd` or `cd ~` | |
| Create two dirs at once | `mkdir ~/testdir ~/newdir` | |
| Remove an empty dir | `rmdir ~/newdir` | |
| Nested path in one go | `mkdir -p ~/testdir/newdir/mydir` | |
| Absolute path to home | `cd /home/<user>` or `cd "$HOME"` | Don't hard-code another user's name |
| Relative path | `cd testdir` (from home) | |
| Search from home | `find ~ -name newdir` | Explicit start point is clearer than relying on the `.` default |
| Hidden files | `ls -a ~` | `ls -A` omits `.` and `..` |
| Download | `curl -O URL` (or `wget URL` if installed) | Prefer `https://` URLs |
| Identify type | `file <name>.pdf` | |
| Copy / rename | `cp a.pdf b.pdf` / `mv b.pdf c.pdf` | |
| Files only, by name | `find ~ -type f -name RHCSA10.pdf` | |

## 9. Quick Revision

```bash
pwd; cd -; ls -la; ls -ld dir; ls -ltr; ls -Z
mkdir -p a/b/c; rmdir -p a/b/c; rm -r dir; rm -- -file
cp -a src dst; cp -r dir/ dst/; mv old new; \cp (bypass root alias)
touch f; file f; stat f; find ~ -type f -name x
mv into service dirs → restorecon -Rv
```

## 10. Cross-References

- [Filesystem hierarchy](../linux-fundamentals/filesystem-hierarchy.md)
- [Expansion & globbing](shell-expansion-and-globbing.md)
- [Finding files](../files-and-text-processing/finding-files.md)
- [File permissions & umask](../users-groups-and-permissions/file-permissions.md) · [Special permissions & ACLs (sticky bit)](../users-groups-and-permissions/special-permissions-and-acls.md)
- [Inodes, hard links & symbolic links](../users-groups-and-permissions/links.md)
- [SELinux contexts & `restorecon`](../firewall-and-selinux/selinux-file-contexts.md)
- [rsync](../networking-and-ssh/rsync-and-remote-backups.md)
