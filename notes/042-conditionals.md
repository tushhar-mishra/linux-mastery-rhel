# 042 · Conditionals: if, test, [ ], [[ ]], (( )) and case

> **You need first:** [041 · Script input and arguments](041-script-input-and-arguments.md)
> **Next:** [043 · Loops](043-loops.md)

---

## What it is

**Conditionals** let a script make decisions: "if the file exists, back it up; otherwise, warn".

| Tool | What it is |
|---|---|
| `if … then … elif … else … fi` | Run commands depending on whether a **command succeeded** |
| `[ … ]` / `test …` | A command that checks a condition (strings, numbers, files) and returns 0 (true) or 1 (false) |
| `[[ … ]]` | bash's safer, more powerful test (patterns, regex, `&&`/`\|\|` inside) |
| `(( … ))` | A numeric comparison using normal maths symbols (`<`, `>=`, `==`) |
| `case … esac` | Pick one branch by matching a value against several patterns |

## Why it exists

Real scripts must react to reality: the user may not exist, the disk may be full, the argument may be missing, the service may already be running. Without conditionals, scripts break or do damage. Validating input and checking results is what separates a safe script from a dangerous one.

## Analogy

`if` is a **traffic light controlled by a question**: it asks a worker to do something (run a command), and if the worker says "done" (exit 0) the light is green; anything else is red. `[ ]` is a **specialist worker whose only job is answering yes/no questions**: "is this a file?", "is 5 greater than 3?". `case` is a **sorting machine** that drops each item into the bin whose label matches.

## How it works inside

**`if` does not evaluate expressions. It runs a command and looks at its exit status.** `0` = true; anything else = false (topic 004).

```bash
if grep -q '^alice:' /etc/passwd; then echo "alice exists"; fi
```
Any command works. `grep -q` exits 0 if it found a match.

- **`[`** is literally a **command** (a builtin, and also `/usr/bin/[`). Its last argument must be `]`. Because it's a command, **spaces are required** around it and every operand: `[ "$a" -gt 10 ]`, never `[$a -gt 10]`. Its arguments go through normal word splitting and globbing, which is why **unquoted variables break it**.
- **`[[ ]]`** is a bash **keyword**, parsed specially: no word splitting or globbing on variables, `&&`/`||`/`<`/`>` work inside, and it supports `==` glob patterns and `=~` regex. It's safer, but bash-only (not `sh`/`dash`).
- **`(( ))`** evaluates arithmetic and returns 0 if the result is non-zero (true). `$` is optional on variable names inside.

**The quoting trap:** with `f=""`, `[ -e $f ]` becomes `[ -e ]`, which is a test of "is the string `-e` non-empty?" → **true**. `[ -e "$f" ]` correctly tests an empty name → false. **Always quote inside `[ ]`.**

## Commands

### if / elif / else

```bash
#!/bin/bash
usage=$(df --output=pcent / | tail -1 | tr -dc '0-9')    # e.g. 87
if [ "$usage" -ge 90 ]; then
    echo "CRITICAL: / is ${usage}% full"
elif [ "$usage" -ge 80 ]; then
    echo "WARNING: / is ${usage}% full"
else
    echo "OK: / is ${usage}% full"
fi
```
```
WARNING: / is 87% full
```
- `df --output=pcent /` prints the use percentage; `tr -dc '0-9'` keeps only the digits.

### String tests

