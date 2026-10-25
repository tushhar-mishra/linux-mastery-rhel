# Finding Files: `find` & `locate`

> **Sessions:** S18 · Supports multiple objectives (permissions troubleshooting, users, storage cleanup) **[RHCSA Core: find]** · locate **[Advanced/Optional]**
> **Related:** [Expansion & globbing (quote patterns!)](../shell-and-command-line/shell-expansion-and-globbing.md#52-exam-traps-rhcsa-core) · [Redirection](io-redirection-and-pipes.md) · [Getting help (`which`/`type`)](../shell-and-command-line/getting-help-and-documentation.md#4-locating-commands-type-vs-which-vs-whereis) · [File permissions](../users-groups-and-permissions/file-permissions.md) · [Special permissions (SUID/SGID audits)](../users-groups-and-permissions/special-permissions-and-acls.md) · [Links (`-inum`, `-samefile`)](../users-groups-and-permissions/links.md)

## 1. Overview

| | `find` | `locate` (plocate) |
|---|---|---|
| How it works | Walks the directory tree **live** | Queries a **prebuilt index** |
| Speed | Slower (reads disk) | Very fast |
| Freshness | Always current | Only as fresh as the last `updatedb` |
| Criteria | Name, type, size, time, owner, permissions, … plus actions | Name/path only |
| On RHEL | Always installed | `dnf install plocate` |

## 2. `find` Syntax

```
find [start-dir…] [options] [tests] [actions]
find /etc -type f -name '*.conf' -mtime -7 -print
```

The default start is `.`; the default action is `-print`. **Quote glob patterns**, or the shell expands them first.

### 2.1 Tests

| Test | Meaning | Example |
|---|---|---|
| `-name` / `-iname` | Basename glob (case-sensitive / insensitive) | `-name '*.log'` |
| `-path` | Glob on the whole path | `-path '*/ssh/*'` |
| `-regex` | Regex on the **whole path** | `-regex '.*\.sh'` |
| `-type` | `f` file, `d` dir, `l` symlink, `b`/`c` device, `s` socket, `p` pipe | `-type d` |
| `-size` | `c` bytes, `k` KiB, `M` MiB, `G` GiB; `+` more, `-` less (**rounded up** to units) | `-size +100M` |
| `-mtime` / `-atime` / `-ctime` | Days since modify / access / change | `-mtime +30` |
| `-mmin` / `-amin` / `-cmin` | Minutes | `-mmin -60` |
| `-newer FILE` | Modified more recently than FILE | `-newer /etc/passwd` |
| `-perm MODE` | **Exactly** MODE | `-perm 644` |
| `-perm -MODE` | **All** these bits set | `-perm -4000` (SUID) |
| `-perm /MODE` | **Any** of these bits set | `-perm /6000` (SUID or SGID) |
| `-user` / `-group` / `-uid` | Ownership | `-user alice` |
| `-nouser` / `-nogroup` | Owner/group no longer exists | after deleting users |
| `-empty` | Empty file or directory | |
| `-executable` | Executable by you | |
| `-inum N` / `-samefile F` / `-links N` | Inode number / all hard links of F / hard-link count ([links](../users-groups-and-permissions/links.md)) | |
| `-xtype l` | **Broken** symlinks | |
| `-maxdepth N` / `-mindepth N` | Limit recursion (**put first**) | `-maxdepth 1` |
| `-xdev` | Don't cross into other filesystems | `find / -xdev …` |

**Time arithmetic** (whole 24-hour periods, rounded down):

| Expression | Meaning |
|---|---|
| `-mtime -1` | Modified less than 24 h ago |
| `-mtime 1` | Between 24 and 48 h ago |
| `-mtime +7` | **8 or more** full days ago (not "more than 7") |

**Size rounding:** `-size -1M` matches only **empty** files, because everything else rounds up to at least 1 MiB. Use `-size -1024k` or `-size -1048576c` for precision.

### 2.2 Operators

| Operator | Meaning |
|---|---|
| (juxtaposition) / `-a` | AND (default) |
| `-o` | OR |
| `!` / `-not` | NOT |
| `\( … \)` | Grouping (spaces required) |

> ⚠️ **AND binds tighter than OR:** in `find . -name '*.log' -o -name '*.txt' -delete`, `-delete` applies **only to `*.txt`**. Group explicitly: `find . \( -name '*.log' -o -name '*.txt' \) -delete`.

### 2.3 Actions

| Action | Effect |
|---|---|
| `-print` / `-print0` | Print paths (NUL-separated for `xargs -0`) |
| `-ls` | `ls -dils`-style listing |
| `-printf '%p %s %u\n'` | Custom format **[Advanced]** |
| `-exec cmd {} \;` | Run cmd **once per file** |
| `-exec cmd {} +` | Run cmd with **many files at once** (efficient, like xargs) |
| `-ok cmd {} \;` | Like `-exec`, but asks for confirmation |
| `-delete` | Delete matches. ⚠️ **Must come last** |
| `-prune` | Don't descend into a directory |

```bash
find . -name '*.log' -exec ls -l {} +              # batch
find . -name '*.log' -print0 | xargs -0 -r rm -f   # safe with spaces; -r: do nothing if no input
find / -path /proc -prune -o -name 'core.*' -print # skip /proc entirely
```

> ⚠️ **Deleting with find, safely:**
> 1. Run with `-print` first and review.
> 2. Add `-delete` **at the end**. `find . -delete -name x` deletes **everything**, because `-delete` runs before `-name` is tested.
> 3. Prefer `-type f` to avoid removing directories.

## 3. RHCSA-Style Tasks **[RHCSA Core]**

```bash
# Copy all files owned by user harry to /root/found, preserving attributes
mkdir -p /root/found
find / -user harry -type f -exec cp -a {} /root/found/ \; 2>/dev/null
# (identical names overwrite each other; use cp --parents to keep directory structure)

# List files larger than 10 MiB under /var into a file
find /var -type f -size +10M > /root/bigfiles.txt 2>/dev/null

# Find SUID binaries (security audit)
find / -xdev -type f -perm -4000 2>/dev/null

# Files with no valid owner after deleting a user
find / -xdev \( -nouser -o -nogroup \) 2>/dev/null

# Config files changed in the last day
find /etc -type f -mtime -1
```

Always verify the result: `ls -l /root/found`, `wc -l /root/bigfiles.txt`. More permission audits (SGID, sticky, world-writable): [special permissions & ACLs](../users-groups-and-permissions/special-permissions-and-acls.md#21-auditing).

## 4. `locate` (plocate) **[Advanced/Optional]**

```bash
sudo dnf install -y plocate
sudo updatedb                      # build/refresh the index (root)
locate sshd_config                 # substring match on full paths
locate -i readme                   # case-insensitive
locate -b '\sshd_config'           # basename exactly sshd_config [Advanced]
locate '*.conf'                    # glob → matched against the WHOLE path (quote it!)
locate -l 5 bash                   # limit results
locate -c '*.conf'                 # count only
systemctl list-timers | grep -i updatedb   # automatic refresh timer
```

- The index lives at `/var/lib/plocate/plocate.db`. Excluded paths and filesystems are configured in `/etc/updatedb.conf`.
- Results only include files **you're allowed to see**; plocate checks permissions itself.
- New or deleted files are invisible or stale until the next `updatedb`.

> ⚠️ **Course corrections:**
> - The database path `/var/lib/mlocate/mlocate.db` belongs to the old mlocate.
> - `-A` doesn't mean "accessible only" (it means *match all patterns*); permission filtering is automatic.
> - Unquoted `locate *.conf` is expanded by the shell first.

## 5. Production Practices

- On large or networked trees, use `-xdev`, limit depth and run at low priority: `nice -n 19 ionice -c3 find …`.
- **Don't delete logs with find in `/var/log`.** Rotated logs on RHEL are named like `messages-20260101`; `logrotate` manages retention (S55).
- Use `-print0 | xargs -0` or `-exec … +` for any filename that might contain spaces.
- For "which package owns this file": `rpm -qf /path`. For "what files does this package install": `rpm -ql pkg`.

## 6. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Screens of `Permission denied` | Unreadable directories | `2>/dev/null`, or run as root |
| `paths must precede expression` | Unquoted glob expanded by the shell | Quote: `-name '*.conf'` |
| `missing argument to '-exec'` | Forgot `\;` or `+` | End `-exec` correctly |
| `-delete` removed too much | Action placed before tests, or OR precedence | Test with `-print`; parenthesize |
| `xargs` fails on spaces | Newline-separated input | `-print0 \| xargs -0` |
| `locate` misses a new file / shows a deleted one | Stale index | `sudo updatedb` |
| `locate: command not found` | Not installed | `dnf install plocate` (or use `find`) |

## 7. Interview Questions

| Question | Answer |
|---|---|
| `find` vs `locate`? | `find` walks the tree live with rich criteria. `locate` queries an index: fast, but possibly stale. |
| `-exec {} \;` vs `-exec {} +`? | One process per file vs batching many files into each invocation. |
| `-perm 644` vs `-perm -644` vs `-perm /644`? | Exact mode vs all bits present vs any bit present. |
| What does `-mtime +7` really mean? | At least 8 full 24-hour periods since modification. |
| How do you find SUID files? | `find / -xdev -type f -perm -4000 2>/dev/null`. |
| Why must `-delete` be last? | find evaluates left to right; an action before the tests applies to everything. |

## 8. Quick Revision

```bash
find / -xdev -type f -name '*.conf' -size +1M -mtime -7 -user u -perm -4000 2>/dev/null
-exec cmd {} \;  |  -exec cmd {} +  |  -print0 | xargs -0 -r  |  -ok  |  -delete (LAST)
\( A -o B \)   !   -maxdepth 1 (first)   -newer f   -samefile f   -xtype l   -nouser
sudo updatedb; locate -i x; locate -l 5 x    (index: /var/lib/plocate/plocate.db)
```

## 9. Cross-References

- [Expansion & globbing](../shell-and-command-line/shell-expansion-and-globbing.md)
- [I/O redirection (`2>/dev/null`)](io-redirection-and-pipes.md)
- [Archiving (find + tar)](archiving-and-compression.md)
- [Files & directories (`cp -a`)](../shell-and-command-line/files-and-directories.md)
- [File permissions](../users-groups-and-permissions/file-permissions.md) · [Special permissions & ACLs](../users-groups-and-permissions/special-permissions-and-acls.md) · [Links & inodes](../users-groups-and-permissions/links.md)
