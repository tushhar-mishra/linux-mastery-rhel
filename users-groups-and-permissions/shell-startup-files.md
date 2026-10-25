# Shell Startup (Profile) Files

> **Sessions:** S23 · Supports user environment tasks (PATH, umask, aliases, variables) **[RHCSA Core]**
> **Related:** [Variables & environment](../shell-and-command-line/shell-variables-and-environment.md) · [Command history](../shell-and-command-line/command-history.md) · [Local users (`/etc/skel`)](local-users.md) · [umask](file-permissions.md#33-umask-default-permissions-rhcsa-core)

## 1. Overview

When bash starts, it reads startup files that set variables, `PATH`, `umask`, aliases, functions and the prompt. **Which** files run depends on whether the shell is a **login** shell and whether it's **interactive**. Most "my setting didn't apply" problems come from putting a setting in the wrong file.

## 2. Shell Types

| Type | Examples | How to check |
|---|---|---|
| Login, interactive | Console/SSH login, `su - user`, `sudo -i`, `bash -l` | `shopt -q login_shell && echo login`; `echo $0` shows `-bash` |
| Non-login, interactive | New terminal tab in GNOME, typing `bash`, `su user`, `sudo -s` | `shopt login_shell` → off |
| Non-interactive | Scripts, `bash -c '…'`, cron jobs | `[[ $- == *i* ]]` is false |

## 3. Files and Order on RHEL

| File | Scope | Read by |
|---|---|---|
| `/etc/profile` | All users | Login shells; it sources `/etc/profile.d/*.sh` |
| `/etc/profile.d/*.sh` | All users (drop-ins) | Via `/etc/profile`; also via `/etc/bashrc` for non-login interactive shells |
| `~/.bash_profile` | One user | Login shells (bash reads the **first** that exists of `~/.bash_profile`, `~/.bash_login`, `~/.profile`) |
| `~/.bashrc` | One user | Interactive non-login shells; RHEL's `~/.bash_profile` sources it, so login shells get it too |
| `/etc/bashrc` | All users | Sourced by `~/.bashrc` on RHEL (aliases, PS1, umask, history defaults) |
| `~/.bash_logout` | One user | Run by bash itself when a **login** shell exits |
| `/etc/environment` | All sessions | Read by `pam_env` at login (simple `KEY=value`, not a shell script) |

**Login shell (e.g., SSH, `su -`):**

```
/etc/profile → /etc/profile.d/*.sh → ~/.bash_profile → ~/.bashrc → /etc/bashrc
… at exit: ~/.bash_logout
```

**Non-login interactive shell (e.g., new terminal tab, `bash`):**

```
~/.bashrc → /etc/bashrc → /etc/profile.d/*.sh (sourced by /etc/bashrc when not a login shell)
```

On RHEL 9/10, the default `~/.bashrc` (from `/etc/skel`) also adds `~/.local/bin:~/bin` to `PATH` and sources any files in `~/.bashrc.d/`.

> ⚠️ **Course corrections:**
> - `~/.bash_logout` is **not** sourced by `~/.bash_profile`; bash runs it at login-shell exit.
> - `chmod -x` does **not** disable a `profile.d` script. `/etc/profile` sources every *readable* `*.sh` file; rename it so it no longer ends in `.sh` (or remove it).

## 4. Where to Put What

| Setting | Best place |
|---|---|
| Your aliases, functions, prompt, history settings | `~/.bashrc` (or a file in `~/.bashrc.d/`) |
| Your environment variables (`EDITOR`, `PATH` additions) | `~/.bashrc` or `~/.bash_profile` (`export`) |
| System-wide variables/functions for all users | `/etc/profile.d/custom.sh` (don't edit `/etc/profile` itself; updates may replace it) |
| Variables for **non-shell** sessions too (GUI, some services) | `/etc/environment` (`KEY=value`, no `export`, no `$VAR` expansion) |
| Defaults for **new** users' dotfiles | `/etc/skel/` |
| Commands at logout | `~/.bash_logout` (per user); system-wide needs PAM (`pam_exec`) **[Advanced]** |

### Examples

```bash
# /etc/profile.d/editor.sh  — all users, all bash sessions
export EDITOR=vim

# /etc/profile.d/custom_path.sh — add a directory to PATH only once
case ":$PATH:" in
  *:/opt/myapp/bin:*) ;;
  *) export PATH="/opt/myapp/bin:$PATH" ;;
esac

# /etc/profile.d/hello.sh — a function for everyone
hello() { echo "Hello, $USER!"; }

# ~/.bash_profile (RHEL default) — makes login shells load ~/.bashrc
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi
```

## 5. Applying and Debugging Changes

```bash
source ~/.bashrc          # or: . ~/.bashrc   — apply to the CURRENT shell
source /etc/profile       # re-run system login setup in this shell
su - "$USER"              # or log out/in: a clean login shell rereads everything
bash -lx -c exit 2>&1 | less     # trace every line a login shell executes at startup
bash --noprofile --norc   # start a shell with no startup files (isolate the culprit)
env | sort ; declare -p VAR      # inspect results
```

Changes to profile files never affect shells that are already running.

## 6. RHCSA Exam Focus

- "Set variable/alias/umask for user X permanently": put it in `~X/.bashrc` (or `~X/.bash_profile` for login-only), then verify with `su - X`.
- "For all users": a file in `/etc/profile.d/` ending in `.sh`.
- "Users created in the future get file Y": `/etc/skel/`.
- Always test with a **login** shell (`su - user`); `su user` skips profile files.

## 7. Production Practices **[Production Practice]**

- Use drop-in files (`/etc/profile.d/*.sh`, `~/.bashrc.d/`) instead of editing distro-owned files.
- Keep startup files fast and silent; output from them can break `scp`, `rsync` and other non-interactive SSH tools.
- Guard interactive-only code: `[[ $- == *i* ]] || return`.
- Don't put `set -e` or `exit` in startup files (see the [shell options note](../shell-and-command-line/command-substitution-and-shell-options.md)).

## 8. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Setting works in SSH but not in new terminal tabs | Put in a login-only file | Move to `~/.bashrc` / `profile.d` |
| Setting missing after `su user` | Non-login switch skips profiles | `su - user` |
| `scp`/`rsync` fail with "protocol error" | A startup file prints output | Guard with `[[ $- == *i* ]]` |
| `profile.d` script still runs after `chmod -x` | Only readability and `.sh` suffix matter | Rename it or remove it |
| `PATH` grows on every new shell | Unconditional append | Use the `case ":$PATH:"` guard |
| Users get broken shells / missing PATH | `/etc/profile` damaged | Restore from backup or `rpm -V setup` / reinstall the `setup` package |

## 9. Interview Questions

| Question | Answer |
|---|---|
| `~/.bash_profile` vs `~/.bashrc`? | Login shells read `.bash_profile`; interactive non-login shells read `.bashrc`. RHEL's `.bash_profile` sources `.bashrc`. |
| Is `su -` a login shell? | Yes; `su` without `-` is not. |
| `/etc/environment` vs `/etc/profile`? | `/etc/environment` is plain `KEY=value` read by PAM for all sessions; `/etc/profile` is a shell script for login shells. |
| How do you disable a script in `/etc/profile.d`? | Rename it away from `*.sh` or remove it; execute permission doesn't matter. |
| How do you debug which startup file sets a variable? | `bash -lx -c exit`, or `grep -r VAR /etc/profile /etc/profile.d /etc/bashrc ~/.bash*`. |

## 10. Course Practice (S23, corrected where needed)

Questions 1–8, 10, 11, 13, 14, 16–18 and 20 are correct as given. Corrections:

| # | Course | Correction |
|---|---|---|
| 2 | SSH reads `/etc/profile`, then `~/.bash_profile` **or** `~/.profile` | Bash reads only the **first** existing of `~/.bash_profile`, `~/.bash_login`, `~/.profile` |
| 5 | `/etc/bashrc` is sourced by non-login shells | On RHEL it's sourced by `~/.bashrc`, which login shells also load via `~/.bash_profile` |
| 9 | `chmod -x` disables a profile.d script | It doesn't; rename or remove |
| 12 | `~/.bash_profile` may source `~/.bash_logout` | `.bash_logout` is run by bash at login-shell exit |
| 15 | Logout script via `/etc/pam.d/system-auth` | Possible with `pam_exec` in the session stack **[Advanced]**; per-user `~/.bash_logout` is the simple route |
| 19 | Debug with echo/`set -x` | Also `bash -lx -c exit` and `bash --noprofile --norc` |

## 11. Quick Revision

```
LOGIN:     /etc/profile → profile.d/*.sh → ~/.bash_profile → ~/.bashrc → /etc/bashrc   (exit: ~/.bash_logout)
NON-LOGIN: ~/.bashrc → /etc/bashrc → profile.d/*.sh
All users: /etc/profile.d/x.sh   One user: ~/.bashrc   New users: /etc/skel   Non-shell: /etc/environment
source ~/.bashrc | su - user | bash -lx -c exit | bash --noprofile --norc | shopt login_shell
```

## 12. Cross-References

- [Variables & environment (PATH, export)](../shell-and-command-line/shell-variables-and-environment.md)
- [Command history (HIST* settings)](../shell-and-command-line/command-history.md)
- [Shell basics (prompt)](../shell-and-command-line/shell-basics-and-command-syntax.md)
- [Local users (`/etc/skel`)](local-users.md)
- [umask](file-permissions.md#33-umask-default-permissions-rhcsa-core) · [PAM & authselect](pam-and-authselect.md)
