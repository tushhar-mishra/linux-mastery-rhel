# 091 · Stratis: Simple Pool-Based Storage

> **You need first:** [090 · VDO](090-vdo.md)
> **Next:** [092 · Processes and system calls](092-processes-and-system-calls.md)

---

## What it is

**Stratis** is a local storage manager that hides the usual "partition → PV → VG → LV → mkfs" steps (topics 046–049) behind **one command**. You give it whole disks; it builds a **pool**; you create **filesystems** in the pool. Each filesystem is **thinly provisioned XFS** that grows automatically.

```
block devices (/dev/vdb, /dev/vdc)  →  pool  (data tier [+ optional cache tier])  →  filesystems
                                                                                      /dev/stratis/<pool>/<fs>
```

| Component | Role |
|---|---|
| `stratisd` | The daemon that manages pools (must be running) |
| `stratis` (stratis-cli) | The command-line client that talks to the daemon |
| **Pool** | One or more whole disks |
| **Filesystem** | Thin XFS inside a pool; grows within the pool |
| **Cache tier** | Optional SSD/NVMe that speeds up a pool of slower disks |

Ubuntu/Debian: Stratis packages exist but are rarely used; it's mainly a Fedora/RHEL tool.

## Why it exists

LVM + XFS is powerful but has many steps and sharp edges (filesystem resize, thin pool management). Stratis offers a **ZFS/Btrfs-like experience** (pools, snapshots, automatic growth) built on proven pieces: device-mapper, thin provisioning (topic 085) and XFS.

## Analogy

LVM is **building furniture from parts**: you choose every board and screw. Stratis is **a flat-pack kit with one instruction**: "put disks in the pool, ask for a filesystem". Fewer choices, fewer mistakes.

## How it works inside

- `stratisd` writes its own metadata onto each disk, then uses device-mapper to build a thin pool across them.
- Each filesystem is a **thin volume** with a large virtual size (1 TiB by default, or `--size`) and XFS on top. As the filesystem fills, stratisd grows the XFS automatically. So **`df` shows the virtual size, not real capacity**; the real limit is the pool (`stratis pool list`).
- Snapshots are thin snapshots: instant, sharing data with the origin.
- Because the filesystems only exist after `stratisd` has started and assembled the pool, fstab entries must say so: **`x-systemd.requires=stratisd.service`**. Otherwise systemd tries to mount before the device exists, and the boot hangs or drops to emergency mode.
- Encrypted pools use LUKS2 (topic 088) under the hood, unlocked with a kernel-keyring key or Clevis (Tang/TPM2).

## Commands

```bash
sudo dnf install -y stratisd stratis-cli
sudo systemctl enable --now stratisd
sudo blkid -p /dev/vdb            # no output = clean disk
sudo wipefs -a /dev/vdb           # ⚠️ only if the disk is meant to be reused: clears old signatures
```
Disks must be **whole and unused** (no partition table, filesystem, LVM or RAID signature).

### Pools

```bash
sudo stratis pool create pool1 /dev/vdb
sudo stratis pool add-data pool1 /dev/vdc          # grow the pool with another disk
sudo stratis pool list
```
```
Name                     Total / Used / Free    Properties                                   UUID   Alerts
pool1   20 GiB / 526 MiB / 19.49 GiB   ~Ca,~Cr, Op   9e1b…
```
- `Total / Used / Free` is the **real** physical capacity. `~Ca` = no cache, `~Cr` = not encrypted, `Op` = overprovisioning allowed.

```bash
sudo stratis blockdev list
sudo stratis pool init-cache pool1 /dev/nvme0n2    # optional SSD cache tier
```

### Filesystems

