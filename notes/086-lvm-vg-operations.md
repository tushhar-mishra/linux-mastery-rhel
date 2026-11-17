# 086 · LVM Volume Group Operations: pvmove, Merge, Split, Rename, Move Between Hosts

> **You need first:** [085 · LVM thin provisioning and striping](085-lvm-thin-and-striping.md)
> **Next:** [087 · RAID with mdadm](087-raid-mdadm.md)

---

## What it is

LVM can **reorganise storage without touching the filesystems** on it:

| Tool | Does |
|---|---|
| **`pvmove`** | Moves data off one disk onto another **while the volumes stay online**. The standard way to replace a disk |
| `vgextend` / `vgreduce` | Add / remove a PV to / from a volume group |
| `vgmerge` | Combines two VGs into one |
| `vgsplit` | Moves some PVs (and the LVs entirely on them) into a new VG |
| `vgrename`, `lvrename` | Rename a VG or LV |
| `vgexport` / `vgimport` | Hand a VG cleanly from one server to another |
| `lvmdevices`, `vgimportdevices` | Tell LVM (RHEL 9/10) which disks it may use |
| `vgimportclone` | Import a **cloned** disk whose IDs duplicate an existing VG |

## Why it exists

Disks age, fail, get replaced with bigger ones, or move from one server to another (a SAN LUN re-mapped, a cloud volume detached and re-attached). Without LVM, each of those means downtime and copying data around. With LVM, a disk swap is five commands and **zero downtime**, and a whole volume group can travel to another host with its volumes intact.

## Analogy

`pvmove` is **moving house one box at a time while you keep living there**: the furniture (data) is carried to the new house (the new disk) and your address (`/dev/vg/lv`) never changes, so the postman (the mounted filesystem) never notices. `vgexport`/`vgimport` is **properly handing a storage unit's keys to a new owner**: the old owner signs it off, the new owner signs it in.

## How it works inside

- **`pvmove` uses a temporary mirror.** For each segment it creates a hidden mirror LV between the old and new PV, copies the data while new writes go to both, and when they're in sync, switches the LV's mapping to the new PV. The filesystem keeps running throughout. Progress is checkpointed in the LVM metadata, so an interrupted move (reboot, crash) can be **resumed** by running `pvmove` again, or **rolled back** with `pvmove --abort`.
- **LVM metadata lives on every PV** in the VG (topic 049). That's what lets a disk carry its VG to another machine.
- **RHEL 9/10's devices file** (`/etc/lvm/devices/system.devices`) lists the devices LVM may use. A disk arriving from another system is **ignored** (`pvs` shows nothing) until you add it. This stops LVM from accidentally grabbing disks that belong to someone else.
- `vgexport` marks a VG as "not owned here", so it can't be activated by accident until `vgimport`.
- **Cloned disks** (copied VM images or array snapshots) carry the **same** PV/VG UUIDs as the original. LVM refuses duplicates; `vgimportclone` gives the copy new UUIDs and a new name.

## Commands

### Replace a disk with no downtime (the most common task)

```bash
lsblk ; sudo lvs -a -o +devices datavg
```
```
  LV     VG     Attr       LSize Devices
  datalv datavg -wi-ao---- 4.00g /dev/vdb1(0)
```
```bash
sudo pvcreate /dev/vdc1
sudo vgextend datavg /dev/vdc1
sha256sum /data/important.db > /tmp/before.sum        # optional integrity check
sudo pvmove /dev/vdb1 /dev/vdc1                       # filesystem stays mounted
```
```
  /dev/vdb1: Moved: 12.50%
  /dev/vdb1: Moved: 50.00%
  /dev/vdb1: Moved: 100.00%
```
```bash
sudo lvs -a -o +devices datavg                        # now on /dev/vdc1
sudo vgreduce datavg /dev/vdb1                        # take the old PV out of the VG
sudo pvremove /dev/vdb1                               # wipe its LVM label; the disk can be removed
sha256sum -c /tmp/before.sum
```
- `pvmove -n datalv /dev/vdb1 /dev/vdc1` moves only one LV. `pvmove /dev/vdb1` (no destination) moves everything to any PVs with free space.
- It's I/O-heavy: run it in quiet hours. Watch progress with `lvs -a` (the `Cpy%Sync` column).
- Interrupted? `sudo pvmove` resumes; `sudo pvmove --abort` rolls back.
- `vgreduce` refuses while the PV still holds data: `pvs` must show `PFree` = `PSize` first.
- A PV that **died** (not just retired): `sudo vgreduce --removemissing datavg` (the LVs on it are lost unless mirrored/RAID).

### Merge two VGs

```bash
sudo umount /test2
sudo vgchange -an vg2           # the SOURCE VG must be inactive
sudo vgmerge vg1 vg2            # vg2 is merged INTO vg1 and disappears
sudo lvchange -ay vg1/lv2
```
- Both VGs need the **same extent size** and no clashing LV names. The device path changes (`/dev/vg2/lv2` → `/dev/vg1/lv2`), so fstab entries using paths must be updated (`UUID=` entries keep working).

### Split a VG

```bash
sudo lvs -o +devices vg1                # each LV must be ENTIRELY on the moving PVs or entirely not
sudo umount /test1 /test2 ; sudo vgchange -an vg1
sudo vgsplit vg1 vg2 /dev/vdd1          # move PV vdd1 and the LVs on it into new VG vg2
sudo vgchange -ay vg1 vg2
```

### Rename

```bash
sudo vgrename vgold vgnew
sudo lvrename vgnew lvold lvnew
```
- Renaming the VG holding `/` or swap breaks booting unless you also update fstab, the kernel arguments (`rd.lvm.lv=`, topic 054) and rebuild the initramfs. Avoid it on system VGs.

