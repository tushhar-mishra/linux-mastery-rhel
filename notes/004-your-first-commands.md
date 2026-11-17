# 004 · Your First Commands: Prompt, Syntax and Exit Status

> **You need first:** [003 · Terminals, consoles and shells](003-terminals-consoles-and-shells.md)
> **Next:** [005 · Getting help](005-getting-help.md)

---

## What it is

A **command line** is one line of text you type at the shell's prompt and send with Enter. The shell (bash) reads it, works out what you mean, runs the program, and shows you the result.

Key words:

- **Prompt**: the text the shell prints when it is ready, such as `[alice@server1 ~]$`.
- **Command**: the first word. It names the program to run.
- **Option** (also called a flag or switch): changes *how* the command behaves. Options usually start with `-` or `--`.
- **Argument**: *what* the command works on, such as a file name or a user name.
- **Exit status** (exit code): a number every command returns when it finishes. `0` means success; anything else means some kind of failure.
- **Builtin**: a command built into bash itself (like `cd`).
- **External command**: a separate program file on disk (like `/usr/bin/ls`).

## Why it exists

Servers usually have no graphical desktop. The command line is faster, uses almost no resources, works over slow networks, and can be **scripted**: anything you type can be saved in a file and run again automatically. Every DevOps tool (Ansible, Docker, kubectl, cloud CLIs) follows the same "command, options, arguments" pattern.

## Analogy

A command line is a **sentence giving an order**:

```
ls      -l            /var/log
verb    how (adverb)  what (object)
```

"List — in long form — the folder /var/log." The exit status is the worker coming back and saying "done" (0) or "couldn't do it" (non-zero).

## How it works inside

### Reading the prompt

```
[alice@server1 ~]$        ← normal user
[root@server1 ~]#         ← root (the administrator)
```

| Part | Meaning |
|---|---|
| `alice` | Who you are |
| `server1` | Which machine. Always check this before typing dangerous commands |
| `~` | Which folder you're in. `~` is short for your **home directory** (your personal folder, like `/home/alice`) |
| `$` / `#` | `$` = normal user, `#` = **root**, the all-powerful admin account. Be careful at a `#` prompt |

Ubuntu's default prompt looks different: `alice@server1:~$`.

The prompt's look comes from a variable called `PS1` (variables are covered in topic 012). RHEL's default is `[\u@\h \W]\$`, where `\u` = user, `\h` = host, `\W` = current folder name, and `\$` = `#` for root or `$` for others.

### Command syntax

```
command  [options]  [arguments]
ls       -l -h      /var/log
```

