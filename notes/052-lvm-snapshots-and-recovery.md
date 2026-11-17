# 052 · LVM Snapshots and Metadata Recovery

> **You need first:** [051 · Filesystem check and repair](051-filesystem-check-and-repair.md)
> **Next:** [053 · The boot process](053-boot-process.md)

---

## What it is

- An **LVM snapshot** is an instant, point-in-time **frozen view** of a logical volume. Creating one takes a second, no matter how big the volume is. You can mount it to copy files out, back it up, or **merge** it to roll the original volume back.
- **LVM metadata backups** are text copies of each volume group's layout that LVM saves automatically on every change (`/etc/lvm/backup/`, `/etc/lvm/archive/`). With `vgcfgrestore`, they can often bring back an **accidentally deleted LV**.

This topic covers classic ("thick") snapshots. Thin snapshots, which scale much better, are in topic 085.

## Why it exists

- **Safe changes:** snapshot `/` or a database volume before an upgrade. If it goes wrong, merge back in minutes.
- **Consistent backups:** a live database or log directory keeps changing while `tar` runs. A snapshot gives you a frozen copy to back up calmly.
- **Undo mistakes:** `lvremove` on the wrong volume isn't necessarily the end, if you act fast.

## Analogy

A snapshot is a **"before" photograph**. It doesn't copy the whole house when taken. Instead, every time someone is about to repaint a wall, a helper first takes a **photo of that one wall** and files it. To see the "before" house, you look at the filed wall photos plus the walls nobody touched. If the folder for wall photos fills up, the photo set becomes useless. Merging = repainting every changed wall back to how it was in the photos.

## How it works inside

### Copy-on-write (COW)

1. `lvcreate -s` creates a snapshot LV with its own **COW area** (the size you give it). Initially it's empty.
2. When a block on the **origin** LV is about to be overwritten **for the first time** after the snapshot, LVM (device mapper, topic 049) first **copies the old block into the COW area**, then lets the write happen.
3. Reading the snapshot returns old blocks from the COW area for changed blocks, and blocks straight from the origin for unchanged ones.
4. The snapshot only needs space for the blocks that **change** while it exists.

Consequences:
- **If the COW area fills up, the snapshot becomes invalid** and unusable. Size it for the amount of change you expect.
- Every **first write** to an origin block costs an extra read and write, so the origin gets slower while snapshots exist. Keep them short-lived.
- **A snapshot is not a backup.** It lives on the same disks as the origin and dies with them.

**Sizing:** a few edits → 5–10% of the origin; an OS upgrade or a data load → 20–100%. A snapshot as big as the origin can never overflow.

### Metadata backups

Every LVM command that changes a VG writes:
- `/etc/lvm/backup/VG`: the **current** layout;
- `/etc/lvm/archive/VG_NNNNN-*.vg`: the layout **before** the change, with the command that made it.

`vgcfgrestore` writes an old layout back to the PVs. It restores the **map** (which extents belong to which LV), **not the data**. If the deleted LV's extents haven't been reused yet, the data is still sitting there untouched, and the LV comes back intact.

## Commands

### Create and inspect a snapshot

```bash
sudo vgs                                                       # VFree must cover the snapshot
sudo lvcreate -s -L 1G -n lvweb_snap /dev/vgdata/lvweb
sudo lvs
```
```
  Logical volume "lvweb_snap" created.
  LV         VG     Attr       LSize Pool Origin Data%  Meta%
  lvweb      vgdata owi-aos--- 1.49g
  lvweb_snap vgdata swi-a-s--- 1.00g      lvweb  0.01
```
- In `Attr`: `o` = origin, `s` = snapshot. `Origin` shows which LV it belongs to.
- **`Data%`** = how full the COW area is. Watch it: at 100% the snapshot is invalid.

### Get files out of it

```bash
sudo mkdir -p /mnt/snap
sudo mount -o ro,nouuid /dev/vgdata/lvweb_snap /mnt/snap     # XFS needs nouuid (same UUID as the origin)
sudo cp -a /mnt/snap/index.html /web/                         # restore one file
```
- ext4 snapshots mount with just `-o ro`.

### Consistent backup

