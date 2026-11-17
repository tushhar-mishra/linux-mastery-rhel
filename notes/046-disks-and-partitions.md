# 046 · Disks, Device Names and Partitions (GPT)

> **You need first:** [045 · Robust production scripts](045-robust-scripts.md)
> **Next:** [047 · Filesystems](047-filesystems.md)

---

## What it is

- A **block device** is a device Linux reads and writes in fixed-size **blocks** (sectors, usually 512 bytes or 4 KiB) and in any order: a disk, a partition, a USB stick, a virtual disk. They appear in `/dev` with type `b` (topic 006).
- A **partition** is a slice of a disk that the system treats as a separate device (`/dev/sdb1`).
- The **partition table** (also called the disk **label**) is the small map at the start of the disk that says where each partition begins and ends. The two formats are **MBR** (Master Boot Record, old) and **GPT** (GUID Partition Table, modern).
- **udev** is the service that creates device files in `/dev` as hardware appears, including stable alias names under `/dev/disk/`.

The full storage stack, which the next topics walk up one layer at a time:
```
disk  →  partition table (GPT)  →  partitions  →  [LVM]  →  filesystem  →  mount point
/dev/vdb      label                 /dev/vdb1     (049)       (047)         /data (048)
```

## Why it exists

A raw disk is just billions of numbered blocks. Partitioning lets you divide it for different uses (boot area, system, swap, data), each with its own filesystem or role. Stable device names matter because the kernel's names (`sda`, `sdb`) can **change between boots**, and mounting the wrong disk can destroy data.

## Analogy

A disk is a **plot of land**. The partition table is the **survey map** recording where each plot's fences are. Partitions are the **fenced plots**. A filesystem (next topic) is the **building** you put on a plot. Device names like `sdb` are **temporary house numbers** that can be reassigned; UUIDs and serial numbers are the **land registry numbers** that never change.

## How it works inside

### Device names

