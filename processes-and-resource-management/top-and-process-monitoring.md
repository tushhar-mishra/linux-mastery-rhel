# top & Process Monitoring

> **Sessions:** S29 (top), S56 (see [system resource monitoring](system-resource-monitoring.md)) · **Objective:** *Identify CPU/memory intensive processes and kill processes* · *Adjust process scheduling* **[RHCSA Core]**
> **Related:** [Processes & signals](processes-and-signals.md) · [Priority & nice](process-priority-and-nice.md) · [System resource monitoring](system-resource-monitoring.md) · [Filesystem hierarchy (`/proc`)](../linux-fundamentals/filesystem-hierarchy.md) · [Memory management](memory-management.md) · [Processes & system calls](processes-and-system-calls.md)

## 1. Overview

`top` (from procps-ng) is an interactive, continuously updating view of system load and processes. It's the fastest way to find what's consuming CPU or memory, and it can kill and renice processes directly. Pair it with `ps` (snapshots, scripting), `free`, `uptime` and `vmstat`.

## 2. The Summary Area

````
top - 15:39:37 up 90 days, 15:26,  2 users,  load average: 0.00, 0.00, 0.00
Tasks:  27 total,   1 running,  26 sleeping,   0 stopped,   0 zombie
%Cpu(s):  0.0 us,  0.0 sy,  0.0 ni,100.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
MiB Mem :   1984.2 total,    250.1 free,    900.3 used,    833.8 buff/cache
MiB Swap:   2048.0 total,   2048.0 free,      0.0 used.   1084.0 avail Mem
````

| Line | Meaning |
|---|---|
| Uptime / users | Time since boot; logged-in sessions (same as `uptime`, `who`) |
| **Load average** | 1/5/15-minute exponentially damped averages of the number of **tasks (threads)** that are runnable (R) or in uninterruptible sleep (D). A process with 40 threads all in D adds 40 |
| Tasks | Totals by state (sleeping = S+D; stopped = T; zombie = Z) |
| %Cpu(s) | See the CPU states table below |
| Mem / Swap | `free`, `used`, `buff/cache` (reclaimable cache), **`avail Mem`** (what new processes can really use) |

### CPU states

| Field | Time spent in |
|---|---|
| `us` | User-space processes (normal nice) |
| `sy` | Kernel |
| `ni` | User-space processes with a **positive nice** value |
| `id` | Idle |
| `wa` | Idle **while waiting for I/O** (high = storage bottleneck) |
| `hi` / `si` | Hardware / software interrupts |
| `st` | **Steal**: time the hypervisor gave this VM's CPU to others (high = overcommitted host) |

### Interpreting load average

- Compare it to the CPU count (`nproc`). A load of 4.0 is saturated on 4 CPUs and idle-ish on 32.
- Because **D-state** processes count, high load with low `us`/`sy` and high `wa` means an **I/O problem**, not a CPU problem.
- Look at the trend: 1-min ≫ 15-min means load is rising; 1-min ≪ 15-min means it's recovering.

### Memory: "free" isn't the whole story

Linux uses spare RAM as page cache, so `free` is usually small. Watch **`avail Mem`**, plus swap usage growth and swap-in activity (`vmstat 1`: `si`/`so` columns). `buff/cache` is given back automatically when applications need memory.

## 3. The Task Area (columns)

| Column | Meaning |
|---|---|
| `PID` / `USER` | Process ID / **effective** user |
| `PR` / `NI` | Priority as top shows it (`20 + NI` for normal tasks; `rt` = real-time) / nice value |
| `VIRT` | Total **virtual** address space (incl. shared libs, mapped files, reserved-but-unused); not real usage |
| `RES` | Resident memory actually in RAM |
| `SHR` | Part of RES that's shared (libraries, shared memory) |
| `S` | State (R, S, D, T, Z, I) |
| `%CPU` | Share of **one** CPU since the last refresh; can exceed 100% for multi-threaded processes (Irix mode; `I` toggles) |
| `%MEM` | RES as a share of total RAM |
| `TIME+` | CPU time consumed since start |
| `COMMAND` | Name (`c` shows the full command line; `[brackets]` = kernel threads) |

## 4. Interactive Keys

| Key | Action |
|---|---|
| `P` / `M` / `N` / `T` | Sort by CPU / memory / PID / CPU time |
| `R` | Reverse the sort order |
| `<` / `>` | Move the sort column left / right |
| `k` | **Kill**: enter PID, then signal (default 15) |
| `r` | **Renice**: enter PID, then new nice value |
| `u` | Show one user's processes |
| `o` / `O` | Add a filter (e.g., `COMMAND=sshd`, `%CPU>5.0`, `!USER=root`); `=` clears filters |
| `c` | Toggle full command line |
| `V` | Forest (tree) view |
| `H` | Toggle threads |
| `1` | Show each CPU separately |
| `t` / `m` | Cycle CPU / memory summary styles (bars) |
| `f` | Choose and order columns |
| `d` / `s` | Change the refresh delay |
| `W` | Save settings (`~/.toprc`, or `~/.config/procps/toprc` on newer procps-ng) |
| `h` / `?` | Help |
| `q` | Quit |

