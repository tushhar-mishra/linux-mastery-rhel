# Shell Basics & Command Syntax

> **Baseline:** RHEL 10, bash 5.x
> **Related:** [Getting help](getting-help-and-documentation.md) · [Files & directories](files-and-directories.md) · [SSH & switching users](../networking-and-ssh/ssh-remote-access.md) · [Quoting & control operators](quoting-and-control-operators.md) · [Variables](shell-variables-and-environment.md)

## 1. Overview

The **shell** is a user-space program that reads a command line, interprets it (expansions, redirections), finds the program to run, and asks the kernel to execute it. On RHEL the default shell is **bash** (Bourne Again Shell). Every RHCSA task is done through the shell, so syntax precision and speed matter.

**Terminal vs. shell vs. console** **[Interview Knowledge]**

| Term | What it is | Example |
|---|---|---|
| Terminal / terminal emulator | Window or device that displays text and sends keystrokes | GNOME Terminal, PuTTY |
| Console | The physical or virtual text terminal of the machine | `tty1`–`tty6` (`Ctrl+Alt+F2`…) |
| TTY / PTS | Kernel device for a terminal | `/dev/tty2` (console), `/dev/pts/0` (SSH or GUI terminal) |
| Shell | Program that interprets commands inside the terminal | `/usr/bin/bash` |

```bash
tty            # /dev/pts/0 → pseudo-terminal (SSH/GUI); /dev/tty2 → console
```

## 2. Key Concepts

### 2.1 Shell types

| Shell | Notes | On RHEL |
|---|---|---|
| **bash** | Bourne Again Shell; default on RHEL | Installed; `/bin/bash` → `/usr/bin/bash` |
| **sh** | POSIX shell interface. The Bourne shell (1979) wasn't the first UNIX shell; the Thompson shell was | `/bin/sh` is a symlink to **bash**, which runs in POSIX mode |
| **csh / tcsh** | C-like syntax. **tcsh = TENEX C shell** (not "Turbo") | Installable if available in repos |
| **ksh** | Korn shell, strong scripting features | Installable if available in repos |
| **zsh** | Rich interactive features | Installable (`dnf install zsh`) |

```bash
cat /etc/shells                 # shells allowed as login shells
dnf list --available zsh tcsh ksh   # check repo availability before relying on them
```

### 2.2 Login shell vs. current shell

| Question | Command | Note |
|---|---|---|
| What is my **login** shell (from `/etc/passwd`)? | `echo $SHELL` or `getent passwd $USER \| cut -d: -f7` | `$SHELL` does **not** change when you start another shell |
| What shell am I **running now**? | `ps -p $$ -o comm=` or `echo $0` | `$$` = PID of the current shell. `echo $0` printing `-bash` (leading dash) means a **login shell** |

> ⚠️ **Common misconception:** `echo $SHELL` does not show the shell you are currently using. Run `zsh`, then `echo $SHELL`, and it still says `/bin/bash`.

### 2.3 How bash processes a command line **[Interview Knowledge]**

1. **Read and tokenize** the line into words and operators (`|`, `;`, `&&`, `>`).
2. **Expand:** brace → tilde → parameter/variable → command substitution → arithmetic → word splitting → globbing ([expansion note](shell-expansion-and-globbing.md)).
3. **Remove quotes.**
4. **Set up redirections** ([redirection note](../files-and-text-processing/io-redirection-and-pipes.md)).
5. **Look up the command,** in this order: alias → keyword → function → builtin → hashed path / `$PATH` search.
6. **Execute.** Builtins run inside the shell. External programs run via `fork()` + `execve()`, and the shell waits, then stores the exit status in `$?`.

**Why must `cd` be a builtin?** A child process can't change its parent's working directory. An external `cd` would change only its own directory, then exit.

```bash
type cd ls ll if            # cd is a shell builtin; ls is aliased…; if is a shell keyword
type -a ls                  # all matches: alias AND /usr/bin/ls
```

### 2.4 The prompt

RHEL's default prompt (set in `/etc/bashrc`):

```
[alice@servera ~]$        ← normal user
[root@servera ~]#         ← root
```

| Escape | Meaning | Escape | Meaning |
|---|---|---|---|
| `\u` | Username | `\w` | Full working directory (`~` abbreviated) |
| `\h` | Short hostname | `\W` | Last component of the working directory (RHEL default) |
| `\H` | Full hostname | `\$` | `#` if UID 0, else `$` |
| `\t` | Time HH:MM:SS | `\n` | Newline |

