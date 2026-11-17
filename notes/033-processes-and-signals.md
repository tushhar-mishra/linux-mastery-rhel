# 033 · Processes, Signals and Job Control

> **You need first:** [032 · Flatpak and snap](032-flatpak-and-snap.md)
> **Next:** [034 · top and load average](034-top-and-load-average.md)

---

## What it is

- A **program** is a file on disk (`/usr/bin/sleep`). A **process** is a program **running**, with its own memory, open files, user identity and state. The same program can run as many processes at once.
- Each process has a **PID** (Process ID), a unique number, and a **PPID** (Parent Process ID), the PID of the process that started it.
- **PID 1** is the first process the kernel starts. On RHEL and Ubuntu it is **systemd** (topic 037), the "parent of all" that starts and supervises services.
- A **daemon** (or **service**) is a background process that runs without a terminal, such as `sshd` or `crond`.
- A **thread** is a separate line of execution **inside** a process, sharing its memory.
- A **signal** is a small numbered message the kernel delivers to a process: "stop", "terminate", "reload your config"…
- **Job control** lets your shell pause, resume and move commands between the foreground and background.

## Why it exists

Everything that "runs" on Linux is a process. When a server is slow, out of memory, or a service is stuck, you are looking for **which process** is the cause and **what state** it is in. Signals are how you (and the system) tell processes to stop or reload safely.

## Analogy

A program is a **recipe book on a shelf**. A process is **a cook actually cooking from it**, with their own pots (memory), ingredients (open files) and name badge (PID, user). Many cooks can follow the same recipe at once. A signal is the **head chef calling out an instruction**: "Finish up and leave" (SIGTERM), "Stop right now and get out" (SIGKILL), "Re-read the recipe, it changed" (SIGHUP).

## How it works inside

### How a process is born: fork and exec

1. A parent process (for example, bash) calls **`fork()`**. The kernel creates an almost identical **copy**, the child, with a new PID. (It doesn't actually copy all the memory up front; it shares it until one side writes. This is "copy-on-write", topic 092.)
2. The child calls **`execve()`**, which **replaces** its program with a new one (`/usr/bin/ls`), keeping the same PID.
3. The parent usually **waits** for the child to finish and collects its exit status.

`exec bash` replaces your current shell with a new bash **without** forking (same PID). If you then type `exit`, your session closes.

### Process states (the `STAT` / `S` column)

| Code | State | Meaning |
|---|---|---|
| `R` | Running / runnable | On a CPU, or waiting in the queue for one |
| `S` | Interruptible sleep | Waiting for something (input, a timer, network). Most processes, most of the time |
| `D` | **Uninterruptible sleep** | Waiting inside the kernel, usually for **disk or network storage I/O**. It won't react to signals until the wait ends, so even `kill -9` appears to do nothing. (Some waits, for example NFS ones, are "killable" and still accept SIGKILL) |
| `T` / `t` | Stopped / stopped by a debugger | Paused (e.g. Ctrl+Z) |
| `Z` | **Zombie** (`<defunct>`) | It has **finished**, but its parent hasn't collected its exit status yet. It uses no CPU and no memory, only a slot in the process table |
| `I` | Idle kernel thread | Kernel housekeeping |

Extra flags you'll see next to the state: `<` high priority, `N` low priority, `s` session leader, `l` multi-threaded, `+` in the foreground of its terminal.

**Zombies and orphans:**
- A **zombie** can't be killed (it's already dead). Fix or restart its **parent** so the exit status is collected.
- An **orphan** is a child whose parent died first. PID 1 adopts it and collects it when it ends.
- **Many `D` processes** usually mean a storage or NFS problem, not a CPU problem.

### Signals

| No. | Name | Default action | Typical use |
|---|---|---|---|
| 1 | **SIGHUP** | Terminate | "Hang up": the terminal closed. Many daemons treat it as **reload config** |
| 2 | **SIGINT** | Terminate | Ctrl+C |
| 3 | SIGQUIT | Terminate + core dump | Ctrl+\ |
| 9 | **SIGKILL** | Terminate | **Can't be caught or ignored**. No cleanup |
| 15 | **SIGTERM** | Terminate | **Default for `kill`**. A polite request; the program can clean up first |
| 18 | SIGCONT | Continue | Resume a stopped process |
| 19 | SIGSTOP | Stop | Pause; can't be caught |
| 20 | SIGTSTP | Stop | Ctrl+Z (can be caught) |

How delivery works: the kernel marks the signal as **pending** on the process. The next time that process is scheduled to run, the kernel runs its **handler** (if the program set one), or the default action. Programs can **catch** most signals (to save work before exiting) or **ignore** them, but never SIGKILL or SIGSTOP. Topic 092 goes deeper.

