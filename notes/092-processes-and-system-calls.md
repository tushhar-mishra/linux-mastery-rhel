# 092 · Processes and System Calls: How Programs Actually Run

> **You need first:** [091 · Stratis](091-stratis.md) (and topics 033 processes and signals, 016 redirection, 027 special permissions)
> **Next:** [093 · Memory management](093-memory-management.md)

---

## What it is

This topic opens the **internals** part. Topic 033 showed how to *use* processes (`ps`, `kill`, jobs). Here we look at the kernel mechanisms underneath:

| Term | Meaning |
|---|---|
| **Program** | An executable file on disk: an **ELF** (Executable and Linkable Format) binary, or a script with a `#!` line |
| **Process** | A running instance of a program. It has its own **virtual address space** (memory), credentials (user IDs), file descriptor table, signal handlers, current directory, namespaces and cgroup |
| **Thread** | A separate line of execution **inside** a process, sharing its memory and open files |
| **Task** | The kernel's unit (`task_struct`). Every thread is a task. A "process" is a **thread group**: its PID is the group's ID, and each thread has its own **TID** (thread ID) |
| **System call** (syscall) | The only way a program can ask the kernel to do something: open a file, allocate memory, start a process, send a packet |
| **errno** | The error number the kernel returns when a syscall fails (`ENOENT`, `EACCES`, `EMFILE`…) |
| **File descriptor** (fd) | A small integer a process uses to refer to an open file, pipe or socket |

## Why it exists

Almost every hard production symptom is explained by a handful of mechanisms: **syscalls, fork/exec/wait, credentials, file descriptors and signals**.
- "Too many open files"
- A zombie storm
- A process that ignores `kill`
- A container that takes 10 seconds to stop
- A service that works by hand but not under systemd
- "Permission denied" as root

Knowing these mechanisms turns guesswork into a short checklist. They're also exactly what **container runtimes are built from** (topic 097).

## Analogy

The kernel is a **bank vault with one service window**. Customers (programs) can't walk into the vault (hardware, other customers' memory). They fill in a **request slip** (a system call) and pass it through the window. The clerk (kernel) checks ID and permissions, does the work, and passes back either the result or a **rejection code** (errno). `fork` is **photocopying a customer**, including what they're holding. `exec` is the copy **changing into a different person while keeping the same ticket number** (PID).

## How it works inside

### 1. System calls

1. The C library wrapper (`open()`, `read()`, `fork()`) puts a syscall number and arguments in CPU registers.
2. A special instruction (`syscall` on x86-64, `svc` on ARM) switches the CPU from **user mode** to **kernel mode**.
3. The kernel validates the request (permissions, SELinux, limits, namespaces), does the work, and returns.
4. On failure the call returns `-1` and sets **errno**. Error messages in logs ("No such file or directory", "Permission denied") are just errno values turned into text, so **seeing the failing syscall tells you exactly which check failed**.

A few frequent calls (like reading the clock) are served from the **vDSO** (virtual Dynamic Shared Object), a kernel page mapped into every process, with no mode switch. That's why `strace` may not show them.

### 2. Process lifecycle: fork → exec → exit → wait

```
 parent (bash, PID 343)
   │ fork()/clone() ───────────────► child (PID 344): a copy of the parent
   │                                   │ execve("/usr/bin/ls") → same PID, new program
   │ wait4() … blocks                  │ … runs …
   │                                   │ exit_group(0) → becomes a ZOMBIE (exit status kept)
   │ ◄──── SIGCHLD ────────────────────┘
   │ wait4() returns the status → the kernel frees the zombie
```

**`fork()` and copy-on-write (COW).** The child starts as a near-copy of the parent: same memory contents, same open fds, same credentials and signal settings. Memory isn't copied up front. Both share the physical pages, marked read-only, and a page is only copied when one side **writes** to it. So forking a 10 GiB process is fast, but a child that then writes a lot can suddenly need much more memory (Redis background saves are a famous case).

On Linux, both `fork()` and thread creation use **`clone()`**. Its flags decide what's shared: `CLONE_VM` (memory: makes a thread), `CLONE_FILES` (fd table), and `CLONE_NEWPID`, `CLONE_NEWNET`… (new **namespaces**: makes a container, topic 097).

**`execve()`** replaces the program in the current process (new code, data, heap, stack), but the **PID stays the same**. What survives matters:

