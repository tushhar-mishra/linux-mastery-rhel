# Filesystems: Types, Creation & Tuning (XFS, ext4, VFAT)

> **Objective:** *Create, mount, unmount, and use VFAT, ext4, and XFS file systems* **[RHCSA Core]**
> **Related:** [Disks & partitioning](disks-and-partitioning.md) · [Mounting & fstab](mounting-and-fstab.md) · [Links & inodes](../users-groups-and-permissions/links.md) · [Filesystem check & repair](filesystem-check-and-repair.md) · [Storage I/O path](storage-io-path.md)

## 1. Overview

A **filesystem** organizes a block device into files and directories with metadata (inodes, permissions, timestamps). On RHEL 10, **XFS** is the default; **ext4** is fully supported; **VFAT** is used for the EFI System Partition and removable media. `mkfs` writes a new filesystem (and destroys access to what was there).

## 2. Key Concepts

### 2.1 Journaling

Metadata changes are first written to a **journal**, then applied to the filesystem. After a crash, the journal is replayed in seconds instead of scanning the whole disk. XFS, ext3 and ext4 journal; ext2 and VFAT don't.

### 2.2 Choosing a filesystem

| FS | Use on RHEL | Grow | Shrink | Max sizes (theoretical) | Notes |
|---|---|---|---|---|---|
| **XFS** | Default for `/`, data, large files | Online (`xfs_growfs`) | **Never** | 8 EiB file/volume | Allocation groups, parallel I/O, delayed allocation |
| **ext4** | General purpose, small/medium volumes, when shrink may be needed | Online (`resize2fs`) | Offline only | 16 TiB file, 1 EiB volume | Extents, delayed allocation, `tune2fs` |
| ext3 / ext2 | Legacy | — | — | — | ext2 has no journal |
| **VFAT (FAT32)** | `/boot/efi`, USB exchange | — | — | 4 GiB max file | No Unix permissions/ownership |
| swap | Paging space | — | — | — | Not a filesystem: `mkswap` + `swapon` |
| iso9660 / UDF | Optical media and `.iso` images (read) | — | — | — | |
| GFS2 | Shared-disk cluster FS | — | — | — | High Availability add-on **[Advanced]** |
| NTFS / APFS | Windows / macOS | — | — | — | Not supported natively on RHEL |

Red Hat's *supported* limits are lower than the theoretical ones (check the RHEL "technology capabilities and limits" page for production planning).

> ⚠️ **Common misconceptions:**
> - XFS **does** use delayed allocation.
> - ext4's max **file** size is 16 TiB (1 EiB is the volume limit).
> - ext3 can be grown online.
> - XFS can't be shrunk at all; ext4 only offline.

```bash
cat /proc/filesystems | grep -v nodev     # filesystems the kernel currently supports on block devices
man fs ; man xfs ; man ext4
```

## 3. Creating Filesystems **[RHCSA Core]**

```bash
mkfs.xfs /dev/vdb1                     # XFS
mkfs.xfs -f -L DATA /dev/vdb1          # -f overwrite an existing signature, -L label (≤12 chars)
mkfs.ext4 /dev/vdb2                    # ext4
mkfs.ext4 -L LOGS /dev/vdb2            # label ≤16 chars
mkfs.vfat /dev/vdb3                    # FAT (dosfstools); FAT32: mkfs.vfat -F 32
mkfs.vfat -n USBDATA /dev/vdb3         # VFAT label (-n, ≤11 chars, stored uppercase)
mkfs -t ext4 /dev/vdb2                 # generic front-end
mkswap -L SWAP1 /dev/vdb4              # swap signature (then swapon; see mounting note)

blkid /dev/vdb1                        # TYPE, UUID, LABEL
lsblk -f                               # all devices with FS type/label/UUID
```

> ⚠️ `mkfs` on the wrong device destroys that filesystem. Verify with `lsblk -f` first; `mkfs.xfs` refusing without `-f` is a safety net, so read its warning before adding `-f`.

## 4. Labels

| | ext2/3/4 | XFS | VFAT |
|---|---|---|---|
| Set at creation | `mkfs.ext4 -L NAME` | `mkfs.xfs -L NAME` | `mkfs.vfat -n NAME` |
| Change later | `e2label DEV NAME` / `tune2fs -L NAME DEV` (mounted OK) | `xfs_admin -L NAME DEV` (**unmounted**) | `fatlabel DEV NAME` |
| View | `e2label DEV`, `blkid` | `xfs_admin -l DEV`, `blkid` | `fatlabel DEV`, `blkid` |
| Max length | 16 | 12 | 11 |

Use in fstab as `LABEL=NAME`. Labels must be unique on the system.

## 5. ext Tools

```bash
tune2fs -l /dev/vdb2                         # superblock: features, block counts, mount counts
tune2fs -l /dev/vdb2 | grep -i 'reserved block count'
tune2fs -m 1 /dev/vdb2                       # reserved-for-root blocks: 5% → 1% (works while mounted)
tune2fs -L NEWLABEL /dev/vdb2
dumpe2fs -h /dev/vdb2                        # header info (similar to tune2fs -l)
resize2fs /dev/vdb2                          # grow to fill the device (after lvextend)
e2fsck -f /dev/vdb2                          # check — UNMOUNTED only
```

