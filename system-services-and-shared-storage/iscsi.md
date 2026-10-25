# iSCSI Target (targetcli) & Initiator (iscsiadm)

> **Sessions:** S99 · **[Advanced/Optional]**
> **Related:** [Multipath](multipath.md) · [Disks & partitioning](../storage-and-filesystems/disks-and-partitioning.md) · [LVM fundamentals](../storage-and-filesystems/lvm-fundamentals.md) · [Mounting & fstab (`_netdev`)](../storage-and-filesystems/mounting-and-fstab.md)

## 1. Overview

**iSCSI** carries SCSI block commands over TCP/IP. A **target** (server) exports block storage as **LUNs**; an **initiator** (client) logs in and sees them as local disks (`/dev/sdX`). RHEL's target is the kernel **LIO** framework, managed with `targetcli`.

| Term | Meaning |
|---|---|
| **IQN** | iSCSI Qualified Name: `iqn.YYYY-MM.reversed.domain:identifier` (e.g., `iqn.2024-10.local.lab:storage.target1`) |
| **Backstore** | Storage behind a LUN: `block` (disk/LV), `fileio` (image file), `pscsi`, `ramdisk` (volatile) |
| **TPG** | Target Portal Group (`tpg1`): holds LUNs, ACLs, portals |
| **Portal** | IP:port the target listens on (default `0.0.0.0:3260`) |
| **ACL** | Initiator IQNs allowed to access the TPG |

Port: **3260/tcp**.

## 2. Target (Server)

```bash
dnf install -y targetcli
systemctl enable --now target            # restores saved config at boot (NOT iscsid)
lsblk                                    # pick a DEDICATED disk or LV — never the OS disk
targetcli
```

````
/> /backstores/block create newlun /dev/vg_iscsi/lv_lun1        # or: fileio create lun1 /iscsi_disks/lun1.img 5G
/> /iscsi create iqn.2024-10.local.lab:storage.target1
/> cd /iscsi/iqn.2024-10.local.lab:storage.target1/tpg1
/iscsi/…/tpg1> luns create /backstores/block/newlun
/iscsi/…/tpg1> acls create iqn.1994-05.com.redhat:client01       # initiator's IQN (from the client)
/iscsi/…/tpg1> portals/ ls                                        # 0.0.0.0:3260 by default
/iscsi/…/tpg1> cd /
/> ls
/> saveconfig                                                     # /etc/target/saveconfig.json (also auto-saved on exit)
/> exit
`````

`````bash
firewall-cmd --permanent --add-service=iscsi-target ; firewall-cmd --reload
`````

**CHAP (optional)** **[Advanced]**: in `acls/<iqn>`: `set auth userid=user password=secret`. On the initiator, set `node.session.auth.*` in `/etc/iscsi/iscsid.conf`.

## 3. Initiator (Client)

`````bash
dnf install -y iscsi-initiator-utils
cat /etc/iscsi/initiatorname.iscsi          # InitiatorName=iqn.1994-05.com.redhat:…  (must match the target ACL)
# (if changed) vi /etc/iscsi/initiatorname.iscsi ; systemctl restart iscsid
iscsiadm -m discovery -t sendtargets -p 192.168.229.132
iscsiadm -m node -T iqn.2024-10.local.lab:storage.target1 -p 192.168.229.132 -l   # log in (-p required)
systemctl enable iscsi                      # log in to saved nodes at boot (node.startup = automatic)
iscsiadm -m session -P 3 | grep -E 'Target|Attached scsi disk'
lsblk ; ls -l /dev/disk/by-path/ | grep iscsi   # identify the NEW disk (not the OS disk)
`````

### Use the LUN

`````bash
parted -s /dev/sdb mklabel gpt mkpart data xfs 1MiB 100%     # (or LVM)
mkfs.xfs /dev/sdb1
mkdir -p /newlun
echo "UUID=$(blkid -s UUID -o value /dev/sdb1) /newlun xfs _netdev,nofail 0 0" >> /etc/fstab
systemctl daemon-reload ; mount -a ; df -hT /newlun
`````

### Log out / remove

`````bash
umount /newlun
iscsiadm -m node -T IQN -p 192.168.229.132 -u          # logout
iscsiadm -m node -T IQN -p 192.168.229.132 -o delete   # forget the node record
`````

## 4. Production Practices **[Production Practice]**

- Dedicated storage network (separate subnets/VLANs), jumbo frames where supported.
- Per-initiator ACLs (plus CHAP); never demo mode in production.
- Use **multipath** for redundant paths ([multipath note](multipath.md)).
- Always `_netdev` (and usually `nofail`) in fstab for iSCSI filesystems; mount by UUID or `/dev/mapper` names.

## 5. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `iscsiadm: … Could not log into all portals … authorization failure` | Initiator IQN not in ACL / changed without restarting iscsid | Fix ACL or initiatorname; `systemctl restart iscsid` |
| Discovery: `No route to host` / timeout | Firewall / network | `iscsi-target` service; ping the portal |
| LUN is read-only (`RO 1`) | Demo mode (`generate_node_acls=1`) with `demo_mode_write_protect=1` | Use ACLs, or `set attribute demo_mode_write_protect=0` |
| Config lost after target reboot | `target.service` not enabled / not saved | `systemctl enable target`; `saveconfig` |
| Boot hang mounting iSCSI fs | Missing `_netdev` | Add `_netdev,nofail` |
| `Could not create NetworkPortal in configFS` | Port already bound by `0.0.0.0` portal | Delete the 0.0.0.0 portal before adding specific IPs |

## 6. Interview Questions

| Question | Answer |
|---|---|
| Target vs initiator? | The target exports LUNs; the initiator consumes them as block devices. |
| What's an IQN? | iSCSI Qualified Name: a unique identifier for targets and initiators. |
| How is access controlled? | ACLs by initiator IQN, optionally CHAP authentication. |
| Why `_netdev` in fstab? | The network (and iSCSI login) must be up before mounting. |

## 7. Quick Revision

`````
target: dnf install targetcli ; systemctl enable --now target ; targetcli
  /backstores/block|fileio create NAME DEV|FILE SIZE · /iscsi create IQN · tpg1/luns create … · tpg1/acls create INIT-IQN · saveconfig
  firewall iscsi-target (3260/tcp)
initiator: dnf install iscsi-initiator-utils · /etc/iscsi/initiatorname.iscsi (restart iscsid) ·
  iscsiadm -m discovery -t st -p IP · -m node -T IQN -p IP -l / -u / -o delete · -m session -P 3 · fstab UUID _netdev,nofail
`````

## 8. Cross-References

- [Multipath](multipath.md)
- [Disks & partitioning](../storage-and-filesystems/disks-and-partitioning.md)
- [LVM fundamentals](../storage-and-filesystems/lvm-fundamentals.md)
- [Mounting & fstab (`_netdev`)](../storage-and-filesystems/mounting-and-fstab.md)
