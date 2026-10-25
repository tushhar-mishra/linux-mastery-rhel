# The Storage I/O Path: From `write()` to the Disk

> **Track:** **[Internals]** · **[Production Practice]** · **Verified:** demos on a RHEL 10.2 UBI container (kernel 6.12); throughput numbers are from a lab VM and only illustrate relative differences
> **Prerequisites:** [Disks & partitioning](disks-and-partitioning.md) · [Filesystems & mkfs](filesystems-and-mkfs.md) · [LVM fundamentals](lvm-fundamentals.md) · [Memory management (page cache)](../processes-and-resource-management/memory-management.md) · [Processes & system calls (fds)](../processes-and-resource-management/processes-and-system-calls.md)
> **Next:** [Resource monitoring (iostat)](../processes-and-resource-management/system-resource-monitoring.md#4-disk-iostat) · [Filesystem check & repair](filesystem-check-and-repair.md) · [Performance & observability](../advanced-rhel-and-career-notes/performance-and-observability.md)

## 1. Why This Matters

"The disk is slow", "writes are fast then suddenly stall", "we lost data after a power cut although the app said it saved", "the filesystem went read-only": each is explained by **where in the stack** the data was when something happened. RHCSA teaches you to build the stack (partition → LVM → filesystem → mount); this note explains how data flows through it.

## 2. The Stack

```
 application           write(fd, buf, n)   read()   fsync()   mmap()
 ───────────────────── system call boundary ───────────────────────────────
 VFS                   path lookup (dentry cache), inode cache, permission/SELinux checks, file operations
 page cache            file data in RAM: reads served here; writes land here as DIRTY pages
 filesystem            XFS / ext4: block allocation, extents, metadata JOURNAL (log)
 block layer (blk-mq)  bios → requests, merging, I/O scheduler (none / mq-deadline / bfq / kyber), per-CPU queues
 device mapper         stacked virtual devices: LVM (dm-linear, thin, raid), LUKS (dm-crypt), multipath, VDO
 driver                nvme / virtio_blk / scsi (sd) / iSCSI / NFS (network instead of block)
 device                SSD/HDD/virtual disk, with its own volatile write cache
```

Each layer can be the bottleneck, and each has its own tools:

| Layer | Look with |
|---|---|
| VFS / caches | `slabtop` (dentry, inode caches), `/proc/meminfo` (`Cached`, `Dirty`) |
| Filesystem | `xfs_info`, `tune2fs -l`, `dmesg` errors, `df -h`, `df -i` |
| Block layer | `iostat -xz 1`, `/sys/block/DEV/queue/*`, `cat /proc/diskstats` |
| Device mapper | `lsblk`, `dmsetup ls --tree`, `dmsetup table` |
| Device | `smartctl -a` (smartmontools), vendor tools, `nvme smart-log` (nvme-cli) |

## 3. VFS: One Interface for Every Filesystem

The **Virtual File System** gives every filesystem (XFS, ext4, VFAT, NFS, tmpfs, procfs, sysfs) the same system-call interface. It keeps two key caches:

- **dentry cache**: path-component → inode lookups (also *negative* entries for names that don't exist, which speeds up repeated failed lookups such as `$PATH` searches).
- **inode cache**: in-memory inodes.

Both live in kernel **slab** memory and are reclaimable. A system with millions of files can show a very large `SReclaimable`; that's normal.

## 4. Reads

1. `read()` → VFS → page cache lookup.
2. **Hit:** copy from RAM (no I/O).
3. **Miss:** the filesystem maps the file offset to disk blocks; the block layer issues a read; the process sleeps in **D** state until it completes (a **major fault** for mmap'd files).
4. **Readahead:** on sequential reads the kernel fetches ahead (`blockdev --getra /dev/vda` in 512-byte sectors; `/sys/block/DEV/queue/read_ahead_kb`; tuned can set `readahead`).

## 5. Writes, Dirty Pages & Durability

### 5.1 Buffered writes (the default)

`write()` copies data into the page cache, marks the pages **dirty**, and returns **immediately**. The data is **not on disk yet**. Kernel **flusher threads** write it back later:

| Tunable (kernel default) | Meaning |
|---|---|
| `vm.dirty_background_ratio` (10) | When dirty data exceeds 10% of available memory, start background writeback |
| `vm.dirty_ratio` (20) | Above 20%, **the writing process itself is throttled** until writeback catches up |
| `vm.dirty_expire_centisecs` (3000 = 30 s) | Dirty data older than this is written at the next flush |
| `vm.dirty_writeback_centisecs` (500 = 5 s) | How often flusher threads wake up |
| `vm.dirty_bytes`, `vm.dirty_background_bytes` | Absolute alternatives to the ratios (useful on large-RAM hosts) |

This explains the classic pattern "**writes are fast, then the app freezes**": the first gigabytes go to RAM at memory speed; once dirty data passes `dirty_ratio`, writers stall at disk speed.

Verified demo, 300 MiB in a lab VM (absolute numbers vary):

```
dd if=/dev/zero of=t bs=1M count=300               → 1.8 GB/s   (lands in page cache)
grep Dirty /proc/meminfo                           → Dirty: 307200 kB   (≈ 300 MiB not yet on disk)
dd … conv=fdatasync                                → 779 MB/s   (includes flushing to the device)
dd … oflag=direct                                  → 1.4 GB/s   (bypasses the page cache)
```

That's why benchmarks without `conv=fdatasync`/`oflag=direct` (or a proper tool like `fio`) measure RAM, not storage.

### 5.2 Making data durable

| Mechanism | Guarantee |
|---|---|
| `fsync(fd)` | File data **and** metadata are on stable storage when it returns (the kernel also tells the device to flush its write cache) |
| `fdatasync(fd)` | Data plus only the metadata needed to read it back (cheaper) |
| `O_SYNC` / `O_DSYNC` | Every `write()` behaves as if followed by fsync/fdatasync |
| `O_DIRECT` | Bypass the page cache (aligned I/O); used by databases with their own caches. **Not** by itself a durability guarantee |
| `sync` (command) | Flush all dirty data system-wide |
| Mount option `sync` | Every write synchronous: very slow; rarely appropriate |

**Journaling protects filesystem consistency, not your data.** After a crash, XFS replays its log so its **metadata** is consistent; ext4 (default `data=ordered`) guarantees metadata won't point at stale blocks. Neither guarantees that data written without `fsync()` survived. Applications (databases, package managers) that need durability call `fsync()` at the right moments. A program that writes a new config by truncating and rewriting in place can leave an empty file after a crash; the safe pattern is: write a temp file → `fsync` → `rename()` over the old name (rename is atomic).

## 6. The Block Layer & I/O Schedulers

Modern Linux uses **blk-mq**: per-CPU software queues mapped to hardware queues (NVMe has many hardware queues). An **I/O scheduler** can reorder/merge requests:

| Scheduler | Best for |
|---|---|
| `none` | NVMe and fast SSDs (the device does its own scheduling); typical default for NVMe |
| `mq-deadline` | General purpose; bounds latency; typical default for SATA/SAS/virtio |
| `bfq` | Fairness between processes, desktops, slow HDDs (higher CPU cost) |
| `kyber` | Latency targets on fast devices |

```bash
cat /sys/block/vda/queue/scheduler                 # [none] mq-deadline kyber   ← brackets = active
cat /sys/block/vda/queue/{rotational,nr_requests,read_ahead_kb}
echo mq-deadline > /sys/block/sdb/queue/scheduler  # runtime only; persist with a udev rule or tuned [disk] elevator=
```

Change schedulers only with measurements; the defaults are sensible.

## 7. Device Mapper: How LVM, LUKS and Multipath Stack

Device mapper creates virtual block devices (`/dev/dm-N`) from **tables** that map ranges of sectors onto other devices:

```bash
lsblk                                   # tree: vdb → vdb1 → vg-lv (lvm) → crypt (crypt) …
dmsetup ls --tree                       # same relationships from device mapper's view
dmsetup table vgdata-lvweb              # e.g. "0 2097152 linear 252:17 2048" = sectors 0–2097151 map to device 252:17 from sector 2048
dmsetup info -c                         # names, major:minor, open count
```

An LVM linear LV is literally a dm-linear table built from PE ranges; a snapshot adds a dm-snapshot target; LUKS adds dm-crypt; multipath adds dm-multipath. Every layer adds a little latency and its own failure modes (thin pool full, missing key, all paths down). When I/O hangs, find **which layer** is waiting: `iostat -x` shows each `dm-N` and its underlying device separately; a `dm-N` with high latency on top of a device with low latency points at the dm layer (e.g., thin pool or dm-crypt CPU cost).

## 8. Measuring I/O

`iostat -xz 1` (sysstat), read from the second sample:

| Column | Meaning | Rule of thumb |
|---|---|---|
| `r/s`, `w/s` | IOPS | Compare with the device's capability |
| `rkB/s`, `wkB/s` | Throughput | |
| `r_await`, `w_await` | Average ms per request, **queue time + service time** | Rising = latency problem (SSD: sub-ms to a few ms; HDD: ~5–15 ms) |
| `aqu-sz` | Average queue length ≈ IOPS × await (Little's law) | Sustained > 1 on a single-queue HDD = saturation |
| `%util` | Share of time the device had at least one request in flight | Meaningful for HDDs; NVMe can be "100%" while far from saturated |

```bash
pidstat -d 1                 # which process does the I/O (kB_rd/s, kB_wr/s, iodelay)
cat /proc/PID/io             # cumulative read_bytes/write_bytes of one process
iotop                        # interactive per-process I/O view (install if available)
vmstat 1                     # b (blocked tasks) and wa (iowait)
fio --name=randread --rw=randread --bs=4k --size=1G --iodepth=32 --ioengine=libaio --direct=1   # realistic benchmark (fio package) [Advanced]
```

## 9. Failure Modes

| Event | What you see | Meaning / action |
|---|---|---|
| Device I/O error | `dmesg`: `I/O error, dev sdb, sector …`, `blk_update_request` | Hardware/path problem; check SMART, cables, SAN, multipath |
| ext4 error | `EXT4-fs error …`, often followed by `Remounting filesystem read-only` | What happens depends on the filesystem's error policy (`tune2fs -l DEV \| grep -i 'errors behavior'`, or the `errors=` mount option: `continue`, `remount-ro`, `panic`). A freshly made ext4 reports `Errors behavior: Continue` (verified with e2fsprogs 1.47, RHEL 10 family); a journal abort still forces read-only. Many hardening guides set `errors=remount-ro`. Fix the cause, unmount, `e2fsck` |
| XFS shutdown | `XFS (dm-3): Corruption detected … Filesystem has been shut down` / `Input/output error` on every access | Unmount, fix storage, `xfs_repair` ([repair](filesystem-check-and-repair.md)) |
| Hung tasks | `task X blocked for more than 120 seconds` (`kernel.hung_task_timeout_secs`); processes in **D** | Storage or NFS server not responding; find the device/mount |
| Thin pool / VDO full | Writes hang or fail while `df` shows space | Extend the pool ([thin provisioning](lvm-thin-provisioning-and-striping.md)) |
| Writeback storm | `Dirty` huge, apps stall periodically | Lower `dirty_*` (or use `dirty_bytes`), faster storage, spread writes |
| No space / no inodes | `ENOSPC` | `df -h`, `df -i`; deleted-but-open files (`lsof +L1`) |

## 10. Labs

1. **Buffered vs synced writes.** Repeat §5.1 with `watch -n1 "grep -E '^(Dirty|Writeback)' /proc/meminfo"` in another terminal. Then run `sync` and watch `Dirty` drop.
2. **Map your stack.** On your RHEL VM: `lsblk -o NAME,TYPE,FSTYPE,MOUNTPOINTS`, `dmsetup ls --tree`, `dmsetup table` for the root LV. Explain each line.
3. **Read cache.** `echo 3 > /proc/sys/vm/drop_caches` (lab only), then time `cat bigfile > /dev/null` twice. Explain why the second run is faster.
4. **Watch latency.** Run `fio` (or `dd oflag=direct`) on a data LV while `iostat -xz 1` runs. Identify the dm device and its physical device and compare their `await`.
5. **Atomic config update.** Write a script that updates a file using `mktemp` in the same directory + `mv` (rename) and explain why it's crash-safe ([robust scripts](../bash-scripting-and-automation/robust-scripts.md)).

## 11. Interview Questions

| Question | Answer |
|---|---|
| Does `write()` returning success mean the data is on disk? | No, only in the page cache; `fsync()` (or O_SYNC) is needed for durability. |
| What does journaling guarantee? | Filesystem metadata consistency after a crash, not the survival of unsynced data. |
| Why are writes fast and then suddenly slow? | Dirty pages accumulate in RAM until `dirty_ratio`, after which writers are throttled to disk speed. |
| What does `%util` 100% mean on NVMe? | Only that a request was always in flight; NVMe handles many in parallel, so check `await`/`aqu-sz`. |
| What's the I/O scheduler for NVMe and why? | Usually `none`: the device's internal parallelism and queues make kernel reordering unnecessary. |
| How do LVM, LUKS and multipath relate? | All are device-mapper targets stacked into `/dev/dm-N` devices; `dmsetup ls --tree` shows the stack. |
| Why benchmark with `oflag=direct`/`fio`? | Otherwise you measure the page cache (RAM). |
| What's a safe way to replace a file atomically? | Write a temp file in the same filesystem, fsync it, `rename()` it over the original. |

## 12. Quick Revision

```
app → syscall → VFS (dentry/inode cache) → page cache → FS (XFS/ext4 journal) → blk-mq (+scheduler) → dm (LVM/LUKS/mpath) → driver → device
reads: cache hit/miss, readahead · writes: dirty pages, flusher threads, dirty_background_ratio 10 / dirty_ratio 20 / expire 30 s
durability: fsync / fdatasync / O_SYNC · O_DIRECT bypasses cache · journal = metadata consistency, not data
schedulers: none (NVMe) · mq-deadline · bfq · kyber — /sys/block/DEV/queue/scheduler
dmsetup ls --tree / table · iostat -xz 1 (await, aqu-sz; %util misleading on NVMe) · pidstat -d · /proc/PID/io · fio
failures: I/O error → remount-ro / XFS shutdown · hung task 120 s · thin pool full · ENOSPC vs inodes
```

## 13. Cross-References

- [Memory management (page cache, Dirty)](../processes-and-resource-management/memory-management.md) · [Resource monitoring (iostat, pidstat)](../processes-and-resource-management/system-resource-monitoring.md)
- [Filesystems & mkfs](filesystems-and-mkfs.md) · [Filesystem check & repair](filesystem-check-and-repair.md) · [LVM fundamentals](lvm-fundamentals.md) · [LUKS](luks-encryption.md) · [Multipath](../system-services-and-shared-storage/multipath.md)
- [tuned (`[disk]` readahead, elevator)](../containers-and-virtualization/tuned-profiles.md) · [Performance & observability (biolatency)](../advanced-rhel-and-career-notes/performance-and-observability.md)
