# 036 · Resource Monitoring: free, vmstat, iostat, mpstat, pidstat, sar

> **You need first:** [035 · Process priority](035-process-priority-nice.md)
> **Next:** [037 · systemd: services and targets](037-systemd-services-and-targets.md)

---

## What it is

A toolkit that answers **"which resource is the bottleneck: CPU, memory, disk or network? And which process is causing it?"**

| Tool | Package | Shows |
|---|---|---|
| `free` | procps-ng | Memory summary |
| `vmstat` | procps-ng | CPU, memory, swap and I/O in one line per interval |
| `iostat` | sysstat | Per-disk load and latency |
| `mpstat` | sysstat | Per-CPU usage |
| `pidstat` | sysstat | Per-process CPU, memory and disk usage over time |
| `sar` | sysstat | **History**: what happened at 03:00 last night |
| `systemd-cgtop` | systemd | Resource use per service |

A simple method to use them is **USE**: for every resource, check **U**tilization (how busy), **S**aturation (how much work is queued/waiting) and **E**rrors.

## Why it exists

`top` (topic 034) shows the present moment. Real investigations also need: **per-disk** detail, **per-CPU** detail, values **over an interval** (not just a snapshot), and **history** for problems that happened while you were asleep. Without these you guess; with them you can prove where the bottleneck is.

## Analogy

The server is a **factory**. `top` is walking the floor once. These tools are the factory's **gauges**: `vmstat` is the main control panel, `iostat` the gauge on each loading dock (disk), `mpstat` one gauge per machine (CPU), `pidstat` a time-card per worker (process), and `sar` the **flight recorder** you replay after an incident.

## How it works inside

- All these tools read kernel **counters** that only ever go up (bytes read, CPU ticks used, …) from `/proc/stat`, `/proc/meminfo`, `/proc/diskstats`, `/proc/<PID>/…`. They take two readings some seconds apart and divide the difference by the time. That's why **the first line** of `vmstat 2` or `iostat 2` is the **average since boot**, so ignore it and read the following lines.
- `sar` history comes from **sysstat timers** (systemd timers, topic 039) that save a sample every 10 minutes into `/var/log/sa/saDD` (DD = day of month). Ubuntu stores it in `/var/log/sysstat/`. History only exists if collection was enabled **before** the incident.

### USE checklist

| Resource | Utilization | Saturation | Errors | Tools |
|---|---|---|---|---|
| CPU | `us`+`sy` % | Run queue `r` > CPU count; load average | — | vmstat, mpstat, sar -u/-q |
| Memory | used vs **available** | Swapping (`si`/`so`); OOM kills | OOM messages | free, vmstat, sar -r/-W |
| Disk | `%util`, throughput | Queue (`aqu-sz`), wait time (`await`), `wa`, `D` processes | I/O errors in `dmesg` | iostat -xz, sar -d |
| Network | Throughput | Drops, retransmits | Errors in `ip -s link` | ip -s link, ss -s, sar -n DEV |

## Commands

```bash
sudo dnf install -y sysstat                 # Ubuntu: sudo apt install sysstat
sudo systemctl enable --now sysstat         # start history collection
```

### free

```bash
free -h
```
```
               total        used        free      shared  buff/cache   available
Mem:           7.5Gi       3.8Gi       302Mi        45Mi       3.4Gi       3.7Gi
Swap:          2.0Gi          0B       2.0Gi
```

| Column | Meaning |
|---|---|
| `total` | RAM the kernel can see |
| `used` | Used by programs and the kernel |
| `free` | Completely unused (small is normal) |
| `shared` | Shared memory (mostly tmpfs) |
| `buff/cache` | Page cache and buffers: reclaimable |
| **`available`** | Estimated memory for new programs without swapping: **watch this** |

### vmstat

```bash
vmstat 2 4
```
```
procs -----------memory---------- ---swap-- -----io---- -system-- -------cpu-------
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st gu
 1  0      0 309120   4212 3551200    0    0    12    40  110  190  3  1 96  0  0  0
 6  0      0 301004   4212 3551300    0    0     0    16 4100 5200 97  3  0  0  0  0
 5  0      0 300880   4212 3551320    0    0     0     8 4050 5100 98  2  0  0  0  0
 6  0      0 300100   4212 3551400    0    0     0    20 4120 5300 97  3  0  0  0  0
```

