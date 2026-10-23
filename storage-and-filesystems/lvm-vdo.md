# VDO on LVM (Deduplication & Compression)

> **Sessions:** S45 · **[Advanced/Optional]** (in older RHCSA versions, not in RHEL 10's objectives)
> **Related:** [LVM fundamentals](lvm-fundamentals.md) · [LVM thin provisioning](lvm-thin-provisioning-and-striping.md) · [Filesystems & mkfs](filesystems-and-mkfs.md) · Stratis (S46): planned

## 1. Overview

**VDO (Virtual Data Optimizer)** reduces physical storage use with three inline techniques:

1. **Zero-block elimination**
2. **Deduplication** (identical 4 KiB blocks are stored once)
3. **Compression**

Since RHEL 9, VDO is managed through **LVM** (`lvcreate --type vdo`); the old standalone `vdo` manager was removed. On RHEL 10 the VDO target is part of the kernel (`dm-vdo`); the `vdo` package provides tools such as `vdostats`.

## 2. Key Concepts

| Term | Meaning |
|---|---|
| VDO pool LV | Hidden LV holding the deduplicated/compressed **physical** data (`-L`) |
| VDO LV | The volume you format and mount; has a **virtual** size (`-V`) larger than the pool |
| Savings | Depends on data: VM images, backups and logs dedupe/compress well; encrypted, already-compressed or random data doesn't |
| Thin semantics | Like thin pools, the physical pool can fill up; monitor it |

**Red Hat's sizing guidance:** virtual ≈ **10×** physical for VM/container storage, ≈ **3×** for object storage. VDO also needs a minimum pool size of a few GB for its metadata and dedupe index.

## 3. Create & Use

```bash
dnf install -y lvm2 vdo
pvcreate /dev/vdb ; vgcreate vg_vdo /dev/vdb
lvcreate --type vdo -n lv_vdo -L 10G -V 30G vg_vdo/vpool0    # 10G physical pool, 30G virtual LV
lvs -a vg_vdo                                               # lv_vdo (vdo) and [vpool0] (vdo-pool)
mkfs.xfs -K /dev/vg_vdo/lv_vdo                               # -K: skip discards at mkfs (much faster)
mkdir -p /vdo_vol
echo "UUID=$(blkid -s UUID -o value /dev/vg_vdo/lv_vdo) /vdo_vol xfs defaults 0 0" >> /etc/fstab
systemctl daemon-reload ; mount -a
```

## 4. Monitor & Tune

```bash
vdostats --human-readable                                   # physical used, saving %
lvs -a -o lv_name,lv_size,data_percent,vdo_compression,vdo_deduplication vg_vdo
lvchange --compression n vg_vdo/lv_vdo                      # toggle (y/n)
lvchange --deduplication n vg_vdo/lv_vdo
fstrim -v /vdo_vol                                          # return freed blocks to the pool
lvextend -L +5G vg_vdo/vpool0                               # grow PHYSICAL pool
lvextend -L +20G vg_vdo/lv_vdo ; xfs_growfs /vdo_vol        # grow VIRTUAL size + filesystem
```

### Demonstrating savings safely

```bash
dd if=/dev/urandom of=/vdo_vol/random.bin bs=1M count=500   # incompressible: physical grows ~500M
cp /vdo_vol/random.bin /vdo_vol/copy.bin                    # duplicate: physical barely grows
dd if=/dev/zero of=/vdo_vol/zeros.bin bs=1M count=500       # zeros: almost no physical space
sync ; vdostats --human-readable
```

## 5. Production Practices **[Production Practice]**

- Monitor **pool** usage (`vdostats`, `lvs` Data%), not just `df`. A full physical pool causes write failures even when `df` shows space.
- Enable discards (`fstrim.timer`) so deleted data frees pool space.
- Expect extra CPU and RAM use for dedupe and compression.
- Don't put VDO under data that's already compressed or encrypted (encrypt **above** VDO if needed).

## 6. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Writes fail, `df` shows space | Physical pool full | `lvextend` the pool; `fstrim` |
| Little or no savings | Data is random/compressed/encrypted | Expected; VDO isn't suitable |
| `mkfs` very slow | Discarding the whole virtual size | `mkfs.xfs -K` |
| `vdostats: command not found` | Package missing | `dnf install vdo` |
| `lvcreate` refuses small pool | Below VDO minimum | Larger `-L` |

## 7. Interview Questions

| Question | Answer |
|---|---|
| What does VDO do? | Inline zero-elimination, deduplication and compression on a block device. |
| Physical vs virtual size? | Physical = real pool capacity; virtual = size presented to the filesystem. |
| Biggest operational risk? | Physical pool exhaustion; monitor it like a thin pool. |
| Where does VDO fit with encryption? | Put encryption above VDO, or deduplication finds nothing to share. |

## 8. Course Corrections

| Course | Correction |
|---|---|
| `dnf install lvm2 vdo kmod-kvdo` | `kmod-kvdo` is the RHEL 9 module; RHEL 10 uses in-kernel `dm-vdo` |
| `lvcreate --type vdo --name lv_vdo --size 10G vg_vdo` | Specify `-V` (virtual size) too; `-L` is the physical pool |
| `mkfs.xfs /dev/vg_vdo/lv_vdo` | `mkfs.xfs -K` |
| `echo '…' >> tee -a /etc/fstab` | Writes to a file named `tee`; use `\| tee -a /etc/fstab` or `>> /etc/fstab`, with `UUID=` |
| `cat /dev/urandom > …` / `cat /dev/zero > …` | Fills the whole volume; use `dd … count=N` |

## 9. Quick Revision

```bash
lvcreate --type vdo -n LV -L PHYS -V VIRT VG/POOL | mkfs.xfs -K | fstab UUID
vdostats --human-readable | lvs -o +vdo_compression,vdo_deduplication,data_percent
lvchange --compression y|n --deduplication y|n | fstrim | lvextend pool vs virtual
```

## 10. Cross-References

- [LVM fundamentals](lvm-fundamentals.md) · [LVM thin provisioning](lvm-thin-provisioning-and-striping.md)
- [Filesystems & mkfs](filesystems-and-mkfs.md)
- Stratis (S46), LUKS (S47): planned
