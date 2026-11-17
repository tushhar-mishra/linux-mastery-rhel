# 012 · Variables, the Environment and PATH

> **You need first:** [011 · Quoting and control operators](011-quoting-and-control-operators.md)
> **Next:** [013 · Expansion and globbing](013-expansion-and-globbing.md)

---

## What it is

- A **variable** is a named value stored by the shell: `count=500`. You read it with `$count`.
- A **shell variable** (local variable) exists only inside the current shell.
- An **environment variable** is a shell variable that has been **exported**. A copy of it is handed to every program the shell starts.
- The **environment** is the full set of exported variables a program receives when it starts.
- **PATH** is the most important environment variable. It is the list of directories bash searches to find a command.
- **Positional parameters** (`$1`, `$2`, …) hold the arguments given to a script or function.

One term: a **child process** is a program started by another program (its **parent**). When you type `ls`, bash is the parent and `ls` is the child. Topic 033 explains processes.

## Why it exists

Variables let you store a value once and reuse it. The environment is how settings flow into programs **without changing their code**: language (`LANG`), editor (`EDITOR`), proxy servers (`https_proxy`), and the database password for an app (`DB_PASSWORD`). This "configure by environment variable" style is how **containers and Kubernetes** configure applications, so this topic matters far beyond the shell.

## Analogy

Shell variables are **notes on your own desk**: only you see them. Exporting a variable is **photocopying the note and stapling it to every job you hand out**. Each worker (child process) gets its own **copy**. If a worker scribbles on their copy, your original doesn't change. And a worker can never reach back and edit your desk.

## How it works inside

### Local vs exported

| | Shell (local) variable | Environment variable |
|---|---|---|
| Created with | `name=value` | `export name=value` (or `export name` later) |
| Seen by child processes | No | Yes, as a **copy** |
| Listed by | `set`, `declare -p` | `env`, `printenv`, `export -p` |
| Examples | `PS1`, `HISTSIZE`, your `count` | `PATH`, `HOME`, `LANG`, `USER` |

When bash starts a program, the kernel's `execve` system call receives the program path, its arguments, **and** the list of exported `NAME=value` strings. The new program finds its environment in its own memory. You can see any running process's starting environment in `/proc/<PID>/environ`.

Copying goes **one way only, parent → child**. That's why:
- A script that sets a variable can't change your shell's variable after it finishes, because the script ran as a child.
- To run a script **inside** your current shell, so its variables stay, use `source script.sh` (or `. script.sh`).

### Rules for names and assignment

- Letters, digits and `_`. Can't start with a digit. Case-sensitive.
- Convention: UPPERCASE for environment and system variables, lowercase for your own.
- **No spaces around `=`.**

| Mistake | What bash does |
|---|---|
| `count = 500` | Runs a command named `count` with arguments `=` and `500` → `command not found` |
| `$count=500` | Replaces `$count` first, then tries to run the result |
| `unset $count` | Tries to remove a variable named after the *value* |

### How PATH lookup works

When you type `ls`, bash (after checking aliases, functions and builtins) looks through each directory in `PATH`, **left to right**, for a file named `ls` that you're allowed to execute. The first match wins. Bash then remembers the location in a **hash table** (a cache), so the next lookup is instant. `hash -r` clears that cache.

- **Prepending** (`PATH=/my/dir:$PATH`) lets your version override the system's. That's powerful, and dangerous.
- **Never put `.` (the current directory) in PATH**, especially for root. An attacker could leave a fake `ls` in `/tmp` that runs when you type `ls` there.
- `sudo` ignores your PATH and uses its own `secure_path` (topic 028).

### Unset variables are silently empty

`echo "$doesnotexist"` prints an empty line, with no error. That's dangerous in scripts: `rm -rf "$dir/"*` with an empty `dir` becomes `rm -rf /*`. Protect yourself with `set -u` (an unset variable becomes an error, topic 014) or `${dir:?}` (below).

## Commands

```bash
count=500
mydir="/opt/my folder"
echo "$count items in $mydir"
```
```
500 items in /opt/my folder
```

```bash
echo "${count}kg"     # braces mark where the name ends
```
```
500kg
```
- Without braces, `$countkg` would look for a variable named `countkg`.

```bash
export GREETING=hello
bash                       # start a CHILD shell
echo $GREETING             # hello   (inherited copy)
GREETING=changed ; exit    # change the copy, leave the child
echo $GREETING             # hello   (parent unchanged)
```

