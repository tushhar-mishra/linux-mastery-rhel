# Loops: for, while, until, break/continue & Processing Input

> **Objective:** *Use Looping constructs (for, etc.) to process file, command line input* **[RHCSA Core]**
> **Related:** [Conditionals & tests](conditionals-and-tests.md) · [Script input & arguments](script-input-and-arguments.md) · [Arithmetic](arithmetic.md) · [Expansion & globbing](../shell-and-command-line/shell-expansion-and-globbing.md)

## 1. Conditionals vs Loops

| | Conditionals (`if`, `case`) | Loops (`for`, `while`, `until`) |
|---|---|---|
| Purpose | Decide | Repeat |
| Condition checked | Once | Every iteration |
| Typical use | "If the file exists…" | "For every file / user / line…" |

Loops usually contain conditionals.

## 2. `for`

````bash
for i in 1 2 3 4 5; do echo "Number: $i"; done
for i in {1..10..2}; do echo "$i"; done            # brace range with step (literal numbers only)
for i in $(seq 1 "$n"); do echo "$i"; done          # variable range
for ((i=1; i<=5; i++)); do echo "Counter: $i"; done # C-style

for file in /var/log/*.log; do                      # files (glob)
    [ -e "$file" ] || continue                      # no match → skip literal pattern
    echo "Processing $file"
done

for user in "$@"; do echo "Arg: $user"; done        # command-line arguments
for u in $(awk -F: '$3>=1000 && $3<60000 {print $1}' /etc/passwd); do   # command output (simple words only)
    echo "Regular user: $u"
done
````

`for x in $(cmd)` splits on whitespace and expands globs. Use `while read` for lines that may contain spaces.

## 3. `while`

````bash
i=1
while [ "$i" -le 5 ]; do echo "$i"; ((i++)); done

while IFS= read -r line; do                    # read a file line by line (safe)
    echo "Line: $line"
done < /etc/hosts

while IFS=: read -r user _ uid _ _ home shell; do   # split fields
    [ "$uid" -ge 1000 ] && echo "$user → $home ($shell)"
done < /etc/passwd

while read -r pid cmd; do                      # read command output WITHOUT a subshell
    echo "$pid $cmd"
done < <(ps -eo pid=,comm= | head -5)          # process substitution

while true; do                                 # infinite loop (with exit condition)
    read -rsp "Password: " pw ; echo
    if [ "${#pw}" -ge 6 ]; then echo "Accepted"; break; fi
    echo "Too short, try again."
done
````

> **Pipe pitfall:** `cmd | while read …; do count=…; done` runs the loop in a **subshell**, so variables set inside are lost afterwards. Use `done < <(cmd)` or `done < file`.

## 4. `until`

````bash
i=1
until [ "$i" -gt 5 ]; do echo "Value: $i"; ((i++)); done

until [ -e /tmp/ready.txt ]; do                 # wait for a condition
    echo "Waiting for file…" ; sleep 2
done
echo "File found!"
````

## 5. Loop Control

| Keyword | Effect |
|---|---|
| `break` / `break 2` | Leave the loop / two nested levels |
| `continue` | Skip to the next iteration |

````bash
for i in {1..10}; do
    (( i % 2 == 0 )) || continue      # odd → skip
    echo "Even: $i"
    (( i >= 8 )) && break
done
````

### `select` menus **[Advanced]**

````bash
PS3="Choose: "
select opt in Date Calendar Quit; do
    case $opt in
        Date) date ;; Calendar) cal ;; Quit) break ;; *) echo "Invalid" ;;
    esac
done
````

## 6. RHCSA Exam Patterns **[RHCSA Core]**

````bash
#!/bin/bash
# Process files given as arguments: report line counts
for f in "$@"; do
    if [ -f "$f" ]; then echo "$f: $(wc -l < "$f") lines"; else echo "$f: not a file" >&2; fi
done

#!/bin/bash
# Process a file: create users listed one per line in users.txt
while IFS= read -r u; do
    [ -z "$u" ] && continue
    id "$u" &>/dev/null || useradd "$u"
done < /root/users.txt

#!/bin/bash
# Search a directory for files owned by a user and copy them
mkdir -p /root/found
for f in $(find /home -user harry -type f 2>/dev/null); do cp -a "$f" /root/found/; done
# (safer with spaces: find … -exec cp -a {} /root/found/ \;)
````

## 7. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Loop runs once with `*.txt` literally | Glob matched nothing | `[ -e "$f" ] \|\| continue` or `shopt -s nullglob` |
| Filenames with spaces split | `for f in $(ls)` / `$(find)` | Globs, `while IFS= read -r`, `find -exec` / `-print0` |
| Counter is 0 after `cmd \| while` | Pipeline subshell | `done < <(cmd)` |
| Last line of a file skipped | No trailing newline | `while IFS= read -r line \|\| [ -n "$line" ]` |
| `{1..$n}` prints literally | Brace expansion happens before variables | `seq 1 "$n"` or C-style loop |
| Infinite loop | Counter never changes | `((i++))`; Ctrl+C to stop |

## 8. Interview Questions

| Question | Answer |
|---|---|
| Best way to read a file line by line? | `while IFS= read -r line; do …; done < file`. |
| `while` vs `until`? | while runs while the condition is true; until runs until it becomes true. |
| Why do variables vanish after `cmd \| while read`? | The loop ran in a subshell; use process substitution or redirection. |
| `break` vs `continue`? | Exit the loop vs skip to the next iteration. |

## 9. Quick Revision

````bash
for x in LIST; do …; done · for i in {1..5} · for ((i=0;i<n;i++)) · for f in /dir/*.ext · for a in "$@"
while COND; do …; done · while IFS= read -r line; do …; done < file · done < <(cmd)
until COND; do …; done · break · continue · select · nullglob
````

## 10. Cross-References

- [Conditionals & tests](conditionals-and-tests.md)
- [Script input & arguments](script-input-and-arguments.md)
- [Arithmetic](arithmetic.md)
- [Expansion & globbing](../shell-and-command-line/shell-expansion-and-globbing.md)
