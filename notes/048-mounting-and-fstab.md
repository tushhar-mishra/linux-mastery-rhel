# 048 · Mounting, Mount Options and /etc/fstab

> **You need first:** [047 · Filesystems](047-filesystems.md)
> **Next:** [049 · LVM](049-lvm.md)

---

## What it is

- **Mounting** attaches a filesystem to a directory (the **mount point**) inside the single tree (topic 006). After `mount /dev/vdb1 /data`, the files on `vdb1` appear under `/data`.
- **Unmounting** (`umount`; note the missing "n") detaches it again.
- **Mount options** change how the filesystem behaves while mounted: read-only, no programs allowed, and so on.
- **`/etc/fstab`** ("filesystem table") lists what to mount **at every boot**. Mounts made by hand with `mount` are **forgotten at reboot**.

## Why it exists

A formatted partition does nothing until it's reachable through a path. Mounting is how Linux keeps **one tree** while data lives on many disks, partitions, volumes and network shares. fstab makes that layout permanent, and mount options add safety (for example, stopping programs from running out of `/tmp`).

## Analogy

The directory tree is a **building**; a filesystem is a **storage container** sitting outside. Mounting is **connecting the container to a door** in the building (the mount point), so people walk through `/data` and are inside the container. Whatever was behind that door before is **hidden** (not deleted) until the container is disconnected. fstab is the **site plan** that says which container connects to which door every morning.

## How it works inside

1. `mount` calls the kernel (the `mount` system call) with: the device, the directory, the filesystem type and the options.
2. The kernel's filesystem driver reads the **superblock**, checks it, and replays the **journal** if the last shutdown wasn't clean (topic 047).
3. The kernel's VFS records "at directory `/data`, continue inside this filesystem" in the process's **mount namespace** (the list of mounts a process can see; containers get their own, topic 097).
4. From now on, any path through `/data` is handled by that filesystem.

**At boot on systemd systems:** a generator converts each fstab line into a **`.mount` unit** (for example `data.mount`). systemd mounts them in the right order: parents before children, network mounts after the network. That's why, **after editing fstab, you run `systemctl daemon-reload`**, which regenerates those units.

**If a mount listed in fstab fails at boot** (a typo, a missing disk) and it isn't marked `nofail`, systemd stops in **emergency mode** (topic 037). A single bad fstab line can stop a server from booting. Always test before rebooting.

**Mounting over a non-empty directory** hides its contents. The old files still take disk space on the parent filesystem but can't be seen. That's a classic cause of "`df` says full, `du` can't find it".

## Commands

### Mount and unmount by hand

```bash
sudo mkdir -p /data
sudo mount /dev/vdb1 /data             # type detected automatically
sudo mount UUID=5f1c2e7a-0d4b-4b8e-9a63-2a8c1e4d9f10 /data
sudo mount LABEL=DATA /data
sudo mount -t ext4 -o ro /dev/vdb2 /mnt
sudo mount -o remount,ro /data         # change options while mounted
sudo umount /data                      # by mount point (clearest)
```

### See what's mounted

```bash
findmnt /data
```
```
TARGET SOURCE    FSTYPE OPTIONS
/data  /dev/vdb1 xfs    rw,relatime,seclabel,attr2,inode64,logbufs=8,logbsize=32k,noquota
```
- `seclabel` = the filesystem supports SELinux labels (topic 072). The rest are XFS defaults.

```bash
findmnt                     # the whole mount tree
findmnt -T /data/x.txt      # which mount holds this path
df -hT                      # usage and type per mount (topic 006)
cat /proc/self/mounts       # the kernel's raw list (/etc/mtab links here)
```

### Mount options

| Option | Effect |
|---|---|
| `defaults` | `rw,suid,dev,exec,auto,nouser,async` |
| `ro` / `rw` | Read-only / read-write |
| `noexec` | Programs on this filesystem can't be **run directly** (`bash /mnt/x.sh` still works, since bash itself lives elsewhere) |
| `nosuid` | SUID/SGID bits are ignored (topic 027) |
| `nodev` | Device files on it are ignored |
| `noatime` / `relatime` | Never record read times / only occasionally (RHEL default). Saves disk writes |
| `nofail` | A missing device doesn't stop the boot |
| `_netdev` | It needs the network: mount after the network is up (iSCSI, NFS) |
| `x-systemd.automount` | Mount on first access instead of at boot |
| `x-systemd.device-timeout=10s` | Wait at most 10 s for the device at boot |
| `uid=`, `gid=`, `umask=` | **VFAT only**: one owner and permission set for all files (VFAT has none of its own) |
| `context="…"` | Give every file one SELinux label (for VFAT, NFS; topic 073) |

Security baseline: mount `/tmp`, `/var/tmp`, `/dev/shm` and removable media with `nodev,nosuid,noexec`.

### /etc/fstab

```
# <device>                                 <mount point>  <type>  <options>                            <dump> <fsck>
UUID=5f1c2e7a-0d4b-4b8e-9a63-2a8c1e4d9f10   /data          xfs     defaults                             0      0
LABEL=LOGS                                  /logs          ext4    defaults,noatime                     0      2
UUID=3F2A-1B9C                              /usb           vfat    defaults,uid=1001,gid=1001,umask=022,nofail 0 0
/dev/mapper/vgdata-lvdb                     /db            xfs     defaults                             0      0
```