| Interface | What it is | Linux names |
|---|---|---|
| SATA / SAS / SCSI / USB | Ordinary and enterprise disks, SAN volumes, USB sticks: all handled by the kernel's SCSI layer | `/dev/sda`, `/dev/sdb`, … |
| **NVMe** (Non-Volatile Memory Express) | Fast SSDs attached directly to PCIe (Peripheral Component Interconnect Express, the motherboard's high-speed bus) | `/dev/nvme0n1` (controller 0, namespace 1) |
| **virtio** | The efficient "paravirtual" disk inside KVM/QEMU virtual machines | `/dev/vda`, `/dev/vdb`, … |
| Cloud (AWS Nitro, …) | Often presented as NVMe | `/dev/nvme1n1` |
| Optical | CD/DVD | `/dev/sr0` |
| Device mapper | Virtual devices built by LVM, encryption, multipath | `/dev/dm-0`, `/dev/mapper/<name>` |

**Partition names:** add the number (`/dev/sdb1`, `/dev/vdb2`). If the disk name already ends in a digit, a `p` goes in between: `/dev/nvme0n1p1`.

**The kernel names disks in the order it detects them.** Add a disk, change a controller or reboot, and `sdb` can become `sdc`. **udev** creates **stable** names under `/dev/disk/`:

| Path | Based on | Use for |
|---|---|---|
| `/dev/disk/by-uuid/` | The **filesystem's** UUID (Universally Unique IDentifier) | `/etc/fstab` (topic 048) |
| `/dev/disk/by-label/` | The filesystem label you set | Human-friendly mounts |
| `/dev/disk/by-partuuid/` | The GPT partition's GUID | Bootloaders |
| `/dev/disk/by-id/` | Model + serial number / WWN (World Wide Name) | Identifying physical disks in tickets |
| `/dev/disk/by-path/` | The hardware bus position | Fixed slots |

The `major:minor` numbers in `lsblk` (like `8:16`) tell the kernel **which driver** (major) and **which device** (minor).

### MBR vs GPT

| | MBR (old, "msdos") | **GPT** (modern) |
|---|---|---|
| Where it lives | The first 512-byte sector only | A header + table at the start **and a backup copy at the end** of the disk |
| Number of partitions | 4 primary (or 3 + an "extended" partition holding "logical" ones) | 128 by default |
| Largest disk | 2 TiB | About 8 ZiB (effectively unlimited) |
| IDs | A 1-byte type code | GUIDs for the disk, each partition and each type, plus optional names |
| Boots with | BIOS | UEFI (BIOS + GPT also works with a 1 MiB "BIOS boot" partition) |
| Damage tolerance | One bad sector = table lost | Backup header can rebuild it; CRC checksums detect corruption |

**Use GPT** for everything new. (GPT also writes a "protective MBR" in sector 0, so old tools don't think the disk is empty.)

### What happens when you partition

1. The tool (`fdisk`, `gdisk`, `parted`) writes the new table to the disk.
2. It asks the kernel to **re-read** the table (an `ioctl` call: a special control request to a device driver). The kernel creates the new partition devices, and udev creates `/dev/vdb1` and the `/dev/disk/*` links.
3. If any partition on that disk is **in use** (mounted, swap, LVM), the kernel may refuse to re-read until the next reboot. `partprobe` asks again and warns you.

Partitions start at **1 MiB** (sector 2048) by default. This **alignment** matches SSD erase blocks and RAID stripes, which avoids slow read-modify-write cycles.

**Partitioning and `mkfs` don't erase data.** They only write new metadata; old data stays on disk and can often be recovered. Erasing needs `blkdiscard` (SSD), `shred`/`dd` (HDD) or vendor secure-erase tools.

## Commands

### Find your disks first (every time)

```bash
lsblk
```
```
NAME          MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sr0            11:0    1 1024M  0 rom
vda           252:0    0   20G  0 disk
├─vda1        252:1    0    1G  0 part /boot
└─vda2        252:2    0   19G  0 part
  ├─rhel-root 253:0    0   17G  0 lvm  /
  └─rhel-swap 253:1    0    2G  0 lvm  [SWAP]
vdb           252:16   0    5G  0 disk
vdc           252:32   0    5G  0 disk
```
- `TYPE`: `disk`, `part` (partition), `lvm` (LVM volume), `rom` (optical). `RM` = removable. `RO` = read-only.
- `vda` is the **system disk** (it holds `/boot` and `/`). `vdb` and `vdc` have no partitions and no mount points: those are your empty practice disks.

**Rule:** before any write, confirm the target in `lsblk`: right size, no partitions, no mount points. On many machines `sda`/`vda`/`nvme0n1` is the OS disk.

```bash
lsblk -f
```
```
NAME          FSTYPE      FSVER    LABEL UUID                                   FSAVAIL FSUSE% MOUNTPOINTS
vda
├─vda1        xfs                        3c1b...-9f2e                           650M    33% /boot
└─vda2        LVM2_member LVM2 001       Xk2f...-aB9c
  ├─rhel-root xfs                        77d0...-1e44                           15G     12% /
  └─rhel-swap swap        1              91a2...-6c3d                                       [SWAP]
vdb
```
- `-f` adds filesystem type, label and UUID.

```bash
sudo blkid ; ls -l /dev/disk/by-id/ | head -3
sudo fdisk -l /dev/vdb
```
```
Disk /dev/vdb: 5 GiB, 5368709120 bytes, 10485760 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
```
- No "Disklabel type" line yet: the disk has no partition table.

### fdisk (interactive, writes only on `w`)

```
$ sudo fdisk /dev/vdb
Device does not contain a recognized partition table.
Created a new DOS (MBR) disklabel with disk identifier 0x062d10f7.   ← only in memory; g replaces it
Command (m for help): g          ← create a new EMPTY GPT table (only on an unused disk!)
Created a new GPT disklabel (GUID: 6C1A…).
Command (m for help): n          ← new partition
Partition number (1-128, default 1): ⏎
First sector (2048-10485726, default 2048): ⏎      ← default = 1 MiB alignment
Last sector, +/-sectors or +/-size{K,M,G,T,P} (...): +1G
Created a new partition 1 of type 'Linux filesystem' and of size 1 GiB.
Command (m for help): n
...
Last sector ...: +512M
Command (m for help): t          ← change the type of a partition
Partition number (1,2, default 2): 2
Partition type or alias (type L to list all): swap
Changed type of partition 'Linux filesystem' to 'Linux swap'.
Command (m for help): p          ← print to check
Command (m for help): w          ← write and exit   (q = quit WITHOUT saving)
```
- Other keys: `d` delete, `F` list free space, `L` list types (`lvm`, `swap`, `linux`, `uefi`).
- Nothing touches the disk until `w`. `q` throws everything away, which makes fdisk safe to explore.

### parted (one-shot and scriptable; changes apply immediately)

```bash
sudo parted -s /dev/vdc mklabel gpt                       # ⚠️ wipes the partition table
sudo parted -s /dev/vdc mkpart data xfs 1MiB 1025MiB
sudo parted -s /dev/vdc mkpart lvm1 1025MiB 100%
sudo parted -s /dev/vdc set 2 lvm on
sudo parted /dev/vdc print
```
```
Model: Virtio Block Device (virtblk)
Disk /dev/vdc: 5369MB
Sector size (logical/physical): 512B/512B
Partition Table: gpt
Disk Flags:

Number  Start   End     Size    File system  Name   Flags
 1      1049kB  1075MB  1074MB               data
 2      1075MB  5368MB  4293MB               lvm1   lvm
```
- `-s` = script mode (no questions). `100%` = to the end of the disk. `gdisk` is a GPT-only interactive alternative with type codes like `8300` Linux, `8200` swap, `8e00` LVM.

### After partitioning

```bash
sudo partprobe /dev/vdb
lsblk /dev/vdb
```
```
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
vdb    252:16   0    5G  0 disk
├─vdb1 252:17   0    1G  0 part
└─vdb2 252:18   0  512M  0 part
```

### Adding a partition without destroying data

On a disk that already has partitions: use `n` in **free space** only. **Never** `g` (new label) or `parted mklabel`, which replace the whole table. Check free space with `sudo parted /dev/vdb print free` or `F` in fdisk.

### Removing old signatures (lab disks only)

```bash
sudo wipefs /dev/vdb1        # list signatures (filesystem, LVM, RAID…)
sudo wipefs -a /dev/vdb1     # erase the signatures on a partition ⚠️
sudo wipefs -a /dev/vdb      # erase the partition table signature ⚠️
```

### Detecting new disks without a reboot

```bash
sudo dmesg | tail          # look for vd*, sd* or nvme* messages
for h in /sys/class/scsi_host/host*/scan; do echo '- - -' | sudo tee "$h" >/dev/null; done   # SCSI rescan
```
- On VMs and clouds, hot-added disks usually appear by themselves. On SCSI/SAN hosts you may need the rescan above.

### Try it
1. Run `lsblk` and identify which disk holds `/` and which are empty.
2. With fdisk, create on `vdb`: a 1 GiB Linux partition and a 512 MiB swap-type partition. Print, then quit with `q` (nothing saved). Do it again, and this time `w`.
3. With parted, give `vdc` a GPT label and one partition using 100%, flagged lvm.
4. Run `ls -l /dev/disk/by-*/ | grep vdb` and see the stable names.

## Where you'll use it

- **Adding storage** to servers and VMs: new data disks for databases, logs, container storage (`/var/lib/containers`).
- **Cloud volumes** (AWS EBS, Azure Managed Disks, GCP Persistent Disk): attach, then partition (or use LVM directly), make a filesystem, mount. Cloud images grow the root partition automatically with `growpart` (topic 104).
- **Kubernetes:** persistent volumes are block devices like these, attached to the node by a storage driver, then formatted and mounted into pods.
- **Incident tickets:** always quote disk **serial/WWN** (`/dev/disk/by-id/`), never `sdb`.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| A new disk isn't visible | Not detected yet | `lsblk`, `dmesg`; SCSI rescan; check the VM's settings |
| A new partition doesn't show in `lsblk` | The kernel hasn't re-read the table | `sudo partprobe /dev/vdb` |
| `Re-reading the partition table failed: Device or resource busy` | Partitions on that disk are in use | `partprobe`; if it still fails, reboot |
| You ran `mkfs` or `mklabel` on the wrong disk | Didn't check `lsblk` | Restore from backup. Prevention is the only cure |
| A 4 TiB disk shows only 2 TiB | It has an MBR table | Use GPT (repartitioning is destructive; back up first) |
| `dmesg \| grep sd` finds nothing | The disk is `vd*` or `nvme*` | Search for the right prefix |
| `/dev/sdb` became `/dev/sdc` after a reboot | Detection order changed | Use UUIDs, labels or `/dev/disk/by-id` |

## Quick recap

- Disks are block devices: `sdX` (SATA/SAS/USB), `vdX` (KVM virtio), `nvme0n1` (NVMe; partitions `p1`). Kernel names can change; `/dev/disk/by-uuid|label|id` are stable.
- Use **GPT** (128 partitions, huge disks, backup header) rather than MBR (4 primaries, 2 TiB).
- `lsblk` (-f) to identify; `fdisk` (writes on `w`) or `parted` (immediate) to partition; `partprobe` afterwards.
- Never relabel a disk that has data. Partitioning and mkfs don't erase data.

**Interview questions**

1. *MBR vs GPT?* MBR supports 4 primary partitions and disks up to 2 TiB, with a single copy of the table. GPT supports 128 partitions, enormous disks, GUIDs and a backup table at the end of the disk.
2. *Why not put `/dev/sdb1` in fstab?* Kernel device names depend on detection order and can change between boots. Filesystem UUIDs and labels don't.
3. *What does `partprobe` do?* It asks the kernel to re-read a disk's partition table, so new partitions appear without a reboot (unless the disk is busy).