```bash
sudo lvcreate -s -L 2G -n backup_snap /dev/vgdata/lvdb
sudo mount -o ro /dev/vgdata/backup_snap /mnt/snap
sudo tar -czf /backup/db-$(date +%F).tgz -C /mnt/snap .
sudo umount /mnt/snap ; sudo lvremove -y /dev/vgdata/backup_snap
```
- For databases, also flush or briefly lock the database before snapshotting, so its files are consistent (or use the database's own backup tool).

### Roll back the whole LV (merge)

```bash
sudo umount /mnt/snap ; sudo umount /web
sudo lvconvert --merge /dev/vgdata/lvweb_snap
sudo mount /web
```
```
  Merging of volume vgdata/lvweb_snap started.
  vgdata/lvweb: Merged: 100.00%
```
- The origin returns to the snapshot's state and the snapshot disappears.
- If the origin is still in use (for example the root filesystem), the merge is **deferred** until the origin is next activated, which means the **next reboot**. That's the standard "snapshot root, upgrade, roll back by rebooting" technique.

### Remove a snapshot

```bash
sudo umount /mnt/snap ; sudo lvremove /dev/vgdata/lvweb_snap
```

### Automatic snapshot growth

In `/etc/lvm/lvm.conf`, set `snapshot_autoextend_threshold = 70` and `snapshot_autoextend_percent = 20`. The LVM monitoring service then grows a snapshot by 20% whenever it passes 70% full (as long as the VG has free space).

### Recover a deleted LV

```bash
sudo vgcfgrestore --list vgdata
```
```
  File:		/etc/lvm/archive/vgdata_00007-1739461234.vg
  VG name:    	vgdata
  Description:	Created *before* executing 'lvremove /dev/vgdata/lvdb'
  Backup Time:	Mon Nov 16 16:40:02 2026
```
- Find the archive taken **before** the mistake.

```bash
sudo vgcfgrestore --test -f /etc/lvm/archive/vgdata_00007-1739461234.vg vgdata   # dry run
sudo vgcfgrestore -f /etc/lvm/archive/vgdata_00007-1739461234.vg vgdata
sudo lvchange -ay /dev/vgdata/lvdb
sudo mount -o ro /dev/vgdata/lvdb /db        # read-only first, check the data, then remount rw
```
- If other LVs in the VG are still active, `vgcfgrestore` (even with `--test`) warns `Restoring VG with active LVs, may cause mismatch with its metadata` and asks `Do you really want to proceed … [y/n]`. Restoring an archive that differs only by the removed LV is safe, so answer `y`. If you can, unmount and deactivate the other LVs first (`vgchange -an vgdata`), which avoids the question.
- Pick the archive by its **Description**: you want the one `Created *before* executing 'lvremove …'`, usually the newest file in `/etc/lvm/archive/`.- **Stop all writes to the VG immediately** after an accidental `lvremove`. Any new LV or growth could reuse the freed extents and overwrite the data. VGs with thin pools need `--force` and extra care.

```bash
sudo vgcfgbackup vgdata          # take a manual metadata backup now
```

### Try it
1. Create a snapshot of an LV, then delete a file on the origin and copy it back from the snapshot.
2. Write a lot of data to the origin and watch `Data%` grow. Make a tiny snapshot (100M), overflow it on purpose, and see it marked invalid.
3. Snapshot an LV, make several changes, then `lvconvert --merge` and confirm the changes are gone.
4. Delete a test LV and bring it back with `vgcfgrestore`.

**Check your work:** on your lab VM, from the notes folder, run `sudo ./checks/check 052` for every step, or `sudo ./checks/check 052 STEP` for one (topic 002 shows how to get the notes there).

## Where you'll use it

- **Before patching or upgrades:** snapshot, upgrade, test, then remove the snapshot (success) or merge it (roll back).
- **Backups of live data** (databases, mail stores, web roots): snapshot → back up from the snapshot → remove it.
- **Mistake recovery:** `vgcfgrestore` after a wrong `lvremove`.
- **The same idea everywhere:** cloud volume snapshots (EBS), VM snapshots, Kubernetes `VolumeSnapshot`, and container image layers all rely on copy-on-write.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `Insufficient free space for snapshot` | The VG has no free extents | `vgextend`, or a smaller snapshot |
| The snapshot is `Invalid` / I/O errors | The COW area overflowed | Remove it; recreate it bigger; enable autoextend |
| `mount: wrong fs type … ` / duplicate UUID (XFS) | The snapshot has the same UUID as the origin | `mount -o nouuid` |
| The merge doesn't happen | The origin is in use | Unmount or deactivate it, or reboot |
| The restored LV has corrupt data | Its extents were reused after the deletion | Restore from a real backup |
| The origin got slow | COW overhead | Remove old snapshots |

## Quick recap

- `lvcreate -s -L SIZE -n SNAP /dev/VG/LV` = an instant copy-on-write snapshot. Watch `lvs` `Data%`: full = invalid.
- Mount read-only (`nouuid` for XFS) to copy files out; `lvconvert --merge` to roll back; `lvremove` when done.
- A snapshot is not a backup (same disks), but it's the way to make **consistent** backups.
- `/etc/lvm/archive` + `vgcfgrestore -f FILE VG` restores the metadata (the map), not the data. Stop writes first.

**Interview questions**

1. *How does an LVM snapshot work?* Copy-on-write: before a block on the origin is overwritten for the first time, the original is copied into the snapshot's COW area. Reading the snapshot combines those saved blocks with the unchanged blocks from the origin.
2. *What happens when a snapshot fills up?* It becomes invalid and can't be used. You must size it for the expected amount of change, or enable autoextend.
3. *How would you recover an LV that was deleted by mistake?* Stop writing to the VG, find the archive taken before the `lvremove` with `vgcfgrestore --list`, test it, restore it, activate the LV, and mount it read-only to verify. It only works if the extents haven't been reused.

**Scenario question** (answer out loud first, then compare)

> *"You must upgrade an application that changes its data files, and you need a fast way back if it goes wrong. The data is on LVM. Plan it."*

**Model answer:**
1. Check the VG has free space for the snapshot: about the amount of data you expect the upgrade to change, plus a margin.
2. Stop or quiesce the app (or flush the database) so the snapshot is **consistent**.
3. `lvcreate -s -L 5G -n data_pre_upgrade /dev/vg/data`.
4. Upgrade, and watch the snapshot fill: `lvs` `Data%`. A snapshot that reaches 100% becomes **invalid**.
5. If it fails: stop the app, unmount, `lvconvert --merge /dev/vg/data_pre_upgrade`. The origin returns to the snapshot's state (the merge finishes on the next activation if the LV was busy).
6. If it succeeds: `lvremove` the snapshot (it slows writes while it exists).
7. A snapshot is **not a backup**: it lives on the same disks. Take a real backup too.

**Likely follow-ups:**
- *Why mount an XFS snapshot with `-o nouuid`?* It has the same UUID as the mounted origin, which XFS refuses otherwise.
- *What does `vgcfgrestore` restore?* The LVM metadata (the map of extents), not the data.
