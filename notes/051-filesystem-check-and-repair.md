# 051 · Filesystem Check and Repair: xfs_repair, e2fsck, fsck

> **You need first:** [050 · Swap](050-swap.md)
> **Next:** [052 · LVM snapshots and metadata recovery](052-lvm-snapshots-and-recovery.md)

---

## What it is

A filesystem's **metadata** (superblocks, inodes, directories, free-space maps; topic 047) can become inconsistent after crashes, power loss, storage faults or bugs. **Repair tools** read all the metadata, find contradictions, and fix them.

| Filesystem | Tool | Package |
|---|---|---|
| ext2/3/4 | **`e2fsck`** (also run through `fsck` or `fsck.ext4`) | e2fsprogs |
| XFS | **`xfs_repair`** (`fsck.xfs` exists but does nothing) | xfsprogs |
| VFAT | `fsck.vfat` | dosfstools |
| Any | `fsck`: a front end that runs the right checker for each type | util-linux |

**`lost+found`** is a directory at the top of each ext filesystem (XFS creates it when needed) where repair tools put files whose directory entry was lost. They're named by inode number.

## Why it exists

Journaling (topic 047) handles **ordinary** crashes automatically at mount time. But disk errors, firmware bugs, a controller losing cached writes, or someone writing to a raw device can still leave real damage. When a filesystem won't mount, or the kernel switches it to **read-only** to protect your data, you need these tools, and you need to use them **safely**, because a careless repair can make things worse.

## Analogy

A filesystem is a **library catalogue**. After a flood, some catalogue cards point to the wrong shelves and some books have no card. The repair tool is the **librarian doing a full stock-take**: walking every shelf, rebuilding the cards, and putting orphaned books on a "found" trolley (`lost+found`). You **close the library** during the stock-take (unmount), because people moving books around while the librarian works would corrupt the result.

## How it works inside

