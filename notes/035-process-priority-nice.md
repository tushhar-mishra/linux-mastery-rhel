# 035 · Process Priority: nice, renice and Friends

> **You need first:** [034 · top and load average](034-top-and-load-average.md)
> **Next:** [036 · Resource monitoring](036-resource-monitoring.md)

---

## What it is

The **scheduler** is the part of the kernel that decides which process runs on which CPU, and for how long. When more processes want CPU time than there are cores, it has to share. For normal processes you influence the sharing with the **nice value**:

- Range **−20** (highest priority, least "nice" to others) to **+19** (lowest priority, very "nice").
- Default **0**.
- Higher nice = a **smaller share** of CPU when the CPUs are busy.

Tools: `nice` (start a command with a nice value), `renice` (change a running process), plus related tools for disk I/O priority (`ionice`), CPU pinning (`taskset`) and real-time scheduling (`chrt`).

## Why it exists

Some work matters more than other work. A nightly backup compressing 200 GB shouldn't slow down the web server answering customers. Nice lets the backup use **spare** CPU without competing equally with important processes.

Nice does **nothing** when the CPUs are idle, and it does **not** affect disk I/O.

## Analogy

The CPU is a **shared pizza**. Each process gets slices according to its **weight**. Nice is how polite you are: a nice value of +19 means "I'll take a tiny slice, others first"; −20 means "give me a big slice". If nobody else is hungry (idle CPUs), even the most polite person can eat the whole pizza.

## How it works inside

- Linux 6.6+ (including RHEL 10's 6.12) uses the **EEVDF** scheduler ("Earliest Eligible Virtual Deadline First"), which replaced the older **CFS** ("Completely Fair Scheduler"). From an admin's point of view, nice works the same in both.
- Each nice value maps to a **weight**. Each step changes the weight by about **1.25×**, so a process at nice 0 gets roughly 10% more CPU than one at nice 1. Shares are **relative**: two processes at nice 10 split the CPU 50/50, exactly like two at nice 0.
- top's `PR` column = `20 + NI` for normal tasks (0…39). The kernel internally uses 100–139 for normal tasks and 0–99 for **real-time** tasks, shown as `rt` in top. Real-time tasks always run before normal ones.
- Nice is stored per process (actually per thread) and **inherited** by child processes. It disappears when the process ends, so to make it permanent for a service, set it in the systemd unit (`Nice=`, topic 098).

### Who may do what

| Action | Normal user | root |
|---|---|---|
| Start a command with nice > 0 | ✔ | ✔ |
| Raise the nice value of your own process (lower its priority) | ✔ | ✔ |
| **Lower** the nice value, even back to where it was | ✘ | ✔ |
| Use negative nice values | ✘ | ✔ |
| Renice other users' processes | ✘ | ✔ |

(PAM's `limits.conf` can allow specific users to go lower, with the `nice` item, topic 029.)

## Commands

```bash
nice -n 10 tar -czf /backup/home.tgz /home
```
- Starts tar at nice 10. `nice cmd` with no `-n` means 10.

```bash
sudo nice -n -5 ./critical_job
```
- Negative values need root.

```bash
renice -n 15 -p 4410
```
```
4410 (process ID) old priority 0, new priority 15
```

```bash
sudo renice -n 10 -u alice     # every process of alice
renice -n 15 -g 4321           # a whole process group
```

```bash
ps -eo pid,ni,pri,%cpu,cmd --sort=-%cpu | head -5
```
```
    PID  NI PRI %CPU CMD
   4410  15   4 48.2 tar -czf /backup/home.tgz /home
   1234   0  19 31.0 /usr/bin/java -jar app.jar
```
- `NI` = nice. (`ps`'s `PRI` column uses a different scale than top's `PR`; compare NI.)

In `top`: press `r`, type the PID, then the new nice value.

### Seeing the effect (on one CPU)

```bash
taskset -c 0 sh -c 'while :; do :; done' &
taskset -c 0 sh -c 'while :; do :; done' &
taskset -c 0 nice -n 10 sh -c 'while :; do :; done' &
top          # press 1: the two nice-0 loops get ~45% each, the nice-10 one ~10%
pkill -f 'while :; do :; done'
```
- `taskset -c 0` pins all three to CPU 0, so they must compete.

### Beyond nice

| Tool | Purpose |
|---|---|
| `ionice -c3 -p PID` | **Disk** I/O priority: class 3 = idle (only when nobody else uses the disk) |
| `ionice -c2 -n7 cmd` | Best-effort class, lowest level (0 = highest, 7 = lowest) |
| `taskset -c 0,1 cmd` | Pin to specific CPUs (CPU **affinity**) |
| `chrt -f -p 50 PID` | **Real-time** FIFO scheduling. ⚠️ A busy real-time task can freeze the whole machine |
| systemd `Nice=`, `CPUWeight=`, `IOWeight=` | Permanent priorities for services (topic 098) |

The polite batch-job combo:
```bash
nice -n 19 ionice -c3 rsync -a /data /backup/
```

### Try it
1. Run the three-loop demo above and watch `%CPU` in top. Then `renice -n 5` one of the nice-0 loops and watch the shares change.
2. As a normal user, renice your own process to 10, then try to set it back to 0 (denied).
3. Run a big `find /` with `nice -n 19 ionice -c3` and compare how the system feels.

## Where you'll use it

- **Backups, compression, report generation, reindexing:** run them with `nice -n 10–19` and `ionice -c3`.
- **Build servers and CI runners:** lower the priority of builds so the agent stays responsive.
- **Services:** `Nice=` / `CPUWeight=` in a systemd drop-in to make it permanent.
- **Containers and Kubernetes:** CPU **requests** become cgroup **CPU weights**, the same "relative share" idea as nice, applied to whole containers (topic 097). CPU **limits** are a hard cap (quota), which nice never is.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `renice: failed to set priority … Permission denied` | A normal user lowering nice, or someone else's process | `sudo renice` |
| renice "did nothing" | CPUs weren't busy, or the job is waiting on disk, not CPU | Check `%CPU` and `wa`; use `ionice` for disk |
| The priority reset after a restart | renice only affects that running PID | Set `Nice=` in the systemd unit |
| The system froze after `chrt` | A real-time task is starving everything else | Avoid real-time for CPU-heavy work; kill it from the console |

## Quick recap

- Nice −20 (high priority) … 0 (default) … +19 (low). top shows `PR = 20 + NI`.
- It only matters when CPUs are contended; shares are relative (about 1.25× per step). It doesn't affect disk.
- Users may only make their own processes nicer; root may do anything.
- `nice -n N cmd`, `renice -n N -p PID`, `ionice -c3`, and `Nice=` in systemd for permanence.

**Interview questions**

1. *What's the range and meaning of nice values?* −20 (highest priority) to +19 (lowest); default 0. A higher nice means a smaller CPU share when CPUs are busy.
2. *Can a normal user raise a process's priority?* No. They can only make their own processes nicer (lower priority), and can't undo it.
3. *Does nice limit disk usage?* No. Use `ionice`, or cgroup `IOWeight` for services and containers.
