# 084 · DM-Multipath: Redundant Paths to Storage

> **You need first:** [083 · iSCSI](083-iscsi.md)
> **Next:** [085 · LVM thin provisioning and striping](085-lvm-thin-and-striping.md)

---

## What it is

In real data centres, a server reaches each storage LUN over **several paths**: two NICs (or two HBAs, Host Bus Adapters: Fibre Channel cards), through two switches, to two storage controllers. Linux then sees **one disk per path**: the same LUN appears as `/dev/sdb` **and** `/dev/sdc`.

**DM-Multipath** (Device-Mapper Multipath) recognises that those disks are the **same LUN** and builds **one** device, `/dev/mapper/mpatha`, which:
- **fails over** to a surviving path when one dies, with no errors for applications;
- can **load-balance** I/O across the active paths.

| Component | Role |
|---|---|
| `dm-multipath` kernel module | The device-mapper target that switches between paths |
| `multipathd` | The daemon: watches path health, fails over, reinstates recovered paths |
| `multipath` | The command to create, list and flush maps |
| `/etc/multipath.conf` | Configuration (defaults, blacklist, aliases) |
| `/etc/multipath/wwids`, `bindings` | Known LUN IDs; `mpathX` name ↔ WWID mapping |

## Why it exists

Storage is critical: if a single cable, switch port, NIC or controller fails and the disk disappears, databases crash and filesystems may be damaged. Multipath removes those single points of failure on the storage path, just as bonding (topic 062) does for normal network links.

## Analogy

The LUN is a **warehouse** with **two roads** leading to it. Without multipath, your GPS thinks they're **two different warehouses** (`sdb`, `sdc`), and if your chosen road is closed, the delivery fails. Multipath is a **smarter GPS**: it knows both roads lead to the same warehouse (the same **WWID**), uses either, and reroutes instantly when one is closed.

## How it works inside

1. Every LUN has a globally unique ID, the **WWID** (World Wide IDentifier), read from the device by udev (`scsi_id`).
2. `multipathd` groups all path devices with the same WWID and creates one **device-mapper** device (like LVM, topic 049) whose table lists the paths and a **path selector** policy (`service-time`, `round-robin`, `queue-length`) for choosing among them.
3. Paths are arranged in **priority groups**. Active/passive arrays keep standby paths in a lower-priority group; active/active arrays use all paths.
4. `multipathd` checks each path regularly. A failed path is marked **faulty**, and I/O moves to the others. When it recovers, it's **reinstated**.
5. If **all** paths fail, I/O is either **queued** (`no_path_retry queue`: applications hang until a path returns, which is safest for data) or failed after N retries.

**Use only `/dev/mapper/mpathX`** (or LVM on top of it). Using `/dev/sdb` directly bypasses multipath: if that path dies, I/O fails. LVM's devices file (topic 049) should list the mpath device, not the paths; otherwise you get "duplicate PV" warnings.

## Commands

### Lab topology: two independent paths

| Host | Path 1 | Path 2 |
|---|---|---|
| Target (server2) | 192.168.1.250/24 | **192.168.2.250/24** |
| Initiator (server1) | 192.168.1.252/24 | **192.168.2.252/24** |

Each path needs its **own subnet** (separate host-only networks). With two NICs in one subnet, the kernel may route both "paths" through one NIC (topic 061).
```bash
sudo nmcli con add type ethernet con-name path1 ifname enp0s9  ip4 192.168.1.252/24 ; sudo nmcli con up path1
sudo nmcli con add type ethernet con-name path2 ifname enp0s10 ip4 192.168.2.252/24 ; sudo nmcli con up path2
```

### Target: expose the LUN on both portals

```
targetcli
/> /backstores/fileio create lun1 /iscsi_disks/lun1.img 5G
/> /iscsi create iqn.2026-11.lan.example:storage.t1
/> cd /iscsi/iqn.2026-11.lan.example:storage.t1/tpg1
…/tpg1> luns create /backstores/fileio/lun1
…/tpg1> acls create iqn.1994-05.com.redhat:server1
…/tpg1> portals/ delete 0.0.0.0 3260
…/tpg1> portals/ create 192.168.1.250 3260
…/tpg1> portals/ create 192.168.2.250 3260
…/tpg1> cd / ; saveconfig ; exit
```

