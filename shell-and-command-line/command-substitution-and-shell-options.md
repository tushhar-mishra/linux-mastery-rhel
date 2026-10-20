# Command Substitution, Subshells & Shell Options

> **Sessions:** S14 ("shell embedding" and options) · **Objective:** *Processing output of shell commands within a script* **[RHCSA Core]**
> **Related:** [Variables](shell-variables-and-environment.md) · [Quoting & control operators](quoting-and-control-operators.md) · [Expansion & globbing](shell-expansion-and-globbing.md) · [History](command-history.md) · Scripting (S85–92)

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

```bash
x=5
( echo "$x" )             # 5   (subshell is a fork)
bash -c 'echo "[$x]"'     # []  (new process sees only exported variables)
echo $(myvar=6; echo $myvar); echo "[$myvar]"   # 6  then []
(cd /etc && ls) ; pwd     # your directory is unchanged
```

## 3. Command Substitution **[RHCSA Core]**

```bash
today=$(date +%F)                         # capture output in a variable
cp -a /etc/hosts /etc/hosts.$(date +%F)   # dated backup
echo "Kernel: $(uname -r)"
users=$(wc -l < /etc/passwd)              # count (number only)
ls -l "$(type -P grep)"                   # long listing of the grep binary
file=$(< /etc/hostname)                   # bash shortcut for $(cat file)
```

**Rules:**

- **Trailing newlines are stripped.** Internal newlines survive only if you **quote**: `echo "$(ls)"` keeps line breaks, `echo $(ls)` puts everything on one line.
- **Quote substitutions** used as arguments: `"$(cmd)"`. Otherwise word splitting and globbing apply to the output.
- **Nesting:** `$(dirname "$(readlink -f /usr/bin/python3)")`.

**Backticks** `` `cmd` `` are the legacy form. They nest only with escaped inner backticks and are easy to confuse with single quotes. Prefer `$( )`.

```bash
echo `myvar=10; echo $myvar`     # 10   (command substitution)
echo 'myvar=10; echo $myvar'     # myvar=10; echo $myvar   (literal text)
```

**Processing output in scripts** (exam objective preview):

```bash
for u in $(awk -F: '$3>=1000 {print $1}' /etc/passwd); do   # fine for simple, space-free words
    echo "Regular user: $u"
done

while IFS= read -r line; do         # robust: one line at a time, spaces preserved
    echo "Line: $line"
done < /etc/hosts
```

## 4. Shell Options with `set`

```bash
echo $-          # active single-letter flags, e.g. himBHs (interactive bash)
set -o           # all options with on/off state
set -o nounset   # enable by name   |  set +o nounset  # disable
set -u           # enable by letter |  set +u          # disable
```

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

```bash
#!/bin/bash
set -euo pipefail     # stop on errors, unset variables, and failures inside pipelines
```

Understand the caveats before relying on it.

> ⚠️ **Never put `set -e`, `set -n` or `set -t` in `~/.bashrc`.**
> - `set -e`: the first failing command closes your shell.
> - `set -t`: every new shell exits after one command.
>
> Either can effectively lock you out of usable logins. Test these options in a child `bash` or in a script, not your login shell.

### 4.2 Debugging scripts

```bash
bash -n script.sh            # syntax check only: catches missing fi/done/quotes
bash -x script.sh            # trace the whole script
set -x; risky_part; set +x   # trace one section
PS4='+ ${LINENO}: '          # add line numbers to the trace
```

`bash -n` does **not** catch runtime errors (division by zero, missing files).

> ⚠️ **Course correction:** The `set -n` example uses `$((5/0))`, which is a runtime error, so `-n` won't report it. Use a real syntax error, such as an `if` without `fi`.

## 5. `shopt` (bash-specific options)

```bash
shopt                       # list all with on/off
shopt -s dotglob            # set (enable)  |  shopt -u dotglob  # unset (disable)
shopt -q nocaseglob && echo on || echo off
shopt -p histappend         # print as a reusable command
```

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

```bash
$(cmd)  "$(cmd)"  `legacy`  $(< file)     ( subshell )  { current; }  source file
echo $-  set -o  set -euxv / +…  set -o pipefail  set -C (>|)  set -f  hash -r
bash -n script  bash -x script  PS4
shopt -s/-u/-q  dotglob nullglob nocaseglob globstar extglob histappend
```

## 11. Cross-References

- [Variables & positional parameters](shell-variables-and-environment.md)
- [Quoting & control operators](quoting-and-control-operators.md)
- [Expansion & globbing (dotglob, nullglob)](shell-expansion-and-globbing.md)
- [I/O redirection (noclobber, pipefail)](../files-and-text-processing/io-redirection-and-pipes.md)
- Scripting (S85–92): planned
