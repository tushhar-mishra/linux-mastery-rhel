# LVM Thin Provisioning & Striping

> **Sessions:** S39–S40 · **[Advanced/Optional]** (not in the RHEL 10 objectives) · common in production and interviews
> **Related:** [LVM fundamentals](lvm-fundamentals.md) · [LVM snapshots & recovery](lvm-snapshots-and-recovery.md) · [Moving VGs between systems](lvm-moving-vgs-between-systems.md) · RAID (S43), VDO & Stratis (S45–46): planned

## 1. Overview

| Feature | What it does | Trade-off |
|---|---|---|
| **Thin provisioning** | LVs get a *virtual* size; physical space is taken from a shared **thin pool** only as data is written. Allows **overprovisioning** | Pool exhaustion can break every thin LV at once, so it must be monitored |
| **Striping** | Spreads an LV across several PVs in fixed-size chunks for parallel I/O (RAID 0) | **No redundancy**: losing one disk loses the whole LV |

## 2. Thin Provisioning

### 2.1 Concepts

| Term | Meaning |
|---|---|
| Thin pool | A special LV holding data (`[pool_tdata]`) and metadata (`[pool_tmeta]`) sub-LVs, plus a spare metadata LV (`[lvol0_pmspare]`) for repairs |
| Thin LV | Virtual-size LV (`-V`) that allocates pool chunks on first write |
| Chunk size | Allocation unit inside the pool (`-c`, default chosen automatically); unrelated to the VG's PE size |
| Overprovisioning | Sum of thin LV virtual sizes > pool size. LVM warns, but allows it |
| Thin snapshot | Snapshot that shares the pool; no fixed COW size; cheap and many can coexist |

### 2.2 Create

```bash
pvcreate /dev/vdb1
vgcreate vg_thin /dev/vdb1                         # default PE size is fine
lvcreate -L 15G -T vg_thin/pool                    # thin pool (= --type thin-pool / --thinpool)
lvcreate -V 5G -T vg_thin/pool -n lv1              # thin LV with virtual size 5G
lvcreate -V 5G -T vg_thin/pool -n lv2
lvcreate -V 5G -T vg_thin/pool -n lv3
lvcreate -V 5G -T vg_thin/pool -n lv4              # 20G virtual on a 15G pool → overprovisioned (warning)
lvs -a                                             # shows pool, thin LVs and hidden [tdata]/[tmeta]/[pmspare]
mkfs.xfs /dev/vg_thin/lv1 ; mkdir -p /mnt/client1
mount /dev/vg_thin/lv1 /mnt/client1               # persist via UUID in fstab as usual
```

### 2.3 Monitor **[Production Practice]**

```bash
lvs -o lv_name,lv_size,data_percent,metadata_percent vg_thin   # Data% and Meta% of the pool
watch -n 2 lvs vg_thin
dmsetup status vg_thin-pool-tpool                              # low-level pool status
```

Watch **both** data and metadata usage. A full metadata area is more damaging than full data.

### 2.4 Grow the pool

```bash
lvextend -L +5G vg_thin/pool                       # needs free extents in the VG
vgextend vg_thin /dev/vdc1                         # add a PV first if the VG is full
lvextend --poolmetadatasize +256M vg_thin/pool     # grow metadata if Meta% is high
```

**Auto-extend** (`/etc/lvm/lvm.conf`, activation section; requires LVM monitoring/dmeventd):

```
thin_pool_autoextend_threshold = 70     # when the pool reaches 70 %…
thin_pool_autoextend_percent   = 20     # …grow it by 20 % (needs free VG space)
```

### 2.5 Returning space to the pool (discard)

Deleting files in a thin LV does **not** shrink pool usage until the filesystem sends discards:

```bash
fstrim -v /mnt/client1                  # one-off
systemctl enable --now fstrim.timer     # periodic (weekly)
# or mount with -o discard (continuous; small runtime cost)
```

### 2.6 When the pool fills up

- New writes to any thin LV block, then fail (by default, after a short queue timeout). Filesystems may shut down, go read-only, or be damaged.
- `lvchange --errorwhenfull y vg_thin/pool` makes writes fail immediately instead of queueing.
- Recovery: extend the pool (add a PV if needed), then check/repair the affected filesystems.

### 2.7 Thin snapshots

```bash
lvcreate -s -n lv1_snap vg_thin/lv1      # no size needed; shares the pool
lvchange -ay -K vg_thin/lv1_snap         # created with "activation skip"; -K overrides it
lvconvert --merge vg_thin/lv1_snap       # roll back lv1 (deferred if lv1 is in use)
```

### 2.8 Remove

```bash
umount /mnt/client1 ; lvremove vg_thin/lv1 … ; lvremove vg_thin/pool
```

## 3. Striping

### 3.1 Concept

Data is written in **stripe-size** chunks round-robin across `N` PVs (`-i N`). Sequential and parallel I/O can use all disks at once.

| Layout | Performance | Redundancy | Capacity |
|---|---|---|---|
| Linear (default LV) | One disk at a time | None | Sum of PVs |
| **Striped** (`--type striped`) | Up to N× for large/parallel I/O | **None** (one failure = total loss) | N × smallest share |
| LVM RAID1 (`--type raid1 -m 1`) | Reads may improve | Survives 1 disk failure | 50 % |

