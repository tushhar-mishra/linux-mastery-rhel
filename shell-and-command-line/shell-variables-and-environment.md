# Shell Variables, Environment & Positional Parameters

> **Sessions:** S12 (variables, PS0–PS4), S13 (positional parameters, supplemented) · **Objective:** *Process script inputs ($1, $2, etc.)* **[RHCSA Core]**
> **Related:** [Quoting](quoting-and-control-operators.md) · [Command substitution & options](command-substitution-and-shell-options.md) · [Shell basics (prompt)](shell-basics-and-command-syntax.md#24-the-prompt) · [History](command-history.md) · Profile files (S23) · Scripting (S85–92)

## 1. Overview

A variable is a named value held by the shell. **Shell (local) variables** exist only in the current shell. **Environment variables** are shell variables that have been **exported**, so they're copied to every child process. `PATH`, `HOME`, `LANG` and the prompt variables control how the shell and programs behave. Positional parameters (`$1`, `$2`, …) carry a script's arguments.

> ⚠️ **Course correction:** The real distinction isn't "system-defined vs user-defined." It's **local vs exported**. `PS1` and `HISTSIZE` are set by the system but are shell variables; any user variable becomes an environment variable once exported.

## 2. Key Concepts

### 2.1 Local vs environment

| | Shell (local) variable | Environment variable |
|---|---|---|
| Created by | `name=value` | `export name=value` (or `export name`) |
| Seen by child processes | No | Yes (a **copy**) |
| Listed by | `set`, `declare -p` | `env`, `printenv`, `export -p` |
| Example | `PS1`, `HISTSIZE`, `count=500` | `PATH`, `HOME`, `LANG`, `USER` |

Inheritance is **one-way and by copy**: parent → child. A child can never change its parent's variables.

```bash
export var5=five
bash                      # start a CHILD shell
echo $var5                # five   (inherited)
var5=changed; exit        # change it in the child, return
echo $var5                # five   (parent unchanged)
```

> ⚠️ **Course correction:** The course's demo omits starting a child `bash`. Without it, `exit` logs you out.

### 2.2 Defining and using variables

```bash
count=500                     # NO spaces around =
mydir="/opt/my folder"        # quote values with spaces
echo "$count $mydir"          # $ is the EXPANSION operator, not part of the name
echo "${pre}man"              # braces delimit the name (Superman)
declare var1=33               # same as var1=33
declare -i n=5; n+=2          # integer attribute → 7
readonly PI=3.14              # or declare -r; can't be changed or unset
unset mydir                   # remove (no $)
declare -p count              # show definition and attributes
```

- Names: letters, digits, underscore; can't start with a digit; case-sensitive.
- Convention: UPPERCASE for environment and system variables, lowercase for your own.

| Mistake | Result |
|---|---|
| `count = 500` | `count: command not found` (runs a command named `count`) |
| `$count=500` | Expands `$count` first, then tries to run the result |
| `unset $count` | Tries to unset a variable named after the *value* |

### 2.3 Listing and inspecting

```bash
set | less                 # all shell variables AND functions
set | grep -E '^(count|mydir)='
declare -p PATH            # declare -x PATH="…"   (-x = exported)
env | sort | less          # environment only
printenv HOME              # one variable from the environment
export -p | head           # exported variables as declare -x lines
echo $-                    # current shell option letters (see options note)
```

### 2.4 Per-command environment and clean environments

```bash
LANG=C ls                       # set LANG for this ONE command only
env LANG=C bash -c 'locale'     # same, via env
env -i bash -c 'echo "[$HOME] [$SHELL]"'   # empty environment: [] [/bin/bash] (bash sets SHELL itself)
env -u LANG cmd                 # run cmd with LANG removed
export -n var                   # un-export but keep the local variable
```

### 2.5 Unset variables and `set -u`

```bash
echo "[$undefined]"     # []  ← an unset variable silently expands to empty
set -u                  # nounset: referencing an unset variable is an error
echo "$undefined"       # bash: undefined: unbound variable
echo "${undefined:-}"   # safe with set -u: explicit empty default
set +u
```

> ⚠️ **Course correction (S12 practice Q8):** `echo "$mydir"` after `unset` prints an **empty line**. You only get an error with `set -u`.

## 3. Important Variables

| Variable | Meaning | Example |
|---|---|---|
| `HOME` | Home directory | `/home/alice` |
| `USER` / `LOGNAME` | Username | `alice` |
| `UID` / `EUID` | Real / effective user ID (read-only) | `1000` |
| `PWD` / `OLDPWD` | Current / previous directory | used by `cd -` |
| `PATH` | Search path for commands | see §4 |
| `SHELL` | Login shell from `/etc/passwd` (not necessarily the current shell) | `/bin/bash` |
| `HOSTNAME` | Host name at shell start | `servera.lab.example.com` |
| `LANG` / `LC_*` / `LC_ALL` | Locale (see [globbing note](shell-expansion-and-globbing.md#6-locale-lang-and-pattern-matching)) | `en_US.UTF-8` |
| `EDITOR` / `VISUAL` | Default editor for `crontab -e`, `visudo`, … | `vim` |
| `PS0`–`PS4` | Prompts (§5) | |
| `HISTSIZE`, `HISTFILE`, … | History settings ([history note](command-history.md)) | |
| `IFS` | Word-splitting characters (space, tab, newline) | |
| `$$` / `$!` / `$?` / `$-` / `$0` | Current shell PID / last background PID / last exit status / option flags / shell or script name | |

## 4. `PATH` **[RHCSA Core]**

```bash
echo "$PATH"
# e.g. /home/alice/.local/bin:/home/alice/bin:/usr/local/bin:/usr/bin:…
PATH="$PATH:$HOME/scripts"        # append (current shell only)
PATH="$HOME/scripts:$PATH"        # prepend: takes priority over system commands ⚠️
hash -r                           # forget cached command locations after changes
```

- RHEL's default `~/.bashrc` (from `/etc/skel`) adds `~/.local/bin` and `~/bin` to `PATH` when they exist in the expected form. Putting personal scripts in `~/bin` is the simplest approach. Check with `echo $PATH` on your system.
- **Never** add `.` (the current directory) to `PATH`, especially for root. A malicious `ls` in `/tmp` would run when you type `ls` there.
- Remove an entry: `PATH=$(printf '%s' "$PATH" | sed 's|:/usr/games||')`.
- `sudo` uses its own `secure_path` from `/etc/sudoers`, not your `PATH`.

> ⚠️ **Course correction:** `/usr/local/games:/usr/games` is a Debian/Ubuntu PATH; RHEL doesn't include those directories.

## 5. Prompt Variables PS0–PS4

| Variable | When shown | Default on RHEL |
|---|---|---|
| `PS0` | After you press Enter, **before** the command runs (bash ≥ 4.4) | Unset |
| `PS1` | Primary prompt | `[\u@\h \W]\$ ` |
| `PS2` | Continuation prompt (unfinished command) | `> ` |
| `PS3` | Prompt used by `select` menus | `#? ` when unset |
| `PS4` | Prefix for `set -x` trace lines (first character repeated per nesting level) | `+ ` |

```bash
PS0='[started \t]\n'                       # timestamp every command as it starts
PS1='[\u@\h \w]\$ '                        # full path in prompt
PS1='\[\e[1;31m\][\u@\h \W]\$\[\e[0m\] '   # red prompt; \[ \] wrap NON-printing codes
PS2='...> '
PS4='+ ${BASH_SOURCE}:${LINENO}: '         # [Advanced] file:line in xtrace output
```

- Wrap color codes in `\[ … \]`, or bash miscounts the prompt length and line editing wraps badly.
- PS1 escapes are listed in the [shell basics note](shell-basics-and-command-syntax.md#24-the-prompt).

`select` with `PS3` (scripting preview):

```bash
#!/bin/bash
PS3="Choose a fruit: "
select fruit in Apple Mango Banana Exit; do
    echo "You selected: $fruit"
    [ "$fruit" = "Exit" ] && break
done
```

> ⚠️ **Course corrections:**
> - PS0 *is* a supported bash feature (since 4.4), not "non-standard/unsupported."
> - PS3's default is `#? `, not `>`.
> - In `[ ]` the POSIX comparison operator is `=`; `==` is a bash extension.

## 6. Positional Parameters **[RHCSA Core]**

*Supplemented (not in course material). Full scripting in S85–92.*

| Parameter | Meaning |
|---|---|
| `$0` | Script name (or the shell's name) |
| `$1` … `$9`, `${10}` | Arguments. Braces are **required** from 10 up |
| `$#` | Number of arguments |
| `"$@"` | All arguments, **each kept as a separate word**. Use this almost always |
| `"$*"` | All arguments joined into **one** string (first character of `IFS`, normally a space) |
| `shift [n]` | Drop the first n arguments; `$2` becomes `$1` |
| `set -- a b c` | Replace the positional parameters in the current shell |

Demo script `args.sh`:

```bash
#!/bin/bash
echo "Script: $0   Count: $#"
echo "First: ${1:-<none>}   Second: ${2:-<none>}"
printf '"$@" → [%s]\n' "$@"
printf '"$*" → [%s]\n' "$*"
```

```bash
$ chmod +x args.sh; ./args.sh "a b" c
Script: ./args.sh   Count: 2
First: a b   Second: c
"$@" → [a b]
"$@" → [c]
"$*" → [a b c]
```

Common patterns:

```bash
[ "$#" -lt 1 ] && { echo "Usage: $0 <username>" >&2; exit 1; }   # require an argument
for arg in "$@"; do echo "Processing: $arg"; done                # loop over all args
while [ "$#" -gt 0 ]; do echo "$1"; shift; done                  # consume one at a time
set -- one two three; echo "$2 / $#"                             # two / 3 (interactive practice)
```

## 7. Making Variables Persistent

| Scope | File | Notes |
|---|---|---|
| One user, interactive shells | `~/.bashrc` | Aliases, functions, PS1, HISTSIZE |
| One user, login environment | `~/.bash_profile` | On RHEL it sources `~/.bashrc` |
| All users | `/etc/profile.d/custom.sh` | Preferred over editing `/etc/profile` or `/etc/bashrc` |

```bash
echo 'export EDITOR=vim' >> ~/.bashrc
source ~/.bashrc          # or: . ~/.bashrc   (apply to the current shell)
```

Full startup-file order (login vs non-login) is in S23.

## 8. Parameter Expansion **[Advanced, used in scripting]**

| Syntax | Result |
|---|---|
| `${var:-default}` | `default` if var is unset or empty (var unchanged) |
| `${var:=default}` | Same, and **assign** it |
| `${var:?message}` | Exit with `message` if unset or empty (script safety) |
| `${#var}` | Length |
| `${var#prefix}` / `${var##prefix}` | Remove the shortest / longest match from the start |
| `${var%suffix}` / `${var%%suffix}` | Remove from the end: `${file%.txt}` |
| `${var/old/new}` / `${var//old/new}` | Replace first / all |
| `${var^^}` / `${var,,}` | Uppercase / lowercase |

## 9. RHCSA Exam Focus

- Scripts: read input with `$1`, `$2`, `$#` and `"$@"`; validate the argument count; quote every expansion.
- Persist user settings in `~/.bashrc`; reload with `source ~/.bashrc`.
- Don't break `PATH`. If commands vanish, run `export PATH=/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin`, then fix the rc file.

## 10. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `count: command not found` | Spaces around `=` | `count=500` |
| Variable empty in a script or child | Not exported | `export var` |
| Variable set in a script missing afterwards | Script runs in a child process | `source script.sh` to run it in the current shell |
| Every command "not found" | `PATH` overwritten (`PATH=/my/dir`) | Restore `PATH`; fix the rc file |
| Old binary still runs after moving it | Hash cache | `hash -r` |
| Prompt wraps and overwrites itself | Color codes not wrapped in `\[ \]` | Wrap them |
| `${10}` prints `$1` followed by `0` | `$10` parsed as `$1` + `0` | Use `${10}` |

## 11. Interview Questions

| Question | Answer |
|---|---|
| Shell vs environment variable? | Environment variables are exported shell variables, copied to child processes. |
| Can a child process change its parent's variables? | No. Inheritance is by copy, one-way. Use `source` to run a script in the current shell. |
| `"$@"` vs `"$*"`? | `"$@"` preserves each argument separately; `"$*"` joins them into one string. |
| `set` vs `env`? | `set` shows all shell variables and functions; `env` shows only the environment. |
| Why not put `.` in PATH? | Command hijacking: you could run a malicious binary from the current directory. |
| What does `${var:?msg}` do? | Aborts with `msg` if `var` is unset or empty, guarding against things like `rm -rf "$dir/"*` with an empty `dir`. |

## 12. Course Practice (S12, corrected where needed)

| # | Task | Command |
|---|---|---|
| 1–2 | Create variables | `count=500` · `mydir=/opt/myfolder` |
| 3–4 | Print on one line / with six spaces | `echo "$count $mydir"` · `echo "$count      $mydir"` |
| 5 | Show `$count=500` | `echo "\$count=$count"` |
| 6 | Find them with `set` | `set \| grep -E '^(count\|mydir)='` |
| 7–8 | Delete; get an error on use | `unset mydir` · `set -u; echo "$mydir"` → *unbound variable* |
| 9 | Remove an entry from PATH | `PATH=$(printf '%s' "$PATH" \| sed 's\|:/usr/games\|\|')` |
| 10 | Persist across logins | Add to `~/.bashrc` |

## 13. Quick Revision

```bash
var=value | "$var" | ${var}x | export var | unset var | readonly var | declare -p var
set | env | printenv VAR | VAR=x cmd | env -i bash
PATH="$PATH:$HOME/bin" | hash -r | source ~/.bashrc
$0 $1 ${10} $# "$@" "$*" shift  set --
PS0 PS1 PS2 PS3('#? ') PS4('+ ')   \[ \] around colors
```

## 14. Cross-References

- [Quoting & control operators](quoting-and-control-operators.md)
- [Command substitution & shell options (`set -u`, `set -a`)](command-substitution-and-shell-options.md)
- [Command history (HIST* variables)](command-history.md)
- [Expansion & globbing (locale)](shell-expansion-and-globbing.md)
- [Profile files](../users-groups-and-permissions/shell-startup-files.md) · [Scripting](../bash-scripting-and-automation/script-basics-and-variables.md)