```bash
sudo stratis filesystem create pool1 fs1
sudo stratis filesystem list
sudo mkdir -p /data ; sudo mount /dev/stratis/pool1/fs1 /data
df -hT /data
```
```
Pool    Filesystem   Total / Used / Free / Limit            Created             Device                    UUID
pool1   fs1          1 TiB / 546 MiB / 1023.47 GiB / None   Nov 17 2026 10:02   /dev/stratis/pool1/fs1   4c7e…
Filesystem                                 Type  Size  Used Avail Use% Mounted on
/dev/mapper/stratis-1-9e1b…-thin-fs-4c7e…  xfs   1.0T  7.4G 1017G   1% /data
```
- `df` claims 1 TiB, though the pool has only 20 GiB. That's the thin virtual size; trust `stratis pool list`.

### Persistent mount (the required option)

```bash
UUID=$(sudo blkid -s UUID -o value /dev/stratis/pool1/fs1)
echo "UUID=$UUID /data xfs defaults,x-systemd.requires=stratisd.service 0 0" | sudo tee -a /etc/fstab
sudo systemctl daemon-reload && sudo mount -a
```

### Snapshots

```bash
sudo stratis filesystem snapshot pool1 fs1 fs1-snap
sudo mkdir -p /mnt/snap ; sudo mount /dev/stratis/pool1/fs1-snap /mnt/snap
sudo cp -a /mnt/snap/lost-file /data/              # restore one file
sudo umount /mnt/snap ; sudo stratis filesystem destroy pool1 fs1-snap
```
- To roll back a whole filesystem, mount the snapshot in place of the original (and update fstab to its UUID). Newer versions also offer `stratis filesystem schedule-revert`.

### Encrypted pool

```bash
sudo stratis key set --capture-key mykey           # type a passphrase; stored in the kernel keyring
sudo stratis pool create --key-desc mykey secpool /dev/vdd
```
The exact options vary by version (`stratis pool create --help`).

### Remove

```bash
sudo umount /data ; sudo vi /etc/fstab             # remove the entry
sudo stratis filesystem destroy pool1 fs1
sudo stratis pool destroy pool1                    # the pool must have no filesystems left
```

### Try it
1. Create a pool from one disk, add a filesystem, mount it persistently with the `x-systemd.requires` option, and reboot.
2. Remove `x-systemd.requires=stratisd.service` from fstab in a lab, reboot, and see the failure; fix it from the emergency shell.
3. Snapshot, delete a file, restore it from the snapshot.
4. Add a second disk with `add-data` and watch the pool's Total grow.

## Where you'll use it

- **Single-server workstations and small servers** where you want snapshots and simple management without learning LVM thin pools.
- In large production fleets, plain **LVM + XFS** (or cloud volumes) is still far more common. Know Stratis well enough to recognise and operate it.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `stratis pool create` refuses a disk | An existing signature or partition table | `blkid -p DEV`; `wipefs -a DEV` if safe |
| The boot hangs / emergency mode | fstab lacks `x-systemd.requires=stratisd.service` | Add it; `systemctl daemon-reload` |
| `stratis` commands can't connect | `stratisd` isn't running | `systemctl enable --now stratisd` |
| Writes fail although `df` shows space | The pool is physically full | `stratis pool add-data POOL DEV` |
| `pool destroy` fails | Filesystems still exist | Destroy them first |

## Quick recap

- Stratis = pools of whole disks + thin XFS filesystems, managed by `stratisd` with the `stratis` CLI.
- `stratis pool create P DEVS` → `stratis filesystem create P FS` → mount `/dev/stratis/P/FS`.
- fstab **must** include `x-systemd.requires=stratisd.service`.
- `df` shows the virtual size; real capacity is `stratis pool list`. Snapshots: `stratis filesystem snapshot P FS SNAP`.

**Interview questions**

1. *What is Stratis built on?* device-mapper thin provisioning and XFS, managed by the `stratisd` daemon.
2. *Why does `df` show 1 TiB on a 20 GiB Stratis pool?* Stratis filesystems are thinly provisioned with a large virtual size; real capacity is the pool's.
3. *What fstab option does a Stratis filesystem need, and why?* `x-systemd.requires=stratisd.service`, so systemd waits for stratisd to set up the pool before mounting.
