# Performance Analysis & Observability

> **Track:** **[Production Practice]** · **[Interview Knowledge]** · **Verification status:** PSI, `/proc`, sysstat-style and cgroup commands were run on RHEL 10.2 containers. `perf`, `bcc-tools`, `bpftrace`, `pcp` and kdump aren't available in UBI container repositories, so those sections follow RHEL package documentation; confirm names with `dnf info PKG` on a subscribed RHEL 10 host.
> **Prerequisites:** [System resource monitoring](../processes-and-resource-management/system-resource-monitoring.md) · [Processes & system calls](../processes-and-resource-management/processes-and-system-calls.md) · [Memory management](../processes-and-resource-management/memory-management.md) · [Storage I/O path](../storage-and-filesystems/storage-io-path.md) · [TCP/IP for operators](../networking-and-ssh/tcp-ip-for-operators.md)
> **Next:** [Troubleshooting methodology](../troubleshooting-and-interviews/troubleshooting-methodology.md) · [Production scenarios](../troubleshooting-and-interviews/production-scenarios.md)

## 1. Methods Before Tools

Tools without a method produce screenshots, not answers. Use one of these frames:

| Method | For | Ask |
|---|---|---|
| **USE** (Utilization, Saturation, Errors) | Every **resource**: CPU, memory, disk, network, plus software resources (fds, threads, conntrack, connection pools) | How busy? Is work queueing? Are there errors? |
| **RED** (Rate, Errors, Duration) | Every **service** | Requests per second, failed requests, latency distribution |
| **Golden signals** (latency, traffic, errors, saturation) | User-facing services (SRE practice) | Same idea as RED + saturation |
| **Workload characterization** | Any | Who is causing the load? What kind (read/write, size, pattern)? How is it changing? |
| **Drill-down / latency analysis** | Slow requests | Where is the time spent: app, syscalls, disk, network, lock, run queue? |

Always ask **"what changed?"** (deploys, config, package updates via `dnf history`, traffic, kernel). Most incidents start with a change.

## 2. The First 60 Seconds on a Slow Linux Host

Adapted from a widely used SRE checklist. Each command answers a USE question:

```bash
uptime                          # load averages: trend (1 vs 15 min); compare with nproc
journalctl -k -p warning -b | tail -30   # kernel: OOM kills, I/O errors, hung tasks, NIC resets, conntrack full
vmstat 1 5                      # r (run queue) vs CPUs, b (blocked/D), si/so (swap), wa, st
mpstat -P ALL 1 3               # one hot CPU? high %sys/%irq/%soft/%steal? (sysstat)
pidstat 1 3                     # which processes use CPU
iostat -xz 1 3                  # await, aqu-sz, %util per device (incl. dm-N)
free -h ; cat /proc/pressure/{cpu,memory,io}   # headroom and stall time
sar -n DEV 1 3 ; sar -n TCP,ETCP 1 3            # NIC throughput; TCP connection rate, retransmits
ss -s ; ss -tan state close-wait | wc -l        # socket summary; leaks
top -b -n 1 | head -20          # snapshot for the incident record
```

Read the first sample of `vmstat`/`iostat`/`mpstat` as **since boot**; use the later samples.

## 3. Pressure Stall Information (PSI)

PSI measures **lost time** rather than utilization: the share of wall-clock time in which tasks were stalled waiting for a resource.

```bash
cat /proc/pressure/cpu /proc/pressure/memory /proc/pressure/io
# some avg10=14.12 avg60=2.55 avg300=0.53 total=2402214     (verified while a cgroup was CPU-throttled)
cat /sys/fs/cgroup/system.slice/httpd.service/memory.pressure   # per cgroup / per service
```

| Line | Meaning |
|---|---|
| `some` | At least one task was stalled (lost throughput/latency for some work) |
| `full` | All non-idle tasks were stalled at the same time (the system did no useful work) |
| `avg10/60/300` | Percentage over 10 s, 60 s, 5 min |
| `total` | Cumulative stall time in µs (use deltas for alerting) |

PSI is a better saturation signal than load average (which mixes CPU and I/O) and is what `systemd-oomd` uses.

## 4. CPU Profiling with `perf`

`perf` (package `perf`) samples where CPUs spend time, using hardware/software events.

```bash
perf top                                  # live: hottest functions system-wide (kernel + user)
perf top -p PID
perf record -F 99 -a -g -- sleep 30       # sample all CPUs at 99 Hz with call graphs for 30 s → perf.data
perf report --stdio | head -60            # hottest code paths
perf stat -p PID -- sleep 10              # counters: cycles, instructions, IPC, context switches, migrations
perf trace -p PID                         # strace-like syscall view with lower overhead [Advanced]
```