| Survives `execve()` | Doesn't survive |
|---|---|
| PID, parent PID, credentials (unless the new file is set-UID or has capabilities) | Memory, other threads |
| Open fds **without** the close-on-exec flag | fds opened with `O_CLOEXEC` |
| cwd, umask, resource limits, nice value, cgroup, namespaces, SELinux context (unless a domain transition applies, topic 072) | Signal **handlers** (reset to default). **Ignored** signals stay ignored |
| The environment, **only** if the caller passes it (shells pass exported variables) | Unexported shell variables |

This one table explains: why `export` matters (topic 012), why a background job ignores Ctrl+C, why `httpd` changes SELinux domain when systemd starts it, and why a leaked fd follows a daemon into every child it starts.

**`exit()`, zombies and orphans.**
- When a process exits, the kernel frees its memory and files immediately, but keeps a tiny record (PID, exit status, CPU usage) until the parent collects it with `wait()`. Until then it's a **zombie** (`Z`, `<defunct>`).
- **You can't kill a zombie**; it's already dead. Fix or kill the **parent**.
- When a parent dies, its children are **re-parented** to PID 1 (or a "subreaper"), which reaps them.

**PID 1 is special:**
1. It adopts orphans and must reap them.
2. The kernel **doesn't deliver signals with a "default" action to PID 1** of a PID namespace when they're sent from inside that namespace. In a container whose PID 1 is `sleep infinity`, `kill -TERM 1` and even `kill -KILL 1` from inside do nothing. From the host, SIGKILL still works.
3. If PID 1 of a namespace exits, the kernel kills everything else in it.

That's why containers use a small init (`--init`: tini or catatonit), and why an app running as PID 1 must handle SIGTERM itself, or `podman stop` waits 10 seconds and then sends SIGKILL.

### 3. Credentials and capabilities

| ID | Meaning |
|---|---|
| **Real UID/GID** | Who started the process |
| **Effective UID/GID** | What permission checks use |
| **Saved set-UID** | Lets a set-UID program drop privilege and regain it later |
| **Supplementary groups** | Fixed when the login session starts (so a new group needs a re-login, topic 024) |

`/usr/bin/passwd` is set-UID root (topic 027): when alice runs it, exec sets the **effective** UID to 0 so it can write `/etc/shadow`.

**Capabilities** split root's power into about 40 separate privileges, each checked on its own:
- `CAP_DAC_OVERRIDE`: bypass file permissions
- `CAP_NET_BIND_SERVICE`: bind ports below 1024
- `CAP_NET_ADMIN`: change network configuration
- `CAP_SYS_ADMIN`: mounts and much more (the "new root")
- `CAP_KILL`, `CAP_CHOWN`, `CAP_SYS_PTRACE`…

**Container root is not host root.** A default container's root has only about 14 capabilities, plus namespaces, seccomp (syscall filtering) and SELinux limits. systemd units can drop capabilities too (topic 098).

### 4. File descriptors: three layers

```
process A fd table          open file descriptions                  inodes
  0 ─────────────────────► [/dev/pts/0, offset, flags] ───────────► pts inode
  1 ─────────────────────► [/var/log/app.log, offset 4096, O_APPEND] ─► inode 1234
process B (forked child)                                               ▲
  1 ─────────────────────► (the SAME description: shared offset) ──────┘
```
- The **fd** is an index into the process's table. It points to an **open file description** (current offset and flags), which points to the **inode** (topic 008).
- After `fork()`, parent and child share descriptions, and therefore the offset.
- **Redirection is fd plumbing** (topic 016). For `cmd > out 2>&1`, the shell's child does `fd=open("out")`, `dup2(fd,1)`, `dup2(1,2)`, then `execve()`. That's why the order of redirections matters.
- **Deleted-but-open files** (topic 020): `rm` removes a name. The inode's blocks are only freed when the link count is 0 **and** no fd still points to it. That's the "`df` says full, `du` says small" mystery.

### 5. Signals in depth

1. **Generated**:
   - by `kill()`;
   - by the terminal (Ctrl+C sends SIGINT to the **foreground process group**);
   - by the kernel (SIGSEGV on a bad memory access, SIGPIPE when writing to a closed pipe, SIGCHLD when a child exits);
   - by timers.
