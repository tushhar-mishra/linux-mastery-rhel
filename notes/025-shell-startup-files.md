# 025 · Shell Startup Files: .bashrc, .bash_profile, /etc/profile.d

> **You need first:** [024 · Groups](024-groups.md)
> **Next:** [026 · File permissions and umask](026-file-permissions-and-umask.md)

---

## What it is

When bash starts, it reads a few **startup files** (also called profile files or rc files, "rc" meaning "run commands"). These set up your environment: variables, PATH, aliases, functions, the prompt, history settings, and the **umask** (the default permissions for new files, topic 026).

**Which** files run depends on the type of shell:

| Shell type | Examples | How to tell |
|---|---|---|
| **Login, interactive** | Console or SSH login, `su - user`, `sudo -i`, `bash -l` | `echo $0` shows `-bash`; `shopt login_shell` → on |
| **Non-login, interactive** | A new terminal tab in a desktop, typing `bash`, `su user` | `shopt login_shell` → off |
| **Non-interactive** | Scripts, `bash -c '…'`, cron jobs, `ssh host command` | `[[ $- == *i* ]]` is false |

## Why it exists

You want settings to apply automatically every time, for one user or for everyone, without retyping them. Splitting the files by shell type lets things that only need doing once per login (setting PATH, printing a welcome message) be separate from things every interactive shell needs (aliases, prompt).

Most "my setting doesn't work" problems come from putting it in the wrong file.

## Analogy

Logging in is **arriving at the office in the morning**: you go through the full routine. Building rules (`/etc/profile`), then your personal morning checklist (`~/.bash_profile`), which includes setting up your desk (`~/.bashrc`). Opening a new terminal tab is **sitting down at another desk in the same building**: you skip the front-door routine, but still set up the desk (`~/.bashrc`). A script is a **robot passing through**: it doesn't go through any of these routines.

## How it works inside

### Files on RHEL

| File | Scope | Read by |
|---|---|---|
| `/etc/profile` | All users | Login shells. It sources every `/etc/profile.d/*.sh` |
| `/etc/profile.d/*.sh` | All users (drop-in files) | Through `/etc/profile`; also through `/etc/bashrc` for non-login interactive shells |
| `~/.bash_profile` | One user | Login shells. bash reads the **first one that exists** of `~/.bash_profile`, `~/.bash_login`, `~/.profile` |
| `~/.bashrc` | One user | Interactive non-login shells. RHEL's `~/.bash_profile` sources it, so login shells get it too |
| `/etc/bashrc` | All users | Sourced by `~/.bashrc` on RHEL (aliases, prompt, history defaults) |
| `~/.bash_logout` | One user | Run when a **login** shell exits |
| `/etc/environment` | All sessions (not only bash) | Read by PAM's `pam_env` at login. Simple `KEY=value` lines, not a script |

**Ubuntu/Debian differences:** the per-user login file is usually `~/.profile` (which sources `~/.bashrc`), and the system-wide rc file is `/etc/bash.bashrc` instead of `/etc/bashrc`.

### The order

**Login shell** (SSH, `su -`):
```
/etc/profile → /etc/profile.d/*.sh → ~/.bash_profile → ~/.bashrc → /etc/bashrc
… when it exits: ~/.bash_logout
```

**Non-login interactive shell** (new tab, `bash`):
```
~/.bashrc → /etc/bashrc → /etc/profile.d/*.sh
```

On RHEL 9/10, the default `~/.bashrc` (copied from `/etc/skel`) also adds `~/.local/bin` and `~/bin` to PATH and sources any files in `~/.bashrc.d/`.

**Sourcing** means "run this file inside the current shell" (`source file` or `. file`), so its variables and aliases stay (topic 012). Startup files are sourced, never run as separate programs.

`/etc/profile` sources each file in `/etc/profile.d/` that ends in **`.sh`** and is **readable**. The execute permission doesn't matter, so `chmod -x` does **not** disable one. Rename it (remove the `.sh`) or delete it.

### Non-interactive shells read almost nothing

Scripts, cron jobs and `ssh host 'command'` don't read `~/.bash_profile`. That's why a variable you set in `~/.bash_profile` is missing in cron (topic 039). Scripts should set what they need themselves.

## Commands

### Where to put what

