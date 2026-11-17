# 047 · Filesystems: XFS, ext4, VFAT and mkfs

> **You need first:** [046 · Disks and partitions](046-disks-and-partitions.md)
> **Next:** [048 · Mounting and fstab](048-mounting-and-fstab.md)

---

## What it is

A **filesystem** is the structure written onto a block device that turns raw blocks into **files and directories**: inodes, directories, free-space maps and a journal. **`mkfs`** ("make filesystem") writes a brand-new, empty filesystem onto a partition or volume.

| Filesystem | Where you'll see it |
|---|---|
| **XFS** | **RHEL's default** for `/`, data and large volumes |
| **ext4** | **Ubuntu/Debian's default**; fully supported on RHEL; can be shrunk (offline) |
| **VFAT** (FAT32) | The EFI System Partition (`/boot/efi`), USB sticks, swapping files with Windows |
| **swap** | Not a filesystem: a raw area for paging memory (topic 050) |
| Btrfs | Fedora's and openSUSE's default; **not** supported on RHEL |
| tmpfs | A filesystem that lives in RAM (`/run`, `/dev/shm`) |
| iso9660 | CD/DVD and `.iso` images |

## Why it exists

A disk only knows "block number 7,340,032". People and programs want `/var/log/messages`. The filesystem keeps track of which blocks belong to which file, who owns it, its permissions and timestamps, and where free space is. It also keeps all of that **consistent after a crash**.

## Analogy

A partition is an **empty warehouse**. `mkfs` installs the **shelving, the aisle numbers and the inventory book** (the catalogue of which box is on which shelf). Different filesystems are different shelving systems: XFS is built for huge warehouses with many forklifts working at once; ext4 is the dependable all-rounder; VFAT is simple shelving that every visitor (Windows, cameras, firmware) understands, but with no locks on any shelf (no Linux permissions).

## How it works inside

### The building blocks

- **Superblock**: the master record: size, block size, features, state, UUID, label. Copies are kept in several places in case one is damaged.
- **Inodes** (topic 008): one per file, holding its metadata and pointers to data. ext4 creates a **fixed number** at `mkfs` time; XFS creates them **as needed**.
- **Extents**: instead of listing every single block of a file, modern filesystems record ranges ("blocks 1000–1999"). Faster, and less fragmentation.
- **Delayed allocation**: blocks are chosen only when data is actually flushed to disk, so files end up contiguous. (Both XFS and ext4 do this.)
- **XFS allocation groups**: XFS splits a volume into independent regions that can be worked on **in parallel**, which is why it scales well on big, busy systems.

### Journaling: crash safety

Changing a file touches several structures (inode, directory, free-space map). If power fails halfway, they disagree. A **journal** fixes this:
1. The filesystem first writes a description of the change to the **journal** (a log area).
2. Then it applies the change to the real structures.
3. After a crash, at the next mount, it **replays** the journal and finishes or discards the half-done changes, in **seconds** instead of scanning the whole disk.

XFS, ext3 and ext4 journal (by default only **metadata**: the structures, not your file contents). ext2 and VFAT don't journal at all. Topic 094 explains how this relates to your data actually reaching the disk (`fsync`).

### Choosing

| | **XFS** | **ext4** | **VFAT** |
|---|---|---|---|
| Default on | RHEL | Ubuntu, Debian | EFI partition, USB sticks |
| Grow | Online (`xfs_growfs`, while mounted) | Online (`resize2fs`) | — |
| **Shrink** | **Never** | Offline only (unmounted) | — |
| Max file size | 8 EiB | 16 TiB | **4 GiB** |
| Inodes | Created as needed | Fixed at creation | — |
| Linux permissions/owners | Yes | Yes | **No** (set at mount time for all files) |
| Label length | 12 chars | 16 chars | 11 chars (stored uppercase) |

**Rule of thumb:** XFS on RHEL; ext4 if you might ever need to **shrink**, or on Ubuntu; VFAT only where other systems must read it.

### What mkfs does

It writes new superblocks, inode tables (ext4), allocation-group headers (XFS), an empty root directory and a journal, and generates a new **UUID**. Old data blocks are **not** erased, just no longer referenced. **mkfs on the wrong device destroys that filesystem's structure**, which in practice means data loss.

## Commands