2. **Pending**: recorded on the target.
3. **Blocked?** Each thread has a **signal mask**; blocked signals wait.
4. **Delivered** when the target next returns from the kernel to user mode: run the handler, ignore it, or take the **default action** (terminate, core dump, stop, continue, ignore).

SIGKILL and SIGSTOP can't be caught, blocked or ignored.

**Process groups and sessions:**
- A **process group** is a job or pipeline; Ctrl+C and Ctrl+Z go to the foreground group.
- A **session** is all the groups of one login, led by the login shell.
- When the **controlling terminal** hangs up (SSH drops), the kernel sends **SIGHUP** to the session.

So:
- `nohup` sets SIGHUP to "ignored" before exec.
- `disown` stops the shell forwarding SIGHUP to a job.
- `setsid` starts a new session with no terminal.
- A systemd service has no terminal at all, which is the robust answer.

## Commands

### Threads

```bash
ps -o pid,tid,nlwp,cmd -L -p "$(pgrep -o sshd)"     # one row per thread; NLWP = thread count
ls /proc/$(pgrep -o chronyd)/task/                  # one directory per thread
```
- The scheduler and load average count **tasks**, so one busy multithreaded program can look like many runnable "processes".

### strace: watch the syscalls

```bash
sudo dnf install -y strace                           # Ubuntu: apt install strace
strace -c ls / > /dev/null
```
```
% time     seconds  usecs/call     calls    errors syscall
------ ----------- ----------- --------- --------- ----------------
 22.41    0.000124           6        19           mmap
 14.10    0.000078           8         9           openat
  9.40    0.000052          52         1           execve
...
100.00    0.000553           6        86         3 total
```
- A summary per syscall: count, errors and time. `errors 3` are usually harmless "file not found" probes.

```bash
strace -f -e trace=execve,clone,clone3,wait4,exit_group bash -c 'ls / > /dev/null; true'
```
```
343   execve("/usr/bin/bash", ["bash", "-c", "ls / > /dev/null; true"], …) = 0
343   clone(…flags=CLONE_CHILD_CLEARTID|CLONE_CHILD_SETTID|SIGCHLD…) = 344   ← fork: child 344
343   wait4(-1,  <unfinished ...>                                           ← parent waits
344   execve("/usr/bin/ls", ["ls", "/"], …) = 0                             ← child becomes ls
344   exit_group(0)                     = ?
343   <... wait4 resumed>[{WIFEXITED(s) && WEXITSTATUS(s) == 0}], 0, NULL) = 344   ← reaped
343   --- SIGCHLD {si_signo=SIGCHLD, si_code=CLD_EXITED, si_pid=344, …} ---
```
- The whole fork → exec → exit → wait cycle, live.

| Option | Meaning |
|---|---|
| `-f` | Follow children and threads |
| `-p PID` | Attach to a running process |
| `-e trace=SET` | Filter: names, or `%file`, `%process`, `%network`, `%signal`, `%memory` |
| `-tt` / `-T` | Timestamps / time spent in each call |
| `-y` | Show the file or socket behind each fd |
| `-o FILE` | Write to a file |

```bash
strace -f -e trace=%file -o /tmp/t sshd -T > /dev/null ; grep -v ENOENT /tmp/t | grep /etc   # which config files does it read?
sudo strace -f -tt -T -p 1234                                                              # what is this process doing right now?
```
- **`strace` slows the traced process a lot**: every syscall stops it twice. Use it briefly on production, filter with `-e`, and prefer eBPF tools for busy processes (topic 103).

### Zombies

```bash
bash -c 'sleep 1 & exec sleep 6' &      # bash starts "sleep 1", then turns itself into "sleep 6", which never wait()s
sleep 2 ; ps -o pid,ppid,stat,cmd -C sleep
```
```
  PID  PPID STAT CMD
  331   324 S    sleep 6
  333   331 Z    [sleep] <defunct>
```
- PID 333 is a zombie whose parent (331) never calls wait. It disappears when 331 exits.

```bash
ps -eo ppid,stat | awk '$2 ~ /Z/ {print $1}' | sort | uniq -c     # which parents own zombies?
```

### Credentials and capabilities

