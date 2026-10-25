# Conditionals: if/elif/else, test, [[ ]], File Tests & case

> **Sessions:** S88–S90 · **Objective:** *Conditionally execute code (use of: if, test, [], etc.)* **[RHCSA Core]**
> **Related:** [Script input](script-input-and-arguments.md) · [Loops](loops.md) · [Arithmetic](arithmetic.md) · [Control operators & exit codes](../shell-and-command-line/quoting-and-control-operators.md)

## 1. How Conditions Work

`if` runs a **command** and checks its **exit status**: `0` = true/success, non-zero = false. `[ … ]` (the `test` command), `[[ … ]]` and `(( … ))` are just commands that return 0 or 1.

```bash
if grep -q '^alice:' /etc/passwd; then echo "alice exists"; fi   # any command works
```

## 2. Syntax

```bash
if [ "$a" -gt 10 ]; then
    echo "big"
elif [ "$a" -gt 5 ]; then
    echo "medium"
else
    echo "small"
fi
```

- `[` is a command, so it needs **spaces**: `[ "$a" -gt 10 ]` (not `[$a -gt 10]`).
- `then` goes on the next line or after `;`. Close with `fi`.

## 3. The Three Test Forms

| Form | Type | Notes |
|---|---|---|
| `[ … ]` / `test …` | POSIX command | Quote variables; escape `\<` `\>` |
| `[[ … ]]` | Bash keyword | No word splitting; `&&`, `\|\|`, `<`, `>`, pattern `==`, regex `=~` |
| `(( … ))` | Arithmetic | Numeric comparisons with `< > <= >= == !=`; `$` optional |

### String tests

| Test | True if |
|---|---|
| `[ "$a" = "$b" ]` (`==` in bash) | Equal |
| `[ "$a" != "$b" ]` | Not equal |
| `[ -z "$a" ]` / `[ -n "$a" ]` | Empty / not empty |
| `[[ $a < $b ]]` / `[[ $a > $b ]]` | Sorts before/after (locale order) |
| `[[ $file == *.log ]]` | Glob pattern match (unquoted right side) |
| `[[ $ip =~ ^[0-9]+(\.[0-9]+){3}$ ]]` | Regex match |

### Integer tests (`[ ]`)

`-eq` `-ne` `-gt` `-ge` `-lt` `-le`: `[ "$n" -ge 18 ]`. Arithmetic form: `(( n >= 18 ))`.

### File tests

| Test | True if | Test | True if |
|---|---|---|---|
| `-e` | Exists | `-r` | Readable by you |
| `-f` | Regular file | `-w` | Writable by you |
| `-d` | Directory | `-x` | Executable by you (dirs: searchable) |
| `-L` / `-h` | Symbolic link | `-s` | Size > 0 (not empty) |
| `-b` / `-c` | Block / character device | `-O` / `-G` | Owned by your UID / GID |
| `-p` / `-S` | Named pipe / socket | `f1 -nt f2` / `-ot` | Newer / older than |

Root sees `-r`/`-w` as true almost always, and `-x` as true if any execute bit is set.

> ⚠️ **Always quote:** with `[ -e $f ]` and an empty `$f`, the test becomes `[ -e ]`, which is **true**. `[ -e "$f" ]` correctly returns false.

## 4. Combining Conditions

```bash
if [ "$age" -ge 18 ] && [ "$age" -le 40 ]; then …       # AND between tests
if [[ $age -ge 18 && $age -le 40 ]]; then …               # AND inside [[ ]]
if (( age < 18 || age > 40 )); then …                     # OR in arithmetic
if ! id "$u" &>/dev/null; then useradd "$u"; fi            # NOT
```

`-a` and `-o` inside `[ ]` are obsolescent (ambiguous); use `&&`/`||` instead.

Between commands: `cmd1 && cmd2` (run cmd2 if cmd1 succeeded), `cmd1 || cmd2` (run cmd2 if cmd1 failed). `a && b || c` isn't a true if/else.

