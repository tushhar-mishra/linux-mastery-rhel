# grep & Regular Expressions

> **Sessions:** S17, S20 (consolidated and expanded) · **Objective:** *Use grep and regular expressions to analyze text* **[RHCSA Core]** · **Verified:** GNU grep 3.11, sed 4.9, gawk 5.3, bash 5.2 on a RHEL 10.2 UBI container (Oct 2026)
> **Prerequisites:** [Quoting](../shell-and-command-line/quoting-and-control-operators.md) · [Globbing (globs ≠ regex)](../shell-and-command-line/shell-expansion-and-globbing.md#51-globs-vs-regular-expressions) · [Redirection & pipes](io-redirection-and-pipes.md)
> **Related:** [Text filters](text-filters.md) · [awk](awk.md) · [vi search/replace](vi-and-vim.md) · [Finding files (`-regex`)](finding-files.md) · [System logging](../logs-scheduling-and-packages/system-logging.md) · [SELinux fcontext regex](../firewall-and-selinux/selinux-file-contexts.md)

## 1. Overview

A **regular expression** (regex) is a pattern that describes a set of strings. `grep` prints the **lines** of its input that contain a match. Regex is used everywhere on Linux: `grep`, `sed`, `awk`, `vim`, `find -regex`, `[[ =~ ]]` in bash, `semanage fcontext`, `journalctl -g`, rsyslog filters, and most programming languages.

Two facts prevent most mistakes:

1. **The shell sees your pattern first.** Always single-quote regexes, so `*`, `$`, `\`, `[`, `|` reach grep unchanged.
2. **Globs and regexes are different languages.** In a glob, `*` means "anything"; in a regex, `*` means "zero or more of the previous item", and "anything" is `.*`.

## 2. How grep Works

grep reads input **line by line**. For each line it asks: "does the pattern match **anywhere** in this line?" (unless anchored with `^`/`$`, or `-x`/`-w` are used). Matching lines are printed; with `-o`, only the matched parts are printed.

**Exit status** (this is what makes grep useful in scripts):

| Status | Meaning |
|---|---|
| `0` | At least one line matched |
| `1` | No line matched |
| `2` | Error (unreadable file, bad regex), even if other files matched |

```bash
if grep -q '^alice:' /etc/passwd; then echo "alice exists"; fi   # -q: quiet, just the status
```

## 3. Regex Flavors

| Flavor | grep option | Used by | Special characters needing **no** backslash |
|---|---|---|---|
| **BRE** (basic) | `grep` (default) | `grep`, `sed`, `vi` | `.` `*` `[ ]` `^` `$` |
| **ERE** (extended) | `grep -E` (`egrep` is deprecated) | `grep -E`, `sed -E`, `awk`, bash `=~` | also `+` `?` `\|` `( )` `{ }` |
| **PCRE** (Perl-compatible) | `grep -P` | Many languages, `grep -P` | adds `\d` `\s` `\w`, lazy `*?`, lookarounds |
| **Fixed string** | `grep -F` | — | Nothing is special: fastest, safest for literal text |

In GNU BRE, the ERE operators exist too, but **must be backslashed**: `\+`, `\?`, `\|`, `\(…\)`, `\{n,m\}`. The two commands below are equivalent (verified):

```bash
grep -E ' (4|5)[0-9]{2} ' app.log        # ERE: readable
grep ' \(4\|5\)[0-9]\{2\} ' app.log      # BRE: same meaning, backslash soup
```

**Rule of thumb:** use `grep -E` whenever you need `+ ? | ( ) { }`; use `grep -F` for literal strings (IP addresses, paths, anything with dots).

## 4. Regex Building Blocks

### 4.1 Characters and classes

| Pattern | Matches |
|---|---|
| `a` | The character `a` |
| `.` | Any **one** character |
| `[abc]` | One of a, b, c |
| `[a-z]`, `[0-9]` | One character in the range |
| `[^abc]` | One character **not** in the set (`^` first inside brackets) |
| `[]-]` | `]` or `-` (put `]` first and `-` first or last to make them literal) |
| `[[:digit:]]` `[[:alpha:]]` `[[:alnum:]]` `[[:upper:]]` `[[:lower:]]` `[[:space:]]` `[[:punct:]]` | POSIX classes (locale-safe; note the **double** brackets) |
| `\.` | A literal dot (any special character can be escaped) |

### 4.2 Anchors and boundaries

| Pattern | Matches |
|---|---|
| `^text` | `text` at the **start** of the line |
| `text$` | `text` at the **end** of the line |
| `^$` | An empty line |
| `\<word\>` / `\bword\b` | `word` as a whole word (GNU) |
| `grep -w word` | Same idea: match must be a whole word |
| `grep -x line` | The **whole line** must match |

### 4.3 Quantifiers (apply to the **previous** item)

| ERE | BRE | Meaning |
|---|---|---|
| `*` | `*` | 0 or more |
| `+` | `\+` | 1 or more |
| `?` | `\?` | 0 or 1 (optional) |
| `{n}` | `\{n\}` | Exactly n |
| `{n,}` | `\{n,\}` | n or more |
| `{n,m}` | `\{n,m\}` | Between n and m |

**Greedy matching:** quantifiers take the **longest** possible match. POSIX regex has no lazy quantifier; use a negated class instead, or `grep -P` with `*?`:

```bash
echo "<a><b>" | grep -oE '<.*>'       # <a><b>        (greedy: one long match)
echo "<a><b>" | grep -oE '<[^>]*>'    # <a> then <b>  (negated class: stops at the first >)
echo "<a><b>" | grep -oP '<.*?>'      # <a> then <b>  (PCRE lazy quantifier)
```

### 4.4 Groups, alternation, backreferences

| ERE | Meaning |
|---|---|
| `(GET\|POST)` | Either alternative (in ERE written `(GET|POST)`) |
| `(ab)+` | Group repeated |
| `(.)\1` | Backreference: the same character twice (`aa`, `zz`) |

```bash
echo "2026-10-24" | sed -E 's/([0-9]+)-([0-9]+)-([0-9]+)/\3.\2.\1/'   # 24.10.2026 (groups reused in the replacement)
```

## 5. grep Options **[RHCSA Core]**

| Option | Effect |
|---|---|
| `-i` | Case-insensitive |
| `-v` | Invert: print lines that do **not** match |
| `-c` | Count **matching lines** (not matches) |
| `-n` | Prefix line numbers |
| `-o` | Print only the matched parts, one per line |
| `-w` / `-x` | Whole word / whole line |
| `-l` / `-L` | Print only names of files that match / don't match |
| `-h` / `-H` | Suppress / force filename prefixes |
| `-r` / `-R` | Recurse into directories (`-R` follows symlinks) |
| `--include='*.conf'`, `--exclude`, `--exclude-dir` | Limit recursive search |
| `-A N` / `-B N` / `-C N` | N lines of context After / Before / both |
| `-m N` | Stop after N matching lines |
| `-e PAT` (repeatable) | Multiple patterns; also for patterns starting with `-` |
| `-f FILE` | Read patterns from a file, one per line |
| `-q` / `-s` | Quiet (status only) / suppress file errors |
| `-E` / `-F` / `-P` | ERE / fixed string / PCRE |
| `--color=auto` | Highlight matches (RHEL aliases `grep` to this) |

## 6. Worked Examples (verified output)

Sample file `app.log`:

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

```bash
$ grep -c -i error app.log                         # count matching lines, any case
3
$ grep -n web02 app.log
4:2026-10-24 09:00:04 INFO  web02 POST /api/v1/orders 201 0.210
5:2026-10-24 09:00:05 error web02 timeout after 30s
$ grep -v -e '^#' -e '^$' app.log | wc -l         # drop comments and blank lines
7
$ grep -E '^[0-9-]+ [0-9:]+ (ERROR|WARN)' app.log  # anchored on the level field
2026-10-24 09:00:02 WARN  web01 GET /login 401 0.034
2026-10-24 09:00:03 ERROR db01  connection refused: 10.0.0.15:5432
2026-10-24 09:00:07 ERROR web01 disk /dev/sdb1 98% full
$ grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' app.log  # extract IPv4-looking strings
10.0.0.15
$ grep -oE '(GET|POST) [^ ]+' app.log | sort | uniq -c
      1 GET /health
      1 GET /index.html
      1 GET /login
      1 POST /api/v1/orders