```bash
grep -E '^(Uid|Gid|Groups)' /proc/self/status       # Uid: real effective saved filesystem
grep Cap /proc/self/status
capsh --decode=00000000a80425fb                     # decode a mask (libcap package)
getcap /usr/bin/ping
sudo setcap cap_net_bind_service=+ep /usr/local/bin/myserver   # let a non-root binary bind port 80
```
```
Uid:	1000	1000	1000	1000
CapEff:	0000000000000000
0x00000000a80425fb=cap_chown,cap_dac_override,cap_fowner,cap_fsetid,cap_kill,cap_setgid,cap_setuid,cap_setpcap,cap_net_bind_service,cap_net_raw,cap_sys_chroot,cap_mknod,cap_audit_write,cap_setfcap
```
- A normal user has **no** effective capabilities. The decoded mask is the typical default set for container root: 14 capabilities, not all ~40.

### File descriptors and limits

```bash
ls -l /proc/$(pgrep -o chronyd)/fd
sudo ls /proc/1234/fd | wc -l          # how many are open (watch it grow = leak)
cat /proc/1234/limits | grep 'open files'
sudo lsof +L1                          # deleted-but-open files
```
```
lr-x------. 1 chrony chrony 64 Nov 17 10:12 0 -> /dev/null
lrwx------. 1 chrony chrony 64 Nov 17 10:12 5 -> 'socket:[23411]'
Max open files            1024                 524288               files
```
- Each fd shows what it points to. The limits line shows the soft (1024) and hard (524288) **per-process** limits.

