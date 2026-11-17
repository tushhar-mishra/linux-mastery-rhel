# 093 · Memory Management: Virtual Memory, Page Cache, Reclaim and the OOM Killer

> **You need first:** [092 · Processes and system calls](092-processes-and-system-calls.md) (and topics 034 top, 036 monitoring, 050 swap)
> **Next:** [094 · The storage I/O path](094-storage-io-path.md)

---

## What it is

How the kernel gives memory to processes, uses spare RAM, and decides what to do when RAM runs out.

| Term | Meaning |
|---|---|
| **Virtual memory** | Each process sees its own private range of addresses; the kernel maps them onto real RAM |
| **Page** | The unit of memory management: 4 KiB on x86-64 (`getconf PAGESIZE`) |
| **Page table** | The per-process map from virtual pages to physical RAM, walked by the CPU's **MMU** (Memory Management Unit) |
| **Page fault** | A CPU trap when a process touches a page that isn't mapped (yet) |
| **Anonymous memory** | Program data with no file behind it: heap, stack, `malloc` |
| **Page cache** | File contents kept in otherwise unused RAM |
| **Reclaim** | Freeing pages when RAM runs low |
| **OOM killer** | The kernel's last resort when memory is exhausted (OOM = Out Of Memory): it kills a process |

## Why it exists

"Is this server out of memory?" is one of the most misdiagnosed questions in operations:
- `free` looks alarming on perfectly healthy systems.
- Swap use isn't necessarily bad.
- A container can be OOM-killed while the host has gigabytes free.
- `VSZ` is almost meaningless.

This topic gives you the model that makes those numbers make sense.

## Analogy

RAM is a **desk**; disk is a **filing cabinet across the room**. Each worker (process) believes they have a huge private desk (virtual memory), but the office manager (kernel) only puts **pages they actually use** on the real desk. Spare desk space is covered with **photocopies of cabinet files** (page cache), which can be swept away instantly if someone needs room, because the originals are in the cabinet. A worker's own **scribbled notes** (anonymous memory) have no copy, so to clear them the manager must first **box them up in the basement** (swap). When the desk is truly full and nothing more can be cleared, the manager **fires a worker** (OOM kill).

## How it works inside

### 1. Virtual memory and lazy allocation

- **Isolation:** a process can't even address another's memory. Shared memory is an explicit mapping of the same physical pages.
- **Lazy allocation:** `malloc(1 GiB)` or `mmap()` only reserves **address space**. Physical pages are given out on **first touch**, through a page fault.
- **Sharing:** shared libraries, the page cache, and copy-on-write pages after `fork()` (topic 092) are mapped into many processes but stored once.

A real demonstration (Python):
```
start RSS kB 7888
after mmap 1GiB untouched RSS kB 8272 VmSize kB 1061368      ← 1 GiB of address space, almost no RAM
after touching 200MiB RSS kB 213072 minflt 52146             ← 200 MiB / 4 KiB ≈ 51,200 page faults
```

| Fault | Meaning | Cost |
|---|---|---|
| **Minor** | The page is in RAM (or is a fresh zero page); only the page table changes | Microseconds |
| **Major** | Data must be read from disk (file not cached, or page swapped out) | Milliseconds: real I/O |
| **Invalid** | The address isn't mapped, or the access isn't allowed → **SIGSEGV** | The process crashes |

A sustained high **major** fault rate means the working set doesn't fit in RAM (**thrashing**), or cold files are being read.

### 2. Anonymous vs file-backed memory

| | Anonymous | File-backed (page cache) |
|---|---|---|
| What | Heap, stack, `malloc`, private writable mappings | Read file data, executables, libraries, mmap'd files |
| Backed by | Nothing, except **swap** | The file itself |
| Reclaimed by | Writing to swap, then freeing | **Clean** pages: just dropped (re-read later). **Dirty** pages: written back first |

**This is why `free` is small on a healthy system.** Linux fills spare RAM with page cache, because empty RAM is wasted RAM. **`MemAvailable`** (the `available` column of `free -h`) estimates how much could be given to applications **without swapping**, counting reclaimable cache. That's the number to watch.

