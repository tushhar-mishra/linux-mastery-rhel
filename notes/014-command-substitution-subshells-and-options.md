# 014 · Command Substitution, Subshells and Shell Options

> **You need first:** [013 · Expansion and globbing](013-expansion-and-globbing.md)
> **Next:** [015 · Command history](015-command-history.md)

---

## What it is

- **Command substitution** `$(command)` runs a command and puts its **output** right into your command line. `echo "Today is $(date +%A)"` → `Today is Monday`.
- A **subshell** is a copy of your current shell that runs some commands, then disappears. Changes made inside it (like `cd` or new variables) don't come back.
- **Shell options** are on/off switches that change how bash behaves. They are set with `set` (standard options, like "stop on errors") and `shopt` (bash-only options, like "make `*` match hidden files").

## Why it exists

Scripts constantly need the output of one command as input to another: today's date in a backup file name, the current kernel version, the number of users, the PID of a service. Command substitution does that in one line.

Shell options make bash safer for automation (stop on the first error, refuse unset variables) and are the main debugging tool (`set -x` shows every command as it runs).

## Analogy

Command substitution is **asking a colleague a question mid-sentence**: "Send the report dated *(hey, what's today's date?)* … *2026-11-16* … to the team." The answer is pasted into your sentence before it is finished.

A subshell is **sending an intern to a different room to try something**. They can rearrange furniture in that room (`cd`, set variables), but your room stays exactly as it was. All you get back is what they report (the output).

## How it works inside

1. When bash sees `$(cmd)`, it creates a **child copy of itself** (a fork: the subshell).
2. The child runs `cmd`. Its output goes into a **pipe** (a one-way channel between processes, topic 016) instead of the screen.
3. The parent reads everything from the pipe, **removes trailing newlines**, and puts the text where `$(cmd)` was.
4. Unless the whole thing is inside double quotes, the result then goes through **word splitting** and **globbing** (topic 013). That's why you should write `"$(cmd)"`.

### Who sees what

| Construct | New process? | Sees non-exported variables? | Do changes stay afterwards? |
|---|---|---|---|
| `{ cmds; }` | No (current shell) | Yes | **Yes** |
| `( cmds )` | Subshell (a fork) | **Yes**, it's a full copy | No |
| `$( cmds )` | Subshell (a fork) | **Yes** | No; only the output returns |
| `bash -c 'cmds'` | A brand-new bash program | **No**, only exported ones | No |
| `./script.sh` | A brand-new bash program | No, only exported ones | No |
| `source script.sh` | No (current shell) | Yes | **Yes** |

A subshell (`( )`, `$( )`) is a **fork**, a perfect copy that even includes unexported variables. A new program (`bash -c`, `./script`) only gets the **environment** (exported variables, topic 012).

## Commands

### Command substitution

```bash
today=$(date +%F) ; echo "$today"
```
```
2026-11-16
```
- `date +%F` prints the date as `YYYY-MM-DD`, which sorts correctly. The output is stored in a variable.

```bash
cp -a /etc/hosts /etc/hosts.$(date +%F_%H%M)
ls /etc/hosts*
```
```
/etc/hosts  /etc/hosts.2026-11-16_1102
```

```bash
echo "Kernel $(uname -r) on $(hostname), $(wc -l < /etc/passwd) accounts"
```
```
Kernel 6.12.0-211.53.1.el10_2.x86_64 on server1.example.com, 27 accounts
```

```bash
echo $(ls /etc/ssh) ; echo "---" ; echo "$(ls /etc/ssh)"
```
```
moduli ssh_config ssh_config.d sshd_config sshd_config.d ssh_host_ecdsa_key ssh_host_ecdsa_key.pub …
---
moduli
ssh_config
ssh_config.d
sshd_config
sshd_config.d
ssh_host_ecdsa_key
ssh_host_ecdsa_key.pub
…
```
- **Unquoted**: newlines are word-split, so everything lands on one line. **Quoted**: newlines are kept.

```bash
ls -l "$(type -P grep)"
```
```
-rwxr-xr-x. 1 root root 169800 Oct 29  2024 /usr/bin/grep
```
- `type -P` prints the path of a program. Substitution feeds it to `ls`.

```bash
dir=$(dirname "$(readlink -f /usr/bin/python3)") ; echo "$dir"
```
```
/usr/bin
```
- Substitutions nest cleanly. `readlink -f` resolves the symlink; `dirname` strips the file name.