$ grep -n -A1 timeout app.log                       # match + 1 line after ("-" marks context lines)
5:2026-10-24 09:00:05 error web02 timeout after 30s
6-2026-10-24 09:00:06 INFO  web01 GET /health 200 0.001
$ grep -P '\d+\.\d{3}$' app.log | wc -l            # lines ending in a 3-decimal response time
4
```

Whole word / whole line (file `w.txt` contains `root`, `rootkit`, `chroot`, `root:x`):

```bash
$ grep root w.txt      # root  rootkit  chroot  root:x   (substring anywhere)
$ grep -w root w.txt   # root  root:x                    (":" is a non-word character)
$ grep -x root w.txt   # root
$ grep '^root:' /etc/passwd     # the right way to find one account
```

The dot trap, and why `-F` exists:

```bash
$ echo "a.b axb" | grep -o 'a.b'     # a.b  axb   ← "." matched "x"
$ echo "a.b axb" | grep -oF 'a.b'    # a.b
```

Recursive search limited to config files:

```bash
grep -rn --include='*.conf' '^Listen' /etc/httpd/
grep -rlw 'PermitRootLogin' /etc/ssh/          # which files mention it
```

## 7. Regex in Other Tools

| Tool | Default flavor | Example |
|---|---|---|
| `sed` | BRE (`-E` for ERE) | `sed -E 's/^(#?)Port .*/Port 2222/' file` |
| `awk` | ERE | `awk '$3 ~ /^(ERROR\|error)$/ {print $4}' app.log` |
| `find -regex` | Emacs-style, matched against the **whole path** | `find . -regextype posix-extended -regex '.*/[a-z][0-9]{2}\.log'` |
| bash `[[ s =~ re ]]` | ERE; captures in `BASH_REMATCH` | see below |
| `vim` | Vim regex (`\v` = "very magic", ERE-like) | `:%s/\v(\d+)-(\d+)/\2-\1/g` |
| `semanage fcontext` | POSIX-style regex matched against the **full path** | `'/srv/web(/.*)?'` |
| `journalctl -g` | PCRE2 | `journalctl -u sshd -g 'Failed password'` |

bash regex: **don't quote** the pattern (quoting makes it a literal string); store complex patterns in a variable:

```bash
ip=10.0.0.15
[[ $ip =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]] && echo "first octet ${BASH_REMATCH[1]}"   # first octet 10
re='^web0[0-9]$' ; [[ web01 =~ $re ]] && echo match          # match
[[ web01 =~ "^web0[0-9]$" ]] || echo "quoted = literal"      # quoted = literal
```

## 8. RHCSA Exam Patterns **[RHCSA Core]**

```bash
# "Find all lines in /usr/share/dict/words containing 'ich' and save them, in original order, to /root/lines"
grep 'ich' /usr/share/dict/words > /root/lines