### Validate numeric input first

```bash
read -rp "Age: " age
[[ $age =~ ^[0-9]+$ ]] || { echo "Not a number" >&2; exit 1; }
```

## 5. Nested if

```bash
read -rp "File: " f
if [ -f "$f" ]; then
    if [ -w "$f" ]; then
        echo "Type text, Ctrl+D to finish:" ; cat >> "$f"
    else
        echo "$f is not writable" >&2
    fi
else
    echo "$f doesn't exist or isn't a regular file" >&2
fi
```

## 6. `case`

```bash
read -rp "Choice [1-3, q]: " choice
case $choice in
    1|date)  date ;;
    2|cal)   cal ;;
    3)       ls ;;
    [qQ]*)   echo "bye" ; exit 0 ;;
    *)       echo "Invalid choice" >&2 ;;
esac
```

Patterns are globs (`*`, `?`, `[…]`, `a|b`), not regex; `;;` ends each branch; `*)` is the default.

## 7. Exit Codes in Scripts

```bash
cp "$src" "$dst" || { echo "copy failed" >&2; exit 1; }
some_cmd ; rc=$?            # capture immediately
exit 0                      # success; 1–125 errors (pick meaningful values)
```

## 8. RHCSA Exam Patterns **[RHCSA Core]**

```bash
#!/bin/bash
# /usr/local/bin/check: prints "yes" if arg is an existing directory, else "no", exit 1
if [ "$#" -ne 1 ]; then echo "Usage: $0 DIR" >&2; exit 2; fi
if [ -d "$1" ]; then echo yes; else echo no; exit 1; fi
```

## 9. Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `[20: command not found` / `[: missing ']'` | Missing spaces | `[ 20 -eq 12 ]` |
| `[: too many arguments` | Unquoted variable with spaces | Quote it or use `[[ ]]` |
| `integer expression expected` | Non-numeric value in `-eq/-gt` | Validate input first |
| `unary operator expected` | Empty unquoted variable | Quote: `[ "$x" = y ]` |
| `<` creates a file named `c` | `<` inside `[ ]` is redirection | `[[ $a < c ]]` or `[ "$a" \< c ]` |
| File test always "exists" | Empty unquoted variable | Quote |

## 10. Interview Questions

| Question | Answer |
|---|---|
| `[ ]` vs `[[ ]]`? | `[` is a POSIX command (needs quoting/escaping); `[[ ]]` is a bash keyword with safer parsing, `&&`/`\|\|`, patterns and regex. |
| How does `if` decide true/false? | By the exit status of the command (0 = true). |
| `-e` vs `-f`? | Exists (any type) vs is a regular file. |
| When use `case`? | Multiple choices on one value: menus, options, patterns. |

## 11. Course Corrections

| Course | Correction |
|---|---|
| `if [20 -eq 12]`, `if [$num -gt 25]` … | Spaces required inside brackets |
| `[ -e $filename ]` (unquoted) throughout file tests | Quote; empty input wrongly reports "exists" |
| `[ $var1 == $var2 ]` | `[ "$var1" = "$var2" ]` |
| "You MUST quote the right side" for `<`/`>` | Quoting matters for `==` patterns; `<`/`>` compare either way |
| `-a` / `-o` as alternatives | Obsolescent; use `&&`/`\|\|` |
| `echo -e "…\c"` prompts | `read -rp "…"` |

## 12. Quick Revision

```bash
if CMD; then …; elif CMD; then …; else …; fi · [ ] needs spaces · quote "$vars"
strings: = != -z -n · ints: -eq -ne -gt -ge -lt -le · (( a > b )) · [[ $x == pat* ]] [[ $x =~ re ]]
files: -e -f -d -L -r -w -x -s -b -c -p -nt -ot · && || ! · case $v in a|b) …;; *) …;; esac
