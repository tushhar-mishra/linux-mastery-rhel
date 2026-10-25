# Command History

> **Baseline:** RHEL 10, bash 5.x
> **Related:** [Quoting (`!` trap)](quoting-and-control-operators.md#23-the--trap-interactive-shells-only) · [Shell options](command-substitution-and-shell-options.md) · [Shell basics (keys)](shell-basics-and-command-syntax.md#26-time-saving-keys-rhcsa-core) · [Variables](shell-variables-and-environment.md)

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

> ⚠️ **Common misconception:** A leading space hides a command **only** if `HISTCONTROL` contains `ignorespace` or `ignoreboth`. RHEL's default is `ignoredups`, so by default spaced commands **are** recorded.

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

```bash
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
```

> ⚠️ **Common misconception:** `> ~/.bash_history` alone doesn't erase history. The in-memory list is written back at exit. Use `history -c && history -w`.

## 6. Persistent Configuration (`~/.bashrc`)

```bash
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth                 # skip duplicates and space-prefixed commands
HISTIGNORE='ls:ll:history*:clear'
HISTTIMEFORMAT='%F %T '
shopt -s histappend
PROMPT_COMMAND="history -a${PROMPT_COMMAND:+; $PROMPT_COMMAND}"   # [Advanced] save after every command
```

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

## 11. Quick Revision

```bash
history [N] | !! | !n | !-n | !str | !?str? | ^old^new | !$ !* !:n | :p | :gs/a/b/
Ctrl+R | Alt+. | history -d N | -c | -w | -a | -r | fc
HISTSIZE HISTFILESIZE HISTFILE HISTCONTROL=ignoreboth HISTIGNORE HISTTIMEFORMAT
shopt -s histappend | set +o history | unset HISTFILE
```

## 12. Cross-References

- [Quoting (`!` expansion)](quoting-and-control-operators.md)
- [Variables & persistence (`~/.bashrc`)](shell-variables-and-environment.md)
- [Shell options (`set -o history`, `shopt`)](command-substitution-and-shell-options.md)
- [System logging](../logs-scheduling-and-packages/system-logging.md) · [Auditing with auditd](../firewall-and-selinux/auditd.md)
