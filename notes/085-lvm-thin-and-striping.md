# 085 · LVM Thin Provisioning and Striping

> **You need first:** [084 · Multipath](084-multipath.md)
> **Next:** [086 · LVM volume group operations](086-lvm-vg-operations.md)

---

## What it is

Two advanced LVM layouts (LVM basics are in topic 049):

| Feature | What it does | The catch |
|---|---|---|
| **Thin provisioning** | Volumes get a **virtual** size. Real space is taken from a shared **thin pool** only when data is **written**. You can promise more than you have (**overprovisioning**) | If the pool fills up, **every** thin volume in it fails at once. You must monitor it |
| **Striping** | Spreads one volume across several disks in chunks, so they work **in parallel** (the same idea as RAID 0, topic 087) | **No redundancy**: one dead disk = the whole volume lost |

Words:
- **Thin pool**: a special LV that holds the shared data space plus a **metadata** area tracking which chunk belongs to which thin volume.
- **Thin LV**: a volume with a virtual size (`-V`) that gets chunks from the pool on first write.
- **Chunk size**: the pool's allocation unit (chosen automatically), separate from the VG's extent size.
- **Discard / TRIM**: the filesystem telling the storage "these blocks are free now", so a thin pool (or SSD) can reclaim them.
- **Stripe size**: how big each chunk is before moving to the next disk (default 64 KiB).

## Why it exists

- **Thin:** in real life, volumes are created "with room to grow" but mostly stay half empty. Thin pools let ten 100 GB volumes share 400 GB of real disk, which is how virtualisation platforms, VM templates and Kubernetes storage drivers (TopoLVM, OpenEBS LVM) save space. **Thin snapshots** are cheap: no fixed size, and many can exist at once.
- **Striping:** one disk does one thing at a time. Striping across 4 disks can give up to 4× the throughput for big sequential or highly parallel I/O.

## Analogy

**Thin provisioning** is an **airline overbooking seats**: it sells more tickets (virtual size) than seats (real space), betting not everyone shows up. It works, until the day everyone shows up and the flight (pool) is full: then **nobody** new can board. **Striping** is **four checkout lanes for one long shopping list**: items are split across lanes and processed at the same time, but if one cashier walks off with part of your shopping, the whole order is ruined.

## How it works inside

### Thin pools

1. A thin pool is built from two hidden LVs: `[pool_tdata]` (the data space) and `[pool_tmeta]` (the mapping metadata), plus a spare metadata LV `[lvol0_pmspare]` for repairs.
2. A new thin LV owns **no** chunks. On the **first write** to a region, the pool allocates a chunk and records the mapping in the metadata. Reads of never-written areas return zeros.
3. **Deleting files doesn't give space back** to the pool. The filesystem still "owns" those blocks until it sends **discards** (`fstrim`, or the `discard` mount option).
4. **When the pool is full**, new writes **queue**, then fail (after about 60 seconds by default). Filesystems on the thin LVs see I/O errors: they may shut down, go read-only or be damaged. A full **metadata** area is even worse than full data.
5. **Thin snapshots** just share chunks with the origin; they need no fixed size, so they never overflow on their own (only the pool can).
6. LVM can **auto-extend** a pool when it passes a threshold, if the VG has free space and the LVM monitoring service (`dmeventd`) is running.

### Striping

With `-i N` stripes and stripe size `-I`, the LV's address space is cut into stripe-size chunks dealt round-robin to N PVs: chunk 0 → disk A, chunk 1 → disk B, chunk 2 → disk A… Large reads and writes hit all disks at once.

| Layout | Performance | Redundancy | Usable capacity |
|---|---|---|---|
| Linear (the default) | One disk at a time | None | Sum of the PVs |
| **Striped** | Up to N× for big or parallel I/O | **None** | N × the smallest share |
| LVM RAID1 (`--type raid1 -m 1`) | Reads may improve | Survives one disk failure | 50% |

## Commands

### Thin pool and thin volumes