`tmpfs` (`/dev/shm`, `/run`) is page-cache memory with **no** backing file: it shows as `Shmem`, can't simply be dropped, and is real memory use.

### 3. Reclaim

The kernel keeps free memory above **watermarks** (derived from `vm.min_free_kbytes`):
1. **kswapd** (a background thread): below the *low* watermark, it reclaims until the *high* watermark. It drops clean cache, writes back dirty pages, and swaps anonymous pages, preferring **inactive** (not recently used) pages.
2. **Direct reclaim**: if allocations outrun kswapd, the allocating process must reclaim memory **itself**. It stalls, so latency rises everywhere. This is "memory pressure".
3. **OOM killer**: if reclaim can't free enough, the kernel kills a process.

`vm.swappiness` (0–200) biases reclaim between anonymous pages (→ swap) and file pages (→ drop cache). It is **not** "the percentage of RAM at which swapping starts" (topic 050).

**Measure pressure, not just usage.** **PSI** (Pressure Stall Information) reports the share of time tasks were stalled waiting for memory. It's a much better early warning than "free is low", and it exists per cgroup too (`memory.pressure`). **On RHEL, PSI is built into the kernel but switched off** (`CONFIG_PSI_DEFAULT_DISABLED=y`): `/proc/pressure/` and the cgroup `*.pressure` files don't exist until you boot with the kernel argument `psi=1` (`sudo grubby --update-kernel=ALL --args=psi=1`, then reboot; topic 054).

### 4. Overcommit

Because allocation is lazy, the kernel may promise more memory than exists:

| `vm.overcommit_memory` | Policy |
|---|---|
| `0` (default) | **Heuristic**: refuse only obviously impossible requests |
| `1` | Always allow (some Redis/database guides use this) |
| `2` | **Strict**: limit = swap + `overcommit_ratio`% of RAM (`CommitLimit`); `malloc` fails with `ENOMEM` instead of an OOM kill later |

With `0` or `1`, a program can allocate successfully and be **killed later**, when it touches memory that isn't there. With `2`, the failure happens at allocation time, but programs that reserve large address spaces (JVMs) may fail to start.

### 5. The OOM killer

The victim is chosen by a **badness** score: roughly its memory footprint (RSS + swap + page tables) as a share of available memory, adjusted by `oom_score_adj`.

| File | Range | Meaning |
|---|---|---|
| `/proc/PID/oom_score` | Read-only | The current ranking; **higher = killed first**. Compare values relative to each other |
| `/proc/PID/oom_score_adj` | −1000 … 1000 | A bias. **−1000 = never kill**; +1000 = kill first |
| systemd `OOMScoreAdjust=` | same | Persistent, per service (topic 098) |

The victim receives **SIGKILL**: exit code **137**; systemd records `Result: oom-kill`. `systemd-oomd` (where enabled) can act **earlier**, based on PSI, killing whole cgroups.

**Global OOM vs cgroup OOM:**

| | Global OOM | cgroup (container/service) OOM |
|---|---|---|
| Trigger | The whole machine is out of reclaimable memory | The cgroup reached its `memory.max` |
| Host free memory | Exhausted | **Can be plentiful** |
| Victim from | All processes | Only that cgroup |
| Evidence | `journalctl -k` | `memory.events` (`oom_kill`), kernel log "Memory cgroup out of memory", container status `OOMKilled` |

### 6. Huge pages and NUMA (awareness)

