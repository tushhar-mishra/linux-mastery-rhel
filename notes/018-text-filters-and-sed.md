# 018 · Text Filters and sed: cut, tr, sort, uniq, paste, diff

> **You need first:** [017 · grep and regular expressions](017-grep-and-regular-expressions.md)
> **Next:** [019 · awk](019-awk.md)

---

## What it is

A **filter** is a small program that reads text (from stdin or files), changes it in one specific way, and writes the result to stdout. You chain filters with pipes (topic 016).

| Tool | Job |
|---|---|
| `cut` | Pull out columns or character ranges |
| `tr` | **Tr**anslate, delete or squeeze single characters |
| `sort` | Sort lines |
| `uniq` | Collapse **adjacent** duplicate lines (and count them) |
| `wc` | Count lines, words, bytes (topic 009) |
| `head` / `tail` | First / last lines (topic 009) |
| `sed` | **S**tream **ed**itor: find-and-replace, delete or print lines, edit files in place |
| `paste` | Join lines side by side, or join all lines into one |
| `column` | Align text into neat columns |
| `nl` | Number lines |
| `rev` | Reverse the characters on each line |
| `diff` | Show the differences between two files |
| `comm` | Compare two **sorted** files: lines only in A, only in B, in both |

A **field** (or column) is a piece of a line between **delimiters**, the separator characters. In `/etc/passwd`, fields are separated by `:`.

## Why it exists

Most admin questions are "count / rank / extract / rewrite this text": which shells are in use, which IPs fail logins most, change a setting in 50 config files. Chaining filters answers these with no programming, and the same pipeline works on 10 lines or 10 million.

## Analogy

Filters are **stations on a factory conveyor belt**. Text flows along the belt. One station cuts out a column (`cut`), the next sorts (`sort`), the next groups and counts (`uniq -c`), and the last keeps the top 10 (`head`). Each station does one simple job well, and you build any product by rearranging stations.

## How it works inside

- Most filters process input **as a stream**: read a line, transform it, write it out. Memory stays tiny even for huge files.
- **`sort` is the exception.** It must see **all** input before it can print anything. For very large input it writes sorted chunks to temporary files (in `/tmp`, or wherever `-T` points) and merges them. That's why a huge `sort` can fill `/tmp`.
- **`uniq` only compares each line with the line just before it.** Duplicates that aren't next to each other aren't noticed. That's why it's always `sort | uniq`.
- `sort` order depends on the **locale** (topic 013). `LC_ALL=C sort` is faster and gives plain byte order.
- **`sed`** reads one line at a time into a working area (the "pattern space"), applies your commands to it, prints it (unless `-n`), and moves on. With `-i`, sed writes the output to a **new temporary file and then renames it over the original**. That means the file gets a **new inode** (topic 008), and hard links to the old file no longer point to the edited version.

## Commands

### cut

```bash
cut -d: -f1 /etc/passwd | head -3
```
```
root
bin
daemon
```
- `-d:` sets the delimiter to `:`. `-f1` keeps field 1 (the user name).

```bash
cut -d: -f1,7 /etc/passwd | tail -2
```
```
alice:/bin/bash
bob:/bin/bash
```
- Fields 1 and 7: user and login shell.

```bash
cut -c1-10 /var/log/messages | head -1
```
```
Nov 16 10:
```
- `-c` = character positions.

**Limit:** `cut` treats **every** delimiter as a separator, so it can't handle "several spaces in a row". For space-separated output (like `ps` or `df`), use `awk '{print $2}'` (topic 019), or squeeze the spaces first with `tr -s ' '`.

### tr

```bash
echo "Hello World 123" | tr 'a-z' 'A-Z'
echo "abc123def456" | tr -d '0-9'
echo "a    b     c" | tr -s ' '
tr -d '\r' < windows.txt > unix.txt
```
```
HELLO WORLD 123
abcdef
a b c
```
- Translate letters, `-d` delete characters, `-s` squeeze repeats into one. The last line strips Windows carriage returns.
- `tr` reads **only stdin**, never a file name. Use `<` or a pipe.

### sort

