# LVM Fundamentals: PVs, VGs, LVs & Resizing

> **Objectives:** *Create and remove physical volumes* · *Assign physical volumes to volume groups* · *Create and delete logical volumes* · *Extend existing logical volumes* · *Add … logical volumes … non-destructively* **[RHCSA Core]**
> **Related:** [Disks & partitioning](disks-and-partitioning.md) · [Filesystems & mkfs](filesystems-and-mkfs.md) · [Mounting & fstab](mounting-and-fstab.md) · [LVM snapshots & recovery](lvm-snapshots-and-recovery.md) · [VG merge/split & migration](lvm-vg-merge-split-and-migration.md)

## 1. Overview

With plain partitions, growing a filesystem usually means unmounting, backing up, re-partitioning and restoring. **LVM (Logical Volume Manager)** puts a flexible layer between disks and filesystems: disks are pooled into a **volume group**, and **logical volumes** are carved from that pool. LVs can be grown online, span several disks, be moved between disks, and be snapshotted. RHEL installs `/` and swap on LVM by default.

```
/dev/vdb1  /dev/vdc1  /dev/vdd      ← partitions or whole disks
   PV         PV        PV          ← pvcreate
   └──────────┼──────────┘
          VG "vgdata"               ← vgcreate (pool of extents)
      ┌───────┴───────┐
   LV "lvweb"     LV "lvdb"         ← lvcreate
   XFS /web       ext4 /db          ← mkfs + mount + fstab
```

## 2. Key Concepts

| Term | Meaning |
|---|---|
| **PV** (physical volume) | A partition or whole disk initialized for LVM (metadata label) |
| **VG** (volume group) | Pool of storage made from one or more PVs |
| **PE** (physical extent) | Allocation unit within a VG; **default 4 MiB**, set at `vgcreate -s` |
| **LV** (logical volume) | Block device carved from a VG; holds a filesystem or swap |
| **LE** (logical extent) | An LV's extents, each mapped to a PE |

**Device paths:** `/dev/VG/LV` (e.g. `/dev/vgdata/lvweb`) and `/dev/mapper/VG-LV`. In mapper names, hyphens inside VG/LV names are doubled (`my-vg` → `my--vg`). Both are stable across reboots.

**LV sizes are always whole extents.** Requests are rounded up ("Rounding up size to full physical extent").

## 3. Commands

| | PV | VG | LV |
|---|---|---|---|
| Create | `pvcreate` | `vgcreate` | `lvcreate` |
| Summary | `pvs` | `vgs` | `lvs` |
| Detail | `pvdisplay` | `vgdisplay` | `lvdisplay` |
| Grow | `pvresize` | `vgextend` | `lvextend` |
| Shrink | `pvresize` | `vgreduce` | `lvreduce` |
| Remove | `pvremove` | `vgremove` | `lvremove` |
| Scan | `pvscan` | `vgscan` | `lvscan` |

```bash
pvs -o +pv_used              # PVs with used space
vgs                          # VSize, VFree per VG
lvs -a -o +devices           # LVs and the PVs they sit on
lsblk                        # tree view incl. LVs (type "lvm")
```

## 4. Creating Storage **[RHCSA Core]**

### 4.1 Prepare PVs

```bash
lsblk                                   # identify the empty disk/partition!
fdisk /dev/vdb   → g (new GPT, empty disk only) → n → +2G → t → "Linux LVM" (alias lvm) → w
partprobe /dev/vdb
pvcreate /dev/vdb1                      # or a whole disk: pvcreate /dev/vdc
pvs
```

### 4.2 Create a VG and LVs

```bash
vgcreate vgdata /dev/vdb1                    # default PE size 4 MiB
vgcreate -s 16M vgexam /dev/vdc1             # custom PE size (power of 2)
lvcreate -n lvweb -L 1G vgdata               # by size  (-L: K/M/G/T)
lvcreate -n lvdb  -l 100 vgdata              # by number of extents (-l)
lvcreate -n lvrest -l 100%FREE vgdata        # all remaining space (also: 50%VG)
lvs ; vgs
```

### 4.3 Filesystem and persistent mount

```bash
mkfs.xfs /dev/vgdata/lvweb
mkdir -p /web
blkid /dev/vgdata/lvweb                      # copy the UUID
echo 'UUID=<uuid> /web xfs defaults 0 0' >> /etc/fstab
systemctl daemon-reload ; mount -a ; findmnt /web
```

`/dev/vgdata/lvweb` (or `/dev/mapper/vgdata-lvweb`) in fstab is also stable, but the objective says **UUID or label**, so use `UUID=` in the exam.

## 5. Extending (online) **[RHCSA Core]**

```bash
vgs                                          # enough VFree?
vgextend vgdata /dev/vdd1                    # if not: add a PV to the SAME VG
lvextend -r -L +500M /dev/vgdata/lvweb       # grow LV AND filesystem in one step (-r)
lvextend -r -L 2G /dev/vgdata/lvweb          # grow TO an absolute size
lvextend -r -l +100%FREE /dev/vgdata/lvweb   # use all free space
df -hT /web                                  # verify the filesystem size
```

Without `-r`, grow the filesystem yourself:

| Filesystem | Grow command | Target |
|---|---|---|
| XFS | `xfs_growfs /web` | **Mount point** (must be mounted) |
| ext4 | `resize2fs /dev/vgdata/lvdb` | Device (mounted or not) |

## 6. Reducing (ext4 only) **[Advanced/Optional]**

XFS **cannot** be shrunk. For ext4, the filesystem must be shrunk **before** the LV:

