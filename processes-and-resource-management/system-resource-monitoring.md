# System Resource Monitoring: free, vmstat, iostat, mpstat, sar

> **Sessions:** S56 · Supports *Identify CPU/memory intensive processes* **[RHCSA Core]** · performance analysis **[Production Practice]**
> **Related:** [top & process monitoring](top-and-process-monitoring.md) · [Processes & signals](processes-and-signals.md) · [Priority & nice](process-priority-and-nice.md) · [Swap](../storage-and-filesystems/swap.md) · [System logging](../logs-scheduling-and-packages/system-logging.md) · [Performance & observability](../advanced-rhel-and-career-notes/performance-and-observability.md) · [Memory management](memory-management.md) · [Storage I/O path](../storage-and-filesystems/storage-io-path.md)

## 1. Overview

Resource monitoring answers: **which resource is the bottleneck (CPU, memory, disk, network), and which process causes it?** A simple method is **USE**: for each resource, check **U**tilization, **S**aturation (queueing/waiting) and **E**rrors.

| Resource | Utilization | Saturation | Tools |
|---|---|---|---|
| CPU | `us`+`sy` %, per-CPU % | Run queue `r` > CPU count, load average | top, vmstat, mpstat, sar -u, sar -q |
| Memory | used vs **available** | Swapping (`si`/`so`), OOM kills | free, vmstat, sar -r, sar -W |
| Disk | `%util`, throughput | `aqu-sz`, `await`, `wa`, D-state processes | iostat -xz, sar -d, vmstat `b`/`wa` |
| Network | throughput | drops, retransmits | `ip -s link`, `ss -s`, sar -n DEV |

````bash
dnf install -y sysstat          # iostat, mpstat, pidstat, sar
systemctl enable --now sysstat  # start history collection (/var/log/sa/)
````

## 2. Memory: `free`

````bash
free -h        # human-readable;  -m MiB;  -s 2 repeat every 2 s
````

| Column | Meaning |
|---|---|
| `total` | Installed RAM visible to the kernel |
| `used` | In use by processes and the kernel |
| `free` | Completely unused (usually small: normal) |
| `buff/cache` | Page cache and buffers, reclaimable |
| **`available`** | Estimate of memory available to new applications without swapping: **the number to watch** |

## 3. `vmstat`

````bash
vmstat 2 5          # every 2 s, 5 samples (the FIRST line is an average since boot; ignore it)
vmstat -s           # counters summary
````

| Group | Column | Meaning / red flag |
|---|---|---|
| procs | `r` | Runnable processes; persistently > CPU count = CPU saturation |
| procs | `b` | Blocked in uninterruptible sleep (I/O); > 0 sustained = I/O problem |
| memory | `swpd`, `free`, `buff`, `cache` | KiB in swap / free / buffers / page cache |
| swap | `si`, `so` | KiB/s swapped in/out; sustained non-zero = memory pressure |
| io | `bi`, `bo` | Blocks read/written per second |
| system | `in`, `cs` | Interrupts, context switches per second |
| cpu | `us` `sy` `id` `wa` `st` `gu` | User, system, idle, I/O wait, steal (hypervisor), guest |

## 4. Disk: `iostat`

````bash
iostat              # CPU + per-device summary since boot
iostat -xz 2 5      # extended, skip idle devices, 2 s interval (read samples after the first)
iostat -dxh nvme0n1 2   # one device, human-readable
````

| Column (`-x`) | Meaning |
|---|---|
| `r/s`, `w/s` | Read/write requests per second (IOPS) |
| `rkB/s`, `wkB/s` | Throughput |
| `r_await`, `w_await` | Average ms per request (queue + service). Rising values = latency |
| `aqu-sz` | Average queue size (saturation) |
| `%util` | Time the device was busy. Near 100% matters for single-queue HDDs; NVMe/SSD can serve many requests in parallel, so check `await` too |

Devices: `dm-N` = device-mapper (LVM/LUKS; map with `lsblk` or `dmsetup ls`), `nvme0n1`/`vda`/`sda` = physical/virtual disks, `sr0` = optical.

## 5. CPU: `mpstat` & `pidstat`

````bash
mpstat              # all CPUs since boot
mpstat -P ALL 2 5   # per CPU, every 2 s: spot one saturated core (single-threaded hog)
pidstat 2 5         # per-process CPU every 2 s
pidstat -r 2 5      # per-process memory (faults, RSS)
pidstat -d 2 5      # per-process disk I/O
````

`%usr %nice %sys %iowait %irq %soft %steal %guest %gnice %idle`. High `%steal` = the hypervisor is giving this VM's CPU time to others; it doesn't indicate whether the system is virtualized.

## 6. History: `sar`

