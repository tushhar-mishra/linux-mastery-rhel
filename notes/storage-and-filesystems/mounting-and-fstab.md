# Mounting, Mount Options & /etc/fstab

> **Objectives:** *Configure systems to mount file systems at boot by UUID or label* · *Create, mount, unmount, and use VFAT, ext4, and XFS file systems* **[RHCSA Core]**
> **Related:** [Disks & partitioning](disks-and-partitioning.md) · [Filesystems & mkfs](filesystems-and-mkfs.md) · [Filesystem hierarchy](../linux-fundamentals/filesystem-hierarchy.md) · [Special permissions (nosuid)](../users-groups-and-permissions/special-permissions-and-acls.md) · [NFS & autofs](../system-services-and-shared-storage/nfs-and-autofs.md) · [Storage I/O path](storage-io-path.md)

## 1. Overview

**Mounting** attaches a filesystem to a directory (the **mount point**) in the single directory tree. Whatever was in that directory is hidden until you unmount. Mounts made with `mount` disappear at reboot; **`/etc/fstab`** makes them permanent. On RHEL, systemd reads fstab at boot (via generated `.mount` units).

## 2. Mounting & Unmounting

```bash
mkdir -p /data
mount /dev/vdb1 /data                   # type auto-detected
mount -t ext4 -o ro /dev/vdb2 /mnt      # explicit type + options
mount UUID=1b2c… /data                  # by UUID
mount LABEL=DATA /data                  # by label
mount -o remount,rw /data               # change options of a mounted FS
umount /data                            # by mount point (preferred) or by device
```

### Viewing mounts

```bash
findmnt                         # tree of all mounts
findmnt /data                   # one mount: SOURCE, FSTYPE, OPTIONS
findmnt -T /data/file.txt       # which mount contains this path
df -hT                          # usage + type per filesystem
lsblk -f                        # devices with mount points
cat /proc/mounts                # kernel's view (/etc/mtab is a symlink to it)
```

## 3. Mount Options

| Option | Effect |
|---|---|
| `defaults` | `rw,suid,dev,exec,auto,nouser,async` |
| `ro` / `rw` | Read-only / read-write |
| `noexec` | Can't **directly** execute binaries/scripts (`bash /mnt/x.sh` still works) |
| `nosuid` | Ignore SUID/SGID bits (programs run as the invoking user) |
| `nodev` | Ignore device files |
| `noatime` / `relatime` | Never update access times / update only if older than mtime (RHEL default) |
| `nofail` | Don't fail the boot if the device is missing |
| `_netdev` | Wait for the network (iSCSI, NFS) |
| `x-systemd.automount` | Mount on first access (systemd automount) **[Advanced]** |
| `uid=`, `gid=`, `umask=` | **VFAT only**: owner and permissions for all files (VFAT has no Unix permissions) |
| `context="…"` | SELinux context for filesystems without labels (VFAT, NFS) **[Advanced]** |

Hardening baseline for `/tmp`, `/var/tmp`, `/dev/shm`, removable media: `nodev,nosuid,noexec`.

## 4. `/etc/fstab` **[RHCSA Core]**

```
# <device>                                 <mount point>  <type>  <options>          <dump> <fsck>
UUID=5d0e8f1a-3c2b-4e8e-9a51-1f1c0d6b2a77   /data          xfs     defaults           0      0
LABEL=LOGS                                  /logs          ext4    defaults,noatime   0      2
UUID=3F2A-1B9C                              /usb           vfat    defaults,uid=1001,gid=1001,umask=022  0 0
UUID=9b1e…                                  none           swap    defaults           0      0
```

| Field | Meaning |
|---|---|
| 1 Device | `UUID=…` (**preferred**), `LABEL=…`, `/dev/mapper/vg-lv` (stable for LVM), or NFS `server:/export` |
| 2 Mount point | Must exist (`mkdir -p`); `none` for swap |
| 3 Type | `xfs`, `ext4`, `vfat`, `swap`, `nfs` … |
| 4 Options | Comma-separated, no spaces |
| 5 Dump | `0` (legacy backup flag) |
| 6 fsck order | `0` = skip (**XFS, swap, network**), `1` = root ext4, `2` = other ext4 |

### 4.1 Persistent mount recipe (exam-safe)

```bash
blkid /dev/vdb1                                       # copy the UUID (not PARTUUID)
mkdir -p /data
echo 'UUID=<uuid> /data xfs defaults 0 0' >> /etc/fstab   # or edit with vim
systemctl daemon-reload                               # systemd regenerates mount units from fstab
mount -a                                              # mounts everything in fstab not yet mounted; errors appear NOW
findmnt --verify                                      # syntax/consistency check of fstab
findmnt /data ; df -hT /data                          # confirm
```

