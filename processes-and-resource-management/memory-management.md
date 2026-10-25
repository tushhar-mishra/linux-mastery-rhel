# Linux Memory Management

> **Track:** **[Internals]** · **[Production Practice]** · **Verified:** demos on a RHEL 10.2 UBI container (kernel 6.12). Sysctl values printed inside containers come from the container host's kernel; RHEL defaults are stated separately and should be checked on your system with `sysctl`.
> **Prerequisites:** [Processes & system calls](processes-and-system-calls.md) · [top & monitoring (free vs available)](top-and-process-monitoring.md) · [Swap](../storage-and-filesystems/swap.md)
> **Next:** [Storage I/O path (page cache writeback)](../storage-and-filesystems/storage-io-path.md) · [Namespaces & cgroups (memory limits)](../containers-and-virtualization/namespaces-and-cgroups.md)

## 1. Why This Matters

"Is this server out of memory?" is one of the most commonly misdiagnosed questions in operations. `free` looks alarming on healthy systems, swap use isn't necessarily bad, a container can be OOM-killed while the host has gigabytes free, and `VSZ` is almost meaningless. This note gives you the model that makes those numbers make sense.

## 2. Virtual Memory: the Core Idea

Every process sees its **own virtual address space**: a range of addresses from 0 to a very large number. The kernel and the CPU's **MMU** translate virtual addresses to physical RAM through **page tables**, in units of **pages** (4 KiB on x86-64 and on RHEL's standard aarch64 kernel; `getconf PAGESIZE`).

Consequences:

- **Isolation:** one process can't address another's memory (shared memory is an explicit mapping of the same physical pages).
- **Lazy allocation:** `malloc(1 GiB)` or `mmap()` only reserves address space. Physical pages are allocated on **first touch**, through a **page fault**.
- **Sharing:** shared libraries, the page cache and copy-on-write pages after `fork()` are mapped into many processes but stored once.

Verified demo (Python, inside a container):

```
start RSS kB 7888
after mmap 1GiB untouched RSS kB 8272 VmSize kB 1061368      ← 1 GiB of address space, almost no RAM
after touching 200MiB RSS kB 213072 minflt 52146             ← 200 MiB / 4 KiB ≈ 51,200 page faults
```

### 2.1 Page faults

| Fault | Meaning | Cost |
|---|---|---|
| **Minor** | Page is in RAM (or zero-fill on first touch); only the page table needs updating | Microseconds |
| **Major** | Data must be read from disk (file not in page cache, or page was swapped out) | Milliseconds: an I/O |
| **Invalid** | Address not mapped or access not allowed → **SIGSEGV** | Process crashes |

```bash
ps -o pid,min_flt,maj_flt,rss,vsz,cmd -p PID       # cumulative fault counters
/usr/bin/time -v cmd                               # "Major (requiring I/O) page faults" (time package)
sar -B 1                                           # system-wide: majflt/s (sysstat)
```

A sustained high **major** fault rate means the working set doesn't fit in RAM (thrashing), or cold files are being read.

## 3. Two Kinds of Memory: Anonymous and File-Backed

| | Anonymous memory | File-backed memory (page cache) |
|---|---|---|
| What | Heap, stack, `malloc`, private writable mappings | Contents of files: read data, executables, libraries, mmap'd files |
| Backed by | Nothing on disk, except **swap** | The file itself |
| How the kernel reclaims it | Write to **swap**, then free | **Clean** pages: just drop them (re-read later). **Dirty** pages: write back first |
| `/proc/meminfo` | `AnonPages`, `Active(anon)`/`Inactive(anon)` | `Cached`, `Buffers`, `Active(file)`/`Inactive(file)`, `Dirty`, `Writeback` |

**The page cache** holds file data in otherwise unused RAM, so repeated reads come from memory. This is why `free` is small on a healthy system, and why `MemAvailable` (`free -h` → `available`) is the number to watch: it estimates how much can be given to applications **without swapping**, counting reclaimable cache.

`tmpfs` (`/dev/shm`, `/run`, and `/tmp` if configured that way) is page-cache memory with no backing file: it shows up as `Shmem`, can't simply be dropped, and can only be swapped. A full `/dev/shm` is real memory use.

## 4. Reading `/proc/meminfo`