```bash
sudo pvcreate /dev/vdb
sudo vgcreate vg_thin /dev/vdb
sudo lvcreate -L 3G -T vg_thin/pool                      # a 3 GiB thin pool
sudo lvcreate -V 2G -T vg_thin/pool -n app1               # thin LVs with 2 GiB virtual size each
sudo lvcreate -V 2G -T vg_thin/pool -n app2
```
```
  Logical volume "app2" created.
  WARNING: Sum of all thin volume sizes (4.00 GiB) exceeds the size of thin pool vg_thin/pool (3.00 GiB).
  WARNING: You have not turned on protection against thin pools running out of space.
  WARNING: Set activation/thin_pool_autoextend_threshold below 100 to trigger automatic extension of thin pools before they get full.
```
- 4 GiB promised on a 3 GiB pool: overprovisioned. LVM warns but allows it.

```bash
sudo lvs -a vg_thin
```
```
  LV              VG      Attr       LSize Pool Origin Data%  Meta%
  app1            vg_thin Vwi-a-tz-- 2.00g pool        0.00
  app2            vg_thin Vwi-a-tz-- 2.00g pool        0.00
  [lvol0_pmspare] vg_thin ewi------- 4.00m
  pool            vg_thin twi-aotz-- 3.00g             0.00   10.94
  [pool_tdata]    vg_thin Twi-ao---- 3.00g
  [pool_tmeta]    vg_thin ewi-ao---- 4.00m
```
- Attr `V…` = a virtual (thin) volume; `t…` = the thin pool. Hidden internal LVs are in `[brackets]`. **Watch the pool's `Data%` and `Meta%`.**

```bash
sudo mkfs.xfs /dev/vg_thin/app1 ; sudo mkdir -p /mnt/app1 ; sudo mount /dev/vg_thin/app1 /mnt/app1
sudo dd if=/dev/urandom of=/mnt/app1/blob bs=1M count=500
sudo lvs -o lv_name,lv_size,data_percent,metadata_percent vg_thin
```
```
  LV   LSize Data%  Meta%
  app1 2.00g 24.71
  app2 2.00g 0.00
  pool 3.00g 16.47  12.30
```

### Give deleted space back

```bash
sudo rm /mnt/app1/blob ; sudo lvs -o lv_name,data_percent vg_thin/pool     # still ~16%
sudo fstrim -v /mnt/app1 ; sudo lvs -o lv_name,data_percent vg_thin/pool
```
```
/mnt/app1: 1.9 GiB (2046820352 bytes) trimmed
  LV   Data%
  pool 0.12
```
- Enable the weekly timer: `sudo systemctl enable --now fstrim.timer`. Mounting with `-o discard` trims continuously, at a small runtime cost.

### Grow the pool / protect it

```bash
sudo vgextend vg_thin /dev/vdc                 # if the VG has no free space
sudo lvextend -L +2G vg_thin/pool
sudo lvextend --poolmetadatasize +64M vg_thin/pool     # if Meta% is high
```
Auto-extend in `/etc/lvm/lvm.conf` (activation section):
```
thin_pool_autoextend_threshold = 70
thin_pool_autoextend_percent   = 20
```
```bash
sudo lvchange --errorwhenfull y vg_thin/pool   # fail writes immediately when full instead of queueing
```

### Thin snapshots

```bash
sudo lvcreate -s -n app1_snap vg_thin/app1     # no size needed
sudo lvchange -ay -K vg_thin/app1_snap         # thin snapshots are created "skip activation"; -K overrides it
sudo lvconvert --merge vg_thin/app1_snap       # roll back app1 (deferred if app1 is in use)
```

### Striping

```bash
sudo pvcreate /dev/vdd /dev/vde
sudo vgcreate vg_fast /dev/vdd /dev/vde
sudo lvcreate --type striped -i 2 -I 128k -L 2G -n lv_fast vg_fast
sudo lvs -o +stripes,stripe_size,devices vg_fast
```
```
  LV      VG      Attr       LSize #Str Stripe  Devices
  lv_fast vg_fast -wi-a----- 2.00g    2 128.00k /dev/vdd(0),/dev/vde(0)
```
- `#Str 2` = two stripes; the LV uses both PVs. XFS detects the stripe geometry at mkfs time.