| Limit | Scope | See / set |
|---|---|---|
| `RLIMIT_NOFILE` | **Per process** | `ulimit -Sn` / `-Hn`; `/proc/PID/limits` |
| systemd `LimitNOFILE=` | Per service (PAM limits don't apply to services) | `systemctl show -p LimitNOFILE svc`; raise with a drop-in (topic 098) |
| `/etc/security/limits.d/*.conf` | Login sessions (PAM) | `alice soft nofile 4096` |
| `fs.nr_open` | The ceiling for any process's hard limit | `sysctl fs.nr_open` |
| `fs.file-max`, `fs.file-nr` | **System-wide** open files | `cat /proc/sys/fs/file-nr` |

**"Too many open files" (`EMFILE`, errno 24) checklist:**
1. `/proc/PID/limits`: what limit does the process really have?
2. `ls /proc/PID/fd | wc -l`: how many are in use?
3. Watch over time: a **leak** keeps growing; a genuine need stays flat.
4. Raise `LimitNOFILE=` for the service **or** fix the leak.

### Signals

```bash
grep -E 'Sig(Pnd|Blk|Ign|Cgt)' /proc/1234/status
```
```
SigPnd:	0000000000000000
SigBlk:	0000000000000000
SigIgn:	0000000000000006
SigCgt:	0000000180004002
```
- Hex bitmasks; bit N−1 = signal N. `SigIgn …06` = bits 1 and 2 = signals 2 (SIGINT) and 3 (SIGQUIT) are **ignored**: a background job started from a non-interactive shell, which is why Ctrl+C doesn't reach it.

| Signal | Typical production meaning |
|---|---|
| SIGTERM (15) | "Please shut down." systemd/podman send it first, then SIGKILL after a timeout (`TimeoutStopSec=`, default 90 s) |
| SIGKILL (9) | Instant death, no cleanup; also the OOM killer. Exit code **137** = 128 + 9 |
| SIGHUP (1) | The terminal hung up; many daemons treat it as "reload config" |
| SIGSEGV (11) | Invalid memory access: an application bug (`coredumpctl`) |
| SIGPIPE (13) | Wrote to a pipe or socket whose reader is gone |
| SIGCHLD (17) | A child changed state; the parent should `wait()` |

### `/proc/PID`: a process's dashboard

| File | Shows |
|---|---|
| `status` | State, PPid, UIDs, threads, VmRSS, signal masks, capabilities, context switches |
| `cmdline`, `environ` | Arguments and environment (NUL-separated: `tr '\0' ' ' < /proc/PID/cmdline`) |
| `exe`, `cwd`, `root` | The binary (shows `(deleted)` after an upgrade replaced it), current directory, root directory |
| `fd/`, `fdinfo/` | Open fds, their offsets and flags |
| `limits` | Effective resource limits |
| `maps`, `smaps_rollup` | Memory mappings; RSS/PSS totals (topic 093) |
| `stack`, `wchan` | Where in the kernel the task is sleeping (root): **why is it stuck in D state?** |
| `io` | Bytes read and written |
| `ns/`, `cgroup` | Namespaces and cgroup (topic 097) |
| `oom_score`, `oom_score_adj` | The OOM killer's ranking (topic 093) |

### Try it
1. `strace -f -e trace=execve,clone,clone3,wait4 bash -c 'ls | wc -l'`: explain each line and why there are two child `execve`s.
2. fd inheritance: `exec 3>/tmp/fdtest ; bash -c 'ls -l /proc/$$/fd'`. The child has fd 3 too. Close it with `exec 3>&-` and repeat.
3. Make the zombie above, then kill its parent and watch the zombie get reaped.
4. `ulimit -n 50 ; python3 -c 'f=[open("/dev/null") for _ in range(100)]'`: read the `Errno 24`.
5. Deleted-but-open: hold a 50 MB file open with Python, `rm` it, compare `df` and `lsof +L1`, then kill the holder.

## Where you'll use it

- **Debugging "works by hand, fails under systemd":** a different environment, limits, capabilities, SELinux domain or working directory. All of these are exec-time inheritance rules.
- **Containers and Kubernetes:**
  - Exit code **137** = SIGKILL (often the OOM killer).
  - Slow pod termination = PID 1 not handling SIGTERM.
  - `terminationGracePeriodSeconds` is the SIGTERM → SIGKILL timeout.
  - Pod `securityContext.capabilities` adds or drops capabilities.
- **"Too many open files"** in Java, nginx and database services: `LimitNOFILE` and fd leaks.
- **Stuck processes:** `strace -p` for S state, `/proc/PID/stack` for D state.

## When it breaks

| Symptom | Mechanism | Commands |
|---|---|---|
| "No such file or directory", but the file exists | A wrong path, a missing **interpreter** in `#!`, or a missing shared library (the error is about the loader) | `strace -e trace=%file`, `head -1 script`, `ldd binary` |
| "Permission denied" as root | Capabilities dropped (container or unit), SELinux, immutable attribute, `noexec` mount | `grep Cap /proc/PID/status`, `ausearch -m avc`, `lsattr`, `findmnt` |
| Many zombies | The parent doesn't `wait()` | Find the parent; fix or restart it |
| The process ignores Ctrl+C | SIGINT is ignored or handled, or it's not in the foreground group | `/proc/PID/status` SigIgn/SigCgt |
| A container takes 10 s to stop | PID 1 has no SIGTERM handler | Add a handler, `--init`, or `STOPSIGNAL` |
| A service says "Too many open files" | `LimitNOFILE` too low, or an fd leak | `/proc/PID/limits`, `ls /proc/PID/fd \| wc -l` over time |
| A job dies when SSH disconnects | SIGHUP to the session | `systemd-run --unit=job …`, tmux, `nohup`/`setsid` |
| A process is stuck and `kill -9` does nothing | Uninterruptible sleep (D), usually storage or NFS | `cat /proc/PID/stack`, `ps -o stat,wchan:32`, `dmesg` |

## Quick recap

- Programs reach the kernel only through **syscalls**; failures return **errno**. `strace` shows them (`-f`, `-e trace=`, `-p`, `-c`).
- **fork** (copy-on-write, via `clone`) → **exec** (same PID, new program; fds, credentials, limits and ignored signals survive) → **exit** (zombie) → **wait** (reaped). PID 1 adopts orphans and is shielded from default-action signals.
- Real vs effective UID, set-UID, **capabilities** (container root ≠ host root).
- fd → open file description (offset) → inode; redirection = `dup2`; deleted-but-open files hold space. "Too many open files" = check `/proc/PID/limits` and the fd count.
- Signals: generated → pending → blocked? → delivered. SIGKILL/SIGSTOP can't be caught. Exit code 128+N = killed by signal N.

**Interview questions**

1. *What happens on `fork()`, and why is it fast?* The kernel creates a child that shares the parent's memory pages copy-on-write (plus copies of the fd table, credentials and signal settings). Pages are only copied when one side writes, so nothing large is copied up front.
2. *Why can't you kill a zombie, and how do you get rid of one?* It's already dead; only its exit status remains for the parent. Make the parent call `wait()`, or kill the parent so PID 1 adopts and reaps it.
3. *Why might `docker stop` / `podman stop` take 10 seconds?* PID 1 in the container doesn't handle SIGTERM, and the kernel won't apply the default action to a namespace's PID 1, so the runtime waits for its timeout and then sends SIGKILL.
