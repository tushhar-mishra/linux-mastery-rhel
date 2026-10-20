# Shell Variables, Environment & Positional Parameters

> **Sessions:** S12 (variables, PS0–PS4), S13 (positional parameters, supplemented) · **Objective:** *Process script inputs ($1, $2, etc.)* **[RHCSA Core]**
> **Related:** [Quoting](quoting-and-control-operators.md) · [Command substitution & options](command-substitution-and-shell-options.md) · [Shell basics (prompt)](shell-basics-and-command-syntax.md#24-the-prompt) · Profile files (S23) · Scripting (S85–92)

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

```````bash
export var5=five
bash                      # start a CHILD shell
echo $var5                # five   (inherited)
var5=changed; exit        # change it in the child, return
echo $var5                # five   (parent unchanged)
```````

> ⚠️ **Course correction:** The course's demo omits starting a child `bash`. Without it, `exit` logs you out.

### 2.2 Defining and using variables

```````bash
count=500                     # NO spaces around =
mydir="/opt/my folder"        # quote values with spaces
echo "$count $mydir"          # $ is the EXPANSION operator, not part of the name
echo "${pre}man"              # braces delimit the name (Superman)
declare var1=33               # same as var1=33
declare -i n=5; n+=2          # integer attribute → 7
readonly PI=3.14              # or declare -r; can't be changed or unset
unset mydir                   # remove (no $)
declare -p count              # show definition and attributes
```````

- Names: letters, digits, underscore; can't start with a digit; case-sensitive.
- Convention: UPPERCASE for environment and system variables, lowercase for your own.

| Mistake | Result |
|---|---|
| `count = 500` | `count: command not found` (runs a command named `count`) |
| `$count=500` | Expands `$count` first, then tries to run the result |
| `unset $count` | Tries to unset a variable named after the *value* |

### 2.3 Listing and inspecting

```````bash
set | less                 # all shell variables AND functions
set | grep -E '^(count|mydir)='
declare -p PATH            # declare -x PATH="…"   (-x = exported)
env | sort | less          # environment only
printenv HOME              # one variable from the environment
export -p | head           # exported variables as declare -x lines
echo $-                    # current shell option letters (see options note)
```````

### 2.4 Per-command environment and clean environments

```````bash
LANG=C ls                       # set LANG for this ONE command only
env LANG=C bash -c 'locale'     # same, via env
env -i bash -c 'echo "[$HOME] [$SHELL]"'   # empty environment: [] [/bin/bash] (bash sets SHELL itself)
env -u LANG cmd                 # run cmd with LANG removed
export -n var                   # un-export but keep the local variable
```````

### 2.5 Unset variables and `set -u`

```````bash
echo "[$undefined]"     # []  ← an unset variable silently expands to empty
set -u                  # nounset: referencing an unset variable is an error
echo "$undefined"       # bash: undefined: unbound variable
echo "${undefined:-}"   # safe with set -u: explicit empty default
set +u
```````

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

```````bash
echo "$PATH"
# e.g. /home/alice/.local/bin:/home/alice/bin:/usr/local/bin:/usr/bin:…
PATH="$PATH:$HOME/scripts"        # append (current shell only)
PATH="$HOME/scripts:$PATH"        # prepend: takes priority over system commands ⚠️
hash -r                           # forget cached command locations after changes
```````

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

```````bash
PS0='[started \t]\n'                       # timestamp every command as it starts
PS1='[\u@\h \w]\$ '                        # full path in prompt
PS1='\[\e[1;31m\][\u@\h \W]\$\[\e[0m\] '   # red prompt; \[ \] wrap NON-printing codes
PS2='...> '
PS4='+ ${BASH_SOURCE}:${LINENO}: '         # [Advanced] file:line in xtrace output
```````

- Wrap color codes in `\[ … \]`, or bash miscounts the prompt length and line editing wraps badly.
- PS1 escapes are listed in the [shell basics note](shell-basics-and-command-syntax.md#24-the-prompt).

`select` with `PS3` (scripting preview):

```````bash
#!/bin/bash
PS3="Choose a fruit: "
select fruit in Apple Mango Banana Exit; do
    echo "You selected: $fruit"
    [ "$fruit" = "Exit" ] && break
done
```````

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

```````bash
#!/bin/bash
echo "Script: $0   Count: $#"
echo "First: ${1:-<none>}   Second: ${2:-<none>}"
printf '"$@" → [%s]\n' "$@"
printf '"$*" → [%s]\n' "$*"
```````

```````bash
$ chmod +x args.sh; ./args.sh "a b" c
Script: ./args.sh   Count: 2
First: a b   Second: c
"$@" → [a b]
"$@" → [c]
"$*" → [a b c]
```````

Common patterns:

```````bash
[ "$#" -lt 1 ] && { echo "Usage: $0 <username>" >&2; exit 1; }   # require an argument
for arg in "$@"; do echo "Processing: $arg"; done                # loop over all args
while [ "$#" -gt 0 ]; do echo "$1"; shift; done                  # consume one at a time
set -- one two three; echo "$2 / $#"                             # two / 3 (interactive practice)
```````

## 7. Making Variables Persistent

| Scope | File | Notes |
|---|---|---|
| One user, interactive shells | `~/.bashrc` | Aliases, functions, PS1, HISTSIZE |
| One user, login environment | `~/.bash_profile` | On RHEL it sources `~/.bashrc` |
| All users | `/etc/profile.d/custom.sh` | Preferred over editing `/etc/profile` or `/etc/bashrc` |

```````bash
echo 'export EDITOR=vim' >> ~/.bashrc
source ~/.bashrc          # or: . ~/.bashrc   (apply to the current shell)
```````

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

```````bash
var=value | "$var" | ${var}x | export var | unset var | readonly var | declare -p var
set | env | printenv VAR | VAR=x cmd | env -i bash
PATH="$PATH:$HOME/bin" | hash -r | source ~/.bashrc
$0 $1 ${10} $# "$@" "$*" shift  set --
PS0 PS1 PS2 PS3('#? ') PS4('+ ')   \[ \] around colors
```````

---

### 3. `shell-and-command-line/command-substitution-and-shell-options.md`

```````markdown
# Command Substitution, Subshells & Shell Options

> **Sessions:** S14 ("shell embedding" and options) · **Objective:** *Processing output of shell commands within a script* **[RHCSA Core]**
> **Related:** [Variables](shell-variables-and-environment.md) · [Quoting & control operators](quoting-and-control-operators.md) · [Expansion & globbing](shell-expansion-and-globbing.md) · Scripting (S85–92)

## 1. Overview

**Command substitution**, which the course calls "shell embedding," runs a command in a **subshell** and replaces `$(…)` with its output. It's how scripts capture command output into variables and arguments. **Shell options** (`set`, `shopt`) change how bash behaves: error handling, globbing, tracing, history.

## 2. Subshells **[Interview Knowledge]**

A subshell is a **fork** of the current shell: it gets a copy of *all* variables, including non-exported ones, but nothing it changes flows back.

| Construct | New process? | Sees non-exported variables? | Changes persist? |
|---|---|---|---|
| `{ cmds; }` | No (current shell) | Yes | **Yes** |
| `( cmds )` | Subshell (fork) | **Yes** | No |
| `$( cmds )` | Subshell (fork) | **Yes** | No; only the output is returned |
| `bash -c 'cmds'` | New bash program | **No** (only exported) | No |
| `./script.sh` | New bash program | No (only exported) | No |
| `source script.sh` | No (current shell) | Yes | **Yes** |

``````bash
x=5
( echo "$x" )             # 5   (subshell is a fork)
bash -c 'echo "[$x]"'     # []  (new process sees only exported variables)
echo $(myvar=6; echo $myvar); echo "[$myvar]"   # 6  then []
(cd /etc && ls) ; pwd     # your directory is unchanged
``````

## 3. Command Substitution **[RHCSA Core]**

``````bash
today=$(date +%F)                         # capture output in a variable
cp -a /etc/hosts /etc/hosts.$(date +%F)   # dated backup
echo "Kernel: $(uname -r)"
users=$(wc -l < /etc/passwd)              # count (number only)
ls -l "$(type -P grep)"                   # long listing of the grep binary
file=$(< /etc/hostname)                   # bash shortcut for $(cat file)
``````

**Rules:**

- **Trailing newlines are stripped.** Internal newlines survive only if you **quote**: `echo "$(ls)"` keeps line breaks, `echo $(ls)` puts everything on one line.
- **Quote substitutions** used as arguments: `"$(cmd)"`. Otherwise word splitting and globbing apply to the output.
- **Nesting:** `$(dirname "$(readlink -f /usr/bin/python3)")`.

**Backticks** `` `cmd` `` are the legacy form. They nest only with escaped inner backticks and are easy to confuse with single quotes. Prefer `$( )`.

``````bash
echo `myvar=10; echo $myvar`     # 10   (command substitution)
echo 'myvar=10; echo $myvar'     # myvar=10; echo $myvar   (literal text)
``````

**Processing output in scripts** (exam objective preview):

``````bash
for u in $(awk -F: '$3>=1000 {print $1}' /etc/passwd); do   # fine for simple, space-free words
    echo "Regular user: $u"
done

while IFS= read -r line; do         # robust: one line at a time, spaces preserved
    echo "Line: $line"
done < /etc/hosts
``````

## 4. Shell Options with `set`

``````bash
echo $-          # active single-letter flags, e.g. himBHs (interactive bash)
set -o           # all options with on/off state
set -o nounset   # enable by name   |  set +o nounset  # disable
set -u           # enable by letter |  set +u          # disable
``````

| Flag | Name | Effect | Notes |
|---|---|---|---|
| `-a` | allexport | Export every variable you assign | Useful when sourcing env files |
| `-b` | notify | Report finished background jobs immediately | |
| `-e` | errexit | Exit when a command fails | Caveats below ⚠️ |
| `-f` | noglob | Disable filename globbing | `echo *` prints `*` |
| `-h` | hashall | Remember command paths (`hash`) | On by default; `hash -r` resets |
| `-m` | monitor | Job control | **On** in interactive shells, **off** in scripts; `set -m` enables it in scripts |
| `-n` | noexec | Read commands but don't execute (**syntax check only**) | Ignored in interactive shells; use `bash -n script` |
| `-u` | nounset | Unset variables are errors | |
| `-v` | verbose | Print input lines **as read** (unexpanded) | |
| `-x` | xtrace | Print each command **after expansion**, prefixed with `PS4` | Main debugging tool |
| `-C` | noclobber | `>` won't overwrite existing files; `>\|` forces it | |
| `-H` | histexpand | `!` history expansion | `set +H` disables |
| `-B` | braceexpand | Brace expansion | On by default |
| — | pipefail (`set -o pipefail`) | A pipeline fails if **any** command in it fails | Not a single letter |
| `-p` | privileged | Don't read `$ENV` or import functions | Rarely used |
| `-t` | onecmd | Exit after one command | ⚠️ see below |

### 4.1 `set -e` caveats **[Production Practice]**

`errexit` does **not** trigger for:

- commands in `if`/`while`/`until` conditions;
- any command in an `&&`/`||` list except the last;
- commands negated with `!`;
- non-final pipeline commands, unless `set -o pipefail` is also set.

Common script header **[Advanced]**:

``````bash
#!/bin/bash
set -euo pipefail     # stop on errors, unset variables, and failures inside pipelines
``````

Understand the caveats before relying on it.

> ⚠️ **Never put `set -e`, `set -n` or `set -t` in `~/.bashrc`.**
> - `set -e`: the first failing command closes your shell.
> - `set -t`: every new shell exits after one command.
>
> Either can effectively lock you out of usable logins. Test these options in a child `bash` or in a script, not your login shell.

### 4.2 Debugging scripts

``````bash
bash -n script.sh            # syntax check only: catches missing fi/done/quotes
bash -x script.sh            # trace the whole script
set -x; risky_part; set +x   # trace one section
PS4='+ ${LINENO}: '          # add line numbers to the trace
``````

`bash -n` does **not** catch runtime errors (division by zero, missing files).

> ⚠️ **Course correction:** The `set -n` example uses `$((5/0))`, which is a runtime error, so `-n` won't report it. Use a real syntax error, such as an `if` without `fi`.

## 5. `shopt` (bash-specific options)

``````bash
shopt                       # list all with on/off
shopt -s dotglob            # set (enable)  |  shopt -u dotglob  # unset (disable)
shopt -q nocaseglob && echo on || echo off
shopt -p histappend         # print as a reusable command
``````

| Option | Effect |
|---|---|
| `histappend` | Append to `HISTFILE` instead of overwriting ([history](command-history.md)) |
| `dotglob` | `*` also matches hidden files |
| `nullglob` / `failglob` | A non-matching glob expands to nothing / causes an error |
| `nocaseglob` | Case-insensitive globbing |
| `globstar` | `**` matches recursively **[Advanced]** |
| `extglob` | Extended patterns `!(…)`, `@(…)`, `+(…)` **[Advanced]** |
| `expand_aliases` | Allow aliases in non-interactive shells |
| `checkwinsize` | Update `LINES`/`COLUMNS` after each command |

Persist chosen options in `~/.bashrc`.

## 6. RHCSA Exam Focus

- Use `$( )` to put command output into variables or arguments, and quote it: `"$(cmd)"`.
- Debug scripts with `bash -x script.sh`. Verify syntax with `bash -n` before running.
- Know that `set -o`/`echo $-` show options and `set -x`/`+x` toggle tracing.

## 7. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Terminal closes after a failed command | `set -e` in an interactive shell or rc file | Remove it from rc files; test in `bash` |
| `cannot overwrite existing file` | `noclobber` set | `>\|` or `set +C` |
| `*` prints literally | `set -f` | `set +f` |
| `unbound variable` | `set -u` with an unset variable | Set it or use `${var:-}` |
| Script appears to do nothing | `set -n` left in the script | Remove it |
| Moved binary: "No such file or directory" | Stale hash entry | `hash -r` |
| `$(cmd)` output on one line | Unquoted substitution | `"$(cmd)"` |

## 8. Interview Questions

| Question | Answer |
|---|---|
| What is command substitution? | `$(cmd)` runs `cmd` in a subshell and substitutes its output, minus trailing newlines. |
| `$( )` vs backticks? | Same function. `$( )` nests cleanly and is readable; backticks are legacy. |
| Does `( )` see non-exported variables? | Yes, it's a fork. `bash -c` doesn't, because it's a new program that gets only the environment. |
| `set -v` vs `set -x`? | `-v` prints input as read; `-x` prints the expanded command about to run. |
| Why isn't `set -e` enough for safety? | It's ignored in conditions, `&&`/`\|\|` lists and pipelines (without `pipefail`). |
| How do you syntax-check a script? | `bash -n script.sh`. |

## 9. Course Practice (S14, corrected)

| # | Task | Correct answer / note |
|---|---|---|
| 1 | `set -e` vs `set -o errexit` | Identical (letter vs name) |
| 2 | Test errexit | Run `bash` first, then `set -e; ls /nonexistent`. The **child** shell exits, not your login |
| 4 | Run `cd /etc; ls` in an embedded shell | `echo $(cd /etc; ls)`, or `(cd /etc; ls)`. Wrapping `bash -c` in `( )` is redundant |
| 5 | Variable in an embedded shell | `echo $(tempvar=hi; echo $tempvar); echo "[$tempvar]"` → `hi` then `[]` |
| 6 | What `set -v` does | Prints input lines as read (unexpanded); useful alongside `-x` |
| 7 | Output `AlphaBetaGamma` | `echo -n Alpha; echo -n Beta; echo Gamma` (the course's `{ …; }` answer prints `Alpha⏎BetaGamma`) |
| 8 | `ls -l` of `grep` via substitution | `ls -l "$(type -P grep)"`. Interactive `which` on RHEL can print alias text too |

## 10. Quick Revision

``````bash
$(cmd)  "$(cmd)"  `legacy`  $(< file)     ( subshell )  { current; }  source file
echo $-  set -o  set -euxv / +…  set -o pipefail  set -C (>|)  set -f  hash -r
bash -n script  bash -x script  PS4
shopt -s/-u/-q  dotglob nullglob nocaseglob globstar extglob histappend
``````

---

### 4. `shell-and-command-line/command-history.md`

``````markdown
# Command History

> **Sessions:** S15 (history) · **Baseline:** RHEL 10, bash 5.x
> **Related:** [Quoting (`!` trap)](quoting-and-control-operators.md#23-the--trap-interactive-shells-only) · [Shell options](command-substitution-and-shell-options.md) · [Shell basics (keys)](shell-basics-and-command-syntax.md#26-time-saving-keys-rhcsa-core)

## 1. Overview

Bash keeps a list of the commands you type, in **memory** during the session, and writes it to **`HISTFILE`** (`~/.bash_history`) when the shell exits. History speeds up repetitive work and helps reconstruct what you did. It is **not** a reliable audit trail.

## 2. How It Works

1. Each command is added to the in-memory list, filtered by `HISTCONTROL` and `HISTIGNORE`; at most `HISTSIZE` entries are kept.
2. On a **clean exit**, the list is written to `HISTFILE`: appended if `histappend` is on, otherwise overwritten. The file is then trimmed to `HISTFILESIZE` lines.
3. A new shell **reads** `HISTFILE` at startup.

Consequences:

- A killed SSH session or crashed terminal can **lose** that session's history.
- With several terminals open and `histappend` off, the last one to exit overwrites the others.
- `history -a` writes immediately.

## 3. Variables & Defaults

| Variable / option | Meaning | Check on your system |
|---|---|---|
| `HISTSIZE` | Max commands kept **in memory** (RHEL `/etc/profile` sets 1000) | `echo $HISTSIZE` |
| `HISTFILESIZE` | Max lines kept **in the file** (defaults to `HISTSIZE` if unset) | `echo $HISTFILESIZE` |
| `HISTFILE` | History file | `~/.bash_history` |
| `HISTCONTROL` | `ignoredups`, `ignorespace`, `ignoreboth`, `erasedups` (RHEL default: **`ignoredups`**) | `echo $HISTCONTROL` |
| `HISTIGNORE` | Patterns never recorded, e.g. `ls:ll:history*` | |
| `HISTTIMEFORMAT` | Show timestamps (`%F %T `) | |
| `shopt histappend` | Append instead of overwrite (RHEL's `/etc/bashrc` typically enables it) | `shopt histappend` |

> ⚠️ **Course correction:** A leading space hides a command **only** if `HISTCONTROL` contains `ignorespace` or `ignoreboth`. RHEL's default is `ignoredups`, so by default spaced commands **are** recorded.

## 4. Recalling & Editing Commands

### 4.1 Event designators

| Syntax | Runs |
|---|---|
| `!!` | Previous command (`sudo !!` reruns it as root) |
| `!n` | Entry number *n* (`!104`) |
| `!-n` | *n*-th previous command (`!-2`) |
| `!string` | Most recent command **starting** with `string` (`!mk`) |
| `!?string?` | Most recent command **containing** `string` |
| `^old^new` | Previous command with the first `old` replaced by `new` |

### 4.2 Words and modifiers

| Syntax | Meaning | Example |
|---|---|---|
| `!$` | Last argument of the previous command (same as `Alt+.`) | `mkdir /srv/app && cd !$` |
| `!^` / `!*` / `!:n` | First / all / n-th argument | `cp !*  /backup/` |
| `:p` | **Print, don't execute** (safety check) | `!rm:p` |
| `:s/old/new/` | Substitute the first occurrence | `!!:s/file1/file2/`, `!c:s/message1/message2/` |
| `:gs/old/new/` | Substitute all occurrences | `!!:gs/dev/prod/` |

> These are **history modifiers**, not regular expressions.

### 4.3 Interactive search

- `Ctrl+R`, then type: reverse-search for the newest match. Press `Ctrl+R` again for older matches.
- `Enter` runs the match; `→`/`Esc` edits it first; `Ctrl+G` cancels.
- `Ctrl+S` searches forward, but terminals often treat it as XOFF and freeze output. Run `stty -ixon` to free it, or press `Ctrl+Q` to unfreeze.
- `shopt -s histverify` makes `!` expansions load into the editing line instead of running immediately. A good safety net.

## 5. Managing History

`````bash
history              # all entries
history 10           # last 10
history -d 100       # delete entry 100 (e.g., a pasted password)
history -c           # clear IN-MEMORY history
history -c && history -w   # clear memory AND overwrite the file with the (now empty) list
history -a           # append this session's new lines to HISTFILE now
history -r           # read HISTFILE into memory
history | grep -w ls # entries containing the word "ls"
fc -l -5             # list the last 5 (POSIX alternative)
fc                   # edit the last command in $EDITOR, then run it
set +o history       # stop recording for this session  |  set -o history  # resume
unset HISTFILE       # this session won't be saved at exit
`````

> ⚠️ **Course correction:** `> ~/.bash_history` alone doesn't erase history. The in-memory list is written back at exit. Use `history -c && history -w`.

## 6. Persistent Configuration (`~/.bashrc`)

`````bash
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth                 # skip duplicates and space-prefixed commands
HISTIGNORE='ls:ll:history*:clear'
HISTTIMEFORMAT='%F %T '
shopt -s histappend
PROMPT_COMMAND="history -a${PROMPT_COMMAND:+; $PROMPT_COMMAND}"   # [Advanced] save after every command
`````

- Apply with `source ~/.bashrc`.
- Timestamps are saved (as `#epoch` comment lines) only for commands recorded **after** `HISTTIMEFORMAT` is set. Older entries all show the same time.

## 7. Security **[Production Practice]**

- **Secrets end up in history.** Avoid passwords on the command line (`mysql -pSecret`, `curl -u user:pass`). Use prompts, files with mode 600, or environment files. If one slips in, run `history -d N`, then `history -w`.
- Shell history is **user-controlled** (it can be disabled, edited or deleted), so it's not an audit control. Use `auditd`, `sudo` logging (`/var/log/secure`) or session recording (tlog) for accountability **[Advanced]**.
- `~/.bash_history` is created with mode `600`; keep it that way.

## 8. RHCSA Exam Focus

- Speed: `Ctrl+R`, `!$`/`Alt+.`, `^old^new` and `sudo !!` save real time.
- Safety: preview risky recalls with `:p` (`!rm:p`) before executing.
- History doesn't help the grader; only the final system state counts.

## 9. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Commands missing after reconnect | Session killed before a clean exit | `history -a` / `PROMPT_COMMAND` (§6) |
| Terminals overwrite each other's history | `histappend` off | `shopt -s histappend` |
| A space-prefixed command still recorded | `HISTCONTROL=ignoredups` | `ignoreboth` |
| `event not found` | `!` inside double quotes | Single quotes, `\!`, or `set +H` |
| Terminal froze after `Ctrl+S` | XOFF flow control | `Ctrl+Q`; `stty -ixon` |
| All old timestamps identical | Recorded before `HISTTIMEFORMAT` was set | Expected; only new entries get times |

## 10. Interview Questions

| Question | Answer |
|---|---|
| `HISTSIZE` vs `HISTFILESIZE`? | In-memory entries vs lines kept in the history file. |
| When is history written to disk? | At clean shell exit (or on `history -a`/`-w`). |
| Why isn't shell history an audit log? | Users can disable, edit or delete it. Use auditd, sudo logs or session recording. |
| How do you rerun the last command as root? | `sudo !!`. |
| How do you hide one command from history? | With `ignorespace`/`ignoreboth`, prefix a space; otherwise `history -d N` afterwards. |

## 11. Course Practice (S15 history, corrected where needed)

Questions 1–7, 9–11, 13, 16, 17, 19 and 20 are correct as given. Corrections:

| # | Course | Correction |
|---|---|---|
| 8 | `export HISTSIZE=5000` | Also raise `HISTFILESIZE`, or the file may still be trimmed |
| 12 / 2.7 | `> ~/.bash_history` deletes history | Memory is written back at exit; use `history -c && history -w` |
| 14 / 2.9 | File "overwritten by default" | RHEL typically enables `histappend` already; check `shopt histappend` |
| 15 / 1.9 | Leading space hides commands | Only with `ignorespace`/`ignoreboth` (RHEL default is `ignoredups`) |
| 18 | `history \| grep 'ls'` | Also matches `false`, `tools`, …; use `grep -w ls` |
| 1.10 | "Regular expressions in history" | They're history **modifiers** (`:s/old/new/`) |

## 12. Quick Revision

`````bash
history [N] | !! | !n | !-n | !str | !?str? | ^old^new | !$ !* !:n | :p | :gs/a/b/
Ctrl+R | Alt+. | history -d N | -c | -w | -a | -r | fc
HISTSIZE HISTFILESIZE HISTFILE HISTCONTROL=ignoreboth HISTIGNORE HISTTIMEFORMAT
shopt -s histappend | set +o history | unset HISTFILE
`````

---

### 5. `shell-and-command-line/shell-expansion-and-globbing.md`

`````markdown
# Shell Expansion & File Globbing

> **Sessions:** S9 (expansion), S15 (globbing) · expansion order and brace expansion supplemented
> **Related:** [Quoting](quoting-and-control-operators.md) · [Variables](shell-variables-and-environment.md) · [Command substitution](command-substitution-and-shell-options.md) · [Files & directories](files-and-directories.md) · Regex & grep (S17, S20) · `find` (S18)

## 1. Overview

**The shell, not the command, expands** wildcards, braces, variables and `~` before running anything. `ls *.txt` never sees `*.txt`; it receives a list of filenames. Knowing the expansion order and the difference between **globs** (filenames) and **regular expressions** (text) prevents a whole class of exam and production mistakes.

## 2. Expansion Order **[Interview Knowledge]**

| # | Expansion | Example | Result |
|---|---|---|---|
| 1 | **Brace** | `file{1,2}.txt` | `file1.txt file2.txt` |
| 2 | **Tilde** | `~`, `~alice`, `~+` (PWD), `~-` (OLDPWD) | `/home/you` |
| 3 | **Parameter/variable**, **arithmetic**, **command substitution** (left to right) | `$HOME`, `$((2*3))`, `$(date +%F)` | values |
| 4 | **Word splitting** of *unquoted* results (on `IFS`) | `f="a b"; touch $f` | 2 files |
| 5 | **Filename expansion (globbing)** of unquoted patterns | `*.conf` | matching names |
| 6 | **Quote removal** | `"x"` | `x` |

Consequences:

- Brace expansion runs **first**, so `{1..$n}` doesn't work. Use `seq 1 "$n"` or a C-style `for` loop.
- `~` isn't expanded inside quotes: `"~/file"` is literal. Use `"$HOME/file"`.
- Quoting stops steps 4 and 5. That's why `"$var"` is safe.

## 3. Brace Expansion

````bash
echo file{1,2,3}.txt        # file1.txt file2.txt file3.txt
echo {1..10}                # 1 2 … 10
echo {01..10}               # 01 02 … 10 (zero-padded)
echo {a..e} {1..10..2}      # a b c d e   1 3 5 7 9
mkdir -p proj/{src,docs,tests}
cp -a nginx.conf{,.bak}     # cp -a nginx.conf nginx.conf.bak
touch my_directory/file{1..10}
````

Braces **generate** text whether or not the files exist; globs **match** only existing files.

## 4. Arithmetic Expansion

````bash
echo $((3 + 5)) $((7 / 2)) $((7 % 2)) $((2 ** 10))   # 8 3 1 1024 (integers only)
n=5; ((n++)); echo $n                                # 6
````

Bash arithmetic is **integer-only**. Use `bc` or `awk` for decimals (scripting, S92).

## 5. Globbing (Filename Expansion) **[RHCSA Core]**

| Pattern | Matches | Example |
|---|---|---|
| `*` | Any string, including empty | `ls Doc*`, `ls *.log` |
| `?` | Exactly one character | `ls Doc?` → `Doc4 DocA` |
| `[abc]` | One character from the set | `ls Doc[5A]*` |
| `[a-z]`, `[0-9]` | One character in the range | `ls doc[0-9]` |
| `[!abc]` or `[^abc]` | One character **not** in the set (`!` is POSIX) | `ls doc[!5]*` |
| `[[:digit:]]`, `[[:upper:]]`, `[[:lower:]]`, `[[:alpha:]]`, `[[:alnum:]]`, `[[:space:]]` | POSIX character classes (locale-safe; preferred in scripts) | `ls *[[:digit:]]` |

**Rules:**

- **Hidden files** (leading `.`) aren't matched by `*` or `?`. Use `.*` explicitly or `shopt -s dotglob`.
- **No match:** the pattern stays **literal**. In an empty directory `echo *` prints `*`, and `ls *.txt` errors with `cannot access '*.txt'`. `shopt -s nullglob` expands it to nothing; `failglob` makes it an error.
- Results are **sorted** according to the locale (`LC_COLLATE`).
- `/` is never matched by a wildcard. `*/` matches directories one level down: `ls -d */`.
- Prevent globbing by quoting or escaping: `echo '*'`, `echo "*"`, `echo \*`, or `set -f`.

### 5.1 Globs vs regular expressions

| | Glob (shell, `find -name`, `case`) | Regex (`grep`, `sed`, `awk`, `semanage fcontext`) |
|---|---|---|
| Any string | `*` | `.*` |
| One character | `?` | `.` |
| Set | `[abc]` | `[abc]` |
| Negated set | `[!abc]` | `[^abc]` |
| Anchors | Whole name matched implicitly | `^` … `$` |
| `*` means | "anything" | "zero or more of the **previous** item" |

### 5.2 Exam traps **[RHCSA Core]**

````bash
find /etc -name *.conf          # ✘ the shell expands *.conf in the current dir first
                                #   → wrong results or "paths must precede expression"
find /etc -name '*.conf'        # ✔ quote patterns meant for the command
grep 'error.*disk' /var/log/messages     # regex, quoted
semanage fcontext -a -t httpd_sys_content_t '/web(/.*)?'   # REGEX, not a glob (S76)
tar -xzf a.tgz --wildcards '*.conf'      # glob handled by tar, quoted
````

### 5.3 Useful patterns

````bash
echo *                     # list names without ls (shell builtin; useful if ls is broken)
printf '%s\n' *            # one per line, handles spaces
ls -d .[!.]* ..?*          # hidden files without . and .. [Advanced]
cp -a src/. dest/          # copy a directory's contents INCLUDING hidden files
echo rm *.log              # preview what a destructive glob would do, then rerun without echo
rm -- *                    # protect against files named "-rf" etc.
shopt -s globstar; ls **/*.conf      # recursive match [Advanced]
shopt -s extglob; ls !(*.log)        # everything except *.log [Advanced]
````

## 6. Locale (`LANG`) and Pattern Matching

| Variable | Role | Precedence |
|---|---|---|
| `LC_ALL` | Overrides everything (use for one-off commands or scripts) | Highest |
| `LC_COLLATE`, `LC_TIME`, `LC_MESSAGES`, … | Individual categories | Middle |
| `LANG` | Default for all categories | Lowest |

````bash
echo $LANG; locale               # current settings
localectl                        # system default (/etc/locale.conf)
localectl list-locales | head    # installed locales
LC_ALL=C ls                      # byte-order sort (uppercase first), predictable
LANG=fr_FR.UTF-8 date            # French output only if glibc-langpack-fr is installed
sudo localectl set-locale LANG=en_US.UTF-8   # persistent system default
````

- **Bash 5.x (RHEL 10) enables `globasciiranges` by default.** `[a-z]` matches only lowercase ASCII letters in any locale, so the classic "`[a-z]` also matches uppercase in `en_US`" behavior no longer applies.
- What `LANG` still visibly changes is **sort order** (`ls`, `sort`), messages, and date/number formats.
- In scripts, set `LC_ALL=C` when you need predictable sorting and ranges.

> ⚠️ **Course corrections:** The `env LANG=…` examples showing `[a-z]` matching `FileA`/`FileB` reflect older bash behavior. Q15 actually demonstrates **sorting**, not range matching. And `LANG=fr_FR.UTF-8` needs `glibc-langpack-fr` installed.

## 7. Directory Stack (`pushd`/`popd`)

````bash
pushd /etc        # go to /etc, remember the previous directory
pushd /var/log    # stack: /var/log /etc ~
dirs -v           # show the numbered stack
popd              # back to /etc
cd -              # toggle between the last two directories (simpler)
````

## 8. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `find: paths must precede expression` | Unquoted glob expanded by the shell | Quote the pattern |
| `ls: cannot access '*.txt'` | No match, so the pattern was passed literally | Expected; or `shopt -s nullglob` in scripts |
| `Argument list too long` | Glob expanded to too many names | `find … -exec … {} +` or `xargs` |
| Hidden files not copied by `cp dir/* dest` | `*` skips dotfiles | `cp -a dir/. dest/` |
| Range matches unexpected names | Locale/collation differences (older shells) | POSIX classes or `LC_ALL=C` |
| `touch {1..$n}` creates a file literally named `{1..5}` | Brace expansion precedes variable expansion | `touch $(seq 1 "$n")` |

## 9. Interview Questions

| Question | Answer |
|---|---|
| Who expands `*.txt`, the shell or `ls`? | The shell; `ls` receives the expanded filenames. |
| Glob vs regex? | Globs match **filenames** (`*` = anything); regex matches **text** (`*` = repeat the previous item). |
| Why quote the pattern in `find -name '*.log'`? | So the shell doesn't expand it before `find` sees it. |
| Brace expansion vs globbing? | Braces generate strings regardless of files; globs match existing files only. |
| What happens if a glob matches nothing? | Bash passes it literally (unless `nullglob`/`failglob`). |
| How do you list files if `ls` is compromised? | `echo *` or `printf '%s\n' *` (shell builtins). |

## 10. Course Practice (S15 globbing, corrected)

Setup: `touch test1 test10 test11 test2 Test2 Test3 test99 testXY testa Testa TestXYZ test\( "test 2"`

| # | Task | Command | Correct output |
|---|---|---|---|
| 3 | Start with `test` | `ls test*` | test1 test10 test11 test2 test99 testXY testa test( "test 2" ✔ |
| 4 | Start with `Test` | `ls Test*` | Test2 Test3 Testa TestXYZ ✔ |
| 5 | `test…` ending in a digit | `ls test*[0-9]` | test1 test10 test11 test2 test99 **"test 2"** |
| 6 | `test…` ending in a letter | `ls test*[a-zA-Z]` | testXY testa ✔ |
| 7–8 | `Test` + digit (+ nothing else) | `ls Test[0-9]*` / `ls Test[0-9]` | Test2 Test3 ✔ |
| 9 | Letter … digit | `ls [a-zA-Z]*[0-9]` | test1 test10 test11 test2 test99 Test2 Test3 **"test 2"** |
| 10 | Exactly five characters | `ls ?????` | test1 test2 Test2 Test3 **testa Testa test(** |
| 11 | Start `t`/`T`, end `3`/`a` | `ls [tT]*[3a]` | Test3 testa Testa ✔ |
| 12 | `t`, then `e` or `R`, … digit | `ls t[eR]*[0-9]` (course used `[eiR]`) | test1 test10 test11 test2 test99 **"test 2"** |
| 13 | Not starting with `T` | `ls [!T]*` (or `[^T]*`) | all lowercase `test…` names ✔ |
| 14 | Copy `LANG` | `MyLANG=$LANG` (export only if children need it) | |
| 15 | `LANG` influence | `ls` vs `LC_ALL=C ls` | Different **sort order** (see §6) |
| 16 | List without `ls` | `echo *` | ✔ |
| 17 | Alternative to `cd` | `pushd`/`popd` | ✔ |

## 11. Quick Revision

````bash
Order: brace → tilde → $var $((…)) $(…) → word split → glob → quote removal
{a,b} {1..10} {01..10} file{,.bak}     * ? [abc] [a-z] [!x] [[:digit:]]
.* / dotglob   nullglob failglob nocaseglob globstar extglob   set -f
find -name '*.x' (QUOTE)   glob ≠ regex   LC_ALL > LC_* > LANG   LC_ALL=C
pushd popd dirs -v   cd -
````
