# Swap: Partitions, LVs, Swap Files & Swappiness

> **Sessions:** S42 · **Objective:** *Add new partitions, logical volumes, and swap to a system non-destructively* **[RHCSA Core]**
> **Related:** [Disks & partitioning](disks-and-partitioning.md) · [LVM fundamentals](lvm-fundamentals.md) · [Mounting & fstab](mounting-and-fstab.md) · [top & monitoring](../processes-and-resource-management/top-and-process-monitoring.md)

## 1. Overview

**Swap** is disk space the kernel uses to page out memory that isn't actively used, freeing RAM for active work and page cache. It can be a **partition**, an **LVM logical volume**, or a **swap file**. Swap is much slower than RAM. Constant swapping in and out (**thrashing**) means the system needs more memory, not more swap.

## 2. Key Concepts

| Concept | Detail |
|---|---|
| Virtual memory | RAM + swap |
| Page out / page in | Moving memory pages to / from swap (`vmstat` `so`/`si`) |
| `vm.swappiness` | Kernel preference between reclaiming **anonymous memory** (→ swap) and **page cache**. Range 0–200 on RHEL 10's kernel; higher = swap more eagerly. Low ≠ "never swap" |
| Defaults | Kernel default 60; **tuned profiles override it** (e.g., `virtual-guest` 30, `throughput-performance` 10) |
| Priority | With several swap areas, higher `pri` is used first; equal priorities are striped |

**Red Hat's sizing guidance (no hibernation):**

| RAM | Recommended swap |
|---|---|
| ≤ 2 GB | 2 × RAM |
| > 2–8 GB | = RAM |
| > 8–64 GB | At least 4 GB |
| > 64 GB | At least 4 GB (workload-dependent) |

## 3. Inspecting Swap

```bash
swapon --show            # active swap areas: NAME TYPE SIZE USED PRIO
free -h                  # Mem and Swap totals/usage
cat /proc/swaps
vmstat 1 5               # si/so columns: swap-in/out per second
sysctl vm.swappiness ; tuned-adm active
grep VmSwap /proc/*/status 2>/dev/null | sort -k2 -n | tail   # biggest swap users [Advanced]
```

## 4. Adding Swap **[RHCSA Core]**

### 4.1 Swap partition (GPT)

```bash
fdisk /dev/vdb   → n → +512M → t → "Linux swap" (alias swap) → w
partprobe /dev/vdb
mkswap /dev/vdb2                         # prints the new UUID
swapon /dev/vdb2
echo "UUID=$(blkid -s UUID -o value /dev/vdb2) none swap defaults 0 0" >> /etc/fstab
swapon -a ; swapon --show                # verify (also after a reboot)
```

### 4.2 Swap on LVM

```bash
lvcreate -n lvswap -L 1G vgdata
mkswap /dev/vgdata/lvswap
echo '/dev/vgdata/lvswap none swap defaults 0 0' >> /etc/fstab   # or UUID=…
swapon -a ; swapon --show
```

### 4.3 Swap file

```bash
dd if=/dev/zero of=/swapfile bs=1M count=1024   # 1 GiB (Red Hat-documented method; no holes)
chmod 600 /swapfile                             # root-only
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap defaults 0 0' >> /etc/fstab
swapon -a ; swapon --show
```

`fallocate -l 1G /swapfile` is faster and works on modern XFS/ext4; if `swapon` reports holes, recreate with `dd`. Don't put swap files on NFS or Btrfs (without special handling).

### 4.4 Priorities

```
UUID=…      none  swap  defaults,pri=10  0 0     # used first
/swapfile   none  swap  defaults,pri=5   0 0
```

## 5. Resizing & Removing

```bash
# Grow a swap LV
swapoff /dev/vgdata/lvswap
lvextend -L +1G /dev/vgdata/lvswap
mkswap /dev/vgdata/lvswap        # ⚠️ new UUID: update fstab if it uses UUID=
swapon -a ; swapon --show

# Remove a swap file
swapoff /swapfile
sed -i '\|^/swapfile |d' /etc/fstab     # or edit with vi
rm /swapfile
```