**Measure honestly** (bypass the page cache, or you measure RAM):
```bash
sudo dd if=/dev/zero of=/mnt/fast/test bs=1M count=1024 oflag=direct
```
`fio` gives realistic benchmarks (topic 094).

**Extending a striped LV** needs free space on **as many PVs as there are stripes**; otherwise: `Insufficient suitable allocatable extents`. Add PVs in matching numbers.

### LVM RAID (preview of topic 087)

```bash
sudo lvcreate --type raid1 -m 1 -L 1G -n lv_mirror vg_fast
sudo lvs -a -o +sync_percent,devices vg_fast
```

### Try it
1. Build a 3 GiB pool with two 2 GiB thin LVs. Fill one with 1 GiB and watch `Data%`. Delete it and run `fstrim`.
2. **On a throwaway VG**, deliberately fill the pool to 100% and see what the filesystem does (`dmesg`). Then extend the pool and repair.
3. Create a thin snapshot, change the origin, and merge it back.
4. Build a striped LV over two disks and compare `dd oflag=direct` speed with a linear LV.

## Where you'll use it

- **Virtualisation and VDI** (Virtual Desktop Infrastructure): many VM disks from templates on thin pools, with cheap snapshots.
- **Kubernetes local storage:** LVM-based CSI drivers carve thin LVs per PersistentVolume; "pool full" on a node breaks many pods at once.
- **Docker's old devicemapper storage driver** used thin pools (now replaced by overlay2).
- **Striping:** scratch or performance volumes on local NVMe; usually unnecessary on cloud or SAN volumes, which are already striped by the provider.
- **Monitoring:** alert on thin-pool `Data%`/`Meta%` above about 70–80%.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `Sum of all thin volume sizes … exceeds the size of thin pool` | Overprovisioning | Intended? Then monitor and enable auto-extend |
| Thin LV writes hang, then I/O errors | The pool's data or metadata is full | Extend the pool / `--poolmetadatasize`; then repair the filesystems (topic 051) |
| Pool usage doesn't drop after deleting files | No discards were sent | `fstrim -v MNT`; `fstrim.timer` |
| A thin snapshot won't activate | Activation-skip flag | `lvchange -ay -K VG/SNAP` |
| `Insufficient suitable allocatable extents` extending a striped LV | Not enough PVs with free space | Add PVs in multiples of the stripe count |
| A benchmark shows impossible speeds | The page cache | `oflag=direct` / `conv=fdatasync` |
| A striped LV is gone after one disk died | Striping has no redundancy | Restore from backup; use RAID for important data |

## Quick recap

- Thin: `lvcreate -L SIZE -T VG/POOL`, then `lvcreate -V VSIZE -T VG/POOL -n LV`. Space is allocated on write; overprovisioning is allowed.
- **Monitor `Data%` and `Meta%`**, auto-extend (`thin_pool_autoextend_*`), keep VG free space, `fstrim`. A full pool breaks every thin LV.
- Thin snapshots: no size, cheap, activate with `-K`.
- Striping: `--type striped -i N -I SIZE` = parallel speed, **no** redundancy; extend with matching PV counts.

**Interview questions**

1. *What is thin provisioning, and what's the main risk?* Volumes draw real space from a shared pool only when data is written, so the total virtual size can exceed physical capacity. The risk is the pool filling up, which makes writes fail on every thin volume at once.
2. *Why doesn't deleting files free space in a thin pool?* The pool only reclaims blocks when the filesystem sends discards (`fstrim` or the `discard` mount option).
3. *Is a striped LV fault tolerant?* No. It's equivalent to RAID 0: data is spread across disks with no redundancy, so losing one disk loses the volume.
