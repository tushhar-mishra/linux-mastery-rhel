# Stratis Storage

> **Sessions:** S46 · **[Advanced/Optional]** (in older RHCSA versions, not in RHEL 10's objectives)
> **Related:** [LVM thin provisioning](lvm-thin-provisioning-and-striping.md) · [LVM VDO](lvm-vdo.md) · [LUKS encryption](luks-encryption.md) · [Mounting & fstab](mounting-and-fstab.md)

## 1. Overview

**Stratis** is a pool-based local storage manager that hides the usual partition → LVM → mkfs steps behind one CLI. Under the hood it uses device-mapper, thin provisioning and **XFS**, and it can encrypt pools with LUKS2.

`````
block devices (/dev/vdb, /dev/vdc)  →  pool  (data tier [+ optional cache tier])  →  filesystems (thin, XFS)
                                                                                      /dev/stratis/<pool>/<fs>
`````

| Component | Role |
|---|---|
| `stratisd` | Daemon that manages pools (must be running) |
| `stratis` (stratis-cli) | Command-line client |
| Pool | One or more whole block devices |
| Filesystem | Thinly provisioned XFS that grows automatically within the pool |

## 2. Install & Prepare

`````bash
dnf install -y stratisd stratis-cli
systemctl enable --now stratisd
blkid -p /dev/vdb            # no output = no signatures (clean)
wipefs -a /dev/vdb           # ⚠️ clear old signatures/partition tables if the disk is meant to be reused
`````

Devices must be **unpartitioned and unused** (no filesystem, LVM or RAID signatures).

## 3. Pools

`````bash
stratis pool create pool1 /dev/vdb                 # one disk
stratis pool create pool2 /dev/vdc /dev/vdd        # several disks
stratis pool list                                  # Total / Used / Free physical space
stratis pool add-data pool1 /dev/vde               # grow a pool
stratis blockdev list                              # devices per pool
stratis pool init-cache pool1 /dev/nvme0n2         # optional SSD cache tier [Advanced]
`````

## 4. Filesystems

`````bash
stratis filesystem create pool1 fs1                # (newer versions accept --size)
stratis filesystem list                            # includes UUIDs
mkdir -p /data
mount /dev/stratis/pool1/fs1 /data
df -hT /data                                       # shows a large VIRTUAL size (thin)
`````

### Persistent mount (required option!)

`````bash
blkid /dev/stratis/pool1/fs1                       # UUID
echo 'UUID=<uuid> /data xfs defaults,x-systemd.requires=stratisd.service 0 0' >> /etc/fstab
systemctl daemon-reload ; mount -a
`````

> ⚠️ Without `x-systemd.requires=stratisd.service`, systemd may try to mount the filesystem before stratisd has set it up. Boot then hangs or drops to emergency mode.

## 5. Snapshots

`````bash
stratis filesystem snapshot pool1 fs1 fs1-snap     # point-in-time copy (itself a filesystem)
mkdir -p /mnt/snap ; mount /dev/stratis/pool1/fs1-snap /mnt/snap
cp -a /mnt/snap/lost-file /data/                   # restore individual files
`````

**Roll back the whole filesystem:** unmount `fs1` and mount the snapshot at `/data` instead (updating fstab to the snapshot's UUID). Newer Stratis versions also offer `stratis filesystem schedule-revert`.

**Delete a snapshot:** `umount /mnt/snap ; stratis filesystem destroy pool1 fs1-snap`.

## 6. Removing

`````bash
umount /data ; vi /etc/fstab                      # remove the entry
stratis filesystem destroy pool1 fs1
stratis pool destroy pool1                        # pool must have no filesystems
`````

## 7. Encrypted Pools **[Advanced]**

`````bash
stratis key set --capture-key mykey               # store a passphrase in the kernel keyring
stratis pool create --key-desc mykey secpool /dev/vdf
`````

Encrypted pools must be unlocked/started after boot with the key or a Clevis (Tang/TPM2) binding. The exact syntax varies by stratis-cli version (`stratis pool --help`).

## 8. Production Practices **[Production Practice]**

- Monitor **pool** usage (`stratis pool list`); `df` reflects virtual size, not physical capacity.
- Always include `x-systemd.requires=stratisd.service` in fstab.
- Use whole, dedicated disks; keep stratisd enabled.
- For complex layouts (RAID, specific LV sizes, sharing), plain LVM is more flexible.

## 9. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `stratis pool create` refuses a device | Existing signature / partition table | `blkid -p DEV`; `wipefs -a DEV` (if safe) |
| Boot hangs / emergency mode | fstab lacks `x-systemd.requires=stratisd.service` | Add it; `systemctl daemon-reload` |
| `stratis` commands fail to connect | `stratisd` not running | `systemctl enable --now stratisd` |
| Writes fail although `df` shows space | Physical pool full | `stratis pool add-data` |
| `pool destroy` fails | Filesystems still exist | Destroy filesystems first |

## 10. Interview Questions

| Question | Answer |
|---|---|
| What is Stratis built on? | device-mapper, thin provisioning and XFS, managed by the stratisd daemon. |
| Why does `df` show a huge size? | Filesystems are thinly provisioned; real capacity is the pool's. |
| Special fstab requirement? | `x-systemd.requires=stratisd.service`. |
| How do you add capacity? | `stratis pool add-data POOL DEV`. |

## 11. Quick Revision

`````bash
dnf install stratisd stratis-cli ; systemctl enable --now stratisd ; blkid -p / wipefs -a
stratis pool create P DEVS | pool list | pool add-data P DEV | blockdev list
stratis filesystem create P FS | filesystem list | mount /dev/stratis/P/FS MNT
fstab: UUID=… MNT xfs defaults,x-systemd.requires=stratisd.service 0 0
snapshot P FS SNAP | filesystem destroy P FS | pool destroy P
`````

## 12. Cross-References

- [LVM thin provisioning](lvm-thin-provisioning-and-striping.md)
- [LVM VDO](lvm-vdo.md)
- [LUKS encryption](luks-encryption.md)
- [Mounting & fstab](mounting-and-fstab.md)
