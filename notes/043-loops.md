# 043 · Loops: for, while, until and Processing Input

> **You need first:** [042 · Conditionals](042-conditionals.md)
> **Next:** [044 · Arithmetic](044-arithmetic.md)

---

## What it is

A **loop** repeats commands.

| Loop | Repeats… | Typical use |
|---|---|---|
| `for x in LIST` | Once for each item in a list | Every file, every argument, every server |
| `for ((i=0; i<n; i++))` | A counter, C-style | "Do it 10 times" |
| `while COND` | **As long as** the condition succeeds | Read a file line by line, retry until healthy |
| `until COND` | **Until** the condition succeeds | Wait for something to appear |

Inside a loop: **`break`** leaves the loop, **`continue`** skips to the next round.

## Why it exists

Admin work is mostly "do this to every one of them": every user in a list, every log file, every server in an inventory, every line in a CSV. Loops turn one command into a bulk operation, and `while`/`until` let scripts wait and retry.

## Analogy

A `for` loop is **dealing cards**: one card to each player in the list, then stop. A `while` loop is **"keep stirring while the sauce is lumpy"**. An `until` loop is **"keep knocking until someone answers"**. `continue` is "skip this player". `break` is "stop the game".

## How it works inside

- **`for x in LIST`**: bash first **expands** the list (globs, `$(…)`, braces, word splitting, topic 013), then assigns each resulting word to `x` in turn. That's why `for f in $(ls)` breaks on file names with spaces: the output is split on spaces before the loop sees it.
- **`while COND`**: runs `COND` (any command); if its exit status is 0, it runs the body and repeats. `until` is the same with the test reversed.
- **`while read`**: `read` returns 0 while it gets a line and non-zero at end of input, so the loop stops naturally at the end of the file.
- **The pipe trap:** in `cmd | while read …; do …; done`, the `while` loop runs in a **subshell** (each part of a pipeline is a separate process, topic 016). Variables changed inside are **lost** after the loop. Use `done < file` or `done < <(cmd)` (**process substitution**, which feeds a command's output in as if it were a file).

## Commands

### for

```bash
for i in 1 2 3; do echo "Number: $i"; done
for i in {1..10..3}; do echo -n "$i "; done; echo
for ((i=1; i<=3; i++)); do echo "Counter: $i"; done
n=4; for i in $(seq 1 "$n"); do echo -n "$i "; done; echo
```
```
Number: 1
Number: 2
Number: 3
1 4 7 10
Counter: 1
Counter: 2
Counter: 3
1 2 3 4
```
- Brace ranges only take **literal** numbers (`{1..$n}` doesn't work, topic 013); use `seq` or the C-style form for variables.

```bash
for file in /var/log/*.log; do
    [ -e "$file" ] || continue          # if nothing matched, skip the literal "*.log"
    echo "$file: $(wc -l < "$file") lines"
done
```
- Looping over a **glob** is safe with spaces in names, as long as you quote `"$file"`.

```bash
for host in web1 web2 db1; do
    ssh -o ConnectTimeout=3 "$host" uptime || echo "$host unreachable" >&2
done
```

```bash
for user in "$@"; do echo "Arg: $user"; done     # every script argument
```

### while: read a file line by line (the safe way)

```bash
while IFS= read -r line; do
    echo "Line: $line"
done < /etc/hosts
```
- `IFS=` keeps leading spaces, `-r` keeps backslashes, `< /etc/hosts` feeds the file to the **whole loop**.

```bash
while IFS=: read -r user _ uid _ _ home shell; do
    [ "$uid" -ge 1000 ] && [ "$uid" -lt 65534 ] && echo "$user → $home ($shell)"
done < /etc/passwd
```
```
alice → /home/alice (/bin/bash)
bob → /home/bob (/bin/bash)
```
- `IFS=:` splits each line on `:` into the named variables. `_` is a throwaway name for fields you don't need.

```bash
count=0
while read -r pid cmd; do
    count=$((count + 1))
done < <(ps -eo pid=,comm=)
echo "processes: $count"
```
- `< <(cmd)` keeps the loop in the **current** shell, so `count` survives. With `ps … | while …`, `count` would print 0.

**Last line without a newline** is skipped by a plain `while read`. Make it bulletproof: `while IFS= read -r line || [ -n "$line" ]; do …`.

### Bulk user creation from a file

```bash
#!/bin/bash
# users.txt: one name per line; blank lines and # comments allowed
while IFS= read -r u; do
    [[ -z $u || $u == \#* ]] && continue
    if id "$u" &>/dev/null; then
        echo "exists: $u"
    else
        sudo useradd "$u" && echo "created: $u"
    fi
done < users.txt
```

### until: wait for something

```bash
until curl -fsS http://localhost:8080/health >/dev/null; do
    echo "waiting for app..."
    sleep 2
done
echo "app is up"
```
- Waits until the health check succeeds. Add a limit, so it can't wait forever:

```bash
for attempt in {1..30}; do
    curl -fsS http://localhost:8080/health >/dev/null && { echo "up"; break; }
    sleep 2
done
```

### break and continue

```bash
for i in {1..10}; do
    (( i % 2 == 0 )) || continue      # skip odd numbers
    echo "Even: $i"
    (( i >= 6 )) && break             # stop after 6
done
```
```
Even: 2
Even: 4
Even: 6
```
- `break 2` leaves two nested loops at once.

### Infinite loop with an exit

```bash
while true; do
    read -rsp "New password (min 8 chars): " pw; echo
    [ "${#pw}" -ge 8 ] && break       # ${#pw} = length of the string
    echo "Too short."
done
```

### select menus

```bash
PS3="Choose: "
select opt in Date Uptime Quit; do
    case $opt in
        Date)   date ;;
        Uptime) uptime ;;
        Quit)   break ;;
        *)      echo "Invalid" ;;
    esac
done
```
```
1) Date
2) Uptime
3) Quit
Choose: 2
 16:05:12 up 9 days, ...
```

### Try it
1. Loop over `/etc/*.conf` and print each name with its line count.
2. Read `/etc/passwd` and print only users whose shell is `/bin/bash`.
3. Count processes with `ps | while read` and with `done < <(ps …)`. See which count survives.
4. Write an `until` loop that waits for `/tmp/ready` to exist; create it from another terminal.

**Check your work:** on your lab VM, from the notes folder, run `sudo ./checks/check 043` for every step, or `sudo ./checks/check 043 STEP` for one (topic 002 shows how to get the notes there).

## Where you'll use it

- **Fleet one-liners:** `for h in $(cat hosts.txt); do ssh "$h" 'sudo dnf -y upgrade'; done` (before you move to Ansible, topic 105).
- **Retry and wait loops** in deploy scripts and container entrypoints ("wait for the database to accept connections").
- **Processing CSV, inventories and log files** line by line.
- **Kubernetes:** `for ns in $(kubectl get ns -o name); do …; done`; `until kubectl rollout status deploy/app; do sleep 5; done`.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| The loop runs once with a literal `*.txt` | The glob matched nothing | `[ -e "$f" ] \|\| continue`, or `shopt -s nullglob` |
| File names with spaces get split | `for f in $(ls)` or `$(find …)` | Loop over a glob, or `find … -print0 \| while IFS= read -r -d '' f` |
| A counter is 0 after `cmd \| while` | The loop ran in a pipeline subshell | `done < <(cmd)` |
| The last line of a file is skipped | No trailing newline | `\|\| [ -n "$line" ]` |
| `{1..$n}` prints literally | Braces expand before variables | `seq 1 "$n"` or C-style |
| Infinite loop | The condition never changes | Increment the counter; Ctrl+C; add a max-attempts limit |
| `ssh` inside a `while read` loop eats the rest of the file | ssh reads stdin too | `ssh -n …` or `ssh … </dev/null` |

## Quick recap

- `for x in LIST` (globs, `"$@"`, `seq`), `for ((i=0;i<n;i++))`, `while COND`, `until COND`, `break`, `continue`.
- Read files safely: `while IFS= read -r line; do …; done < file`.
- `cmd | while` runs in a subshell, so variables are lost. Use `done < <(cmd)`.
- Never `for f in $(ls)`. Loop over globs, and always quote `"$f"`.

**Interview questions**

1. *What's the best way to read a file line by line in bash?* `while IFS= read -r line; do …; done < file`.
2. *Why is a counter still 0 after `cmd | while read …; do ((n++)); done`?* Each part of a pipeline runs in a subshell, so the loop's variable changes are lost when it ends. Use `done < <(cmd)`.
3. *`while` vs `until`?* `while` repeats as long as the condition succeeds; `until` repeats until it succeeds.

**Scenario question** (answer out loud first, then compare)

> *"A script loops over a list of servers to run a command with SSH, but it stops after the first server. The list has 20 lines. Why?"*

**Model answer:**
1. The loop is `while read -r host; do ssh "$host" uptime; done < servers.txt`.
2. `ssh` reads from **stdin**, which is the same file the loop is reading. It swallows the remaining 19 lines, so `read` hits end-of-file.
3. Fix: stop ssh reading stdin: `ssh -n "$host" uptime` (or `< /dev/null`). Or read the list from a different file descriptor: `while read -r host <&3; do …; done 3< servers.txt`.
4. Also use `IFS= read -r` and skip blank or comment lines.

**Likely follow-ups:**
- *Why is a counter 0 after `cmd | while read …`?* The loop runs in a subshell; use `done < <(cmd)`.
- *Why not `for f in $(ls)`?* Names with spaces split, and globs inside names expand. Loop over a glob instead: `for f in ./*`.
