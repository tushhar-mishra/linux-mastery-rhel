# 040 · Bash Scripting Basics: Your First Scripts

> **You need first:** [039 · Job scheduling](039-job-scheduling-cron-and-timers.md)
> **Next:** [041 · Script input and arguments](041-script-input-and-arguments.md)

---

## What it is

A **shell script** is a plain text file full of commands that bash runs from top to bottom, exactly as if you had typed them. There's no compiling step.

- The **shebang** (`#!`, from "hash" + "bang") on the first line names the **interpreter**, the program that runs the file: `#!/bin/bash`.
- A **function** is a named block of commands you can call like a command.
- A **comment** is a line (or the end of a line) starting with `#`; bash ignores it.

Everything from Parts 1–2 (quoting, variables, expansion, redirection, pipes, exit codes) works the same inside scripts. A script is just those skills saved in a file.

## Why it exists

Anything you do twice, you'll eventually do a hundred times: create users, back up configs, check disk space, rotate files, deploy an app. Scripts make those tasks **repeatable, fast, reviewable and schedulable** (cron and timers, topic 039). Shell scripts are the glue of Linux administration, CI pipelines, container entrypoints and cloud-init.

## Analogy

A script is a **recipe card**. Instead of telling the cook each step out loud every time, you write the steps down once. The shebang is the line at the top saying **which cook** should follow it ("this is a bash recipe", "this is a Python recipe").

## How it works inside

When you run `./backup.sh`:
1. Your shell asks the kernel to run (execve) the file.
2. The kernel reads the first two bytes. If they are `#!`, it reads the rest of that line (`/bin/bash`) and runs **that program**, passing the script's path as an argument: effectively `/bin/bash ./backup.sh`.
3. A **new bash process** (a child, topic 033) reads the file and runs it. When it finishes, its exit status is the status of the **last command** run (or the number given to `exit N`).
4. Because the script ran in a **child**, its variables, `cd` and settings disappear when it ends (topic 012). `source script.sh` runs it **inside your current shell** instead.

Bash reads a whole compound command (an `if` block, a loop, a function) before running it. A **syntax** error stops that block. **Runtime** errors (a command that fails) do **not** stop the script unless you use `set -e` or check `$?` (topics 014, 045).

### Shebang options

| First line | Interpreter |
|---|---|
| `#!/bin/bash` | bash. Use this when you use bash features (`[[ ]]`, arrays, `(( ))`) |
| `#!/usr/bin/env bash` | The first `bash` found in PATH. More portable (macOS, BSD, Nix) |
| `#!/bin/sh` | The POSIX shell. RHEL: bash in POSIX mode. **Ubuntu: `dash`**, which lacks bash features, so a bash-only script with `#!/bin/sh` **breaks on Ubuntu** |
| `#!/usr/bin/python3` | Python |

The shebang must be the **very first line**, starting at the first character.

## Commands

### Write, make executable, run

```bash
mkdir -p ~/bin
cat > ~/bin/hello.sh <<'EOF'
#!/bin/bash
# hello.sh - greet the user and show basic facts
name="${1:-world}"                     # first argument, or "world" if none (topic 041)
echo "Hello, $name!"
echo "You are $(whoami) on $(hostname), kernel $(uname -r)"
EOF
chmod +x ~/bin/hello.sh
```

| How to run | What happens |
|---|---|
| `./hello.sh` | Run from the current directory (needs the `x` permission) |
| `~/bin/hello.sh` or `hello.sh` | `~/bin` is in PATH on RHEL (topic 012), so the name alone works |
| `bash hello.sh` | Run with bash explicitly; no `x` needed; ignores the shebang |
| `source hello.sh` or `. hello.sh` | Run **in your current shell**; variables and `cd` stay afterwards |

```bash
hello.sh Alice ; echo "exit status: $?"
```
```
Hello, Alice!
You are alice on server1.example.com, kernel 6.12.0-211.53.1.el10_2.x86_64
exit status: 0
```

### Output: echo and printf

```bash
echo "Plain line"
echo -n "No newline at the end"
printf '%-10s %5d\n' "disk" 85
printf 'Enter your name: ' ; read -r who      # read: topic 041
```
```
Plain line
No newline at the enddisk          85
```
- In scripts, prefer `printf`: it behaves the same everywhere (topic 011).

### Variables in scripts (recap)

```bash
backup_dir="/backup/$(date +%F)"     # no spaces around =
readonly MAX_COPIES=7                # can't be changed later
echo "Saving to ${backup_dir}"       # always quote expansions
```
- Lowercase for script-local variables, UPPERCASE for constants and exported values.
- Useful built-ins: `$HOME`, `$USER`, `$HOSTNAME`, `$PWD`, `$RANDOM` (a random number), `$$` (this script's PID), `$?`, `$0` (the script's name).

### Functions

```bash
log() {
    printf '%s %s\n' "$(date '+%F %T')" "$*" >> /tmp/myscript.log
}

log "starting"
log "done"
```
- Inside a function, `$1`, `$2`… and `"$@"` are the **function's** arguments; `$*` joins them into one string.
- Variables are **global** by default. Use `local var=…` inside functions to keep them private.
- `return N` sets the function's exit status (0–255). Output is "returned" by printing it and capturing it with `$(…)`.

### A good skeleton

