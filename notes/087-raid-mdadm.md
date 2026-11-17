# 087 · Software RAID with mdadm

> **You need first:** [086 · LVM volume group operations](086-lvm-vg-operations.md)
> **Next:** [088 · LUKS encryption](088-luks-encryption.md)

---

## What it is

**RAID** (Redundant Array of Independent Disks) combines several disks into one device for **speed**, **redundancy** (surviving a disk failure), or both. On Linux, software RAID is done by the kernel's **md** ("multiple devices") driver and managed with **`mdadm`**. The result is a device like `/dev/md0` that you format and mount like any disk.

| Level | Min disks | How | Survives | Usable space | Notes |
|---|---|---|---|---|---|
| **RAID 0** | 2 | **Striping**: data split across disks | **0** failures | 100% | Fast, no protection at all |
| **RAID 1** | 2 | **Mirroring**: identical copies | N−1 failures | One disk's worth | Simple, fast reads; typical for OS disks |
| **RAID 5** | 3 | Striping + **parity** spread over all disks | 1 failure | (N−1)/N | Write penalty; long, risky rebuilds on large disks |
| **RAID 6** | 4 | Striping + **two** independent parities | 2 failures | (N−2)/N | Preferred over RAID 5 for big drives |
| **RAID 10** | 4 | Mirror pairs, then striped together | 1 per mirror pair | 50% | Best mix of speed and safety (databases) |

- **Parity** is extra data computed with **XOR** (exclusive OR) from the data blocks. If any one block is lost, XOR-ing all the others recreates it: `1011 XOR 0101 = 1110`, and `1110 XOR 0101 = 1011`.
- **Degraded**: the array is running with a failed member (still working, but no longer protected).
- **Resync / rebuild**: copying or recomputing data onto a new or replaced disk.
- **Hot spare**: an idle disk that automatically replaces a failed one.

**RAID is not a backup.** It survives **disk hardware failure**, not deletion, corruption, ransomware, fire or theft.

## Why it exists

Disks fail; it's a question of when, not if. Without RAID, one dead disk means downtime plus a restore from backup. With RAID 1/5/6/10, the server keeps running on the remaining disks while you replace the dead one. RAID 0 and 10 also give speed by working on several disks in parallel.

## Analogy

- **RAID 1** = writing every page of a notebook **twice**, in two notebooks. Lose one, and the other has everything.
- **RAID 0** = tearing the notebook in half and giving each half to a different person: twice as fast to read, but lose either person and the notebook is useless.
- **RAID 5** = three people each hold part of the notes, plus a clever **checksum page** spread among them; any one person can be replaced by working the missing part out from the others.
- **RAID 6** = the same with **two** checksum pages, so two people can be lost.

## How it works inside

- `mdadm --create` writes an **md superblock** (metadata: array UUID, level, member role) onto each member disk, and the kernel creates `/dev/mdN`.
- Every write to `/dev/md0` is translated by the md driver: duplicated (RAID 1), split (RAID 0), or split with parity computed (RAID 5/6).
  - A **RAID 5 small write** must read the old data and old parity, compute the new parity, and write both: the "write penalty".
- **At boot**, the md superblocks let the kernel/udev **assemble** arrays automatically. Listing them in `/etc/mdadm.conf` gives them stable names (otherwise you may see `/dev/md127`).
- **When a disk fails**, md marks it faulty and keeps serving I/O from the rest (degraded). Reads that needed the dead disk are reconstructed on the fly from mirrors or parity. Adding a replacement triggers a **rebuild**, which reads every other disk completely. On huge disks this takes hours, and a **second** failure or unreadable sector during a RAID 5 rebuild loses the array. That's why RAID 6 or RAID 10 is preferred for large drives.
- The array works **during** the initial resync.

## Commands

```bash
sudo dnf install -y mdadm
lsblk                                     # choose EMPTY disks (never the OS disk)
```

### Create

