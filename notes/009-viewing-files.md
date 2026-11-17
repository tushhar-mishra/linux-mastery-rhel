# 009 · Viewing Files: cat, less, head, tail, wc, file

> **You need first:** [008 · Inodes and links](008-inodes-and-links.md)
> **Next:** [010 · vi and vim](010-vi-and-vim.md)

---

## What it is

Tools to **read** files without changing them:

| Need | Tool |
|---|---|
| Print a short file | `cat` (con**cat**enate) |
| Scroll and search a long file | `less` (better) or `more` |
| First / last N lines | `head` / `tail` |
| Watch a log grow live | `tail -F` |
| Count lines, words, bytes | `wc` (**w**ord **c**ount) |
| Print lines in reverse order | `tac` (`cat` backwards) |
| What kind of file is it? | `file` |
| Show hidden characters (tabs, Windows line endings) | `cat -A` |
| Readable text inside a binary program | `strings` |

A **pager** is a program that shows text one screen at a time (`less`, `more`). A **log** is a file where a program records what it did, line by line, usually with a timestamp.

## Why it exists

Reading configs and logs is most of an admin's day. The right tool matters:
- `cat` on a 5 GB log floods your terminal and can freeze your session. `less` opens it instantly because it reads only what it displays.
- Following a live log while you reproduce a bug is the fastest way to see what's going wrong.
- Invisible characters (Windows line endings, tabs vs spaces) break scripts and config files in ways you can't see with a normal view.

## Analogy

- `cat` = dumping a whole book on the table.
- `less` = a book you can flip forward and back, with an index search.
- `head` / `tail` = reading only the first or last page.
- `tail -F` = sitting next to a printer and reading each page as it comes out. If someone replaces the paper tray (log rotation), you keep reading the new tray.

## How it works inside

- `cat` reads the file from start to end and writes every byte to your terminal.
- `less` reads only as much as fits on the screen, and more when you scroll. It can jump to the end of a huge file without reading the middle. It uses the same keys as man pages (topic 005).
- `tail -n 10` jumps near the end of the file, reads backwards to find 10 line breaks, then prints from there.
- `tail -f` keeps the file **open** and checks for new data. The `-f` follows the open file. If the log is **rotated** (renamed to `messages-20261116` and a fresh `messages` created, topic 038), `tail -f` keeps watching the *old renamed file* and goes silent. **`tail -F`** follows the **name**: when the file is replaced, it notices and reopens the new one. Always use `-F` for logs.
- A **line** in Linux ends with one invisible "newline" character (shown as `\n` or `$`). **Windows** ends lines with two characters, "carriage return + newline" (`\r\n`, shown as `^M$`). These **CRLF** endings break shell scripts copied from Windows.
- `wc -l` counts newline characters. If the last line has no newline at the end, it isn't counted.
- `wc -c` counts **bytes**, not characters. In UTF-8 (the standard text encoding), characters like `é` or `₹` take 2–3 bytes. Use `wc -m` for characters.

## Commands

```bash
cat /etc/hostname
```
```
server1.example.com
```

```bash
cat -n /etc/shells
```
```
     1	/bin/sh
     2	/bin/bash
     3	/usr/bin/sh
     4	/usr/bin/bash
```
- `-n` numbers every line. `-b` numbers only non-blank lines.

```bash
cat -A script.sh
```
```
#!/bin/bash^M$
echo^I"hello"^M$
```
- `-A` shows **all** hidden characters: `$` marks each line end, `^I` is a tab, and `^M` is a carriage return. Seeing `^M$` means **Windows line endings**. Fix it with `sed -i 's/\r$//' script.sh` (topic 018) or `dos2unix script.sh`.

```bash
tac /etc/shells
```
```
/usr/bin/bash
/usr/bin/sh
/bin/bash
/bin/sh
```

```bash
less /var/log/messages      # needs root: sudo less /var/log/messages
```
Keys inside `less`:

| Key | Action |
|---|---|
| Space / `b` | Page down / up |
| `g` / `G` | Top / bottom of the file |
| `/text` / `?text` | Search forward / backward |
| `n` / `N` | Next / previous match |
| `F` | Follow mode (like `tail -f`). Ctrl+C stops following |
| `-N` (typed inside less) | Toggle line numbers |
| `-S` | Toggle wrapping of long lines |
| `q` | Quit |

`less -S file` opens with no line wrap, which is very useful for wide log lines. `less +G file` opens at the end.

```bash
head -n 3 /etc/passwd
```
```
root:x:0:0:Super User:/root:/bin/bash
bin:x:1:1:bin:/bin:/usr/sbin/nologin
daemon:x:2:2:daemon:/sbin:/usr/sbin/nologin
```
- The first 3 lines. (The format of this file is explained in topic 022.)

```bash
tail -n 2 /etc/passwd
```
```
alice:x:1000:1000:Alice:/home/alice:/bin/bash
bob:x:1001:1001::/home/bob:/bin/bash
```

| Form | Meaning |
|---|---|
| `head -n -5 file` | Everything **except** the last 5 lines |
| `head -c 100 file` | The first 100 bytes |
| `tail -n +5 file` | From line 5 to the end (skips a 4-line header) |

```bash
sudo tail -F /var/log/secure
```
```
Nov 16 20:26:06 server1 sshd-session[5976]: Accepted publickey for alice from 192.168.56.1 port 56497 ssh2: ED25519 SHA256:wyQC5ags7i8+vyyHlciARilNROwtWnoKxE8O6r0A+x4
Nov 16 20:26:07 server1 sshd-session[5976]: pam_unix(sshd:session): session opened for user alice(uid=1000) by alice(uid=0)
```
- Keeps printing new lines as they're written. Ctrl+C to stop.
- Each line has a timestamp, the hostname, the program and its process ID (`sshd-session[5976]`), then the message. Since OpenSSH 9.8, each login is handled by a separate `sshd-session` program, so that is the name you see; older systems say `sshd[PID]`. Here, Alice logged in with an SSH key. On Ubuntu this file is `/var/log/auth.log`.