```bash
host=$(< /etc/hostname)
```
- A bash shortcut for `$(cat /etc/hostname)`. It's faster because no extra program is started.

**Backticks** `` `cmd` `` are the old form of `$(cmd)`. They're hard to nest and easy to confuse with single quotes. You'll see them in old scripts; don't write new ones.

### Processing command output line by line

```bash
while IFS= read -r line; do
    echo "Line: $line"
done < /etc/hosts
```
```
Line: # Loopback entries; do not change.
Line: # For historical reasons, localhost precedes localhost.localdomain:
Line: 127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
Line: ::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
...
```
- `read -r line` reads one line into `line`. `IFS=` keeps leading spaces. `-r` keeps backslashes. `< /etc/hosts` feeds the file in (topic 016).
- This is the **safe** way to handle lines that contain spaces. `for x in $(cat file)` splits on every space (topic 043).

### Subshells

```bash
x=5
( echo "subshell sees $x" )
bash -c 'echo "new bash sees [$x]"'
```
```
subshell sees 5
new bash sees []
```

```bash
(cd /var/log && ls | head -2) ; pwd
```
```
anaconda
audit
/home/alice
```
- Did work inside `/var/log` without changing your own location.

### Shell options with `set`

```bash
echo $-
```
```
himBHs
```
- The active single-letter options. `i` = interactive, `m` = job control, `B` = brace expansion, `H` = `!` history, `h` = remember command paths.

```bash
set -o | head -5
```
```
allexport      	off
braceexpand    	on
emacs          	on
errexit        	off
errtrace       	off
```
- Every option and whether it's on. Turn on with `set -o NAME` or `set -X`; turn off with `set +o NAME` or `set +X` (yes, **plus means off**).

| Flag | Name | What it does |
|---|---|---|
| `-e` | errexit | Exit the script when a command fails (with exceptions, below) |
| `-u` | nounset | Using an unset variable is an error |
| `-o pipefail` | pipefail | A pipeline fails if **any** part fails, not just the last |
| `-x` | xtrace | Print each command **after expansion**, prefixed with `+`, before running it |
| `-v` | verbose | Print each line **as read**, before expansion |
| `-n` | noexec | Read but don't run: a **syntax check** |
| `-f` | noglob | Turn off wildcards |
| `-C` | noclobber | `>` refuses to overwrite an existing file (`>\|` forces it) |
| `-a` | allexport | Export every variable you set (handy when loading `.env` files) |
| `-H` | histexpand | `!` history expansion (`set +H` turns it off) |

### Debugging with `-x`

```bash
name="world"
set -x
echo "hello $name" > /tmp/out.txt
set +x
```
```
+ echo 'hello world'
+ set +x
```
- The `+` line shows the command **after** expansion, exactly as it ran. The redirection (`> /tmp/out.txt`) isn't shown, and the `set +x` itself is traced before tracing stops. This is the #1 tool for "why does my script do that?"
- For a whole script: `bash -x script.sh`. Add line numbers with `PS4='+ ${LINENO}: '`.

```bash
bash -n script.sh
```
```
script.sh: line 9: syntax error: unexpected end of file
```
- Syntax check only (here, a missing `fi` or `done`). It does **not** catch runtime errors like a missing file.

### The famous script header

```bash
#!/bin/bash
set -euo pipefail
```
- `-e` stop on errors, `-u` stop on unset variables, `-o pipefail` catch failures inside pipelines.
- **Limits of `set -e`:** it is **ignored** for commands that are part of an `if`/`while` condition, all but the last command in `&&`/`||` lists, commands negated with `!`, and (without `pipefail`) all but the last command of a pipeline. Topic 045 covers these traps in depth.

**Never put `set -e` (or `set -n`, `set -t`) in `~/.bashrc`.** Your login shell would close at the first failed command, which can lock you out of usable sessions. Test options in a child `bash` first.

### `shopt`: bash-only options

```bash
shopt -s dotglob      # -s = set (on)
shopt -u dotglob      # -u = unset (off)
shopt dotglob nullglob
```
```
dotglob        	off
nullglob       	off
```

| Option | Effect |
|---|---|
| `dotglob` | `*` also matches hidden files |
| `nullglob` / `failglob` | A glob with no match becomes nothing / an error |
| `nocaseglob` | Case-insensitive globs |
| `globstar` | `**` matches any depth |
| `extglob` | Extra patterns like `!(*.log)` |
| `histappend` | Append to the history file instead of overwriting (topic 015) |
| `expand_aliases` | Allow aliases in scripts |
| `checkwinsize` | Update the window size after each command |

