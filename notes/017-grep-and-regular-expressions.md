# 017 · grep and Regular Expressions

> **You need first:** [016 · Redirection and pipes](016-redirection-and-pipes.md)
> **Next:** [018 · Text filters and sed](018-text-filters-and-sed.md)

---

## What it is

- **grep** (from the old editor command `g/re/p`: **g**lobally search for a **r**egular **e**xpression and **p**rint) prints the **lines** of a file or stream that match a pattern.
- A **regular expression** (regex) is a small language for describing text patterns: "a line that starts with a date", "an IP address", "ERROR or WARN".

Regex is used everywhere: `grep`, `sed`, `awk`, `vim`, `find -regex`, bash `[[ =~ ]]`, `journalctl -g`, SELinux `semanage fcontext`, log shippers, monitoring alerts and every programming language.

## Why it exists

Servers produce huge amounts of text: logs, configs, command output. You rarely read it all. You **search** it: "show me only the errors", "which config file sets this port?", "how many failed logins came from this IP?". grep plus regex answers these in seconds, across gigabytes.

## Analogy

grep is a **highlighter pen run over every line of a book**: it keeps only the lines where it found something. A regex is the **description you give the highlighter**. "The word cat" is simple. "Any word that starts with a capital letter and ends in a number" is a regex.

## How it works inside

1. grep reads its input **one line at a time**.
2. For each line it asks: "does the pattern match **anywhere** in this line?" (unless you anchor it with `^`/`$`, or use `-x`/`-w`).
3. Matching lines are printed. With `-o`, only the matched part is printed.
4. The regex is compiled once into a fast matching machine (a state machine), so grep is very quick even on huge files.

**Exit status** makes grep perfect for scripts:

| Status | Meaning |
|---|---|
| `0` | At least one line matched |
| `1` | No match |
| `2` | Error (unreadable file, bad pattern), even if other files matched |