> ⚠️ **A broken fstab can stop the boot** (emergency mode). Always run `mount -a` and `findmnt --verify` before rebooting. On RHEL 10 the root account is disabled by default, so the emergency shell may refuse access; recovery then requires interrupting the boot ([boot recovery](../boot-systemd-and-kernel/boot-recovery.md)). Add `nofail` to non-essential mounts.

## 5. Swap Basics

```bash
mkswap /dev/vdb4                                     # write swap signature
swapon /dev/vdb4                                     # activate now
echo 'UUID=<uuid> none swap defaults 0 0' >> /etc/fstab
swapon -a ; swapon --show ; free -h                  # activate from fstab and verify
```

## 6. Busy Unmounts

```bash
umount /data                  # umount: /data: target is busy.
cd /                          # are YOU inside it?
lsof +f -- /data              # which processes use it
fuser -vm /data               # same, with users/PIDs; fuser -km kills them ⚠️
umount -l /data               # lazy unmount: detach now, finish when idle (use sparingly)
```

## 7. RHCSA Exam Focus **[RHCSA Core]**

- Mount **by UUID or label** in fstab, at the **exact** mount point, with the requested options.
- XFS → fsck field `0`; ext4 data → `2`.
- After editing: `systemctl daemon-reload`, `mount -a`, `findmnt --verify`, and a test reboot near the end of the exam.
- VFAT mounts usually need `uid`/`gid`/`umask` if users must write to them.
- For swap tasks: `swapon --show` must list it after reboot.

## 8. Production Practices **[Production Practice]**

- Use UUIDs or `/dev/mapper/` names; never `sdX`.
- `nofail` (+ `x-systemd.device-timeout=10s`) for optional disks so a missing disk doesn't block the boot.
- `_netdev` for network-backed storage.
- Keep a copy before editing: `cp -a /etc/fstab /etc/fstab.bak.$(date +%F)`.
- Mounting over a non-empty directory hides its contents (a common cause of "missing" data and "disk full but `du` disagrees").

## 9. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `mount: (hint) your fstab has been modified, but systemd still uses the old version` | fstab edited | `systemctl daemon-reload` |
| `mount: /data: mount point does not exist` | Directory missing | `mkdir -p /data` |
| `wrong fs type, bad option, bad superblock` | Wrong type/option, no FS, typo | `blkid`; `findmnt --verify`; `dmesg` |
| `can't find UUID=…` | Typo or used PARTUUID | Copy the `UUID=` value from `blkid` |
| `target is busy` on umount | Open files / a shell's cwd | `lsof`, `fuser -vm`; `cd` out |
| Boot drops to emergency mode | Bad fstab line or missing device | At the console: fix fstab (`mount -o remount,rw /` first), or boot with `systemd.unit=emergency.target`/`rd.break` ([boot recovery](../boot-systemd-and-kernel/boot-recovery.md)) |
| Users can't write to a VFAT mount | VFAT has no Unix perms; mounted as root | `uid=`, `gid=`, `umask=` options |
| `noexec` "isn't working" | Script run via interpreter | Expected; `noexec` blocks only direct execution |

## 10. Interview Questions

| Question | Answer |
|---|---|
| What are the six fstab fields? | Device, mount point, type, options, dump, fsck order. |
| Why UUID instead of `/dev/sdb1`? | Kernel names can change; UUIDs identify the filesystem itself. |
| What does `mount -a` do? | Mounts everything in fstab that isn't mounted (except `noauto`), so it tests fstab without a reboot. |
| Why `systemctl daemon-reload` after editing fstab? | systemd generates mount units from fstab; reload regenerates them. |
| `noexec` vs `nosuid`? | noexec blocks direct execution; nosuid ignores SUID/SGID bits. |
| How do you find what's keeping a filesystem busy? | `lsof +f -- MNT` or `fuser -vm MNT`. |

## 11. Quick Revision

```bash
mount [-t T] [-o opts] DEV|UUID=|LABEL= MNT · umount MNT · mount -o remount,ro MNT
findmnt [MNT] [-T path] [--verify] · df -hT · lsblk -f · blkid
fstab: UUID=… /mnt xfs defaults 0 0 · ext4 … 0 2 · swap: UUID=… none swap defaults 0 0
edit → systemctl daemon-reload → mount -a → findmnt --verify → reboot test
options: ro noexec nosuid nodev noatime nofail _netdev uid= gid= umask= (vfat)
busy: lsof +f -- MNT · fuser -vm MNT · umount -l
```

## 12. Cross-References

- [Disks & partitioning](disks-and-partitioning.md)
- [Filesystems & mkfs](filesystems-and-mkfs.md)
- [Filesystem hierarchy](../linux-fundamentals/filesystem-hierarchy.md)
- [LVM fundamentals](lvm-fundamentals.md) · [Swap](swap.md) · [NFS & autofs](../system-services-and-shared-storage/nfs-and-autofs.md) · [Boot recovery (broken fstab)](../boot-systemd-and-kernel/boot-recovery.md#5-fix-a-broken-etcfstab)
