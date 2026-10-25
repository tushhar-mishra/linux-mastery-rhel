# Bash Scripting Basics: Scripts, Shebang, Output & Variables

> **Sessions:** S85–S86 · supports all *Create simple shell scripts* objectives **[RHCSA Core]**
> **Related:** [Script input & arguments](script-input-and-arguments.md) · [Conditionals & tests](conditionals-and-tests.md) · [Loops](loops.md) · [Arithmetic](arithmetic.md) · [Variables & environment](../shell-and-command-line/shell-variables-and-environment.md) · [Quoting](../shell-and-command-line/quoting-and-control-operators.md) · [Command substitution & `set -x`](../shell-and-command-line/command-substitution-and-shell-options.md) · [Robust scripts](robust-scripts.md)

## 1. Overview

A **shell script** is a text file of commands run by an interpreter (bash on RHEL), line by line, without compilation. Scripts automate repetitive admin work: user creation, backups, checks and reports.

**Terminal vs shell:** the terminal (GNOME Terminal, SSH client) shows text and sends keystrokes; the **shell** (`bash`, `zsh`, `ksh`) interprets commands. `echo $SHELL` shows your **login** shell; `ps -p $$ -o comm=` shows the shell you're running now.

## 2. Your First Script

`````bash
vim ~/bin/hello.sh
`````

`````bash
#!/bin/bash
# hello.sh — prints a greeting (comment lines start with #)
echo "Hello World"
`````

`````bash
chmod +x ~/bin/hello.sh        # or chmod 755
./hello.sh                     # run from the current directory
~/bin/hello.sh                 # absolute path; ~/bin is usually in PATH → just: hello.sh
bash hello.sh                  # run with bash explicitly (no x bit needed)
source hello.sh  /  . hello.sh # run in the CURRENT shell (variables/cd persist)
`````

### The shebang (`#!`)

| Line | Interpreter |
|---|---|
| `#!/bin/bash` | bash (use this for bash features: `[[ ]]`, arrays, `(( ))`) |
| `#!/bin/sh` | POSIX shell: on RHEL this is bash in POSIX mode |
| `#!/usr/bin/python3` | Python 3 |
| `#!/usr/bin/env bash` | First `bash` in PATH (portable across systems) |

The shebang must be the **first line**; without it, `./script` is run by `/bin/sh` or the calling shell, depending on how it's invoked.

## 3. Output: `echo` and `printf`

`````bash
echo "Hi All"                       # newline added
echo -n "No newline"                # suppress newline
echo -e "Line1\nLine2\tTabbed"      # interpret escapes (\n \t \c)
printf '%s is %d years old\n' "Alice" 30    # portable, precise formatting
printf 'Enter name: ' ; read -r name        # prompt without newline (or read -p)
`````

## 4. Variables

`````bash
course="Bash Scripting"            # NO spaces around =
echo "Welcome to $course"          # quote expansions
echo "${course}s"                  # braces delimit the name
count=5 ; readonly MAX=10          # readonly: can't be changed
unset course                       # remove
today=$(date +%F)                  # command substitution (preferred over `backticks`)
`````

- Names: letters, digits, `_`; not starting with a digit; case-sensitive.
- Convention: UPPERCASE for environment/constant values, lowercase for script-local variables.

| Quoting | Example | Output |
|---|---|---|
| Single quotes: literal | `echo 'My name is $USER'` | `My name is $USER` |
| Double quotes: expand, no splitting | `echo "My name is $USER"` | `My name is alice` |
| No quotes: expand + word splitting + globbing | `echo $USER` | `alice` (but unsafe for spaces/`*`) |

**Export:** a variable is visible to child processes (other scripts, `bash`) only if exported: `export DB_HOST=db1`. Persist for a user in `~/.bashrc`; system-wide in `/etc/profile.d/*.sh` or `/etc/environment`.

Common shell variables: `$HOME`, `$USER`, `$HOSTNAME`, `$PWD`, `$SHELL` (login shell), `$BASH_VERSION`, `$RANDOM`, `$$` (PID), `$?` (last exit status).

## 5. Script Skeleton (good habits)

`````bash
#!/bin/bash
# purpose: …    usage: script.sh ARG
set -euo pipefail                 # stop on errors / unset vars / pipe failures (know the caveats)
LOG=/var/log/myscript.log

log() { printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }

main() {
    log "started"
    # … work …
    log "finished"
}
main "$@"
`````

## 6. Debugging

`````bash
bash -n script.sh        # syntax check only
bash -x script.sh        # trace every command (after expansion)
set -x ; …; set +x       # trace part of a script
shellcheck script.sh     # static analysis (EPEL) [Advanced]
`````

Bash reads a whole compound command (if/loop/function) before running it, so a syntax error aborts that block. Commands that fail at runtime don't stop the script unless you use `set -e` or check `$?`.

## 7. RHCSA Exam Focus **[RHCSA Core]**

- Scripts must have a shebang, be executable, and be at the **exact path** requested (often in `/usr/local/bin` so they're in PATH).
- Test them as the intended user; check exit codes (`echo $?`).
- Quote every variable expansion.

## 8. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Permission denied` | Not executable / `noexec` mount | `chmod +x`; run with `bash script` |
| `command not found` when typing `script.sh` | Not in PATH | `./script.sh` or move to `/usr/local/bin` |
| `bad interpreter: /bin/bash^M` | Windows line endings | `sed -i 's/\r$//' script.sh` |
| `name: command not found` on assignment | Spaces around `=` | `name=value` |
| Variable empty in child script | Not exported | `export VAR` |
| Variable set in script missing afterwards | Script ran in a child shell | `source script.sh` |

## 9. Interview Questions

| Question | Answer |
|---|---|
| What does the shebang do? | Tells the kernel which interpreter runs the file. |
| `./script.sh` vs `source script.sh`? | Child process vs current shell (changes persist). |
| Single vs double quotes? | Single: literal. Double: variables/command substitution expand, no word splitting. |
| How do you debug a script? | `bash -n` (syntax), `bash -x` (trace), `set -x` sections. |

## 10. Quick Revision

`````bash
#!/bin/bash · chmod +x · ./s.sh | bash s.sh | source s.sh · echo -e / printf
var=value "$var" "${var}" $(cmd) export readonly unset · 'literal' "expand"
bash -n · bash -x · set -euo pipefail · sed -i 's/\r$//'
`````

## 11. Cross-References

- [Script input & arguments](script-input-and-arguments.md)
- [Conditionals & tests](conditionals-and-tests.md)
- [Loops](loops.md)
- [Arithmetic](arithmetic.md)
- [Variables & environment](../shell-and-command-line/shell-variables-and-environment.md)
- [Quoting](../shell-and-command-line/quoting-and-control-operators.md)
- [Command substitution & `set -x`](../shell-and-command-line/command-substitution-and-shell-options.md)
