# 094 · The Storage I/O Path: From `write()` to the Disk

> **You need first:** [093 · Memory management](093-memory-management.md) (and topics 046–052 storage, 083–091 advanced storage)
> **Next:** [095 · TCP/IP deep dive](095-tcp-ip-deep-dive.md)

---

## What it is

The journey data takes from an application's `write()` call down to the physical disk, and back up for a `read()`, through every kernel layer:

```
 application           write(fd, buf, n)   read()   fsync()   mmap()
 ───────────────────── system call boundary ───────────────────────────────
 VFS                   path lookup (dentry cache), inode cache, permission/SELinux checks
 page cache            file data in RAM: reads served here; writes land here as DIRTY pages
 filesystem            XFS / ext4: block allocation, extents, metadata JOURNAL
 block layer (blk-mq)  requests, merging, I/O scheduler, per-CPU queues
 device mapper         stacked virtual devices: LVM, LUKS (dm-crypt), multipath, VDO, thin
 driver                nvme / virtio_blk / scsi (sd) / iSCSI    (NFS goes over the network instead)
 device                SSD / HDD / virtual disk, with its own volatile write cache
```

| Term | Meaning |
|---|---|
| **VFS** (Virtual File System) | The kernel layer that gives every filesystem (XFS, ext4, NFS, tmpfs, /proc) the same interface |
| **Dirty page** | A page-cache page modified in RAM but not yet written to disk |
| **Writeback** | Kernel flusher threads writing dirty pages to disk |
| **Durability** | Data surviving a crash or power cut |
| **I/O scheduler** | Code in the block layer that may reorder or merge requests |
| **IOPS** | I/O operations per second |
| **Latency** (await) | How long one I/O takes, including time spent queued |

## Why it exists

These common production mysteries are all explained by **where in the stack the data was** when something happened:
- "The disk is slow."
- "Writes are fast, then suddenly freeze."
- "We lost data after a power cut, although the app said it saved."
- "The filesystem went read-only."
- "`%util` says 100%, but the NVMe is idle."

Topics 046–049 built the stack; this topic explains how data flows through it.

## Analogy

Sending a parcel:
- You hand it to the **front desk** (the page cache) and get a receipt **immediately**. That's `write()` returning, but the parcel is still in the building.
- **Couriers** (flusher threads) collect parcels in batches.
- The **sorting office** (block layer) groups parcels going the same way.
- The **regional depots** (device mapper layers) relabel them.
- Finally the parcel reaches the **warehouse** (disk).

`fsync()` is asking the desk "**don't give me the receipt until it's signed for at the warehouse**".

## How it works inside

### VFS caches

