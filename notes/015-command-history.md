# 015 · Command History

> **You need first:** [014 · Command substitution, subshells and options](014-command-substitution-subshells-and-options.md)
> **Next:** [016 · Redirection and pipes](016-redirection-and-pipes.md)

---

## What it is

bash remembers the commands you type. You can scroll through them (↑/↓), search them (**Ctrl+R**), re-run them, and edit old commands with short `!` codes.

- **In-memory history**: the list kept while your shell is running.
- **History file** (`HISTFILE`, normally `~/.bash_history`): where the list is saved when your shell exits, and loaded from when a new shell starts.
- **History expansion**: the `!` shortcuts (`!!`, `!$`, `!ssh`) that pull pieces of old commands into a new one.

## Why it exists

Admins type the same long commands again and again. History turns "retype a 120-character `kubectl` command" into "Ctrl+R, type `kub`, Enter". It also helps you remember what you did yesterday on this server.

It is **not** a security log. Users can turn it off, edit it or delete it.

## Analogy

History is your shell's **notebook**. During the day it writes on a scratch pad (memory). When you leave (exit cleanly), it copies the scratch pad into the notebook (the file). If you're thrown out suddenly (the SSH connection dies), the scratch pad can be lost. Ctrl+R is **flipping back through the notebook** looking for a word.

## How it works inside

1. Each command you run is added to the in-memory list, unless filtered by `HISTCONTROL`/`HISTIGNORE`. At most `HISTSIZE` entries are kept.
2. On a **clean exit**, bash writes the list to `HISTFILE`: **appended** if the `histappend` option is on, otherwise the file is **overwritten**. The file is then trimmed to `HISTFILESIZE` lines.
3. A new shell **reads** `HISTFILE` when it starts.

What follows from this:
- A killed SSH session or crashed terminal can **lose** that session's history.
- With several terminals open and `histappend` off, the **last terminal to exit overwrites** the others.
- `history -a` writes new entries to the file immediately.

| Variable / option | Meaning | RHEL default |
|---|---|---|
| `HISTSIZE` | Max entries in memory | 1000 (set in `/etc/profile`) |
| `HISTFILESIZE` | Max lines in the file | Same as `HISTSIZE` if unset |
| `HISTFILE` | The file | `~/.bash_history` |
| `HISTCONTROL` | `ignoredups` (skip repeats), `ignorespace` (skip commands starting with a space), `ignoreboth` (both), `erasedups` | `ignoredups` |
| `HISTIGNORE` | Patterns never saved, e.g. `ls:ll:history*` | unset |
| `HISTTIMEFORMAT` | Show a timestamp per entry, e.g. `'%F %T '` | unset |
| `shopt histappend` | Append instead of overwrite | On (set in `/etc/bashrc`) |

**Trap:** many guides say "start a command with a space to hide it from history". That only works if `HISTCONTROL` contains `ignorespace` or `ignoreboth`. RHEL's default is `ignoredups`, so **spaced commands are saved**. Ubuntu's default `~/.bashrc` uses `ignoreboth`.

## Commands

```bash
history 5
```
```
  996  systemctl status sshd
  997  sudo tail -F /var/log/secure
  998  cd /etc/ssh
  999  vi sshd_config
 1000  history 5
```
- The last 5 entries, each with a number you can reuse.

### Re-running and reusing

| Syntax | Runs | Example |
|---|---|---|
| `!!` | The previous command | `sudo !!` re-runs it as root |
| `!n` | Entry number n | `!996` |
| `!-n` | The nth-previous command | `!-2` |
| `!string` | The latest command **starting with** `string` | `!sys` |
| `!?string?` | The latest command **containing** `string` | `!?secure?` |
| `^old^new` | The previous command with the first `old` replaced | `^status^restart` |
| `!$` | Last argument of the previous command (= **Alt+.**) | `mkdir /srv/app && cd !$` |
| `!^`, `!*`, `!:n` | First / all / nth argument | `cp !* /backup/` |
| `:p` | **Print only, don't run** (safety check) | `!rm:p` |
| `:s/a/b/`, `:gs/a/b/` | Replace the first / all occurrences | `!!:gs/dev/prod/` |

```bash
systemctl status nginx
^status^restart
```
```
systemctl restart nginx
```
- bash prints the rewritten command, then runs it.

```bash
cat /etc/os-release
sudo !!
```
```
sudo cat /etc/os-release
NAME="Red Hat Enterprise Linux"
...
```

```bash
!rm:p
```
```
rm -rf /tmp/build-old
```
- `:p` shows what `!rm` **would** run without running it. Always do this before re-running anything destructive.

### Searching

- **Ctrl+R**, then type part of a command. It shows the newest match. Press Ctrl+R again for older matches.
- **Enter** runs it. **→** or **Esc** puts it on the line to edit first. **Ctrl+G** cancels.

