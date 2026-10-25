# DM-Multipath (Redundant Storage Paths)

> **[Advanced/Optional]** · SAN/iSCSI/FC production storage
> **Related:** [iSCSI](iscsi.md) · [LVM fundamentals (devices file)](../storage-and-filesystems/lvm-fundamentals.md) · [Network bonding (path redundancy at L2)](../networking-and-ssh/network-bonding.md) · [NetworkManager](../networking-and-ssh/networkmanager-nmcli.md)

## 1. Overview

When a LUN is reachable over **several paths** (two NICs/HBAs, two switches, two storage controllers), Linux sees one SCSI disk per path (`/dev/sdb`, `/dev/sdc` …). **DM-Multipath** recognizes that they share the same **WWID** and builds one device, `/dev/mapper/mpatha`, that:

- **fails over** when a path dies (no I/O errors to applications),
- optionally **load-balances** across active paths.

| Component | Role |
|---|---|
| `dm-multipath` kernel module | Device-mapper target doing the path switching |
| `multipathd` | Daemon: monitors paths, reinstates, fails over |
| `multipath` | Command to create/list/flush maps |
| `/etc/multipath.conf` | Configuration (defaults, blacklist, devices, multipaths) |
| `/etc/multipath/wwids`, `bindings` | Known WWIDs; mapping of `mpathX` names to WWIDs |

## 2. Lab Topology (two independent paths)

| Host | Path 1 | Path 2 |
|---|---|---|
| Target | 192.168.1.250/24 | **192.168.2.250/24** |
| Initiator | 192.168.1.252/24 | **192.168.2.252/24** |

Put each path on **its own subnet** (separate host-only networks). With two NICs in the same subnet, the kernel may route both "paths" through one NIC.

````bash
nmcli con add type ethernet con-name path1 ifname enp0s8 ip4 192.168.1.252/24 ; nmcli con up path1
nmcli con add type ethernet con-name path2 ifname enp0s9 ip4 192.168.2.252/24 ; nmcli con up path2
````

## 3. Target: Expose the LUN on Both Portals

````
targetcli
/> /backstores/fileio create lun1 /iscsi_disks/lun1.img 5G
/> /iscsi create iqn.2024-10.local.lab:storage.target1
/> cd /iscsi/iqn.2024-10.local.lab:storage.target1/tpg1
…/tpg1> luns create /backstores/fileio/lun1
…/tpg1> acls create iqn.1994-05.com.redhat:client01         # per-initiator ACL (preferred over demo mode)
…/tpg1> portals/ delete 0.0.0.0 3260
…/tpg1> portals/ create 192.168.1.250 3260
…/tpg1> portals/ create 192.168.2.250 3260
…/tpg1> cd / ; saveconfig ; exit
````

````bash
systemctl enable --now target
firewall-cmd --permanent --add-service=iscsi-target ; firewall-cmd --reload
````

Demo mode for quick labs only: `set attribute authentication=0 generate_node_acls=1 cache_dynamic_acls=1 demo_mode_write_protect=0`. Without the last setting, LUNs are **read-only**.

## 4. Initiator: Log In on Both Paths & Enable Multipath

````bash
dnf install -y iscsi-initiator-utils device-mapper-multipath
iscsiadm -m discovery -t sendtargets -p 192.168.1.250      # lists both portals
iscsiadm -m node --login                                    # log in to all discovered portals
lsblk                                                        # sdb and sdc: same size, same LUN
/usr/lib/udev/scsi_id -g -u /dev/sdb ; /usr/lib/udev/scsi_id -g -u /dev/sdc   # identical WWIDs

mpathconf --enable --with_multipathd y                      # creates /etc/multipath.conf, starts multipathd
multipath -ll                                                # mpatha (WWID) dm-N … two paths "active ready running"
ls -l /dev/mapper/
````

## 5. `/etc/multipath.conf`

````
defaults {
    user_friendly_names yes        # mpathX names (else the WWID is the name)
    find_multipaths on             # only devices with >1 path (or known WWIDs)
}

blacklist {
    wwid "36000c29f0123456789abcdef01234567"     # local disk — blacklist by WWID, not by sda
}

