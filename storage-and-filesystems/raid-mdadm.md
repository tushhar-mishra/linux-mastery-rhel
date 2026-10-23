# Software RAID with mdadm

> **Sessions:** S43 · **[Advanced/Optional]** · core infrastructure and interview knowledge
> **Related:** [LVM thin provisioning & striping (LVM RAID)](lvm-thin-provisioning-and-striping.md) · [Filesystems & mkfs](filesystems-and-mkfs.md) · [Mounting & fstab](mounting-and-fstab.md)

## 1. Overview

**RAID** (Redundant Array of Independent Disks) combines disks for performance, redundancy, or both. On RHEL, software RAID is provided by the kernel **md** driver and managed with **`mdadm`**, producing devices like `/dev/md0` that you format and mount like any disk.

> **RAID is not a backup.** It survives disk failures, not deletion, corruption, ransomware or site loss.

## 2. RAID Levels

| Level | Min disks | Method | Survives | Usable capacity | Notes |
|---|---|---|---|---|---|
| **RAID 0** | 2 | Striping | **0** failures | 100 % | Fast, no redundancy |
| **RAID 1** | 2 | Mirroring | N−1 failures | 1 disk | Simple, fast reads |
| **RAID 5** | 3 | Striping + **distributed XOR parity** | 1 failure | (N−1)/N | Write penalty; long rebuilds on big disks |
| **RAID 6** | 4 | Striping + **two different parities** (P + Q) | 2 failures | (N−2)/N | Preferred over RAID 5 for large drives |
| **RAID 10** | 4 (classic) | Mirrors, then striped | 1 per mirror pair | 50 % | Best mix of speed + redundancy; md `raid10` also works on 2+ disks |

**Parity is XOR:** `1011 XOR 0101 = 1110`. Any one missing block can be rebuilt by XOR-ing the others.

## 3. Creating Arrays

```bash
dnf install -y mdadm
lsblk                                                       # pick EMPTY disks (not the OS disk)
mdadm --create /dev/md0 --level=1 --raid-devices=2 /dev/vdb /dev/vdc      # RAID 1
mdadm -C /dev/md0 -l 5 -n 3 /dev/vdb /dev/vdc /dev/vdd                   # RAID 5
mdadm -C /dev/md0 -l 5 -n 3 -x 1 /dev/vd{b,c,d,e}                        # RAID 5 + 1 hot spare
mdadm -C /dev/md0 -l 10 -n 4 /dev/vd{b,c,d,e}                            # RAID 10
cat /proc/mdstat                                            # [UU] = all members up; resync progress
```

Members can be whole disks or partitions (type "Linux RAID"). The array is usable while it's still resyncing.

### Make it persistent

```bash
mdadm --detail --scan >> /etc/mdadm.conf   # ARRAY /dev/md0 metadata=1.2 UUID=… (stable name at boot)
mkfs.xfs /dev/md0
mkdir -p /raid1 ; echo "UUID=$(blkid -s UUID -o value /dev/md0) /raid1 xfs defaults 0 0" >> /etc/fstab
systemctl daemon-reload ; mount -a
```

Without `/etc/mdadm.conf` the array may be assembled as `/dev/md127` after reboot. Mounting by filesystem UUID avoids depending on the name.

## 4. Monitoring

```bash
cat /proc/mdstat
mdadm --detail /dev/md0          # State: clean / degraded / recovering; member states
mdadm --examine /dev/vdb         # md superblock on a member disk
```

Alerts: set `MAILADDR root@example.com` in `/etc/mdadm.conf` and run `systemctl enable --now mdmonitor`. A failed disk with no alerting means the array silently runs degraded.

## 5. Handling a Failed Disk

```bash
mdadm /dev/md0 --fail /dev/vdb       # (simulate) mark faulty → State: clean, degraded
mdadm /dev/md0 --remove /dev/vdb     # remove from the array
# replace the disk physically (or attach a new virtual disk)
mdadm /dev/md0 --add /dev/vdd        # becomes "spare rebuilding" → resync
watch cat /proc/mdstat               # until [UU]
```

With a hot spare (`-x 1`), rebuild starts automatically on failure.

## 6. Growing, Stopping & Removing

```bash
mdadm /dev/md0 --add /dev/vde
mdadm --grow /dev/md0 --raid-devices=4      # reshape (e.g., RAID 5 from 3 to 4 disks); slow
xfs_growfs /raid5                            # then grow the filesystem

umount /raid1
mdadm --stop /dev/md0                        # deactivate
mdadm --zero-superblock /dev/vdb /dev/vdc    # ⚠️ wipe md metadata to reuse disks
# remove the ARRAY line from /etc/mdadm.conf and the fstab entry
```