```bash
#!/bin/bash
# disk-report.sh - print usage of each real filesystem
# usage: disk-report.sh [threshold_percent]
set -euo pipefail                    # stop on errors, unset variables, pipeline failures (topic 014)

threshold="${1:-80}"

log() { printf '%s %s\n' "$(date '+%F %T')" "$*" >&2; }   # messages to stderr

main() {
    log "checking filesystems above ${threshold}%"
    df -hP -x tmpfs -x devtmpfs | awk -v t="$threshold" 'NR>1 && $5+0 > t {print $6, $5}'
}

main "$@"
```
- The data (the filesystem list) goes to **stdout**; status messages go to **stderr**. Other programs can then use the output cleanly.
- `main "$@"` at the end passes all the script's arguments to `main`, and keeps the top of the file readable.

### Debugging

```bash
bash -n disk-report.sh         # syntax check only
bash -x disk-report.sh 50      # trace every command after expansion
```
```
+ set -euo pipefail
+ threshold=50
+ main 50
+ log 'checking filesystems above 50%'
...
```
- Or wrap just one part in `set -x` … `set +x`.
- **ShellCheck** (`dnf install ShellCheck` from EPEL, or `apt install shellcheck`) finds quoting bugs and common mistakes before you run anything. Use it on every script.

### Where to put scripts

| Location | For |
|---|---|
| `~/bin` | Your own scripts |
| `/usr/local/bin` | Scripts for all users (in everyone's PATH) |
| `/usr/local/sbin` | Admin-only scripts |
| `/opt/<app>/bin` | Scripts that belong to one application |

### Try it
1. Create `hello.sh` as above, run it four different ways, and compare.
2. Add `cd /tmp` to a script. Run it with `./` and with `source`, and check `pwd` afterwards.
3. Write `disk-report.sh` and run it with thresholds 10 and 90.
4. Introduce a typo (`fi` without `if`), run `bash -n`, then fix it and trace it with `bash -x`.

**Check your work:** on your lab VM, from the notes folder, run `sudo ./checks/check 040` for every step, or `sudo ./checks/check 040 STEP` for one (topic 002 shows how to get the notes there).

## Where you'll use it

- **Automation:** backup, cleanup, user provisioning, health checks, run by cron or timers.
- **Container entrypoints:** `entrypoint.sh` prepares config, then `exec`s the main program (so it becomes PID 1 and receives signals, topic 033).
- **CI/CD steps** are shell commands and small scripts.
- **cloud-init** user-data (topic 104) is often a bash script that runs at first boot.
- **When to stop using bash:** big logic, data structures or JSON handling are better in Python or Go (topic 045).

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `Permission denied` | No `x` bit, or the filesystem is mounted `noexec` | `chmod +x`, or run with `bash script` |
| `script.sh: command not found` | The directory isn't in PATH | `./script.sh`, or move it to `/usr/local/bin` |
| `bad interpreter: /bin/bash^M` | Windows line endings | `sed -i 's/\r$//' script.sh` |
| `[[: not found` / `Syntax error: "(" unexpected` on Ubuntu | `#!/bin/sh` runs `dash`, not bash | Use `#!/bin/bash` |
| `name: command not found` on an assignment | Spaces around `=` | `name=value` |
| A variable set in the script is gone afterwards | The script ran in a child | `source script.sh` |
| Works by hand, fails in cron | Minimal environment (topic 039) | Full paths; set PATH in the script |

## Quick recap

- A script = commands in a file. The first line `#!/bin/bash` names the interpreter (the kernel reads it). `chmod +x` to run it as `./script`.
- It runs in a **child** process; `source` runs it in the current shell. Its exit status = the last command's, or `exit N`.
- Use functions, `local`, `printf`, quoted expansions; messages to stderr, data to stdout.
- Debug with `bash -n`, `bash -x`, ShellCheck. On Ubuntu, `#!/bin/sh` is dash, not bash.

**Interview questions**

1. *What does the shebang line do?* It tells the kernel which interpreter to run the file with. The kernel reads `#!` and runs that program with the script path as an argument.
2. *`./script.sh` vs `source script.sh`?* `./script.sh` runs in a new child process, so its variables and `cd` vanish. `source` runs it in the current shell, so changes persist.
3. *How do you debug a bash script?* `bash -n` for syntax, `bash -x` (or `set -x`) to trace each expanded command, and ShellCheck for static analysis.

**Scenario question** (answer out loud first, then compare)

> *"A script that works on your RHEL laptop fails on an Ubuntu server with `Syntax error: "(" unexpected` or `[[: not found`. Why?"*

**Model answer:**
1. Look at the first line. It's probably `#!/bin/sh`.
2. On RHEL, `/bin/sh` is bash (in POSIX mode), so bash features like `[[ ]]`, arrays and `function` happen to work.
3. On Ubuntu, `/bin/sh` is **dash**, a strict POSIX shell without those features.
4. Fix: if the script uses bash features, say so: `#!/bin/bash` (or `#!/usr/bin/env bash`). Or rewrite it in POSIX sh.
5. Running it as `sh script.sh` also ignores the shebang, so call it as `./script.sh` or `bash script.sh`.
6. ShellCheck warns about this ("In POSIX sh, [[ ]] is undefined").

**Likely follow-ups:**
- *Why does `./script.sh` give "Permission denied" but `bash script.sh` works?* The file lacks the execute bit (`chmod +x`), or it's on a `noexec` mount.
- *Where should a script send error messages?* stderr (`>&2`), so they don't mix with the data on stdout.