| Setting | Best place |
|---|---|
| Your aliases, functions, prompt, history settings | `~/.bashrc` (or a file in `~/.bashrc.d/`) |
| Your environment variables (`EDITOR`, PATH additions) | `~/.bashrc` or `~/.bash_profile`, with `export` |
| Settings for **all users** | A new file `/etc/profile.d/<name>.sh` (don't edit `/etc/profile`; updates may replace it) |
| Variables for non-shell sessions too (desktop apps, some services) | `/etc/environment` (`KEY=value`, no `export`, no `$VAR`) |
| Default dotfiles for **future** users | `/etc/skel/` (topic 022) |

### Examples

```bash
# /etc/profile.d/editor.sh  — every user, every bash session
export EDITOR=vim
```

```bash
# /etc/profile.d/myapp-path.sh — add a directory to PATH only once
case ":$PATH:" in
  *:/opt/myapp/bin:*) ;;                           # already there: do nothing
  *) export PATH="/opt/myapp/bin:$PATH" ;;
esac
```
- `case` (topic 042) checks whether PATH already contains the directory, so nested shells don't keep adding it again and again.

```bash
# ~/.bashrc additions
alias k='kubectl'
alias ll='ls -lh'
export HISTCONTROL=ignoreboth HISTTIMEFORMAT='%F %T '
[[ $- == *i* ]] || return        # stop here if not interactive: keeps scp/rsync working
```

```bash
# ~/.bash_profile (RHEL default content)
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi
```

### Applying and debugging

```bash
source ~/.bashrc
```
- Applies changes to the **current** shell. Changes never affect shells that are already running.

```bash
su - "$USER"
```
- A clean login shell that re-reads everything. The best test.

```bash
bash -lx -c exit 2>&1 | grep -E 'profile|bashrc' | head
```
```
+ . /etc/profile.d/bash_completion.sh
+ . /etc/profile.d/colorgrep.sh
+ . /home/alice/.bashrc
+ . /etc/bashrc
```
- `-l` = login shell, `-x` = trace every line. This shows exactly which files ran and in what order. Remove the `grep` to see every command.

```bash
grep -r 'EDITOR' /etc/profile /etc/profile.d /etc/bashrc ~/.bash* 2>/dev/null
```
- "Where on earth is this variable set?"

```bash
bash --noprofile --norc
```
- A shell with **no** startup files. If a problem disappears here, it's caused by a startup file.

### Try it
1. Add `export GREETING=hi` to `~/.bash_profile` only. Open a new non-login shell (`bash`) and check `echo $GREETING`. Then try `bash -l`.
2. Create `/etc/profile.d/hello.sh` with a function `hello() { echo "Hello, $USER"; }`. Log in as another user and run `hello`.
3. Add `echo "Welcome!"` to `~/.bashrc`, then try `scp` to that account from another host and see what happens. Remove it, or guard it with `[[ $- == *i* ]]`.
4. Run `bash -lx -c exit 2>&1 | less` and follow the startup chain.

## Where you'll use it

- **Team-wide tooling:** `/etc/profile.d/company.sh` sets the proxy, PATH and aliases for every engineer.
- **Kubernetes workstations:** `source <(kubectl completion bash)` and `alias k=kubectl` in `~/.bashrc`.
- **Debugging "works in my terminal, fails in cron/systemd/CI":** those are non-interactive and don't read your profile. Set variables inside the script, the unit file (`Environment=`, topic 098) or the cron job.
- **Containers:** `docker exec -it c bash` starts a **non-login** shell, so profile settings in the image may not apply; `bash -l` forces a login shell.
- **Security baselines:** a session timeout for idle shells (`TMOUT=900; readonly TMOUT` in a profile.d file) and the umask (topic 026).

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| Works over SSH but not in new terminal tabs | Set in a login-only file | Move it to `~/.bashrc` or a profile.d file |
| Missing after `su user` | `su` without `-` isn't a login shell | Use `su - user` |
| `scp` or `rsync` fail with "protocol error" | A startup file prints text | Guard output with `[[ $- == *i* ]]` |
| A profile.d script still runs after `chmod -x` | Only `.sh` and readability matter | Rename or remove it |
| PATH grows each time you start a nested shell | Unconditional append | Use the `case ":$PATH:"` guard |
| Every user gets broken shells | `/etc/profile` or `/etc/bashrc` damaged | Restore from backup; `rpm -V setup bash`, then reinstall |
| Variable set in a profile is missing in cron/systemd | They don't read profiles | Set it in the script or unit |

## Quick recap

- Login shells: `/etc/profile` → `profile.d/*.sh` → `~/.bash_profile` → `~/.bashrc` → `/etc/bashrc`. Non-login shells: `~/.bashrc` → `/etc/bashrc` → `profile.d`.
- One user: `~/.bashrc`. All users: `/etc/profile.d/x.sh`. Future users: `/etc/skel`. Non-shell sessions: `/etc/environment`.
- `source` applies to the current shell; `su -` gives a clean test; `bash -lx -c exit` traces startup.
- Scripts and cron don't read these files, and output in them breaks scp/rsync.

**Interview questions**

1. *`~/.bash_profile` vs `~/.bashrc`?* Login shells read `~/.bash_profile`; interactive non-login shells read `~/.bashrc`. On RHEL, `.bash_profile` sources `.bashrc`, so login shells get both.
2. *Is `su -` a login shell?* Yes. `su` without the dash is not, so profile files are skipped.
3. *How do you find which startup file sets a variable?* Trace a login shell with `bash -lx -c exit`, or grep for it across `/etc/profile*`, `/etc/bashrc` and `~/.bash*`.