```bash
lsblk -f /dev/vdb          # ALWAYS check: right device? any existing FSTYPE?
```

### Create

```bash
sudo mkfs.xfs -L DATA /dev/vdb1
```
```
meta-data=/dev/vdb1              isize=512    agcount=4, agsize=65536 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=1, sparse=1, rmapbt=1
         =                       reflink=1    bigtime=1 inobtcount=1 nrext64=1
         =                       exchange=0   metadir=0
data     =                       bsize=4096   blocks=262144, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0, ftype=1, parent=0
log      =internal log           bsize=4096   blocks=16384, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
         =                       rgcount=0    rgsize=0 extents
         =                       zoned=0      start=0 reserved=0
```
- `agcount=4`: 4 allocation groups. `bsize=4096`: 4 KiB blocks. `crc=1`: metadata checksums (detect corruption). `reflink=1`: supports instant copy-on-write file copies (`cp --reflink`). `log=internal`: the journal lives inside the filesystem.

```bash
sudo mkfs.ext4 -L LOGS /dev/vdb2
sudo mkfs.vfat -F 32 -n USBDATA /dev/vdb3     # needs the dosfstools package
sudo mkfs -t ext4 /dev/vdb2                    # generic front-end, same thing
```
- If a device already has a filesystem, `mkfs.xfs` refuses unless you add `-f`. **Read that warning**; it's your last safety net.

```bash
sudo blkid /dev/vdb1
```
```
/dev/vdb1: LABEL="DATA" UUID="5f1c2e7a-0d4b-4b8e-9a63-2a8c1e4d9f10" BLOCK_SIZE="512" TYPE="xfs" PARTLABEL="data" PARTUUID="a1b2c3d4-..."
```
- The **UUID** (filesystem) is what you'll put in `/etc/fstab` (topic 048). `PARTUUID` belongs to the partition, not the filesystem.

### Labels

| | ext2/3/4 | XFS | VFAT |
|---|---|---|---|
| At creation | `mkfs.ext4 -L NAME` | `mkfs.xfs -L NAME` | `mkfs.vfat -n NAME` |
| Change later | `e2label DEV NAME` (even while mounted) | `xfs_admin -L NAME DEV` (**unmounted**) | `fatlabel DEV NAME` |
| View | `e2label DEV` | `xfs_admin -l DEV` | `fatlabel DEV` |

### ext4 tools

```bash
sudo tune2fs -l /dev/vdb2 | grep -E 'volume name|Block count|Reserved block count|Inode count'
```
```
Filesystem volume name:   LOGS
Inode count:              131072
Block count:              524288
Reserved block count:     26214
```
- **Reserved blocks** (5% by default) are kept for root only, so a full disk doesn't lock out the admin or crash system services. On big data volumes you can lower it: `sudo tune2fs -m 1 /dev/vdb2`.
- `dumpe2fs -h DEV` shows the same header. `resize2fs DEV` grows the filesystem to fill its device (topic 049). `e2fsck -f DEV` checks it (**unmounted**, topic 051).

### XFS tools

```bash
xfs_info /data               # geometry of a mounted XFS (by mount point)
sudo xfs_admin -l /dev/vdb1  # show label (-u: show UUID)
sudo xfs_growfs /data        # grow to fill the device, while mounted (topic 049)
sudo xfs_repair -n /dev/vdb1 # check only, UNMOUNTED (topic 051)
```

### Which filesystems does this kernel support?

```bash
grep -v nodev /proc/filesystems
```
```
	xfs
	fuseblk
	vfat
	ext3
	ext2
	ext4
```
- Only filesystems whose driver is **loaded right now** are listed. Just after boot this machine showed only `xfs`, `fuseblk` and `vfat`; the `ext*` lines appeared after an ext4 filesystem was mounted, because mounting loads the module automatically (topic 055). So "not in this list" doesn't mean "not supported".

### Cloned disks: duplicate UUIDs

If you clone a disk or VM image, both copies have the **same filesystem UUID**. XFS refuses to mount a second filesystem with a UUID already mounted (`Filesystem has duplicate UUID … can't mount`). Generate a new one:
```bash
sudo xfs_admin -U generate /dev/vdc1     # XFS (unmounted)
sudo tune2fs -U random /dev/vdc2         # ext4
```

