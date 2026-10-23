# VG Merge/Split, Renaming & Online Disk Migration (pvmove)

> **Sessions:** S37–S38 · `vgextend`/`vgreduce` support *Assign physical volumes to volume groups* **[RHCSA Core]** · merge/split/pvmove **[Advanced/Optional]**
> **Related:** [LVM fundamentals](lvm-fundamentals.md) · [LVM snapshots & recovery](lvm-snapshots-and-recovery.md) · [Mounting & fstab](mounting-and-fstab.md)

## 1. Overview

LVM can reorganize storage without touching filesystems:

- **`vgmerge`** combines two VGs into one.
- **`vgsplit`** moves PVs (and the LVs on them) into a new or existing VG.
- **`pvmove`** migrates extents from one PV to another **while the LV stays online**, the standard way to replace or retire a disk.

## 2. Merging VGs (`vgmerge`)

```bash
umount /test2
vgchange -an vg2                 # source VG must be INACTIVE
vgmerge vg1 vg2                  # merge vg2 INTO vg1 (vg2 disappears)
vgs ; lvs                        # lv2 is now vg1/lv2
lvchange -ay vg1/lv2
mount /dev/vg1/lv2 /test2
```

Conditions:

- The source VG must be inactive.
- Both VGs must use the **same PE size**.
- LV names must not clash (`lvrename` first if needed).
- LV paths change (`/dev/vg2/lv2` → `/dev/vg1/lv2`). Update fstab entries that use the **path**; `UUID=` entries keep working.

## 3. Splitting a VG (`vgsplit`)

```bash
umount /test1 /test2
vgchange -an vg1                 # LVs on the moving PVs must be inactive
vgsplit vg1 vg2 /dev/sdb1        # move PV /dev/sdb1 (and LVs wholly on it) into new VG vg2
vgchange -ay vg1 vg2
lvs -o +devices                  # confirm placement
mount /dev/vg1/lv1 /test1 ; mount /dev/vg2/lv2 /test2
```

Every LV must sit **entirely** on the PVs being moved, or entirely on those staying. An LV can't straddle both VGs. Check first with `lvs -o +devices`.

## 4. Renaming

```bash
vgrename vgold vgnew             # update fstab paths, and /etc/default/grub + rebuild if root VG ⚠️
lvrename vgnew lvold lvnew
```

> ⚠️ Renaming the VG that holds `/` or swap breaks booting unless the kernel command line (`rd.lvm.lv=`) and fstab are updated and the bootloader config is rebuilt (S49). Avoid in the exam.

## 5. Migrating Data to a New Disk (`pvmove`)

```bash
lsblk ; fdisk /dev/sdb ; partprobe /dev/sdb   # new partition, type Linux LVM
pvcreate /dev/sdb1
vgextend datavg /dev/sdb1                     # new PV joins the VG
lvs -a -o +devices                            # where does datalv live now? (or: dmsetup deps)
sha256sum /data/cal.txt                       # optional: checksum before
pvmove -n datalv /dev/sda1 /dev/sdb1          # move only datalv's extents  (filesystem stays mounted)
pvmove /dev/sda1                              # or: move ALL extents off sda1 to any free PVs
lvs -a -o +devices                            # verify the LV is on sdb1
vgreduce datavg /dev/sda1                     # remove the old PV from the VG
pvremove /dev/sda1                            # wipe its LVM label (disk can now be removed/reused)
sha256sum /data/cal.txt                       # optional: compare
```

- `pvmove` works through a temporary mirror. It's online but I/O-heavy; run it in quiet hours.
- If interrupted (reboot, crash), run `pvmove` with no arguments to resume, or `pvmove --abort` to roll back.
- `vgreduce` refuses while the PV still holds extents; `pvs` should show it fully free (`PFree` = `PSize`).
- `vgreduce --removemissing VG` cleans up a VG after a PV **died** **[Advanced]**.

## 6. Production Practices **[Production Practice]**

- **Disk replacement runbook:** add new PV → `vgextend` → `pvmove` old PV → `vgreduce` → `pvremove` → detach disk. No downtime.
- Use `UUID=` in fstab so VG renames/merges don't break mounts.
- Throttle long moves with I/O scheduling or run them in maintenance windows; monitor with `lvs -a` (Cpy%Sync).
- Moving a whole VG to another server (`vgexport`/`vgimport`) is covered in S41.

## 7. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `vgmerge: … must be inactive` | Source VG active | `umount`; `vgchange -an SRC` |
| `vgmerge: extent sizes differ` | Different PE sizes | Can't merge directly; migrate data instead |
| `vgsplit: Logical volume … must be inactive` / split across PVs | LV active or straddles PVs | Deactivate; `pvmove` extents first so each LV is on one side |
| `vgreduce: … still in use` | PV holds extents | `pvmove` it first |
| `No extents available for allocation` (pvmove) | Destination too small | Add a bigger PV |
| Mount fails after merge | fstab uses the old `/dev/vg2/…` path | Update the path, or use `UUID=` |

## 8. Interview Questions

| Question | Answer |
|---|---|
| How do you replace a disk under LVM with no downtime? | Add the new PV to the VG, `pvmove` the old PV's extents, `vgreduce`, `pvremove`, remove the disk. |
| Can `pvmove` run with the filesystem mounted? | Yes; it's online. |
| What are the requirements for `vgmerge`? | Source VG inactive, same PE size, no LV name conflicts. |
| What does `vgsplit` require? | LVs must be entirely on the moving PVs (or entirely not) and inactive. |
| How do you see which disks an LV uses? | `lvs -a -o +devices` (or `pvs -o +lv_name`, `dmsetup deps`). |

## 9. Course Corrections

| Course | Correction |
|---|---|
| `ls -l /dev/ \| grep sd*` | Unquoted `sd*` is expanded by the shell first; use `ls -l /dev/sd*` or `lsblk` |
| Migration ends at `vgreduce` | Also `pvremove /dev/sda1` to wipe the label |
| "Create new primary partition" | MBR wording; on GPT just create a partition |
| `md5sum` validation | Fine for copy checks; `sha256sum` preferred |

## 10. Quick Revision

```bash
vgchange -an SRC ; vgmerge DEST SRC ; lvchange -ay DEST/LV
vgchange -an VG ; vgsplit VG NEWVG PV ; vgchange -ay VG NEWVG
vgrename · lvrename · lvs -a -o +devices
pvcreate NEW → vgextend VG NEW → pvmove [-n LV] OLD [NEW] → vgreduce VG OLD → pvremove OLD
pvmove (resume) · pvmove --abort · vgreduce --removemissing
```

## 11. Cross-References

- [LVM fundamentals](lvm-fundamentals.md)
- [LVM snapshots & recovery](lvm-snapshots-and-recovery.md)
- [Mounting & fstab](mounting-and-fstab.md)
- Thin provisioning, striping, VG export/import (S39–41): planned
