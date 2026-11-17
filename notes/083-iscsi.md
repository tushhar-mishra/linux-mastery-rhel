# 083 · iSCSI: Block Storage over the Network

> **You need first:** [082 · FTP with vsftpd](082-ftp-vsftpd.md)
> **Next:** [084 · Multipath](084-multipath.md)

---

## What it is

**iSCSI** (Internet Small Computer Systems Interface) sends **SCSI disk commands over TCP/IP**. A server exports **raw block devices**, and clients see them as **local disks** (`/dev/sdb`), which they partition, format and mount like any disk (topics 046–049).

- **SCSI** is the command language computers use to talk to disks ("read block 1000", "write block 2000").
- **SAN** (Storage Area Network): a network dedicated to block storage. iSCSI makes one out of ordinary Ethernet; **Fibre Channel** (FC) is the traditional, special-hardware alternative.

| Term | Meaning |
|---|---|
| **Target** | The **server** that exports storage (on RHEL: the kernel's **LIO** framework, managed with `targetcli`) |
| **Initiator** | The **client** that logs in and uses the storage (`iscsiadm`) |
| **LUN** (Logical Unit Number) | One exported block device |
| **IQN** (iSCSI Qualified Name) | A unique name for a target or initiator: `iqn.YYYY-MM.reversed.domain:identifier`, like `iqn.2026-11.lan.example:storage.t1` |
| **Backstore** | What's behind a LUN: `block` (a disk or LV), `fileio` (an image file), `ramdisk` |
| **TPG** (Target Portal Group) | Holds the LUNs, ACLs and portals of a target |
| **Portal** | The IP:port the target listens on (default `0.0.0.0:3260`) |
| **ACL** | Which initiator IQNs may connect |

Port: **TCP 3260**.

## Why it exists

**NFS and Samba share files**; iSCSI shares **disks**. Some workloads need a real block device: databases that want their own filesystem, VM disk images, clustered filesystems, or applications that don't support network file shares. iSCSI lets a central storage array (or a Linux server) provide those disks to many machines over the normal network.

## Analogy

NFS is a **shared library**: everyone reads books (files) from the same shelves. iSCSI is **renting someone a whole empty storage unit** (a disk) that only they use: they bring their own shelving (filesystem) and arrange it however they like. The storage unit just happens to be across town, reached by road (the network) instead of being in their house.

## How it works inside

1. The **target** maps a backstore (an LV, a disk, an image file) to a **LUN** inside a TPG and listens on its portal.
2. The **initiator** performs **discovery** (asks the portal "which targets do you have?"), then **logs in** to a target. The ACL must contain the initiator's IQN (from `/etc/iscsi/initiatorname.iscsi`); optionally **CHAP** (Challenge-Handshake Authentication Protocol) adds a password.
3. The login creates a **session**. The kernel's SCSI layer registers the LUN as a new disk, `/dev/sdX`, exactly as if a disk had been plugged in.
4. Every read and write on that disk becomes SCSI commands carried inside TCP packets to the target, which performs them on its backstore.
5. **Only one machine should mount a normal filesystem (XFS/ext4) on a LUN at a time.** Two hosts writing the same XFS **corrupts** it, because neither knows what the other cached. Sharing a LUN needs a **cluster filesystem** (GFS2, OCFS2) or a cluster manager.

Because the disk only exists after the **network** is up and the **login** has happened, fstab entries need `_netdev` (topic 048).

## Commands

### Target (server)

```bash
sudo dnf install -y targetcli
sudo systemctl enable --now target       # restores the saved configuration at every boot
lsblk                                    # pick a DEDICATED disk or LV, never the OS disk
sudo lvcreate -n lun1 -L 2G vgdata       # an LV to export (topic 049)
sudo targetcli
```
```
/> /backstores/block create lun1 /dev/vgdata/lun1
Created block storage object lun1 using /dev/vgdata/lun1.
/> /iscsi create iqn.2026-11.lan.example:storage.t1
Created target iqn.2026-11.lan.example:storage.t1.
Created TPG 1.
Global pref auto_add_default_portal=true
Created default portal listening on all IPs (0.0.0.0), port 3260.
/> cd /iscsi/iqn.2026-11.lan.example:storage.t1/tpg1
/iscsi/iqn.20...e.t1/tpg1> luns create /backstores/block/lun1
Created LUN 0.
/iscsi/iqn.20...e.t1/tpg1> acls create iqn.1994-05.com.redhat:server1
Created Node ACL for iqn.1994-05.com.redhat:server1
Created mapped LUN 0.
/iscsi/iqn.20...e.t1/tpg1> cd /
/> ls
o- / ......................................................................... [...]
  o- backstores .............................................................. [...]
  | o- block .................................................. [Storage Objects: 1]
  | | o- lun1 ................... [/dev/vgdata/lun1 (2.0GiB) write-thru activated]
  o- iscsi ............................................................ [Targets: 1]
    o- iqn.2026-11.lan.example:storage.t1 ................................ [TPGs: 1]
      o- tpg1 ............................................... [no-gen-acls, no-auth]
        o- acls .......................................................... [ACLs: 1]
        | o- iqn.1994-05.com.redhat:server1 ....................... [Mapped LUNs: 1]
        o- luns .......................................................... [LUNs: 1]
        | o- lun0 .............. [block/lun1 (/dev/vgdata/lun1) (default_tg_pt_gp)]
        o- portals .................................................... [Portals: 1]
          o- 0.0.0.0:3260 ..................................................... [OK]
/> saveconfig
/> exit
```
- `targetcli` is a shell with a tree; `ls` shows the whole configuration. `saveconfig` writes `/etc/target/saveconfig.json` (it's also saved on exit).

```bash
sudo firewall-cmd --permanent --add-service=iscsi-target ; sudo firewall-cmd --reload
```

**CHAP** (optional): inside `acls/<iqn>` run `set auth userid=user password=secret`; on the initiator, set `node.session.auth.*` in `/etc/iscsi/iscsid.conf`.

### Initiator (client)

```bash
sudo dnf install -y iscsi-initiator-utils           # Ubuntu: open-iscsi
sudo systemctl start iscsid                          # first start generates the name if the file is missing
sudo grep InitiatorName /etc/iscsi/initiatorname.iscsi    # root-only file (mode 600)
```
```
InitiatorName=iqn.1994-05.com.redhat:server1
```
- This must match the target's ACL. If you change it, run `sudo systemctl restart iscsid`.

```bash
sudo iscsiadm -m discovery -t sendtargets -p 192.168.56.11
sudo iscsiadm -m node -T iqn.2026-11.lan.example:storage.t1 -p 192.168.56.11 -l
```
```
192.168.56.11:3260,1 iqn.2026-11.lan.example:storage.t1
Login to [iface: default, target: iqn.2026-11.lan.example:storage.t1, portal: 192.168.56.11,3260] successful.
```

```bash
sudo iscsiadm -m session -P 3 | grep -E 'Target:|Attached scsi disk'
lsblk ; ls -l /dev/disk/by-path/ | grep iscsi
```
```
Target: iqn.2026-11.lan.example:storage.t1 (non-flash)
		Attached scsi disk sdb		State: running
lrwxrwxrwx. 1 root root 9 Nov 16 19:30 ip-192.168.56.11:3260-iscsi-iqn.2026-11.lan.example:storage.t1-lun-0 -> ../../sdb
```
- The LUN appeared as `sdb`. The `/dev/disk/by-path` name shows clearly that it's iSCSI.

```bash
sudo systemctl enable iscsi          # log back in to saved targets at every boot
```

### Use the LUN

```bash
sudo parted -s /dev/sdb mklabel gpt mkpart data xfs 1MiB 100%
# parted may warn "not properly aligned for best performance": LIO reports an odd optimal I/O size; 1 MiB alignment is fine
sudo mkfs.xfs /dev/sdb1
sudo mkdir -p /iscsidata
echo "UUID=$(sudo blkid -s UUID -o value /dev/sdb1) /iscsidata xfs _netdev,nofail 0 0" | sudo tee -a /etc/fstab
sudo systemctl daemon-reload && sudo mount -a && df -hT /iscsidata
```
- **`_netdev`** is essential: without it, the boot tries to mount before the network and the login exist.

### Log out and clean up

```bash
sudo umount /iscsidata
sudo iscsiadm -m node -T iqn.2026-11.lan.example:storage.t1 -p 192.168.56.11 -u          # log out
sudo iscsiadm -m node -T iqn.2026-11.lan.example:storage.t1 -p 192.168.56.11 -o delete   # forget it
```

### Try it
1. Export a 2 GiB LV from server2 as an iSCSI LUN with an ACL for server1.
2. On server1, discover, log in, create XFS, mount it with `_netdev`, reboot and confirm it's back.
3. Change server1's initiator name without updating the ACL; see the authorisation failure; fix it.
4. Log out and delete the node record.

**Check your work:** on your lab VM, from the notes folder, run `sudo ./checks/check 083` for every step, or `sudo ./checks/check 083 STEP` for one (topic 002 shows how to get the notes there).

## Where you'll use it

- **Enterprise storage arrays** (NetApp, Pure, Dell) present LUNs over iSCSI or Fibre Channel to database and virtualisation hosts.
- **Virtualisation:** hypervisor clusters keep VM disks on shared LUNs.
- **Kubernetes:** iSCSI is a supported volume type, and many storage CSI drivers attach iSCSI LUNs to nodes behind the scenes, so the node runs `iscsiadm` for you. A stuck "volume attach" may be an iSCSI login problem on the node.
- **Production practice:** a dedicated storage network/VLAN, per-initiator ACLs plus CHAP, jumbo frames where supported, and **multipath** for redundancy (next topic).

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `Could not log into all portals … authorization failure` | The initiator IQN isn't in the ACL, or it was changed without restarting iscsid | Fix the ACL or initiatorname; `systemctl restart iscsid` |
| Discovery: `No route to host` / timeout | Firewall or network | `iscsi-target` firewall service; ping the portal |
| The LUN is read-only | The target is in "demo mode" with write-protect | Use real ACLs, or `set attribute demo_mode_write_protect=0` |
| The configuration is gone after the target reboots | `target.service` not enabled, or not saved | `systemctl enable target`; `saveconfig` |
| The boot hangs mounting the iSCSI filesystem | Missing `_netdev` | Add `_netdev,nofail` |
| `Could not create NetworkPortal in configFS` | The default `0.0.0.0` portal already holds the port | Delete the 0.0.0.0 portal before adding specific IPs |
| XFS corruption on a shared LUN | Two hosts mounted it at once | Never do that without a cluster filesystem |

## Quick recap

- iSCSI = SCSI disk commands over TCP 3260. **Target** (server, `targetcli`/LIO) exports **LUNs**; **initiator** (client, `iscsiadm`) logs in and gets `/dev/sdX`.
- Target: backstore → `/iscsi create IQN` → `luns create` → `acls create INITIATOR-IQN` → `saveconfig`; enable `target`; firewall `iscsi-target`.
- Initiator: `/etc/iscsi/initiatorname.iscsi` → discovery → `-m node … -l` → enable `iscsi` → mkfs → fstab with **`_netdev`**.
- Block storage = **one** writer per normal filesystem.

**Interview questions**

1. *Target vs initiator?* The target is the storage server that exports LUNs; the initiator is the client that logs in and uses them as local block devices.
2. *iSCSI vs NFS?* NFS shares files (the server owns the filesystem, and many clients can share it). iSCSI shares raw block devices (the client puts its own filesystem on them, and normally only one client mounts it).
3. *Why does an iSCSI filesystem need `_netdev` in fstab?* The disk only exists after the network is up and the iSCSI login has completed; `_netdev` tells systemd to mount it after the network.

**Scenario question** (answer out loud first, then compare)

> *"An iSCSI LUN mounted on a server works fine, but after every reboot the server hangs at boot or the mount is missing. What's wrong?"*

**Model answer:**
1. The fstab entry is probably missing **`_netdev`**. systemd tries to mount it as a local disk before the network and the iSCSI login exist, and the boot waits or drops into emergency mode.
2. Fix the line: `UUID=…  /data  xfs  _netdev,nofail  0 0`, and mount by **UUID**, not `/dev/sdb` (iSCSI disk names change).
3. Check the initiator's services are enabled: `iscsi` (logs in to saved nodes at boot) and `iscsid`.
4. Check the node record is set to log in automatically: `iscsiadm -m node -T IQN -o show | grep startup` should show `automatic`.
5. Test with `systemctl daemon-reload`, `mount -a` and a reboot.

**Likely follow-ups:**
- *What do the target's ACLs check?* The initiator's IQN (from `/etc/iscsi/initiatorname.iscsi`). Change it, and the login fails with an authorisation error.
- *Can two servers mount the same iSCSI XFS filesystem?* Not safely. It needs a cluster filesystem (GFS2), or the filesystem gets corrupted.
