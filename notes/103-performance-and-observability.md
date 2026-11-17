# 103 · Performance Analysis and Observability

> **You need first:** [102 · A troubleshooting method](102-troubleshooting-method.md) (and topics 034–036 monitoring, 092–095 internals)
> **Next:** [104 · cloud-init](104-cloud-init.md)

---

## What it is

The methods and tools to answer "**why is it slow?**" and "**what happened?**":

| Term | Meaning |
|---|---|
| **Observability** | How well you can understand a system's internal state from its outputs: **metrics** (numbers over time), **logs** (events), **traces** (the path of one request) |
| **USE method** | For every **resource**: Utilisation (how busy), Saturation (how much work is queued), Errors |
| **RED method** | For every **service**: Rate (requests/s), Errors, Duration (latency) |
| **Golden signals** | Latency, traffic, errors, saturation: Google SRE's version of RED + saturation |
| **PSI** | Pressure Stall Information: the share of time tasks were stalled waiting for CPU, memory or I/O |
| **Profiling** | Sampling where CPU time is spent (`perf`) |
| **eBPF** (extended Berkeley Packet Filter) | Small, verified programs that run safely inside the kernel to trace events with low overhead |
| **Core dump** / **vmcore** | A memory image of a crashed process / crashed kernel, saved for analysis |

## Why it exists

"Tools without a method produce screenshots, not answers." A slow server can be:
- CPU-bound;
- memory-starved;
- waiting on disk;
- losing packets;
- blocked on a lock;
- throttled by a cgroup.

Each needs a different fix. A method tells you which resource to look at first; the right tool then tells you who is using it and where the time goes. Historical metrics answer "what happened at 03:00?" after the fact.

## Analogy

A **hospital triage nurse** doesn't run every test on every patient. They check vital signs in a fixed order (pulse, breathing, blood pressure, temperature) to find the system that's failing, then call the right specialist. The USE checklist is your vital signs; `perf` and eBPF tools are the specialists' scanners.

## How it works inside

- **Utilisation vs saturation:** a resource at 100% utilisation isn't necessarily a problem; **saturation** (work queueing: run queue, I/O queue, stalled tasks) is what causes latency.
- **Load average is a poor CPU metric on Linux**: it counts tasks in uninterruptible I/O sleep (D state) as well as runnable ones (topic 034). Use the run queue (`vmstat` `r`), **PSI**, or `runqlat`.
- **PSI** measures **lost time**, not busyness:
  - `some` = at least one task was stalled;
  - `full` = all non-idle tasks were stalled at once (no useful work).
  It exists system-wide and **per cgroup**, and `systemd-oomd` and Kubernetes-adjacent tooling use it.
- **`perf`** uses CPU performance counters and timer interrupts to **sample** what code is running (for example, 99 times a second on every CPU), building statistics of the hottest functions and call stacks, in the kernel and in applications.
- **eBPF** attaches programs to kernel **tracepoints**, **kprobes** (any kernel function) or **uprobes** (application functions). The kernel **verifies** each program is safe, then runs it in-kernel; only summaries go to user space. That's why eBPF tools are safe on production, unlike `strace`, which stops the process on every syscall (topic 092). Modern observability and networking products (Cilium, Pixie, Falco, Parca) are built on eBPF.
- **Crash capture:**
  - **systemd-coredump** stores application core dumps.
  - **kdump** reserves memory for a second "capture" kernel (`crashkernel=` boot argument, topic 054). On a kernel panic it boots and saves a **vmcore** to `/var/crash/`.

## Commands

### The first 60 seconds on a slow host

```bash
uptime                                   # load trend (1 vs 15 min); compare with nproc
journalctl -k -p warning -b | tail -30   # OOM kills, I/O errors, hung tasks, NIC resets, conntrack full
vmstat 1 5                               # r (run queue) vs CPUs, b (blocked), si/so (swap), wa, st
mpstat -P ALL 1 3                        # one hot CPU? high %sys / %irq / %soft / %steal?
pidstat 1 3                              # which processes use CPU
iostat -xz 1 3                           # await, aqu-sz, %util per device (incl. dm-N)
free -h ; cat /proc/pressure/{cpu,memory,io}
sar -n DEV 1 3 ; sar -n TCP,ETCP 1 3     # NIC throughput; TCP connection rate, retransmits
ss -s ; ss -tan state close-wait | wc -l
top -b -n 1 | head -20                   # a snapshot for the incident record
```
- `vmstat`, `iostat` and `mpstat` print **since boot** first; read the later samples.

```
procs -----------memory---------- ---swap-- -----io---- -system-- -------cpu-------
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
 9  0      0 312000   2100 5400000   0    0     5    40 4100 9800 92  6  2  0  0
```
- On a 4-CPU box, `r 9` means 9 runnable tasks for 4 CPUs: **CPU saturation**, with 92% user time. Next: `pidstat` (who?) and `perf top` (where in the code?).

### PSI

