# Viewing & Creating File Contents

> **Sessions:** S7 (practice) · theory supplemented · **Objective:** *Create and edit text files* (partial; `vi` in S20) **[RHCSA Core]**
> **Related:** [Archiving & compression](archiving-and-compression.md) · [Files & directories](../shell-and-command-line/files-and-directories.md) · Redirection (S16) · Filters, grep (S17) · vi (S20)

## 1. Overview

Admins read files constantly (configs, logs) and create small ones quickly (repo files, test data, configs). This note covers read-only viewing (`cat`, `less`, `head`, `tail`, `wc`) and fast creation without an editor (`echo`, `printf`, heredocs, `tee`). Full redirection theory is in S16; interactive editing with `vi` is in S20.

## 2. Viewing Files

### 2.1 Which tool to use

| Need | Tool |
|---|---|
| Short file, print it all | `cat` |
| Long file, scroll and search | `less` (preferred) / `more` |
| First or last N lines | `head` / `tail` |
| Follow a growing log live | `tail -f` / `tail -F` / `less +F` |
| Count lines, words, bytes | `wc` |
| Reverse line order | `tac` |
| Is it text? which encoding? CRLF? | `file` |
| Show hidden characters | `cat -A` |
| Printable strings in a binary | `strings` |
| Compressed files | `zcat`/`zless`, `bzcat`/`bzless`, `xzcat`/`xzless` (see [compression](archiving-and-compression.md)) |

### 2.2 `cat` and `tac`

```bash
cat /etc/group                 # print the file
cat -n file                    # number all lines (-b: number non-blank only)
cat -A file                    # show tabs (^I), line ends ($), CR (^M), non-printing chars
cat -s file                    # squeeze repeated blank lines
cat f1 f2 > combined           # concatenate, the original purpose of cat
tac file                       # last line first
```

### 2.3 `less` vs `more`

| | `more` | `less` |
|---|---|---|
| Scroll back | Limited | Yes |
| Search | `/pattern` | `/` forward, `?` backward, `n`/`N` |
| Large files | Reads sequentially | Opens instantly; doesn't load the whole file |
| Extras | — | `-N` line numbers, `-S` don't wrap long lines, `F` follow mode, `g`/`G` top/bottom |