**Conversions** **[Advanced/Optional]** (unmount first, back up):

```bash
tune2fs -j /dev/vdb2                                   # ext2 → ext3 (add journal)
tune2fs -O extents,uninit_bg,dir_index /dev/vdb2       # ext3 → ext4 features…
e2fsck -fD /dev/vdb2                                   # …REQUIRED afterwards; then change fstab type to ext4
tune2fs -O ^has_journal /dev/vdb2                      # remove journal (rarely sensible)
```

Existing files keep their old block maps after an ext3→ext4 conversion; only new files use extents.

## 6. XFS Tools

```bash
xfs_info /data                     # geometry: agcount, block size, log, etc. (mount point or device)
xfs_admin -l /dev/vdb1             # show label      | xfs_admin -u: show UUID
xfs_admin -L NEW /dev/vdb1         # set label (unmounted)
xfs_admin -U generate /dev/vdb1    # new UUID (e.g., after cloning a disk) [Advanced]
xfs_growfs /data                   # grow to fill the (enlarged) device, while mounted
xfs_repair -n /dev/vdb1            # check only (no changes); UNMOUNTED
xfs_repair /dev/vdb1               # repair; UNMOUNTED
xfs_db -r -c frag /dev/vdb1        # fragmentation report (read-only) [Advanced]
```

> ⚠️ `xfs_repair -L` **zeroes the log** and can lose recent metadata changes. Use it only after mounting (to replay the log) has failed. There's no `fsck` for XFS (`fsck.xfs` does nothing); never repair a mounted filesystem.

Newer xfsprogs can relabel a mounted XFS: `xfs_io -c 'label -s NEW' /data` **[Advanced]**.

## 7. RHCSA Exam Focus **[RHCSA Core]**

- Create exactly the requested type: VFAT, ext4 or XFS, on the requested partition/LV, with the requested label if any.
- Verify with `lsblk -f` / `blkid` (type, label, UUID) before writing fstab.
- `mkfs.vfat` comes from **dosfstools**; if it's missing, install it.

## 8. Production Practices **[Production Practice]**

- Default to XFS; choose ext4 if you might need to **shrink** later or for small volumes.
- Keep ext4's reserved blocks on `/` (protects root from a full disk); reduce them on large data volumes.
- After cloning disks or VM images, duplicate filesystem UUIDs can break mounting (XFS refuses duplicate UUIDs): regenerate with `xfs_admin -U generate` or `tune2fs -U random`.
- Never mount the same non-cluster filesystem on two hosts at once; it causes corruption. Use NFS or GFS2.

## 9. Troubleshooting

| Message / symptom | Cause | Fix |
|---|---|---|
| `mkfs.xfs: … appears to contain an existing filesystem` | Old signature | Confirm it's the right device, then `-f` |
| `… is mounted; will not make a filesystem here!` | Device in use | `umount` first (and check it's really the target) |
| `mkfs.vfat: command not found` | Package missing | `dnf install dosfstools` |
| `xfs_admin: … contains a mounted filesystem` | XFS label change while mounted | `umount`, or `xfs_io … label` |
| Label too long / truncated | Length limits | ≤12 XFS, ≤16 ext, ≤11 VFAT |
| `wrong fs type, bad option, bad superblock` on mount | Wrong `-t`, no filesystem, or corruption | `blkid DEV`; check `dmesg`; [repair](filesystem-check-and-repair.md) |
| Disk full but files deleted | Open deleted files / ext4 reserved blocks | `lsof +L1`; `tune2fs -l` |

## 10. Interview Questions

| Question | Answer |
|---|---|
| Why XFS by default on RHEL? | Scales well for large filesystems and parallel I/O; mature journaling; online growth. |
| Can you shrink XFS? | No. Back up, recreate smaller, restore (or use ext4 where shrink matters). |
| What's journaling? | Writing metadata changes to a log first so the filesystem can be made consistent quickly after a crash. |
| Why does `df` show less free space than size − used on ext4? | Reserved blocks for root (5% by default). |
| What does `mkfs` actually do to the data? | Writes new metadata; old data blocks remain until overwritten. |
| How do you change a filesystem's label? | ext: `e2label`/`tune2fs -L`; XFS: `xfs_admin -L` (unmounted). |

## 11. Quick Revision

```bash
mkfs.xfs [-f] [-L L] DEV | mkfs.ext4 [-L L] DEV | mkfs.vfat [-F 32] [-n L] DEV | mkswap DEV
blkid | lsblk -f | e2label | tune2fs -l/-L/-m | xfs_admin -l/-L/-u | xfs_info MNT
grow: xfs_growfs MNT / resize2fs DEV · XFS never shrinks · repair UNMOUNTED: xfs_repair [-n] / e2fsck -f
labels ≤12 XFS ≤16 ext ≤11 VFAT · XFS default on RHEL 10
```

## 12. Cross-References

- [Disks & partitioning](disks-and-partitioning.md)
- [Mounting & fstab](mounting-and-fstab.md)
- [Links & inodes (`df -i`)](../users-groups-and-permissions/links.md)
- [LVM & resizing](lvm-fundamentals.md) · [Swap](swap.md) · [Filesystem check & repair](filesystem-check-and-repair.md) · [Storage I/O path](storage-io-path.md)