**Escalation rule:** send SIGTERM, wait a few seconds, and only then SIGKILL. SIGKILL can leave lock files, half-written data or corrupt databases behind.

### Services: let systemd do it

A service is managed by systemd, which tracks **all** its processes in a group (a **cgroup**, topic 097). If you `kill` a service's PID by hand, systemd may simply **restart** it (its `Restart=` setting). Use `systemctl stop|restart|reload` (topic 037).

## Commands

### Who am I, who's my parent

```bash
echo $$ $PPID
```
```
2381 2380
```
- `$$` = this shell's PID, `$PPID` = its parent (here, the sshd process serving your session).

### Listing processes

```bash
ps aux | head -4
```
```
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root           1  0.0  0.4 174512 16480 ?        Ss   08:50   0:03 /usr/lib/systemd/systemd --switched-root --system --deserialize=31
root           2  0.0  0.0      0     0 ?        S    08:50   0:00 [kthreadd]
root           3  0.0  0.0      0     0 ?        S    08:50   0:00 [pool_workqueue_release]
```

| Column | Meaning |
|---|---|
| `USER` / `PID` | Owner and process ID |
| `%CPU` | CPU use averaged over the process's whole life (not "right now"; use `top` for that) |
| `%MEM` | Share of physical RAM |
| `VSZ` | **Virtual** size in KB: all memory it has *reserved*, much of it never used. Usually ignore |
| `RSS` | **Resident Set Size** in KB: the memory actually in RAM now. The useful one |
| `TTY` | Terminal; `?` = none (a daemon) |
| `STAT` | State (table above) |
| `START` / `TIME` | When it started / total CPU time used |
| `COMMAND` | The command line. Names in `[brackets]` are kernel threads |

- `ps aux` uses BSD-style options (no dash). `ps -ef` is the UNIX style, with a PPID column. Both list everything.

```bash
ps -ef --forest | grep -A3 sshd
```
```
root      1050     1  0 08:51 ?        00:00:00 sshd: /usr/sbin/sshd -D [listener] 0 of 10-100 startups
root      2370  1050  0 09:12 ?        00:00:00  \_ sshd-session: alice [priv]
alice     2380  2370  0 09:12 ?        00:00:00      \_ sshd-session: alice@pts/0
alice     2381  2380  0 09:12 pts/0    00:00:00          \_ -bash
```
- The tree view: the sshd listener → a privileged process for your session → the unprivileged session process → your login shell.

### Finding the top consumers

```bash
ps -eo pid,user,%cpu,%mem,rss,stat,cmd --sort=-%cpu | head -5
ps -eo pid,user,%mem,rss,cmd --sort=-%mem | head -5
```
- `-o` picks the columns; `--sort=-%cpu` sorts descending.

### Finding PIDs by name

```bash
pgrep -a sshd
pidof sshd
pstree -p -s $$
```
```
1050 sshd: /usr/sbin/sshd -D [listener] 0 of 10-100 startups
2370 sshd-session: alice [priv]
2380 sshd-session: alice@pts/0
1050
systemd(1)───sshd(1050)───sshd-session(2370)───sshd-session(2380)───bash(2381)───pstree(2502)
```
- `pgrep -a` shows PID and full command line. Its pattern is matched **anywhere in the name**, so `sshd` also catches every `sshd-session`. `-x` = exact name only (`pgrep -x sshd` → just 1050). `-u alice` = only alice's.
- `pidof` always matches the exact program name, so it finds only the listener: each login runs a separate `sshd-session` program (OpenSSH 9.8+).
- `pstree -s PID` shows the chain of ancestors.

### Sending signals

```bash
sleep 600 &
kill %1                 # SIGTERM to job 1 (or: kill PID)
kill -9 4321            # SIGKILL: last resort
kill -HUP 1050          # ask a daemon to reload (prefer: systemctl reload sshd)
kill -STOP 4321 ; kill -CONT 4321
kill -l                 # list all signals
pkill -x sleep          # by exact name (without -x, "sleep" also matches "sleepy")
pkill -u baduser        # every process of a user ⚠️
pkill -t pts/3          # everything on one terminal (kicks a user off)
```
Check before killing: `pgrep -a pattern` shows **what** would match. Then confirm the owner with `ps -o pid,user,cmd -p PID`.

### Job control

```bash
sleep 300 &
```
```
[1] 4410
```
```bash
jobs -l
```
```
[1]+  4410 Running                 sleep 300 &
```

