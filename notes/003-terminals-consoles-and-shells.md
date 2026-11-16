# 003 · Terminals, Consoles and Shells

> **You need first:** [002 · Build your practice lab](002-build-your-practice-lab.md)
> **Next:** [004 · Your first commands](004-your-first-commands.md)

---

## What it is

When you "use the command line", three separate things work together. Beginners mix them up all the time.

| Thing | What it is | Example |
|---|---|---|
| **Terminal** | The "screen and keyboard" part. It shows text and sends your key presses | A text console, the GNOME Terminal window, an SSH session in Windows Terminal or PuTTY |
| **Shell** | The program that **reads your commands and runs them** | `bash` (default on RHEL and Ubuntu), `zsh`, `sh` |
| **Command** | The program the shell starts for you | `ls`, `cp`, `systemctl` |

So: the terminal shows the text, the shell understands it, and the commands do the work.

Now the device words. They look scary, but they're simple:

- **/dev** (short for "devices") is a folder where Linux shows hardware and virtual devices as files. Linux treats almost everything as a file (topic 001). To talk to a device, a program reads or writes its file.
- **TTY** (TeleTYpewriter) comes from the 1960s. Back then a "terminal" was a real typewriter wired to the computer. Today a TTY means a **text terminal the kernel provides directly**. On a machine with a screen, press **Ctrl+Alt+F2** to **F6** to switch to one. They appear as `/dev/tty1`, `/dev/tty2`, and so on.
- **Console** is the terminal physically attached to the machine: its own screen and keyboard (or, for a VM, the window your hypervisor shows). `/dev/console` is where the kernel writes its boot messages.
- **PTY** (Pseudo-TeleTYpewriter, "pseudo-terminal") is a *fake* terminal that software creates. It comes as a pair:
  - The **master** side is held by a program such as the SSH server or your GUI terminal window.
  - The **PTS** (Pseudo-Terminal Slave) side is what your shell sees. It appears as `/dev/pts/0`, `/dev/pts/1`, and so on. Newer documents sometimes call this side the "subsidiary".
- **Serial console** is a terminal over a serial cable or its virtual version, `/dev/ttyS0`. Cloud providers use it for their "emergency console" feature.

## Why it exists

Programs like `bash` were written to talk to a terminal: read keys, print text. Today almost nobody uses a real hardware terminal. We connect over the network (SSH) or open a window in a desktop. Pseudo-terminals let these modern connections *pretend* to be an old-style terminal, so `bash`, `vim`, `top` and every other tool work unchanged.

The extra TTYs (Ctrl+Alt+F2 and so on) exist so you can still get in when the graphical desktop is frozen or broken.

## Analogy

The house has many doors:

- The **GUI** (graphical desktop) is the front door.
- The **TTYs** (Ctrl+Alt+F2–F6) are spare side doors into the same house. If the front door is jammed (the desktop has frozen), you walk in through a side door and fix things.
- A **PTS** is a phone line into the house. When you SSH in from your laptop, the SSH server creates a "virtual door" (the PTS) for you. Each new call gets a new line number: `/dev/pts/0`, `/dev/pts/1`, …
- The **shell** is the butler standing behind whichever door you used. It takes your instructions and gets them done.

## How it works inside

### What happens when you SSH in

1. Your SSH client connects to the SSH server program (`sshd`) on the server (topic 065).
2. After you log in, `sshd` asks the kernel for a new pseudo-terminal pair. The kernel creates `/dev/pts/N`.
3. `sshd` keeps the **master** end. It starts your **shell** (for example `bash`) with the **slave** end, `/dev/pts/N`, as its keyboard input and screen output.
4. You type `ls`. Your key presses travel over the network → `sshd` → the master end → the kernel's terminal layer → `/dev/pts/N` → `bash`.
5. `bash` runs `ls`. The output goes back the same way in reverse and appears on your laptop screen.
6. When you log out, `bash` exits, `sshd` closes the master, and `/dev/pts/N` disappears. The number is reused later.

### The kernel's terminal layer (the "line discipline")

Between the terminal and the shell, the kernel runs a small piece of logic called the **line discipline**. It handles:

- **Echo**: showing the letters you type.
- **Line editing**: Backspace works before you press Enter.
- **Special keys**, which it turns into **signals**. A signal is a short message the kernel sends to a running program (topic 033). For example:
  - **Ctrl+C** → "interrupt" (stop the current command)
  - **Ctrl+Z** → "stop" (pause it)
  - **Ctrl+D** at the start of a line → "end of input" (the shell exits)
  - **Ctrl+S / Ctrl+Q** → pause / resume the screen output