## 7. Hardware vs Software vs LVM RAID

| | Hardware RAID controller | mdadm (software) | LVM RAID (`--type raid1/5/6/10`) |
|---|---|---|---|
| CPU cost | Offloaded | Host CPU (small for RAID 1/10) | Host CPU (uses md internally) |
| Portability | Tied to controller model | Any Linux system | Any Linux with LVM |
| Visibility/monitoring | Vendor tools | `/proc/mdstat`, mdadm | `lvs -a` |
| Typical use | Enterprise servers with battery-backed cache | Common and flexible | When you're already managing everything in LVM |

## 8. Production Practices **[Production Practice]**

- Use RAID 1/10 for OS and databases, RAID 6 for large capacity arrays; avoid RAID 5 on multi-TB disks.
- Enable `mdmonitor` alerts; test failure/rebuild procedures before production.
- Use disks of equal size and type; keep a hot spare for critical arrays.
- Schedule periodic scrubs (RHEL's `raid-check` runs weekly when configured) to find latent sector errors.
- Back up separately.

## 9. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Array appears as `/dev/md127` | Not in `/etc/mdadm.conf` | `mdadm --detail --scan >> /etc/mdadm.conf`; rebuild initramfs if root is on RAID |
| `[U_]` in mdstat / State: degraded | Member failed or missing | `--detail`; replace and `--add` |
| `mdadm: cannot open /dev/vdb: Device or resource busy` | Disk in use (old array, LVM, mounted) | `lsblk`; stop the old array; `--zero-superblock` |
| Rebuild very slow | Throttling | Tune `/proc/sys/dev/raid/speed_limit_min` [Advanced] |
| Old RAID metadata on a "new" disk | Previous array superblock | `mdadm --zero-superblock DEV` |

## 10. Interview Questions

| Question | Answer |
|---|---|
| RAID 5 vs RAID 6? | RAID 5 has one parity (survives 1 failure); RAID 6 has two independent parities (survives 2). |
| How does parity rebuild data? | XOR of the remaining blocks reconstructs the missing block. |
| RAID 10 vs RAID 01? | RAID 10 stripes across mirrors and is more resilient; RAID 01 mirrors stripes. |
| Is RAID a backup? | No. It only protects against disk hardware failure. |
| How do you replace a failed disk in mdadm? | `--fail`, `--remove`, replace, `--add`, watch `/proc/mdstat`. |

## 11. Course Corrections

| Course | Correction |
|---|---|
| RAID 5 parity "1011 − 0101 = 0010" | Parity is XOR: `1011 ⊕ 0101 = 1110` |
| RAID 6 diagram: same parity on two disks | Two **different** parities (P and Q) |
| RAID 5 diagram with a dedicated parity disk | Parity is distributed (dedicated = RAID 4); the text pages are correct |
| Infographic: RAID 0 with parity blocks; "No fault tolerance" under Advantages; RAID 1 "power down for rebuilds"; RAID 5 pros under Disadvantages | RAID 0 has no parity; md rebuilds online; labels reversed |
| Practical stops after create/fail/add | Add `/etc/mdadm.conf`, fstab by UUID, `mdmonitor`, `--zero-superblock` when reusing |
| `dnf list install mdadm` | `dnf list --installed mdadm` |

## 12. Quick Revision

```bash
mdadm -C /dev/md0 -l {0|1|5|6|10} -n N [-x SPARES] DEVS | cat /proc/mdstat | mdadm -D /dev/md0
mdadm --detail --scan >> /etc/mdadm.conf | mkfs + fstab UUID | systemctl enable --now mdmonitor
fail/replace: mdadm MD --fail D ; --remove D ; --add NEW
mdadm --grow MD --raid-devices=N | mdadm --stop MD | mdadm --zero-superblock D
0 none · 1 mirror · 5 XOR parity (1 fail) · 6 P+Q (2 fails) · 10 mirror+stripe · RAID ≠ backup
```

## 13. Cross-References

- [LVM thin provisioning & striping (LVM RAID)](lvm-thin-provisioning-and-striping.md)
- [Filesystems & mkfs](filesystems-and-mkfs.md) · [Mounting & fstab](mounting-and-fstab.md)
- Filesystem repair (S48): planned