```
(reverse-i-search)`tail': sudo tail -F /var/log/secure
```

`shopt -s histverify` makes `!` expansions appear on the line for you to check before they run. A good safety net.

### Managing history

```bash
history -d 997             # delete one entry (e.g. a pasted password)
history -c                 # clear the in-memory list
history -c && history -w   # clear memory AND overwrite the file with the empty list
history -a                 # append this session's new entries to the file now
history -r                 # re-read the file into memory
history | grep -w ssh      # find entries containing the word ssh
fc                         # open the last command in your editor, run it on save
set +o history             # stop recording in this session (set -o history to resume)
```

**Trap:** `> ~/.bash_history` alone does **not** erase history. Your shell writes its in-memory list back at exit. Use `history -c && history -w`.

### A better setup (put in `~/.bashrc`)

```bash
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth
HISTIGNORE='ls:ll:history*:clear'
HISTTIMEFORMAT='%F %T '
shopt -s histappend
PROMPT_COMMAND="history -a${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
```
- `PROMPT_COMMAND` runs before every prompt; here it saves each command immediately, so nothing is lost if the session dies.
- `${PROMPT_COMMAND:+; $PROMPT_COMMAND}` keeps any existing value (parameter expansion, topic 012).

```bash
history 2
```
```
 1001  2026-11-16 11:20:04 df -h
 1002  2026-11-16 11:20:09 history 2
```
- Timestamps appear only for commands saved **after** `HISTTIMEFORMAT` was set.

### Try it
1. Run `ls /etc/ssh`, then `cd !$`. Where are you?
2. Run `systemctl status chronyd`, then `^chronyd^sshd`.
3. Press Ctrl+R and find a command you ran earlier containing `tail`.
4. Run `echo SECRET123`, then find its number and delete it with `history -d N`.

**Check your work:** on your lab VM, from the notes folder, run `sudo ./checks/check 015` for every step, or `sudo ./checks/check 015 STEP` for one (topic 002 shows how to get the notes there).

## Where you'll use it

- **Speed during incidents:** Ctrl+R for the long `journalctl`/`kubectl` command you ran an hour ago. `sudo !!` when you forgot sudo.
- **"What did I change?"** Review `history` after a session and copy the commands into your change notes.
- **Secrets hygiene:** passwords on the command line (`mysql -pSecret`, `curl -u user:pass`) land in `~/.bash_history`. Prefer prompts, `--password-file` options or environment files with mode `600`. If one slips in: `history -d N; history -w`.
- **Real auditing** uses `auditd` (topic 077), sudo logs (topic 028) or session recording, never shell history.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| Commands from the last session are missing | The session was killed before a clean exit | `history -a` in `PROMPT_COMMAND` |
| Terminals overwrite each other's history | `histappend` is off | `shopt -s histappend` |
| A space-prefixed command was still saved | `HISTCONTROL=ignoredups` | `HISTCONTROL=ignoreboth` |
| `bash: !foo: event not found` | `!` inside double quotes triggered expansion | Single quotes, `\!`, or `set +H` |
| Terminal froze after Ctrl+S (forward search) | Ctrl+S is the "pause output" key | Ctrl+Q; `stty -ixon` frees Ctrl+S for searching |
| All old entries show the same timestamp | Saved before `HISTTIMEFORMAT` was set | Expected |

## Quick recap

- History lives in memory and is saved to `~/.bash_history` on a **clean exit** (or with `history -a`).
- **Ctrl+R** to search, `!!`/`sudo !!`, `!$`/Alt+., `^old^new`, and `:p` to preview.
- `HISTCONTROL=ignoreboth` + `histappend` + `HISTTIMEFORMAT` make history much more useful.
- History is not an audit trail, and it can leak secrets.

**Interview questions**

1. *`HISTSIZE` vs `HISTFILESIZE`?* `HISTSIZE` is how many entries are kept in memory during the session; `HISTFILESIZE` is how many lines are kept in the history file.
2. *Why isn't shell history a reliable audit log?* The user controls it: they can disable it, edit or delete the file, and it's lost if a session is killed. Use auditd, sudo logs or session recording.
3. *How do you re-run the last command as root?* `sudo !!`.

**Scenario question** (answer out loud first, then compare)

> *"You typed a database password on the command line by mistake. What risks does that create, and how do you clean up?"*

**Model answer:**
1. It's in your **shell history** (memory now, `~/.bash_history` later). Delete the entry: `history -d N`, then `history -w`.
2. While the command ran, the password was visible to every user in `ps` output (`/proc/PID/cmdline`).
3. It may also be in audit logs, terminal scrollback and session recordings.
4. **Rotate the password**: cleaning the history doesn't make it safe again.
5. Prevention: pass secrets through files with tight permissions, environment variables or prompts, and set `HISTCONTROL=ignoreboth` so commands starting with a space aren't saved.

**Likely follow-ups:**
- *Why didn't my history from another window appear?* Each shell keeps history in memory and writes it at exit. `shopt -s histappend` plus `history -a` makes it saved straight away.
- *Is history an audit trail?* No. The user controls it. Use auditd or sudo logs.
