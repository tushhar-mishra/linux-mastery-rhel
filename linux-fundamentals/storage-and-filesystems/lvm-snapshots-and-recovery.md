# LVM Snapshots & Metadata Recovery

> **Sessions:** S36 · **[Advanced/Optional]** (not in the RHEL 10 objectives) · high value for production and interviews
> **Related:** [LVM fundamentals](lvm-fundamentals.md) · [VG merge/split & migration](lvm-vg-merge-split-and-migration.md) · [Archiving & compression (backups)](../files-and-text-processing/archiving-and-compression.md)

## 1. Overview

- An **LVM snapshot** is a point-in-time view of an LV, created instantly. Use it to back up a consistent image, test a risky change, or roll back.
- **LVM metadata backups** (`/etc/lvm/backup`, `/etc/lvm/archive`) record every VG configuration change, so an accidentally removed LV can often be restored with `vgcfgrestore`.

## 2. How Classic (Thick) Snapshots Work

- **Copy-on-write (COW):** the snapshot starts empty. When a block on the **origin** LV is about to change, the original block is first copied into the snapshot's space.
- Reading the snapshot returns the original blocks (from COW space) plus unchanged blocks (from the origin).
- The snapshot only needs space for blocks that **change** while it exists.
- **If the snapshot's space fills up, it becomes invalid** and unusable.
- Writes to the origin are slower while snapshots exist (each first write copies a block).

**Sizing:** a few edits → 5–10% of the origin; heavy changes (upgrades, data loads) → 20–100%. A snapshot the same size as the origin can never overflow.

## 3. Commands

```bash
vgs                                                         # VFree must cover the snapshot size
lvcreate -s -L 1G -n lv_data_snap /dev/vg1/lv_data          # create (= --snapshot --size --name)
lvs                                                         # Origin column; Data% = how full the COW area is
mkdir -p /mnt/snap
mount -o ro /dev/vg1/lv_data_snap /mnt/snap                 # inspect (ext4)
mount -o ro,nouuid /dev/vg1/lv_data_snap /mnt/snap          # XFS: same UUID as origin, so nouuid is required
```

### 3.1 Restore individual files

```bash
cp -a /mnt/snap/important_file.txt /mnt/data/
```

### 3.2 Roll back the whole LV (merge)

```bash
umount /mnt/snap ; umount /mnt/data
lvconvert --merge /dev/vg1/lv_data_snap     # origin reverts to the snapshot state; the snapshot disappears
mount /mnt/data
```

If the origin is still in use, the merge is **deferred** until the origin is next activated. Deactivate and reactivate (`lvchange -an` / `-ay`) or reboot.

### 3.3 Remove a snapshot

```bash
umount /mnt/snap ; lvremove /dev/vg1/lv_data_snap
```

### 3.4 Snapshot-based backup

```bash
lvcreate -s -L 2G -n backup_snap /dev/vg1/lv_data
mount -o ro /dev/vg1/backup_snap /mnt/snap
tar -czf /backup/data-$(date +%F).tgz -C /mnt/snap .
umount /mnt/snap ; lvremove -y /dev/vg1/backup_snap
```

A snapshot is **not** a backup by itself: it lives on the same disks and dies with them.

## 4. Snapshot Caveats

| Risk | Mitigation |
|---|---|
| COW area fills → snapshot invalid | Size generously; watch `lvs` Data%; enable auto-extend [Advanced] |
| Performance overhead on origin writes | Keep snapshots short-lived |
| XFS snapshot won't mount | `-o nouuid` |
| Many long-lived snapshots | Use thin provisioning snapshots instead (S40) |

Auto-extend **[Advanced]**: in `/etc/lvm/lvm.conf`, set `snapshot_autoextend_threshold = 70` and `snapshot_autoextend_percent = 20` (needs LVM monitoring/dmeventd).

## 5. LVM Metadata Backups & `vgcfgrestore`

LVM writes a text copy of each VG's metadata on every change:

| Location | Content |
|---|---|
| `/etc/lvm/backup/VG` | Latest configuration of each VG |
| `/etc/lvm/archive/VG_NNNNN-*.vg` | History: state **before** each change (with the command in the description) |