| Field | Meaning | Watch for |
|---|---|---|
| `MemTotal` | RAM usable by the kernel | — |
| `MemFree` | Completely unused | Low is **normal** |
| **`MemAvailable`** | Estimated memory available for new work without swapping | The real headroom |
| `Buffers` / `Cached` | Block-device metadata cache / file page cache (includes `Shmem`) | Big = good, usually |
| `SwapCached` | Pages in RAM that also have a copy in swap | — |
| `Active(anon/file)` / `Inactive(anon/file)` | LRU lists: recently used vs reclaim candidates | Huge `Inactive(anon)` + swap pressure = cold app memory |
| `Dirty` / `Writeback` | Modified file pages waiting to be written / being written | Large and growing = storage can't keep up |
| `AnonPages` | Anonymous memory mapped into processes | Application memory growth (leaks) |
| `Shmem` | tmpfs and shared memory | `/dev/shm` or tmpfs filling RAM |
| `Slab` = `SReclaimable` + `SUnreclaim` | Kernel object caches (dentries, inodes, network buffers) | Large `SUnreclaim` growing = possible kernel leak |
| `Committed_AS` / `CommitLimit` | Memory promised to processes / limit used in strict overcommit mode | `Committed_AS` far above RAM+swap = risk if all of it is used |
| `HugePages_*`, `AnonHugePages` | Pre-reserved huge pages / transparent huge pages | Reserved hugepages are unavailable to anything else |

```bash
free -h ; cat /proc/meminfo ; vmstat 1 5        # si/so = swap in/out per second
slabtop -o | head -15                           # biggest kernel slab caches (procps-ng)
```

## 5. Per-Process Memory: VSZ, RSS, PSS, USS

| Metric | Meaning | Problem |
|---|---|---|
| **VSZ / VIRT** | All mapped address space | Includes reserved but unused memory: nearly meaningless for capacity |
| **RSS / RES** | Pages of this process currently in RAM | **Shared pages counted fully in every process**: summing RSS over-counts |
| **PSS** | RSS with each shared page divided among its sharers | Sums correctly across processes |
| **USS** | Pages **only** this process uses | What you'd free by killing it |

```bash
ps -eo pid,rss,vsz,cmd --sort=-rss | head
cat /proc/PID/smaps_rollup         # Rss, Pss, Pss_Anon, Pss_File, Pss_Shmem, Swap … (one line each)
grep VmSwap /proc/PID/status       # how much of this process is in swap
```

Verified example (`smaps_rollup` of a tiny process): `Rss: 2156 kB` but `Pss: 782 kB`; most of its RSS was shared library pages.

## 6. Reclaim: What Happens When RAM Runs Low

The kernel keeps free memory above **watermarks** (derived from `vm.min_free_kbytes`):

1. **kswapd** (background): when free memory drops below the *low* watermark, it reclaims pages until the *high* watermark is restored. It drops clean page cache, writes back dirty pages, and swaps anonymous pages, preferring **inactive** pages.
2. **Direct reclaim** (foreground): if allocation outpaces kswapd, the allocating process reclaims memory itself. It stalls, so latency rises everywhere. This is "memory pressure".
3. **OOM killer**: if reclaim can't free enough, the kernel kills a process (§8).