The VFS keeps a **dentry cache** (path component → inode lookups, including "negative" entries for names that don't exist, which speeds up `$PATH` searches) and an **inode cache**. Both live in reclaimable kernel **slab** memory. A host with millions of files can show a big `SReclaimable`; that's normal (topic 093).

### Reads

1. `read()` → VFS → page cache lookup.
2. **Hit:** copy from RAM; no I/O.
3. **Miss:** the filesystem maps the file offset to disk blocks; the block layer issues a read; the process sleeps in **D** state (topic 033) until it completes.
4. **Readahead:** on sequential reads the kernel fetches ahead (`/sys/block/DEV/queue/read_ahead_kb`).

### Writes and dirty pages

`write()` copies data into the page cache, marks the pages **dirty**, and **returns immediately. The data is not on disk yet.** Flusher threads write it back later:

| Tunable (kernel default) | Meaning |
|---|---|
| `vm.dirty_background_ratio` (10) | Above 10% of available memory dirty → start background writeback |
| `vm.dirty_ratio` (20; **30** on RHEL VMs and servers, set by tuned's `virtual-guest`/`throughput-performance` profiles) | Above this share → **the writing process itself is throttled** until writeback catches up |
| `vm.dirty_expire_centisecs` (3000 = 30 s) | Dirty data older than this is written at the next flush |
| `vm.dirty_writeback_centisecs` (500 = 5 s) | How often the flushers wake |
| `vm.dirty_bytes`, `vm.dirty_background_bytes` | Absolute alternatives (better on large-RAM hosts) |

This is the classic "**fast, then freezes**": the first gigabytes go into RAM at memory speed; once dirty data passes `dirty_ratio`, writers slow to disk speed. Check your real values with `sysctl -a | grep dirty` and `tuned-adm active` (topic 056).

### Durability

| Mechanism | Guarantee |
|---|---|
| `fsync(fd)` | File data **and** metadata are on stable storage when it returns (the kernel also tells the device to flush its own cache) |
| `fdatasync(fd)` | Data, plus only the metadata needed to read it back (cheaper) |
| `O_SYNC` / `O_DSYNC` | Every `write()` behaves as if followed by fsync / fdatasync |
| `O_DIRECT` | Bypasses the page cache (databases with their own caches use it). **Not** a durability guarantee by itself |
| `sync` (command) | Flushes all dirty data system-wide |

**Journaling protects the filesystem's consistency, not your data.** After a crash, XFS replays its log so its **metadata** is consistent; ext4 (`data=ordered`) also makes sure metadata never points at stale blocks. **Neither guarantees that data written without `fsync()` survived.**

Databases and package managers call `fsync()` at the right moments. A program that rewrites a config file **in place** can leave an empty file after a crash. The safe pattern is: write a temp file in the same directory → `fsync` → `rename()` it over the old name. Rename is **atomic**: readers see either the old file or the new one, never half (topic 045).

### Block layer and schedulers

Modern Linux uses **blk-mq**: per-CPU software queues mapped onto hardware queues (NVMe has many). An I/O scheduler may reorder or merge requests:

| Scheduler | Best for |
|---|---|
| `none` | NVMe and fast SSDs, which schedule internally: the usual NVMe default |
| `mq-deadline` | General purpose; bounds latency: the usual default for SATA/SAS/virtio |
| `bfq` | Fairness between processes; desktops; slow HDDs (more CPU) |
| `kyber` | Latency targets on fast devices |

Change schedulers only after measuring; the defaults are sensible.

### Device mapper stacks

LVM, LUKS, multipath, thin pools and VDO are all **device-mapper targets**: virtual devices (`/dev/dm-N`) defined by **tables** that map sector ranges onto other devices. A linear LV is literally a dm-linear table built from extent ranges. Each layer adds a little latency and its own failure mode (thin pool full, missing key, all paths down). When I/O hangs, find **which layer** is waiting.

## Commands

### Map your stack

```bash
lsblk -o NAME,TYPE,FSTYPE,MOUNTPOINTS
sudo dmsetup ls --tree
sudo dmsetup table rhel-root
```
```
NAME          TYPE FSTYPE      MOUNTPOINTS
vda           disk
├─vda1        part vfat        /boot/efi
├─vda2        part xfs         /boot
└─vda3        part LVM2_member
  ├─rhel-root lvm  xfs         /
  └─rhel-swap lvm  swap        [SWAP]
rhel-swap (253:1)
 └─ (252:3)
rhel-root (253:0)
 └─ (252:3)
0 35643392 linear 252:3 4196352
```
- The table says: sectors 0–35,643,391 of `rhel-root` map **linearly** onto device 252:3 (`vda3`), starting at its sector 4,196,352. That's all an LV is.

### Buffered vs synced writes

```bash
cd /var/tmp
dd if=/dev/zero of=t bs=1M count=300 ; grep -E '^(Dirty|Writeback):' /proc/meminfo
dd if=/dev/zero of=t bs=1M count=300 conv=fdatasync
dd if=/dev/zero of=t bs=1M count=300 oflag=direct
rm t
```
```
314572800 bytes (315 MB, 300 MiB) copied, 0.17 s, 1.8 GB/s       ← landed in RAM
Dirty:            307200 kB                                     ← ≈300 MiB not yet on disk
Writeback:             0 kB
314572800 bytes (315 MB, 300 MiB) copied, 0.40 s, 779 MB/s      ← includes flushing to the device
314572800 bytes (315 MB, 300 MiB) copied, 0.22 s, 1.4 GB/s      ← bypasses the cache
```
- Benchmarks without `conv=fdatasync`, `oflag=direct`, or a proper tool measure **RAM, not storage**.

### Scheduler and queue settings

```bash
cat /sys/block/vda/queue/scheduler
cat /sys/block/vda/queue/{rotational,nr_requests,read_ahead_kb}
```
```
[none] mq-deadline kyber bfq
0
256
4096
```
- Brackets mark the active scheduler. `rotational 0` = not a spinning disk. Change at runtime with `echo mq-deadline | sudo tee /sys/block/sdb/queue/scheduler`; persist with a udev rule or tuned's `[disk] elevator=` (topic 056).

### Measure I/O

```bash
iostat -xz 1 3          # read the 2nd and later samples (the first is "since boot")
```
```
Device   r/s    w/s   rkB/s    wkB/s  r_await w_await aqu-sz  %util
vda     0.00 1450.00   0.00 185600.0    0.00    2.10   3.05   97.20
dm-0    0.00 1450.00   0.00 185600.0    0.00    2.30   3.34   97.20
```

| Column | Meaning | Rule of thumb |
|---|---|---|
| `r/s`, `w/s` | IOPS | Compare with what the device can do |
| `rkB/s`, `wkB/s` | Throughput | |
| `r_await`, `w_await` | Average ms per request, **queue time + service time** | SSD: under 1 to a few ms; HDD: about 5–15 ms. Rising = trouble |
| `aqu-sz` | Average queue length (≈ IOPS × await) | Sustained > 1 on a single HDD = saturated |
| `%util` | Share of time at least one request was in flight | Meaningful for HDDs. **NVMe can show 100% while far from saturated** |

- `dm-0` (the LV) and `vda` (the disk) have similar await, so the device-mapper layer adds almost nothing here. If `dm-N` were much slower than its disk, suspect that layer (a thin pool, dm-crypt CPU cost).

```bash
pidstat -d 1                 # which process does the I/O
sudo cat /proc/1234/io       # one process's cumulative read_bytes / write_bytes
vmstat 1                     # b = tasks blocked on I/O; wa = iowait %
sudo fio --name=randread --rw=randread --bs=4k --size=1G --iodepth=32 --ioengine=libaio --direct=1 --filename=/var/tmp/fio.test
```
- `fio` is the standard realistic benchmark (random/sequential, block size, queue depth).

### Try it
1. Run the three `dd` variants with `watch -n1 "grep -E '^(Dirty|Writeback)' /proc/meminfo"` in another terminal. Then run `sync` and watch `Dirty` drop.
2. Map your VM's stack with `lsblk` and `dmsetup table` and explain every line.
3. Lab only: `sync; echo 3 | sudo tee /proc/sys/vm/drop_caches`, then time `cat bigfile > /dev/null` twice and explain why the second run is faster.
4. Run `fio` on a data LV while `iostat -xz 1` runs; compare the dm device and its physical disk.

## Where you'll use it

- **Databases** (PostgreSQL, MySQL, etcd) depend on `fsync` latency. **etcd**, the brain of Kubernetes, is famously sensitive to slow disk fsync: its "slow fdatasync" warnings and leader elections often trace back to the storage path.
- **Node disk pressure in Kubernetes:** slow I/O, full disks and evictions.
- **Cloud volumes** have IOPS and throughput caps. `iostat` await rising at exactly the cap's IOPS = you hit the provisioned limit.
- **Benchmarking and capacity planning:** `fio`, never plain `dd`.

## When it breaks

| Event | What you see | Meaning / action |
|---|---|---|
| Device I/O error | `dmesg`: `I/O error, dev sdb, sector …` | Hardware or path problem: SMART (`smartctl -a`), cables, SAN, multipath |
| ext4 error | `EXT4-fs error …`, maybe `Remounting filesystem read-only` | Depends on the `errors=` policy (`continue`, `remount-ro`, `panic`; see `tune2fs -l`). A journal abort always forces read-only. Fix the cause, unmount, `e2fsck` (topic 051) |
| XFS shutdown | `XFS (dm-3): … Filesystem has been shut down`; every access gives `Input/output error` | Unmount, fix the storage, `xfs_repair` (topic 051) |
| Hung tasks | `task X blocked for more than 120 seconds`; processes in **D** | Storage or NFS server not responding; find the device or mount |
| Thin pool / VDO full | Writes hang or fail while `df` shows space | Extend the pool (topics 085, 090) |
| Writeback storms | `Dirty` huge; applications stall periodically | Lower the `dirty_*` settings (or use `dirty_bytes`), faster storage |
| No space / no inodes | `ENOSPC` | `df -h`, `df -i`, `lsof +L1` (topic 006) |

## Quick recap

- app → syscall → **VFS** → **page cache** → **filesystem** (journal) → **block layer** (scheduler) → **device mapper** (LVM/LUKS/multipath) → driver → device.
- `write()` returning ≠ on disk. Dirty pages are flushed later (`dirty_background_ratio` 10, `dirty_ratio` 20 (30 under tuned), 30 s expiry). **`fsync()`** for durability; temp file + fsync + `rename()` for atomic updates.
- Journaling = metadata consistency, not data survival.
- Schedulers: `none` (NVMe), `mq-deadline` (default elsewhere). `dmsetup ls --tree`/`table` show the stack.
- Measure with `iostat -xz 1` (await, aqu-sz; `%util` misleads on NVMe), `pidstat -d`, `fio`.

**Interview questions**

1. *Does a successful `write()` mean the data is on disk?* No. It's only in the page cache; it reaches disk later via writeback, or when the application calls `fsync()`/`fdatasync()` (or uses `O_SYNC`).
2. *Why do writes run fast and then suddenly stall?* Dirty pages accumulate in RAM until `vm.dirty_ratio` is reached; then the writing process is throttled to the speed the storage can flush.
3. *What does `%util` = 100% mean on an NVMe drive?* Only that at least one request was always in flight. NVMe handles many requests in parallel, so look at await and queue size before calling it saturated.
