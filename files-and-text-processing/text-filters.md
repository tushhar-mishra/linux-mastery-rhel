`````````markdown
# Text Filters & Pipelines

> **Sessions:** S17 (practice in course; theory **supplemented**) · Supports *Use grep and regular expressions to analyze text* **[RHCSA Core]**
> **Related:** [Redirection & pipes](io-redirection-and-pipes.md) · [grep & regex](grep-and-regular-expressions.md) · [awk](awk.md) · [Viewing files](viewing-and-creating-file-contents.md)

## 1. Overview

A **filter** reads stdin (or files), transforms the text, and writes to stdout. Chaining small filters with pipes is the UNIX way to answer questions like "which shells are in use?" or "which IPs failed SSH logins most?" without writing a program.

## 2. The Toolkit

| Tool | Purpose | Key options |
|---|---|---|
### 2. `files-and-text-processing/text-filters.md`

`````````markdown
# Text Filters & Pipelines

> **Sessions:** S17 (practice in course; theory **supplemented**) · Supports *Use grep and regular expressions to analyze text* **[RHCSA Core]**
> **Related:** [Redirection & pipes](io-redirection-and-pipes.md) · [grep & regex](grep-and-regular-expressions.md) · [awk](awk.md) · [Viewing files](viewing-and-creating-file-contents.md)

## 1. Overview

A **filter** reads stdin (or files), transforms the text, and writes to stdout. Chaining small filters with pipes is the UNIX way to answer questions like "which shells are in use?" or "which IPs failed SSH logins most?" without writing a program.

## 2. The Toolkit

| Tool | Purpose | Key options |
|---|---|---|
### 2. `files-and-text-processing/text-filters.md`

`````````markdown
# Text Filters & Pipelines

> **Sessions:** S17 (practice in course; theory **supplemented**) · Supports *Use grep and regular expressions to analyze text* **[RHCSA Core]**
> **Related:** [Redirection & pipes](io-redirection-and-pipes.md) · [grep & regex](grep-and-regular-expressions.md) · [awk](awk.md) · [Viewing files](viewing-and-creating-file-contents.md)

## 1. Overview

A **filter** reads stdin (or files), transforms the text, and writes to stdout. Chaining small filters with pipes is the UNIX way to answer questions like "which shells are in use?" or "which IPs failed SSH logins most?" without writing a program.

## 2. The Toolkit

| Tool | Purpose | Key options |
|---|---|---|
### 2. `files-and-text-processing/text-filters.md`

`````````markdown
# Text Filters & Pipelines

> **Sessions:** S17 (practice in course; theory **supplemented**) · Supports *Use grep and regular expressions to analyze text* **[RHCSA Core]**
> **Related:** [Redirection & pipes](io-redirection-and-pipes.md) · [grep & regex](grep-and-regular-expressions.md) · [awk](awk.md) · [Viewing files](viewing-and-creating-file-contents.md)

## 1. Overview

A **filter** reads stdin (or files), transforms the text, and writes to stdout. Chaining small filters with pipes is the UNIX way to answer questions like "which shells are in use?" or "which IPs failed SSH logins most?" without writing a program.

## 2. The Toolkit

| Tool | Purpose | Key options |
|---|---|---|
### 2. `files-and-text-processing/text-filters.md`

`````````markdown
# Text Filters & Pipelines

> **Sessions:** S17 (practice in course; theory **supplemented**) · Supports *Use grep and regular expressions to analyze text* **[RHCSA Core]**
> **Related:** [Redirection & pipes](io-redirection-and-pipes.md) · [grep & regex](grep-and-regular-expressions.md) · [awk](awk.md) · [Viewing files](viewing-and-creating-file-contents.md)

## 1. Overview

A **filter** reads stdin (or files), transforms the text, and writes to stdout. Chaining small filters with pipes is the UNIX way to answer questions like "which shells are in use?" or "which IPs failed SSH logins most?" without writing a program.

## 2. The Toolkit

| Tool | Purpose | Key options |
|---|---|---|
### 2. `files-and-text-processing/text-filters.md`

`````````markdown
# Text Filters & Pipelines

> **Sessions:** S17 (practice in course; theory **supplemented**) · Supports *Use grep and regular expressions to analyze text* **[RHCSA Core]**
> **Related:** [Redirection & pipes](io-redirection-and-pipes.md) · [grep & regex](grep-and-regular-expressions.md) · [awk](awk.md) · [Viewing files](viewing-and-creating-file-contents.md)

## 1. Overview

A **filter** reads stdin (or files), transforms the text, and writes to stdout. Chaining small filters with pipes is the UNIX way to answer questions like "which shells are in use?" or "which IPs failed SSH logins most?" without writing a program.

## 2. The Toolkit

| Tool | Purpose | Key options |
|---|---|---|
### 2. `files-and-text-processing/text-filters.md`

