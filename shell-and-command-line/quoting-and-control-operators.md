# Quoting, Arguments & Control Operators

> **Sessions:** S9 (commands & arguments), S11 (control operators) · **Baseline:** RHEL 10, bash 5.x
> **Related:** [Shell basics](shell-basics-and-command-syntax.md) · [Variables](shell-variables-and-environment.md) · [Expansion & globbing](shell-expansion-and-globbing.md) · [History](command-history.md) · [I/O redirection](../files-and-text-processing/io-redirection-and-pipes.md) · [Processes & job control](../processes-and-resource-management/processes-and-signals.md)

## 1. Overview

Before running anything, bash splits the command line into **words** (arguments), applies quoting and escaping, and recognizes **control operators** that decide *whether* and *when* commands run. Most "mysterious" shell behavior is a quoting problem, so this is foundational for every exam task and every script.

## 2. Arguments & Quoting **[RHCSA Core]**

### 2.1 Word splitting

Unquoted spaces, tabs and newlines separate arguments, and runs of whitespace collapse. Quotes and backslashes keep text together.

Use `printf '[%s]\n'` to *see* how many arguments the shell produced:

```bash
$ printf '[%s]\n' '/var/log/x.log' 'document 55.txt' "notes 21.txt"
[/var/log/x.log]
[document 55.txt]
[notes 21.txt]                 # 3 arguments
$ printf '[%s]\n' document 55.txt
[document]
[55.txt]                       # 2 arguments
```

### 2.2 Quoting rules

| Form | Variables / `$(cmd)` expanded? | Globs (`*`) expanded? | Notes |
|---|---|---|---|
| Unquoted | Yes, then **word-split** | Yes | Whitespace separates arguments |
| `"double"` | Yes, **no** word splitting | No | Backslash escapes only `$`, backquote, `"`, `\`, newline. **`!` history expansion still active** in interactive shells |
| `'single'` | No | No | Fully literal; can't contain a `'` |
| `\c` | — | — | Escapes one character |
| `$'ansi'` | No variables; ANSI escapes like `\n` `\t` `\'` | No | `echo $'a\tb'` **[Advanced]** |

```bash
var=42
echo "The answer is $var"      # The answer is 42
echo 'The answer is $var'      # The answer is $var
echo "Why \$var?"              # Why $var?
echo "Hello \"Linux\" User"    # Hello "Linux" User
echo 'It'\''s'                 # It's   (close quote, escaped ', reopen)
echo hello   world             # hello world      (unquoted spaces collapse)
echo hello\ \ \ world          # hello   world    (escaped spaces are KEPT)
echo escaping \\ \# \& \" \'   # escaping \ # & " '
```

### 2.3 The `!` trap (interactive shells only)

Bash history expansion replaces `!!`, `!word`, etc., **even inside double quotes**:

```bash
echo "!!// 202 commands and options"     # ✘ !! becomes your previous command
echo '!!// 202 commands and options'     # ✔ single quotes
echo \!\!// 202 commands and options     # ✔ escaped, unquoted
echo '!!'"// 202 commands and options"   # ✔ mixed quoting
set +H; echo "!!// 202 …"; set -H        # ✔ history expansion off, then back on
```

Scripts aren't affected; history expansion is off in non-interactive shells.

### 2.4 `echo` vs `printf`

| | `echo` | `printf` |
|---|---|---|
| Trailing newline | Always added (`-n` suppresses) | Only if you write `\n` |
| Escapes (`\n`, `\t`) | Only with `-e` | Always interpreted in the format string |
| Portability | Varies between shells | Consistent; preferred in scripts |

```bash
echo World                         # World⏎
echo -e "World\n"                  # World⏎⏎ (extra blank line)
echo -e "word1\nword2\nword3"      # three lines
printf '%s\n' word1 word2 word3    # same, portable
printf '3+5\t\t=8\n12+18\t=30\n'   # tab stops every 8 columns
echo "X Y   Z"                     # quoted → spacing preserved
```

## 3. Command Types & Aliases

### 3.1 What will actually run?

```bash
type rev                 # rev is /usr/bin/rev  → external, not a builtin
type -a printf           # printf is a shell builtin / printf is /usr/bin/printf
type -P grep             # path only, ignores aliases: /usr/bin/grep
command ls               # skip aliases and functions
\ls                      # skip aliases only, once
```

`printf` runs the **builtin** (it wins in the lookup order). `/usr/bin/printf` forces the external program. The same applies to `echo`, `kill`, `test`/`[` and `pwd`.

### 3.2 Aliases

```bash
alias                          # list all
alias ll                       # show one
alias country='echo "India"'   # define (current shell only)
alias mv='mv -i'               # safer mv
unalias country                # remove
```

- Persist aliases in `~/.bashrc`, or system-wide in `/etc/profile.d/*.sh`.
- Aliases apply only to the **first word**, and only in **interactive** shells. Scripts ignore them unless `shopt -s expand_aliases`.
- Need arguments? Use a function:

```bash
  mkcd() { mkdir -p -- "$1" && cd -- "$1"; }
```

- RHEL ships aliases such as `ls --color=auto`, `ll`, `l.` and color `grep`. Root's `~/.bashrc` adds `rm -i`, `cp -i`, `mv -i`. Run `alias` to see what's active.

## 4. Control Operators **[RHCSA Core]**