```bash
sudo mdadm --create /dev/md0 --level=1 --raid-devices=2 /dev/vdb /dev/vdc
```
```
To optimize recovery speed, it is recommended to enable write-intent bitmap, do you want to enable it now? [y/N]? y
mdadm: Note: this array has metadata at the start and
    may not be suitable as a boot device.  If you plan to
    store '/boot' on this device please ensure that
    your boot-loader understands md/v1.x metadata, or use
    --metadata=0.90
Continue creating array [y/N]? y
mdadm: Defaulting to version 1.2 metadata
mdadm: array /dev/md0 started.
```
- A **write-intent bitmap** records which areas changed, so after a crash or a briefly missing disk only those areas are resynced instead of the whole disk. Say yes (or add `--bitmap=internal`).

```bash
sudo mdadm -C /dev/md1 -l 5 -n 3 -x 1 /dev/vd{d,e,f,g}      # RAID 5 on 3 disks + 1 hot spare
sudo mdadm -C /dev/md2 -l 10 -n 4 /dev/vd{h,i,j,k}         # RAID 10
```

### Watch and inspect

```bash
cat /proc/mdstat
```
```
Personalities : [raid1] [raid6] [raid5] [raid4]
md0 : active raid1 vdc[1] vdb[0]
      5237760 blocks super 1.2 [2/2] [UU]
      [=====>...............]  resync = 27.4% (1436288/5237760) finish=0.3min speed=203111K/sec
      bitmap: 1/1 pages [4KB], 65536KB chunk
```
- `[2/2]` = 2 members expected, 2 working. `[UU]` = both Up (`_` would mark a missing one). The resync line shows progress.

```bash
sudo mdadm --detail /dev/md0
```
```
/dev/md0:
           Version : 1.2
        Raid Level : raid1
        Array Size : 5237760 (5.00 GiB 5.36 GB)
      Raid Devices : 2
     Total Devices : 2
             State : clean
    Active Devices : 2
   Working Devices : 2
    Failed Devices : 0
     Spare Devices : 0
              UUID : 3b1c…:9f2e…:…
    Number   Major   Minor   RaidDevice State
       0     252       16        0      active sync   /dev/vdb
       1     252       32        1      active sync   /dev/vdc
```
- **`State: clean`** = healthy. `degraded`, `recovering` or `resyncing` need attention.

### Make it permanent and use it

```bash
sudo mdadm --detail --scan | sudo tee -a /etc/mdadm.conf
sudo mkfs.xfs /dev/md0
sudo mkdir -p /raid1
echo "UUID=$(sudo blkid -s UUID -o value /dev/md0) /raid1 xfs defaults 0 0" | sudo tee -a /etc/fstab
sudo systemctl daemon-reload && sudo mount -a
```
```
ARRAY /dev/md0 metadata=1.2 UUID=3b1c…:9f2e…:…
```
- Run it only when the array is **clean**. During a rebuild the new disk counts as a spare, the line gets `spares=1`, and mdadm will later expect a spare that doesn't exist.
- If the root filesystem is on RAID, also rebuild the initramfs (`dracut -f`, topic 053).

### Alerts (essential)

```bash
echo 'MAILADDR ops@example.com' | sudo tee -a /etc/mdadm.conf
sudo systemctl enable --now mdmonitor
```
- An array that silently runs **degraded** for months is the classic disaster: the second disk dies and everything is gone. Also feed `/proc/mdstat` into your monitoring (node_exporter has an md collector).

### Replace a failed disk

```bash
sudo mdadm /dev/md0 --fail /dev/vdb          # (simulate a failure)
cat /proc/mdstat
```
```
md0 : active raid1 vdc[1] vdb[0](F)
      5237760 blocks super 1.2 [2/1] [_U]
```
- `(F)` = faulty. `[2/1] [_U]` = degraded, but still serving data.

```bash
sudo mdadm /dev/md0 --remove /dev/vdb
# physically replace the disk (or attach a new virtual disk)
sudo mdadm /dev/md0 --add /dev/vdd
watch -n 2 cat /proc/mdstat                  # recovery = …%, until [UU]
```
- With a hot spare, the rebuild starts **automatically** when a member fails.