| Group | Column | Meaning / warning sign |
|---|---|---|
| procs | `r` | Tasks wanting CPU. **Persistently more than the CPU count = CPU saturation** |
| procs | `b` | Tasks blocked on I/O (`D` state). Sustained > 0 = I/O problem |
| memory | `swpd` `free` `buff` `cache` | KiB in swap / free / buffers / page cache |
| swap | `si` `so` | KiB/s swapped in / out. **Sustained non-zero = memory pressure** |
| io | `bi` `bo` | Blocks read / written per second |
| system | `in` `cs` | Interrupts / context switches (CPU switching between tasks) per second |
| cpu | `us sy id wa st gu` | User, system, idle, I/O wait, steal, guest (time running VMs) |

- Line 1 = since boot (ignore). Lines 2–4: `r` is 5–6 on what's presumably a 4-CPU box, and `us` is ~97%. **CPU-bound.**

### iostat

```bash
iostat -xz 2 3
```
```
Device            r/s     w/s     rkB/s     wkB/s  r_await w_await aqu-sz  %util
nvme0n1         12.00  850.00    192.00  98000.00    0.40    4.10   3.50  88.00
dm-0             0.00  850.00      0.00  98000.00    0.00    4.30   3.66  88.00
```
- `-x` extended, `-z` hide idle devices, then interval and count. The real `-x` output has about 20 columns (merges, request sizes, discards, flushes); only the most useful ones are shown here.

| Column | Meaning |
|---|---|
| `r/s`, `w/s` | Read / write requests per second (**IOPS**: I/O operations per second) |
| `rkB/s`, `wkB/s` | Throughput |
| `r_await`, `w_await` | Average milliseconds per request, waiting **plus** being served. **Rising = latency problem** |
| `aqu-sz` | Average queue length: saturation |
| `%util` | Share of time the device was busy. Near 100% is serious for a single spinning disk; **SSDs/NVMe handle many requests in parallel**, so judge them by `await` and `aqu-sz` |

- `dm-0` is a **device-mapper** device (LVM or encryption, topics 049/088) sitting on top of `nvme0n1`. Map them with `lsblk`.

### mpstat and pidstat

```bash
mpstat -P ALL 2 1
```
```
CPU    %usr   %nice    %sys %iowait    %irq   %soft  %steal  %idle
all   26.10    0.00    1.20    0.10    0.00    0.20    0.00  72.40
  0  100.00    0.00    0.00    0.00    0.00    0.00    0.00   0.00
  1    2.00    0.00    3.00    0.50    0.00    0.50    0.00  94.00
...
```
- (Trimmed: the real output also has `%guest` and `%gnice` columns, which matter only on hosts running VMs.)
- The "all" average looks fine (72% idle), but **CPU 0 is pegged at 100%**: a single-threaded process that can't use more cores. Averages hide this.

```bash
pidstat 2 3          # per-process CPU
pidstat -r 2 3       # per-process memory (page faults, RSS)
pidstat -d 2 3       # per-process disk read/write
```
```
UID       PID   kB_rd/s   kB_wr/s kB_ccwr/s iodelay  Command
0        4410      0.00  97800.00      0.00     180  rsync
```
- Finds **which process** is producing the disk writes seen in iostat.

### sar: history

```bash
sar -u                     # today's CPU, 10-minute intervals
sar -r                     # memory
sar -q                     # run queue and load
sar -d -p                  # disks with readable names
sar -n DEV                 # network per interface
sar -f /var/log/sa/sa15 -s 02:00:00 -e 04:00:00 -u    # the 15th of the month, 02:00-04:00
```
- Right after installing sysstat, `sar` says `Cannot open /var/log/sa/saDD: No such file or directory`. The first sample is written by `sysstat-collect.timer` within 10 minutes, so wait and try again. (The package enables `sysstat.service` and its timers itself; the `enable --now` above just makes sure.)
```
02:00:01 AM     CPU     %user     %nice   %system   %iowait    %steal     %idle
02:10:01 AM     all      4.10      0.00      1.20     61.30      0.00     33.40
02:20:01 AM     all      3.90      0.00      1.10     64.80      0.00     30.20
```
- "What happened last night?": heavy I/O wait between 02:00 and 02:20. Next, check what was scheduled then (backups? topic 039).

### Quick extras

```bash
watch -n 2 -d free -h          # rerun every 2 s and highlight changes
systemd-cgtop                  # CPU / memory / I/O per service (cgroup)
ip -s link show eth0           # packets, errors, drops per interface
ss -s                          # socket summary (topic 095)
```

### Try it (load generator)