### Try it
1. On `vdb`, create three partitions and put XFS (label DATA), ext4 (label LOGS) and VFAT (label USB) on them. Check with `lsblk -f`.
2. Try `mkfs.ext4` on the XFS partition: notice that it warns. Answer `n`.
3. Run `tune2fs -l` on the ext4 one and find the reserved block count.
4. Change the ext4 label with `e2label`, and the XFS label with `xfs_admin` (it must be unmounted).

**Check your work:** on your lab VM, from the notes folder, run `sudo ./checks/check 047` for every step, or `sudo ./checks/check 047 STEP` for one (topic 002 shows how to get the notes there).

## Where you'll use it

- **Every new disk or volume:** `mkfs`, then mount (next topic).
- **Choosing a filesystem for a database or log volume:** XFS on RHEL; ext4 when shrinking might be needed.
- **Containers:** Podman/Docker's `overlay` storage works on XFS only if it was created with `ftype=1` (the default for years); `xfs_info` shows it.
- **Kubernetes:** a PersistentVolume's `fsType: xfs` or `ext4` tells the storage driver which `mkfs` to run the first time the volume is used.
- **Cloud images:** cloned images all share a UUID until regenerated; another reason to mount by UUID carefully.

## When it breaks

| Message / symptom | Cause | Fix |
|---|---|---|
| `mkfs.xfs: … appears to contain an existing filesystem` | An old signature exists | Confirm it's the right device, then add `-f` |
| `… is mounted; will not make a filesystem here!` | The device is in use | Unmount first, and double-check it's really the target |
| `mkfs.vfat: command not found` | Package missing | `dnf install dosfstools` |
| `xfs_admin: … contains a mounted filesystem` | XFS label change while mounted | Unmount first |
| `wrong fs type, bad option, bad superblock` when mounting | Wrong type, no filesystem, or damage | `blkid DEV`, `dmesg`; repair (topic 051) |
| `Filesystem has duplicate UUID` (XFS) | A cloned disk | `xfs_admin -U generate` |
| Want to make XFS smaller | Not possible | Back up, recreate smaller, restore |
| `df` shows less free space than expected on ext4 | The 5% reserved for root | `tune2fs -l`; `tune2fs -m` |

## Quick recap

- A filesystem turns blocks into files: superblock, inodes, extents, **journal** (fast crash recovery).
- RHEL default **XFS** (grow online, never shrink); Ubuntu default **ext4** (grow online, shrink offline); **VFAT** for EFI/USB (no Linux permissions, 4 GiB file limit).
- `mkfs.xfs -L`, `mkfs.ext4 -L`, `mkfs.vfat -n`; check with `blkid`/`lsblk -f`. `mkfs` doesn't erase old data, but destroys the old structure.
- Tools: `xfs_info`, `xfs_admin`, `xfs_growfs`; `tune2fs`, `e2label`, `resize2fs`.

**Interview questions**

1. *What is journaling?* The filesystem writes a description of each metadata change to a log before applying it, so after a crash it can replay or discard incomplete changes in seconds instead of checking the whole disk.
2. *Can you shrink XFS?* No. Back up, recreate the filesystem smaller, and restore. ext4 can be shrunk, but only while unmounted.
3. *Why does ext4 show less free space than size minus used?* 5% of blocks are reserved for root by default, so system services and the admin can still work when users fill the disk.

**Scenario question** (answer out loud first, then compare)

> *"You need a filesystem for a new volume that will hold logs now but may need to shrink later. XFS or ext4? Defend the choice."*

**Model answer:**
1. **XFS** (RHEL's default) is excellent for large files and parallel I/O, and it grows online, but it **can never shrink**.
2. **ext4** grows online and **can shrink** (offline, with `resize2fs` or `lvreduce -r`).
3. If shrinking is a real requirement, choose ext4. Otherwise XFS on LVM, sized modestly and grown when needed, avoids the problem: it's easier to grow later than to shrink.
4. Either way, put it on LVM so growing is one command, and label it (`-L`) so it's easy to identify.

**Likely follow-ups:**
- *ext4 shows less free space than expected. Why?* 5% of blocks are reserved for root (`tune2fs -m` changes it).
- *What does `mkfs` do to the old data?* It writes new structures over the old ones; the old data is mostly still there but unreachable, so it's not a secure erase.