Same keys as man pages (`Space`, `b`, `/`, `n`, `N`, `q`); see [getting help](../shell-and-command-line/getting-help-and-documentation.md#23-navigation-the-pager-is-less).

### 2.4 `head` and `tail`

```bash
head -n 6 /etc/passwd          # first 6 lines (obsolete form: head -6)
head -n -5 file                # all EXCEPT the last 5 lines
head -c 100 file               # first 100 bytes
tail -n 12 /etc/passwd         # last 12 lines
tail -n +5 file                # from line 5 to the end (skip a header)
sudo tail -f /var/log/messages # follow by file descriptor (stops tracking after rotation)
sudo tail -F /var/log/secure   # follow by NAME, survives log rotation (prefer for logs)
sed -n '10,20p' file           # lines 10–20 (sed covered in S17)
```

### 2.5 `wc`

| Option | Counts | Note |
|---|---|---|
| `-l` | Newline characters | A last line without a trailing newline is **not counted** |
| `-w` | Words | |
| `-c` | **Bytes** | Not characters |
| `-m` | Characters | Differs from `-c` for multi-byte UTF-8 text |
| `-L` | Length of the longest line | |

```bash
wc -l /etc/passwd              # 42 /etc/passwd
wc -l < /etc/passwd            # 42, number only (handy in scripts)
getent passwd | wc -l          # count accounts from all sources (S21)
```

> ⚠️ **Course correction:** `wc -c` counts **bytes**, not characters. Use `wc -m` for characters.

### 2.6 Inspecting file type and hidden characters

```bash
file notes.txt                 # ASCII text  |  ... with CRLF line terminators (Windows file)
cat -A notes.txt | head        # ^M$ at line ends = CRLF
sed -i 's/\r$//' notes.txt     # convert CRLF → LF (or dos2unix if installed)
strings /usr/bin/ls | less     # readable strings inside a binary
od -c file | head              # [Advanced] byte-level view (also: hexdump -C)
```

CRLF line endings in scripts cause errors like `/bin/bash^M: bad interpreter`.

## 3. Creating & Appending Content

### 3.1 Methods

| Method | Use | Example |
|---|---|---|
| `>` | Create/**overwrite** | `echo "text" > file` |
| `>>` | Append | `echo "more" >> file` |
| `cat > file` | Type lines interactively; `Ctrl+D` to finish | `cat > ten.txt` |
| Heredoc | Multi-line content in one command (**best for exam configs**) | below |
| `printf` | Exact formatting, portable | `printf '%s\n' a b c > file` |
| `tee` | Write to a file **and** stdout; works with `sudo` | below |
| `touch` | Empty file / update timestamp | `touch file` |

### 3.2 `echo` vs `printf`

```bash
echo "Nehra Classes Are Awesome." > nehraclasses.txt
echo '"Igniting the Minds"' >> nehraclasses.txt    # single quotes keep the double quotes literally
echo -n "no newline"            # suppress the trailing newline
echo -e "a\tb\nc"               # interpret escapes (bash builtin echo)
printf '%s\n' line1 line2 > f   # one argument per line, predictable everywhere
printf 'Name: %s, UID: %d\n' alice 1001
```

Quoting rules (single vs double quotes, `$` expansion) are covered in S9–15.

### 3.3 Heredocs **[RHCSA Core technique]**

```bash
cat > /etc/yum.repos.d/local.repo <<'EOF'
[local-baseos]
name=Local BaseOS
baseurl=file:///mnt/iso/BaseOS
enabled=1
gpgcheck=0
EOF
```

- Quoting the delimiter (`'EOF'`) prevents `$var` and `$(cmd)` expansion; the text is written literally.
- An unquoted `EOF` expands variables, which is useful for templating.
- `<<-EOF` strips leading **tabs** (not spaces), for indented scripts.
- The closing `EOF` must be alone on its line, with no trailing spaces.

### 3.4 Writing root-owned files: `sudo` + `tee`

```bash
sudo echo "nameserver 1.1.1.1" > /etc/resolv.conf   # ✘ Permission denied:
                                                     #   the redirection is done by YOUR shell, not sudo
echo "192.168.122.20 serverb" | sudo tee -a /etc/hosts      # ✔ append as root
sudo tee /etc/motd >/dev/null <<'EOF'                       # ✔ overwrite, multi-line, quiet
Authorized use only.
EOF
```

> ⚠️ `>` **truncates the target immediately**, even if the command then fails. `sort file > file` produces an empty file. Use `set -o noclobber` in interactive shells to block accidental overwrites (`>|` forces one).

## 4. RHCSA Exam Focus **[RHCSA Core]**

- Create config and repo files with a **heredoc** or `tee`; it's fast and exact. Verify with `cat -A` if whitespace matters.
- `>` vs `>>`: tasks often say "append." Overwriting `/etc/hosts` or `/etc/fstab` can break other tasks.
- Logs under `/var/log` need root: `sudo tail`, `sudo less`, or `journalctl` (S55).
- Count things exactly: `grep -c pattern file` or `… | wc -l` (S17).

## 5. Production Practices **[Production Practice]**

- Use `less`, not `cat`, on unknown or large files; `cat` on a multi-GB log can flood your terminal.
- `tail -F` survives logrotate; `tail -f` silently stops at the rotated file.
- Before editing configs, take a backup: `cp -a file{,.bak.$(date +%F)}`. After editing, validate with the service's checker (`sshd -t`, `visudo -c`, `nginx -t`, `findmnt --verify`).
- In scripts, prefer `printf` over `echo` for predictable output.

## 6. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Permission denied` with `sudo echo … > /etc/x` | Redirection runs as your user | `… \| sudo tee /etc/x` |
| File unexpectedly empty | Truncated by `>` (e.g., `cmd file > file`) | Write to a temp file, then `mv`; restore from backup |
| `wc -l` is one less than expected | Last line lacks a trailing newline | `tail -c1 file \| od -c`; append a newline |
| `bad interpreter: /bin/bash^M` | CRLF line endings | `sed -i 's/\r$//' script` |
| Terminal shows garbage after `cat binary` | Binary output changed terminal state | `reset`; use `file`/`strings`/`less` first |
| `tail -f` stops showing new lines | Log was rotated | `tail -F` |
| Heredoc never ends | Closing `EOF` indented or has trailing spaces | Put `EOF` alone at column 1 (or use `<<-` with tabs) |

## 7. Interview Questions

| Question | Answer |
|---|---|
| Why does `sudo echo x > /etc/file` fail? | Redirection is performed by the calling (non-root) shell before sudo runs. Use `sudo tee` or `sudo sh -c '…'`. |
| `tail -f` vs `tail -F`? | `-f` follows the open file descriptor; `-F` follows the name and reopens after rotation. |
| `more` vs `less`? | `less` scrolls both ways, searches better and doesn't read the whole file first. |
| What does `cat -A` reveal? | Tabs (`^I`), line ends (`$`), carriage returns (`^M`), control characters. |
| Why might `sort file > file` destroy data? | The shell truncates `file` before `sort` reads it. |
| Quoted vs unquoted heredoc delimiter? | Quoted: content is literal. Unquoted: `$vars` and `$(cmds)` are expanded. |

## 8. Course Practice Questions (corrected)

| # | Task | Command | Note |
|---|---|---|---|
| 1 | Top 6 lines of `/etc/passwd` | `head -n 6 /etc/passwd` | `head -6` is the obsolete form |
| 2 | Bottom 12 lines | `tail -n 12 /etc/passwd` | |
| 3 | Show `/etc/group` | `cat /etc/group` | |
| 4 | Page through `/var/log/messages` | `sudo more /var/log/messages` (better: `sudo less`) | File is root-only |
| 5 | Create a 10-line file | `cat > ten.txt` … `Ctrl+D` | Or `seq 1 10 > ten.txt` for test data |
| 6 | Reverse it | `tac ten.txt` | |
| 7 | Count lines | `wc -l ten.txt` | |
| 8 | Count characters | `wc -m ten.txt` | `wc -c` counts **bytes** |
| 9 | Create with echo | `echo "Nehra Classes Are Awesome." > nehraclasses.txt` | |
| 10 | Append a quoted line | `echo '"Igniting the Minds"' >> nehraclasses.txt` | Single quotes keep the inner `"` |

## 9. Quick Revision

```bash
less file | head -n N | tail -n N | tail -n +N | sudo tail -F log
cat -n / -A | tac | wc -l -w -c -m | file | strings
echo x > f (overwrite) | >> (append) | printf '%s\n' | cat > f <<'EOF' … EOF
cmd | sudo tee [-a] /etc/file      # write root-owned files
```

## 10. Cross-References

- [Archiving & compression](archiving-and-compression.md) (`zcat`, `zless`, `xzgrep`)
- Redirection & pipes (S16), filters & grep (S17), `vi` (S20): planned in this folder
- Journal & logs (S55): `logs-scheduling-and-packages/` (planned)