Collected by the sysstat timers into `/var/log/sa/saDD` (DD = day of month).

````bash
sar -u 5 5                 # live CPU, 5 samples
sar -u                     # today's history (10-minute intervals)
sar -r                     # memory      | sar -S swap  | sar -W paging/swapping
sar -q                     # run queue and load averages
sar -b ; sar -d -p         # I/O totals ; per-device (pretty names)
sar -n DEV                 # network per interface
sar -f /var/log/sa/sa15 -s 09:00:00 -e 11:00:00 -u   # yesterday-style investigation of a past window
````

`sar` answers the most common production question: "What happened at 03:00 last night?"

## 7. Other Quick Tools

````bash
uptime                                   # load averages; compare with nproc
watch -n 2 -d free -h                    # repeat every 2 s, highlight changes
watch -d 'ps aux --sort=-%mem | head -10'
ps -eo pid,user,%cpu,%mem,cmd --sort=-%cpu | head
ip -s link ; ss -s                       # interface counters; socket summary
systemd-cgtop                            # resource use per service (cgroup)
````

## 8. Lab Scenario

````bash
vmstat 2 & iostat -xz 2 &                            # baseline in another terminal
dnf install -y stress-ng                             # (check availability with dnf info)
stress-ng --cpu 2 --timeout 60s                      # CPU: watch r and us rise
stress-ng --vm 1 --vm-bytes 75% --timeout 60s        # memory: watch available drop, si/so
stress-ng --hdd 1 --timeout 60s                      # disk: watch wa, b, await, %util
top  → P / M → k (kill the hog) → confirm recovery
````

## 9. Reading the Signals

| Observation | Bottleneck | Next step |
|---|---|---|
| `r` > CPUs, `us`/`sy` high, `id` ~0 | CPU | Find the top processes (`top P`, `pidstat`); renice, optimize, or add CPUs |
| `available` low, `si`/`so` > 0 | Memory | Find large RSS (`top M`, `pidstat -r`); fix leaks, add RAM |
| `wa` high, `b` > 0, `await` high | Disk I/O | `iostat -x` for the device, `pidstat -d` for the process |
| `st` high | Hypervisor contention | Escalate to the virtualization team |
| One CPU at 100% in `mpstat -P ALL` | Single-threaded process | Identify it; it can't use more cores |

## 10. RHCSA Exam Focus **[RHCSA Core]**

- The objective is practical: find the process using the most CPU or memory (`top` P/M, `ps --sort`) and act on it (kill, renice). The sysstat tools are for diagnosis; they're not required, but they make the reasoning faster.

## 11. Production Practices **[Production Practice]**

- Enable sysstat (or a metrics agent) **before** incidents; history is what you'll need.
- Baseline normal values for each server so anomalies are obvious.
- Watch saturation metrics (run queue, `await`, swapping), not just utilization.
- Correlate with logs (`journalctl --since`) and recent changes.

## 12. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `iostat: command not found` | sysstat missing | `dnf install sysstat` |
| `sar`: "Cannot open /var/log/sa/saDD" | Collection not enabled | `systemctl enable --now sysstat`; wait for samples |
| First vmstat/iostat line looks wrong | Since-boot averages | Use intervals; read later samples |
| `%util` 100% but fast NVMe | Parallel device | Judge by `await`/`aqu-sz` |

## 13. Interview Questions

| Question | Answer |
|---|---|
| A server is slow. Where do you start? | `uptime`/load vs CPUs, `vmstat 1` (r, b, si/so, wa, st), `iostat -xz 1`, then top processes and logs. |
| Why is "free" memory low on a healthy system? | Linux uses spare RAM as page cache; look at `available`. |
| What does high `wa` mean? | CPUs idle while waiting for I/O; investigate storage. |
| How do you see yesterday's CPU usage? | `sar -u -f /var/log/sa/saDD`. |
| What's `%steal`? | CPU time the hypervisor gave to other VMs. |

## 14. Quick Revision

````bash
free -h (available!) · uptime vs nproc · vmstat 2 5 (r b si so wa st; skip line 1)
iostat -xz 2 (await aqu-sz %util) · mpstat -P ALL 2 · pidstat [-r|-d] 2 · sar -u|-r|-q|-d|-n DEV [-f saDD -s -e]
watch -n 2 -d CMD · ps --sort=-%cpu · systemd-cgtop · dnf install sysstat ; systemctl enable --now sysstat
USE: Utilization · Saturation · Errors
````

## 15. Cross-References

- [top & process monitoring](top-and-process-monitoring.md)
- [Processes & signals](processes-and-signals.md)
- [Priority & nice](process-priority-and-nice.md)
- [Swap](../storage-and-filesystems/swap.md)
- [System logging](../logs-scheduling-and-packages/system-logging.md)