multipaths {
    multipath {
        wwid  "3600140524b357a7552d42a3b5ecdd96c"
        alias "iscsi_data"          # /dev/mapper/iscsi_data
    }
}
````

- Built-in defaults already cover common arrays, including LIO (`LIO-ORG`). Add a `devices { device { … } }` override only when the vendor documents one. View the effective configuration with `multipathd show config`.
- Apply changes with `systemctl reload multipathd` (or `multipathd reconfigure`); `multipath -ll` to verify.

## 6. Using the Multipath Device

````bash
pvcreate /dev/mapper/mpatha ; vgcreate vg_san /dev/mapper/mpatha ; lvcreate -n data -l 100%FREE vg_san
mkfs.xfs /dev/vg_san/data ; mkdir -p /san
echo '/dev/vg_san/data /san xfs _netdev,nofail 0 0' >> /etc/fstab
systemctl daemon-reload ; mount -a
````

Always use `/dev/mapper/mpathX` (or LVM on top of it), **never** the individual path devices (`sdb`, `sdc`). With the RHEL 9/10 LVM devices file, the multipath device (not its paths) is what gets added.

## 7. Failover Test

````bash
multipathd show paths                 # all paths: active/ready
nmcli con down path2                  # on the initiator (or take down a target portal NIC)
multipath -ll                         # one path "failed faulty", the other active; I/O continues
dd if=/dev/zero of=/san/test bs=1M count=100 oflag=direct    # still works
nmcli con up path2 ; multipath -ll    # path reinstated
````

## 8. Commands

| Command | Purpose |
|---|---|
| `multipath -ll` | Show maps and path states |
| `multipath -v2` / `multipath -r` | Create / reload maps |
| `multipath -f mpatha` / `multipath -F` | Flush one / all **unused** maps |
| `multipathd show paths` / `show maps` / `show config` | Live daemon views |
| `mpathconf --enable` / `--disable` | Manage basic config and service |

## 9. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Only `sdb`/`sdc`, no mpath device | multipathd not running / `find_multipaths` / blacklisted | `mpathconf --enable --with_multipathd y`; `multipath -v3` |
| Both paths fail together | Paths share a NIC/subnet/switch | Separate subnets and hardware |
| LUN read-only (`wp=ro`, `RO 1`) | LIO demo mode write-protect | ACLs or `demo_mode_write_protect=0` |
| Local disk got multipathed | Not blacklisted | Blacklist by WWID; rebuild initramfs (`dracut -f`) if the boot disk is involved |
| `Could not create NetworkPortal` on target | `0.0.0.0:3260` already bound | Delete the 0.0.0.0 portal first |
| LVM "duplicate PV" warnings | LVM sees path devices | Use the devices file with `/dev/mapper/mpathX` only |

## 10. Interview Questions

| Question | Answer |
|---|---|
| What problem does multipath solve? | Redundant (and optionally load-balanced) access to one LUN over several paths, with transparent failover. |
| How does it know two disks are the same LUN? | Same SCSI WWID. |
| Why not use `/dev/sdb` directly? | It's a single path; if it fails, I/O fails. Use `/dev/mapper/mpathX`. |
| `user_friendly_names`? | Names like `mpatha` instead of WWIDs (mapping kept in `/etc/multipath/bindings`). |

## 11. Quick Revision

````bash
dnf install device-mapper-multipath · mpathconf --enable --with_multipathd y · multipath -ll · multipathd show paths
/etc/multipath.conf: defaults{user_friendly_names find_multipaths} blacklist{wwid} multipaths{multipath{wwid alias}}
use /dev/mapper/mpathX (LVM on top) · fstab _netdev,nofail · separate subnets per path · scsi_id -g -u /dev/sdX
````

## 12. Cross-References

- [iSCSI](iscsi.md)
- [LVM fundamentals (devices file)](../storage-and-filesystems/lvm-fundamentals.md)
- [Network bonding (path redundancy at L2)](../networking-and-ssh/network-bonding.md)
- [NetworkManager](../networking-and-ssh/networkmanager-nmcli.md)
