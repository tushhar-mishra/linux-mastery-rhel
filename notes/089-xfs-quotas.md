# 089 · XFS Disk Quotas: User, Group and Project Limits

> **You need first:** [088 · LUKS encryption](088-luks-encryption.md)
> **Next:** [090 · VDO](090-vdo.md)

---

## What it is

**Quotas** limit how much a **user**, a **group**, or a **project** (a directory tree) may store on a filesystem: both **space** (blocks) and **number of files** (inodes, topic 008).

| Term | Meaning |
|---|---|
| **Soft limit** | May be exceeded for a **grace period** (default 7 days), then it's enforced like a hard limit |
| **Hard limit** | The absolute maximum: writes fail with "Disk quota exceeded" |
| Block limits (`bsoft`, `bhard`) | Space |
| Inode limits (`isoft`, `ihard`) | Number of files and directories |
| **User quota** | Counts files **owned** by the user |
| **Group quota** | Counts files whose **group owner** is the group (not the user's other memberships) |
| **Project quota** | Counts everything under a tagged directory tree, whoever owns it |

XFS has quotas built in. You enable them with **mount options** and manage them with **`xfs_quota`**. (ext4 uses the separate `quota` tools: shown at the end.)

## Why it exists

On a shared filesystem, one user or one runaway application can fill the disk for everyone, and a full disk breaks other services (topic 006). Quotas guarantee fair shares: per-user home limits, per-tenant or per-application directory limits, and caps on millions of tiny files (inode exhaustion).

## Analogy

A shared **office storage room** where each person gets a **taped-off area** (user quota), each department a bigger area (group quota), and each project a set of labelled shelves (project quota). You may briefly spill over your line (soft limit) while you tidy up, but the hard line is a wall.

## How it works inside

- XFS keeps **usage counters** per user, group and project in hidden quota metadata, updated on every allocation, so checks are instant (no scanning).
- Each write that allocates blocks or inodes is checked against the owner's (and group's, and project's) limits. Exceeding a hard limit, or a soft limit past its grace period, returns `EDQUOT` ("Disk quota exceeded").
- **Accounting** (tracking usage) and **enforcement** (blocking) are separate. The `*noenforce` mount options track usage without blocking, which is handy for measuring before you enforce.
- **Quota options must be present at mount time.** XFS can't turn them on with `-o remount`: you must unmount and mount. For the **root** filesystem, they go on the kernel command line as `rootflags=uquota,pquota` (topic 054).
- **Project quotas** tag every inode under a directory with a project ID; new files inside inherit the tag.

| Mount option | Effect |
|---|---|
| `uquota` (`usrquota`) | User quotas: accounting + enforcement |
| `gquota` (`grpquota`) | Group quotas |
| `pquota` (`prjquota`) | Project quotas |
| `uqnoenforce`, `gqnoenforce`, `pqnoenforce` | Accounting only |

## Commands

### Enable

```bash
sudo mkfs.xfs /dev/vdb1
sudo mkdir -p /shared
echo "UUID=$(sudo blkid -s UUID -o value /dev/vdb1) /shared xfs defaults,uquota,gquota,pquota 0 0" | sudo tee -a /etc/fstab
sudo systemctl daemon-reload && sudo mount -a
sudo xfs_quota -x -c 'state' /shared
```
```
User quota state on /shared (/dev/vdb1)
  Accounting: ON
  Enforcement: ON
  Inode: #131 (1 blocks, 1 extents)
Blocks grace time: [7 days]
Inodes grace time: [7 days]
...
```
- `xfs_quota -x` = expert (admin) mode; `-c` runs one command (or run `xfs_quota -x /shared` for an interactive prompt).

### Set limits

```bash
sudo xfs_quota -x -c 'limit bsoft=1g bhard=1500m alice' /shared
sudo xfs_quota -x -c 'limit isoft=1000 ihard=1200 alice' /shared
sudo xfs_quota -x -c 'limit -g bsoft=5g bhard=6g devs' /shared
sudo xfs_quota -x -c 'limit bsoft=0 bhard=0 alice' /shared        # 0 = remove the limit
```

### Reports

```bash
sudo xfs_quota -x -c 'report -h' /shared
```
```
User quota on /shared (/dev/vdb1)
                        Blocks
User ID      Used   Soft   Hard Warn/Grace
---------- ---------------------------------
root            0      0      0  00 [------]
alice        1.1G     1G   1.5G  00 [6 days]
bob        120.0M      0      0  00 [------]
```
- alice is **over her soft limit** and has 6 days of grace left to clean up; after that, she can't write until she does. bob has no limit. Right after someone first crosses the soft limit, the column may still show `[------]`; the countdown appears once XFS rechecks them at their next write.

```bash
sudo xfs_quota -x -c 'report -ugph' /shared     # users, groups and projects
xfs_quota -c 'quota -h alice' /shared           # one user (works for normal users, on themselves)
sudo xfs_quota -x -c 'timer -u -b 10days' /shared    # change the user block grace period
```

### Project quotas (limit a directory tree)

```bash
sudo mkdir -p /shared/webapp
echo 'webapp:11' | sudo tee -a /etc/projid               # name:id
echo '11:/shared/webapp' | sudo tee -a /etc/projects     # id:directory
sudo xfs_quota -x -c 'project -s webapp' /shared          # tag the existing tree
sudo xfs_quota -x -c 'limit -p bsoft=200m bhard=300m webapp' /shared
sudo xfs_quota -x -c 'report -pbih' /shared
```
- Now **anything** under `/shared/webapp`, whoever writes it (root included), counts towards 300 MiB. `df /shared/webapp` reports the project's **soft** limit as the size (here 200M), or the hard limit if no soft limit is set.
- When a project hits its hard limit, writes fail with **`No space left on device`**, not "Disk quota exceeded" (on XFS, a project behaves like a small separate disk). Check `report -p` before blaming the disk.

### Turning enforcement on and off

| Command | Effect |
|---|---|
| `disable -ugp` | Stop **enforcing** (accounting continues) |
| `enable -ugp` | Resume enforcing |
| `off -ugp` | Stop accounting **and** enforcing; can't be re-enabled until remount |

### Test it

```bash
sudo chmod 1777 /shared                                     # lab: everyone may write (sticky bit)
su - alice -c 'dd if=/dev/zero of=/shared/big bs=1M count=1600'
```
```
dd: error writing '/shared/big': Disk quota exceeded
1501+0 records in
1500+0 records out
```

### ext4 comparison

```bash
# mount with usrquota,grpquota, then:
sudo quotacheck -cug /data ; sudo quotaon /data
sudo setquota -u alice 1000000 1500000 0 0 /data      # soft/hard blocks (KiB), soft/hard inodes
sudo repquota -a
```

### Try it
1. Make an XFS filesystem with all three quota types; set a 100 MiB soft / 150 MiB hard limit for a test user; fill it and see the soft-then-hard behaviour.
2. Set an inode hard limit of 15 and `touch f{1..20}`.
3. Create a project quota for a directory and confirm `df -h /shared/webapp` shows the project size.

## Where you'll use it

- **Shared servers** (universities, hosting, build servers): per-user home and scratch limits.
- **Per-application or per-tenant directories** on one big filesystem (project quotas).
- **Containers:** Podman/Docker's overlay storage on XFS can use **project quotas** to cap each container's writable layer (`--storage-opt size=10G` requires an XFS backing filesystem mounted with `pquota`).
- **Kubernetes:** kubelet can use project quotas (the LocalStorageCapacityIsolationFSQuotaMonitoring feature) to track `emptyDir` usage more efficiently than scanning.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| Limits are set but not enforced | Mounted without quota options, or enforcement disabled | `findmnt -no OPTIONS /shared`; remount with the options; `state` |
| `mount -o remount,uquota` does nothing | XFS can't enable quotas on remount | Unmount, then mount |
| Root filesystem quotas don't work | They need `rootflags=` | Add the kernel argument (topic 054) and reboot |
| A group quota doesn't apply | Files are owned by the user's primary group, not the quota group | SGID directory (topic 027) or change the file's group |
| Used `off`, now `enable` fails | Accounting is off | Remount |
| A user is blocked but `df` shows plenty of free space | They hit their quota, not the disk limit | `xfs_quota -c 'quota -h USER'` |

## Quick recap

- Quotas cap space (blocks) and files (inodes) per **user**, **group** (group owner) or **project** (directory tree). Soft = allowed over during grace; hard = never.
- XFS: mount options `uquota,gquota,pquota` in fstab → **unmount + mount** (no remount) → `xfs_quota -x -c 'state'`.
- `limit [-u|-g|-p] bsoft= bhard= isoft= ihard= NAME`, `report -ugph`, `quota -h USER`, `timer`.
- Projects: `/etc/projid` + `/etc/projects` + `project -s NAME`. ext4 uses `quotacheck`/`quotaon`/`setquota`/`repquota`.

**Interview questions**

1. *Soft vs hard quota?* A soft limit may be exceeded for a grace period (7 days by default), after which it's enforced; a hard limit can never be exceeded.
2. *What is a project quota?* A limit on a whole directory tree (tagged with a project ID), counting all files inside regardless of who owns them.
3. *Why don't XFS quotas work after `mount -o remount,uquota`?* XFS only enables quota accounting at mount time, so you must unmount and mount again (or use `rootflags=` for the root filesystem).