This is why **Ctrl+S "freezes" a terminal**: it's flow control from the typewriter days, not a crash. Press **Ctrl+Q** to resume.

`stty -a` shows these settings. `reset` repairs a terminal left in a weird state (for example, after you `cat` a binary file and the screen fills with garbage).

### Login: from terminal to shell

On a text console (TTY), a program called **`agetty`** waits at each TTY and shows the `login:` prompt. When you type a name and password, the `login` program checks them and starts your shell. Over SSH, `sshd` does the same job. Either way, you end up in a **login shell**: a shell started because you logged in. It reads extra start-up files (topic 025).

Opening a new terminal tab in a desktop, or typing `bash` inside a shell, gives you a **non-login shell**.

### Which shell?

| Shell | Notes |
|---|---|
| `bash` (Bourne Again SHell) | Default on RHEL and Ubuntu for users. Everything in these notes uses bash |
| `sh` | The basic POSIX shell. On RHEL, `/bin/sh` is bash in compatibility mode. On **Ubuntu/Debian**, `/bin/sh` is **`dash`**, a smaller, faster shell. Scripts that use bash-only features but start with `#!/bin/sh` break on Ubuntu (topic 040) |
| `zsh` | Popular on desktops (macOS default) |
| `nologin` | Not a real shell. It refuses logins. Used for service accounts (topic 022) |

The list of shells allowed for login is in the file `/etc/shells`.

## Commands

```bash
tty
```
```
/dev/pts/0
```
- Prints **which terminal device** your shell is connected to. `/dev/pts/0` means you're on a pseudo-terminal (SSH or a GUI window). On a text console you'd see `/dev/tty2`.

```bash
who
```
```
vagrant  pts/0        2026-11-16 09:12 (192.168.56.1)
alice    pts/1        2026-11-16 09:40 (10.0.0.25)
root     tty2         2026-11-16 08:55
```
- Lists who is logged in **right now**.
- Column 1 is the user name. Column 2 is the terminal: `pts/N` means a pseudo-terminal (usually SSH), `ttyN` means the local console.
- Next comes the login time. The part in brackets is **where they came from**: the remote IP address for SSH. Local console logins have nothing in brackets.

```bash
w
```
```
 09:45:02 up 2 days,  3:01,  3 users,  load average: 0.08, 0.03, 0.01
USER     TTY      FROM             LOGIN@   IDLE   JCPU   PCPU  WHAT
vagrant  pts/0    192.168.56.1     09:12    0.00s  0.05s  0.00s w
alice    pts/1    10.0.0.25        09:40    4:30   0.02s  0.02s vim app.conf
root     tty2     -                08:55    50:10  0.01s  0.01s -bash
```
- Like `who`, but it also shows **what each person is doing**.
- First line: current time, **uptime** (how long since the last boot), number of users, and **load average** (how busy the system is, topic 034).
- `IDLE`: time since they last pressed a key. `WHAT`: the command they are running now. `-bash` with a dash means a login shell sitting at its prompt.

```bash
echo $0
```
```
-bash
```
- `$0` holds the name of the running shell. A leading `-` means it is a **login shell**.

```bash
ps -p $$
```
```
    PID TTY          TIME CMD
   2381 pts/0    00:00:00 bash
```
- `$$` is your shell's process ID (PID: a unique number for each running program, topic 033). `ps -p` shows that process. The `TTY` column confirms your terminal is `pts/0`.

```bash
ls -l /dev/pts/
```
```
total 0
crw--w----. 1 vagrant tty  136, 0 Nov 16 09:45 0
crw--w----. 1 alice   tty  136, 1 Nov 16 09:45 1
c---------. 1 root    root   5, 2 Nov 16 08:50 ptmx
```
- Each number is a live pseudo-terminal. The first letter `c` means **character device**: a device you read and write as a stream of bytes, like a keyboard.
- The owner is the logged-in user, which is why `alice` can't type into your terminal.
- `136, 0` are the device's **major and minor numbers**. The major (136) tells the kernel "this is the pts driver"; the minor (0) says which one.
- `ptmx` is the special "PTY master multiplexer" file programs open to get a new pseudo-terminal.

```bash
cat /etc/shells
```
```
/bin/sh
/bin/bash
/usr/bin/sh
/usr/bin/bash
```
- The valid login shells on this system.