On RHEL, PSI is compiled in but **off by default**. Turn it on once per machine:
```bash
ls /proc/pressure 2>/dev/null || echo "PSI is off"
sudo grubby --update-kernel=ALL --args=psi=1 ; sudo reboot
```

```bash
cat /proc/pressure/cpu
cat /sys/fs/cgroup/system.slice/httpd.service/cpu.pressure
```
```
some avg10=14.12 avg60=2.55 avg300=0.53 total=2402214
```
- Tasks were stalled waiting for CPU 14% of the last 10 seconds. Alert on the `total` deltas or `avg60`, not on load average.

### CPU profiling with perf

```bash
sudo dnf install -y perf
sudo perf top                                   # live hottest functions, kernel + user
sudo perf record -F 99 -a -g -- sleep 30        # sample all CPUs at 99 Hz with call stacks → perf.data
sudo perf report --stdio | head -40
sudo perf stat -p PID -- sleep 10               # cycles, instructions, IPC, context switches
```
```
Samples: 12K of event 'cpu-clock:ppp', Event count (approx.): 3012000000
Overhead  Command  Shared Object         Symbol
  38.21%  python3  libpython3.12.so.1.0  [.] _PyEval_EvalFrameDefault
  11.04%  python3  libpython3.12.so.1.0  [.] long_mul
   6.80%  swapper  [kernel.kallsyms]   [k] native_safe_halt
```
- `[.]` = user-space function, `[k]` = kernel function. High `%sys` in `vmstat` → look for `[k]` hot spots (locks, page faults, network stack).
- Missing names → install debuginfo (`sudo dnf debuginfo-install PKG`). **Flame graphs** visualise `perf record -g` output.

### eBPF: BCC tools and bpftrace

```bash
sudo dnf install -y bcc-tools bpftrace       # Ubuntu: bpfcc-tools (tools named *-bpfcc) and bpftrace
# the tools live in /usr/share/bcc/tools; sudo resets PATH (secure_path), so use the full path
sudo /usr/share/bcc/tools/execsnoop          # takes 10–20 s to compile and attach before it prints
```
```
PCOMM            PID     PPID    RET ARGS
sh               8812    8810      0 /bin/sh -c /usr/local/bin/healthcheck.sh
curl             8813    8812      0 /usr/bin/curl -fsS http://127.0.0.1:8080/health
```
- It catches short-lived processes that `top` never shows: fork storms, surprise cron jobs, health checks.

| Tool | Answers |
|---|---|
| `execsnoop` | Which short-lived processes are being spawned |
| `opensnoop -p PID` | Which files it opens (and fails to open) |
| `biolatency` / `biosnoop` | Disk I/O latency histogram / per-I/O detail |
| `xfsslower 10` / `ext4slower 10` | Filesystem operations slower than 10 ms |
| `cachestat` | Page cache hit ratio |
| `runqlat` | How long tasks wait for a CPU (CPU saturation) |
| `offcputime -p PID` | Where a thread is **blocked** (locks, I/O) |
| `tcpconnect` / `tcpaccept` / `tcplife` | Connections and their lifetimes |
| `tcpretrans` | Retransmissions (packet loss), with addresses |
| `oomkill` | OOM kill events |

```bash
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_openat { printf("%s %s\n", comm, str(args->filename)); }'
sudo bpftrace -e 'tracepoint:raw_syscalls:sys_enter { @[comm] = count(); }'     # syscalls per process (Ctrl+C)
```

### History: sar and PCP

```bash
sudo systemctl enable --now sysstat
sar -u -f /var/log/sa/sa$(date -d yesterday +%d) -s 02:50:00 -e 03:20:00    # CPU yesterday 02:50–03:20
sudo dnf install -y pcp pcp-system-tools ; sudo systemctl enable --now pmcd pmlogger
pcp dstat --time --cpu --mem --disk 1 5
```
- In real fleets, metrics usually go to **Prometheus** (node_exporter) and **Grafana**, logs to Loki/Elasticsearch, and traces to OpenTelemetry/Jaeger. PCP can export to these.

### Crashes

```bash
sleep 100 & kill -SEGV $!              # lab: make a process crash
coredumpctl list | tail -2
coredumpctl info $! | head -15
```
```
TIME                           PID  UID  GID SIG     COREFILE EXE        SIZE
Tue 2026-11-17 14:20:11 UTC   9123 1000 1000 SIGSEGV present  /usr/bin/sleep 18.4K
```
```bash
sudo dnf install -y kdump-utils                 # RHEL 10: kdumpctl moved here from kexec-tools
sudo kdumpctl status ; grep -o 'crashkernel=[^ ]*' /proc/cmdline
sudo kdumpctl get-default-crashkernel          # e.g. 2G-64G:256M,64G-:512M → nothing reserved below 2 GiB RAM
# ONLY on a lab VM — crashes the kernel immediately:  echo c | sudo tee /proc/sysrq-trigger
```
After a panic, the vmcore lands in `/var/crash/`. Analysing it with the `crash` tool needs `kernel-debuginfo`. Most admins collect it plus a `sos report` and open a support case.

### Choosing the right tool