### Initiator: log in on both paths and enable multipath

```bash
sudo dnf install -y iscsi-initiator-utils device-mapper-multipath     # Ubuntu: multipath-tools
sudo iscsiadm -m discovery -t sendtargets -p 192.168.1.250
sudo iscsiadm -m node --login
lsblk -o NAME,SIZE,TYPE
sudo /usr/lib/udev/scsi_id -g -u /dev/sdb ; sudo /usr/lib/udev/scsi_id -g -u /dev/sdc
```
```
192.168.1.250:3260,1 iqn.2026-11.lan.example:storage.t1
192.168.2.250:3260,1 iqn.2026-11.lan.example:storage.t1
NAME SIZE TYPE
sdb    5G disk
sdc    5G disk
360014052e3a1d2b7c4d4e9f0a1b2c3d4
360014052e3a1d2b7c4d4e9f0a1b2c3d4
```
- Two disks, **identical WWIDs**: the same LUN over two paths.

```bash
sudo mpathconf --enable --with_multipathd y
sudo multipath -ll
```
```
mpatha (360014052e3a1d2b7c4d4e9f0a1b2c3d4) dm-3 LIO-ORG,lun1
size=5.0G features='1 queue_if_no_path' hwhandler='1 alua' wp=rw
`-+- policy='service-time 0' prio=50 status=active
  |- 3:0:0:0 sdb 8:16 active ready running
  `- 4:0:0:0 sdc 8:32 active ready running
```
- One device, `mpatha` (= `/dev/mapper/mpatha`), with its WWID, vendor `LIO-ORG`, size, and write permission (`wp=rw`).
- One **path group** holding both paths, each `active ready running`: the target reports both as equally good (ALUA "active/optimized", same `prio=50`), so I/O uses both. Arrays with a standby controller show a second, lower-priority group instead. `policy='service-time'` = send each I/O to the path with the shortest expected service time.
- `features='1 queue_if_no_path'`: if every path fails, I/O waits instead of failing. The built-in settings for this array type turn it on.

### Configuration

```
# /etc/multipath.conf
defaults {
    user_friendly_names yes        # mpatha, mpathb… instead of WWIDs
    find_multipaths on             # only build maps for devices with more than one path (or known WWIDs)
}

blacklist {
    wwid "36000c29f0123456789abcdef01234567"      # the local system disk: blacklist by WWID, not "sda"
}

multipaths {
    multipath {
        wwid  "360014052e3a1d2b7c4d4e9f0a1b2c3d4"
        alias "san_data"                          # → /dev/mapper/san_data
    }
}
```
```bash
sudo systemctl reload multipathd ; sudo multipath -ll
sudo multipathd show config | less      # the effective config, including built-in vendor defaults
```
- Built-in defaults already cover common arrays. Add a `devices {}` override only when the storage vendor documents one.

### Use it

```bash
sudo pvcreate /dev/mapper/san_data
sudo vgcreate vg_san /dev/mapper/san_data
sudo lvcreate -n data -l 100%FREE vg_san
sudo mkfs.xfs /dev/vg_san/data ; sudo mkdir -p /san
echo '/dev/vg_san/data /san xfs _netdev,nofail 0 0' | sudo tee -a /etc/fstab
sudo systemctl daemon-reload && sudo mount -a
```

### Failover test

```bash
sudo multipathd show paths
sudo nmcli con down path2
sudo multipath -ll | grep -E 'sd[bc]'
sudo dd if=/dev/zero of=/san/test bs=1M count=100 oflag=direct     # still works
sudo nmcli con up path2 ; sleep 10 ; sudo multipath -ll | grep -E 'sd[bc]'
```
```
  `- 3:0:0:0 sdb 8:16 active ready running
  `- 4:0:0:0 sdc 8:32 active faulty offline
...
  `- 4:0:0:0 sdc 8:32 active ready running