`````````markdown
# Text Filters & Pipelines

> **Sessions:** S17 (practice in course; theory **supplemented**) · Supports *Use grep and regular expressions to analyze text* **[RHCSA Core]**
> **Related:** [Redirection & pipes](io-redirection-and-pipes.md) · [grep & regex](grep-and-regular-expressions.md) · [awk](awk.md) · [Viewing files](viewing-and-creating-file-contents.md)

## 1. Overview

A **filter** reads stdin (or files), transforms the text, and writes to stdout. Chaining small filters with pipes is the UNIX way to answer questions like "which shells are in use?" or "which IPs failed SSH logins most?" without writing a program.

## 2. The Toolkit

| Tool | Purpose | Key options |
|---|---|---|
| `grep` | Select lines matching a pattern | `-i -v -c -n -w -E -o` ([details](grep-and-regular-expressions.md)) |
| `cut` | Extract columns or characters | `-d: -f1,7`, `-c1-5` |
| `tr` | Translate, delete or squeeze characters (**stdin only**) | `-d`, `-s`, `'[:lower:]' '[:upper:]'` |
| `sort` | Sort lines | `-n -r -k2 -t: -u -h -V` |
| `uniq` | Collapse **adjacent** duplicates (sort first!) | `-c -d -u -i` |
| `wc` | Count lines, words, bytes | `-l -w -c -m` |
| `head` / `tail` | First / last lines | `-n N`, `tail -n +N` |
| `tee` | Copy the stream to a file | `-a` |
| `sed` | Stream editor: substitute, delete, print ranges | `s///g`, `-n`, `-i`, `-E` |
| `awk` | Field-based processing and reports | see [awk](awk.md) |
| `paste` / `column` | Merge lines / align columns | `paste -sd,`, `column -t` |
| `nl` / `rev` | Number lines / reverse characters | |
| `diff` / `comm` | Compare files | `diff -u`, `comm -12` (sorted input) |
| `xargs` | Turn stdin into arguments | `-0 -r -n -I{}` |

## 3. Commands & Examples

### cut

````````bash
cut -d: -f1 /etc/passwd             # usernames
cut -d: -f1,7 /etc/passwd           # username:shell
cut -c1-8 file                      # first 8 characters of each line
````````

`cut` treats **each** delimiter as a separator, so it can't handle runs of spaces. Use `awk '{print $2}'` or `tr -s ' ' | cut -d' ' -f2`.

### tr

````````bash
echo "abc123def456" | tr -d '0-9'          # abcdef
tr '[:lower:]' '[:upper:]' < f             # uppercase
echo "a   b    c" | tr -s ' '              # a b c (squeeze)
tr -d '\r' < win.txt > unix.txt            # strip CR from CRLF files
````````

### sort and uniq