- High `%sys` → `perf top` shows which **kernel** functions (e.g., spinlocks, page faults, network stack).
- Missing function names for applications → install debuginfo (`dnf debuginfo-install PKG`) or build with frame pointers.
- **Flame graphs** visualize `perf record -g` output (stack depth vs time share) **[Advanced]**.

## 5. eBPF Tools: BCC & bpftrace

eBPF runs small, verified programs inside the kernel to trace events with low overhead. It's the modern replacement for many `strace`/`tcpdump` investigations in production.

```bash
dnf install -y bcc-tools          # tools in /usr/share/bcc/tools/ (add it to PATH)
export PATH=$PATH:/usr/share/bcc/tools
```

| Tool | Answers |
|---|---|
| `execsnoop` | Which short-lived processes are being spawned (fork storms, cron surprises) |
| `opensnoop -p PID` | Which files is it opening (and failing to open) |
| `biolatency` / `biosnoop` | Disk I/O latency histogram / per-I/O detail |
| `xfsslower 10` / `ext4slower 10` | Filesystem operations slower than 10 ms |
| `cachestat` | Page cache hit ratio |
| `runqlat` | How long tasks wait in the CPU run queue (CPU saturation) |
| `offcputime -p PID` | Where a thread spends time **blocked** (locks, I/O) |
| `tcpconnect` / `tcpaccept` / `tcplife` | Outgoing / incoming connections and their lifetimes |
| `tcpretrans` | Retransmitted segments (packet loss) with addresses |
| `oomkill` | OOM kill events with details |

**bpftrace** (package `bpftrace`) for one-liners:

```bash
bpftrace -e 'tracepoint:syscalls:sys_enter_openat { printf("%s %s\n", comm, str(args->filename)); }'
bpftrace -e 'tracepoint:raw_syscalls:sys_enter { @[comm] = count(); }'     # syscalls by process (Ctrl+C prints)
bpftrace -l 'tracepoint:block:*'                                            # list available probes
```

eBPF tools need root (or specific capabilities). With Secure Boot/kernel lockdown, some probes may be restricted.

## 6. Historical Metrics: sysstat & PCP

