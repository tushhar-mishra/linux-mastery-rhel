# Process Priority & nice/renice

> **Objective:** *Adjust process scheduling* **[RHCSA Core]**
> **Related:** [top & monitoring](top-and-process-monitoring.md) · [Processes & signals](processes-and-signals.md) · [tuned profiles](../containers-and-virtualization/tuned-profiles.md) · [cgroups (CPU weight & quota)](../containers-and-virtualization/namespaces-and-cgroups.md) · [systemd unit files](../boot-systemd-and-kernel/systemd-unit-files.md)

## 1. Overview

When more processes want CPU than there are cores, the kernel scheduler decides who runs. For normal processes you influence that with the **nice value**: higher nice = "nicer" to others = **lower** priority = a smaller share of CPU. Nice doesn't change anything when CPUs are idle, and it doesn't affect disk I/O.

## 2. Key Concepts

| Item | Range / meaning |
|---|---|
| Nice value (`NI`) | **−20** (highest priority) … **0** (default) … **+19** (lowest) |
| top `PR` for normal tasks | `20 + NI` (so 0…39); `rt` = real-time |
| Kernel internal priority | 0–99 real-time, 100–139 normal (`100 + 20 + NI`) **[Interview Knowledge]** |
| Effect | Each nice step changes the CPU **weight** by roughly 1.25×, so the share is relative, not absolute |

**Who can do what:**

| Action | Regular user | root |
|---|---|---|
| Start a command with nice > 0 | ✔ | ✔ |
| Increase nice of own process (lower priority) | ✔ | ✔ |
| Decrease nice (raise priority), **even back to the previous value** | ✘ | ✔ |
| Use negative nice values | ✘ | ✔ |
| Renice other users' processes | ✘ | ✔ |

> ⚠️ **Common misconception:** "other users can set 0 to 19" is incomplete. They can only *raise* niceness on their own processes and can never lower it again.

## 3. Commands & Syntax

```bash
nice -n 10 tar -czf /backup/home.tgz /home     # start with nice 10
nice tar …                                     # no -n → nice 10
sudo nice -n -5 ./critical_job                 # negative nice needs root

renice -n 5 -p 1234                            # change a running process
sudo renice -n -5 -p 1234                      # raise priority (root only)
sudo renice -n 10 -u alice                     # all of alice's processes
renice -n 15 -g 4321                           # a process group

ps -o pid,ni,cmd -p 1234                       # verify NI
ps -eo pid,ni,%cpu,cmd --sort=-%cpu | head     # nice values of busy processes
top        # then 'r', enter PID, enter the new nice value
```

## 4. Demonstration (single CPU)

```bash
for i in 1 2 3; do sh -c 'while :; do :; done' & done   # three CPU burners, ~33% each
nice -n 10 sh -c 'while :; do :; done' &                # gets far less CPU (PR 30, NI 10)
renice -n 5 -p <PID-of-first>                           # its share drops relative to the others
top                                                     # watch PR/NI/%CPU
pkill -f 'while :; do :; done'                          # clean up
```

On a multi-core VM, pin the burners to one CPU to see the effect: `taskset -c 0 nice -n 10 …` **[Advanced]**.

## 5. Beyond nice **[Advanced/Optional]**

| Tool | Purpose |
|---|---|
| `ionice -c3 -p PID` / `ionice -c2 -n7 cmd` | Disk I/O priority (idle / best-effort level 0–7) |
| `chrt -f -p 50 PID` | Real-time scheduling (FIFO/RR); can starve the system ⚠️ |
| `taskset -c 0,1 cmd` | CPU affinity |
| systemd unit `Nice=`, `CPUWeight=`, `IOWeight=` | Persistent priorities for services ([unit files](../boot-systemd-and-kernel/systemd-unit-files.md)) |
| `/etc/security/limits.conf` `priority`/`nice` | Default/maximum nice per user via PAM |

The RHEL 10 kernel (6.12) uses the EEVDF scheduler (successor to CFS); nice values work the same way from an admin's point of view.

## 6. RHCSA Exam Focus **[RHCSA Core]**

```bash
nice -n 15 /usr/local/bin/report.sh &     # "start with nice value 15"
renice -n -10 -p $(pgrep -x heavyjob)     # "set nice value of running process to -10" (as root)
ps -o pid,ni,comm -p $(pgrep -x heavyjob) # verify
```

- Read whether the task wants **higher priority** (lower/negative nice) or **lower priority** (higher nice).
- Nice set with `renice` lasts only for the life of the process; services need `Nice=` in their unit to persist.

## 7. Production Practices **[Production Practice]**

- Run backups, compression, reindexing and batch jobs with `nice -n 10–19` (plus `ionice -c3`).
- Don't "fix" an overloaded server by renicing everything; find the real bottleneck (CPU vs I/O vs memory) first.
- For services, set `Nice=`/`CPUWeight=` in a systemd drop-in rather than renicing PIDs by hand.

## 8. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `renice: failed to set priority … Permission denied` | Non-root lowering nice / another user's process | `sudo renice` |
| Renice "did nothing" | CPUs aren't contended, or the job is I/O-bound | Check `%CPU`, `wa`; use `ionice` for I/O |
| Priority resets after a restart | renice affects the running PID only | `Nice=` in the systemd unit |
| System unresponsive after `chrt` | Real-time task starving others | Avoid RT for CPU-bound work; kill from the console |

## 9. Interview Questions

| Question | Answer |
|---|---|
| Range and meaning of nice? | −20 (highest priority) to 19 (lowest); default 0. |
| Can a normal user make a process higher priority? | No. Only increase niceness of their own processes. |
| Relation between PR and NI in top? | `PR = 20 + NI` for normal processes. |
| Does nice limit disk usage? | No; use `ionice` or cgroup `IOWeight`. |
| How do you make a service's priority persistent? | `Nice=` (or `CPUWeight=`) in its systemd unit. |

## 10. Quick Revision

```bash
NI −20 (high) … 0 … 19 (low) · PR = 20+NI · users: only raise NI on own processes · root: anything
nice -n 10 cmd | renice -n 5 -p PID | renice -n 10 -u user | top → r | ps -o pid,ni,cmd
ionice -c3 · chrt (RT, careful) · systemd Nice=/CPUWeight= for persistence
```

## 11. Cross-References

- [top & process monitoring](top-and-process-monitoring.md)
- [Processes & signals](processes-and-signals.md)
- [systemd unit files (`Nice=`, `CPUWeight=`)](../boot-systemd-and-kernel/systemd-unit-files.md) · [tuned profiles](../containers-and-virtualization/tuned-profiles.md)