```bash
env | sort | head -5
```
```
DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
DEBUGINFOD_IMA_CERT_PATH=/etc/keys/ima:
GPG_TTY=/dev/pts/0
HISTCONTROL=ignoredups
HISTSIZE=1000
```
- `env` prints the **environment** (exported variables only). `set` prints everything, including local variables and shell functions.

```bash
printenv HOME ; declare -p PATH
```
```
/home/alice
declare -x PATH="/home/alice/.local/bin:/home/alice/bin:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin"
```
- `declare -p` shows how a variable is defined. `-x` means exported.

```bash
LANG=C date
```
```
Mon Nov 16 20:28:19 UTC 2026
```
- `NAME=value command` sets a variable **for that one command only**. Here it forces English/plain output. (Compare plain `date`, which on RHEL prints `08:28:19 PM` because of `en_US.UTF-8`, topic 004.) This is very handy for scripts that parse output.

```bash
env -i bash -c 'echo "[$HOME] [$PATH]"'
```
```
[] [/usr/local/bin:/usr/bin]
```
- `env -i` starts a program with an **empty** environment. Bash then fills in a short built-in fallback PATH (on RHEL 10 just `/usr/local/bin:/usr/bin`; other builds differ, so never rely on it). Useful to test how a program behaves under cron or systemd, which give a minimal environment.

```bash
readonly PI=3.14 ; PI=3
```
```
bash: PI: readonly variable
```

```bash
unset count ; echo "[$count]"
```
```
[]
```

### Important variables

| Variable | Meaning |
|---|---|
| `HOME` | Your home directory |
| `USER` / `LOGNAME` | Your user name |
| `UID` / `EUID` | Your real / effective user ID number (read-only, topic 022) |
| `PWD` / `OLDPWD` | Current / previous directory (`cd -` uses `OLDPWD`) |
| `PATH` | Where to search for commands |
| `SHELL` | Your login shell from `/etc/passwd`; not necessarily the shell you're in now |
| `HOSTNAME` | Machine name when the shell started |
| `LANG`, `LC_*`, `LC_ALL` | **Locale**: language, sort order, character set (topic 013) |
| `EDITOR` / `VISUAL` | The editor `crontab -e`, `visudo`, `git` and `kubectl edit` open |
| `TERM` | Terminal type (topic 003) |
| `TZ` | Time zone override: `TZ=Asia/Kolkata date` |
| `http_proxy`, `https_proxy`, `no_proxy` | Proxy settings many tools read |
| `PS1`–`PS4` | Prompts (below) |
| `IFS` | Internal Field Separator: the characters used for word splitting (space, tab, newline) |

Special parameters:

| Parameter | Meaning |
|---|---|
| `$?` | Exit status of the last command |
| `$$` | PID of the current shell |
| `$!` | PID of the last background job |
| `$0` | Name of the shell or script |
| `$-` | Current shell option letters |

### PATH

```bash
echo "$PATH"
```
```
/home/alice/.local/bin:/home/alice/bin:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin
```
- Colon-separated directories, searched left to right. RHEL's default `~/.bashrc` adds `~/.local/bin` and `~/bin`. Putting your own scripts in `~/bin` is the easy way to make them runnable by name.

```bash
PATH="$PATH:$HOME/scripts"     # append: system commands still win
PATH="$HOME/scripts:$PATH"     # prepend: your versions win ⚠️
hash -r                        # forget cached command locations
```

### Prompt variables