| Operator | Meaning | Example |
|---|---|---|
| `;` or newline | Run sequentially, regardless of result | `cd /tmp; ls` |
| `&` | Run in the background | `sleep 60 &` |
| `&&` | Run next **only if** previous succeeded (exit 0) | `mkdir d && cd d` |
| `\|\|` | Run next **only if** previous failed | `mkdir d \|\| echo "exists"` |
| `\|` | Pipe stdout → stdin ([redirection note](../files-and-text-processing/io-redirection-and-pipes.md)) | `ls -l \| less` |
| `!` | Negate an exit status | `! grep -q root /etc/passwd && echo "no root?"` |
| `( … )` | Group in a **subshell** | `(cd /etc; ls)` (your cwd is unchanged) |
| `{ …; }` | Group in the **current** shell (spaces and final `;` required) | `{ date; uptime; } > report.txt` |
| `#` | Comment, only at the **start of a word** | `echo a#b` → `a#b`; `echo a #b` → `a` |
| `\` + Enter | Continue on the next line (must be the **last** character) | `cmd --opt1 \` ⏎ `--opt2` |

### 4.1 Exit status (`$?`)

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | General failure (e.g., `grep` found nothing) |
| `2` | Misuse / serious error (e.g., `ls` can't access an argument) |
| `126` | Command found but not executable |
| `127` | Command not found |
| `128+N` | Killed by signal N (`130` = Ctrl+C/SIGINT, `137` = SIGKILL; see [signals](../processes-and-resource-management/processes-and-signals.md#4-signals)) |

```bash
ls /nonexistent; echo $?      # ls: cannot access '/nonexistent': … → 2
rc=$?                         # save it immediately; the next command overwrites $?
```

### 4.2 `&& … ||` is NOT a true if/else

```bash
true && false || echo "runs!"        # prints runs!, because the || reacts to `false`, not to `true`
cmd1 && cmd2 || cmd3                 # cmd3 runs if cmd1 fails OR cmd2 fails
if cmd1; then cmd2; else cmd3; fi    # exact if/else (S88)
```

### 4.3 Background jobs (preview of S29)

```bash
sleep 60 &            # [1] 12345   ← job number, PID
jobs -l               # list jobs with PIDs
fg %1                 # bring to the foreground;  Ctrl+Z suspends;  bg %1 resumes in background
kill %1               # signal a job by number
echo $!               # PID of the most recent background job
wait                  # (scripts) wait for background jobs to finish
```

Background jobs started from a terminal normally receive SIGHUP when it closes. For long-running work use `nohup`, `disown` or a systemd unit. Full coverage: [processes, signals & job control](../processes-and-resource-management/processes-and-signals.md#5-job-control).

## 5. RHCSA Exam Focus

- Quote paths with spaces and every variable (`"$var"`).
- Chain dependent steps with `&&` so a failure stops the chain: `mkdir -p /mnt/data && mount -a`.
- Exit codes drive `if`/`test` in scripts (S87–90). Know `0` = success.
- Aliases you define vanish at logout unless they're in `~/.bashrc`. Never rely on aliases inside scripts.

## 6. Production Practices **[Production Practice]**

- Debug argument splitting with `printf '[%s]\n' …` or `set -x`.
- Fail loudly: `cmd || { echo "cmd failed" >&2; exit 1; }`.
- Prefer functions over aliases for anything non-trivial.
- Put long commands on several lines with `\`, but watch for trailing spaces after the backslash.

## 7. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `bash: !…: event not found` | History expansion of `!` | Single quotes, `\!`, or `set +H` |
| `No such file or directory` for a name with spaces | Unquoted, so split into words | Quote it |
| A `>` prompt appears and waits | Unclosed quote/brace or trailing `\` (PS2) | Finish the command or press Ctrl+C |
| Alias works interactively, not in a script | Aliases aren't expanded in scripts | Use a function or the full command |
| Line continuation doesn't work | Space after the `\` | Remove trailing whitespace |
| `else` branch runs unexpectedly after `&& …\|\|` | Middle command failed | Use `if … then … else … fi` |

## 8. Interview Questions

| Question | Answer |
|---|---|
| Single vs double quotes? | Single: everything literal. Double: `$`, backquote and `\` still work, but there's no word splitting or globbing. |
| Is `a && b \|\| c` an if/else? | No. `c` also runs if `b` fails. |
| What do exit codes 126, 127 and 130 mean? | Not executable; not found; terminated by SIGINT (Ctrl+C). |
| `( )` vs `{ }`? | `( )` runs in a subshell (changes don't persist). `{ }` runs in the current shell. |
| Alias vs function? | An alias is a text substitution for the first word. A function takes arguments and logic, and works in scripts. |
| Why can `printf` and `/usr/bin/printf` behave differently? | The first is the bash builtin, the second the coreutils binary; their option and escape support differ slightly. |

## 9. Quick Revision

```bash
printf '[%s]\n' args…        # count/inspect arguments
'literal'  "expand $var"  \x  $'\t'
a ; b    a & b    a && b    a || b    ! a    ( a; b )    { a; b; }
echo $?   rc=$?   126/127/130
type -a cmd | alias | unalias | \cmd | command cmd
set +H   # stop ! history expansion
```

## 10. Cross-References

- [Variables & environment](shell-variables-and-environment.md) (variable quoting)
- [Expansion & globbing](shell-expansion-and-globbing.md) (expansion order)
- [Command substitution & options](command-substitution-and-shell-options.md) (`set -x`, subshells)
- [I/O redirection & pipes](../files-and-text-processing/io-redirection-and-pipes.md)
- [Processes, signals & job control](../processes-and-resource-management/processes-and-signals.md)
- [Scripting conditions](../bash-scripting-and-automation/conditionals-and-tests.md)
