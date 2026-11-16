# 050 · Swap: Partitions, LVs, Swap Files and Swappiness

> **You need first:** [049 · LVM](049-lvm.md)
> **Next:** [051 · Filesystem check and repair](051-filesystem-check-and-repair.md)

---

## What it is

**Swap** is disk space the kernel uses as an overflow area for RAM. When memory is tight, the kernel moves **memory pages** (4 KiB chunks of a program's memory) that haven't been used recently out to swap, which frees RAM for active work and the file cache.

- Swap can be a **partition**, an **LVM logical volume** or a **swap file**.
- **Paging out** / **swapping out** = moving pages to swap. **Paging in** = bringing them back when needed (the program pauses while that happens).
- **Thrashing** = constant swapping in and out. The system is crawling because it truly doesn't have enough RAM.
- **`vm.swappiness`** is a kernel setting that controls how eagerly the kernel swaps.

## Why it exists

Programs often allocate memory they rarely touch (startup code, idle buffers). Moving those pages to disk lets the kernel use that RAM for active programs and caching, so overall the machine runs faster. Swap is also a **safety cushion**: without it, a sudden memory spike goes straight to the **OOM killer** (out-of-memory killer, topic 093), which kills a process.

Swap is **much** slower than RAM, so it's not a substitute for buying enough memory.

## Analogy

RAM is your **desk**; swap is a **filing cabinet across the room**. Papers you're not using right now go into the cabinet, freeing desk space. Fetching one back takes a walk. If you keep walking back and forth all day (thrashing), the desk is simply too small.

## How it works inside

- Memory used by programs is either **file-backed** (it came from a file on disk, like program code or cached files, so the kernel can just drop it and re-read it later) or **anonymous** (heap and stack data that exists nowhere else). Only **anonymous** memory needs swap. Topic 093 explains this in depth.
- When free memory runs low, the kernel's **reclaim** process chooses between dropping file cache and swapping anonymous pages. **`vm.swappiness`** biases that choice: higher = swap more willingly; lower = prefer dropping cache. The range is 0–200 on current kernels (RHEL 10). **Low does not mean "never swap".**
- Defaults: the kernel uses **60**, but **tuned profiles** (topic 056) change it. For example, `virtual-guest` sets 30 and `throughput-performance` sets 10.
- `mkswap` writes a **swap signature** (and a UUID) onto the area. `swapon` tells the kernel to start using it. Several swap areas are used by **priority** (higher first); equal priorities are used in parallel.
- A **swap file** must not have holes (it must be fully allocated on disk), because the kernel writes to its blocks directly.

**Sizing guidance (Red Hat, without hibernation):**

| RAM | Swap |
|---|---|
| ≤ 2 GB | 2 × RAM |
| 2–8 GB | = RAM |
| 8–64 GB | At least 4 GB |
| > 64 GB | At least 4 GB, depending on workload |

## Commands

### Look at swap

```bash
swapon --show ; free -h
```
```
NAME      TYPE      SIZE USED PRIO
/dev/dm-1 partition   2G  12M   -2
               total        used        free      shared  buff/cache   available
Mem:           7.5Gi       3.8Gi       302Mi        45Mi       3.4Gi       3.7Gi
Swap:          2.0Gi        12Mi       2.0Gi
```
- `/dev/dm-1` is the `rhel-swap` LV. `PRIO -2` = the automatic priority. 12 MiB used is normal: idle pages parked on disk.

```bash
vmstat 2 3            # the si / so columns: KiB swapped in / out per second (topic 036)
sysctl vm.swappiness  # sysctl reads/writes kernel settings (topic 055)
```
```
vm.swappiness = 30
```

```bash
grep VmSwap /proc/*/status 2>/dev/null | sort -k2 -n | tail -3
```
- Which processes have the most memory in swap.

### Add a swap partition

```bash
sudo fdisk /dev/vdb      # n → +512M → t → swap → w
sudo partprobe /dev/vdb
sudo mkswap /dev/vdb2
```
```
Setting up swapspace version 1, size = 512 MiB (536866816 bytes)
no label, UUID=7b2f0c3e-5d1a-4f8b-9c6e-0a1b2c3d4e5f
```
```bash
sudo swapon /dev/vdb2
echo "UUID=$(sudo blkid -s UUID -o value /dev/vdb2) none swap defaults 0 0" | sudo tee -a /etc/fstab
sudo swapon -a ; swapon --show
```
- fstab swap lines use `none` as the mount point and `swap` as the type (topic 048). `swapon -a` activates everything in fstab, which proves the line works.

### Swap on LVM (easiest to resize)

```bash
sudo lvcreate -n lvswap -L 1G vgdata
sudo mkswap /dev/vgdata/lvswap
echo '/dev/vgdata/lvswap none swap defaults 0 0' | sudo tee -a /etc/fstab
sudo swapon -a
```

### Swap file (no spare disk needed)

```bash
sudo dd if=/dev/zero of=/swapfile bs=1M count=1024    # 1 GiB, fully written (no holes)
sudo chmod 600 /swapfile                               # only root may read it (it can hold secrets!)
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap defaults 0 0' | sudo tee -a /etc/fstab
```
- `fallocate -l 1G /swapfile` is faster and works on modern XFS/ext4. If `swapon` complains about holes, use `dd`.
- Don't put swap files on NFS. Btrfs needs special handling.

### Priorities

```
UUID=…      none swap defaults,pri=10 0 0     ← used first
/swapfile   none swap defaults,pri=5  0 0
```

### Grow or remove

```bash
sudo swapoff /dev/vgdata/lvswap
sudo lvextend -L +1G /dev/vgdata/lvswap
sudo mkswap /dev/vgdata/lvswap        # ⚠️ new UUID: update fstab if it uses UUID=
sudo swapon -a
```
```bash
sudo swapoff /swapfile && sudo sed -i '\|^/swapfile |d' /etc/fstab && sudo rm /swapfile
```
- `swapoff` must pull every page back into RAM, so it fails (or takes a while) if RAM is too full.

### Change swappiness permanently

```bash
sudo sysctl -w vm.swappiness=10                                  # now (until reboot)
echo 'vm.swappiness = 10' | sudo tee /etc/sysctl.d/99-swappiness.conf
sudo sysctl --system                                             # load all settings files
```
- If a tuned profile also sets swappiness, the cleanest permanent override is a custom tuned profile (topic 056).

### Try it
1. Add a 512 MiB swap partition and a 256 MiB swap file, both in fstab, with different priorities. Reboot and check `swapon --show`.
2. Watch `vmstat 1` while running `stress-ng --vm 1 --vm-bytes 90% --timeout 30s` and see `si`/`so` appear.
3. Remove the swap file cleanly.

## Where you'll use it

- **Sizing new servers and VMs:** keep some swap as a safety net, even with lots of RAM.
- **Cloud images** often ship **without** swap; add a swap file if workloads spike.
- **Databases and latency-critical apps:** low swappiness (1–10), but rarely zero swap.
- **Kubernetes nodes:** the kubelet has traditionally **required swap to be off** (or explicitly configured with the NodeSwap feature), because swapping makes memory limits and scheduling unpredictable. On Kubernetes nodes you usually run `swapoff -a` and remove swap from fstab.
- **Incidents:** "slow server" plus constant `si`/`so` = memory pressure; find the memory hog (topics 034, 093).

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `swapon: … read swap header failed` | You forgot `mkswap` | `mkswap DEV` |
| `swapon: … insecure permissions 0644, 0600 suggested` | The swap file is readable by others | `chmod 600 /swapfile` |
| `swapon: swapfile has holes` | It was created sparse | Recreate with `dd` |
| Swap missing after a reboot | An fstab typo, or a stale UUID after `mkswap` | `blkid`; fix fstab; `swapon -a` |
| `swapoff: Cannot allocate memory` | Not enough RAM to take back the swapped pages | Free memory, or add other swap first |
| Sluggish system with high `si`/`so` | Thrashing | More RAM, fix the memory hog, or set memory limits (topic 097) |
| The kubelet won't start | Swap is on | `swapoff -a`, remove swap from fstab (or configure NodeSwap) |

## Quick recap

- Swap = disk overflow for **anonymous** memory pages. Thrashing (constant `si`/`so`) means you need RAM, not more swap.
- Create: partition, LV or file → `mkswap` → `swapon` → fstab `UUID=… none swap defaults 0 0` → `swapon -a`.
- Swap files: write them fully (`dd`), `chmod 600`. Re-running `mkswap` gives a new UUID.
- `vm.swappiness` (0–200) biases swap vs. dropping cache; persist it in `/etc/sysctl.d/` or a tuned profile.

**Interview questions**

1. *What does `vm.swappiness` control?* How willing the kernel is to reclaim anonymous memory by swapping, compared with dropping file cache. Lower values prefer dropping cache; it doesn't disable swap.
2. *Is high swap usage a problem?* Not by itself: idle pages sitting in swap are fine. Continuous swap-in/swap-out (thrashing) is the problem, visible in `vmstat` `si`/`so`.
3. *Why do Kubernetes nodes traditionally disable swap?* Swap makes a pod's memory behaviour and limits unpredictable, so the kubelet historically refused to run with swap on unless explicitly configured.