### Grow, stop, remove

```bash
sudo mdadm /dev/md1 --add /dev/vdl
sudo mdadm --grow /dev/md1 --raid-devices=4   # reshape RAID 5 from 3 to 4 disks (slow)
sudo xfs_growfs /raid5                         # then grow the filesystem

sudo umount /raid1
sudo mdadm --stop /dev/md0
sudo mdadm --zero-superblock /dev/vdb /dev/vdc # ⚠️ wipe the md metadata to reuse the disks
# also remove its ARRAY line from /etc/mdadm.conf and its fstab entry
```

### Hardware vs software vs LVM RAID

| | Hardware RAID controller | mdadm | LVM RAID (`lvcreate --type raid1/5/6/10`) |
|---|---|---|---|
| CPU cost | Offloaded to the card | Host CPU (small for 1/10) | Host CPU (uses md inside) |
| Portability | Tied to that controller model | Any Linux | Any Linux with LVM |
| Monitoring | Vendor tools | `/proc/mdstat`, mdadm | `lvs -a` |
| Typical use | Servers with battery-backed write cache | Common, flexible | When everything is already LVM-managed |

### Try it
1. Create a RAID 1 from two lab disks, put XFS on it, write files, and add it to fstab.
2. Fail a member, watch `[_U]`, add a replacement, and watch the rebuild.
3. Create a RAID 5 with a hot spare, fail a disk, and watch the spare take over automatically.
4. Reboot without the `ARRAY` line in `/etc/mdadm.conf` and see the `md127` name; then add the line.

## Where you'll use it

- **Bare-metal servers:** RAID 1 for the OS disks, RAID 10 for databases, RAID 6 for big storage.
- **Kubernetes bare-metal nodes:** local NVMe often in RAID 0 (speed, with the application replicating data itself) or RAID 10.
- **Cloud:** the provider already protects volumes. RAID 0 across several cloud volumes is sometimes used for more throughput.
- **Remember:** RAID ≠ backup (topic 068).

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| The array appears as `/dev/md127` | Not in `/etc/mdadm.conf` | `mdadm --detail --scan >> /etc/mdadm.conf`; `dracut -f` if root is on it |
| `[U_]` / `State: degraded` | A member failed or is missing | `--detail`; replace and `--add` |
| `mdadm: cannot open /dev/vdb: Device or resource busy` | The disk is in use (an old array, LVM, mounted) | `lsblk`; stop the old array; `--zero-superblock` |
| The rebuild is very slow | Speed limits | `/proc/sys/dev/raid/speed_limit_min` (careful on busy systems) |
| A "new" disk has old RAID metadata | A leftover superblock | `mdadm --zero-superblock DEV` |
| A second disk failed during a RAID 5 rebuild | RAID 5's weakness on big disks | Restore from backup; prefer RAID 6 or 10 |

## Quick recap

- RAID 0 (speed, no safety), 1 (mirror), 5 (single parity, 1 failure), 6 (double parity, 2 failures), 10 (mirror + stripe). **RAID ≠ backup.**
- `mdadm -C /dev/md0 -l LEVEL -n N [-x SPARES] DISKS`; check `cat /proc/mdstat` (`[UU]`), `mdadm --detail`.
- Persist: `mdadm --detail --scan >> /etc/mdadm.conf`, fstab by UUID. Alert: `mdmonitor` + `MAILADDR`.
- Replace: `--fail` → `--remove` → swap → `--add` → watch the rebuild.

**Interview questions**

1. *RAID 5 vs RAID 6?* RAID 5 stores one parity block per stripe and survives one disk failure. RAID 6 stores two independent parities and survives two, which matters on large disks where rebuilds take hours.
2. *How does parity let RAID 5 rebuild a lost disk?* Parity is the XOR of the data blocks in a stripe; XOR-ing the surviving blocks with the parity recreates the missing block.
3. *Is RAID a backup?* No. It only protects against disk hardware failure; deletions, corruption, ransomware and site loss are copied to every member instantly.
