# Filesystem Check & Repair (e2fsck, fsck, xfs_repair)

> **Sessions:** S48 · **[Advanced/Optional]** (not a named RHEL 10 objective) · essential production troubleshooting
> **Related:** [Filesystems & mkfs](filesystems-and-mkfs.md) · [Mounting & fstab](mounting-and-fstab.md) · [Filesystem hierarchy (read-only remounts)](../linux-fundamentals/filesystem-hierarchy.md) · boot & rescue (S49–51, planned)

## 1. Overview

Filesystems can become inconsistent after crashes, power loss, storage faults or bugs. Repair tools check the metadata (superblocks, inodes, directories, allocation maps) and fix inconsistencies. **Journaling** (XFS, ext3/4) makes most crashes recover automatically at mount, so full repairs are needed less often.

**Signs you need a check:** mount fails (`wrong fs type, bad superblock`), kernel messages about corruption (`dmesg`, `journalctl -k`), the filesystem was remounted **read-only**, or I/O errors.

## 2. Golden Rules

1. **Never repair a mounted filesystem.** Confirm with `findmnt DEV` and `lsof`/`fuser` that it's fully unmounted. **Don't use `umount -l`** (lazy) before a repair; the filesystem stays in use.
2. **Check read-only first** (`-n`) to see what would change.
3. For critical data, **image or back up first** (`dd`/snapshot), because repairs can delete damaged files.
4. Fix the **cause** too: check the disk (`dmesg`, SMART, RAID status).

## 3. Tools

| Filesystem | Tool | Package |
|---|---|---|
| ext2/3/4 | `e2fsck` (also via `fsck` / `fsck.ext4`) | e2fsprogs |
| XFS | `xfs_repair` (`fsck.xfs` is a no-op) | xfsprogs |
| VFAT | `fsck.vfat` | dosfstools |
| Any (front end) | `fsck` dispatches to the type-specific checker | util-linux |

## 4. ext4 Repair

```bash
findmnt /dev/vdb1 ; umount /data                   # must be unmounted
e2fsck -n /dev/vdb1                                # read-only check: report only
e2fsck -f /dev/vdb1                                # force a full check, interactive
e2fsck -f -y /dev/vdb1                             # answer yes to all fixes
e2fsck -p /dev/vdb1                                # "preen": fix safe problems automatically
mount /data ; ls /data/lost+found                  # recovered orphaned files land here (named by inode)
```

### Damaged primary superblock

```bash
dumpe2fs /dev/vdb1 | grep -i 'backup superblock'   # list backup superblock locations
mke2fs -n /dev/vdb1                                # alternative listing; -n = DRY RUN ONLY ⚠️
e2fsck -b 32768 /dev/vdb1                          # repair using a backup superblock
```

> ⚠️ `mke2fs` **without** `-n` reformats the device.

### `fsck` front-end vs `e2fsck` options

| `fsck` front-end | Meaning |
|---|---|
| `-A` | Check all filesystems in fstab (by pass number) |
| `-R` | With `-A`, skip root |
| `-M` | Skip mounted filesystems |
| `-t TYPE` | Only this type |
| `-N` | Show what would run (dry run) |

| `e2fsck` (passed through) | Meaning |
|---|---|
| `-n` | Read-only, answer "no" |
| `-y` | Answer "yes" to all |
| `-p` | Automatic safe repair (preen) |
| `-f` | Force a check even if marked clean |
| `-v` | Verbose |
| `-c` | Scan for bad blocks (badblocks) |
| `-b N` | Use a backup superblock |

### Boot-time checks

- The fstab 6th field controls order: `1` = root only, `2` = other ext filesystems, `0` = skip (XFS, swap, network).
- systemd-fsck runs these at boot. Force a full check on next boot with kernel arguments `fsck.mode=force fsck.repair=yes` (e.g., add once via the GRUB editor).

## 5. XFS Repair