````````bash
sort -t: -k3 -n /etc/passwd | head         # by UID, numerically
du -sh /var/* 2>/dev/null | sort -h        # human-readable sizes
sort -u names.txt                          # unique (sorted)
cut -d: -f7 /etc/passwd | sort | uniq -c | sort -rn   # count of each login shell
uniq -d sorted.txt                         # only lines that repeat
````````

`uniq` only removes **adjacent** duplicates; always `sort` first.

### sed (basics)

````````bash
sed 's/old/new/' f            # first match per line → stdout
sed 's/old/new/g' f           # all matches
sed -n '10,20p' f             # print lines 10–20 only
sed '/^#/d; /^$/d' f          # drop comments and blank lines
sed -E 's/([0-9]+)/<\1>/g' f  # ERE with backreference
sed -i.bak 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config.d/40-local.conf
````````

> ⚠️ `sed -i` edits **in place**. Use `-i.bak` to keep a backup, test without `-i` first, and validate configs afterwards (`sshd -t`).

### Classic pipelines

````````bash
who | awk '{print $2}' | sort -u                     # logged-in terminals
grep -c 'processor' /proc/cpuinfo                    # CPU count (or nproc)
sudo grep 'Failed password' /var/log/secure \
  | grep -oE 'from [0-9.]+' | sort | uniq -c | sort -rn | head    # top failed-login IPs
ps -eo user= | sort | uniq -c | sort -rn             # processes per user
````````

## 4. RHCSA Exam Focus

- grep is the named objective. `cut`, `sort`, `uniq` and `wc` help you verify task results and write scripts.
- Typical task: "find lines containing X in file Y and copy them, in their original order, to Z": `grep 'X' Y > Z`. Don't sort unless asked.
- Count things precisely: `grep -c`, `wc -l`.

## 5. Production Practices

- Set `LC_ALL=C` for fast, predictable `sort`/`grep` on large logs.
- Prefer `awk` over long `grep | cut | tr` chains when fields are involved.
- Never parse `ls` output in scripts; use `find -printf` or `stat`.

## 6. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `uniq` leaves duplicates | Input not sorted | `sort \| uniq` or `sort -u` |
| `cut -d' '` returns empty fields | Multiple spaces | `awk` or `tr -s ' '` first |
| `sort` puts `10` before `9` | Lexical sort | `sort -n` (or `-V` for versions) |
| `tr` complains about extra operand | `tr` takes no file arguments | `tr … < file` |
| `sed -i` broke a config | Unchecked in-place edit | Restore `.bak`; test without `-i` |

## 7. Interview Questions

| Question | Answer |
|---|---|
| Why `sort` before `uniq`? | `uniq` compares only adjacent lines. |
| `cut` vs `awk` for columns? | `cut` handles single-character delimiters; `awk` splits on any whitespace and supports logic. |
| How do you count unique values in a column? | `cut -d: -f7 /etc/passwd \| sort \| uniq -c \| sort -rn`. |
| What does `sed -n '5p'` do? | Suppresses automatic printing, then prints only line 5. |

## 8. Course Practice (S17, corrected)

| # | Task | Better command | Note |
|---|---|---|---|
| 1 | Users with `/bin/sh`, sorted | `awk -F: '$7=="/bin/sh"{print $1}' /etc/passwd \| sort > shusers.txt` | Course's unanchored `grep '/bin/sh'` can match other fields; `grep ':/bin/sh$'` also works |
| 2 | Logged-in terminals | `who \| awk '{print $2}' \| sort -u > onlineterminals.txt` | ✔ |
| 3 | Names in `/var/log` containing "log" | `ls /var/log \| grep log > logfile_names.txt` | ✔ (interactive use; `find /var/log -maxdepth 1 -name '*log*'` in scripts) |
| 4 | Files in `/usr/bin` matching "python" (any case) | `ls /usr/bin \| grep -i python \| sort > pythonfiles.txt` | ✔ |
| 5 | IP/prefix of non-loopback interfaces | `ip -4 -o addr show scope global \| awk '{print $4}'` | ⚠️ Course's `grep -v 'lo'` also removes lines with "g**lo**bal", which hides real addresses. Output is CIDR (`/24`), not a dotted mask |
| 6 | Remove digits | `tr -d '0-9'` | ✔ |

## 9. Quick Revision

````````bash
grep | cut -d: -f1 | tr -d/-s | sort -n -r -k -t -u -h | uniq -c | wc -l | tee
sed 's/a/b/g' | sed -n 'Np' | sed '/re/d' | sed -i.bak
… | sort | uniq -c | sort -rn | head      # frequency count pattern
````````

---

### 3. `files-and-text-processing/finding-files.md`

````````markdown
# Finding Files: `find` & `locate`

> **Sessions:** S18 · Supports multiple objectives (permissions troubleshooting, users, storage cleanup) **[RHCSA Core: find]** · locate **[Advanced/Optional]**
> **Related:** [Expansion & globbing (quote patterns!)](../shell-and-command-line/shell-expansion-and-globbing.md#52-exam-traps-rhcsa-core) · [Redirection](io-redirection-and-pipes.md) · [Getting help (`which`/`type`)](../shell-and-command-line/getting-help-and-documentation.md#4-locating-commands-type-vs-which-vs-whereis) · Permissions & SUID (S25–26)

## 1. Overview

| | `find` | `locate` (plocate) |
|---|---|---|
| How it works | Walks the directory tree **live** | Queries a **prebuilt index** |
| Speed | Slower (reads disk) | Very fast |
| Freshness | Always current | Only as fresh as the last `updatedb` |
| Criteria | Name, type, size, time, owner, permissions, … plus actions | Name/path only |
| On RHEL | Always installed | `dnf install plocate` |

## 2. `find` Syntax

```````
find [start-dir…] [options] [tests] [actions]
find /etc -type f -name '*.conf' -mtime -7 -print
```````

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
| `-inum N` / `-links N` | Inode number / hard-link count (S28) | |
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

```````bash
find . -name '*.log' -exec ls -l {} +              # batch
find . -name '*.log' -print0 | xargs -0 -r rm -f   # safe with spaces; -r: do nothing if no input
find / -path /proc -prune -o -name 'core.*' -print # skip /proc entirely
```````

> ⚠️ **Deleting with find, safely:**
> 1. Run with `-print` first and review.
> 2. Add `-delete` **at the end**. `find . -delete -name x` deletes **everything**, because `-delete` runs before `-name` is tested.
> 3. Prefer `-type f` to avoid removing directories.

## 3. RHCSA-Style Tasks **[RHCSA Core]**

```````bash
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
```````

Always verify the result: `ls -l /root/found`, `wc -l /root/bigfiles.txt`.

## 4. `locate` (plocate) **[Advanced/Optional]**

```````bash
sudo dnf install -y plocate
sudo updatedb                      # build/refresh the index (root)
locate sshd_config                 # substring match on full paths
locate -i readme                   # case-insensitive
locate -b '\sshd_config'           # basename exactly sshd_config [Advanced]
locate '*.conf'                    # glob → matched against the WHOLE path (quote it!)
locate -l 5 bash                   # limit results
locate -c '*.conf'                 # count only
systemctl list-timers | grep -i updatedb   # automatic refresh timer
```````

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

```````bash
find / -xdev -type f -name '*.conf' -size +1M -mtime -7 -user u -perm -4000 2>/dev/null
-exec cmd {} \;  |  -exec cmd {} +  |  -print0 | xargs -0 -r  |  -ok  |  -delete (LAST)
\( A -o B \)   !   -maxdepth 1 (first)   -newer f   -xtype l   -nouser
sudo updatedb; locate -i x; locate -l 5 x    (index: /var/lib/plocate/plocate.db)
```````

---

### 4. `files-and-text-processing/awk.md`

```````markdown
# awk

> **Sessions:** S19 · **[Advanced/Optional]**, but very useful for scripts, log analysis and interviews
> **Related:** [Text filters](text-filters.md) · [grep & regex](grep-and-regular-expressions.md) · [Redirection](io-redirection-and-pipes.md)

## 1. Overview

`awk` is a pattern-scanning language named after Aho, Weinberger and Kernighan (Bell Labs, 1977). It reads input as **records** (lines) split into **fields**, and runs `pattern { action }` rules on each record. On RHEL, `awk` is **GNU awk (gawk)**.

``````bash
awk 'pattern { action }' file
command | awk -F: '$3 >= 1000 { print $1 }'
``````

Always use **single quotes**, so the shell doesn't expand awk's `$1`.

## 2. Key Concepts

| Variable | Meaning |
|---|---|
| `$0` | Whole record (line) |
| `$1` … `$NF` | Fields; `$NF` is the last field |
| `NF` | Number of fields in this record |
| `NR` / `FNR` | Record number overall / within the current file |
| `FS` (`-F`) | Input field separator. Default: runs of whitespace |
| `OFS` | Output field separator (default space), used between comma-separated `print` items |
| `RS` / `ORS` | Input / output record separators |
| `FILENAME` | Current file name |

- **Patterns:** `NR>1`, `$3=="Delhi"`, `/regex/`, `$1 ~ /^ab/`, `$1 !~ /x/`, `cond1 && cond2`, `BEGIN`, `END`.
- **Comma vs concatenation:** `print $1, $2` inserts OFS; `print $1 $2` joins them directly.

## 3. Examples

Sample `data.txt` (with a header line):

``````
Name Age City
Tarun 24 Jaipur
Ravi 30 Delhi
Priya 27 Mumbai
Neha 25 Pune
``````

``````bash
awk '{print $1, $3}' data.txt                         # columns 1 and 3
awk 'NR>1 {print $1}' data.txt                        # skip header
awk 'NR>1 && $2 > 25' data.txt                        # condition (default action: print)
awk '$3 == "Delhi"' data.txt
awk 'NR>1 {s+=$2; n++} END {if (n) print "Avg:", s/n}' data.txt
awk '{print NR": "$0}' data.txt                       # number lines
awk 'NR>1 {printf "%-10s %3d %s\n", $1, $2, $3}' data.txt
awk -F, 'BEGIN{OFS="\t"} {print $1, $2, $3}' users.csv # CSV → TSV
awk -v min=26 'NR>1 && $2 >= min {print $1}' data.txt  # pass a shell value safely
awk 'NR>1 {c[$3]++} END {for (k in c) print k, c[k]}' data.txt   # count per city (arrays)
awk 'BEGIN {for (i=1; i<=5; i++) print "Number:", i}'
``````

**System administration one-liners:**

``````bash
awk -F: '$3>=1000 && $3<65534 {print $1}' /etc/passwd        # regular users (65534 = nobody)
awk -F: '{print $1, $3, $7}' /etc/passwd                      # user, UID, shell
df -hP | awk 'NR>1 && $5+0 > 80 {print $6, $5}'               # filesystems over 80% full
ps -eo pid,%mem,comm --sort=-%mem | awk 'NR<=6'               # top memory consumers
sudo awk '/Failed password/ {print $(NF-3)}' /var/log/secure | sort | uniq -c | sort -rn
ip -4 -o addr show scope global | awk '{print $2, $4}'        # interface + address/prefix
``````

## 4. awk vs cut vs grep vs sed

| Need | Best tool |
|---|---|
| Select lines by pattern | `grep` |
| Simple single-character delimiter column | `cut` |
| Columns separated by variable whitespace, conditions, sums, reports | `awk` |
| Substitutions and in-place edits | `sed` |

## 5. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Header line appears in numeric filters | `"Age" > 25` is a **string** comparison and true | Add `NR>1` |
| `$1` empty or odd in output | Double quotes let the shell expand `$1` | Single-quote the program |
| Wrong columns on CSV | Default FS is whitespace | `-F,` (quoted commas need a real CSV parser) |
| `$5 > 80` misbehaves on `85%` | `85%` is a string | Force numeric: `$5+0` |
| Division by zero in END | No matching lines | Guard: `if (n)` |

## 6. Interview Questions

| Question | Answer |
|---|---|
| What is `NF` and `$NF`? | Field count, and the last field. |
| `NR` vs `FNR`? | Overall record number vs per-file record number. |
| How do you pass a shell variable into awk? | `awk -v name="$var" '…'`. |
| Print the 2nd column of lines containing "error"? | `awk '/error/ {print $2}' file`. |

## 7. Course Corrections

- `awk '$2 > 25' data.txt` also prints the **header** (string comparison). Use `NR>1 && $2 > 25`.
- `awk '$9 == 404 …' access.log` assumes the Apache/Nginx combined log format.
- `dmesg` may require root, depending on `kernel.dmesg_restrict`.

## 8. Quick Revision

``````bash
awk -F: -v x=1 'BEGIN{OFS=","} NR>1 && $3>=1000 {print $1,$NF; n++} END{print n}' /etc/passwd
$0 $1 $NF NF NR FNR FS OFS   ~ !~ /re/   printf "%-10s %5d\n"   arrays: c[$1]++
``````

---

### 5. `files-and-text-processing/grep-and-regular-expressions.md`

``````markdown
# grep & Regular Expressions

> **Sessions:** S17, S20 · **Objective:** *Use grep and regular expressions to analyze text* **[RHCSA Core]**
> **Related:** [Text filters (sed)](text-filters.md) · [awk](awk.md) · [Globs vs regex](../shell-and-command-line/shell-expansion-and-globbing.md#51-globs-vs-regular-expressions) · [vi search & replace](vi-and-vim.md)

## 1. Overview

A **regular expression** describes a text pattern. `grep` prints the lines that match. Regex flavors differ in syntax, so know which one your tool uses:

| Flavor | Tools | Notes |
|---|---|---|
| **BRE** (basic) | `grep`, `sed`, `vi` (default) | `? + \| ( ) { }` need a backslash (`\+` is a GNU extension) |
| **ERE** (extended) | `grep -E`, `sed -E`, `awk` | `? + \| ( ) { }` work unescaped |
| **PCRE** (Perl-compatible) | `grep -P`, `perl` | Adds `\d`, lazy `*?`, lookahead/lookbehind |

`egrep` and `fgrep` are obsolete; RHEL 10's grep prints a warning. Use `grep -E` and `grep -F`.

## 2. `grep` Options **[RHCSA Core]**

| Option | Meaning |
|---|---|
| `-i` | Ignore case |
| `-v` | Invert: lines that do **not** match |
| `-n` | Show line numbers |
| `-c` | Count matching lines |
| `-l` / `-L` | Print only filenames with / without matches |
| `-r` / `-R` | Recursive (`-R` also follows symlinks) |
| `-w` / `-x` | Match whole words / whole lines only |
| `-o` | Print only the matched part |
| `-E` / `-F` / `-P` | ERE / fixed string (no regex) / PCRE |
| `-A N` / `-B N` / `-C N` | Lines of context after / before / around |
| `-q` | Quiet: exit status only (scripts) |
| `-e PAT` (repeatable) / `-f FILE` | Multiple patterns |
| `-s` | Suppress errors about unreadable files |

## 3. Regex Syntax

| Element | BRE | ERE / PCRE | Meaning |
|---|---|---|---|
| Any character | `.` | `.` | Exactly one character |
| Start / end of line | `^` `$` | `^` `$` | Anchors |
| 0 or more of the previous item | `*` | `*` | |
| 1 or more | `\+` | `+` | |
| 0 or 1 | `\?` | `?` | |
| n to m times | `\{n,m\}` | `{n,m}` | `{3}`, `{2,}` |
| Alternation | `\|` | `\|` | OR |
| Group | `\( \)` | `( )` | |
| Backreference | `\1` | `\1` (GNU ERE, PCRE) | Repeat a captured group |
| Character set / negated | `[abc]` `[^abc]` | same | |
| POSIX classes | `[[:digit:]]` `[[:alpha:]]` `[[:space:]]` `[[:upper:]]` | same | Locale-safe |
| Word boundary / start / end | `\b` `\<` `\>` (GNU) | `\b` (GNU ERE, PCRE) | |
| Word / space character | `\w` `\s` (GNU) | `\w` `\s` | |
| Digit shorthand | — | `\d` (**PCRE only**) | Use `[0-9]` in BRE/ERE |
| Literal special character | `\.` `\*` `\[` | same | Escape to match literally |

> ⚠️ **Course corrections:**
> - The comparison table's columns are shifted. In BRE, `+ ? |` need `\`; in ERE they don't.
> - GNU grep supports `\b \w \s \< \>` in BRE and ERE, so they're not PCRE-only.
> - Backreferences are standard in BRE (and supported in GNU ERE), not only PCRE.
> - "PRE" is properly **PCRE**.

## 4. Practical Patterns **[RHCSA Core]**

`````bash
grep '^alice:' /etc/passwd                        # exact user record
grep -v '^#' file | grep -v '^$'                  # strip comments and blanks…
grep -Ev '^[[:space:]]*(#|$)' /etc/ssh/sshd_config   # …in one pass, including indented comments
grep -rn 'PermitRootLogin' /etc/ssh/              # where is it set? (file:line)
sudo grep -c 'Failed password' /var/log/secure    # count failures
grep -i 'error' /var/log/messages | tail          # case-insensitive, latest
grep -w 'root' /etc/group                         # whole word, not "chroot"
grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' file | sort -u   # extract IPv4-like strings
grep -E '\.(txt|log)$' list.txt                   # extensions
grep -q '^alice:' /etc/passwd && echo "exists"    # script test
journalctl -u sshd -g 'Accepted'                  # journal has built-in grep (-g)
`````

**Typical exam task:** "Find all lines in `/usr/share/dict/words` containing `seismic` and save them, in order, to `/root/lines`":

`````bash
grep 'seismic' /usr/share/dict/words > /root/lines   # keep the original order; verify with cat
`````

## 5. Practice (corrected)

| # | Task | Command | Note |
|---|---|---|---|
| Q1 | Lines starting with "error" | `grep '^error' f` | ✔ |
| Q2 | Lines ending ".log" | `grep '\.log$' f` | ✔ (escaped dot) |
| Q3 | Line **is** exactly three digits | `grep -E '^[0-9]{3}$' f` | For "**contains** exactly three digits": `grep -E '^[^0-9]*([0-9][^0-9]*){3}$' f` |
| Q4 | "cat" or "dog" | `grep -E 'cat\|dog' f` (add `-w` for whole words) | |
| Q5 | Two or more consecutive spaces | `grep -E ' {2,}' f` | Course's `' +'` matches **one** or more |
| Q6 | Letters only | `grep -E '^[[:alpha:]]+$' f` | ✔ |
| Q7 | Repeated word ("the the") | `grep -Ei '\b([a-z]+) +\1\b' f` (or the course's `-P` version) | Backrefs work in GNU ERE |
| Q8 | .txt or .log | `grep -E '\.(txt\|log)$' f` | |
| Q9 | 10-digit number | `grep -E '\b[0-9]{10}\b' f` | ✔ |
| Q10 | No digits | `grep -v '[0-9]' f` | ✔ |
| Q11 | "abc" + any 3 characters | `grep -E 'abc.{3}' f` | ✔ |
| Q12 | Simple email | `grep -E '[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}' f` | Course's TLD limit `{2,4}` misses longer TLDs |
| Q13 | IPv4-like strings | `grep -E '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' f` | Also matches 999.999.999.999; validation needs more logic |
| Q14 | Word ending "ing" | `grep -E '\b\w+ing\b' f` | ✔ |
| Q15 | 4-letter palindromes | `grep -P '\b(\w)(\w)\2\1\b' f` | ✔ |

## 6. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Pattern matches oddly or "No such file" | Unquoted pattern expanded by the shell | Always single-quote patterns |
| `egrep: warning: egrep is obsolescent` | Deprecated wrapper | `grep -E` |
| `grep: warning: stray \ before d` | `\d` used outside PCRE | `[0-9]` or `-P` |
| `Binary file … matches` | Non-text bytes | `-a` (treat as text) or `strings` first |
| `.` matches everything | Unescaped dot | `\.` |
| Too slow on huge logs | Locale/UTF-8 processing | `LC_ALL=C grep …`; `-F` for fixed strings |

## 7. Interview Questions

| Question | Answer |
|---|---|
| BRE vs ERE? | ERE treats `+ ? \| ( ) {}` as operators without escaping; BRE needs backslashes. |
| Glob `*` vs regex `*`? | Glob: any string. Regex: zero or more of the **previous** item (`.*` = any string). |
| Show config lines that aren't comments or blank? | `grep -Ev '^[[:space:]]*(#\|$)' file`. |
| `grep -w` vs `\b`? | `-w` matches whole-word matches for the entire pattern; `\b` places boundaries where you choose. |
| How do you test for a match in a script? | `if grep -q pattern file; then …`. |

## 8. Quick Revision

`````bash
grep -i -v -n -c -l -r -w -x -o -E -F -P -A/-B/-C -q   'PATTERN' files
^ $ . * \+ \? [..] [^..] [[:digit:]] \b \< \>    ERE: + ? | () {n,m}    PCRE: \d *? (?=…)
grep -Ev '^[[:space:]]*(#|$)' conf    grep 'x' in > out (keeps order)
`````

---

### 6. `files-and-text-processing/vi-and-vim.md`

`````markdown
# vi & vim

> **Sessions:** S20 · **Objective:** *Create and edit text files* **[RHCSA Core]**
> **Related:** [Viewing & creating files (heredoc/tee)](viewing-and-creating-file-contents.md) · [grep & regex (patterns in `:s`)](grep-and-regular-expressions.md) · Variables (`EDITOR`): [variables note](../shell-and-command-line/shell-variables-and-environment.md)

## 1. Overview

`vi` is the editor guaranteed on every RHEL system, including minimal installs and rescue environments. On RHEL, `vi` comes from **vim-minimal**; **vim-enhanced** (`vim`) adds syntax highlighting and more, and includes `vimtutor`. Many admin tools open `$EDITOR`, which is usually vi/vim: `visudo`, `crontab -e`, `systemctl edit`, `vipw`, `vigr`, `git commit`.

````bash
vi file          # open or create
vim +25 file     # open at line 25
vimtutor         # 30-minute built-in tutorial (vim-enhanced) — highly recommended
sudo dnf install -y vim-enhanced
````

## 2. Modes

| Mode | Purpose | Enter with | Leave with |
|---|---|---|---|
| **Normal** | Navigate, delete, copy, paste | `Esc` | — |
| **Insert** | Type text | `i a I A o O` | `Esc` |
| **Command-line** | Save, quit, search/replace, ex commands | `:` `/` `?` | `Enter` / `Esc` |
| **Visual** | Select characters / lines / block | `v` / `V` / `Ctrl+v` | `Esc` |
| **Replace** | Overtype | `R` | `Esc` |

> ⚠️ **Course correction:** vi has more than three modes; Visual and Replace are used constantly.

## 3. Survival Kit **[RHCSA Core]**

| Task | Keys |
|---|---|
| Start typing | `i` (before cursor), `a` (after), `o` (new line below), `A` (end of line) |
| Stop typing | `Esc` |
| Save / quit / both | `:w` / `:q` / `:wq` |
| Save only if changed and quit | `:x` or `ZZ` |
| Quit **discarding** changes | `:q!` (or `ZQ`) |
| Revert to the saved version | `:e!` |
| Undo / redo | `u` / `Ctrl+r` |
| Go to line N / first / last | `:N` or `NG` / `gg` / `G` |
| Search | `/text` then `n` / `N` |
| Replace everywhere | `:%s/old/new/g` |
| Line numbers | `:set nu` / `:set nonu` |

> ⚠️ **Course correction:** `:x` isn't exactly `:wq`. `:x` writes **only if the buffer changed**, so it preserves the file's timestamp when nothing changed.

## 4. Navigation

| Keys | Move |
|---|---|
| `h j k l` | Left, down, up, right |
| `w` / `b` / `e` | Next word / previous word / end of word |
| `0` / `^` / `$` | Line start / first non-blank / line end |
| `gg` / `G` / `:N` | File start / end / line N |
| `Ctrl+f` / `Ctrl+b` | Page down / up |
| `%` | Jump to matching bracket |
| `*` / `#` | Search the word under the cursor forward / backward |

Counts multiply most commands: `5j`, `3w`, `10G`.

## 5. Editing

| Keys | Action |
|---|---|
| `x` / `r<c>` | Delete character / replace one character |
| `dd` / `3dd` / `dw` / `D` | Delete line / 3 lines / word / to end of line |
| `cw` / `cc` / `C` | Change word / line / to end of line (enters Insert) |
| `yy` / `5yy` / `yw` | Yank (copy) line / 5 lines / word |
| `p` / `P` | Paste after / before |
| `J` | Join the next line onto this one |
| `.` | Repeat the last change |
| `>>` / `<<` | Indent / unindent the line |
| `~` | Toggle case |

**Visual block editing** (comment out several lines): `Ctrl+v`, move down to select, `I#`, then `Esc`.

## 6. Search & Replace

````
/pattern          search forward  (n next, N previous)
?pattern          search backward
:s/old/new/       first match on the current line
:s/old/new/g      all matches on the current line
:%s/old/new/g     whole file
:%s/old/new/gc    whole file, confirm each
:%s/old/new/gi    whole file, ignore case
:10,20s/a/b/g     lines 10–20
:%s/\<hello\>/Hi/g        whole word only
:%s#/old/path#/new/path#g # another delimiter avoids escaping slashes
:set ic / :set noic       ignore case in searches
:set hlsearch / :noh      highlight / clear highlight
````

## 7. Ex (`:`) Commands

| Command | Action |
|---|---|
| `:5d` / `:5,10d` | Delete line 5 / lines 5–10 |
| `:3t7` (or `:3co7`) | Copy line 3 to after line 7 |
| `:3m7` | Move line 3 to after line 7 |
| `:g/^$/d` | Delete blank lines |
| `:g/pattern/d` / `:v/pattern/d` | Delete matching / non-matching lines |
| `:r file` / `:r !cmd` | Insert a file / a command's output |
| `:w newfile` / `:10,20w part.txt` | Save as / save a line range |
| `:w!` / `:wq!` | Force a write (e.g. a read-only file you own, or as root) |
| `:!cmd` | Run a shell command |
| `:set list` | Show tabs (`^I`) and line ends (`$`) |
| `:set paste` | Paste without auto-indent "staircasing" (then `:set nopaste`) |

## 8. Registers ("buffers") **[Advanced]**

| Register | Content |
|---|---|
| `"a`–`"z` | Named. `"ayy` yank into a, `"ap` paste from a; **uppercase appends** (`"Ayy`) |
| `"0` | Last yank |
| `"1`–`"9` | Recent line-wise deletes (shifted on each delete) |
| `"-` | Last small (within-line) delete |
| `".` `":` `"/` | Last inserted text / last command / last search |
| `"+` `"*` | System clipboard. **Only in clipboard-enabled builds** (not typical on RHEL servers) |

````
:reg          list all registers
:reg ab       only registers a and b
````

## 9. Configuration (`~/.vimrc`)

````vim
set number
syntax on
set tabstop=4 shiftwidth=4 expandtab   " spaces instead of tabs (good for YAML)
set hlsearch incsearch ignorecase smartcase
````

## 10. Swap Files & Recovery

vim keeps unsaved changes in `.file.swp` next to the file. Opening a file that has a swap file shows **`E325: ATTENTION`**. Two causes:

1. **A previous session crashed:** press `R` to recover, then save, then delete the swap file.
2. **Someone (or another of your terminals) is editing it now:** press `Q`/`A` and don't edit concurrently.

````bash
vim -r file          # recover from swap
ls -a | grep swp     # find leftover swap files; delete only once recovered
````

## 11. RHCSA Exam Focus

- Fast config edits: `vi /etc/fstab` → `o` new line → type → `Esc` → `:wq` → **validate** (`findmnt --verify`, `mount -a`).
- Use `visudo` (not vi) for `/etc/sudoers`; it checks syntax before saving.
- If anything goes wrong mid-edit: `Esc`, then `:q!`, and start again. Nothing is written until you save.
- `nano` may not be installed on exam systems; be fluent in vi.

## 12. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Typed text runs as commands | Not in Insert mode | `Esc`, `u` to undo, then `i` |
| "Stuck", can't quit | Wrong mode or pending command | `Esc Esc` then `:q!` |
| `E45: 'readonly' option is set` | No write permission or read-only open | `:w!` if you own the file; otherwise reopen with `sudo` (or `:w !sudo tee %` **[Advanced]**) |
| `E212: Can't open file for writing` | Directory missing or no permission | Check the path; use `sudo` |
| `E325: ATTENTION` | Existing swap file | See §10 |
| Pasted text indents like stairs | Auto-indent during paste | `:set paste` before pasting |
| Screen froze | `Ctrl+s` (XOFF) | `Ctrl+q` |

## 13. Course Practical Challenge (solutions)

| Step | Keys |
|---|---|
| Create a 10-line file | `vi ten.txt` → `i` → type 10 lines → `Esc` |
| Delete line 5 | `:5d` |
| Copy line 3 to after line 7 | `:3t7` |
| Replace "hello" with "Hi" everywhere | `:%s/hello/Hi/g` |
| Save and exit | `:wq` |

## 14. Quick Revision

````
i a o A I O | Esc | :w :q :wq :x ZZ :q! :e! | u Ctrl+r | gg G :N | / ? n N
dd yy p P x r cw dw D J . >> | v V Ctrl+v | :%s/a/b/gc | :g/^$/d | :3t7 :3m7
:set nu list paste ic hlsearch | "ayy "ap :reg | vim -r (swap) | visudo for sudoers
````

---

### 7. Updates to existing files

**`README.md`.** Under *Topic Index → Files & text processing*, append:

````markdown
- [I/O redirection & pipes](files-and-text-processing/io-redirection-and-pipes.md)
- [Text filters & pipelines](files-and-text-processing/text-filters.md)
- [Finding files: find & locate](files-and-text-processing/finding-files.md)
- [awk](files-and-text-processing/awk.md)
- [grep & regular expressions](files-and-text-processing/grep-and-regular-expressions.md)
- [vi & vim](files-and-text-processing/vi-and-vim.md)
````

In the *Session → Topic Map*, replace the 16–20 row with:

````markdown
| 16–20 | Redirection, filters, find/locate, awk, regex, vi | `files-and-text-processing/` (6 files) | Done (S17 theory supplemented) |
````

**`rhcsa-exam-labs/exam-objectives-map.md`.** In section 1, replace these three rows:

````markdown
| Use input-output redirection (`>`, `>>`, `\|`, `2>`, etc.) | 16 | [io-redirection-and-pipes.md](../files-and-text-processing/io-redirection-and-pipes.md) |
| Use grep and regular expressions to analyze text | 17, 20 | [grep-and-regular-expressions.md](../files-and-text-processing/grep-and-regular-expressions.md) |
| Create and edit text files | 7, 20 | [vi-and-vim.md](../files-and-text-processing/vi-and-vim.md) · [viewing-and-creating-file-contents.md](../files-and-text-processing/viewing-and-creating-file-contents.md) |
````

**`files-and-text-processing/viewing-and-creating-file-contents.md`.** In *10. Cross-References*, replace the "Redirection & pipes (S16), filters & grep (S17), `vi` (S20): planned" line with:

````markdown
- [Redirection & pipes](io-redirection-and-pipes.md) · [Text filters](text-filters.md) · [grep & regex](grep-and-regular-expressions.md) · [vi & vim](vi-and-vim.md)
````

---

**Gaps and practice**

1. **Supplemented content:** `text-filters.md` (S17 theory) and the vi survival, swap-file and visual-block sections. Send any lecture material I've missed and I'll merge it in.
2. **Highest-value drills:**
   - Compare `cmd > f 2>&1` with `cmd 2>&1 > f`.
   - Find user files and `cp -a` them into a directory.
   - Run `find -perm -4000` and `-nouser` searches.
   - Use `grep -Ev '^[[:space:]]*(#|$)'` on `sshd_config`.
   - Complete `vimtutor` once.
   - Recover from a deliberately killed vim session (`E325`).
3. **Advanced/Optional:** `sed` scripting, gawk `FPAT` for CSV, `ripgrep`, and vim macros (`q`).

**The "Understand and use essential tools" objective category is now fully covered.** The next logical batch is **Batch 6, Sessions 21–24** (local users, password management, profile files, groups). It covers the "Manage users and groups" objectives and will start `users-groups-and-permissions/`. The profile files in Session 23 will tie back to the variables and history notes.
