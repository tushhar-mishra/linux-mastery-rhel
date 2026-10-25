# Disks, Device Naming & Partitioning (GPT)

> **Objectives:** *List, create, and delete partitions on GPT disks* · *Add new partitions … non-destructively* **[RHCSA Core]**
> **Related:** [Filesystems & mkfs](filesystems-and-mkfs.md) · [Mounting & fstab](mounting-and-fstab.md) · [Filesystem hierarchy](../linux-fundamentals/filesystem-hierarchy.md) · [LVM fundamentals](lvm-fundamentals.md) · [Swap](swap.md)

## 1. Overview

Storage on Linux is a stack:

```
physical/virtual disk  →  partition table (GPT)  →  partitions  →  [LVM PV/VG/LV]  →  filesystem  →  mount point
/dev/vdb                  label                     /dev/vdb1       (LVM)               mkfs.xfs      /data (+ /etc/fstab)
```

To use a new disk: **identify it → partition it → make a filesystem → mount it → make the mount persistent**. This note covers the first two steps.

## 2. Devices, Interfaces & Naming

| Interface | Notes | Linux device names |
|---|---|---|
| IDE/PATA | Obsolete parallel interface | `/dev/hda` (very old kernels); now handled as `sd*` |
| SATA | Common for HDDs/SSDs | `/dev/sda`, `/dev/sdb` … |
| SCSI / **SAS** | Enterprise disks (SAS = serial SCSI), SAN LUNs | `/dev/sd*` |
| USB storage | Uses the SCSI layer | `/dev/sd*` |
| **NVMe** | SSD directly on PCIe (≈7–8 GB/s Gen4 ×4) | `/dev/nvme0n1` (controller 0, namespace 1) |
| **virtio** | Paravirtual disk in KVM VMs | `/dev/vda`, `/dev/vdb` … |
| Optical | CD/DVD | `/dev/sr0` |
| Device-mapper | LVM, LUKS, multipath | `/dev/dm-0`, `/dev/mapper/vg-lv` |

**Partition names:** append the number (`/dev/sdb1`, `/dev/vdb2`). If the disk name ends in a digit, a `p` is added: `/dev/nvme0n1p1`.

**Kernel names can change** between boots (detection order). Stable names live under `/dev/disk/`:

| Path | Based on |
|---|---|
| `/dev/disk/by-uuid/` | **Filesystem UUID** (use in fstab) |
| `/dev/disk/by-label/` | Filesystem label |
| `/dev/disk/by-partuuid/`, `by-partlabel/` | GPT partition GUID / name |
| `/dev/disk/by-id/` | Model + serial / WWN |
| `/dev/disk/by-path/` | Hardware bus path |

### 2.1 Discovering disks

```bash
lsblk                                   # tree of disks, partitions, LVs, mount points
lsblk -f                                # + FSTYPE, LABEL, UUID
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS
fdisk -l /dev/vdb                       # partition table details (root)
blkid                                   # filesystem signatures, UUIDs, labels
ls -l /dev/disk/by-uuid/
dmesg | grep -iE 'sd[a-z]|vd[a-z]|nvme'  # detection messages (match your disk type!)
lsscsi                                  # SCSI devices (lsscsi package)
cat /proc/partitions
```

> ⚠️ **Identify the target disk before every write.** Check `lsblk`: the disk with **no partitions and no mount points** that matches the task's size. On many VMs `sda`/`vda`/`nvme0n1` is the **OS disk**.

## 3. Partition Tables: MBR vs GPT

| | MBR (msdos) **[Advanced/Optional]** | **GPT** **[RHCSA Core]** |
|---|---|---|
| Location | First 512-byte sector (446 boot code + 64-byte table + signature) | Protective MBR + primary header/table at the start, **backup** at the end |
| Partitions | 4 primary, or 3 primary + 1 extended (with logical partitions) | 128 by default |
| Max disk size | 2 TiB (512-byte sectors) | ~8 ZiB |
| Identifiers | 1-byte type ID | GUIDs for disk, partitions and types; optional partition names |
| Boot | BIOS | UEFI (BIOS+GPT needs a 1 MiB "BIOS boot" partition for GRUB) |

The RHEL 10 exam objectives mention **GPT only**. Apple Partition Map (APM) is historical.

## 4. Partitioning Tools

| Tool | Style | Notes |
|---|---|---|
| `fdisk` | Interactive, changes written on `w` | Supports GPT and MBR (`g` = new GPT, `o` = new MBR) |
| `gdisk` | Interactive, GPT-only, writes on `w` | Type codes `8300` Linux, `8200` swap, `8e00` LVM, `ef00` EFI |
| `parted` | Interactive or one-shot | **Changes apply immediately**; scriptable |

### 4.1 `fdisk` on a new disk (GPT)