`vm.swappiness` (0–200 on RHEL 10's kernel; tuned profiles set it) biases reclaim between anonymous pages (→ swap) and file pages (→ drop cache). It is **not** "the percentage of RAM at which swapping starts". See [swap](../storage-and-filesystems/swap.md#6-swappiness).

**Measure pressure, not just usage.** Pressure Stall Information (PSI) reports the share of time tasks were stalled waiting for memory:

```bash
cat /proc/pressure/memory
# some avg10=0.00 avg60=0.00 avg300=0.00 total=0   ← "some": at least one task stalled
# full avg10=0.00 avg60=0.00 avg300=0.00 total=0   ← "full": all non-idle tasks stalled (severe)
```

Non-zero and rising `some`/`full` values are a better early warning than "free memory is low". PSI is also available per cgroup (`memory.pressure`).

## 7. Overcommit

Because allocation is lazy, the kernel may promise more memory than exists:

| `vm.overcommit_memory` | Policy |
|---|---|
| `0` (kernel default, RHEL default) | **Heuristic**: refuse only obviously impossible requests |
| `1` | Always allow (some database/caching guidance uses this) |
| `2` | **Strict**: commit limit = swap + `overcommit_ratio`% of RAM (`CommitLimit` in meminfo); `malloc` fails with `ENOMEM` instead of OOM later |

With `0`/`1`, a program can allocate successfully and be killed later, when it **touches** the memory and none is left. With `2`, failures happen at allocation time, which well-written programs can handle, but many programs that reserve large address spaces (JVMs, some runtimes) fail to start.

## 8. The OOM Killer

When reclaim fails, the kernel picks a victim by **badness**: roughly its memory footprint (RSS + swap + page tables) as a share of available memory, adjusted by `oom_score_adj`.

| File | Range | Meaning |
|---|---|---|
| `/proc/PID/oom_score` | Read-only | Current ranking; **higher = killed first**. On 6.12 kernels a tiny process shows about 666 (verified); compare values relative to each other |
| `/proc/PID/oom_score_adj` | −1000 … 1000 | Bias. **−1000 = never kill**; +1000 = kill first (verified: setting 500 raised a tiny process's score from 666 to 1000) |
| systemd `OOMScoreAdjust=` | same | Persistent per service |

The kill is logged in the kernel log:

```bash
journalctl -k | grep -iE 'out of memory|oom-kill|Killed process'
#   Out of memory: Killed process 4242 (java) total-vm:…kB, anon-rss:…kB, file-rss:…kB, shmem-rss:…kB, UID:1001 pgtables:…kB oom_score_adj:0
```

The victim gets **SIGKILL** (exit status 137); systemd records `Result: oom-kill`. `systemd-oomd` (when enabled) can act earlier, based on PSI, and kill whole cgroups **[Advanced]**.

### 8.1 Global OOM vs cgroup OOM

| | Global OOM | cgroup (container/service) OOM |
|---|---|---|
| Trigger | Whole machine out of reclaimable memory | The cgroup reached `memory.max` |
| Host free memory | Exhausted | **Can be plentiful** |
| Victim chosen from | All processes | Processes in that cgroup only |
| Evidence | `journalctl -k` | `memory.events` (`oom_kill` counter), kernel log ("Memory cgroup out of memory"), container status `OOMKilled` |

Verified with a 64 MiB container limit: allocating 200 MiB → `Killed`, exit status 137, and `/sys/fs/cgroup/memory.events` shows `oom_kill 1`. Details in [namespaces & cgroups](../containers-and-virtualization/namespaces-and-cgroups.md).

## 9. Huge Pages & NUMA (Awareness) **[Advanced]**

- **Huge pages** (2 MiB on x86-64) reduce page-table and TLB overhead for large-memory apps. **Explicit** hugepages (`vm.nr_hugepages`) are reserved up front. **Transparent Huge Pages** (THP, `/sys/kernel/mm/transparent_hugepage/enabled`) are automatic; some databases recommend `madvise` or `never` because THP compaction can cause latency spikes. tuned profiles manage THP (`[vm] transparent_hugepages=`).
- **NUMA:** on multi-socket servers, memory attached to the local CPU is faster. `numactl --hardware`, `numastat -p PID`. A NUMA node can run out of memory while the machine still has free memory, causing reclaim or swapping on one node.

## 10. Labs

1. **Page cache in action.** `free -h` → `dd if=/dev/zero of=/var/tmp/big bs=1M count=1024 ; sync` → `free -h` (buff/cache up 1 GiB, `available` roughly unchanged) → `rm /var/tmp/big` (cache freed). Lab only: `sync; echo 3 > /proc/sys/vm/drop_caches` empties clean caches; never use it as a production "fix".
2. **Lazy allocation.** Run the §2 Python demo (mmap 1 GiB, touch 200 MiB), watching `ps -o rss,vsz,min_flt` in another terminal.
3. **RSS vs PSS.** Compare `ps -o rss` with `Pss` in `/proc/PID/smaps_rollup` for several `httpd` workers: why does the sum of RSS exceed what `free` reports?
4. **cgroup OOM without a container.** `systemd-run --scope -p MemoryMax=64M python3 -c 'b=bytearray(200*1024*1024)'` → `Killed`; then `journalctl -k | tail` shows "Memory cgroup out of memory".
5. **OOM priority.** Start two `sleep` processes, set one's `oom_score_adj` to 1000 and the other's to −1000; compare `oom_score`.

## 11. Troubleshooting

| Symptom | Interpretation | Next step |
|---|---|---|
| `free` near 0, `available` high | Page cache doing its job | Nothing to fix |
| Swap used, `si`/`so` ≈ 0 | Cold pages parked in swap | Usually harmless |
| `si`/`so` sustained, high major faults, PSI memory rising | **Thrashing**: working set > RAM | Find top RSS/PSS (`ps --sort=-rss`, `smaps_rollup`); add RAM or limit workloads |
| Process killed, exit 137, `Killed` | OOM kill (global or cgroup) | `journalctl -k \| grep -i oom`; cgroup `memory.events`; raise the limit or fix the leak |
| Container OOMKilled, host has free RAM | cgroup `memory.max` reached | Container/pod memory limit vs real usage (`memory.current`, `memory.stat`) |
| `AnonPages`/RSS grows without bound | Application memory leak | Track RSS over time; restart as mitigation; profile the app |
| `Slab`/`SUnreclaim` keeps growing | Kernel object leak or huge dentry cache | `slabtop`; check for a known kernel bug; vendor support |
| `Dirty` stays large, writes stall | Storage slower than writers | [Storage I/O path](../storage-and-filesystems/storage-io-path.md): writeback tunables, device latency |
| `fork: Cannot allocate memory` with free RAM | Strict overcommit (`overcommit_memory=2`), or PID/thread limits | `sysctl vm.overcommit_memory`; `CommitLimit` vs `Committed_AS`; `pids.max` |
| `/dev/shm` full | tmpfs consumes RAM | `df -h /dev/shm`; find the files |

## 12. Interview Questions

| Question | Answer |
|---|---|
| Why is "free" memory low on a healthy server? | Linux uses unused RAM for the page cache; it's reclaimable, so `MemAvailable` is the real headroom. |
| VSZ vs RSS vs PSS? | VSZ = address space; RSS = resident pages (shared counted fully); PSS = shared pages divided among sharers (sums correctly). |
| What's a page fault? Minor vs major? | A trap when a page isn't mapped as needed; minor = resolved in memory, major = needs disk I/O. |
| What does swappiness control? | The balance between reclaiming anonymous memory (swap) and file pages (cache), not a threshold. |
| How does the OOM killer choose? | Highest badness (memory footprint adjusted by `oom_score_adj`); see `/proc/PID/oom_score`. |
| How do you protect a critical daemon from the OOM killer? | `OOMScoreAdjust=-1000` (or a negative value) in its unit; better, size limits so OOM never happens. |
| Container killed with 137, host has 30 GB free. Why? | Its cgroup hit `memory.max`; the cgroup OOM killer acted. Check `memory.events` and the kernel log. |
| What's overcommit? | Promising more virtual memory than RAM+swap; with the heuristic default, failures appear later as OOM kills instead of `malloc` errors. |
| Is swap usage bad? | Not by itself; sustained swap-in/out activity is. |
| How do you know memory pressure is hurting performance? | PSI (`/proc/pressure/memory`), major faults, direct-reclaim stalls, `si`/`so`. |

## 13. Quick Revision

```
virtual memory · 4 KiB pages · page tables · lazy allocation · minor vs major faults (ps -o min_flt,maj_flt)
anon (→ swap) vs file-backed/page cache (→ drop clean, write back dirty) · tmpfs = Shmem
MemAvailable is the headroom · Dirty/Writeback · Slab (SUnreclaim) · Committed_AS vs CommitLimit
VSZ ≫ RSS > PSS ≥ USS · /proc/PID/smaps_rollup · VmSwap
kswapd (background) → direct reclaim (stalls) → OOM killer · PSI /proc/pressure/memory
overcommit_memory 0 heuristic (default) | 1 always | 2 strict · oom_score / oom_score_adj (−1000 never) · OOMScoreAdjust=
global OOM vs cgroup OOM (memory.max, memory.events oom_kill) · exit 137 · journalctl -k | grep -i oom
```

## 14. Cross-References

- [Processes & system calls (fork COW, exit codes)](processes-and-system-calls.md) · [top & monitoring](top-and-process-monitoring.md) · [Resource monitoring (vmstat, sar -B)](system-resource-monitoring.md)
- [Swap & swappiness](../storage-and-filesystems/swap.md) · [Storage I/O path (dirty pages, writeback)](../storage-and-filesystems/storage-io-path.md)
- [Namespaces & cgroups (memory.max, memory.events)](../containers-and-virtualization/namespaces-and-cgroups.md) · [tuned (THP, swappiness)](../containers-and-virtualization/tuned-profiles.md)
- [systemd unit files (MemoryMax=, OOMScoreAdjust=)](../boot-systemd-and-kernel/systemd-unit-files.md) · [Performance & observability (PSI)](../advanced-rhel-and-career-notes/performance-and-observability.md)