```bash
sort -t: -k3 -n /etc/passwd | tail -3
```
```
nobody:x:65534:65534:Kernel Overflow User:/:/usr/sbin/nologin
```
(the last 3 lines, by UID)
- `-t:` delimiter, `-k3` sort by field 3, `-n` numeric.

| Option | Effect |
|---|---|
| `-n` | Numeric (otherwise `10` sorts before `9`) |
| `-r` | Reverse |
| `-k N` or `-k N,N` | Sort by field N (`-k2,2` = only field 2) |
| `-t X` | Field delimiter |
| `-u` | Remove duplicates |
| `-h` | Human sizes (`1K`, `2M`, `3G`) |
| `-V` | Version order (`1.9` before `1.10`) |
| `-f` | Ignore case |
| `-o FILE` | Write output to FILE (safe even if FILE is the input) |
| `-T DIR` | Temporary directory for huge sorts |

```bash
du -sh /var/* 2>/dev/null | sort -h | tail -3
```
```
41M	/var/log
188M	/var/lib
1.1G	/var/cache
```

### uniq (after sort!)

```bash
cut -d: -f7 /etc/passwd | sort | uniq -c | sort -rn
```
```
     15 /usr/sbin/nologin
      6 /sbin/nologin
      2 /bin/bash
      1 /sbin/shutdown
      1 /sbin/halt
      1 /bin/sync
      1 /bin/false
```
- The most important pipeline pattern in Linux: **extract → sort → uniq -c → sort -rn → head**. It's a frequency count, most common first.
- `uniq -c` puts a count before each unique line.
- `/sbin/nologin` and `/usr/sbin/nologin` are the same program (/sbin links to /usr/sbin, topic 006), but `uniq` compares **text**, so they count separately. Normalise first if you need true totals: `sed 's#^/sbin/#/usr/sbin/#'`.

| `uniq` option | Effect |
|---|---|
| `-c` | Count |
| `-d` | Show only lines that appear more than once |
| `-u` | Show only lines that appear exactly once |
| `-i` | Ignore case |

### sed

```bash
sed 's/http/HTTPS/' file        # replace the FIRST match on each line
sed 's/http/HTTPS/g' file       # replace ALL matches (g = global)
sed 's/http/HTTPS/2' file       # replace only the 2nd match on each line
sed -n '10,20p' file            # print only lines 10-20 (-n = don't print by default; p = print)
sed -n '/ERROR/p' file          # like grep
sed '/^#/d; /^$/d' file         # delete comment lines and blank lines
sed '5d' file                   # delete line 5
sed '$d' file                   # delete the last line
sed '3i\new line above 3' file  # insert before line 3
sed '3a\new line after 3' file  # append after line 3
sed -E 's/([0-9]+)-([0-9]+)/\2-\1/' file   # ERE with groups: swap two numbers
sed 's#/old/path#/new/path#g' file         # use # as separator to avoid escaping /
```

The **address** before a command chooses which lines it applies to: a line number (`5`), a range (`10,20`), the last line (`$`), a regex (`/ERROR/`), or a regex range (`/start/,/end/`).

**Editing a config file in place (carefully):**
```bash
sudo sed -i.bak 's/^#\?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sshd -t && echo "config OK"
```
```
config OK
```
- `-i.bak` edits the file and keeps the original as `sshd_config.bak`.
- `^#\?` matches an optional leading `#` (BRE), so it works whether the line was commented out or not.
- **Always:** test without `-i` first (it prints to the screen), keep a backup, and validate the config (`sshd -t`, `nginx -t`, …) before reloading the service.

### paste, column, nl, rev

```bash
cut -d: -f1 /etc/passwd | head -4 | paste -sd,
```
```
root,bin,daemon,adm
```
- `paste -s` joins all lines into one; `-d,` uses commas. Handy for building lists.

```bash
mount | head -3 | column -t
```
- Lines up columns neatly.

```bash
nl /etc/shells ; echo "hello" | rev
```
```
     1	/bin/sh
     2	/bin/bash
...
olleh
```

### diff and comm

