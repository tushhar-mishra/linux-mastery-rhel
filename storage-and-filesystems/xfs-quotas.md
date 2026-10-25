# XFS Disk Quotas (User, Group & Project)

> **Sessions:** S44 · **[Advanced/Optional]** · multi-user servers, shared storage, hosting
> **Related:** [Filesystems & mkfs](filesystems-and-mkfs.md) · [Mounting & fstab](mounting-and-fstab.md) · [Local users](../users-groups-and-permissions/local-users.md) · [Groups](../users-groups-and-permissions/groups.md)

## 1. Overview

Quotas cap how much **space (blocks)** and how many **files (inodes)** a user, group or project (directory tree) may consume on a filesystem. XFS implements quotas natively; they are enabled with **mount options** and managed with **`xfs_quota`**.

## 2. Key Concepts

| Term | Meaning |
|---|---|
| **Soft limit** | Can be exceeded for the **grace period** (default 7 days); then it's enforced like a hard limit |
| **Hard limit** | Absolute maximum; writes fail with "Disk quota exceeded" |
| Block limit (`bsoft`/`bhard`) | Space |
| Inode limit (`isoft`/`ihard`) | Number of files and directories |
| User quota | Files **owned** by the user |
| Group quota | Files whose **group owner** is the group (not supplementary membership) |
| Project quota | All files under a directory tree tagged with a project ID |

### Mount options

| Option | Effect |
|---|---|
| `uquota` / `usrquota` | User quotas: accounting + enforcement |
| `gquota` / `grpquota` | Group quotas |
| `pquota` / `prjquota` | Project quotas |
| `uqnoenforce`, `gqnoenforce`, `pqnoenforce` | Accounting only (report usage, don't enforce) |

> ⚠️ XFS quota options **can't be enabled with `-o remount`**. Unmount and mount again. For the **root** filesystem, add `rootflags=uquota,…` to the kernel command line (`grubby --update-kernel=ALL --args=…`) and reboot **[Advanced]**.

## 3. Setup

```bash
mkfs.xfs /dev/vdb1
mkdir -p /xfsquota
echo "UUID=$(blkid -s UUID -o value /dev/vdb1) /xfsquota xfs defaults,uquota,gquota,pquota 0 0" >> /etc/fstab
systemctl daemon-reload ; mount -a
findmnt -no OPTIONS /xfsquota            # …usrquota,prjquota,grpquota
xfs_quota -x -c 'state' /xfsquota        # accounting/enforcement status per type
```

## 4. Managing Limits with `xfs_quota`

`xfs_quota -x -c '<command>' <mountpoint>`, where `-x` = expert (admin) mode and `-c` = run a command (or run `xfs_quota -x` alone for an interactive prompt).

```bash
# User block + inode limits
xfs_quota -x -c 'limit bsoft=1g bhard=1536m deepak' /xfsquota
xfs_quota -x -c 'limit isoft=10 ihard=15 deepak' /xfsquota
# Group limits (-g); user limits can be explicit with -u
xfs_quota -x -c 'limit -g bsoft=600m bhard=900m admin' /xfsquota
# Reports
xfs_quota -x -c 'report -h' /xfsquota          # users (human-readable)
xfs_quota -x -c 'report -ugph' /xfsquota       # users, groups, projects
xfs_quota -c 'quota -h deepak' /xfsquota       # one user's usage (non-expert)
# Remove a limit: set it to 0
xfs_quota -x -c 'limit bsoft=0 bhard=0 deepak' /xfsquota
```

### Grace periods

```bash
xfs_quota -x -c 'timer -u -b 10days' /xfsquota   # user block grace period
xfs_quota -x -c 'timer -p -i 3days'  /xfsquota   # project inode grace period
```

### Project quotas (directory trees)

```bash
mkdir -p /xfsquota/webapp
echo 'webapp:11' >> /etc/projid                  # name:id
echo '11:/xfsquota/webapp' >> /etc/projects      # id:directory
xfs_quota -x -c 'project -s webapp' /xfsquota    # tag the directory tree
xfs_quota -x -c 'limit -p bsoft=200m bhard=300m webapp' /xfsquota
xfs_quota -x -c 'report -pbih' /xfsquota
```

### Enabling, disabling, turning off

| Command | Effect |
|---|---|
| `disable -ugp` | Stop **enforcement** (accounting continues) |
| `enable -ugp` | Resume enforcement |
| `off -ugp` | Stop accounting **and** enforcement; can't be re-enabled until remount |

## 5. Testing

```bash
chmod 1777 /xfsquota                              # lab only: everyone can write, sticky bit
su - deepak -c 'fallocate -l 1.2G /xfsquota/t1'   # over soft → allowed (grace starts)
su - deepak -c 'dd if=/dev/zero of=/xfsquota/t2 bs=1M count=700'   # hits hard → "Disk quota exceeded"
su - deepak -c 'cd /xfsquota && touch f{1..20}'   # inode hard limit 15 → failures after 15
```

## 6. ext4 Quotas (comparison) **[Advanced]**

ext4 uses the `quota` package: mount with `usrquota,grpquota`, then `quotacheck -cug MNT`, `quotaon MNT`, `edquota -u user` / `setquota`, `repquota -a`.

## 7. Production Practices **[Production Practice]**

- Use project quotas for per-application or per-tenant directories on shared filesystems.
- Start with `*noenforce` to measure usage before enforcing.
- Monitor with `report -h`; alert on users in grace.
- Remember group quotas follow the **group owner** of files; combine with SGID directories so new files get the right group.

## 8. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Limits set but not enforced | Mounted without quota options, or `disable`d | `findmnt -no OPTIONS`; remount with options; `state` |
| `-o remount,uquota` does nothing | XFS limitation | `umount` + `mount` |
| Root FS quotas not active | Needs `rootflags=` | Kernel argument + reboot |
| Group quota not applied | Files owned by the user's primary group, not the quota group | SGID directory or `usermod -g` |
| `off` used; can't `enable` | Accounting off | Remount |

## 9. Interview Questions

| Question | Answer |
|---|---|
| Soft vs hard limit? | Soft can be exceeded during the grace period; hard never. |
| What's a project quota? | A limit on a directory tree regardless of file owner. |
| How do you enable XFS quotas? | Mount options (`uquota`, `gquota`, `pquota`) in fstab, then unmount/mount. |
| `disable` vs `off`? | `disable` stops enforcement; `off` stops accounting too and requires a remount to re-enable. |

## 10. Quick Revision

```bash
fstab: defaults,uquota,gquota,pquota → umount/mount (not remount) → xfs_quota -x -c 'state' MNT
limit [-u|-g|-p] bsoft= bhard= isoft= ihard= NAME | report -ugph | quota -h USER | timer -u -b 7days
/etc/projid name:id · /etc/projects id:/dir · project -s NAME
disable/enable (enforcement) · off (needs remount)
```

## 11. Cross-References

- [Filesystems & mkfs](filesystems-and-mkfs.md) · [Mounting & fstab](mounting-and-fstab.md)
- [Local users](../users-groups-and-permissions/local-users.md) · [Groups](../users-groups-and-permissions/groups.md) · [Special permissions (SGID)](../users-groups-and-permissions/special-permissions-and-acls.md)
