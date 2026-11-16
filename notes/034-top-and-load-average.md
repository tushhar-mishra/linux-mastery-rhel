# 034 · top, Load Average and Reading a Busy System

> **You need first:** [033 · Processes and signals](033-processes-and-signals.md)
> **Next:** [035 · Process priority: nice and renice](035-process-priority-nice.md)

---

## What it is

**`top`** is a live, self-refreshing view of the whole system: how busy the CPUs are, how much memory is used, and which processes use the most. You can also kill and reprioritise processes from inside it.

Key words:
- **Load average**: three numbers (1, 5 and 15 minutes) showing **how many tasks were running or waiting** on average. On Linux, this includes tasks waiting for **disk I/O** (`D` state).
- **CPU states** (`us`, `sy`, `wa`, `st`, …): **what** the CPU time was spent on.
- **Page cache** (`buff/cache`): spare RAM the kernel uses to keep recently read files in memory. It is handed back when programs need memory.
- **avail Mem**: how much memory new programs could really get. This is the number that matters.
- **Steal time** (`st`): on a VM, CPU time the hypervisor gave to *other* VMs while yours wanted it.

`htop` (from EPEL, or apt) is a friendlier, colourful alternative.

## Why it exists

"The server is slow" can mean four completely different things: not enough CPU, slow disks, not enough memory, or a noisy neighbour on the hypervisor. `top`'s summary lines tell you **which** in seconds, before you start guessing. The process list then tells you **who** is responsible.

## Analogy

The system is a **supermarket**. CPUs are **checkout lanes**. **Load average** is the average number of customers being served **or standing in line**. If people are stuck waiting at the deli counter (disk I/O), Linux counts them too. A load of 8 with 8 lanes is busy but fine. A load of 8 with 2 lanes means long queues. And if the queue is full of people waiting at the deli (high `wa`), opening more lanes (CPUs) won't help.

## How it works inside

`top` reads files in `/proc` every few seconds (`/proc/loadavg`, `/proc/stat`, `/proc/meminfo`, and `/proc/<PID>/stat` for each process), works out the differences since the last reading, and redraws the screen.

### The summary area

```
top - 15:39:37 up 9 days, 15:26,  2 users,  load average: 3.10, 1.80, 0.95
Tasks: 212 total,   3 running, 209 sleeping,   0 stopped,   0 zombie
%Cpu(s): 62.0 us,  8.1 sy,  0.0 ni, 22.4 id,  6.9 wa,  0.0 hi,  0.6 si,  0.0 st
MiB Mem :   7684.2 total,    310.1 free,   3900.3 used,   3473.8 buff/cache
MiB Swap:   2048.0 total,   2048.0 free,      0.0 used.   3784.0 avail Mem
```

| Line | Meaning |
|---|---|
| `up 9 days` / `2 users` | Uptime and logged-in sessions |
| **load average** `3.10, 1.80, 0.95` | Averages over 1, 5 and 15 minutes. Here it's **rising** (1-min > 15-min) |
| Tasks | Counts by state (running, sleeping, stopped, zombie) |
| `%Cpu(s)` | Where CPU time went (table below) |
| Mem | `free` (truly unused), `used`, `buff/cache` (reclaimable cache) |
| Swap / **avail Mem** | Swap use, and the memory available to new programs |

### CPU states

| Field | Time spent… | High value means |
|---|---|---|
| `us` | Running user programs | Applications are CPU-busy |
| `sy` | Running kernel code | Lots of system calls, interrupts, I/O handling |
| `ni` | User programs with a positive nice value (topic 035) | Low-priority batch jobs |
| `id` | Idle | Spare capacity |
| `wa` | **Idle while waiting for I/O** | **Storage is the bottleneck** |
| `hi` / `si` | Hardware / software interrupts | Heavy network or disk traffic |
| `st` | **Stolen** by the hypervisor | The VM host is overloaded; you can't fix it inside the VM |

### Reading load average correctly

- **Compare it to the CPU count** (`nproc`). Load 4.0 means saturated on 4 CPUs, but quiet on 32.
- Linux counts **runnable (`R`)** and **uninterruptible (`D`)** tasks, including threads. So **high load with low `us`/`sy` and high `wa` = an I/O problem**, not CPU. One hung NFS mount with 40 stuck threads can show a load of 40 on an idle machine.
- **Trend:** 1-min ≫ 15-min = getting worse; 1-min ≪ 15-min = recovering.
- It's an exponentially smoothed average, so it reacts with a delay.

### Memory: "free" being low is normal

Linux puts unused RAM to work as **page cache** (topic 093). So `free` is almost always small on a healthy server. Watch **`avail Mem`** instead, along with swap activity (`vmstat 1`, the `si`/`so` columns, topic 036). Real memory trouble = `avail Mem` low **and** swapping **and/or** OOM-killer messages.

### The process columns

| Column | Meaning |
|---|---|
| `PID` / `USER` | Process ID / effective user |
| `PR` / `NI` | Priority (`20 + NI` for normal tasks; `rt` = real-time) / nice value |
| `VIRT` | **Virtual** memory reserved: not real use, usually ignore |
| `RES` | **Resident** memory: actually in RAM. The real number |
| `SHR` | The part of RES shared with others (libraries) |
| `S` | State (R, S, D, T, Z, I) |
| `%CPU` | Percent of **one** CPU since the last refresh. **Can exceed 100%** for multi-threaded programs (400% = 4 full cores) |
| `%MEM` | RES as a share of total RAM |
| `TIME+` | Total CPU time used |
| `COMMAND` | Name (`c` toggles the full command line) |