### Try it
1. `echo "Uptime: $(uptime -p), users: $(who | wc -l)"`.
2. Compare `echo $(ls /etc | head -3)` with `echo "$(ls /etc | head -3)"`.
3. Write a 3-line script with a bug (an `if` without `fi`). Run `bash -n` on it, then fix it and run it with `bash -x`.
4. In a **child** bash: `bash`, then `set -e`, then `false`. Notice you're back in your original shell.

**Check your work:** on your lab VM, from the notes folder, run `sudo ./checks/check 014` for every step, or `sudo ./checks/check 014 STEP` for one (topic 002 shows how to get the notes there).

## Where you'll use it

- **Dated backups and file names:** `tar czf backup-$(date +%F).tgz /etc`.
- **Grabbing IDs:** `pid=$(pgrep -o nginx)` (topic 033), `ip=$(hostname -I | awk '{print $1}')`.
- **Kubernetes one-liners:** `kubectl logs $(kubectl get pod -l app=web -o name | head -1)`.
- **CI/CD scripts** almost always start with `set -euo pipefail`, so a failed step stops the pipeline instead of deploying something broken.
- **Debugging someone's script during an incident:** `bash -x script.sh 2>&1 | less` shows exactly which command misbehaves.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| Your terminal closes after a failed command | `set -e` in an interactive shell or rc file | Remove it from `~/.bashrc`; test in a child `bash` |
| `cannot overwrite existing file` | `noclobber` (`set -C`) is on | `>\|` to force, or `set +C` |
| `*` prints literally | `set -f` is on | `set +f` |
| `unbound variable` | `set -u` and a variable isn't set | Set it, or use `${var:-}` |
| Script does nothing | A leftover `set -n` | Remove it |
| `$(cmd)` output all on one line | Unquoted substitution | `"$(cmd)"` |
| Script keeps going after an error despite `set -e` | The failing command was in a condition, an `&&` list or a pipeline | `set -o pipefail`; check exit codes explicitly (topic 045) |
| Variable set inside `( )` or `$( )` is empty later | Subshell changes don't come back | Use `{ ; }` or set it in the current shell |

## Quick recap

- `"$(cmd)"` inserts a command's output (trailing newlines removed). Quote it. Prefer it over backticks.
- `( )` and `$( )` run in a subshell (a fork; sees everything, changes are lost). `bash -c`/`./script` only see exported variables. `source` runs in the current shell.
- `set -x` traces, `bash -n` checks syntax, `set -euo pipefail` makes scripts stop on errors (with known exceptions).
- `shopt -s/-u` for bash-only options like `dotglob`, `nullglob`, `globstar`.

**Interview questions**

1. *What is command substitution?* `$(cmd)` runs `cmd` in a subshell and replaces itself with the command's output, minus trailing newlines.
2. *Does a subshell see unexported variables?* Yes. `( )` and `$( )` are forks of the current shell, so they have a full copy. A new program like `bash -c` only gets exported (environment) variables.
3. *Why isn't `set -e` enough to make a script safe?* It's ignored in `if`/`while` conditions, in all but the last command of `&&`/`||` lists, for negated commands, and (without `pipefail`) for all but the last command in a pipeline.

**Scenario question** (answer out loud first, then compare)

> *"A colleague's script has `set -e` at the top, yet it carried on after a command failed and corrupted data. How is that possible?"*

**Model answer:**
1. `set -e` is ignored in several places:
   - commands in an `if`, `while` or `until` condition;
   - all but the last command of an `&&`/`||` list;
   - negated commands (`! cmd`);
   - failures inside a function called from such a context.
2. In a **pipeline**, only the last command's status counts unless `set -o pipefail` is set: `bad_cmd | tee log` "succeeds".
3. Failures inside `$( )` used in an assignment with `local` or `export` are hidden by those commands' own exit status.
4. So use `set -euo pipefail`, but **also** check critical steps explicitly: `cmd || { echo "cmd failed" >&2; exit 1; }`.
5. Debug with `bash -x` to see exactly which line ran last.

**Likely follow-ups:**
- *What does `bash -n` catch?* Syntax errors only (a missing `fi`, `done`, quote). Not runtime errors.
- *Why prefer `$( )` over backticks?* It nests without escaping and is easier to read.