```bash
umount /db
lvreduce -r -L 1G /dev/vgdata/lvdb      # -r: runs e2fsck + resize2fs first, then shrinks the LV
mount -a
```

Manual equivalent (order is critical): `e2fsck -f` → `resize2fs DEV 1G` → `lvreduce -L 1G DEV` → `resize2fs DEV` (fills any slack) → mount.

> ⚠️ **Shrinking the LV before the filesystem destroys data.** Back up first; prefer `lvreduce -r`.

## 7. Removing Storage

```bash
umount /db ; vi /etc/fstab                   # remove the fstab line first!
lvremove /dev/vgdata/lvdb                    # ⚠️ data gone
vgremove vgdata                              # removes the VG (and any remaining LVs, after prompting)
pvremove /dev/vdb1                           # wipe the LVM label
```

## 8. RHCSA Exam Patterns **[RHCSA Core]**

```bash
# "Create VG 'vg01' with PE size 16 MiB; LV 'lv01' of 20 extents; ext4; mount on /mnt/lv01 persistently"
vgcreate -s 16M vg01 /dev/vdb1
lvcreate -n lv01 -l 20 vg01               # 20 × 16 MiB = 320 MiB
mkfs.ext4 /dev/vg01/lv01
mkdir -p /mnt/lv01 ; echo "UUID=$(blkid -s UUID -o value /dev/vg01/lv01) /mnt/lv01 ext4 defaults 0 2" >> /etc/fstab
systemctl daemon-reload ; mount -a

# "Resize lv 'database' to a size between 830 MiB and 870 MiB"
lvextend -r -L 850M /dev/vgdb/database    # aim at the middle; extent rounding stays in range
```

- Verify everything: `vgdisplay vg01 | grep 'PE Size'`, `lvs`, `df -hT`, `findmnt`.
- Extend the **right** VG, the one containing the LV.
- Don't destroy existing LVs or data; only add or extend.

## 9. Production Practices **[Production Practice]**

- Leave free space in each VG so you can grow LVs and take snapshots quickly.
- Prefer growing by adding PVs or extending virtual disks (`pvresize` after the disk grows).
- Name VGs and LVs meaningfully (`vg_app`, `lv_logs`).
- **RHEL 9/10 LVM devices file:** LVM only uses devices listed in `/etc/lvm/devices/system.devices`. Disks attached from another system won't appear until imported (`vgimportdevices VG` or `lvmdevices --adddev`).
- Back up LVM metadata state is automatic (`/etc/lvm/backup`, `/etc/lvm/archive`); see the [recovery note](lvm-snapshots-and-recovery.md).

## 10. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Insufficient free extents` | VG too small | `vgextend` with a new PV; or smaller size |
| LV bigger but `df` unchanged | Filesystem not grown | `xfs_growfs MNT` / `resize2fs DEV` (next time use `-r`) |
| `Can't open /dev/vdb1 exclusively. Mounted filesystem?` | Partition in use / has a mounted FS | `lsblk -f`; pick the right device |
| `Cannot use /dev/vdb: device is partitioned` | Whole disk has a partition table | Use the partition, or `wipefs -a` an unused disk |
| VG/PV not visible after moving a disk in | Not in the devices file | `vgimportdevices VG` / `lvmdevices --adddev /dev/X` |
| `Logical volume … contains a filesystem in use` | LV mounted | `umount` first |
| Data lost after shrink | LV reduced before the FS | Restore from backup; always `lvreduce -r` |
| Boot fails after `lvremove` | fstab still references the LV | Remove/comment the fstab line (emergency shell) |

## 11. Interview Questions

| Question | Answer |
|---|---|
| PV, VG, LV? | PV: initialized disk/partition; VG: pool of PVs; LV: virtual block device carved from the VG. |
| What's a PE and why does it matter? | Allocation unit (default 4 MiB); LV sizes are multiples of it. |
| How do you grow a filesystem on LVM online? | `lvextend -r -L +X /dev/VG/LV` (or lvextend + xfs_growfs/resize2fs). |
| Can you shrink XFS? | No. ext4 can be shrunk offline (`lvreduce -r`). |
| `-L` vs `-l`? | Size in units vs number of extents (or a percentage like `100%FREE`). |
| `/dev/VG/LV` vs `/dev/mapper/VG-LV`? | Same device (symlinks to `/dev/dm-N`); mapper names double internal hyphens. |

## 12. Quick Revision

```bash
pvcreate DEV | vgcreate [-s 16M] VG PVs | lvcreate -n LV -L SIZE|-l EXTENTS|-l 100%FREE VG
pvs vgs lvs [-o +devices] | *display | lsblk
vgextend VG PV | lvextend -r -L +SIZE /dev/VG/LV | xfs_growfs MNT | resize2fs DEV
lvreduce -r -L SIZE (ext4 only, unmounted) | XFS never shrinks
umount → fstab → lvremove → vgremove → pvremove
/dev/VG/LV = /dev/mapper/VG-LV · fstab: UUID=… · default PE 4 MiB
```

## 13. Cross-References

- [Disks & partitioning](disks-and-partitioning.md) · [Filesystems & mkfs](filesystems-and-mkfs.md) · [Mounting & fstab](mounting-and-fstab.md)
- [LVM snapshots & recovery](lvm-snapshots-and-recovery.md) · [VG merge/split & pvmove](lvm-vg-merge-split-and-migration.md) · [Thin provisioning & striping](lvm-thin-provisioning-and-striping.md)
- [Swap on LVM](swap.md) · [Storage I/O path (device-mapper)](storage-io-path.md)
