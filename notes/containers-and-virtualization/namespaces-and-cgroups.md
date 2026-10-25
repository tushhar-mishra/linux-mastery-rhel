# Namespaces, cgroups & How Containers Are Built

> **Track:** **[Internals]** (the foundation of Podman, Kubernetes and systemd resource control) · **Verified:** every demo below (including §6) was run on RHEL 10.2 UBI containers (systemd 257, util-linux, kernel 6.12; Oct 2026). Use a lab VM: the commands need root and change kernel state.
> **Prerequisites:** [Processes & system calls](../processes-and-resource-management/processes-and-system-calls.md) · [Memory management](../processes-and-resource-management/memory-management.md) · [systemd unit files (resource control)](../boot-systemd-and-kernel/systemd-unit-files.md#9-resource-control-cgroups) · [TCP/IP (netns, veth)](../networking-and-ssh/tcp-ip-for-operators.md#12-network-namespaces-veth--bridges-container-networking-in-6-commands)
> **Next:** [Podman containers](podman-containers.md) · [Linux → Kubernetes bridge](../advanced-rhel-and-career-notes/linux-foundations-of-kubernetes.md)

## 1. Why This Matters

A container is **not** a lightweight VM. It is an ordinary Linux process tree that the kernel shows a different view of the system (**namespaces**), limits in resources (**cgroups**), and restricts in privileges (**capabilities, seccomp, SELinux, user namespaces**), running on a layered root filesystem (**overlayfs**). Every container problem ("OOMKilled", "CPU throttled", "permission denied as root", "can't see the host's processes", "PID 1 won't stop") is one of these mechanisms at work. The same mechanisms power systemd's per-service limits.

```
container = clone(namespaces) + cgroup(limits) + overlayfs rootfs + pivot_root
          + dropped capabilities + seccomp filter + SELinux label (container_t:s0:cX,cY) [+ user namespace]
```

## 2. Namespaces: What a Process Can See

| Namespace | Isolates | `unshare` flag | Container effect |
|---|---|---|---|
| **mnt** | Mount table | `--mount` | Own root filesystem and mounts |
| **pid** | PID numbers | `--pid --fork` | Container's first process is PID 1 |
| **net** | Interfaces, addresses, routes, firewall, sockets | `--net` | Own `eth0`, own `localhost` |
| **uts** | Hostname, domain name | `--uts` | Own hostname |
| **ipc** | SysV IPC, POSIX message queues | `--ipc` | Shared memory isolation |
| **user** | UID/GID mappings, capabilities scope | `--user` | Root inside = unprivileged outside (rootless) |
| **cgroup** | View of the cgroup hierarchy | `--cgroup` | Container sees its cgroup as `/` |
| **time** | Boot/monotonic clock offsets | `--time` | Rarely used |

Every process has a link per namespace in `/proc/PID/ns/`. Two processes share a namespace when the inode numbers match.

```bash
lsns                              # all namespaces on the host: NS, TYPE, NPROCS, PID, COMMAND
ls -l /proc/$$/ns                 # net -> net:[4026532695] …
lsns -p PID                       # namespaces of one process
```

### 2.1 Try each namespace (verified)

```bash
# PID + UTS + mount: a new process tree with its own hostname
unshare --fork --pid --mount-proc --uts bash -c 'hostname inside-ns; echo inside: $(hostname); echo shell PID: $$; ps -ef'
#   inside: inside-ns
#   shell PID: 1                      ← the shell is PID 1 in its own PID namespace
#   (ps -ef shows only bash and ps)   ← --mount-proc mounted a /proc for the new PID namespace
hostname                              # outside: unchanged

# USER namespace as an unprivileged user: "root" without real privilege
su - kim -c 'unshare --user --map-root-user bash -c "id; cat /proc/self/uid_map; touch /etc/x"'
#   uid=0(root) gid=0(root) groups=0(root)
#            0       1000          1   ← UID 0 inside maps to UID 1000 outside, 1 ID long
#   touch: cannot touch '/etc/x': Permission denied   ← the real (host) permissions still apply

# NET namespace + entering it from outside
unshare --net --fork sleep 300 &
nsenter -t "$(pgrep -n -x sleep)" -n ip -br link     # only lo (DOWN) and tunnel stubs: no eth0
```

`nsenter -t PID -a` enters all namespaces of a running process; `podman exec` does the equivalent.

## 3. cgroups v2: What a Process Can Use

A **control group** is a directory in `/sys/fs/cgroup/` containing processes and **controller** files. RHEL 10 supports **cgroups v2 only** (the unified hierarchy).

```
/sys/fs/cgroup/                         ← root
├── init.scope/                         ← PID 1
├── system.slice/                       ← system services
│   ├── sshd.service/   (cgroup.procs, memory.max, cpu.max, pids.max …)
│   └── httpd.service/
├── user.slice/user-1000.slice/session-3.scope/   ← login sessions
└── machine.slice/                      ← VMs and containers (libvirt, rootful Podman)
```

```bash
cat /proc/PID/cgroup              # 0::/system.slice/sshd.service
systemd-cgls                      # tree of slices → units → processes
systemd-cgtop                     # live CPU/memory/IO per cgroup
```

### 3.1 Controllers and their key files

| Controller | Files | Meaning |
|---|---|---|
| **memory** | `memory.current`, `memory.max`, `memory.high`, `memory.swap.max`, `memory.events`, `memory.stat`, `memory.pressure` | Usage; hard limit (→ OOM kill); throttling threshold; swap limit; event counters (`oom`, `oom_kill`, `high`, `max`) |
| **cpu** | `cpu.max` (`QUOTA PERIOD`), `cpu.weight` (1–10000, default 100), `cpu.stat`, `cpu.pressure` | Bandwidth cap; relative share under contention; usage & throttling stats |
| **pids** | `pids.max`, `pids.current`, `pids.events` | Max tasks (processes + threads): fork-bomb protection |
| **io** | `io.max`, `io.weight`, `io.stat`, `io.pressure` | Per-device bandwidth/IOPS limits and weights |
| **cpuset** | `cpuset.cpus`, `cpuset.mems` | Pin to CPUs / NUMA nodes |
| core | `cgroup.procs`, `cgroup.controllers`, `cgroup.subtree_control`, `cgroup.events`, `cgroup.kill` | Members; available controllers; controllers enabled for children; populated state; kill all |

**Rules that trip people up:**

- A controller is usable in a child cgroup **only if it's enabled in the parent's `cgroup.subtree_control`**. Verified: with only `memory pids` enabled at the root, writing `cpu.max` in a child failed (`Permission denied`; the file didn't exist) until `echo +cpu > /sys/fs/cgroup/cgroup.subtree_control`.
- **No internal processes:** apart from the root, a cgroup that has controllers enabled for its children can't itself contain processes. That's why systemd puts processes in leaf `.service`/`.scope` cgroups.
- On a systemd host, **let systemd own the tree**: use `systemd-run`, unit properties or `systemctl set-property` rather than `mkdir` under `/sys/fs/cgroup` (the manual steps below are for understanding, in a lab).

### 3.2 Memory limit by hand (verified)

```bash
mkdir /sys/fs/cgroup/demo
echo 50M > /sys/fs/cgroup/demo/memory.max
echo 0   > /sys/fs/cgroup/demo/memory.swap.max
bash -c 'echo $$ > /sys/fs/cgroup/demo/cgroup.procs; cat /proc/self/cgroup; python3 -c "b=bytearray(200*1024*1024)"'
#   0::/demo
#   … Killed                 rc=137
grep -E '^(oom|oom_kill) ' /sys/fs/cgroup/demo/memory.events
#   oom 1
#   oom_kill 1
```

This is precisely a Kubernetes/Podman **OOMKilled** container: the cgroup hit `memory.max`, the kernel's OOM killer chose a victim **inside the cgroup**, and the host's free memory was irrelevant ([memory management §8.1](../processes-and-resource-management/memory-management.md#81-global-oom-vs-cgroup-oom)). `memory.high` is the softer knob: above it the cgroup is throttled and reclaimed, not killed.

### 3.3 CPU quota and throttling (verified)

`cpu.max` = `QUOTA PERIOD` in microseconds: `20000 100000` allows 20 ms of CPU time per 100 ms period, i.e. 20% of one CPU (`max 100000` = unlimited).

```bash
mkdir /sys/fs/cgroup/cpudemo ; echo "20000 100000" > /sys/fs/cgroup/cpudemo/cpu.max
bash -c 'echo $$ > /sys/fs/cgroup/cpudemo/cgroup.procs; timeout 3 bash -c "while :; do :; done"'
grep -E 'usage_usec|nr_periods|nr_throttled|throttled_usec' /sys/fs/cgroup/cpudemo/cpu.stat
#   usage_usec 620917         ← 0.62 s of CPU in 3 s wall time (≈ 20%)
#   nr_periods 31
#   nr_throttled 31           ← throttled in every period
#   throttled_usec 2401469    ← 2.4 s spent waiting for the next period
cat /sys/fs/cgroup/cpudemo/cpu.pressure    # some avg10=14.12 … ← tasks stalled for CPU
```

**Why this matters in production:** a service or pod with a CPU *limit* can show high latency while the node's CPUs are mostly **idle**, because it exhausts its quota early in each period and then waits. Look at `nr_throttled`/`throttled_usec` growth, not just CPU utilization. `cpu.weight` (Kubernetes CPU *requests*) only matters under contention and never throttles.

### 3.4 Process limit (verified)

```bash
mkdir /sys/fs/cgroup/pidsdemo ; echo 5 > /sys/fs/cgroup/pidsdemo/pids.max
bash -c 'echo $$ > /sys/fs/cgroup/pidsdemo/cgroup.procs; for i in 1 2 3 4 5 6; do sleep 5 & done; wait'
#   bash: fork: retry: Resource temporarily unavailable
cat /sys/fs/cgroup/pidsdemo/pids.events     # max 3  ← number of times the limit was hit
```

systemd sets `TasksMax=` for every service (and `pids.max` for user slices), which is why a runaway fork loop in one unit can't take down the host.

### 3.5 The systemd way (persistent)

```bash
systemd-run --unit=job1 -p MemoryMax=1G -p CPUQuota=50% -p TasksMax=100 /usr/local/bin/batch.sh
systemctl set-property httpd.service MemoryMax=2G CPUWeight=200
systemctl show httpd -p MemoryMax -p CPUQuotaPerSecUSec -p TasksMax
cat /sys/fs/cgroup/system.slice/httpd.service/memory.max
```

## 4. Overlay Filesystem: Container Image Layers

Container images are stacks of read-only **layers**; a running container adds one writable layer on top, combined with **overlayfs**:

```bash
mount -t tmpfs tmpfs /mnt/ov ; cd /mnt/ov ; mkdir lower upper work merged
echo base > lower/a.txt ; echo keep > lower/b.txt
mount -t overlay overlay -o lowerdir=lower,upperdir=upper,workdir=work merged
echo changed > merged/a.txt ; rm merged/b.txt ; echo new > merged/c.txt
ls -l upper
#   -rw-r--r-- … a.txt         ← COPY-UP: the modified file now lives in the upper layer
#   c--------- … 0, 0 b.txt    ← WHITEOUT: a 0,0 character device hides the deleted lower file
#   -rw-r--r-- … c.txt         ← new files go to the upper layer
cat lower/a.txt                # base   ← the lower (image) layer is never modified
```

Consequences: deleting a file in a later image layer doesn't shrink the image (the data stays in a lower layer); writing large files into the container layer is slow and lost when the container is removed (use **volumes**); `overlay` upper directories can't sit on another overlay (verified: `filesystem on upper not supported as upperdir`).

Podman storage: rootful `/var/lib/containers/storage/overlay/`, rootless `~/.local/share/containers/storage/`.

## 5. Privilege Reduction

| Mechanism | What it does in a container | Inspect |
|---|---|---|
| **Capabilities** | Default container "root" keeps only a small set. Verified in a default container: 14 capabilities (`cap_chown,cap_dac_override,…,cap_net_bind_service,cap_net_raw,cap_sys_chroot,…`); no `CAP_SYS_ADMIN`, `CAP_NET_ADMIN`, `CAP_SYS_MODULE` | `grep Cap /proc/PID/status`; `capsh --decode=…`; `podman run --cap-add/--cap-drop` |
| **seccomp** | Syscall filter blocks dangerous calls (e.g., `kexec_load`, most `mount` variants, kernel keyring operations) | `grep Seccomp /proc/PID/status` (2 = filter active) |
| **SELinux** | Processes run as `container_t` with a unique **MCS category pair**; files as `container_file_t` with the same categories, so containers can't read each other's files or most host files | `ps -eZ \| grep container_t`; `:Z`/`:z` on bind mounts ([MCS](../firewall-and-selinux/selinux-mls-and-mcs.md)) |
| **User namespace** (rootless) | Container UID 0 maps to your UID; other UIDs to your `/etc/subuid` range | `podman unshare cat /proc/self/uid_map`; `/etc/subuid` |
| **no_new_privs** | Set-UID binaries can't escalate | `grep NoNewPrivs /proc/PID/status` |

**"Root in a container" therefore means:** UID 0 in the user namespace (maybe an unprivileged host UID), with few capabilities, filtered syscalls, a confined SELinux domain, and a cgroup limit. `--privileged` turns most of that off; avoid it.

## 6. Assembling a Container by Hand (Lab) **[Advanced]**

This is roughly what `crun` (Podman's default OCI runtime) does:

```bash
# 1. A root filesystem (here: export one from an existing image)
mkdir -p /srv/ctr/rootfs
podman export "$(podman create registry.access.redhat.com/ubi10/ubi)" | tar -x -C /srv/ctr/rootfs
# 2. A cgroup with limits
mkdir /sys/fs/cgroup/myctr ; echo 100M > /sys/fs/cgroup/myctr/memory.max ; echo 50 > /sys/fs/cgroup/myctr/pids.max
# 3. New namespaces + join the cgroup + switch root
unshare --mount --uts --ipc --net --pid --fork bash -c '
  echo $$ > /sys/fs/cgroup/myctr/cgroup.procs        # $$ is 1 here; the kernel resolves it in the writer's PID namespace
  hostname myctr
  mount --make-rprivate /                             # don't propagate our mounts back to the host
  cd /srv/ctr/rootfs && mount --bind . . && cd /srv/ctr/rootfs && mkdir -p old && pivot_root . old
  cd / && mount -t proc proc /proc && umount -l /old  # fresh /proc for the new PID namespace; detach the host root
  exec /bin/bash'
# Inside (verified): cat /proc/sys/kernel/hostname → myctr · ls /proc → only PIDs 1 and your children
#                    cat /proc/self/cgroup → 0::/myctr · cat /etc/redhat-release → the image's release · /old is gone
# (The UBI base image has no ps/ip; install procps-ng/iproute into the rootfs with dnf --installroot to explore further.)
```

Then compare with `podman run --rm -it --memory 100m --pids-limit 50 ubi10/ubi bash`: the same kernel objects, plus networking (veth + bridge), capabilities, seccomp and SELinux set up for you.

## 7. Troubleshooting

| Symptom | Mechanism | Check |
|---|---|---|
| Container/service killed, exit 137, host has free RAM | cgroup `memory.max` | `memory.events` (`oom_kill`), `memory.current`, `memory.stat`; kernel log "Memory cgroup out of memory" |
| High latency, CPU looks idle | `cpu.max` throttling | `cpu.stat` `nr_throttled`, `throttled_usec`; `cpu.pressure` |
| `fork: Resource temporarily unavailable` | `pids.max` (or `ulimit -u`) | `pids.events`, `pids.current`; `TasksMax=` |
| "Permission denied" as root inside a container | Missing capability, seccomp, SELinux, or user namespace mapping | `grep Cap /proc/1/status` inside; `ausearch -m avc`; run with a specific `--cap-add` to test |
| Bind mount unreadable | SELinux label | `:Z`/`:z`; `ls -Z` |
| Container sees host processes / network | Namespace not created (e.g., `--pid=host`, `--network=host`) | `podman inspect`; compare `/proc/PID/ns/*` inodes |
| Can't write `cpu.max` in a new cgroup | Controller not enabled in parent `subtree_control` | `cat cgroup.subtree_control` |
| `rmdir` cgroup: `Device or resource busy` | Processes still inside | `cat cgroup.procs`; wait or `echo 1 > cgroup.kill` |

## 8. Interview Questions

| Question | Answer |
|---|---|
| What is a container, technically? | A process tree in its own namespaces, constrained by a cgroup, with reduced capabilities/seccomp/SELinux, running on an overlay root filesystem. |
| Namespaces vs cgroups? | Namespaces limit what a process can **see**; cgroups limit what it can **use**. |
| Name the namespace types. | mnt, pid, net, uts, ipc, user, cgroup, time. |
| How does rootless Podman work? | A user namespace maps container UID 0 to the user's UID and other IDs to the subuid range; no real root privileges are involved. |
| Why is a pod CPU-throttled at 30% node utilization? | Its `cpu.max` quota (CPU limit) is used up early in each 100 ms period; check `nr_throttled`. |
| What does `memory.high` do vs `memory.max`? | `high` throttles and reclaims; `max` triggers the cgroup OOM killer. |
| How does overlayfs handle a deleted file? | It creates a whiteout (a 0,0 character device) in the upper layer; the lower layer is unchanged. |
| Why can't you just `mkdir` cgroups on a systemd host? | systemd owns the hierarchy; use units, `systemd-run`, or `set-property`, or delegate a subtree. |
| What does `--privileged` do? | Grants all capabilities, disables seccomp and SELinux separation, exposes host devices: avoid. |

## 9. Quick Revision

```
container = namespaces (see) + cgroups (use) + overlayfs + pivot_root + caps/seccomp/SELinux/userns (privilege)
ns: mnt pid net uts ipc user cgroup time · lsns · /proc/PID/ns/* · unshare --fork --pid --mount-proc · nsenter -t PID -a
cgroup v2 only on RHEL 10 · /sys/fs/cgroup · cgroup.procs · subtree_control (+cpu) · no internal processes · systemd owns it
memory.max (OOM) memory.high (throttle) memory.events (oom_kill) · cpu.max "QUOTA PERIOD" cpu.stat nr_throttled · cpu.weight · pids.max
systemd-run -p MemoryMax= -p CPUQuota= · systemctl set-property · systemd-cgls / systemd-cgtop
overlay: lower (ro) + upper (rw) + work → copy-up, whiteout (c 0,0) · volumes for data
rootless: uid_map 0 → your UID, /etc/subuid · container_t:s0:cX,cY · --privileged = all protections off
```

## 10. Cross-References

- [Podman containers](podman-containers.md) · [Virtualization vs containers](virtualization-vs-containers.md) · [SELinux MCS](../firewall-and-selinux/selinux-mls-and-mcs.md)
- [Processes & system calls (clone, PID 1, capabilities)](../processes-and-resource-management/processes-and-system-calls.md) · [Memory management (cgroup OOM)](../processes-and-resource-management/memory-management.md)
- [systemd unit files (MemoryMax, CPUQuota, TasksMax, sandboxing)](../boot-systemd-and-kernel/systemd-unit-files.md) · [TCP/IP (netns, veth, NAT)](../networking-and-ssh/tcp-ip-for-operators.md)
- [Linux → Kubernetes bridge](../advanced-rhel-and-career-notes/linux-foundations-of-kubernetes.md)