```bash
vgcfgrestore --list vg1                                   # list archives with times and descriptions
vgcfgbackup vg1                                           # manual backup now
```

### Recover an accidentally removed LV

```bash
vgcfgrestore --list VolGrp                                # find the archive from BEFORE "lvremove"
vgcfgrestore --test -f /etc/lvm/archive/VolGrp_00003-xxxx.vg VolGrp   # dry run
vgcfgrestore -f /etc/lvm/archive/VolGrp_00003-xxxx.vg VolGrp          # restore metadata
lvchange -ay /dev/VolGrp/LogVol                           # activate
mount /dev/VolGrp/LogVol /data                            # data is back IF its extents weren't reused
```

> ⚠️ `vgcfgrestore` restores **metadata only**. If new LVs or writes have reused the freed extents since the deletion, the data is corrupt or lost. Stop writing to the VG immediately after an accidental `lvremove`. Thin-pool VGs need `--force` and extra care.

## 6. Production Practices **[Production Practice]**

- Take a snapshot before risky upgrades or schema changes; merge to roll back or remove when the change is confirmed.
- Monitor snapshot fill (`lvs -o lv_name,data_percent`) and remove snapshots promptly.
- Keep `/etc/lvm` in your configuration backups; copy archives off-host for critical systems.
- Recovery order after an accident: stop writes → `vgcfgrestore --list` → `--test` → restore → activate → mount read-only first → verify.

## 7. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Insufficient free space for snapshot` | VG has no free extents | `vgextend`, or a smaller snapshot |
| Snapshot `Invalid` in `lvs` / I/O errors | COW area overflowed | Remove it; recreate larger |
| `mount: wrong fs type … duplicate UUID` (XFS) | Same UUID as origin | `mount -o nouuid` |
| Merge doesn't happen | Origin in use | Unmount/deactivate origin, or reboot |
| Restored LV has corrupted data | Extents reused after deletion | Restore from real backups |

## 8. Interview Questions

| Question | Answer |
|---|---|
| How do LVM snapshots work? | Copy-on-write: original blocks are copied into snapshot space before they're overwritten on the origin. |
| What happens when a snapshot fills up? | It becomes invalid and unusable. |
| Is a snapshot a backup? | No. It shares the same physical disks; use it to create consistent backups. |
| How do you roll back an LV to a snapshot? | `lvconvert --merge SNAP` (with the origin unmounted, or deferred until next activation). |
| How do you recover a deleted LV? | `vgcfgrestore -f <archive before deletion> VG`, then `lvchange -ay`, if the extents weren't reused. |

## 9. Course Practice Notes

| Course step | Note |
|---|---|
| `lvcreate --size 1G --snapshot --name … /dev/vg1/lv_data` | ✔ (`-s -L 1G -n …` is the short form) |
| Mount the snapshot | Mount `ro`; add `nouuid` for XFS |
| `lvconvert --merge`, then `lvchange -an`/`-ay` | ✔ Deactivate/activate triggers the deferred merge |
| Recovery: `ls -ltrh /etc/lvm/archive` | `vgcfgrestore --list VG` shows descriptions; pick the archive taken **before** `lvremove` |
| `vgcfgrestore VolGrp --test -f filename_latest` | Use the archive from before the deletion (the newest one may already reflect the removal) |

## 10. Quick Revision

```bash
lvcreate -s -L SIZE -n SNAP /dev/VG/LV | lvs (Data%) | mount -o ro[,nouuid] SNAP MNT
cp from snapshot | lvconvert --merge SNAP (origin unmounted) | lvremove SNAP
/etc/lvm/backup (latest) · /etc/lvm/archive (history) · vgcfgbackup · vgcfgrestore --list|--test|-f FILE VG · lvchange -ay
snapshot full → invalid · snapshot ≠ backup · metadata restore ≠ data restore
```

## 11. Cross-References

- [LVM fundamentals](lvm-fundamentals.md)
- [VG merge/split & disk migration](lvm-vg-merge-split-and-migration.md)
- [Archiving & compression](../files-and-text-processing/archiving-and-compression.md)
- Thin provisioning and thin snapshots (S40): planned