### Move a VG to another server

**On the source:**
```bash
sudo umount /appdata
sudo vi /etc/fstab                      # remove its entry FIRST, or the source won't boot cleanly
sudo vgchange -an appvg
sudo vgexport appvg
sudo vgs -o vg_name,vg_attr appvg       # 'x' in the attributes = exported
sudo cp /etc/lvm/backup/appvg /root/appvg.meta.backup   # keep the metadata backup safe, off-host
```
Detach the disk (or re-map the LUN, or detach the cloud volume).

**On the target:**
```bash
lsblk ; sudo blkid /dev/vdb             # TYPE="LVM2_member"
sudo pvs                                # probably shows nothing yet (devices file)
sudo vgimportdevices appvg              # or: sudo lvmdevices --adddev /dev/vdb
sudo vgimport appvg
sudo vgchange -ay appvg
sudo mkdir -p /appdata ; sudo mount /dev/appvg/applv /appdata
```
Add an fstab line by UUID (topic 048).

**Name clash** (both machines have a VG called `rhel`):
```bash
sudo vgs -o vg_name,vg_uuid
sudo vgrename <UUID-of-the-imported-one> rhel_old
```

**Cloned disk** (duplicate UUIDs):
```bash
sudo vgimportclone --basevgname data_clone /dev/vdc
```

### Last-resort metadata recovery (damaged PV label)

Only when you're **certain** which disk held the VG and you have the metadata backup file:
```bash
grep -A3 'pv0' /root/appvg.meta.backup       # find the PV's old UUID
sudo pvcreate --uuid "<PV-UUID>" --restorefile /root/appvg.meta.backup /dev/vdb
sudo vgcfgrestore -f /root/appvg.meta.backup appvg
sudo vgchange -ay appvg ; sudo mount -o ro /dev/appvg/applv /mnt     # read-only first, verify
```
The wrong device or UUID here destroys data.

### Try it
1. Put an LV with some files on `vdb1`, then `pvmove` it to `vdc1` while a loop keeps writing to the filesystem. Compare checksums afterwards.
2. Reboot in the middle of a long `pvmove` (use a large LV) and resume it.
3. Export a VG on server1, attach its virtual disk to server2, import and mount it there.
4. Merge two small VGs and fix the fstab path.

## Where you'll use it

- **Storage refreshes:** move every LV off old SAN LUNs or disks onto new ones during business hours.
- **Cloud:** swap a volume type (e.g. gp2 → gp3, or onto a faster disk) by attaching the new volume and running `pvmove`.
- **Disaster recovery / migrations:** detach data volumes from a dead VM and attach them to a new one (`vgimportdevices` + `vgimport`).
- **Lab clones:** `vgimportclone` when mounting a snapshot or clone of a disk on the same host as its original.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `lvcreate` asks `WARNING: xfs signature detected … Wipe it? [y/n]` and, in a script, aborts with `Failed to wipe start of new LV` | The new LV landed on extents that still hold an old filesystem signature (common after removing and re-creating LVs) | Answer `y` interactively; in scripts use `lvcreate -y -Wy …`. Note that `-q` does **not** mean yes: it answers no |
| `pvs`/`vgs` show nothing for a moved disk | It's not in the LVM devices file | `vgimportdevices VG` or `lvmdevices --adddev DEV` |
| `Volume group "X" is exported` | Not imported | `vgimport X` |
| `Multiple VGs found with the same name` | Name clash | `vgrename <VG-UUID> newname` |
| `WARNING: PV … has duplicate PV UUID` | A cloned disk | `vgimportclone` |
| `vgmerge: … must be inactive` / `extent sizes differ` | Source active / different PE sizes | Deactivate it / migrate data with pvmove instead |
| `vgsplit` refuses | An LV is active or spans both groups of PVs | Deactivate; `pvmove` so each LV is on one side |
| `vgreduce: … still in use` | The PV still holds extents | `pvmove` it first |
| `No extents available for allocation` (pvmove) | The destination is too small | Add a bigger PV |
| A mount fails after a merge or rename | fstab uses the old path | Update it, or use `UUID=` |
| The source host won't boot after the move | fstab still lists the removed LV | Fix fstab from the emergency shell (topic 057) |

## Quick recap

- Replace a disk online: `pvcreate NEW` → `vgextend VG NEW` → **`pvmove OLD NEW`** → `vgreduce VG OLD` → `pvremove OLD`. Resume with `pvmove`; roll back with `--abort`.
- `vgmerge DEST SRC` (SRC inactive, same PE size), `vgsplit VG NEW PV` (LVs wholly on one side), `vgrename`/`lvrename` (careful with the root VG).
- Move between hosts: umount → fstab → `vgchange -an` → `vgexport` → detach → `vgimportdevices` → `vgimport` → `vgchange -ay` → mount.
- Duplicates: `vgrename <UUID>` for name clashes, `vgimportclone` for cloned disks. Keep `/etc/lvm/backup` copies.

**Interview questions**

1. *How do you replace a disk under LVM with no downtime?* Add the new disk as a PV to the VG, `pvmove` the old PV's extents onto it (online), then `vgreduce` the old PV out of the VG and `pvremove` it.
2. *A disk carrying a VG was attached to a new RHEL 9 server, but `pvs` shows nothing. Why?* RHEL 9/10's LVM devices file limits which devices LVM scans. Add the disk with `vgimportdevices VG` or `lvmdevices --adddev`.
3. *What happens if `pvmove` is interrupted by a reboot?* Progress is recorded in the LVM metadata, so running `pvmove` again resumes it, or `pvmove --abort` rolls it back. The LV stays usable throughout.