`swapoff` needs enough free RAM to absorb the pages currently in that swap area.

## 6. Swappiness

```bash
sysctl vm.swappiness                               # current value
sysctl -w vm.swappiness=10                         # runtime only
echo 'vm.swappiness = 10' > /etc/sysctl.d/99-swappiness.conf
sysctl --system                                    # apply all sysctl files; verify with sysctl vm.swappiness
```

Prefer a drop-in in `/etc/sysctl.d/` over editing `/etc/sysctl.conf`. If a tuned profile sets swappiness, a custom tuned profile is the cleanest permanent override (S83).

## 7. RHCSA Exam Focus **[RHCSA Core]**

- "Add a swap partition of 512 MiB, persistent, without removing existing swap": new partition → `mkswap` → fstab by UUID → `swapon -a` → `swapon --show` shows **both** areas.
- Never `swapoff` or delete the existing swap unless the task says so.
- Verify after a test reboot.

## 8. Production Practices **[Production Practice]**

- Monitor `si`/`so` and memory pressure, not just "swap used". Swap holding idle pages is fine; continuous paging is not.
- Databases and latency-sensitive apps often use low swappiness (e.g., 1–10) but still keep some swap as a safety net against the OOM killer.
- Swap files are convenient on cloud VMs without spare disks; LV swap is easiest to resize.

## 9. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `swapon: … read swap header failed` | No `mkswap` | `mkswap DEV` |
| `swapon: … insecure permissions 0644, 0600 suggested` | Swap file mode | `chmod 600 /swapfile` |
| `swapon: swapfile has holes` | Sparse/fallocated file unsupported | Recreate with `dd` |
| Swap missing after reboot | fstab typo or stale UUID (after `mkswap`) | `blkid`; fix fstab; `swapon -a` |
| `swapoff: Cannot allocate memory` | Not enough RAM to absorb swapped pages | Free memory or add other swap first |
| System sluggish, high `si`/`so` | Thrashing | Add RAM, fix the memory hog, or limit workloads |

## 10. Interview Questions

| Question | Answer |
|---|---|
| What does swappiness control? | The kernel's balance between swapping anonymous memory and dropping page cache. |
| Swap partition vs swap file? | Same function; files are easier to add, partitions/LVs are traditional and easy to manage under LVM. |
| Does high swap usage mean a problem? | Not by itself. Continuous swap-in/out (thrashing) does. |
| Why does `mkswap` matter for fstab? | It creates a new UUID; fstab entries must match. |
| How do you persist swappiness? | A file in `/etc/sysctl.d/` (or a tuned profile). |

## 11. Course Corrections

| Course | Correction |
|---|---|
| Default swappiness "60 older, 30 RHEL 8+" | Kernel default 60; tuned profiles set 30 (virtual-guest) or 10 (throughput-performance) |
| Range 0–100 | 0–200 on RHEL 10's kernel |
| "Swappiness = how often swap is used" | It weights anonymous-memory reclaim vs page-cache reclaim |
| `fallocate` first | `dd` is the documented, hole-free method |
| Tested on Ubuntu 18.04 / CentOS 7 | Outdated; procedure verified for RHEL 10 |
| `epel-release-latest-9` / `yum install stress` | RHEL 10 → EPEL 10, `dnf`; check `dnf info stress-ng` first |

## 12. Quick Revision

```bash
swapon --show | free -h | vmstat 1 | /proc/swaps
partition/LV/file → mkswap → swapon → fstab "UUID=… none swap defaults 0 0" → swapon -a
file: dd bs=1M count=N ; chmod 600 ; mkswap ; swapon
grow LV swap: swapoff → lvextend → mkswap (new UUID!) → swapon
sysctl vm.swappiness ; /etc/sysctl.d/99-swappiness.conf ; sysctl --system ; pri=N
```

## 13. Cross-References

- [Disks & partitioning](disks-and-partitioning.md) · [LVM fundamentals](lvm-fundamentals.md) · [Mounting & fstab](mounting-and-fstab.md)
- [top & process monitoring](../processes-and-resource-management/top-and-process-monitoring.md)
- tuned profiles (S83), kernel parameters/sysctl (S53): planned