Two facts prevent most mistakes:
1. **The shell sees your pattern first.** Always put regexes in **single quotes**, so `*`, `$`, `\`, `[` and `|` reach grep unchanged.
2. **Globs and regexes are different languages** (topic 013). In a glob `*` means "anything". In a regex, `*` means "zero or more of the previous item", and "anything" is `.*`.

### Regex flavours

| Flavour | grep option | Used by | Characters that are special without a backslash |
|---|---|---|---|
| **BRE** (Basic Regular Expressions) | `grep` (default) | `grep`, `sed`, `vi` | `.` `*` `[ ]` `^` `$` |
| **ERE** (Extended Regular Expressions) | `grep -E` | `grep -E`, `sed -E`, `awk`, bash `=~` | Also `+` `?` `\|` `( )` `{ }` |
| **PCRE** (Perl-Compatible Regular Expressions) | `grep -P` | Most programming languages | Adds `\d` (digit), `\s` (space), `\w` (word char), lazy `*?`, lookarounds |
| **Fixed string** | `grep -F` | — | Nothing special: fastest and safest for literal text |

GNU BRE has the same operators as ERE, but they need a backslash (`\+`, `\?`, `\|`, `\(…\)`, `\{n,m\}`). **Rule of thumb:** use `grep -E` whenever you need `+ ? | ( ) { }`, and `grep -F` for literal strings like IP addresses and paths. `egrep`/`fgrep` are deprecated names for `grep -E`/`grep -F`.

### Building blocks

**Characters and sets**

| Pattern | Matches |
|---|---|
| `a` | The letter a |
| `.` | Any **one** character |
| `[abc]` | One of a, b, c |
| `[a-z]`, `[0-9]` | One character in the range |
| `[^abc]` | One character **not** in the set (`^` first inside brackets) |
| `[[:digit:]]` `[[:alpha:]]` `[[:alnum:]]` `[[:upper:]]` `[[:lower:]]` `[[:space:]]` `[[:punct:]]` | Named classes (note the **double** brackets) |
| `\.` | A literal dot. A backslash makes any special character literal |

**Anchors**

| Pattern | Matches |
|---|---|
| `^text` | `text` at the **start** of the line |
| `text$` | `text` at the **end** of the line |
| `^$` | An empty line |
| `\<word\>` or `\bword\b` | `word` as a whole word |

**Quantifiers** (they apply to the item **just before** them)

| ERE | BRE | Meaning |
|---|---|---|
| `*` | `*` | 0 or more |
| `+` | `\+` | 1 or more |
| `?` | `\?` | 0 or 1 (optional) |
| `{n}` | `\{n\}` | Exactly n |
| `{n,}` | `\{n,\}` | n or more |
| `{n,m}` | `\{n,m\}` | Between n and m |

**Greedy matching:** quantifiers grab the **longest** possible match. `<.*>` on `<a><b>` matches the whole `<a><b>`. To stop at the first `>`, use a negated set, `<[^>]*>`, or PCRE's lazy `<.*?>`.

**Groups, alternatives, back-references** (ERE)

| Pattern | Meaning |
|---|---|
| `(GET\|POST)` | Either word |
| `(ab)+` | `ab` repeated |
| `(.)\1` | The same character twice (`\1` = "whatever group 1 matched") |

## Commands

Sample file `app.log` used below:
```
2026-10-24 09:00:01 INFO  web01 GET /index.html 200 0.012
2026-10-24 09:00:02 WARN  web01 GET /login 401 0.034
2026-10-24 09:00:03 ERROR db01  connection refused: 10.0.0.15:5432
2026-10-24 09:00:04 INFO  web02 POST /api/v1/orders 201 0.210
2026-10-24 09:00:05 error web02 timeout after 30s
2026-10-24 09:00:06 INFO  web01 GET /health 200 0.001
# maintenance window start
2026-10-24 09:00:07 ERROR web01 disk /dev/sdb1 98% full

```

### grep options

| Option | Effect |
|---|---|
| `-i` | Ignore case |
| `-v` | Invert: print lines that do **not** match |
| `-c` | Count **matching lines** (not matches) |
| `-n` | Show line numbers |
| `-o` | Print only the matched part, one per line |
| `-w` / `-x` | Whole word / whole line must match |
| `-l` / `-L` | Print only the names of files that match / don't match |
| `-h` / `-H` | Hide / show file names |
| `-r` / `-R` | Search directories recursively (`-R` follows symlinks) |
| `--include='*.conf'`, `--exclude`, `--exclude-dir` | Limit a recursive search |
| `-A N` / `-B N` / `-C N` | Also show N lines **A**fter / **B**efore / around each match |
| `-m N` | Stop after N matches |
| `-e PAT` | Add a pattern (repeatable; also for patterns starting with `-`) |
| `-f FILE` | Read patterns from a file |
| `-q` | Quiet: no output, just the exit status |
| `-s` | Hide "file not found" type errors |
| `-a` | Treat a binary file as text |

```bash
grep -c -i error app.log
```
```
3
```
- 3 lines contain "error" in any case.

```bash
grep -n web02 app.log
```
```
4:2026-10-24 09:00:04 INFO  web02 POST /api/v1/orders 201 0.210
5:2026-10-24 09:00:05 error web02 timeout after 30s
```
- `4:` and `5:` are line numbers.

```bash
grep -v -e '^#' -e '^$' app.log | wc -l
```
```
7
```
- Drop comment lines (`^#`) and empty lines (`^$`), then count what's left. Very common for reading config files: `grep -Ev '^[[:space:]]*(#|$)' /etc/ssh/sshd_config`.

```bash
grep -E '^[0-9-]+ [0-9:]+ (ERROR|WARN)' app.log
```
```
2026-10-24 09:00:02 WARN  web01 GET /login 401 0.034
2026-10-24 09:00:03 ERROR db01  connection refused: 10.0.0.15:5432
2026-10-24 09:00:07 ERROR web01 disk /dev/sdb1 98% full
```
- Anchored to the level column, so a message that merely *mentions* ERROR elsewhere isn't caught. The lowercase `error` line isn't matched either.

```bash
grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' app.log
```
```
10.0.0.15
```
- An IPv4-looking pattern: 1–3 digits, then three times "dot + 1–3 digits". `-o` prints just the match.

```bash
grep -oE '(GET|POST) [^ ]+' app.log | sort | uniq -c
```
```
      1 GET /health
      1 GET /index.html
      1 GET /login
      1 POST /api/v1/orders
```
- `[^ ]+` = one or more non-space characters (the URL). `sort | uniq -c` counts them (topic 018).

```bash
grep -n -A1 timeout app.log
```
```
5:2026-10-24 09:00:05 error web02 timeout after 30s
6-2026-10-24 09:00:06 INFO  web01 GET /health 200 0.001
```
- The match uses `:` after the line number; context lines use `-`.

```bash
grep -P '\d+\.\d{3}$' app.log | wc -l
```
```
4
```
- PCRE: `\d` = digit. Lines ending in a number with 3 decimals.

### Whole word, whole line

File `w.txt` contains the lines `root`, `rootkit`, `chroot`, `root:x`:
```bash
grep root w.txt      # root rootkit chroot root:x   (anywhere in the line)
grep -w root w.txt   # root root:x                  (":" isn't a word character)
grep -x root w.txt   # root                         (the whole line)
grep '^root:' /etc/passwd     # the right way to find one account
```

### The dot trap

```bash
echo "a.b axb" | grep -o 'a.b'
echo "a.b axb" | grep -oF 'a.b'
```
```
a.b
axb
a.b
```
- `.` means "any character", so it also matched `axb`. `-F` treats the pattern literally. This matters for IP addresses: `grep 10.0.0.1` also matches `10.0.0.15` and `10a0b0c1`. Use `grep -Fw 10.0.0.1`.

### Searching many files

```bash
grep -rn --include='*.conf' '^Listen' /etc/httpd/
sudo grep -rlw 'PermitRootLogin' /etc/ssh/
sudo grep -rl 'password' /etc 2>/dev/null
```
```
/etc/ssh/sshd_config
```
- `-l` lists only file names. Great for "which config file sets this?"
- `sudo` matters here: `sshd_config` and the files in `sshd_config.d/` are readable only by root (mode `600`). Without it, grep prints `Permission denied` for each one and exits with status 2.

### Regex in other tools

| Tool | Flavour | Example |
|---|---|---|
| `sed` | BRE (`-E` for ERE) | `sed -E 's/^#?Port .*/Port 2222/' file` |
| `awk` | ERE | `awk '$3 ~ /^(ERROR\|WARN)$/ {print $4}' app.log` |
| `find -regex` | Matches the **whole path** | `find . -regextype posix-extended -regex '.*/app[0-9]{2}\.log'` |
| bash `[[ s =~ re ]]` | ERE; captured groups land in `BASH_REMATCH` | below |
| `vim` | Vim regex (`\v` makes it ERE-like) | `:%s/\v(\d+)-(\d+)/\2-\1/g` |
| `semanage fcontext` | Matches the **full path** | `'/srv/web(/.*)?'` (topic 073) |
| `journalctl -g` | PCRE2 | `journalctl -u sshd -g 'Failed password'` |

```bash
ip=10.0.0.15
[[ $ip =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]] && echo "first octet: ${BASH_REMATCH[1]}"
```
```
first octet: 10
```
- In bash `=~`, do **not** quote the pattern (quoting makes it literal). Store complex patterns in a variable: `re='^web0[0-9]$'; [[ $h =~ $re ]]`.

### Fast and safe habits

- `LC_ALL=C grep …` is much faster on big logs (it compares bytes, skipping multi-byte character handling).
- `grep -F -f ips.txt access.log`: many literal patterns at once, far faster than a long `a|b|c|…`.
- `zgrep` / `xzgrep` search compressed logs; `journalctl -g` searches the journal.
- `grep -c` counts **lines**. To count every occurrence, use `grep -o PAT | wc -l`.

### Try it
1. Print only the lines of `app.log` whose level is exactly uppercase `ERROR`.
2. Count the 2xx responses. (Answer: 3. Hint: `' 2[0-9]{2} '`.)
3. List the unique host names (`web01`, `db01`, …) sorted. (Hint: `grep -oE '\b(web|db)[0-9]+\b' | sort -u`.)
4. Show `/etc/ssh/sshd_config` without comments or blank lines.
5. Find every file under `/etc` that mentions your hostname.

## Where you'll use it

- **Incident triage:** `grep -c 'HTTP/1.1" 5' access.log`, `journalctl -u app --since -1h | grep -i error`.
- **Security:** `grep 'Failed password' /var/log/secure | grep -oE 'from [0-9.]+' | sort | uniq -c | sort -rn | head` shows the top brute-force sources.
- **Config audits:** `grep -r '^PermitRootLogin' /etc/ssh/`.
- **Scripts:** `if grep -q '^alice:' /etc/passwd; then …` (branch on the exit status).
- **Kubernetes:** `kubectl get pods -A | grep -v Running` shows everything that isn't healthy. `kubectl logs pod | grep -E 'ERROR|panic'`.
- **Monitoring and log tools** (Prometheus relabel rules, Loki, Fluent Bit, Logstash) are all configured with regexes.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `Unmatched ( or \(` or `Invalid preceding regular expression` | ERE syntax without `-E`, or the reverse | Use `grep -E`, or escape correctly for BRE |
| A pattern like `*.log` acts strangely | It's a glob, not a regex, or the shell expanded it | The regex is `\.log$`; single-quote it |
| Matches too much (`a.b` matches `axb`) | `.` means any character | `\.` or `grep -F` |
| `grep -v foo` also prints blank lines | Blank lines don't contain foo | Add `-e '^$'` to the exclusions |
| `grep: invalid option -- 'v'` when searching for `-v` | The pattern looks like an option | `grep -e '-v' file` or `grep -- -v file` |
| `Binary file x matches` | The file contains NUL bytes | `grep -a`, or `strings file \| grep` |
| A script treats an error as "not found" | Didn't separate exit 1 from exit 2 | Check `$?` explicitly |
| Very slow on huge logs | Multi-byte locale processing | `LC_ALL=C grep` |

## Quick recap

- grep prints matching **lines**. Single-quote patterns. Exit 0 = match, 1 = none, 2 = error.
- `.` any char, `[abc]`/`[^abc]` sets, `^`/`$` anchors, `* + ? {n,m}` repeat the previous item, `(a|b)` alternatives.
- `-E` for ERE, `-F` for literal text, `-P` for `\d \s \w`. Key options: `-i -v -c -n -o -w -x -l -r -A -B -C -q`.
- Glob `*.log` ≠ regex `\.log$`.

**Interview questions**

1. *BRE vs ERE?* ERE gives `+ ? | ( ) { }` special meaning without backslashes. In GNU BRE the same operators exist but must be escaped (`\+`, `\|`, `\(`).
2. *What does `grep -c` count?* Matching lines, not individual matches. For occurrences use `grep -o pattern | wc -l`.
3. *How do you find which files under /etc contain a string?* `grep -rl 'string' /etc 2>/dev/null`.