```bash
wc /etc/passwd
```
```
  27   54 1397 /etc/passwd
```
- Three numbers: **lines**, **words**, **bytes**.

```bash
wc -l < /etc/passwd
```
```
27
```
- Just the number, with no file name. `<` feeds the file in as input (topic 016); handy in scripts.

| `wc` option | Counts |
|---|---|
| `-l` | Lines (newline characters) |
| `-w` | Words |
| `-c` | Bytes |
| `-m` | Characters |
| `-L` | Length of the longest line |

```bash
file notes.txt win.txt /usr/bin/ls backup.tar.gz
```
```
notes.txt:     ASCII text
win.txt:       ASCII text, with CRLF line terminators
/usr/bin/ls:   ELF 64-bit LSB pie executable, x86-64, version 1 (SYSV), dynamically linked, …
backup.tar.gz: gzip compressed data, from Unix, original size modulo 2^32 10240
```
- `file` looks at the actual bytes (the "magic number" at the start), not the name. `with CRLF line terminators` warns you it came from Windows.

```bash
sudo dnf install -y binutils      # strings comes from binutils, not in a minimal install
strings /usr/bin/ls | grep -i usage
```
```
Usage: %s [OPTION]... [FILE]...
```
- `strings` pulls readable text out of a binary. It's handy to find version strings, paths or error messages inside a program.

```bash
sed -n '10,20p' /etc/passwd
```
- Prints only lines 10–20. `sed` is covered in topic 018; this one form is worth memorising now.

```bash
od -c file | head -3          # byte-by-byte view; hexdump -C file is similar
```

Viewing compressed files without unpacking them (topic 021): `zcat`, `zless`, `zgrep` for `.gz`; `bzcat`, `bzless` for `.bz2`; `xzcat`, `xzless` for `.xz`.

### Try it
1. `cat -n /etc/os-release` then `wc -l /etc/os-release`. Do the numbers match?
2. Open `sudo less /var/log/messages` (Ubuntu: `/var/log/syslog`). Press `G`, then `?sshd`, then `n`.
3. In one terminal run `sudo tail -F /var/log/secure`. In another, SSH into the machine. Watch the login appear.
4. Create a Windows-style file with `printf 'a\r\nb\r\n' > win.txt` and inspect it with `file` and `cat -A`.

**Check your work:** on your lab VM, from the notes folder, run `sudo ./checks/check 009` for every step, or `sudo ./checks/check 009 STEP` for one (topic 002 shows how to get the notes there).

## Where you'll use it

- **Live debugging:** `tail -F` on the app log in one window while you send test requests in another.
- **Huge logs:** `less +G app.log`, then `?ERROR` to search backward from the end.
- **Quick counts:** "how many lines/users/errors?" → `wc -l`.
- **Broken script from a colleague's Windows laptop:** `file` or `cat -A` shows CRLF instantly.
- **Containers:** `kubectl logs -f` and `docker logs -f` are the same idea as `tail -f`, for container output.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| Terminal floods with text or freezes | `cat` on a huge file | Ctrl+C; use `less` |
| Garbage on screen after `cat` | You printed a binary file | Type `reset`; check with `file` first |
| `tail -f` stops showing new lines | The log was rotated; `-f` follows the old file | Use `tail -F` |
| `Permission denied` reading `/var/log/...` | Many logs are readable only by root | `sudo less …` or `journalctl` (topic 038) |
| `/bin/bash^M: bad interpreter` running a script | Windows CRLF line endings | `sed -i 's/\r$//' script` or `dos2unix` |
| `wc -l` is one less than you expect | The last line has no trailing newline | `tail -c1 file \| od -c` to check |

## Quick recap

- `cat` for short files, `less` for long ones (`/` search, `G` end, `F` follow, `q` quit).
- `head -n N` / `tail -n N` / `tail -n +N`. Use **`tail -F`** for logs (survives rotation).
- `wc -l -w -c -m`: lines, words, bytes, characters.
- `file` tells the real type; `cat -A` reveals tabs and Windows `^M` line endings.

**Interview questions**

1. *`tail -f` vs `tail -F`?* `-f` follows the open file; after log rotation it keeps watching the old renamed file. `-F` follows the file name and reopens the new file after rotation.
2. *`more` vs `less`?* `less` scrolls both directions, searches better and doesn't load the whole file first.
3. *What does `cat -A` show?* Tabs as `^I`, line ends as `$`, carriage returns as `^M`, and other control characters. It's useful for spotting Windows line endings and stray whitespace.

**Scenario question** (answer out loud first, then compare)

> *"You're watching an application log with `tail -f` during an incident, and the output stops at midnight even though the app is still busy. What happened?"*

**Model answer:**
1. Log rotation ran at midnight: `app.log` was renamed (to `app.log-20261117`) and a new `app.log` was created.
2. `tail -f` follows the **open file**, so it's still watching the old, renamed file, which nobody writes to any more.
3. Use **`tail -F`**: it follows the **name**, notices the new file and reopens it.
4. Or, if the app logs to the journal, `journalctl -fu app` doesn't have this problem.

**Likely follow-ups:**
- *A config file from a Windows colleague gives strange errors. How do you check it?* `file conf` says "with CRLF line terminators"; `cat -A` shows `^M$` at line ends. Fix it with `sed -i 's/\r$//'` or `dos2unix`.
- *How do you see the last 50 lines of a huge file without loading it all?* `tail -n 50 file`, or `less +G file`. `less` doesn't read the whole file first.