- **sysstat** (`sar`) keeps 10-minute samples in `/var/log/sa/` once `sysstat.service` and its timers are enabled ([resource monitoring](../processes-and-resource-management/system-resource-monitoring.md#6-history-sar)).
- **Performance Co-Pilot (PCP)**, Red Hat's metrics framework: `dnf install pcp pcp-system-tools ; systemctl enable --now pmcd pmlogger` → `pcp dstat`, `pmrep`, `pmstat`, archives under `/var/log/pcp/pmlogger/`; `pmproxy` + the Grafana PCP plugin for dashboards. Also exposes metrics to Prometheus-style collectors **[Advanced]**.
- Fleet monitoring stacks (Prometheus + node_exporter, Grafana, OpenTelemetry) aren't part of RHEL's base repositories; they're common in DevOps/SRE roles and worth separate study ([gaps](../GAPS.md)).

## 7. Crashes: Core Dumps & Kernel Dumps

### 7.1 Application crashes (core dumps)

On RHEL, `kernel.core_pattern` is typically piped to **systemd-coredump**, which stores compressed cores in `/var/lib/systemd/coredump/`:

```bash
sysctl kernel.core_pattern                 # |/usr/lib/systemd/systemd-coredump … (typical)
coredumpctl list                           # crashes: time, PID, signal (SIGSEGV, SIGABRT), executable
coredumpctl info PID                       # stack trace summary, command line, cgroup
coredumpctl debug PID                      # open in gdb (needs gdb + debuginfo)
```

`ulimit -c` / systemd `LimitCORE=` control whether cores are written; `/etc/systemd/coredump.conf` sets storage limits.

### 7.2 Kernel crashes (kdump)

kdump reserves memory for a second "capture" kernel (`crashkernel=` boot argument). When the main kernel panics, the capture kernel boots and saves a **vmcore** to `/var/crash/`.

```bash
kdumpctl status ; systemctl status kdump       # kexec-tools package
cat /proc/cmdline | grep -o 'crashkernel=[^ ]*'
# Test ONLY on a lab VM: crashes the system immediately
#   echo c > /proc/sysrq-trigger
crash /usr/lib/debug/lib/modules/$(uname -r)/vmlinux /var/crash/*/vmcore   # needs kernel-debuginfo [Advanced]
```

For most admins the job is: keep kdump working, collect the vmcore and `sosreport`/`sos report`, and open a support case.

## 8. Choosing the Right Tool

| Question | First tool | Deeper tool |
|---|---|---|
| Which resource is saturated? | `vmstat`, PSI, `iostat -x`, `sar -n` | `mpstat`, `pidstat`, cgroup `*.stat` |
| Which process burns CPU? | `top`/`pidstat` | `perf top -p`, `perf record -g` |
| Why is a process slow but not using CPU? | `ps -o stat,wchan`, `/proc/PID/stack` | `offcputime`, `strace -T -p` (briefly) |
| What files/syscalls does it use? | `strace -f -e trace=%file` | `opensnoop`, `perf trace` |
| Is the disk slow? | `iostat -xz` (`await`) | `biolatency`, `xfsslower` |
| Network loss? | `ss -ti` (retrans), `nstat` | `tcpretrans`, `tcpdump` |
| Short-lived process storm? | `pidstat`/`top` miss them | `execsnoop` |
| What happened at 03:00? | `sar -f /var/log/sa/saDD`, `journalctl --since/--until` | PCP archives |
| Did something crash? | `journalctl -k`, `coredumpctl list` | kdump vmcore + `crash` |

## 9. Labs

1. **60-second checklist.** Run §2 on an idle VM and save the output as a baseline. Then run `stress-ng --cpu 2 --io 2 --vm 1 --vm-bytes 60% --timeout 60s` and repeat. Write down which line of output revealed each stress type.
2. **PSI.** Watch `/proc/pressure/memory` while running `stress-ng --vm 1 --vm-bytes 90%` (lab VM).
3. **perf.** `perf record -F 99 -g -- python3 -c 'sum(i*i for i in range(10**8))'` then `perf report --stdio | head -40`.
4. **execsnoop.** Run `execsnoop` while `dnf makecache` or a cron job runs; count processes spawned.
5. **Core dump.** `sleep 100 & kill -SEGV $!` then `coredumpctl list` / `coredumpctl info`.

## 10. Interview Questions

| Question | Answer |
|---|---|
| Server is slow: what do you check first? | Method first (USE): load vs CPUs, kernel log, vmstat (r, b, si/so, wa, st), per-CPU usage, per-process CPU, iostat await, memory/PSI, network errors; then drill into the saturated resource. |
| Why is load average a poor CPU metric on Linux? | It includes D-state tasks (I/O waits) and counts threads; use run-queue length, PSI cpu, or `runqlat`. |
| What's PSI? | Pressure Stall Information: share of time tasks were stalled on CPU, memory or I/O, system-wide and per cgroup. |
| strace vs eBPF? | strace uses ptrace (stops the process on every syscall: high overhead); eBPF tools run in the kernel with low overhead, suitable for production. |
| How do you find what a process is waiting on? | `/proc/PID/stack`/`wchan` and `offcputime` (blocked time), or `strace -p` briefly to see the blocking syscall. |
| How do you investigate an application crash? | `coredumpctl info`, stack trace with debuginfo, logs around the time, recent changes. |
| What's kdump for? | Capturing a kernel memory dump on panic via a reserved capture kernel, for root-cause analysis. |

## 11. Quick Revision

```
methods: USE (resources) · RED/golden signals (services) · "what changed?" (dnf history, deploys)
60 s: uptime · journalctl -k -p warning · vmstat 1 · mpstat -P ALL · pidstat · iostat -xz · free / PSI · sar -n DEV,TCP · ss -s · top -b -n1
PSI: /proc/pressure/{cpu,memory,io} some/full avg10 · per cgroup *.pressure
perf top|record -g|report|stat|trace · bcc-tools (/usr/share/bcc/tools): execsnoop opensnoop biolatency runqlat offcputime tcpretrans oomkill · bpftrace -e
history: sar (/var/log/sa), PCP (pmlogger, pmrep) · crashes: coredumpctl list|info|debug · kdumpctl, crashkernel=, /var/crash, crash
```

## 12. Cross-References

- [System resource monitoring](../processes-and-resource-management/system-resource-monitoring.md) · [top](../processes-and-resource-management/top-and-process-monitoring.md)
- [Processes & system calls](../processes-and-resource-management/processes-and-system-calls.md) · [Memory management](../processes-and-resource-management/memory-management.md) · [Storage I/O path](../storage-and-filesystems/storage-io-path.md) · [TCP/IP for operators](../networking-and-ssh/tcp-ip-for-operators.md)
- [Boot recovery (kdump context)](../boot-systemd-and-kernel/boot-recovery.md#63-capture-panics-for-analysis-advanced) · [Troubleshooting methodology](../troubleshooting-and-interviews/troubleshooting-methodology.md)
