# Text Filters & Pipelines

> Supports *Use grep and regular expressions to analyze text* **[RHCSA Core]**
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

```bash
cut -d: -f1 /etc/passwd             # usernames
cut -d: -f1,7 /etc/passwd           # username:shell
cut -c1-8 file                      # first 8 characters of each line
```

`cut` treats **each** delimiter as a separator, so it can't handle runs of spaces. Use `awk '{print $2}'` or `tr -s ' ' | cut -d' ' -f2`.

### tr

```bash
echo "abc123def456" | tr -d '0-9'          # abcdef
tr '[:lower:]' '[:upper:]' < f             # uppercase
echo "a   b    c" | tr -s ' '              # a b c (squeeze)
tr -d '\r' < win.txt > unix.txt            # strip CR from CRLF files
```

### sort and uniq

```bash
sort -t: -k3 -n /etc/passwd | head         # by UID, numerically
du -sh /var/* 2>/dev/null | sort -h        # human-readable sizes
sort -u names.txt                          # unique (sorted)
cut -d: -f7 /etc/passwd | sort | uniq -c | sort -rn   # count of each login shell
uniq -d sorted.txt                         # only lines that repeat
```

`uniq` only removes **adjacent** duplicates; always `sort` first.

### sed (basics)

```bash
sed 's/old/new/' f            # first match per line → stdout
sed 's/old/new/g' f           # all matches
sed -n '10,20p' f             # print lines 10–20 only
sed '/^#/d; /^$/d' f          # drop comments and blank lines
sed -E 's/([0-9]+)/<\1>/g' f  # ERE with backreference
sed -i.bak 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config.d/40-local.conf
```

> ⚠️ `sed -i` edits **in place**. Use `-i.bak` to keep a backup, test without `-i` first, and validate configs afterwards (`sshd -t`).

### Classic pipelines

```bash
who | awk '{print $2}' | sort -u                     # logged-in terminals
grep -c 'processor' /proc/cpuinfo                    # CPU count (or nproc)
sudo grep 'Failed password' /var/log/secure \
  | grep -oE 'from [0-9.]+' | sort | uniq -c | sort -rn | head    # top failed-login IPs
ps -eo user= | sort | uniq -c | sort -rn             # processes per user
```

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

## 8. Practice Exercises (with Solutions)

| # | Task | Better command | Note |
|---|---|---|---|
| 1 | Users with `/bin/sh`, sorted | `awk -F: '$7=="/bin/sh"{print $1}' /etc/passwd \| sort > shusers.txt` | Course's unanchored `grep '/bin/sh'` can match other fields; `grep ':/bin/sh$'` also works |
| 2 | Logged-in terminals | `who \| awk '{print $2}' \| sort -u > onlineterminals.txt` | ✔ |
| 3 | Names in `/var/log` containing "log" | `ls /var/log \| grep log > logfile_names.txt` | ✔ (interactive use; `find /var/log -maxdepth 1 -name '*log*'` in scripts) |
| 4 | Files in `/usr/bin` matching "python" (any case) | `ls /usr/bin \| grep -i python \| sort > pythonfiles.txt` | ✔ |
| 5 | IP/prefix of non-loopback interfaces | `ip -4 -o addr show scope global \| awk '{print $4}'` | ⚠️ Course's `grep -v 'lo'` also removes lines with "g**lo**bal", which hides real addresses. Output is CIDR (`/24`), not a dotted mask |
| 6 | Remove digits | `tr -d '0-9'` | ✔ |

## 9. Quick Revision

```bash
grep | cut -d: -f1 | tr -d/-s | sort -n -r -k -t -u -h | uniq -c | wc -l | tee
sed 's/a/b/g' | sed -n 'Np' | sed '/re/d' | sed -i.bak
… | sort | uniq -c | sort -rn | head      # frequency count pattern
```

## 10. Cross-References

- [I/O redirection & pipes](io-redirection-and-pipes.md)
- [grep & regular expressions](grep-and-regular-expressions.md)
- [awk](awk.md)
- [Finding files (xargs)](finding-files.md)