| Rule | Example |
|---|---|
| Everything is **case-sensitive** | `ls -r` (reverse order) is not `ls -R` (recursive) |
| Short options use one dash and can be combined | `ls -l -a -h` = `ls -lah` |
| Long options use two dashes and can't be combined | `ls --all --human-readable` |
| Some options take a value | `head -n 5 file` or `head -n5 file` or `head --lines=5 file` |
| `--` means "no more options after this" | `rm -- -weird-name` deletes a file whose name starts with `-` |
| Many commands take several arguments | `cp a.txt b.txt /tmp/` (the last one is the destination) |
| A `\` at the very end of a line continues the command on the next line | `long command \` ↵ `--option value` |

### What bash does when you press Enter (simple version)

1. **Split** the line into words and operators (`|`, `;`, `>`). Spaces separate words, which is why file names with spaces need quotes (topic 011).
2. **Expand** shortcuts: `~` becomes your home folder, `*.log` becomes the matching file names, `$HOME` becomes its value (topics 012–014).
3. **Set up redirections**, for example `> file` (topic 016).
4. **Find the command.** bash checks, in order: an **alias** (a nickname, like `ll` for `ls -l`) → a shell **keyword** (`if`, `for`) → a shell **function** → a **builtin** → a program file found by searching the folders listed in the `PATH` variable.
5. **Run it.**
   - A **builtin** runs inside bash itself.
   - An **external program**: bash makes a copy of itself (a system call named `fork`), and the copy replaces itself with the program (a system call named `execve`). The original bash **waits** for it to finish. Topic 033 explains processes, and topic 092 goes deep.
6. **Store the exit status** in the special variable `$?` and print the prompt again.

**Why must `cd` be a builtin?** Each program has its own "current folder". A separate `cd` program would only change *its own* folder, then exit, and your shell would be unchanged. So `cd` must run inside the shell.

### Exit status

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | General failure |
| `2` | Wrong usage (bad option) for many commands |
| `126` | Found the file but couldn't run it (not executable) |
| `127` | Command not found |
| `128 + N` | Killed by signal number N. For example, `130` = 128+2 (Ctrl+C, SIGINT) and `137` = 128+9 (SIGKILL) |

Scripts, CI pipelines (automated build/test systems) and Kubernetes all decide "did it work?" from this number.

## Commands

```bash
whoami
```
```
alice
```
- Shows the user you are acting as **right now**.

```bash
hostname
```
```
server1.example.com
```
- The machine's name. `hostname NEWNAME` changes it only until reboot. `hostnamectl set-hostname NEWNAME` changes it permanently (topic 060).

```bash
pwd
```
```
/home/alice
```
- **P**rint **W**orking **D**irectory: which folder you're in.

```bash
ls -l /var/log
```
```
total 3528
drwxr-x---. 2 chrony chrony      6 Oct  3 10:12 chrony
-rw-------. 1 root   root    18321 Nov 16 09:00 cron
-rw-r--r--. 1 root   root   184212 Nov 16 08:50 dnf.log
-rw-------. 1 root   root   612455 Nov 16 09:44 messages
-rw-------. 1 root   root    48211 Nov 16 09:40 secure
```
- `ls` lists files. `-l` = long format. `/var/log` is the argument (which folder). Topic 007 explains every column.

```bash
date
```
```
Mon Nov 16 08:22:20 PM UTC 2026
```
- The format follows your **locale** (language and region settings, `LANG`). RHEL's default `en_US.UTF-8` gives a 12-hour clock with AM/PM. `LC_TIME=C date` prints the classic 24-hour form (`Mon Nov 16 20:22:20 UTC 2026`), which scripts should use, or better, an explicit format such as `date +%F_%T`.

```bash
cal -3
```
```
    October 2026         November 2026         December 2026
Su Mo Tu We Th Fr Sa  Su Mo Tu We Th Fr Sa  Su Mo Tu We Th Fr Sa
             1  2  3   1  2  3  4  5  6  7         1  2  3  4  5
...
```
- A calendar of the previous, current and next month.

```bash
uptime
```
```
 09:47:30 up 2 days,  3:03,  2 users,  load average: 0.00, 0.01, 0.00
```
- How long since boot, and the load averages (topic 034).

```bash
ls /nonexistent ; echo "exit status: $?"
```
```
ls: cannot access '/nonexistent': No such file or directory
exit status: 2
```
- `;` runs commands one after another. `$?` holds the exit status of the **last** command, here 2 (failure).

```bash
true ; echo $? ; false ; echo $?
```
```
0
1
```
- `true` and `false` do nothing except return 0 and 1. They're handy for testing.

```bash
type cd ls if
```
```
cd is a shell builtin
ls is aliased to `ls --color=auto'
if is a shell keyword
```
- `type` tells you **what kind** of command a name is. On RHEL, `ls` is an alias that adds colours.