- **Huge pages** (2 MiB on x86-64) reduce page-table and **TLB** (Translation Lookaside Buffer: the CPU's cache of address translations) overhead for big-memory applications.
  - **Explicit** huge pages (`vm.nr_hugepages`) are reserved up front and unavailable to anything else.
  - **Transparent Huge Pages** (THP) are automatic. Some databases recommend `madvise` or `never`, because THP compaction can cause latency spikes. tuned profiles manage THP (topic 056).
- **NUMA** (Non-Uniform Memory Access): on multi-socket servers, each CPU has "local" memory that is faster to reach. One NUMA node can run out and start reclaiming while the machine as a whole still has free memory. See `numactl --hardware` and `numastat -p PID`.

## Commands

### System-wide

```bash
free -h
```
```
               total        used        free      shared  buff/cache   available
Mem:           7.5Gi       2.1Gi       312Mi        48Mi       5.4Gi       5.4Gi
Swap:          4.0Gi        12Mi       4.0Gi
```
- Only 312 MiB "free", but **5.4 GiB available**: most RAM is page cache that can be reclaimed. This machine is healthy.

```bash
grep -E 'MemTotal|MemFree|MemAvailable|^Cached|Dirty|Writeback:|AnonPages|Shmem:|SUnreclaim|Committed_AS|CommitLimit' /proc/meminfo
```

| Field | Meaning | Watch for |
|---|---|---|
| `MemAvailable` | Real headroom | Falling steadily |
| `Cached` / `Buffers` | Page cache / block metadata | Big is good |
| `Dirty` / `Writeback` | File pages waiting to be written / being written | Large and growing = storage can't keep up (topic 094) |
| `AnonPages` | Application (anonymous) memory | Unbounded growth = a leak |
| `Shmem` | tmpfs + shared memory | `/dev/shm` filling RAM |
| `Slab`: `SReclaimable` + `SUnreclaim` | Kernel object caches | Growing `SUnreclaim` = possible kernel leak (`slabtop`) |
| `Committed_AS` / `CommitLimit` | Memory promised / strict-mode limit | Promised far above RAM + swap = risk |

```bash
vmstat 1 5           # si/so = swap in/out per second (sustained non-zero = thrashing)
sar -B 1 3           # majflt/s system-wide (sysstat)
cat /proc/pressure/memory
```
```
some avg10=0.00 avg60=0.00 avg300=0.00 total=0
full avg10=0.00 avg60=0.00 avg300=0.00 total=0
```
- `some` = % of time at least one task was stalled on memory; `full` = % of time **all** non-idle tasks were stalled (severe). Rising values = real pressure.

### Per process: VSZ, RSS, PSS, USS

| Metric | Meaning | Problem |
|---|---|---|
| **VSZ / VIRT** | All mapped address space | Includes reserved-but-unused memory: nearly meaningless for capacity |
| **RSS / RES** | This process's pages currently in RAM | **Shared pages counted fully in every process**: summing RSS over-counts |
| **PSS** | RSS with each shared page divided among its sharers | Sums correctly across processes |
| **USS** | Pages used **only** by this process | What you'd free by killing it |

```bash
ps -eo pid,rss,vsz,min_flt,maj_flt,cmd --sort=-rss | head -5
sudo cat /proc/$(pgrep -o httpd)/smaps_rollup | grep -E '^(Rss|Pss|Swap):'
grep VmSwap /proc/$(pgrep -o httpd)/status
```
```
Rss:                2156 kB
Pss:                 782 kB
Swap:                  0 kB
```
- RSS 2.1 MB but PSS only 0.8 MB: most of its resident pages are shared libraries, used by others too.

### OOM

```bash
cat /proc/$(pgrep -o sshd)/oom_score ; cat /proc/$(pgrep -o sshd)/oom_score_adj
journalctl -k | grep -iE 'out of memory|oom-kill|Killed process'
```
```
0
-1000
Nov 17 11:02:41 server1 kernel: Out of memory: Killed process 4242 (java) total-vm:8123456kB, anon-rss:6234120kB, file-rss:0kB, shmem-rss:0kB, UID:1001 pgtables:12880kB oom_score_adj:0
```
- RHEL sets `sshd` to −1000, so you can always log in to a struggling box. The kernel log shows the victim, its anonymous RSS (6.2 GB: the real culprit) and its adj.

### Try it
1. **Page cache:** `free -h` → `dd if=/dev/zero of=/var/tmp/big bs=1M count=1024; sync` → `free -h` (buff/cache +1 GiB, `available` about the same) → `rm /var/tmp/big`. Lab only: `sync; echo 3 | sudo tee /proc/sys/vm/drop_caches` empties clean caches; never a production "fix".
2. **cgroup OOM without a container:** `sudo systemd-run --scope -p MemoryMax=64M python3 -c 'b=bytearray(200*1024*1024)'` → `Killed`; then `journalctl -k | tail` shows "Memory cgroup out of memory".
3. **RSS vs PSS:** sum `ps -o rss` for all `httpd` workers and compare with the sum of their PSS values.
4. **OOM priority:** start two `sleep` processes; set one's `oom_score_adj` to 1000 and the other's to −1000; compare their `oom_score`.

## Where you'll use it

- **Kubernetes:**
  - A pod's `resources.limits.memory` becomes the cgroup's `memory.max`. Exceeding it means `OOMKilled` (exit code 137) even when the node has free RAM.
  - `requests` affect scheduling, and **eviction** happens when the node's `MemAvailable` falls below kubelet thresholds.
  - Kubernetes has historically required **swap off** on nodes (swap support is newer and opt-in).
- **JVM and database tuning:** heap sizes vs container limits; THP and huge pages settings.
- **Capacity planning and alerts:** alert on `MemAvailable`, PSI and major faults, not on "free".

## When it breaks

| Symptom | Interpretation | Next step |
|---|---|---|
| `/proc/pressure/memory: No such file or directory` | PSI is disabled by default on RHEL kernels | Kernel argument `psi=1`, reboot |
| `free` near 0, `available` high | The page cache doing its job | Nothing to fix |
| Swap used, but `si`/`so` ≈ 0 | Cold pages parked in swap | Usually harmless |
| Sustained `si`/`so`, high major faults, rising PSI | **Thrashing**: working set > RAM | Find the top PSS users; add RAM or cap workloads |
| Exit 137 / `Killed` | OOM kill (global or cgroup) | `journalctl -k \| grep -i oom`; cgroup `memory.events`; raise the limit or fix the leak |
| A container is OOMKilled while the host has free RAM | Its cgroup `memory.max` was reached | Compare the limit with `memory.current` / `memory.stat` |
| `AnonPages`/RSS grows without bound | An application memory leak | Track RSS over time; restart as mitigation; profile the app |
| `SUnreclaim` keeps growing | A kernel object leak | `slabtop`; check known bugs; vendor support |
| `Dirty` stays large, writes stall | Storage slower than the writers | Topic 094 |
| `fork: Cannot allocate memory` with free RAM | Strict overcommit, or PID/thread limits | `sysctl vm.overcommit_memory`; `CommitLimit` vs `Committed_AS`; `pids.max` |
| `/dev/shm` full | tmpfs uses RAM | `df -h /dev/shm`; find the files |

## Quick recap

- Virtual memory + 4 KiB pages + lazy allocation. **Minor** faults are cheap; **major** faults mean disk I/O.
- Anonymous memory → swap; file pages → dropped or written back. **`MemAvailable`** is the real headroom; low "free" is normal.
- Reclaim: kswapd → direct reclaim (stalls) → **OOM killer** (SIGKILL, exit 137). Watch PSI `/proc/pressure/memory`.
- VSZ ≫ RSS > PSS ≥ USS; use `smaps_rollup`. `oom_score_adj` −1000 = never kill.
- **cgroup OOM** happens at `memory.max`, even with plenty of host RAM (containers, pods).

**Interview questions**

1. *Why is "free" memory low on a healthy Linux server?* Linux uses unused RAM as page cache. That cache is reclaimable, so `MemAvailable` (`available` in `free`) is the real headroom.
2. *A container was killed with exit code 137, but the host has 30 GB free. Why?* Its cgroup hit `memory.max`, so the cgroup OOM killer sent SIGKILL (128 + 9 = 137). Check `memory.events` and the kernel log.
3. *What's the difference between RSS and PSS?* RSS counts every resident page of a process, including shared ones in full; PSS divides each shared page among the processes sharing it, so PSS values add up correctly.
