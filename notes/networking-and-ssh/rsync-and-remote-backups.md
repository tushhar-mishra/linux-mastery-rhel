# rsync & Automated Remote Backups

> Supports *Securely transfer files between systems* **[RHCSA Core]** · backups **[Production Practice]**
> **Related:** [SSH remote access](ssh-remote-access.md) · [Job scheduling (cron, timers)](../logs-scheduling-and-packages/job-scheduling.md) · [Archiving & compression](../files-and-text-processing/archiving-and-compression.md) · [LVM snapshots](../storage-and-filesystems/lvm-snapshots-and-recovery.md)

## 1. Overview

`rsync` copies and synchronizes files locally or over SSH, transferring only the **differences**. That makes repeated copies fast, and interrupted transfers can be resumed. Combined with SSH keys and cron or a systemd timer, it makes a simple automated off-host copy.

````bash
dnf install -y rsync         # needed on BOTH ends for remote transfers
````

## 2. Syntax & the Trailing Slash

````
rsync [options] SOURCE… DESTINATION
remote: user@host:/path   (over SSH by default)
````

| Command | Result |
|---|---|
| `rsync -a src/ dest/` | Copies the **contents** of `src` into `dest` |
| `rsync -a src dest/` | Creates `dest/src/…` |
| `rsync -a src/* dest/` | Like the first, but the shell glob **skips hidden files** |

## 3. Key Options

| Option | Meaning |
|---|---|
| `-a` | Archive: recursive + preserve permissions, owner/group (as root), times, symlinks, devices |
| `-v` / `-h` | Verbose / human-readable sizes |
| `-z` | Compress during transfer |
| `-P` | `--partial --progress` (resume + progress) |
| `-n` / `--dry-run` | Show what **would** happen |
| `--delete` | Delete files in the destination that no longer exist in the source (**mirror**) ⚠️ |
| `--exclude='*.tmp'` / `--exclude-from=FILE` | Skip paths |
| `-e "ssh -p 2222 -i KEY"` | Custom SSH options |
| `-A -X -H` | Preserve ACLs, extended attributes (incl. SELinux), hard links |
| `--bwlimit=10M` | Limit bandwidth |
| `--link-dest=DIR` | Hard-link unchanged files to a previous backup (space-efficient snapshots) **[Advanced]** |

## 4. Examples

````bash
rsync -avh ~/backup/ /tmp/backup/                          # local
rsync -avhP /srv/data/ alice@backup01:/backups/web01/data/ # push to remote
rsync -avh alice@web01:/var/www/ /restore/www/             # pull from remote
rsync -avhn --delete /srv/data/ backup01:/backups/data/    # dry-run a mirror first
rsync -aAXH --delete /etc/ backup01:/backups/etc/          # keep ACLs/xattrs/hard links
````

## 5. Automated Backup over SSH

````bash
# On the source (as the account that runs the job)
ssh-keygen -t ed25519 -f ~/.ssh/backup_ed25519 -N ''        # dedicated automation key (no passphrase)
ssh-copy-id -i ~/.ssh/backup_ed25519.pub backup@192.168.229.130
ssh -i ~/.ssh/backup_ed25519 backup@192.168.229.130 true    # test: no password prompt
````

````bash
# /usr/local/bin/backup.sh
#!/bin/bash
set -euo pipefail
exec 9>/run/backup.lock ; flock -n 9 || exit 0             # don't overlap runs
/usr/bin/rsync -aH --delete -e "ssh -i /root/.ssh/backup_ed25519" \
    /backupsource/ backup@192.168.229.130:/backupdestination/ \
    >> /var/log/backup.log 2>&1
````

````bash
chmod 700 /usr/local/bin/backup.sh
crontab -e   →   30 1 * * * /usr/local/bin/backup.sh       # daily 01:30 (every minute only for testing)
tail -f /var/log/cron /var/log/backup.log
````

A systemd timer (`OnCalendar=*-*-* 01:30:00`, `Persistent=true`) is a good alternative (see [job scheduling](../logs-scheduling-and-packages/job-scheduling.md)).

## 6. Verify & Restore

````bash
ssh backup@192.168.229.130 'ls -l /backupdestination/'
rsync -avhn --checksum /backupsource/ backup@192.168.229.130:/backupdestination/   # anything differ?
rsync -avh backup@192.168.229.130:/backupdestination/ /restore/                     # test a restore
````

## 7. Production Practices **[Production Practice]**

- **rsync isn't a backup strategy on its own.** A mirror copies deletions and corruption too. Keep versions (`--link-dest` snapshots, backup software) and follow **3-2-1** (3 copies, 2 media, 1 off-site).
- Use a dedicated **backup user** rather than root-to-root SSH. Restrict the key in `authorized_keys` (`command="…",restrict` or the `rrsync` helper shipped with rsync).
- Get consistent copies of databases and busy filesystems from dumps or LVM snapshots.
- Monitor job results (exit codes, logs, alerts); **test restores** regularly.

## 8. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `rsync: command not found` (remote) | Not installed on the other end | `dnf install rsync` there |
| Asks for a password in cron | Key not used / not installed | `-e "ssh -i KEY"`; test manually as the same user |
| Files land in `dest/src/` | Trailing-slash semantics | `src/` vs `src` |
| Hidden files not copied | `src/*` glob | Use `src/` |
| Ownership not preserved | Not root on the receiver | Run the receiver as root, or accept |
| `--delete` removed files unexpectedly | Wrong source path / empty source | Always `-n` first; guard with checks in scripts |
| Jobs pile up | Previous run still running | `flock` |

## 9. Interview Questions

| Question | Answer |
|---|---|
| rsync vs scp? | rsync transfers only differences, can resume, preserves metadata and can mirror; scp copies whole files. |
| What does the trailing slash do? | `src/` copies the contents; `src` copies the directory itself. |
| Why is `--delete` dangerous? | It removes destination files missing from the source; mistakes propagate. |
| How do you schedule rsync securely? | Dedicated user and restricted key, cron/systemd timer, logs, locking, monitoring. |

## 10. Quick Revision

````bash
rsync -avhP SRC/ user@host:/DST/ · -n (dry run) · --delete (mirror) · --exclude · -e "ssh -p P -i KEY" · -aAXH · --link-dest
src/ = contents · src = directory · src/* skips dotfiles
key: ssh-keygen -t ed25519 -f KEY -N '' ; ssh-copy-id -i KEY.pub user@host · cron/timer + flock + log + test restores
````

## 11. Cross-References

- [SSH remote access](ssh-remote-access.md)
- [Job scheduling (cron, timers)](../logs-scheduling-and-packages/job-scheduling.md)
- [Archiving & compression](../files-and-text-processing/archiving-and-compression.md)
- [LVM snapshots](../storage-and-filesystems/lvm-snapshots-and-recovery.md)
