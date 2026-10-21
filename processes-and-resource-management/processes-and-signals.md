# Processes, Signals & Job Control

> **Sessions:** S29 · **Objective:** *Identify CPU/memory intensive processes and kill processes* **[RHCSA Core]**
> **Related:** [top & monitoring](top-and-process-monitoring.md) · [Priority & nice](process-priority-and-nice.md) · [Shell basics (fork/exec)](../shell-and-command-line/shell-basics-and-command-syntax.md#23-how-bash-processes-a-command-line-interview-knowledge) · [Control operators (`&`)](../shell-and-command-line/quoting-and-control-operators.md) · systemd services (S50, planned)

## 1. Overview

A **process** is a running instance of a program (binary or script) with its own PID, memory, open files, credentials and state. Admins list processes to find what's consuming resources, send **signals** to stop or reload them, and manage **jobs** started from a shell. On RHEL, long-running services should be managed through **systemd**, not by killing PIDs by hand.

## 2. Key Concepts

| Term | Meaning |
|---|---|
| **PID / PPID** | Process ID / parent's PID. Every process except PID 1 has a parent |
| **PID 1 (systemd)** | First user-space process, started by the kernel (its PPID is 0). Adopts orphaned processes |
| **Daemon** | Background service process, usually started and supervised by systemd (`sshd`, `crond`). Can be stopped and restarted |
| **Zombie (`Z`)** | Process that has **exited** but hasn't been *reaped* by its parent (exit status not yet collected). Uses no CPU and almost no memory, just a process-table slot. Signals don't affect it; fix or kill the **parent** |
| **Orphan** | Child whose parent died; re-parented to PID 1 (or a subreaper) |
| **Thread** | Execution unit inside a process sharing its memory; has its own TID (`ps -L`, top `H`) |

### 2.1 fork & exec

1. The parent calls `fork()`, creating an almost identical child (new PID).
2. The child calls `exec()`, replacing its program image with the new program (same PID).

```bash
echo $$ $PPID          # current shell PID and its parent's PID
bash; echo $$ $PPID    # new child shell: its PPID = previous $$
exit
exec bash              # replace the current shell WITHOUT forking (same PID); exit will then close it
```

### 2.2 Process states (`STAT` / `S` column)

| Code | State | Notes |
|---|---|---|
| `R` | Running or runnable (on the run queue) | |
| `S` | Interruptible sleep (waiting for an event) | Most processes |
| `D` | **Uninterruptible** sleep (usually I/O) | Can't be killed, even with `-9`, until the I/O returns (hung NFS, failing disk) |
| `T` / `t` | Stopped (job control) / stopped by a tracer | |
| `Z` | Zombie (defunct) | |
| `I` | Idle kernel thread | |

BSD-style extra flags: `<` high priority, `N` low priority (niced), `L` locked pages, `s` session leader, `l` multi-threaded, `+` foreground process group.

## 3. Listing & Finding Processes

| Command | Shows |
|---|---|
| `ps` | Processes on your terminal |
| `ps aux` | BSD style: all processes with USER, %CPU, %MEM, VSZ, RSS, STAT, START, COMMAND (no dash: `-aux` means something else) |
| `ps -ef` | UNIX style: UID, PID, PPID, C, STIME, TTY, TIME, CMD |
| `ps -elf` | Long format incl. state, priority (PRI), nice (NI) |
| `ps fax` / `ps -ef --forest` | Process tree |
| `ps -C sshd` | By exact command name |
| `ps -u alice` / `ps -t pts/0` / `ps -p 1234` | By user / terminal / PID |
| `ps -L -p PID` | Threads of a process |
| `pgrep -l sleep` · `pgrep -a ssh` · `pgrep -u alice` · `pgrep -x sshd` | PIDs by name pattern (`-l` name, `-a` full cmdline, `-x` exact) |
| `pidof sshd` | PIDs of an exact program name |
| `pstree -p` · `pstree -p -u alice` · `pstree -p -s PID` | Tree with PIDs / for a user / ancestors of a PID |

**Find top consumers** **[RHCSA Core]**:

```bash
ps -eo pid,user,%cpu,%mem,stat,cmd --sort=-%cpu | head    # biggest CPU users
ps -eo pid,user,%mem,rss,cmd --sort=-%mem | head          # biggest memory users
ps -p 1 -o pid,comm                                       # what is PID 1?
```

## 4. Signals

| No. | Name | Default action | Use |
|---|---|---|---|
| 1 | SIGHUP | Terminate | Many daemons treat it as "reload configuration" |
| 2 | SIGINT | Terminate | `Ctrl+C` |
| 3 | SIGQUIT | Core dump | `Ctrl+\` |
| 9 | **SIGKILL** | Terminate | **Cannot be caught or ignored**; no cleanup |
| 15 | **SIGTERM** | Terminate | **Default for `kill`**; polite request, allows cleanup |
| 18 | SIGCONT | Continue | Resume a stopped process |
| 19 | SIGSTOP | Stop | Cannot be caught |
| 20 | SIGTSTP | Stop | `Ctrl+Z` (catchable) |

```bash
kill -l                       # list signal names and numbers
kill 1234                     # SIGTERM (same as kill -15 / kill -TERM)
kill -9 1234                  # SIGKILL: last resort
kill -STOP 1234 ; kill -CONT 1234
kill -HUP 1234                # ask a daemon to reload (prefer systemctl reload svc)
pkill -x sleep                # by exact name (without -x, "sleep" also matches "sleepy")
pkill -u alice                # all of alice's processes ⚠️
pkill -t pts/2                # everything on a terminal
killall sleep                 # by exact name (psmisc package; may not be installed)
```

**Escalation:** send SIGTERM first, wait a few seconds, and use SIGKILL only if the process is still running. SIGKILL skips cleanup, which can leave lock files, temp files or corrupt data.

**Services:** use `systemctl stop|restart|reload httpd` and `systemctl kill -s HUP httpd` rather than raw PIDs. systemd may restart a killed service automatically (`Restart=`).

> ⚠️ **Course corrections:**
> - SIGKILL is delivered to the process (it's just uncatchable); it isn't "sent to the kernel."
> - `Ctrl+Z` sends **SIGTSTP (20)**, not SIGSTOP (19).
> - `kill -1 1` (reload systemd) and `kill -1 <firewalld PID>` work, but on RHEL use `systemctl daemon-reload` and `firewall-cmd --reload`.

## 5. Job Control

```bash
sleep 300 &           # [1] 12345  start in background ($! = 12345)
jobs -l               # list jobs with PIDs
fg %1                 # bring job 1 to the foreground
Ctrl+Z                # suspend the foreground job (SIGTSTP)
bg %1                 # resume it in the background
kill %1               # signal by job number
nohup long_task &     # ignore SIGHUP; output → nohup.out; survives logout
disown %1             # detach an already-running job from the shell
```

Jobs belong to the shell that started them; another terminal's `jobs` won't show them. For durable background work use `systemd-run`, a service unit, or tmux.

## 6. Debugging Processes **[Advanced]**

```bash
strace -p PID                    # live system calls (root for others' processes; dnf install strace)
strace -f -o /tmp/trace.txt cmd  # trace a command and its children to a file
ls -l /proc/PID/fd               # open files of a process
cat /proc/PID/status             # state, memory, threads, UIDs
lsof -p PID                      # open files (lsof package)
```

## 7. RHCSA Exam Focus **[RHCSA Core]**

```bash
ps aux --sort=-%cpu | head -5            # identify the CPU hog
ps aux --sort=-%mem | head -5            # identify the memory hog
kill PID   (then kill -9 PID only if needed)
pkill -u baduser ; pkill -x stress-ng
```

- Kill **exactly** what's asked: verify the PID and owner first (`ps -o pid,user,cmd -p PID`).
- If a killed process comes back, it's a service; use `systemctl stop` (and `disable`).

## 8. Production Practices **[Production Practice]**

- Investigate before killing: check what the process is doing (`top`, `strace`, logs).
- Prefer `systemctl` for services; it tracks all of a service's processes via cgroups (`systemd-cgls`, `systemctl status svc`).
- Many `D`-state processes usually point to storage or NFS problems, not CPU.
- A growing number of zombies means a buggy parent; restart the parent service.

## 9. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `kill -9` has no effect | Process in `D` state, or a zombie | Fix the underlying I/O / kill or restart the parent |
| Process reappears after kill | Supervised by systemd (`Restart=`) or cron | `systemctl stop/disable`; check timers/cron |
| `kill: (PID) - Operation not permitted` | Another user's process | `sudo kill` |
| `pkill` killed more than intended | Pattern match | `pgrep -a pattern` first; use `-x` |
| `fg: no such job` | Different shell/terminal | Use `kill PID` from any shell |
| Background job died at logout | SIGHUP | `nohup`, `disown`, or a systemd unit |

## 10. Interview Questions

| Question | Answer |
|---|---|
| What is a zombie and how do you remove it? | An exited process not yet reaped by its parent; make the parent reap it or kill the parent so PID 1 adopts and reaps it. |
| SIGTERM vs SIGKILL? | TERM can be caught for graceful shutdown; KILL can't be caught and gives no cleanup. |
| Why can't you kill a `D` state process? | It's blocked in uninterruptible kernel I/O; signals are handled only when it returns. |
| What's fork/exec? | fork duplicates the process; exec replaces the program in that process. |
| `ps aux` vs `ps -ef`? | BSD vs UNIX syntax; both list all processes with different columns. |
| How do you keep a job running after logout? | `nohup`, `disown`, `systemd-run`/a service unit, or tmux. |

## 11. Course Practice (S29, corrected where needed)

| # | Task | Command | Note |
|---|---|---|---|
| 1 | Find systemd by name | `ps -C systemd` | ✔ |
| 2 | PID of systemd | `ps -p 1 -o pid,comm` | Course's `pidof init` may print nothing (the process is named `systemd`) |
| 3 | Your terminal | `who am i` or `tty` | ✔ |
| 4 | Processes on your terminal | `ps -t pts/0` | `ps fax \| grep pts/0` also matches the grep |
| 5–6 | Shell PID / parent | `echo $$` · `echo $PPID` | ✔ |
| 7 | Two background sleeps | `sleep 3366 & sleep 3366 &` | ✔ |
| 8 | PIDs of sleeps | `pidof sleep` or `pgrep -x sleep` | ✔ |
| 9 | Show only them in top | `top -p PID1,PID2` | ✔ |
| 10 | Standard kill one | `kill PID1` | SIGTERM ✔ |
| 11 | Kill all sleeps | `pkill -x sleep` | `-x` avoids partial-name matches |

## 12. Quick Revision

```bash
ps aux | ps -ef | ps fax | ps -eo pid,user,%cpu,%mem,cmd --sort=-%cpu | ps -C x | ps -t pts/0
pgrep -a -x name | pidof name | pstree -p [-u user] [-s PID]
kill [-15|-9|-HUP|-STOP|-CONT] PID | pkill -x name | pkill -u user | killall name
& jobs fg %n bg %n Ctrl+Z nohup disown $!     states: R S D T Z I
```

## 13. Cross-References

- [top & process monitoring](top-and-process-monitoring.md)
- [Priority & nice](process-priority-and-nice.md)
- [Control operators (`&`, background jobs)](../shell-and-command-line/quoting-and-control-operators.md#43-background-jobs-preview-of-s29)
- systemd services & `systemctl kill` (S50), resource monitoring (S56): planned