### 3.2 Create & verify

```bash
pvcreate /dev/vdb /dev/vdc                         # confirm with lsblk these are NOT the OS disk
vgcreate vg_striped /dev/vdb /dev/vdc
lvcreate --type striped -i 2 -I 128k -L 2G -n lv_striped vg_striped   # 2 stripes, 128 KiB stripe size (default 64 KiB)
lvs -o +stripes,stripe_size,devices vg_striped     # or: lvs --segments ; lvdisplay -m
mkfs.xfs /dev/vg_striped/lv_striped                # XFS detects stripe geometry automatically
```

### 3.3 Measuring performance correctly

```bash
dd if=/dev/zero of=/mnt/stripedvol/testfile bs=1M count=1024 oflag=direct    # bypass the page cache
# (without oflag=direct / conv=fdatasync, dd mostly measures RAM)
```

`fio` gives realistic benchmarks **[Advanced]**.

### 3.4 Extending striped LVs

Extending a striped LV needs free extents on **as many PVs as there are stripes**. Otherwise you get `Insufficient suitable allocatable extents`. Add PVs in matching numbers.

### 3.5 LVM RAID (preview)

```bash
lvcreate --type raid1 -m 1 -L 1G -n lv_mirror vg     # mirrored LV
lvs -a -o +sync_percent,devices vg                   # watch initial sync
```

Software RAID with `mdadm` is covered in S43.

## 4. Production Practices **[Production Practice]**

- Thin pools: alert at ~70–80 % Data/Meta, enable auto-extend, keep free VG space, run `fstrim.timer`.
- Avoid overprovisioning for critical databases unless capacity is actively managed.
- Use striping only on identical, independent disks and only for performance. Combine with RAID (or storage-array redundancy) for important data.
- On SAN/virtual disks that are already striped/RAID-protected by the array, LVM striping often adds little.

## 5. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `WARNING: Sum of all thin volume sizes … exceeds the size of thin pool` | Overprovisioning | Intended? Then monitor and auto-extend |
| Thin LV writes hang / I/O errors | Pool data or metadata full | `lvextend` the pool / `--poolmetadatasize`; then fsck/xfs_repair |
| Pool usage doesn't drop after deleting files | No discard | `fstrim -v MNT`; enable `fstrim.timer` |
| Thin snapshot won't activate | Activation-skip flag | `lvchange -ay -K VG/SNAP` |
| `Insufficient suitable allocatable extents` extending striped LV | Not enough PVs with free space | Add PVs in multiples of the stripe count |
| Benchmark shows impossible speeds | Page cache | `oflag=direct` / `conv=fdatasync` |

## 6. Interview Questions

| Question | Answer |
|---|---|
| What is thin provisioning? | Allocating storage on write from a shared pool, so LVs can be larger in total than the physical space. |
| Biggest risk of overprovisioning? | The pool filling up, which affects every thin LV at once. Monitor and auto-extend. |
| Why doesn't deleting files free thin-pool space? | Blocks are only returned when the filesystem issues discards (`fstrim` / `discard`). |
| Thick vs thin snapshots? | Thick: fixed-size COW area that becomes invalid when full. Thin: shares the pool, no fixed size, cheap. |
| What does `-i 2 -I 128k` mean? | Stripe across 2 PVs with a 128 KiB stripe size. |
| Is striping fault tolerant? | No. It's RAID 0; one disk failure loses the LV. |

## 7. Course Corrections

| Course | Correction |
|---|---|
| `vgcreate -s 32M … (required for thin pools)` | PE size isn't required for thin pools; the pool has its own chunk size (`-c`) |
| `lvs -o +seg_monitor` "shows pool usage" | It shows monitoring status; usage is `data_percent`/`metadata_percent` |
| `dd if=/dev/zero … bs=1M count=1024` as a performance test | Add `oflag=direct` or `conv=fdatasync` |
| fstab `/dev/vg_striped/lv_striped …` | Prefer `UUID=` |
| `pvcreate /dev/sda /dev/sdb` | Verify with `lsblk` they aren't the OS disk |

## 8. Quick Revision

```bash
lvcreate -L SIZE -T VG/POOL | lvcreate -V VSIZE -T VG/POOL -n LV | lvs -a
lvs -o lv_name,data_percent,metadata_percent | lvextend -L +X VG/POOL | --poolmetadatasize +X
lvm.conf thin_pool_autoextend_threshold/percent | fstrim -v MNT / fstrim.timer | --errorwhenfull y
thin snap: lvcreate -s -n SNAP VG/LV ; lvchange -ay -K VG/SNAP
lvcreate --type striped -i N -I 64k -L SIZE -n LV VG | lvs -o +stripes,stripe_size,devices
striped = RAID0 = no redundancy · LVM RAID: --type raid1 -m 1
```

## 9. Cross-References

- [LVM fundamentals](lvm-fundamentals.md)
- [LVM snapshots & recovery](lvm-snapshots-and-recovery.md)
- [Moving VGs between systems](lvm-moving-vgs-between-systems.md)
- RAID with mdadm (S43), VDO (S45), Stratis (S46): planned