```
# fdisk /dev/vdb
Command (m for help): g          ← create a new EMPTY GPT label (only on a new/unused disk!)
Command (m for help): n          ← new partition
Partition number (1-128, default 1): ⏎
First sector (…default 2048): ⏎  ← default keeps 1 MiB alignment
Last sector, +/-sectors or +/-size{K,M,G,T,P}: +1G
Command (m for help): t          ← change type (L lists types; e.g. "Linux swap", "Linux LVM")
Command (m for help): p          ← print and check
Command (m for help): w          ← write and exit (q = quit WITHOUT saving)
```

Other keys: `d` delete, `l`/`L` list types, `F` list free space.

### 4.2 `parted` one-shot

```bash
parted -s /dev/vdb mklabel gpt                          # ⚠️ wipes the partition table
parted -s /dev/vdb mkpart data xfs 1MiB 1025MiB
parted -s /dev/vdb mkpart swap1 linux-swap 1025MiB 1537MiB
parted -s /dev/vdb mkpart lvm1 1537MiB 100%
parted -s /dev/vdb set 3 lvm on
parted /dev/vdb print
```

### 4.3 After changing partitions

```bash
partprobe /dev/vdb      # ask the kernel to re-read the table (or: udevadm settle)
lsblk /dev/vdb          # confirm the new partitions exist before mkfs
```

If the disk is in use (e.g., the OS disk), the kernel may not re-read the table until reboot. `partprobe` warns about this.

### 4.4 Removing signatures before reuse

```bash
wipefs /dev/vdb1        # list signatures
wipefs -a /dev/vdb1     # remove filesystem signatures (data blocks remain but are orphaned) ⚠️
wipefs -a /dev/vdb      # remove the partition table signature from a lab disk ⚠️
```

## 5. RHCSA Exam Focus **[RHCSA Core]**

- "Add a 512 MiB partition **without destroying existing data**": create it only in **free space** on the specified disk; never `g`/`mklabel` a disk that already has partitions.
- Sizes: `+512M` in fdisk means 512 MiB. Partition sizes are rounded for alignment, so "approximately" is fine, but stay close to the requested size.
- Set the right type when the task implies it (swap → Linux swap, LVM PV → Linux LVM). It isn't strictly required by the tools, but it's clean.
- Verify with `lsblk` after `w`; run `partprobe` if the partition isn't visible.

## 6. Production Practices **[Production Practice]**

- Partition disks **once**, keep a 1 MiB aligned start, and put most capacity under LVM for flexibility.
- Record disk serials/WWNs (`/dev/disk/by-id`) in change tickets; never rely on `sdX` letters.
- Securely erasing disks: `dd if=/dev/zero …` or `shred` for HDDs, `blkdiscard` / vendor secure-erase for SSDs. `mkfs` and repartitioning do **not** erase data.

## 7. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| New disk not visible | Not detected or rescan needed | `lsblk`; `dmesg`; for SCSI: `echo '- - -' > /sys/class/scsi_host/host0/scan` [Advanced] |
| New partition not in `lsblk` | Kernel hasn't re-read the table | `partprobe /dev/vdb` |
| `Re-reading the partition table failed: Device or resource busy` | Disk has mounted partitions | `partprobe`; reboot if it still fails |
| `mkfs` on the wrong disk | Didn't verify | Restore from backup; always check `lsblk` first |
| Disk > 2 TiB shows only 2 TiB | MBR label | Use GPT (destructive on existing data) |
| `dmesg \| grep sd` shows nothing | Disk is `vd*` or `nvme*` | Search for the right prefix |

## 8. Interview Questions

| Question | Answer |
|---|---|
| MBR vs GPT? | MBR: 4 primary partitions, 2 TiB limit, single table. GPT: 128 partitions, huge disks, GUIDs, backup table at the end. |
| Why not use `/dev/sdb1` in fstab? | Device names can change between boots; UUIDs and labels are stable. |
| `fdisk` vs `parted`? | fdisk writes only on `w`; parted applies changes immediately and is scriptable. |
| What does `partprobe` do? | Tells the kernel to re-read a disk's partition table. |
| Name for partition 1 on the first NVMe disk? | `/dev/nvme0n1p1`. |
| Does `mkfs` erase data? | No; it writes new metadata. Old data can often be recovered. |

## 9. Quick Revision

```bash
lsblk [-f] | blkid | fdisk -l DISK | ls -l /dev/disk/by-uuid/ | partprobe DISK | wipefs [-a]
fdisk DISK: g (new GPT!) n (new) +SIZE t (type) p (print) d (delete) w (write) q (quit)
parted -s DISK mklabel gpt | mkpart NAME FSTYPE START END | set N lvm on | print
names: sdX vdX nvme0n1p1 sr0 dm-N /dev/mapper/* · GPT: 128 parts, backup header, ZiB
```

## 10. Cross-References

- [Filesystems & mkfs](filesystems-and-mkfs.md)
- [Mounting & fstab](mounting-and-fstab.md)
- [Filesystem hierarchy](../linux-fundamentals/filesystem-hierarchy.md)
- [LVM fundamentals](lvm-fundamentals.md) · [Swap](swap.md) · [RAID (mdadm)](raid-mdadm.md)