```bash
type -a ls
```
```
ls is aliased to `ls --color=auto'
ls is /usr/bin/ls
```
- `-a` shows **all** matches in lookup order: first the alias, then the real program.

```bash
echo $SHELL ; echo $0
```
```
/bin/bash
-bash
```
- `$SHELL` is your **login shell** setting. `$0` is the shell **running now**. They can differ: if you start `zsh`, `$SHELL` still says `/bin/bash`.

```bash
passwd
```
```
Changing password for user alice.
Current password:
New password:
Retype new password:
passwd: password updated successfully
```
- Changes your own password. Nothing appears while you type a password; that is normal.

```bash
exit
```
- Leaves the shell. If it was your login shell, you log out. `Ctrl+D` on an empty line does the same.

### Keys that save hours

| Key | What it does |
|---|---|
| **Tab** | Completes a command, file name or option. **Tab Tab** lists the choices. Use it all the time; it prevents typos |
| **↑ / ↓** | Go through previous commands |
| **Ctrl+C** | Stop the running command |
| **Ctrl+D** | End of input; on an empty prompt, log out |
| **Ctrl+L** | Clear the screen |
| **Ctrl+A / Ctrl+E** | Jump to the start / end of the line |
| **Ctrl+U / Ctrl+K** | Delete from the cursor to the start / end of the line |
| **Ctrl+W** | Delete the previous word |
| **Ctrl+R** | Search your command history (topic 015) |
| **Alt+.** | Paste the last argument of the previous command |
| **Ctrl+Z** | Pause the running command (`fg` brings it back, topic 033) |

### Try it
1. Run `whoami`, `hostname`, `pwd`, `date`, `uptime`.
2. Run `ls /etc/hosts` then `echo $?`. Then run `ls /nope` then `echo $?`. Compare.
3. Run `type pwd echo ls cd ll` and note which are builtins, aliases or files.
4. Type `ls /etc/sys` and press Tab twice.

## Where you'll use it

- **Every day, everywhere.** Each tool (kubectl, docker, aws, git, terraform) follows `command [options] [arguments]`.
- **Exit codes drive automation.** CI jobs fail when a step returns non-zero. Kubernetes restarts containers based on exit codes and health checks that return 0 or non-zero. `137` in a pod status means "killed by SIGKILL", very often by the out-of-memory killer (topic 093).
- **Check the prompt before destructive commands.** Many outages started with `rm` or `reboot` typed on the wrong host. The `user@host` in the prompt is your safety check.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `bash: foo: command not found` (exit 127) | Typo, program not installed, or its folder isn't in `PATH` | Check spelling; `type foo`; `echo $PATH`; install the package (`dnf provides '*/foo'`, topic 031) |
| `bash: ./script.sh: Permission denied` (exit 126) | The file isn't marked executable, or the disk is mounted with `noexec` | `chmod +x script.sh` (topic 026); check mount options (topic 048) |
| `ls: invalid option -- 'z'` | A wrong option letter | Check `ls --help` (topic 005) |
| A command behaves differently than expected | An alias or function with the same name | `type -a cmd`; run the real one with `\cmd` or `command cmd` |
| `rm: invalid option` when deleting `-file` | The file name looks like an option | `rm -- -file` or `rm ./-file` |
| Typed a command on the wrong server | Didn't read the prompt | Always check `user@host`; make production prompts colourful |

## Quick recap

- Syntax: `command [options] [arguments]`. Case matters. `--` ends the options.
- The prompt shows user, host and folder; `#` means you're root.
- bash expands the line, finds the command (alias → keyword → function → builtin → PATH), runs it, and saves the exit status in `$?`.
- `0` = success. `127` = not found. `126` = not executable. `128+N` = killed by signal N.

**Interview questions**

1. *What happens when you type `ls -l` and press Enter?* Bash splits and expands the line, finds `ls` (alias → builtin → PATH), forks a child process, which runs `/usr/bin/ls` with `execve`. Bash waits, then saves the exit status in `$?`.
2. *Builtin vs external command?* A builtin runs inside the shell process (`cd`, `echo`, `export`). An external command is a separate program file run in a child process. `type` tells you which.
3. *What does exit code 137 mean?* 128 + 9: the process was killed by SIGKILL. Typical causes are `kill -9`, the out-of-memory killer, or a container runtime enforcing a memory limit.