```bash
echo "$PS1"                                  # RHEL default: [\u@\h \W]\$
PS1='[\u@\h \w]\$ '                          # current shell only
echo "PS1='[\u@\h \w]\\$ '" >> ~/.bashrc     # persistent for this user
```

- `PS2` is the continuation prompt (`> `), shown when a command is incomplete (open quote, trailing `\`). All PS0–PS4 variables are covered in the [variables note](shell-variables-and-environment.md#5-prompt-variables-ps0ps4).

> ℹ️ `user@host:~$` is the Debian/Ubuntu default prompt, not RHEL's.

### 2.5 Command syntax

```
command  [options]  [arguments]
ls       -l -h      /var/log
```

| Element | Rules |
|---|---|
| Command | Program, builtin, alias or function name. **Case-sensitive** |
| Short options | `-l -a` = `-la` (combinable). Case matters: `ls -r` (reverse) ≠ `ls -R` (recursive) |
| Long options | `--all`, `--human-readable`. Not combinable. Value via `--lines=5` or `--lines 5` |
| Option arguments | `-n 5` or `-n5` (e.g., `head -n 5`) |
| `--` | End of options; everything after is an argument: `rm -- -weird-file` |
| Arguments | Files, directories, users, PIDs; usually several allowed |
| Exit status | `$?`: `0` = success, non-zero = failure (check with `echo $?`) |

```bash
cp file1.txt file2.txt /tmp/        # multiple sources → last argument must be a directory
ls -l /etc | less                   # pipe: stdout of ls → stdin of less
cmd1 ; cmd2                         # run sequentially
mkdir /data && cd /data             # run cmd2 only if cmd1 succeeded
long command \                      # backslash continues a line
  --option value
```

> ⚠️ **Common misconception:** `ls -l | grep ".txt"` also matches names like `atxt`, because `.` in a regex means "any character." Use `ls *.txt`, or `grep '\.txt$'` when filtering text.

### 2.6 Time-saving keys **[RHCSA Core]**

| Key | Action |
|---|---|
| `Tab` / `Tab Tab` | Complete command, path or option / list candidates. **Use constantly**; it prevents typos |
| `Ctrl+C` | Interrupt (SIGINT) the running command |
| `Ctrl+D` | End of input; at an empty prompt → log out |
| `Ctrl+Z` then `fg` / `bg` | Suspend a job, then resume it in the foreground / background |
| `Ctrl+L` | Clear the screen |
| `Ctrl+A` / `Ctrl+E` | Start / end of line |
| `Ctrl+U` / `Ctrl+K` / `Ctrl+W` | Delete to start / to end / previous word |
| `Ctrl+R` | Reverse-search history ([history note](command-history.md)) |
| `Alt+.` | Insert the last argument of the previous command |
| `Ctrl+S` / `Ctrl+Q` | Freeze / resume terminal output (if the terminal "hangs," try `Ctrl+Q`) |

## 3. First Commands

| Task | Command | Notes |
|---|---|---|
| Logged-in users | `who`, `w` | Details in [SSH note §4](../networking-and-ssh/ssh-remote-access.md#4-logging-in-and-switching-users-rhcsa-core) |
| Current identity | `whoami` vs. `who am i` | `whoami` = **effective** user now; `who am i` = **original login** (still shows `alice` after `su -`; may print nothing in some GUI terminals) |
| Hostname | `hostname`, `hostnamectl` | `hostname NAME` is **temporary**. `hostnamectl set-hostname NAME` is **persistent** ([nmcli §9](../networking-and-ssh/networkmanager-nmcli.md)) |
| Change password | `passwd` (self), `sudo passwd alice` (other user) | pwquality may reject weak passwords for normal users |
| Date/time | `date`, `timedatectl` | NTP client setup: [chrony](../system-services-and-shared-storage/chrony-time-sync.md) |
| Calendar | `cal`, `cal 2026`, `cal -3` | |
| Log out | `exit`, `logout`, `Ctrl+D` | |

## 4. Commands

```bash
echo $SHELL; ps -p $$ -o comm=; echo $0       # login shell vs running shell
cat /etc/shells                               # valid login shells
getent passwd alice                           # alice:x:1001:1001::/home/alice:/bin/bash
sudo usermod -s /bin/zsh alice                # change login shell (root, reliable)
chsh -s /bin/zsh                              # user self-service; needs util-linux-user + shell in /etc/shells
type -a <cmd>; command -v <cmd>               # how a name resolves
echo $PATH                                    # external command search path
```

## 5. RHCSA Exam Focus **[RHCSA Core]**

- Correct syntax, exact paths and names. **Tab completion** is your typo insurance.
- Read error messages fully. They usually say exactly what's wrong.
- Classic task: a user with **no interactive login**: `useradd -s /sbin/nologin svcuser` ([local users](../users-groups-and-permissions/local-users.md)). `/sbin/nologin` prints "This account is currently not available."
- Changing a shell: `usermod -s` works for any user as root and doesn't depend on `chsh` being installed.
- Quote paths containing spaces: `cd "/tmp/my dir"`.

## 6. Production Practices **[Production Practice]**

- Scripts declare their interpreter (`#!/bin/bash`). Never depend on a user's interactive shell.
- Put the **hostname in the prompt** (RHEL does by default) and consider a colored PS1 on production hosts to avoid running commands on the wrong server.
- Avoid slow commands in `PS1`/`PROMPT_COMMAND`; they run before every prompt.
- Bypass a surprising alias with `\cmd` or `command cmd`.

## 7. Troubleshooting

| Symptom | Diagnose | Fix |
|---|---|---|
| `bash: foo: command not found` | Typo? `type foo`; `echo $PATH`; `dnf provides '*/foo'` | Install the package; use the full path; add the directory to PATH. Note that `sudo` uses its own `secure_path` |
| `bash: ./script: Permission denied` | `ls -l script`; `findmnt -no OPTIONS --target .` | `chmod +x`; or the filesystem is mounted `noexec` |
| User can't log in after a shell change | `getent passwd user`; `cat /etc/shells`; `ls -l <shell>` | As root: `usermod -s /bin/bash user` |
| `chsh: command not found` | `rpm -q util-linux-user` | `dnf install util-linux-user`, or use `usermod -s` |
| Command behaves unexpectedly | `type -a cmd` | It's an alias or function; use `\cmd` |
| Terminal frozen, no output | Pressed `Ctrl+S`? | `Ctrl+Q` |
| Prompt change lost after logout | Was it set only interactively? | Put it in `~/.bashrc` |

## 8. Interview Questions

| Question | Answer |
|---|---|
| What happens when you type `ls -l` and press Enter? | Bash tokenizes and expands the line, resolves `ls` (alias → builtin → PATH), forks a child, which `execve`s `/usr/bin/ls`. The parent waits and records the exit status in `$?`. |
| Builtin vs. external command? | Builtins run inside the shell process (`cd`, `echo`, `export`). External commands are separate executables run in child processes. `type` tells you which. |
| Why is `cd` a builtin? | A child process can't change its parent's working directory. |
| Login vs. non-login shell? | Login shells (console/SSH login, `su -`, `bash -l`) read the profile files; non-login interactive shells read `~/.bashrc`. `$0` starting with `-` indicates a login shell ([startup files](../users-groups-and-permissions/shell-startup-files.md)). |
| What does `--` do? | Marks the end of options, so arguments starting with `-` are treated as filenames. |
| `whoami` vs. `who am i`? | Effective user vs. the user recorded for the original login session. |
| `/sbin/nologin` vs. `/bin/false`? | Both deny interactive login. `nologin` prints a polite message and is the RHEL convention for service accounts. |

## 9. Quick Revision

```bash
ps -p $$ -o comm=      # current shell        echo $SHELL     # login shell
type -a cmd            # alias/builtin/file   echo $?         # last exit status
usermod -s /sbin/nologin user                 # deny interactive login
PS1='[\u@\h \W]\$ '    # RHEL default prompt  hostnamectl set-hostname NAME   # persistent
```

## 10. Cross-References

- [Getting help & documentation](getting-help-and-documentation.md)
- [Files & directories](files-and-directories.md)
- [Login & switching users](../networking-and-ssh/ssh-remote-access.md#4-logging-in-and-switching-users-rhcsa-core)
- [Quoting & control operators](quoting-and-control-operators.md) · [Variables](shell-variables-and-environment.md) · [Substitution & options](command-substitution-and-shell-options.md) · [History](command-history.md) · [Expansion & globbing](shell-expansion-and-globbing.md)
- [Profile files (`~/.bashrc`, `/etc/profile`)](../users-groups-and-permissions/shell-startup-files.md) · [Processes & system calls (fork/exec in depth)](../processes-and-resource-management/processes-and-system-calls.md)