```bash
sudo dnf install -y stress-ng                 # in AppStream on RHEL 10; apt install stress-ng on Ubuntu
vmstat 2 &                                    # in one window
stress-ng --cpu 2 --timeout 60s               # watch r and us rise
stress-ng --vm 1 --vm-bytes 75% --timeout 60s # watch available drop, si/so appear
stress-ng --hdd 1 --timeout 60s               # watch wa, b, and iostat await
```
Identify each bottleneck from the numbers alone, then check with `top`.

**Check your work:** on your lab VM, from the notes folder, run `sudo ./checks/check 036` for every step, or `sudo ./checks/check 036 STEP` for one (topic 002 shows how to get the notes there).

## Where you'll use it

- **"Server is slow" triage:** `uptime` → `vmstat 1` → `iostat -xz 1` → `mpstat -P ALL 1` → `pidstat 1`. This is the core of "the first 60 seconds" (topic 103).
- **After-the-fact investigation:** `sar -f` for the incident window, then correlate with logs (`journalctl --since`, topic 038) and cron/timer schedules.
- **Capacity planning:** sar history shows growth trends.
- **Production monitoring** (Prometheus node_exporter, Datadog, CloudWatch) collects these **same kernel counters**. Understanding vmstat/iostat columns is understanding your dashboards.

## When it breaks

| Observation | Bottleneck | Next step |
|---|---|---|
| `r` > CPUs, `us`/`sy` high, `id` ≈ 0 | CPU | Top processes (`pidstat`); optimise, renice, scale |
| `available` low, `si`/`so` > 0 | Memory | Large RSS (`pidstat -r`); fix leaks; add RAM or limits |
| `wa` high, `b` > 0, `await` rising | Disk | `iostat -x` for the device, `pidstat -d` for the process |
| `st` high | Hypervisor contention | Escalate; resize or move the VM |
| One CPU at 100% in `mpstat -P ALL` | A single-threaded process | Identify it; it can't use more cores |
| `iostat: command not found` | sysstat not installed | `dnf install sysstat` |
| `sar: Cannot open /var/log/sa/saDD` | Collection not enabled | `systemctl enable --now sysstat`; wait for samples |
| The first line of vmstat/iostat looks odd | It's the average since boot | Read the later lines |

## Quick recap

- USE: Utilization, Saturation, Errors, for CPU, memory, disk and network.
- `free -h` (watch **available**), `vmstat 2` (`r b si so wa st`), `iostat -xz 2` (`await aqu-sz %util`), `mpstat -P ALL`, `pidstat -r/-d`.
- `sar` = history from `/var/log/sa/`; enable sysstat **before** you need it.
- Ignore the first sample (since-boot average). Judge SSDs by latency, not `%util`.

**Interview questions**

1. *A server is slow. Where do you start?* `uptime` (load vs CPUs), `vmstat 1` (run queue, blocked tasks, swapping, I/O wait, steal), `iostat -xz 1` (disk latency), `mpstat -P ALL` (single hot CPU), then `pidstat`/`top` for the process, then the logs.
2. *What does high `wa` mean?* CPUs are idle while waiting for I/O, so storage is the bottleneck. Check `iostat -x` for latency and find the process with `pidstat -d`.
3. *How would you see what happened at 3 AM yesterday?* `sar -f /var/log/sa/saDD -s 03:00:00 -e 04:00:00` with `-u`, `-r`, `-d`, `-q`, then correlate with logs and scheduled jobs.

**Scenario question** (answer out loud first, then compare)

> *"Users say the server 'was slow around 3 AM' but it's fine now. How do you investigate something that's already over?"*

**Model answer:**
1. **sar** history (if sysstat was enabled): `sar -u`, `-q` (load, run queue), `-r` (memory), `-B` (paging), `-d` (disk), `-n DEV` for 02:30–03:30 from `/var/log/sa/saDD`.
2. The **journal** for that window: `journalctl --since "03:00" --until "03:30"`, especially OOM kills, I/O errors, service restarts.
3. **Scheduled jobs** at that time: `systemctl list-timers`, cron files, backups, `logrotate`, database maintenance.
4. Correlate: high `%iowait` and disk await at the same minute as a backup start points at the cause.
5. If there's no history, enable sysstat (and persistent journal) now, so the next occurrence is captured.

**Likely follow-ups:**
- *What is the USE method?* For every resource, check Utilization, Saturation and Errors.
- *Why ignore the first line of `vmstat 1`?* It's the average since boot, not the current state.