```bash
stty -a | head -3
```
```
speed 38400 baud; rows 48; columns 160; line = 0;
intr = ^C; quit = ^\; erase = ^?; kill = ^U; eof = ^D; eol = <undef>;
eol2 = <undef>; swtch = <undef>; start = ^Q; stop = ^S; susp = ^Z; rprnt = ^R;
```
- The terminal settings. `^C` means Ctrl+C. `intr = ^C` maps Ctrl+C to "interrupt", `susp = ^Z` maps Ctrl+Z to "suspend", `stop = ^S` / `start = ^Q` are the freeze/unfreeze keys.
- `rows 48; columns 160` is the window size. Tools like `top` use it to fit the screen.

```bash
reset
```
- Re-initialises a garbled terminal. Type it blind if the screen is full of junk, then press Enter.

### Try it
1. SSH into server1 twice (two windows). In each, run `tty`, then `who`. See `pts/0` and `pts/1`.
2. In the VirtualBox window (the console), log in at the text prompt and run `tty`. You'll see `/dev/tty1`. If it has a desktop, press Ctrl+Alt+F3 to go to another TTY.
3. Run `cat /usr/bin/ls` to scramble your terminal, then type `reset`.
4. Press Ctrl+S, type something (nothing appears), then press Ctrl+Q and watch it appear.

## Where you'll use it

- **Security checks:** `who` and `w` show who is logged in and from which IP. If you spot an unknown login on `pts/3` from a strange address, that's an incident.
- **"Who is editing this file?":** `w` shows `vim app.conf` on someone's pts before you restart a service.
- **Rescue:** when a server's desktop or network is broken, you use the **console** (the cloud provider's serial console, or a VM console) to get in. That's a TTY, not SSH.
- **Programs that need a terminal:** some commands refuse to run without one. That's why `ssh -t host sudo …` exists (`-t` forces a pseudo-terminal). Containers have the same idea: `docker run -it` (`-t` allocates a pseudo-terminal, `-i` keeps input open).
- **Scripts:** `[ -t 0 ]` tests whether input comes from a terminal, so a script can tell "a human typed this" from "this was run by cron".

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| Terminal "frozen", nothing appears when you type | You pressed Ctrl+S (output paused) | Press **Ctrl+Q** |
| Screen full of strange symbols after viewing a file | A binary file sent control codes that changed terminal settings | Type `reset` and press Enter |
| A command says `the input device is not a TTY` or `sudo: a terminal is required` | It runs without a terminal (from a script, cron or a pipe) but needs one for a password prompt | Use `ssh -t`, `docker exec -it`, or configure the tool not to prompt |
| Backspace prints `^?` or `^H` | The terminal and the system disagree about the erase key | `stty erase ^?` (or `^H`), or set the right terminal type in your client |
| `top` or `vim` draws badly | The `TERM` variable names a terminal type the system doesn't know | `echo $TERM`; use `export TERM=xterm-256color` |
| GUI frozen and you can't get in | Desktop crashed | Ctrl+Alt+F3 for a text TTY, log in, then fix or restart the display manager |
| SSH session dies when idle | A network device dropped the idle connection | Use client keep-alives (`ServerAliveInterval`, topic 065) or `tmux` |

**`tmux` and `screen`** are "terminal multiplexers". They run your shells inside a session that survives disconnection. If SSH drops during a long job, reconnect and run `tmux attach`, and the job is still there. Use one for anything long-running on a server.

## Quick recap

- **Terminal** = shows text. **Shell** = understands commands. **Command** = does the work.
- **/dev** holds device files. **TTY** = text console (`/dev/ttyN`, Ctrl+Alt+F2–F6). **PTS** = pseudo-terminal for SSH and GUI windows (`/dev/pts/N`).
- The kernel's line discipline turns Ctrl+C / Ctrl+Z / Ctrl+D into signals or end-of-input.
- `tty`, `who` and `w` show where you and others are connected.

**Interview questions**

1. *What is the difference between a TTY and a PTS?* A TTY is a terminal the kernel provides directly (the console, Ctrl+Alt+F2). A PTS is the slave end of a pseudo-terminal that software (sshd, a terminal emulator) creates so programs can act as if they're on a real terminal.
2. *What happens when you press Ctrl+C?* The kernel's terminal layer turns it into a SIGINT signal and sends it to the program running in the foreground of that terminal. Most programs exit when they get it.
3. *How do you see who is logged into a server and from where?* `who` or `w`. The FROM column shows the remote IP. `last` shows past logins (topic 038).