```bash
sudo diff -u /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
```
```
--- /etc/ssh/sshd_config.bak	2026-09-14 12:52:16.544114070 +0000
+++ /etc/ssh/sshd_config	2026-11-16 23:10:17.126612168 +0000
@@ -37,7 +37,7 @@
 # Authentication:
 
 #LoginGraceTime 2m
-#PermitRootLogin prohibit-password
+PermitRootLogin no
 #StrictModes yes
 #MaxAuthTries 6
 #MaxSessions 10
```
- `-u` = "unified" format: the same format Git and code reviews use.
- Lines starting with `-` were removed, lines with `+` were added, and lines with a space are unchanged context. `@@ -37,7 +37,7 @@` means "starting at line 37, 7 lines, in both files" (3 context lines, the change, 3 more context lines).

```bash
comm -12 <(sort a.txt) <(sort b.txt)
```
- Prints lines found in **both** files. `-1` hides "only in A", `-2` hides "only in B". `<( … )` is **process substitution**: bash gives the output of a command to another command as if it were a file.

### Classic pipelines

```bash
sudo grep 'Failed password' /var/log/secure \
  | grep -oE 'from [0-9.]+' | sort | uniq -c | sort -rn | head -5
```
```
    212 from 203.0.113.50
     87 from 198.51.100.7
      3 from 192.168.56.1
```
- The top sources of failed SSH logins. A real security check.

```bash
ps -eo user= | sort | uniq -c | sort -rn | head -3
```
```
     98 root
     12 alice
      4 chrony
```
- Processes per user (`ps` is topic 033).

```bash
awk '{print $1}' access.log | sort | uniq -c | sort -rn | head
```
- Top client IPs in a web log (awk is next).

### Try it
1. List each login shell in `/etc/passwd` with a count, most common first.
2. Turn `/etc/hostname` into uppercase with `tr`.
3. Copy `/etc/ssh/sshd_config` to `/tmp/s`. With `sed -i`, change `#Port 22` to `Port 2222` in the copy, then check with `diff -u`.
4. Print lines 5–8 of `/etc/passwd` using `sed`, then using `head` and `tail` together.

## Where you'll use it

- **Log analysis:** top IPs, top URLs, top error messages, errors per hour.
- **Config changes across many servers:** `sed -i` inside Ansible or scripts (validate after!).
- **Reviewing changes:** `diff -u` before and after editing a config; it's the same format as Git diffs.
- **Building lists for other commands:** `… | paste -sd,` for comma-separated host lists.
- **Kubernetes:** `kubectl get pods -A --no-headers | awk '{print $4}' | sort | uniq -c` gives a count of pods per status.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `uniq` leaves duplicates | Input wasn't sorted | `sort \| uniq`, or `sort -u` |
| `cut -d' '` gives empty fields | Several spaces in a row | Use `awk`, or `tr -s ' '` first |
| `sort` puts `10` before `9` | Text sort, not numeric | `sort -n` (or `-V` for versions, `-h` for sizes) |
| `tr: extra operand` | `tr` takes no file argument | `tr … < file` |
| `sed -i` broke a config | Untested in-place edit | Restore the `.bak`; test without `-i`; validate |
| `sed: -e expression #1, char N: unknown option to s` | The pattern contains `/` | Use a different separator: `s#a/b#c/d#` |
| Huge `sort` fails with "No space left" | Temp files filled `/tmp` | `sort -T /bigdisk/tmp`, or `LC_ALL=C sort` |
| A hard link to the file didn't change after `sed -i` | `sed -i` creates a new inode | Edit in place with an editor, or update the links |

## Quick recap

- `cut -d: -f1` for fields, `tr` for characters (stdin only), `sort -n -r -k -t -h -V`, `uniq -c` after `sort`.
- Frequency-count pattern: `… | sort | uniq -c | sort -rn | head`.
- `sed 's/a/b/g'`, `sed -n '10,20p'`, `sed '/re/d'`, `sed -i.bak` (test first, validate after).
- `diff -u` shows changes in the same format as Git.

**Interview questions**

1. *Why must you sort before `uniq`?* `uniq` only compares each line with the one before it; duplicates must be adjacent.
2. *When would you use `awk` instead of `cut`?* When fields are separated by runs of spaces, or when you need conditions or calculations. `cut` only handles a single-character delimiter.
3. *What does `sed -n '5p' file` do?* `-n` turns off automatic printing, then `5p` prints only line 5.