| Variable | Shown when | RHEL default |
|---|---|---|
| `PS1` | Normal prompt | `[\u@\h \W]\$ ` |
| `PS2` | Command not finished (open quote, trailing `\`) | `> ` |
| `PS3` | `select` menus in scripts | `#? ` |
| `PS4` | Prefix of `set -x` trace lines (topic 014) | `+ ` |
| `PS0` | After Enter, before the command runs (bash ≥ 4.4) | unset |

```bash
PS1='[\u@\h \w]\$ '                         # show the full path
PS1='\[\e[1;31m\][\u@\h \W]\$\[\e[0m\] '    # red prompt: good for production hosts
```
- `\e[1;31m` is a colour code. Wrap colour codes in `\[ … \]` so bash knows they take no space. Otherwise long lines wrap badly.

### Parameter expansion (tricks you'll use in scripts)

```bash
file=/var/log/app/server.log
echo "${file##*/}"      # server.log         (remove the longest match of "*/" from the start → basename)
echo "${file%/*}"       # /var/log/app       (remove the shortest match of "/*" from the end → dirname)
echo "${file%.log}.gz"  # /var/log/app/server.gz
echo "${#file}"         # 23                 (length)
echo "${file//log/LOG}" # /var/LOG/app/server.LOG   (replace all)
name=Alice; echo "${name^^} ${name,,}"   # ALICE alice
echo "${PORT:-8080}"    # 8080 if PORT is unset or empty (PORT unchanged)
echo "${PORT:=8080}"    # same, and also sets PORT=8080
rm -rf "${dir:?dir is empty}/"*          # STOP with an error if dir is empty
```

### Positional parameters (preview, full detail in topic 041)

| Parameter | Meaning |
|---|---|
| `$1` … `$9`, `${10}` | The arguments. Braces are needed from 10 up |
| `$#` | How many arguments |
| `"$@"` | All arguments, **each kept separate**. Use this almost always |
| `"$*"` | All arguments joined into **one** string |
| `shift` | Drop `$1`; everything moves down one |
| `set -- a b c` | Set the positional parameters by hand (good for practice) |

```bash
set -- "a b" c ; echo "$# | $1 | $2"
```
```
2 | a b | c
```

### Making it permanent

Variables set at the prompt vanish when you log out. To keep them:
- For you only: add `export EDITOR=vim` to `~/.bashrc`.
- For all users: create `/etc/profile.d/custom.sh`.
- Apply now without logging out: `source ~/.bashrc`.

Topic 025 explains exactly which file runs when.

### Try it
1. `x=1; bash -c 'echo "child sees: [$x]"'`, then `export x`, then repeat. What changed?
2. Write a 2-line script `setx.sh` containing `y=5`. Run `bash setx.sh; echo $y`, then `source setx.sh; echo $y`.
3. `file=/etc/ssh/sshd_config` — print just `sshd_config` and just `/etc/ssh` using parameter expansion.
4. Break your PATH on purpose (`PATH=/nope`), try `ls`, then fix it with `PATH=/usr/local/bin:/usr/bin:/usr/sbin`.

## Where you'll use it

- **Containers and Kubernetes:** apps get config through environment variables (`env:` in a pod spec, `-e` in `docker run`, `.env` files). "It works locally but not in the container" is often a missing variable. `kubectl exec pod -- env` or `cat /proc/1/environ | tr '\0' '\n'` shows what it really got.
- **CI/CD pipelines** pass secrets and settings as environment variables.
- **cron and systemd** run jobs with a **tiny environment** (often a short PATH, no `LANG`). That's the #1 reason "the script works by hand but not from cron" (topic 039). Use full paths or set PATH at the top of the script.
- **Proxies:** corporate networks need `https_proxy` and `no_proxy` exported for `curl`, `dnf` and `pip`.
- **Safety:** `${var:?}` before any `rm -rf` on a path built from a variable.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `count: command not found` when assigning | Spaces around `=` | `count=500` |
| A program or child shell doesn't see the variable | Not exported | `export var` |
| A variable set in a script is gone afterwards | The script ran in a child process | `source script.sh` |
| Every command is "not found" | PATH was overwritten (e.g. `PATH=/my/dir`) | `export PATH=/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin`, then fix the rc file |
| An old copy of a program still runs after you moved it | bash's command cache | `hash -r` |
| Prompt overwrites itself on long lines | Colour codes not wrapped in `\[ \]` | Wrap them |
| `$10` prints the first argument followed by `0` | Parsed as `$1` + `0` | `${10}` |
| Script works in your terminal but not in cron | cron's minimal PATH/environment | Full paths, or set `PATH=` at the top |

## Quick recap

- `name=value` (no spaces) makes a local variable. `export` makes it an environment variable, copied to child processes. Copies flow one way, parent → child.
- `env` shows the environment; `set` shows everything. `VAR=x cmd` sets a variable for one command only.
- PATH is searched left to right. Never add `.`. `hash -r` after moving programs.
- Quote expansions (`"$var"`). Use `${var:-default}` and `${var:?error}` for safe scripts.

**Interview questions**

1. *Shell variable vs environment variable?* An environment variable is a shell variable that has been exported; it is copied into the environment of every child process. A plain shell variable stays inside the current shell.
2. *Can a script change the parent shell's variables?* No. It runs as a child with a copy of the environment. Use `source script.sh` to run it in the current shell.
3. *Why shouldn't `.` be in PATH?* Command hijacking: a malicious program named like a common command in the current directory (e.g. `/tmp/ls`) would run instead of the real one.