## Commands

```bash
top
```

### Keys inside top

| Key | Action |
|---|---|
| `P` / `M` / `T` / `N` | Sort by CPU / memory / CPU time / PID |
| `R` | Reverse the sort |
| `1` | Show each CPU separately (spot one maxed-out core) |
| `k` | **Kill**: enter the PID, then the signal (default 15) |
| `r` | **Renice**: enter the PID, then the new nice value |
| `u` | Show one user's processes |
| `o` | Filter, e.g. `%CPU>5.0` or `COMMAND=nginx` (`=` clears filters) |
| `c` | Full command lines |
| `V` | Tree view |
| `H` | Show threads |
| `t` / `m` | Bar-graph style for CPU / memory |
| `f` | Choose columns |
| `d` | Change the refresh interval |
| `W` | Save your layout |
| `q` | Quit |

### Useful start options

```bash
top -o %MEM               # start sorted by memory
top -u nginx              # only nginx's processes
top -p 1234,5678          # only these PIDs
top -H -p 1234            # the threads of one process
top -b -n 1 | head -15    # batch mode: one snapshot as plain text (scripts, incident notes)
```

```bash
uptime ; nproc
```
```
 15:40:02 up 9 days, 15:27,  2 users,  load average: 3.10, 1.80, 0.95
4
```
- Load 3.1 on 4 CPUs: busy but not overloaded.

```bash
cat /proc/loadavg
```
```
3.10 1.80 0.95 3/412 98123
```
- The raw source: the three averages, then `3/412` = runnable tasks right now / total tasks, then the most recently created PID.

```bash
ps -eo pid,stat,cmd | awk '$2 ~ /^D/'
```
```
  4410 D    rsync -a /data /mnt/nfs/backup
```
- Lists processes in `D` state: the first thing to check when load is high but the CPU is idle.

```bash
free -h
```
```
               total        used        free      shared  buff/cache   available
Mem:           7.5Gi       3.8Gi       302Mi        45Mi       3.4Gi       3.7Gi
Swap:          2.0Gi          0B       2.0Gi
```
- Only 302 MiB is free, but **3.7 GiB is available**. Healthy.

### Try it
1. Run `top`, press `1`, `P`, `M`, `c`, `V`. Get comfortable.
2. Start a CPU burner: `sh -c 'while :; do :; done' &`. Watch it in top, then kill it from top with `k`.
3. Run `dd if=/dev/zero of=/tmp/big bs=1M count=3000 oflag=direct` in one window and watch `wa` rise in top. Delete `/tmp/big` afterwards.
4. Save a snapshot with `top -b -n 1 > /tmp/top-$(date +%F_%H%M).txt`.

## Where you'll use it

- **First 60 seconds on a slow server** (topic 103): `uptime` → `top` → which CPU state is high → which process.
- **Incident evidence:** `top -b -n 1` before restarting anything, so you can explain the problem later.
- **VMs and cloud:** persistent `st` above 5–10% is a "noisy neighbour" or undersized host. Escalate it, or move to a different instance type.
- **Kubernetes nodes:** `kubectl top node/pod` gives a similar summary from metrics; on the node itself, top shows the container processes like any others.
- **Memory incidents:** after a crash, `journalctl -k | grep -i oom` (topic 093).

## When it breaks

| Observation | Likely meaning | Next step |
|---|---|---|
| High load, low `us`/`sy`, high `wa` | Storage or NFS bottleneck | Find `D` processes; `iostat -xz 1` (topic 036); `dmesg` for disk errors |
| One process at 100% `us` | CPU-bound application or a busy loop | Inspect it; renice or stop it; profile (topic 103) |
| High `sy` | Heavy kernel work: syscalls, interrupts, I/O | `perf top` / `strace -c` (topics 092, 103) |
| High `st` | Hypervisor overcommit | Escalate to the virtualization/cloud team |
| `free` near 0 but `avail Mem` high | Normal page cache | Nothing to fix |
| `avail Mem` low and swap busy | Real memory pressure | Top `RES` processes; add RAM or set limits |
| Zombie count rising | A parent isn't collecting children | Restart the parent service |
| `%CPU` above 100% | Multi-threaded program on several cores | Normal; press `H` to see threads |

## Quick recap

- Load average = average count of runnable + I/O-blocked tasks over 1/5/15 min. Compare it with `nproc`.
- CPU states: `us` app, `sy` kernel, `wa` waiting for disk, `st` stolen by the hypervisor.
- Look at `avail Mem`, not `free`. `RES` is real memory; `VIRT` mostly isn't.
- Keys: `P` `M` `1` `c` `k` `r` `H` `q`. Script with `top -b -n 1`.

**Interview questions**

1. *What does load average measure on Linux?* Smoothed 1/5/15-minute averages of tasks that are runnable or in uninterruptible sleep. Because it includes `D` state, I/O stalls raise the load even when CPUs are idle.
2. *Load is 8 on a server. Is that bad?* It depends on the CPU count and the cause. On 16 CPUs it's fine; on 2 it's overloaded. If `wa` is high, the problem is storage, not CPU.
3. *Why is "free" memory always low on Linux?* The kernel uses spare RAM as page cache. That memory is reclaimed when needed, so "available" is the real headroom.