## 5. Command-Line Options

```bash
top -o %MEM                    # start sorted by memory
top -u apache                  # one user
top -p 1234,5678               # specific PIDs
top -H -p 1234                 # threads of one process
top -c                         # full command lines
top -d 2                       # 2-second refresh
top -b -n 1 | head -20         # batch mode: one snapshot, for scripts and logs
top -b -n 1 -o %CPU | sed -n '7,12p'   # top CPU consumers in a script
```

## 6. Complementary Tools

```bash
uptime                       # load averages
nproc ; lscpu                # CPU count / topology
free -h                      # memory summary (look at "available")
vmstat 1 5                   # r/b queues, swap si/so, I/O bi/bo, us/sy/id/wa/st
ps -eo pid,user,%cpu,%mem,cmd --sort=-%cpu | head
cat /proc/loadavg /proc/meminfo
```

`iostat`, `mpstat`, `pidstat`, `sar` (sysstat) and the bottleneck workflow are covered in [system resource monitoring](system-resource-monitoring.md). `htop` (EPEL) and Cockpit offer interactive alternatives.

## 7. RHCSA Exam Focus **[RHCSA Core]**

- Find the CPU or memory hog: `top` then `P` or `M` (or `ps --sort`), read its PID and owner.
- Kill it from top (`k`) or with `kill PID`; renice it from top (`r`) or with `renice`.
- Verify the change: the process is gone, or `NI` shows the new value.

## 8. Production Practices **[Production Practice]**

- First check **which resource** is the problem: `us`/`sy` (CPU), `wa` (disk), `st` (hypervisor), `avail Mem`/swap (memory).
- Use batch mode (`top -b -n 1`) to capture evidence during incidents before restarting anything.
- On VMs, persistent `st` > 5–10% means the host is overcommitted; it's not fixable inside the guest.
- The OOM killer logs to the kernel log: `journalctl -k | grep -i oom` after memory incidents.

## 9. Troubleshooting

| Observation | Likely meaning | Next step |
|---|---|---|
| High load, low `us`/`sy`, high `wa` | Storage/NFS bottleneck | Find `D`-state processes: `ps -eo pid,stat,cmd \| awk '$2 ~ /D/'`; check `dmesg`, `iostat -xz` |
| High `us` from one PID | CPU-bound application | Inspect, renice, or stop it |
| High `sy` | Kernel work (syscalls, interrupts, I/O) | `perf`/`strace` [Advanced] |
| High `st` | Noisy neighbors on the hypervisor | Escalate to the virtualization team |
| `free` near 0 but `avail Mem` high | Normal page cache | Nothing to fix |
| `avail Mem` low and swap `si`/`so` busy | Real memory pressure | Find the top `RES` consumers; add RAM/limits |
| Zombie count rising | Parent not reaping | Restart the parent process/service |

## 10. Interview Questions

| Question | Answer |
|---|---|
| What does load average measure on Linux? | Exponentially damped 1/5/15-minute averages of tasks (threads) that are runnable or in uninterruptible (D) sleep. Unlike most UNIXes, Linux includes D, so I/O stalls raise load. For CPU-only pressure use `vmstat` `r` or `/proc/pressure/cpu`. |
| Is a load of 8 bad? | Depends on CPU count and on whether it's CPU or I/O (`wa`). |
| VIRT vs RES? | VIRT is reserved address space; RES is physical RAM in use. |
| Why is "free" memory always low? | The kernel uses spare RAM as cache; `available` is the real headroom. |
| What's steal time? | CPU time this VM wanted but the hypervisor gave to another VM. |
| How do you capture top output in a script? | `top -b -n 1`. |

## 11. Quick Revision

````
load ≈ R + D processes, compare to nproc · us sy ni id wa hi si st · avail Mem matters, not free
PR = 20+NI · VIRT ≠ usage, RES = RAM · %CPU can exceed 100 (per-CPU)
keys: P M N T R k r u o = c V H 1 t m f d W q · top -o %MEM -u user -p PIDs -H -c -b -n 1
uptime nproc free -h vmstat 1 ps --sort=-%cpu
````

## 12. Cross-References

- [Processes & signals](processes-and-signals.md)
- [Priority & nice](process-priority-and-nice.md)
- [System resource monitoring (vmstat, iostat, mpstat, sar)](system-resource-monitoring.md)
- [Filesystem hierarchy (`/proc`)](../linux-fundamentals/filesystem-hierarchy.md)
- [tuned profiles](../containers-and-virtualization/tuned-profiles.md) · [Memory management](memory-management.md) · [Performance & observability tools](../advanced-rhel-and-career-notes/performance-and-observability.md)