# "Copy lines containing 'Listen' from httpd.conf to /root/listen.txt" (exactly what's asked: no -n, no -i)
grep 'Listen' /etc/httpd/conf/httpd.conf > /root/listen.txt

# "List non-comment, non-blank lines of sshd_config"
grep -Ev '^[[:space:]]*(#|$)' /etc/ssh/sshd_config

# "Users whose login shell is /bin/bash"
grep -E ':/bin/bash$' /etc/passwd | cut -d: -f1

# Verify every result
wc -l /root/lines ; head -3 /root/lines
```

- Don't add `-n`, `-i` or `sort` unless the task asks; graders often compare exact content.
- Quote the pattern; redirect with `>` (overwrite) unless "append" is requested.

## 9. Production Practices **[Production Practice]**

- `LC_ALL=C grep …` is much faster on large logs (byte comparison, no multibyte processing) and makes ranges predictable.
- Use `grep -F -f patterns.txt` for many literal patterns (IPs, user lists); it's dramatically faster than a long alternation.
- Search compressed logs with `zgrep`/`xzgrep`; journal content with `journalctl -g`.
- In scripts, test with `grep -q` and branch on the exit status; remember status `2` means an error, not "no match".
- `grep -c` counts **lines**; count occurrences with `grep -o PAT | wc -l` (`echo "ERROR ERROR" | grep -c ERROR` → `1`; with `-o … | wc -l` → `2`).

## 10. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `grep: Unmatched ( or \(` / `Invalid preceding regular expression` | ERE syntax used without `-E` (or vice versa) | `grep -E`, or escape correctly for BRE |
| Pattern like `*.log` behaves oddly | It's a glob, not a regex; or the shell expanded it | Regex is `\.log$`; single-quote it |
| Matches too much (`a.b` matches `axb`) | `.` is "any character" | `\.` or `grep -F` |
| `grep -v foo` prints blank lines too | Blank lines don't contain foo | Add `-e '^$'` to the exclusion |
| `[a-z]` behaves unexpectedly in a script | Locale collation (older shells/tools) | `[[:lower:]]` or `LC_ALL=C` |
| `grep: invalid option -- 'v'` when searching for "-v" | Pattern parsed as an option | `grep -e '-v'` or `grep -- -v` |
| Binary file matches | File contains NUL bytes | `grep -a` to treat as text, or `strings FILE \| grep` |
| Script treats an error as "not found" | Didn't distinguish exit 1 from 2 | Check `$?` explicitly |

## 11. Interview Questions

| Question | Answer |
|---|---|
| BRE vs ERE? | ERE gives `+ ? \| ( ) { }` special meaning without backslashes; GNU BRE has the same operators but they must be escaped. |
| How do you match a literal dot? | `\.`, `[.]`, or `grep -F`. |
| What does `grep -c` count? | Matching **lines**, not individual matches. |
| `-w` vs `-x`? | `-w`: the match must be a whole word; `-x`: the whole line must match. |
| Why is regex `.*` "greedy"? | It matches the longest possible string; use a negated class `[^>]*` (or PCRE `*?`) for the shortest. |
| What are grep's exit codes? | 0 match, 1 no match, 2 error. |
| How do you find which files under /etc contain a string? | `grep -rl 'string' /etc 2>/dev/null`. |
| Glob vs regex for "all .log files"? | Glob `*.log`; regex `\.log$`. |

## 12. Practice (solutions below)

Using `app.log` from §6:

1. Print only the lines whose level is exactly `ERROR` (uppercase).
2. Count the requests that returned a 2xx status.
3. Print the unique host names (`web01`, `db01`, …) in sorted order.
4. Print every line that is **not** a comment, blank, or INFO line.
5. Extract all response times (last field of lines ending in a decimal number).

Solutions:

```bash
grep -E '^[^ ]+ [^ ]+ ERROR ' app.log                 # 1 → 2 lines (09:00:03, 09:00:07)
grep -cE ' 2[0-9]{2} [0-9.]+$' app.log                # 2 → 3
grep -oE '\b(web|db)[0-9]+\b' app.log | sort -u       # 3 → db01 web01 web02
grep -Ev '^(#|$)| INFO ' app.log                      # 4 → WARN, ERROR, error, ERROR lines
grep -oE '[0-9]+\.[0-9]+$' app.log                    # 5 → 0.012 0.034 0.210 0.001
```

## 13. Quick Revision

```
'quote patterns' · . any · [abc] [^abc] [[:digit:]] · ^ $ \< \> · * + ? {n,m} · (a|b) \1
BRE: \+ \? \| \( \) \{ \}   ERE: grep -E   PCRE: grep -P   literal: grep -F
-i -v -c -n -o -w -x -l -L -r --include -A -B -C -m -e -f -q · exit 0/1/2
sed (BRE, -E) · awk (ERE) · [[ $s =~ $re ]] (unquoted, BASH_REMATCH) · find -regex (whole path)
```

## 14. Cross-References

- [Text filters (cut, sort, uniq, sed basics)](text-filters.md) · [awk](awk.md) · [vi & vim (search/replace)](vi-and-vim.md)
- [Globs vs regex](../shell-and-command-line/shell-expansion-and-globbing.md#51-globs-vs-regular-expressions) · [Quoting](../shell-and-command-line/quoting-and-control-operators.md)
- [Conditionals (`[[ =~ ]]`)](../bash-scripting-and-automation/conditionals-and-tests.md) · [System logging (`journalctl -g`)](../logs-scheduling-and-packages/system-logging.md)
