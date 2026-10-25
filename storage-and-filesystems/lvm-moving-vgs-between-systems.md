# Moving LVM Volume Groups Between Systems

> **Sessions:** S41 · **[Advanced/Optional]** · production disk moves, SAN re-mapping, VM disk re-attachment
> **Related:** [LVM fundamentals](lvm-fundamentals.md) · [LVM snapshots & recovery (metadata backups)](lvm-snapshots-and-recovery.md) · [VG merge/split & migration](lvm-vg-merge-split-and-migration.md) · [Mounting & fstab](mounting-and-fstab.md)

## 1. Overview

LVM stores VG metadata **on the PVs themselves**, so a data disk can be detached from one server and attached to another with its VGs and LVs intact. The clean procedure:

1. **Source:** unmount, deactivate and export the VG.
2. Move the disk.
3. **Target:** make the disk visible to LVM, then import, activate and mount.

## 2. Key Concepts

| Concept | Why it matters |
|---|---|
| **Exported VG** (`vgexport`) | Marks the VG as "not owned here"; it can't be activated until `vgimport` |
| **LVM devices file** (RHEL 9/10) | LVM only scans devices listed in `/etc/lvm/devices/system.devices`. A newly attached disk from another system is **ignored** until added |
| **VG name clash** | Two VGs with the same name (e.g., both `rhel`) can't coexist by name; rename one by UUID |
| **Cloned disks** | Identical PV/VG UUIDs (e.g., a cloned VM disk) need `vgimportclone` |
| **Metadata backup** | `/etc/lvm/backup/VG` from the source helps if on-disk metadata is damaged |

## 3. Source System

```bash
umount /my_data
vi /etc/fstab                         # remove/comment the entry, or the source won't boot cleanly later
vgchange -an my_vg                    # deactivate all LVs
vgexport my_vg                        # mark exported
vgs -o vg_name,vg_attr my_vg          # attr shows "x" (exported) in the 3rd position
cp /etc/lvm/backup/my_vg /safe/location/   # keep a copy of the metadata backup off-host
pvs -o pv_name,pv_uuid,vg_name        # note the PV UUID(s)
poweroff                               # then detach the disk (or unmap the LUN / detach the virtual disk)
```

## 4. Target System

```bash
lsblk ; blkid /dev/sdb                 # TYPE="LVM2_member" → LVM PV found
file -s /dev/sdb                       # "LVM2 PV (Linux Logical Volume Manager)…"
pvs                                    # may show nothing: device not in the devices file (RHEL 9/10)
lvmdevices --adddev /dev/sdb           # add it (or: vgimportdevices my_vg)
pvs ; vgs                              # my_vg appears, flagged exported
vgimport my_vg                         # clear the exported flag
vgchange -ay my_vg                     # activate LVs
lvs my_vg
mkdir -p /my_data ; mount /dev/my_vg/my_lv /my_data
blkid /dev/my_vg/my_lv                 # → add UUID=… to /etc/fstab, then systemctl daemon-reload ; mount -a
```

### Name clash on the target

```bash
vgs -o vg_name,vg_uuid                 # two VGs called "rhel"?
vgrename <VG-UUID-of-imported-one> rhel_old   # rename by UUID
```

### Cloned disks (duplicate UUIDs)

```bash
vgimportclone --basevgname data_clone /dev/sdc   # assigns new PV/VG UUIDs and a new VG name
```

## 5. Recovering Damaged Metadata (last resort) ⚠️

Use this only if the disk definitely held this VG, `file -s` shows just `data`, and you have the metadata backup file from the source:

```bash
grep -A3 'pv0' /root/my_vg.backup                     # find the PV UUID (id = "…") and device
pvcreate --uuid "<PV-UUID>" --restorefile /root/my_vg.backup /dev/sdb   # rewrite PV label with the old UUID
vgcfgrestore -f /root/my_vg.backup my_vg               # restore VG metadata
vgchange -ay my_vg ; mount -o ro /dev/my_vg/my_lv /mnt # mount read-only first and verify
```

`-ff` (force) overrides safety checks; add it only if `pvcreate` refuses and you're certain of the device. Wrong device or UUID = data loss.

## 6. Production Practices **[Production Practice]**

- Always export before moving (clean ownership hand-off); keep `/etc/lvm/backup` copies in your config backups.
- Use `UUID=` in fstab on both sides; remove the entry on the source before detaching.
- On SANs, prefer re-mapping LUNs between hosts over physical moves; never present the same VG to two hosts read-write without a cluster manager.
- Avoid generic VG names like `rhel` for data disks; meaningful names prevent clashes.
- Multi-host LVM ownership can also be enforced with LVM system IDs (`lvm systemid`, `vgchange --systemid`) **[Advanced]**.

## 7. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `pvs`/`vgs` show nothing for the moved disk | Not in the LVM devices file | `lvmdevices --adddev /dev/sdX` or `vgimportdevices VG` |
| `Volume group "my_vg" is exported` on activation | Not imported | `vgimport my_vg` |
| `Multiple VGs found with the same name` | Name clash | `vgrename <UUID> newname` |
| `WARNING: PV … has duplicate PV UUID` | Cloned disk | `vgimportclone` |
| `file -s` shows `data`, no LVM label | Label/metadata damaged | Recovery procedure (§5) with the source's backup |
| Source fails to boot after the move | fstab still references the removed LV | Comment the fstab line (emergency shell) |

## 8. Interview Questions

| Question | Answer |
|---|---|
| Where is LVM metadata stored? | On every PV in the VG (plus text backups in `/etc/lvm/backup` and `/etc/lvm/archive`). |
| Steps to move a VG to another server? | Unmount → `vgchange -an` → `vgexport` → move disk → add to devices file → `vgimport` → `vgchange -ay` → mount. |
| Why might `pvs` not show a newly attached PV on RHEL 9/10? | The LVM devices file limits which devices LVM scans. |
| How do you handle two VGs with the same name? | Rename one by UUID with `vgrename`. |
| How do you recover a PV whose label was wiped? | `pvcreate --uuid … --restorefile …`, then `vgcfgrestore -f …`. |

## 9. Quick Revision

```bash
SOURCE: umount → fstab → vgchange -an VG → vgexport VG → save /etc/lvm/backup/VG → detach
TARGET: blkid / file -s → lvmdevices --adddev DEV (or vgimportdevices VG) → vgimport VG → vgchange -ay VG → mount → fstab UUID
clash: vgrename <VG-UUID> NEW · clones: vgimportclone · recovery: pvcreate --uuid U --restorefile F DEV ; vgcfgrestore -f F VG
```

## 10. Cross-References

- [LVM fundamentals](lvm-fundamentals.md)
- [LVM snapshots & recovery](lvm-snapshots-and-recovery.md)
- [VG merge/split & migration](lvm-vg-merge-split-and-migration.md)
- [Mounting & fstab](mounting-and-fstab.md)