```

| Command | Purpose |
|---|---|
| `multipath -ll` | Maps and path states |
| `multipath -r` | Reload maps |
| `multipath -f mpatha` / `-F` | Remove one / all **unused** maps |
| `multipathd show paths` / `show maps` / `show config` | Live daemon views |
| `mpathconf --enable` / `--disable` | Basic setup on/off |

### Try it
1. Build the two-subnet lab and see two disks with the same WWID.
2. Enable multipath and put LVM + XFS on `/dev/mapper/mpatha`.
3. Run a `dd` loop while you take a path down and bring it back. No errors should appear.
4. Give the LUN a friendly alias.

**Check your work:** on your lab VM, from the notes folder, run `sudo ./checks/check 084` for every step, or `sudo ./checks/check 084 STEP` for one (topic 002 shows how to get the notes there).

## Where you'll use it

- **Every SAN-attached server** (Fibre Channel or iSCSI) in enterprise data centres: databases, hypervisors, SAP.
- **Kubernetes nodes** with iSCSI/FC CSI drivers often require multipathd configured on the node; misconfigured multipath is a classic cause of volumes failing to attach or attaching to the wrong device.
- **Cloud:** you rarely configure it yourself; the provider handles path redundancy.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| Only `sdb`/`sdc`, no mpath device | multipathd not running, `find_multipaths`, or blacklisted | `mpathconf --enable --with_multipathd y`; `multipath -v3` for details |
| Both paths fail at once | The paths share a NIC, subnet or switch | Separate subnets and hardware |
| The LUN is read-only (`wp=ro`) | The target is in demo mode with write-protect | Use ACLs, or `demo_mode_write_protect=0` |
| The local system disk got multipathed | Not blacklisted | Blacklist it by WWID; `dracut -f` if the boot disk is involved |
| LVM "duplicate PV" warnings | LVM sees the individual path devices | Use the devices file with `/dev/mapper/mpathX` only |
| Applications hang when all paths are down | `no_path_retry queue` | Expected (protects data); restore a path |

## Quick recap

- Several paths to one LUN show up as several `sdX` disks with the **same WWID**. Multipath combines them into `/dev/mapper/mpathX` with failover and load balancing.
- `dnf install device-mapper-multipath`, `mpathconf --enable --with_multipathd y`, `multipath -ll`, `multipathd show paths`.
- `/etc/multipath.conf`: `user_friendly_names`, `find_multipaths`, blacklist by WWID, aliases.
- Always use the mpath device (LVM on top), `_netdev` in fstab, and truly separate paths.

**Interview questions**

1. *What problem does multipath solve?* Redundant (and optionally load-balanced) access to one storage LUN over several physical paths, with transparent failover when a path fails.
2. *How does multipath know two disks are the same LUN?* They report the same SCSI WWID.
3. *Why must you not use `/dev/sdb` directly on a multipathed system?* It's a single path; if that path fails, I/O fails. The `/dev/mapper/mpathX` device survives path failures.

**Scenario question** (answer out loud first, then compare)

> *"A SAN-attached server shows the same 1 TB LUN as `/dev/sdb`, `/dev/sdc`, `/dev/sdd` and `/dev/sde`. Someone created LVM on `/dev/sdb`. What's the risk, and how do you fix it?"*

**Model answer:**
1. Four disks with the same WWID are **four paths** to one LUN. Using `/dev/sdb` directly means:
   - all I/O depends on one path, and if it fails, the filesystem fails;
   - LVM may see "duplicate PVs" on the other paths and pick inconsistently.
2. Fix:
   - install and enable multipath (`mpathconf --enable --with_multipathd y`);
   - check `multipath -ll` shows one `mpathX` device with 4 paths;
   - make LVM use only the mpath device: on RHEL 9/10, `lvmdevices` should list `/dev/mapper/mpathX`, not the `sdX` paths.
3. Plan this in a maintenance window: deactivate the VG, enable multipath, reactivate on the mpath device, and update fstab (`_netdev`).
4. Test by taking one path down during I/O: no errors should reach the application.

**Likely follow-ups:**
- *How does multipath know paths belong together?* They report the same WWID.
- *What's `find_multipaths` for?* It stops multipath grabbing ordinary single-path local disks.