| Question | First tool | Deeper tool |
|---|---|---|
| Which resource is saturated? | `vmstat`, PSI, `iostat -x`, `sar -n` | `mpstat`, `pidstat`, cgroup `*.stat` |
| Which process burns CPU? | `top` / `pidstat` | `perf top -p`, `perf record -g` |
| Slow but not using CPU? | `ps -o stat,wchan`, `/proc/PID/stack` | `offcputime`, brief `strace -T -p` |
| Which files/syscalls? | `strace -f -e trace=%file` | `opensnoop`, `perf trace` |
| Is the disk slow? | `iostat -xz` (await) | `biolatency`, `xfsslower` |
| Network loss? | `ss -ti` (retrans), `nstat` | `tcpretrans`, `tcpdump` |
| Short-lived process storm? | (`top` misses them) | `execsnoop` |
| What happened at 03:00? | `sar -f`, `journalctl --since/--until` | PCP archives, Prometheus |
| Did something crash? | `journalctl -k`, `coredumpctl list` | kdump vmcore + `crash` |

### Try it
1. Run the 60-second checklist on an idle VM and save it as a baseline. Then run `stress-ng --cpu 2 --io 2 --vm 1 --vm-bytes 60% --timeout 60s` and repeat. Which line revealed each kind of stress?
2. Watch `/proc/pressure/memory` while `stress-ng --vm 1 --vm-bytes 90%` runs.
3. `perf record -F 99 -g -- python3 -c 'sum(i*i for i in range(10**8))'`, then `perf report`.
4. Run `execsnoop` while `dnf makecache` runs; count the processes spawned.
5. Make a core dump and read it with `coredumpctl info`.

## Where you'll use it

- **Kubernetes:**
  - `kubectl top` and metrics-server read cgroup stats.
  - Prometheus scrapes node_exporter and cAdvisor (cgroup metrics, including `container_cpu_cfs_throttled_*`).
  - eBPF-based tools (Cilium/Hubble, Pixie, Parca, Falco) observe pods without changing them.
- **SLOs** (Service Level Objectives) are built on RED/golden-signal metrics: alert on symptoms users feel (latency, errors), and use USE metrics to diagnose.
- **Capacity planning and post-incident analysis** from historical metrics.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `cat: /proc/pressure/memory: No such file or directory` (and no `*.pressure` files in cgroups) | RHEL kernels ship with PSI disabled (`CONFIG_PSI_DEFAULT_DISABLED=y`) | Add the kernel argument `psi=1` (`grubby --update-kernel=ALL --args=psi=1`) and reboot |
| `perf` shows hex addresses instead of names | Missing debug symbols, or no frame pointers | `dnf debuginfo-install PKG`; `--call-graph dwarf` |
| BCC tools fail to compile or attach | Kernel headers missing, or lockdown/Secure Boot restrictions | Install `kernel-devel` for the running kernel; check `dmesg` for lockdown messages |
| `sar` says "No such file" | sysstat collection not enabled | `systemctl enable --now sysstat` |
| `sudo: kdumpctl: command not found` | On RHEL 10 `kdumpctl` is in the **kdump-utils** package | `dnf install kdump-utils` |
| No core dumps | `LimitCORE=0`/`ulimit -c 0`, or storage limits | `coredumpctl`; limits in `/usr/lib/systemd/coredump.conf` (override with a drop-in in `/etc/systemd/coredump.conf.d/`) |
| No vmcore after a panic | kdump not running, or no `crashkernel=` reservation | `kdumpctl status`; add `crashkernel=` (topic 054); test on a lab VM |
| "Everything looks fine" but users see latency | Looking at averages, or the wrong layer | Look at percentiles (p99), PSI, cgroup throttling, the network path |

## Quick recap

- **Method first:** USE for resources, RED/golden signals for services, and always "what changed?".
- 60 seconds: `uptime`, kernel log, `vmstat`, `mpstat`, `pidstat`, `iostat -xz`, `free`/PSI, `sar -n`, `ss -s`.
- **PSI** (`/proc/pressure/*`, per cgroup) measures stall time: a better saturation signal than load.
- `perf` profiles CPU; **eBPF** (bcc-tools, bpftrace) traces safely in production; `sar`/PCP/Prometheus give history.
- Crashes: `coredumpctl` for apps, **kdump** for the kernel.

**Interview questions**

1. *A server is slow. What do you check first?* Use a method: load vs CPU count, the kernel log, `vmstat` (run queue, blocked tasks, swap, iowait, steal), per-CPU and per-process CPU, disk await, memory and PSI, network errors. Then drill into whichever resource is saturated, and ask what changed.
2. *Why is load average a poor CPU metric on Linux?* It includes tasks in uninterruptible I/O sleep as well as runnable tasks, so I/O problems inflate it. The run-queue length, PSI CPU or `runqlat` measure CPU saturation directly.
3. *strace vs eBPF tools in production?* `strace` uses ptrace and stops the process on every syscall (high overhead). eBPF programs run verified inside the kernel and only send summaries out, so they're safe on busy production systems.