| Field | Meaning |
|---|---|
| 1 Device | `UUID=…` (**best**), `LABEL=…`, `/dev/mapper/vg-lv` (stable LVM names), or `server:/export` for NFS |
| 2 Mount point | Must already exist (`mkdir -p`); `none` for swap |
| 3 Type | `xfs`, `ext4`, `vfat`, `swap`, `nfs`, … |
| 4 Options | Comma-separated, **no spaces** |
| 5 Dump | `0` (an old backup flag) |
| 6 fsck order | `0` = don't check (**XFS, swap, network**); `1` = root if ext4; `2` = other ext4 |

### The safe recipe (every time)

```bash
sudo blkid /dev/vdb1                                 # copy the UUID= value (not PARTUUID)
sudo cp -a /etc/fstab /etc/fstab.bak.$(date +%F)     # backup
sudo mkdir -p /data
echo 'UUID=5f1c2e7a-0d4b-4b8e-9a63-2a8c1e4d9f10 /data xfs defaults 0 0' | sudo tee -a /etc/fstab
sudo systemctl daemon-reload                         # regenerate the mount units
sudo mount -a                                        # mount everything listed: errors show up NOW, not at boot
sudo findmnt --verify                                # check fstab for mistakes
findmnt /data
```
```
Success, no errors or warnings detected
TARGET SOURCE    FSTYPE OPTIONS
/data  /dev/vdb1 xfs    rw,relatime,seclabel,attr2,inode64,...
```
- If `mount -a` or `findmnt --verify` complains, fix it **before** rebooting.

### "Target is busy"

```bash
sudo umount /data
```
```
umount: /data: target is busy.
```
```bash
cd /                              # is YOUR shell sitting inside it?
sudo lsof +f -- /data             # which processes have files open there
sudo fuser -vm /data              # same, shorter
```
```
                     USER        PID ACCESS COMMAND
/data:               root     kernel mount /data
                     alice      4410 ..c.. bash
```
- alice's shell has `/data` as its current directory (`c`). Ask her to leave, or stop the process. `fuser -km` kills them all ⚠️. `umount -l` (lazy) detaches it now and finishes when it's no longer in use; use that sparingly.

### Making a filesystem writable for users

```bash
sudo chown alice:devs /data ; sudo chmod 2775 /data   # topic 026/027
```
- A freshly made filesystem's root directory belongs to root. Set its owner and permissions **after mounting** (on the mounted directory), not on the empty mount point underneath.

### Try it
1. Mount the XFS from topic 047 at `/data` by UUID and the ext4 one at `/logs` by LABEL, both in fstab. Run `daemon-reload`, `mount -a`, `findmnt --verify`, then reboot and check.
2. Put a file in the empty `/data` directory **before** mounting, then mount. Where did it go? Unmount and see it again.
3. Mount the VFAT one with `uid=` of a normal user and confirm that user can write to it.
4. Make an fstab typo on purpose, then run `findmnt --verify` and see it caught before rebooting.

## Where you'll use it

- **Every new disk or volume** ends with an fstab line.
- **Cloud servers:** attached volumes (EBS etc.) get fstab entries **by UUID with `nofail`**. Without `nofail`, an instance can fail to boot when a volume is detached.
- **Security hardening:** `noexec,nosuid,nodev` on `/tmp` and upload directories (CIS benchmarks).
- **Containers:** volumes and bind mounts are mounts into the container's mount namespace. `docker run -v /host:/ctr:ro` is `mount --bind` + `ro`. Kubernetes `readOnlyRootFilesystem` and `volumeMounts` work the same way.
- **"Device busy" during maintenance:** `lsof`/`fuser` before unmounting.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `mount: (hint) your fstab has been modified, but systemd still uses the old version` | You edited fstab | `systemctl daemon-reload` |
| `mount point does not exist` | Directory missing | `mkdir -p` |
| `wrong fs type, bad option, bad superblock` | Wrong type or option, no filesystem, or a typo | `blkid`; `findmnt --verify`; `dmesg` |
| `can't find UUID=…` | Typo, or you copied the PARTUUID | Copy the `UUID=` value from `blkid` |
| `target is busy` | Open files, or a shell inside it | `lsof`, `fuser -vm`; `cd` out |
| **Boot stops in emergency mode** | A bad fstab line or a missing device | From the console: `mount -o remount,rw /`, fix fstab, reboot. If root is locked, use the recovery method in topic 057. Prevent with `nofail` |
| Users can't write to a VFAT mount | VFAT has no Linux permissions | Use the `uid=`, `gid=`, `umask=` options |
| `noexec` "doesn't work" | The script was run through `bash script.sh` | Expected: noexec only blocks direct execution |
| Files "vanished" | Something is mounted on top of them | Unmount to see them, or `mount --bind / /mnt/root` and look underneath |

## Quick recap

- `mount DEV|UUID=|LABEL= DIR`, `umount DIR`, `findmnt`, `df -hT`. Mounting hides what was in the directory.
- fstab: `device  mountpoint  type  options  0  fsck` (0 for XFS/swap/network, 2 for ext4 data). Use UUIDs.
- After editing: `daemon-reload` → `mount -a` → `findmnt --verify` → only then reboot. Use `nofail` for non-essential disks.
- Options: `ro`, `noexec`, `nosuid`, `nodev`, `noatime`, `nofail`, `_netdev`, VFAT `uid/gid/umask`. Busy? `lsof`/`fuser`.

**Interview questions**

1. *What are the six fstab fields?* Device, mount point, filesystem type, options, dump flag, fsck order.
2. *Why mount by UUID instead of `/dev/sdb1`?* Kernel device names can change between boots; the UUID identifies the filesystem itself.
3. *How do you test an fstab change without rebooting?* `systemctl daemon-reload`, then `mount -a` (mounts every entry and shows errors) and `findmnt --verify`.
