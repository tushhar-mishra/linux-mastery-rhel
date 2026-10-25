# Processes & System Calls: How Programs Actually Run

> **Track:** **[Internals]** (foundation for production troubleshooting and containers) · **Verified:** demos run on a RHEL 10.2 UBI container (kernel and tools from Oct 2026); host-specific values are labeled "typical"
> **Prerequisites:** [Processes, signals & job control](processes-and-signals.md) · [Shell basics (how bash runs a command)](../shell-and-command-line/shell-basics-and-command-syntax.md#23-how-bash-processes-a-command-line-interview-knowledge) · [I/O redirection](../files-and-text-processing/io-redirection-and-pipes.md) · [Special permissions (set-UID)](../users-groups-and-permissions/special-permissions-and-acls.md)
> **Next:** [Memory management](memory-management.md) → [Namespaces & cgroups](../containers-and-virtualization/namespaces-and-cgroups.md)

## 1. Why This Matters

Every symptom you debug ("Too many open files", a zombie storm, a process that ignores `kill`, a container that won't stop, a service that works by hand but not under systemd) is explained by a handful of kernel mechanisms: **system calls, fork/exec/wait, credentials, file descriptors and signals**. Knowing them turns guesswork into a short checklist, and they are exactly what container runtimes are built from.

## 2. Programs, Processes, Threads

| Term | What it is |
|---|---|
| **Program** | An executable file on disk (ELF binary or script with a `#!` line) |
| **Process** | A running instance: its own **virtual address space**, credentials, file descriptor table, signal handlers, current directory, namespaces, cgroup |
| **Thread** | A schedulable execution context **inside** a process, sharing its memory and file descriptors |
| **Task** | The kernel's unit (`task_struct`). Every thread is a task. A "process" is a **thread group**; its PID is the thread-group ID, and each thread has its own TID |

```bash
ps -o pid,tid,nlwp,cmd -L -p "$(pgrep -o sshd)"   # one row per thread (TID); NLWP = thread count
ls /proc/PID/task/                                 # one directory per thread
```

Consequence: the scheduler, load average and many limits count **tasks**, so a multithreaded program can look like "many processes" to the kernel.

## 3. System Calls: the Only Door into the Kernel

User-space code can't touch hardware, other processes' memory or kernel data. To open a file, allocate memory, create a process or send a packet it makes a **system call**:

1. The C library wrapper (`open()`, `read()`, `fork()`) puts the syscall number and arguments in registers.
2. A special instruction (`syscall` on x86-64, `svc` on aarch64) switches the CPU to **kernel mode**.
3. The kernel validates the request (permissions, SELinux, limits, namespaces), does the work, and returns a result.
4. On failure it returns `-1` and sets **`errno`** (`ENOENT` no such file, `EACCES` permission denied, `EMFILE` too many open files, `EAGAIN` try again, `EINTR` interrupted by a signal).

Error messages you see in logs (`No such file or directory`, `Permission denied`) are just `errno` values printed with `strerror()`. Seeing the failing syscall tells you exactly which check failed.

A few hot calls (like reading the time) are served from the **vDSO**, a kernel-provided page mapped into every process, without a mode switch. That's why `strace` may not show them.

### 3.1 Watching syscalls with `strace`

```bash
dnf install -y strace
strace -c ls /                          # summary: count, errors and time per syscall
strace -f -e trace=execve,clone,clone3,wait4,exit_group bash -c 'ls / >/dev/null'   # process lifecycle
strace -e trace=openat,stat,statx -o /tmp/t.txt sshd -t   # which files does it look for?
strace -f -tt -T -p PID                 # attach to a running process: timestamps + time spent in each call
strace -y -e trace=read,write -p PID    # -y: show the file/socket behind each fd number
```

| Option | Meaning |
|---|---|
| `-f` | Follow child processes and threads (needed for anything that forks) |
| `-p PID` | Attach to a running process (root, or same user with ptrace allowed) |
| `-e trace=SET` | Filter: names, or classes `%file`, `%process`, `%network`, `%signal`, `%memory` |
| `-tt` / `-T` | Wall-clock timestamps / time spent inside each syscall |
| `-o FILE` | Write the trace to a file |
| `-c` | Summary table instead of a trace |
| `-y` / `-yy` | Decode file descriptors into paths / socket addresses |

Verified excerpt of `bash -c 'ls / > /dev/null'` (PIDs differ on your system):

```
343   execve("/usr/bin/bash", ["bash", "-c", "ls / > /dev/null; true"], …) = 0
343   clone(…flags=CLONE_CHILD_CLEARTID|CLONE_CHILD_SETTID|SIGCHLD…) = 344   ← fork(): child 344 created
343   wait4(-1,  <unfinished ...>                                           ← parent blocks waiting
344   execve("/usr/bin/ls", ["ls", "/"], …) = 0                             ← child replaces itself with ls
344   exit_group(0)                     = ?
343   <... wait4 resumed>[{WIFEXITED(s) && WEXITSTATUS(s) == 0}], 0, NULL) = 344   ← parent reaps the child
343   --- SIGCHLD {si_signo=SIGCHLD, si_code=CLD_EXITED, si_pid=344, …} ---
```

> ⚠️ `strace` slows the traced process considerably (every syscall stops it twice). Use it briefly on production processes, filter with `-e`, and prefer eBPF tools for hot paths ([performance & observability](../advanced-rhel-and-career-notes/performance-and-observability.md)).

## 4. Process Lifecycle: fork, exec, wait, exit

```
 parent (bash, PID 343)
   │ fork()/clone() ───────────────► child (PID 344): a copy of the parent
   │                                   │ execve("/usr/bin/ls")  → same PID, new program image
   │ wait4() … blocks                  │ … runs …
   │                                   │ exit_group(0) → becomes a ZOMBIE (exit status kept)
   │ ◄──── SIGCHLD ──────────────────────┘
   │ wait4() returns status → kernel frees the zombie's task_struct
```

### 4.1 `fork()` and copy-on-write

`fork()` creates a new process that is a near-copy of the parent: same memory contents, same open file descriptors, same credentials, same signal dispositions, same cwd. It doesn't copy memory up front. Parent and child share the physical pages, marked **read-only**, and a page is copied only when one side writes to it (**copy-on-write**, COW). That's why forking a 10 GiB process is fast, and why a forked child that writes heavily can suddenly need much more memory (a common surprise with Redis-style snapshotting).

On Linux, `fork()` and thread creation are both implemented with **`clone()`**; flags decide what's shared (`CLONE_VM` memory, `CLONE_FILES` fd table, `CLONE_NEWPID`/`CLONE_NEWNET`… new **namespaces**). Containers are "just" processes created with namespace flags; see [namespaces & cgroups](../containers-and-virtualization/namespaces-and-cgroups.md).

### 4.2 `execve()`

`execve()` **replaces** the program running in the current process: new code, data, heap and stack; the **PID stays the same**. What survives an exec matters in practice:

| Survives `execve()` | Does not survive |
|---|---|
| PID, parent PID, credentials (unless set-UID/capabilities on the new file change them) | Memory contents, threads (other than the caller) |
| Open file descriptors **without** the close-on-exec flag | fds opened with `O_CLOEXEC` |
| cwd, umask, resource limits, nice value, cgroup, namespaces, SELinux context (unless a domain transition applies) | Signal **handlers** (reset to default); ignored signals stay ignored |
| Environment, **only** if the caller passes it (shells pass exported variables) | Shell variables that weren't exported |

This table explains several things you've seen: why `export` matters, why a background job ignores SIGINT, why SELinux domains change when systemd starts `httpd`, and why a leaked file descriptor follows a daemon into every child it starts.

### 4.3 `exit()`, zombies, `wait()` and orphans

- When a process exits, the kernel frees its memory and files immediately, but keeps a tiny record (PID, exit status, CPU usage) so the parent can collect it. Until then the process is a **zombie** (`Z`, `<defunct>`).
- The parent collects it with `wait()`/`waitpid()`/`wait4()`. The kernel also sends the parent **SIGCHLD**.
- A parent that never calls `wait()` accumulates zombies. You **can't kill a zombie** (it's already dead); kill or fix the parent. When a parent dies, its children are **re-parented** to the nearest *subreaper* or PID 1, which reaps them.

Reproduce a zombie (verified):

```bash
bash -c 'sleep 1 & exec sleep 6' &   # bash forks "sleep 1", then exec()s itself into "sleep 6",
sleep 2 ; ps -o pid,ppid,stat,cmd -C sleep   # …which never calls wait() for its child
#   331   324 S    sleep 6
#   333   331 Z    [sleep] <defunct>          ← zombie until its parent (331) exits
```

### 4.4 PID 1 is special

PID 1 (systemd on the host; the first process in a container) has extra duties and rules:

1. It **adopts orphans** and must reap them, or zombies accumulate.
2. The kernel **doesn't deliver signals whose action is "default" to PID 1** of a PID namespace when they're sent from inside that namespace. Verified: in a container whose PID 1 is `sleep infinity`, `kill -TERM 1` and even `kill -KILL 1` from inside do nothing. From the parent namespace (the host), SIGKILL still works.
3. If PID 1 of a namespace exits, the kernel kills every other process in it.

That's why containers use a proper init or `--init` (tini / catatonit), and why an app running as PID 1 must install its own SIGTERM handler or `podman stop`/`docker stop` waits for the timeout and then sends SIGKILL.

## 5. Credentials & Privilege

| ID | Meaning |
|---|---|
| **Real UID/GID** | Who started the process |
| **Effective UID/GID** | What permission checks use |
| **Saved set-UID** | Lets a set-UID program drop and regain privilege |
| **Supplementary groups** | Fixed when the session starts (which is why a new group needs a re-login) |

```bash
ps -o pid,ruser,euser,cmd -C passwd      # while passwd is waiting for input: RUSER alice, EUSER root
grep -E '^(Uid|Gid|Groups)' /proc/self/status   # Uid: real effective saved filesystem
```

`/usr/bin/passwd` is set-UID root (`-rwsr-xr-x`): when alice runs it, exec sets the **effective** UID to 0, so it can write `/etc/shadow`. SELinux additionally restricts it to the `passwd_t` domain.

### 5.1 Capabilities

Root's power is split into ~40 **capabilities**, checked individually: `CAP_DAC_OVERRIDE` (bypass file permissions), `CAP_NET_BIND_SERVICE` (bind ports < 1024), `CAP_SYS_ADMIN` (mounts and much more), `CAP_NET_ADMIN` (network config), `CAP_KILL`, `CAP_SYS_PTRACE`, `CAP_CHOWN` …

```bash
grep Cap /proc/self/status                      # CapPrm/CapEff/CapBnd… as hex bitmasks
capsh --decode=00000000a80425fb                 # decode (libcap package)
getcap /usr/bin/ping                            # file capabilities instead of set-UID (ping may show cap_net_raw or none, depending on the ping_group_range sysctl)
setcap cap_net_bind_service=+ep /usr/local/bin/myserver   # let a non-root binary bind :80 [Advanced]
```

Verified: inside a default container, "root" has only 14 capabilities (`cap_chown,cap_dac_override,…,cap_net_bind_service,cap_net_raw,cap_sys_chroot,…`), not the full set, and an unprivileged user has `CapEff: 0`. **Container root is not host root**: capabilities, namespaces, seccomp and SELinux all reduce it. systemd units can do the same (`CapabilityBoundingSet=`, `AmbientCapabilities=`; see [systemd unit files](../boot-systemd-and-kernel/systemd-unit-files.md)).

## 6. File Descriptors

### 6.1 Three layers

```
process A fd table          open file descriptions           inodes
  0 ─────────────────────► [/dev/pts/0, offset, flags] ───► pts inode
  1 ─────────────────────► [/var/log/app.log, offset 4096, O_APPEND] ─► inode 1234
  3 ──┐                                                     ▲
process B (forked child)   │                                │
  1 ──┴──────────────────► (same description: shared offset)┘
```

- An **fd** is a small integer index into the process's table.
- It points to an **open file description**: the file position (offset) and flags (read/write/append, non-blocking).
- That points to the **inode**.

After `fork()`, parent and child share open file descriptions, so they share the offset. This is why two processes appending to one log via an inherited fd don't overwrite each other.

**Shell redirection is just fd manipulation:** `cmd > out 2>&1` makes the child do `fd = open("out")`, `dup2(fd, 1)`, then `dup2(1, 2)` before `execve()`. That's why order matters ([redirection](../files-and-text-processing/io-redirection-and-pipes.md#21-order-matters)).

**Deleted-but-open files:** `rm` removes a **name** (directory entry). The inode and its blocks are freed only when the link count is 0 **and** no fd references it. Hence `df` full / `du` small, fixed by restarting the holder or truncating via `/proc/PID/fd/N` (`: > /proc/PID/fd/N`).

### 6.2 Inspecting

```bash
ls -l /proc/PID/fd                  # each fd → file, pipe:[inode], socket:[inode], anon_inode:[eventpoll]…
ls /proc/PID/fd | wc -l             # how many are open (fd-leak detection: watch it grow)
cat /proc/PID/fdinfo/3              # offset, flags of fd 3
lsof -p PID ; lsof +L1              # open files of a process ; deleted-but-open files system-wide
ss -tanp | grep 'pid=PID'           # its sockets
```

### 6.3 Limits: "Too many open files" (`EMFILE`/`ENFILE`)

| Limit | Scope | See / set |
|---|---|---|
| `RLIMIT_NOFILE` (soft/hard) | **Per process** | `ulimit -Sn` / `-Hn`; `/proc/PID/limits`; typical RHEL login default: soft 1024, hard 524288 |
| systemd `LimitNOFILE=` | Per service (pam_limits doesn't apply to services) | `systemctl show -p LimitNOFILE svc`; drop-in to raise |
| `/etc/security/limits.d/*.conf` | Login sessions (PAM) | `alice soft nofile 4096` |
| `fs.nr_open` | Maximum any process's hard limit can be | `sysctl fs.nr_open` |
| `fs.file-max` / `fs.file-nr` | **System-wide** open files | `cat /proc/sys/fs/file-nr` (allocated, 0, max) |

Verified reproduction (Python with a soft limit of 20): after 17 successful opens (fds 0–2 already used) → `[Errno 24] Too many open files`.

Diagnosis order: `/proc/PID/limits` (what limit does the process really have?) → `ls /proc/PID/fd | wc -l` (how many in use?) → watch it over time (leak vs genuine need) → raise `LimitNOFILE=` for the service **or** fix the leak.

## 7. Signals in Depth

### 7.1 Lifecycle of a signal

1. **Generated**: by `kill()`, the terminal driver (Ctrl+C → SIGINT to the **foreground process group**), the kernel (SIGSEGV on a bad memory access, SIGPIPE on writing to a closed pipe, SIGCHLD when a child exits), or timers.
2. **Pending**: recorded on the target.
3. **Blocked?** Each thread has a **signal mask**; blocked signals stay pending.
4. **Delivered** when the target next returns from kernel to user mode: run the handler, ignore, or take the **default action** (terminate, core dump, stop, continue, ignore).

`SIGKILL` and `SIGSTOP` can't be caught, blocked or ignored. Everything else can.

```bash
grep -E 'Sig(Pnd|Blk|Ign|Cgt)' /proc/PID/status    # pending / blocked / ignored / caught (hex bitmasks; bit N-1 = signal N)
```

Verified: a background job started from a **non-interactive** shell shows `SigIgn: 0000000000000006`. Bits 1 and 2 are signals 2 (SIGINT) and 3 (SIGQUIT): the shell set them to "ignore" before exec, and ignored dispositions survive `execve()`.

### 7.2 Process groups, sessions, controlling terminal

| Concept | Purpose |
|---|---|
| **Process group** | A pipeline/job (`ps -o pid,pgid,sid,tty,cmd`). Ctrl+C/Ctrl+Z go to the **foreground** process group |
| **Session** | All process groups of one login; the **session leader** is usually the login shell |
| **Controlling terminal** | When it hangs up (SSH drops), the kernel sends **SIGHUP** to the session; the shell forwards it to its jobs |

So: `nohup` sets SIGHUP to ignored before exec; `disown` removes a job from the shell's list so the shell won't forward SIGHUP; `setsid` starts a new session with no controlling terminal; a systemd service has no terminal at all and lives in its own cgroup, which is the robust answer.

### 7.3 Common signals and what they mean in production

| Signal | Typical meaning |
|---|---|
| SIGTERM (15) | "Please shut down." systemd/podman send it first, then SIGKILL after a timeout (`TimeoutStopSec=`, default 90 s for services) |
| SIGKILL (9) | Immediate death, no cleanup; also used by the OOM killer. Exit status 137 = 128 + 9 |
| SIGHUP (1) | Terminal hung up; many daemons use it as "reload config" |
| SIGSEGV (11) | Invalid memory access: an application bug (core dump; see `coredumpctl`) |
| SIGPIPE (13) | Wrote to a pipe/socket whose reader has gone (`yes \| head` ends this way) |
| SIGCHLD (17) | A child changed state; parent should `wait()` |

## 8. `/proc/PID`: a Process's Dashboard

| File | Shows |
|---|---|
| `status` | State, PPid, Uid/Gid, threads, VmRSS, signal masks, capabilities, context switches |
| `cmdline`, `environ` | Arguments, environment (NUL-separated: `tr '\0' ' ' < /proc/PID/cmdline`) |
| `exe`, `cwd`, `root` | Symlinks to the binary, current directory and root directory (`exe` shows `(deleted)` after an upgrade replaced the binary) |
| `fd/`, `fdinfo/` | Open file descriptors |
| `limits` | Effective resource limits |
| `maps`, `smaps_rollup` | Memory mappings; RSS/PSS totals ([memory management](memory-management.md)) |
| `stack`, `wchan` | Kernel stack / function where the task sleeps (root): **why is it stuck in D?** |
| `io` | Bytes read/written by this process |
| `sched`, `status` (`*_ctxt_switches`) | Scheduler stats: many **non-voluntary** switches = CPU contention |
| `ns/`, `cgroup` | Namespaces and cgroup membership |
| `oom_score`, `oom_score_adj` | OOM-killer ranking ([memory management](memory-management.md)) |

## 9. Labs

1. **See fork/exec/wait.** `strace -f -e trace=execve,clone,clone3,wait4 bash -c 'ls | wc -l'`. Explain each line, and why there are two `execve` children.
2. **fd inheritance.** `exec 3>/tmp/fdtest ; bash -c 'ls -l /proc/$$/fd'`: the child shows fd 3 too. Repeat with `exec 3>&-` first.
3. **Zombie.** Run the §4.3 demo, then kill the parent PID and watch the zombie disappear (adopted and reaped).
4. **Too many open files.** As a normal user: `ulimit -n 50 ; python3 -c 'f=[open("/dev/null") for _ in range(100)]'`. Read the traceback (`Errno 24`), then check `/proc/self/limits`.
5. **Deleted-but-open.** `python3 -c 'import time;f=open("/tmp/big","w");f.write("x"*50_000_000);f.flush();time.sleep(600)' &`, then `rm /tmp/big`, `df -h /tmp`, `lsof +L1`, `ls -l /proc/$!/fd`. Free the space by killing the process.
6. **Where does a program look for config?** `strace -f -e trace=%file -o /tmp/t sshd -T >/dev/null ; grep -v ENOENT /tmp/t | grep etc`.

## 10. Troubleshooting

| Symptom | Mechanism | Commands |
|---|---|---|
| "No such file or directory" but the file exists | Wrong path, missing **interpreter** in `#!`, or missing shared library (the error is about the loader) | `strace -e trace=%file`, `head -1 script`, `ldd binary` |
| "Permission denied" as root | Capabilities dropped (container/unit), SELinux, immutable attribute, `noexec` mount | `grep Cap /proc/PID/status`, `ausearch -m avc`, `lsattr`, `findmnt` |
| Many zombies | Parent doesn't `wait()` | `ps -eo ppid,stat | awk '$2~/Z/{print $1}' | sort | uniq -c` → fix/restart the parent |
| Process ignores Ctrl+C | SIGINT ignored or handled; or not in the foreground process group | `/proc/PID/status` SigIgn/SigCgt |
| Container takes 10 s to stop | PID 1 ignores SIGTERM (no handler) → runtime waits, then SIGKILL | Add a SIGTERM handler, use `--init`, or `STOPSIGNAL` |
| Service: "Too many open files" | `LimitNOFILE` too low or fd leak | `/proc/PID/limits`, `ls /proc/PID/fd \| wc -l` over time |
| Job dies when SSH disconnects | SIGHUP to the session | `systemd-run --unit=job …`, tmux, or `nohup`/`setsid` |
| Process stuck, `kill -9` ineffective | Uninterruptible sleep (D) | `cat /proc/PID/stack`, `ps -o stat,wchan:32`, `dmesg` (hung task), storage/NFS |

## 11. Interview Questions

| Question | Answer |
|---|---|
| What is a system call? | The controlled entry into the kernel; user code switches to kernel mode, the kernel checks and performs the operation, and returns a result or an `errno`. |
| What happens on `fork()`? Why is it fast? | A child is created sharing the parent's pages copy-on-write, plus copies of the fd table, credentials and signal dispositions. Pages are only copied when written. |
| What does `exec` keep and discard? | Keeps PID, fds without CLOEXEC, credentials, cwd, limits, ignored signals; discards memory, threads and signal handlers. |
| Why can't you kill a zombie? How do you get rid of it? | It's already dead; only its exit status remains. Make the parent `wait()`, or kill the parent so PID 1 adopts and reaps it. |
| Why might `docker stop` take 10 seconds? | PID 1 in the container has no SIGTERM handler; the kernel won't apply the default action to a namespace's PID 1, so the runtime waits and then SIGKILLs. |
| Exit code 137? | Killed by signal 9 (128 + 9), often the OOM killer. |
| Difference between `ulimit -n` and `fs.file-max`? | Per-process fd limit vs system-wide maximum of open files. |
| How does `cmd > file 2>&1` work? | The shell opens file, `dup2`s it onto fd 1, then duplicates fd 1 onto fd 2, all before exec. |
| Real vs effective UID? | Real = who started it; effective = what permission checks use (changed by set-UID binaries). |
| What are capabilities? | Root's privileges split into individually grantable units, checked by the kernel per operation; containers and services drop most of them. |
| How do you find why a process is stuck? | State in `ps`; `/proc/PID/stack` and `wchan` for D state; `strace -p` for S state (which syscall is it waiting in?). |

## 12. Quick Revision

```
syscall → kernel mode → errno on failure · strace -f -tt -T -e trace=%file|%process|%network -p PID · strace -c
clone() = fork + threads + namespaces · fork = COW · exec keeps PID/fds(no CLOEXEC)/creds/ignored sigs · exit → zombie until wait()
PID 1: reaps orphans, ignores default-action signals from inside its namespace, its death kills the namespace
ruid/euid/saved · set-UID · capabilities: grep Cap /proc/PID/status ; capsh --decode ; getcap/setcap
fd → open file description (offset, flags) → inode · dup2 = redirection · rm ≠ free while open (lsof +L1)
EMFILE: /proc/PID/limits · LimitNOFILE= · limits.d · fs.nr_open · fs.file-max/file-nr
signal: generated → pending → blocked? → delivered (handler/ignore/default) · SIGKILL/SIGSTOP uncatchable · 128+N exit codes
pgrp (Ctrl+C) · session (SIGHUP) · nohup/disown/setsid/systemd-run
/proc/PID: status cmdline environ exe cwd fd limits maps smaps_rollup stack wchan io ns cgroup oom_score
```

## 13. Cross-References

- [Processes, signals & job control (operations)](processes-and-signals.md) · [top & monitoring](top-and-process-monitoring.md)
- [Memory management](memory-management.md) · [Namespaces & cgroups](../containers-and-virtualization/namespaces-and-cgroups.md)
- [systemd unit files (KillMode, TimeoutStopSec, LimitNOFILE, capabilities)](../boot-systemd-and-kernel/systemd-unit-files.md)
- [Links & inodes](../users-groups-and-permissions/links.md) · [I/O redirection](../files-and-text-processing/io-redirection-and-pipes.md)
- [Performance & observability (eBPF instead of strace)](../advanced-rhel-and-career-notes/performance-and-observability.md)