| Action | How |
|---|---|
| Start in the background | `cmd &` |
| List jobs | `jobs -l` |
| Bring to the foreground | `fg %1` |
| Pause the foreground job | Ctrl+Z (SIGTSTP) |
| Continue it in the background | `bg %1` |
| Kill a job | `kill %1` |
| Survive logout | `nohup cmd &` (output to `nohup.out`), or `disown %1` for a running job |

Jobs belong to the shell that started them. Closing the terminal sends SIGHUP, which usually kills them. For anything long-running on a server, use `tmux`, `systemd-run` or a real service.

### Peeking inside a process

```bash
cat /proc/2381/status | head -8
ls -l /proc/2381/fd
sudo cat /proc/4321/stack        # where a D-state process is stuck in the kernel
ps -o pid,stat,wchan:32,cmd -p 4321
```
```
Name:	bash
Umask:	0022
State:	S (sleeping)
Tgid:	2381
Ngid:	0
Pid:	2381
PPid:	2380
...
```
- `/proc/<PID>/` is the kernel's live view of each process (topic 092). `wchan` = the kernel function a sleeping process is waiting in.

### Try it
1. Start two `sleep 3366 &`. Find them with `pgrep -x sleep`, look at them with `ps -o pid,stat,cmd -p …`, then `kill` one and `pkill -x sleep` the other.
2. Run `sleep 100`, press Ctrl+Z, run `jobs`, then `bg`, then `fg`, then Ctrl+C.
3. `ps -ef --forest` and find your own shell's chain back to PID 1.
4. Make a zombie: `bash -c 'sleep 1 & exec sleep 30' &`, then `ps -o pid,ppid,stat,cmd --ppid $!` after 2 seconds. The child shows `Z`, because its parent (now `sleep 30`) never collects it.

## Where you'll use it

- **"The server is slow"** → find the top CPU and memory processes (here, `top` in topic 034, `pidstat` in topic 036).
- **"I can't stop this process"** → check the state: `D` = storage problem, `Z` = parent problem, comes back = supervised by systemd.
- **Graceful restarts:** many servers reload config on SIGHUP (nginx, rsyslog) without dropping connections.
- **Containers:** the app is PID 1 inside its container. `docker stop` / Kubernetes send **SIGTERM**, wait a grace period (30 seconds by default in Kubernetes), then **SIGKILL**. Apps must handle SIGTERM to shut down cleanly. Exit code **137** = killed by SIGKILL (often the OOM killer); **143** = 128+15 = SIGTERM.
- **Kicking a user off:** `pkill -t pts/3` or `pkill -u user`.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `kill -9` has no effect | The process is in `D` state (stuck I/O) or a zombie | `D`: find the hung storage/NFS (`/proc/PID/stack`). Zombie: restart its parent |
| The process comes back after `kill` | systemd restarts it (`Restart=`), or cron/a timer starts it | `systemctl stop` (and `disable`); check timers and cron |
| `kill: (PID) - Operation not permitted` | It's another user's process | `sudo kill` |
| `pkill` killed more than intended | The pattern matched other names | Preview with `pgrep -a`; use `-x` |
| `fg: no such job` | The job belongs to a different shell | Use `kill PID` |
| A background job died at logout | SIGHUP when the terminal closed | `nohup`, `disown`, tmux, or `systemd-run` |
| Zombies keep piling up | A buggy parent never collects its children | Restart the parent service; report the bug |

## Quick recap

- Process = running program with a PID, PPID, memory, files and state. Created by `fork()` + `execve()`. PID 1 = systemd.
- States: R running, S sleeping, **D uninterruptible (I/O)**, T stopped, **Z zombie** (fix the parent).
- `ps aux`, `ps -ef --forest`, `ps -eo … --sort=-%cpu`, `pgrep -a -x`, `pstree -p`.
- `kill` = SIGTERM (polite) → `kill -9` = SIGKILL (last resort). SIGHUP often means reload. Use `systemctl` for services.

**Interview questions**

1. *What is a zombie process and how do you get rid of it?* A process that has exited but whose parent hasn't collected its exit status. Signals don't affect it. Make the parent collect it, or kill or restart the parent so PID 1 adopts and reaps it.
2. *SIGTERM vs SIGKILL?* SIGTERM can be caught, so the program can clean up and exit gracefully. SIGKILL can't be caught: the kernel ends the process immediately, with no cleanup.
3. *Why doesn't `kill -9` kill a process in `D` state?* It's blocked in an uninterruptible kernel wait, usually for I/O, and the signal is only acted on when the wait ends. Fix the underlying storage or NFS problem.