```bash
umount /xfsdata                                    # must be unmounted (no lazy umount)
mount /xfsdata && umount /xfsdata                  # mounting first replays the journal (log)
xfs_repair -n /dev/vdc1                            # dry run: report only
xfs_repair /dev/vdc1                               # repair; don't interrupt
mount /xfsdata ; ls /xfsdata/lost+found
```

- **`xfs_repair -L`** zeroes a damaged log. It's a **last resort** after mounting (log replay) fails, because recent metadata changes are lost.
- `xfs_metadump` captures metadata for vendor support **[Advanced]**.

## 6. Root Filesystem

You can't unmount `/` on a running system:

| Filesystem | Approach |
|---|---|
| ext4 root | Reboot with `fsck.mode=force fsck.repair=yes` on the kernel command line |
| XFS root | Boot RHEL installation media → *Troubleshooting* → *Rescue a RHEL system* → choose to **skip** mounting the system → `xfs_repair /dev/mapper/rhel-root` |

Rescue and emergency procedures are covered in S51/S67.

## 7. Production Practices **[Production Practice]**

- Treat repeated corruption as a **hardware or storage** problem: check `dmesg`, SMART (`smartctl`), RAID/multipath state.
- Snapshot or image before repairing critical volumes.
- After a repair, verify application data integrity (checksums, database consistency tools).
- Keep XFS fsck pass at `0`; repairs are manual by design.

## 8. Troubleshooting

| Message / symptom | Cause | Fix |
|---|---|---|
| `e2fsck: Cannot continue, aborting.` / `… is mounted` | Filesystem in use | Unmount; use rescue for root |
| `Bad magic number in super-block` | Primary superblock damaged (or wrong device/type) | Confirm with `blkid`; `e2fsck -b <backup>` |
| `xfs_repair: … contains a mounted filesystem` | Still mounted | `findmnt`; unmount fully |
| `ERROR: The filesystem has valuable metadata changes in a log…` | Dirty XFS log | Mount/unmount to replay; `-L` only if mounting fails |
| Filesystem remounted read-only | Kernel detected errors | `dmesg`; fix storage; unmount and repair |
| Files appear in `lost+found` | Orphaned inodes reconnected by repair | Identify with `file`, restore names from backups |

## 9. Interview Questions

| Question | Answer |
|---|---|
| Why not run fsck on a mounted filesystem? | The kernel and fsck would modify metadata concurrently, causing corruption. |
| How do you repair XFS? | Unmount, mount/unmount to replay the log, `xfs_repair -n`, then `xfs_repair`; `-L` only as a last resort. |
| What is `lost+found`? | Where repair tools reconnect files whose directory entries were lost. |
| How do you repair a damaged ext4 superblock? | Find backups (`dumpe2fs`), then `e2fsck -b <backup>`. |
| How do you check the root filesystem? | ext4: `fsck.mode=force` at boot; XFS: repair from rescue media. |

## 10. Course Corrections

| Course | Correction |
|---|---|
| "Force unmount (`umount -l`) before repair" | Dangerous; lazy unmount leaves it in use. Fully unmount instead |
| fstab `/dev/sdb /ext3_data ext3 defaults 0 1` | Pass `1` is for root only; data uses `2` (and `UUID=`) |
| One options table for `fsck` | `-A -R -M -t` are front-end options; `-n -y -p -f -c -b` belong to e2fsck |
| "NEVER run fsck on XFS: will damage data" | `fsck.xfs` is a harmless no-op; use `xfs_repair` |
| `xfs_repair -L` as an optional step | Try mounting (log replay) first; `-L` is the last resort |

## 11. Quick Revision

```bash
UNMOUNT FIRST (no -l) → read-only check → repair → mount → check lost+found
ext: e2fsck -n | -f | -f -y | -p | -b BACKUP ; dumpe2fs | grep -i superblock ; mke2fs -n (dry run!)
fsck -A -R -M -t TYPE -N (front end) · fstab pass 1 root / 2 others / 0 xfs
xfs: mount+umount (replay) → xfs_repair -n → xfs_repair → -L last resort
root: fsck.mode=force (ext4) · rescue media (XFS)