| Test | True if |
|---|---|
| `[ "$a" = "$b" ]` (bash also accepts `==`) | Equal |
| `[ "$a" != "$b" ]` | Not equal |
| `[ -z "$a" ]` | Empty (**z**ero length) |
| `[ -n "$a" ]` | Not empty |
| `[[ $f == *.log ]]` | Matches a **glob** pattern (right side unquoted) |
| `[[ $ip =~ ^[0-9]+(\.[0-9]+){3}$ ]]` | Matches a **regex** (topic 017) |
| `[[ $a < $b ]]` | Sorts before (inside `[ ]` you'd have to write `\<`) |

### Number tests

| `[ ]` form | `(( ))` form | Meaning |
|---|---|---|
| `-eq` | `==` | Equal |
| `-ne` | `!=` | Not equal |
| `-gt` | `>` | Greater than |
| `-ge` | `>=` | Greater or equal |
| `-lt` | `<` | Less than |
| `-le` | `<=` | Less or equal |

```bash
n=7
[ "$n" -gt 5 ] && echo "bigger than 5"
(( n % 2 == 1 )) && echo "odd"
```

**Validate before comparing:** `[ "abc" -gt 5 ]` errors with `integer expression expected`.
```bash
[[ $n =~ ^[0-9]+$ ]] || { echo "Not a number: $n" >&2; exit 1; }
```

### File tests

| Test | True if | Test | True if |
|---|---|---|---|
| `-e` | Exists (any type) | `-r` | You can read it |
| `-f` | Regular file | `-w` | You can write it |
| `-d` | Directory | `-x` | You can execute it (directory: enter it) |
| `-L` | Symbolic link | `-s` | Exists and isn't empty |
| `-b` / `-c` | Block / character device | `-O` / `-G` | Owned by your UID / your GID |
| `-p` / `-S` | Named pipe / socket | `a -nt b` / `a -ot b` | `a` newer / older than `b` |

As root, `-r` and `-w` are almost always true (root bypasses permissions, topic 026).

```bash
config=/etc/myapp.conf
if [ ! -f "$config" ]; then
    echo "missing $config" >&2 ; exit 1
fi
[ -s /var/log/app.log ] || echo "log is empty"
```

### Combining conditions

```bash
if [ "$age" -ge 18 ] && [ "$age" -le 65 ]; then echo "working age"; fi   # two [ ] tests
if [[ $age -ge 18 && $age -le 65 ]]; then echo "working age"; fi          # inside [[ ]]
if (( age < 18 || age > 65 )); then echo "outside"; fi                    # arithmetic
if ! id "$u" &>/dev/null; then sudo useradd "$u"; fi                      # NOT (!)
```
- `-a` and `-o` inside `[ ]` are old and ambiguous; use `&&` and `||` instead.
- Remember: `a && b || c` is **not** a real if/else (topic 011).

### Nested if

```bash
if [ -f "$f" ]; then
    if [ -w "$f" ]; then
        echo "appending to $f"
    else
        echo "$f is not writable" >&2
    fi
else
    echo "$f is not a regular file" >&2
fi
```

### case

```bash
#!/bin/bash
# svc.sh start|stop|status SERVICE
action=${1:-}
svc=${2:?service name required}
case $action in
    start|up)       sudo systemctl start "$svc" ;;
    stop|down)      sudo systemctl stop "$svc" ;;
    status)         systemctl --no-pager status "$svc" ;;
    [Rr]estart)     sudo systemctl restart "$svc" ;;
    *)              echo "Usage: $0 {start|stop|status|restart} SERVICE" >&2; exit 1 ;;
esac
```
- Each branch is `pattern) commands ;;`. Patterns are **globs** (`*`, `?`, `[…]`) and `|` means "or". `*)` is the default branch. `esac` ("case" backwards) ends it.
- Only the **first** matching branch runs.

### Exit codes in scripts

```bash
cp "$src" "$dst" || { echo "copy failed" >&2; exit 1; }
some_cmd
rc=$?                     # save it immediately: the next command overwrites $?
if [ "$rc" -ne 0 ]; then echo "some_cmd failed with $rc" >&2; fi
exit 0
```

### Try it
1. Write `check.sh DIR`: print `yes` and exit 0 if DIR is an existing directory, else print `no` and exit 1. Usage error = exit 2.
2. Test the quoting trap: `f=""; [ -e $f ] && echo "wrong"; [ -e "$f" ] || echo "right"`.
3. Write a `case` menu that runs `date`, `uptime` or `df -h` for inputs 1, 2, 3, and handles anything else.
4. Check whether a user exists, and create it only if not.

**Check your work:** on your lab VM, from the notes folder, run `sudo ./checks/check 042` for every step, or `sudo ./checks/check 042 STEP` for one (topic 002 shows how to get the notes there).

## Where you'll use it

- **Validating input** at the top of every script (argument count, file exists, value is a number).
- **Health checks:** `if ! curl -fsS http://localhost:8080/health >/dev/null; then systemctl restart app; fi`.
- **Idempotent automation:** "create only if missing", "append only if not already there" (`grep -q … || echo … >> file`). Ansible works the same way internally.
- **Entrypoint scripts:** `case "$1" in serve) … ;; migrate) … ;; esac`.
- **Kubernetes probes:** a liveness probe command is "healthy" if it exits 0, exactly like `if`.

## When it breaks

| Error | Cause | Fix |
|---|---|---|
| `[20: command not found` / `[: missing ']'` | Missing spaces | `[ 20 -eq 12 ]` |
| `[: too many arguments` | An unquoted variable contained spaces | Quote it, or use `[[ ]]` |
| `integer expression expected` | A non-number in `-eq`/`-gt` | Validate the input first |
| `unary operator expected` | An empty unquoted variable | Quote: `[ "$x" = y ]` |
| A file named `c` appears | `<` inside `[ ]` is a redirection | `[[ $a < c ]]` or `[ "$a" \< c ]` |
| A file test always says "exists" | Empty unquoted variable (`[ -e ]` is true) | Quote |
| `[[: not found` | Running under `sh`/`dash` | Use `#!/bin/bash` |

## Quick recap

- `if CMD; then …; elif CMD; then …; else …; fi`: `if` checks a command's exit status (0 = true).
- `[ ]` is a command: needs spaces, **quote variables**. `[[ ]]` is safer (patterns, regex, `&&`). `(( ))` for maths.
- Strings `= != -z -n`; numbers `-eq -ne -gt -ge -lt -le`; files `-e -f -d -r -w -x -s -L`.
- `case $v in a|b) … ;; *) … ;; esac` for choosing between many options.

**Interview questions**

1. *`[ ]` vs `[[ ]]`?* `[` is a POSIX command whose arguments undergo word splitting, so variables must be quoted and `<`/`>` escaped. `[[ ]]` is a bash keyword: no splitting, `&&`/`||` inside, glob matching with `==` and regex with `=~`.
2. *How does `if` decide true or false?* It runs a command and checks the exit status: 0 is true, anything else is false.
3. *Why must you quote variables inside `[ ]`?* An empty or space-containing variable changes the number of arguments: `[ -e $f ]` with an empty `f` becomes `[ -e ]`, which is true, and `[ $a = b ]` with spaces gives "too many arguments".

**Scenario question** (answer out loud first, then compare)

> *"This check reports 'file exists' even when the variable is empty: `if [ -e $CONFIG ]; then …`. Explain, and fix it."*

**Model answer:**
1. With `CONFIG` empty, the unquoted variable disappears and the test becomes `[ -e ]`.
2. A test with a single argument is true whenever that argument is non-empty, and `-e` is a non-empty string, so it's **true**.
3. Fix: quote it, `[ -e "$CONFIG" ]` (now `[ -e "" ]`, which is false), or use `[[ -e $CONFIG ]]`, which doesn't split words.
4. Better still, check for empty explicitly: `[ -n "$CONFIG" ] && [ -e "$CONFIG" ]`, or `: "${CONFIG:?CONFIG must be set}"`.

**Likely follow-ups:**
- *How do you compare numbers vs strings?* `-eq -lt -gt` (or `(( a < b ))`) for numbers; `=` and `!=` for strings. `[ 10 \< 9 ]` compares as text.
- *How do you match a pattern in a condition?* `[[ $file == *.log ]]`, or a regex: `[[ $ip =~ ^[0-9.]+$ ]]`.