- A checker walks every structure: the superblock, every inode, every directory entry, every block map. It cross-checks them ("this block is marked used but no inode owns it", "this inode says 2 links but only 1 directory points to it") and rewrites the metadata so it's consistent again.
- **Never repair a mounted filesystem.** The kernel caches and changes metadata while it's mounted. Two writers changing the same structures = guaranteed corruption.
- **ext4** keeps **backup superblocks** at known spots (for example block 32768), so a damaged primary superblock can be rebuilt.
- **XFS** first needs its **log replayed**, which happens on mount. So the procedure is: mount once (replay) → unmount → repair. If mounting fails, `xfs_repair -L` **zeroes the log**, which throws away the most recent metadata changes. That's a last resort.
- The kernel may **remount a filesystem read-only** by itself when it detects errors (ext4's `errors=remount-ro` behaviour; XFS shuts the filesystem down). It's a protective move; the cause is in `dmesg`.

### Golden rules

1. **Unmount first**, completely. Check with `findmnt` and `lsof`/`fuser`. Never use lazy unmount (`umount -l`) before a repair.
2. **Dry run first** (`-n`) to see what would change.
3. For important data, **take an image or snapshot first** (`dd`, LVM snapshot): repairs can delete damaged files.
4. **Fix the cause:** check the disk (`dmesg`, SMART via `smartctl`, RAID state). Repeated corruption = a hardware or storage problem.

## Commands

### Spotting trouble

```bash
sudo dmesg | tail -20
journalctl -k -p err --since today
```
```
XFS (vdc1): Metadata corruption detected at xfs_dir3_data_read_verify+0x7e/0x110 [xfs], xfs_dir3_data block 0x2a8
XFS (vdc1): Corruption of in-memory data (0x8) detected at xfs_trans_cancel+0x12b/0x150 [xfs]. Shutting down filesystem.
```
```
EXT4-fs error (device vdb2): ext4_lookup:1859: inode #131073: comm ls: deleted inode referenced: 131090
EXT4-fs (vdb2): Remounting filesystem read-only
```

### ext4

```bash
findmnt /dev/vdb2 && sudo umount /logs          # must be unmounted
sudo e2fsck -fn /dev/vdb2                        # read-only check: force a real check, answer "no" to every fix
sudo e2fsck -f -y /dev/vdb2                      # force a full check, fix everything (yes to all)
```
```
e2fsck 1.47.1 (20-May-2024)
Pass 1: Checking inodes, blocks, and sizes
Pass 2: Checking directory structure
Entry 'report.txt' in /data (129025) has deleted/unused inode 129026.  Clear? yes

Pass 3: Checking directory connectivity
Pass 4: Checking reference counts
Pass 5: Checking group summary information
Block bitmap differences:  -573440
Fix? yes

Free blocks count wrong for group #17 (16383, counted=16384).
Fix? yes
...
Inode bitmap differences:  -129026
Fix? yes
...

LOGS: ***** FILE SYSTEM WAS MODIFIED *****
LOGS: 12/282240 files (0.0% non-contiguous), 38517/1127424 blocks
```
- The five passes: inodes → directory structure → whether every directory is connected to the tree → link counts → free-space summaries. "WAS MODIFIED" = fixes were made.
- Here a directory entry pointed at an inode that had been wiped. Pass 2 removed the entry, and Pass 5 then corrected the free-block and free-inode counts that no longer matched.
- **Always add `-f` to a check-only run.** Plain `e2fsck -n` trusts the "clean" flag in the superblock and skips the check: on this damaged filesystem it printed `LOGS: clean, 13/282240 files` and exited 0.
- Exit code: `0` = no errors, `1` = errors were fixed, `4` = errors left uncorrected (e.g. with `-n`), `8` = operational error. Scripts and boot checks rely on it.

| `e2fsck` option | Meaning |
|---|---|
| `-n` | Read-only; answer "no" to everything (combine with `-f`, or a "clean" filesystem isn't checked at all) |
| `-y` | Answer "yes" to everything |
| `-p` | "Preen": automatically fix only safe problems (used at boot) |
| `-f` | Force a check even if the filesystem looks clean |
| `-b N` | Use the backup superblock at block N |
| `-c` | Also scan for bad blocks |
| `-v` | Verbose |

**Damaged primary superblock** (`Bad magic number in super-block`):
```bash
sudo dumpe2fs /dev/vdb2 | grep -i 'backup superblock'
sudo e2fsck -b 32768 /dev/vdb2
```
```
  Backup superblock at 32768, Group descriptors at 32769-32769
  Backup superblock at 98304, Group descriptors at 98305-98305
```
(`mke2fs -n /dev/vdb2` also lists them. **`-n` = dry run. Without `-n`, `mke2fs` reformats the device.**)

**Boot-time checks:** fstab's 6th field (topic 048) decides the order: `1` root, `2` other ext filesystems, `0` skip (XFS, swap, network). To force a full check at the next boot, add `fsck.mode=force fsck.repair=yes` to the kernel command line (topic 054).

### XFS

```bash
sudo umount /data
sudo mount /data && sudo umount /data           # mount once to replay the log
sudo xfs_repair -n /dev/vdc1                     # dry run
sudo xfs_repair /dev/vdc1                        # repair (don't interrupt it)
```
```
Phase 1 - find and verify superblock...
Phase 2 - using internal log
        - zero log...
        - scan filesystem freespace and inode maps...
Phase 3 - for each AG...
...
Phase 7 - verify and correct link counts...
done
```
- XFS works through 7 phases, per allocation group (AG).

```bash
sudo xfs_repair /dev/vdc1
```
```
ERROR: The filesystem has valuable metadata changes in a log which needs to
be replayed.  Mount the filesystem to replay the log, and unmount it before
re-running xfs_repair.  If the filesystem is a snapshot of a mounted
filesystem, you may need to give mount the nouuid option. If you are unable
to mount the filesystem, then use the -L option to destroy the log and
attempt a repair.
```
- Do exactly what it says. Use `-L` **only** if the mount fails. A successful mount replays the log; the kernel log then shows `XFS (dm-0): Starting recovery (logdev: internal)` and `Ending recovery`. This situation is easy to reproduce in a lab: `sudo xfs_io -x -c shutdown /web` stops a busy XFS filesystem without flushing its log, just like a crash.

### The root filesystem

You can't unmount `/` on a running system.

| Root filesystem | How |
|---|---|
| ext4 | Reboot with `fsck.mode=force fsck.repair=yes` on the kernel command line |
| XFS | Boot from installation or rescue media → "Rescue a Red Hat Enterprise Linux system" → choose **not** to mount the system → `xfs_repair /dev/mapper/rhel-root` (topic 057) |

### After a repair

```bash
sudo mount -a
ls -l /data/lost+found
file /data/lost+found/*          # identify recovered files by their content
```

### Try it (lab disk only!)
1. Make an ext4 filesystem on a spare partition, copy some files onto it, unmount it, and run `e2fsck -n` and then `e2fsck -f`.
2. Corrupt the primary superblock on that **lab** partition: `sudo dd if=/dev/zero of=/dev/vdb2 bs=1024 seek=1 count=1`. Try to mount it, then repair it with a backup superblock.
3. On an XFS lab volume, run `xfs_repair -n`, then a real repair.

## Where you'll use it

- **After power failures or storage incidents** when a volume won't mount.
- **"Filesystem became read-only" alerts:** read `dmesg`, fix the storage, unmount, repair.
- **Cloud recovery:** attach the broken root volume to a helper VM as a secondary disk, then run `xfs_repair` on it there (you can't repair a mounted root).
- **Databases:** after a filesystem repair, also run the database's own consistency check, because the filesystem being consistent doesn't mean the data inside files is.

## When it breaks

| Message / symptom | Cause | Fix |
|---|---|---|
| `e2fsck: Cannot continue, aborting` / `… is mounted` | It's in use | Unmount; for root, use rescue media |
| `Bad magic number in super-block` | Damaged primary superblock, or the wrong device or type | Confirm with `blkid`; `e2fsck -b <backup>` |
| `xfs_repair: … contains a mounted filesystem` | Still mounted | `findmnt`; unmount fully |
| `The filesystem has valuable metadata changes in a log` | A dirty XFS log | Mount/unmount to replay; `-L` only if mounting fails |
| The filesystem was remounted read-only | The kernel detected errors | `dmesg`; fix the storage; unmount and repair |
| Files appeared in `lost+found` | Orphans reconnected by the repair | Identify with `file`; restore names from backup |
| Corruption keeps coming back | Failing hardware | `smartctl -a`, RAID status, replace the disk |

## Quick recap

- **Unmount first** (never lazily) → dry run (`-n`) → repair → mount → check `lost+found`. Back up or snapshot critical volumes first.
- ext4: `e2fsck -n`, `-f -y`, `-p`; bad superblock → `dumpe2fs | grep -i backup` → `e2fsck -b N`.
- XFS: mount+umount to replay the log → `xfs_repair -n` → `xfs_repair`; `-L` is the last resort.
- Root: `fsck.mode=force` at boot (ext4), or rescue media (XFS). Repeated corruption = hardware.

**Interview questions**

1. *Why must you never run fsck on a mounted filesystem?* The kernel is reading and changing the same metadata at the same time, so the repair and the kernel would overwrite each other's changes and cause corruption.
2. *How do you repair XFS?* Unmount; mount and unmount once to replay the log; `xfs_repair -n` to preview; then `xfs_repair`. Use `-L` (zero the log) only if the log can't be replayed.
3. *What is `lost+found`?* A directory where repair tools put files that still have data but lost their directory entry; they're named by inode number.
