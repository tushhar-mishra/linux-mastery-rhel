# 068 · rsync and Automated Backups

> **You need first:** [067 · SSH tunnels](067-ssh-tunnels.md)
> **Next:** [069 · Time sync with chrony](069-time-sync-chrony.md)

---

## What it is

**rsync** ("remote sync") copies and **synchronises** files and directories, locally or between machines over SSH, transferring **only what changed**. Interrupted transfers can be resumed, and it can preserve all metadata (owners, permissions, times, links, ACLs, SELinux labels).

A **backup** is a copy you can restore from after data loss. **rsync on its own is a copy tool, not a full backup strategy**, but it's the building block of many.

## Why it exists

Copying a 200 GB directory again every night with `scp` would be slow and wasteful. rsync compares source and destination and sends only the differences, so the second run takes seconds. It's the standard tool for migrations (move data to a new server, then a quick final sync during the cut-over), mirrors, deployments of static files, and simple off-host backups.

## Analogy

rsync is a **smart mover with a checklist**. On the first trip he moves everything. On later trips he walks through both houses, compares the item lists, and only carries what's new or changed. With `--delete`, he also **throws out** anything in the new house that's no longer in the old one, which is great for a mirror and disastrous if you pointed him at the wrong house.

## How it works inside

1. rsync starts a copy of itself on the remote side, through SSH (so **rsync must be installed on both ends**).
2. The receiver sends a list of its files. By default, a file is "unchanged" if its **size and modification time** match (`--checksum` compares content instead, which is slower).
3. For changed files, the **delta-transfer algorithm** splits the receiver's old copy into blocks, sends their **checksums**, and the sender transmits only the blocks that differ, plus instructions to rebuild the new file. Large files with small edits transfer very little.
4. The receiver writes the new version to a **temporary file**, then **renames** it into place (atomic, topic 007). With `--partial`, an interrupted transfer keeps what it already got.

### The trailing slash rule

| Command | Result |
|---|---|
| `rsync -a src/ dest/` | Copies the **contents** of `src` into `dest` |
| `rsync -a src dest/` | Creates **`dest/src/…`** |
| `rsync -a src/* dest/` | Like the first, but the shell glob **skips hidden files** (topic 013) |

## Commands

```bash
sudo dnf install -y rsync          # on BOTH machines (Ubuntu: apt install rsync)
```

| Option | Meaning |
|---|---|
| `-a` | **Archive**: recursive + keep permissions, owner/group (as root), times, symlinks, devices |
| `-v` / `-h` | Verbose / human-readable sizes |
| `-z` | Compress in transit (helps on slow links; wasteful on fast ones) |
| `-P` | `--partial --progress`: resumable, with a progress display |
| `-n` / `--dry-run` | Show what **would** happen; change nothing |
| `--delete` | Delete destination files that no longer exist in the source (**mirror**) ⚠️ |
| `--exclude='*.tmp'`, `--exclude-from=FILE` | Skip paths |
| `-e "ssh -p 2222 -i KEY"` | SSH options |
| `-A -X -H` | Keep ACLs, extended attributes (including SELinux labels), hard links |
| `--checksum` | Compare file contents, not size/time |
| `--bwlimit=10M` | Limit bandwidth |
| `--link-dest=DIR` | Hard-link unchanged files to a previous backup (space-efficient daily snapshots) |

```bash
rsync -avhP /srv/data/ alice@backup01:/backups/web01/data/
```
```
sending incremental file list
./
reports/2026-11.csv
        180.22M 100%   98.10MB/s    0:00:01 (xfr#1, to-chk=12/15)
...
sent 180.31M bytes  received 342 bytes  72.13M bytes/sec
total size is 2.10G  speedup is 11.65
```
- `speedup is 11.65` = only about 1/12 of the data had to be sent; the rest was already there.

```bash
rsync -avhn --delete /srv/data/ backup01:/backups/data/
```
```
sending incremental file list
deleting old/report-2024.csv
reports/2026-12.csv

sent 151 bytes  received 38 bytes  378.00 bytes/sec
total size is 2.10G  speedup is 110,960.44 (DRY RUN)
```
- **Always dry-run `--delete` first.** `deleting …` lines show what would be removed.

```bash
rsync -avh alice@web01:/var/www/ /restore/www/          # pull from a remote machine
sudo rsync -aAXH --delete /etc/ backup01:/backups/etc/   # keep ACLs, xattrs/SELinux, hard links
```

### Automated backup over SSH

```bash
# On the source, as the account that runs the job:
ssh-keygen -t ed25519 -f ~/.ssh/backup_ed25519 -N ''            # a dedicated key, no passphrase (automation)
ssh-copy-id -i ~/.ssh/backup_ed25519.pub backup@backup01
ssh -i ~/.ssh/backup_ed25519 backup@backup01 true               # must not ask for a password
```

```bash
# /usr/local/bin/backup.sh
#!/bin/bash
set -euo pipefail
exec 9>/run/lock/backup.lock ; flock -n 9 || exit 0              # never overlap (topic 045)
dest="backup@backup01:/backups/$(hostname -s)"
today=$(date +%F)
/usr/bin/rsync -aAXH --delete \
    --link-dest="../latest" \
    -e "ssh -i /root/.ssh/backup_ed25519" \
    /srv/data/ "$dest/$today/" >> /var/log/backup.log 2>&1
ssh -i /root/.ssh/backup_ed25519 backup@backup01 "ln -sfn $today /backups/$(hostname -s)/latest"
```
- Each night a new dated directory is created. Files unchanged since `latest` are **hard links** (topic 008), so they take no extra space, yet every day looks like a full copy you can browse. This gives you **versions**, not just a mirror.
- Schedule it with a systemd timer or cron (topic 039).

**Restrict the backup key** on the receiving server so it can only run rsync into one directory: in `~backup/.ssh/authorized_keys`, prefix the key with `command="rrsync /backups/web01",restrict`. `rrsync` is a helper script shipped with rsync.

### Verify and restore

```bash
rsync -avhn --checksum /srv/data/ backup01:/backups/web01/latest/    # does anything differ?
rsync -avh backup01:/backups/web01/2026-11-15/ /restore/             # restore a specific day
```
**A backup you have never restored is not a backup.** Test restores on a schedule.

### Backup principles

- **3-2-1:** 3 copies of your data, on 2 different kinds of media, with 1 off-site.
- **Versions:** a plain `--delete` mirror copies deletions and corruption (and ransomware encryption) to the backup the next night. Keep dated versions (`--link-dest`) or use backup software (restic, borg, Bacula, cloud snapshots).
- **Consistency:** databases need a dump (`pg_dump`, `mysqldump`) or a snapshot (topic 052) first; copying live database files gives a corrupt backup.
- **Monitoring:** check exit codes and log sizes; alert when a backup fails or is too old.

### Try it
1. `rsync -av src dest/` vs `rsync -av src/ dest/`: see where the files land.
2. Sync a directory, change one file and add one, then sync again with `-v` and see that only those two moved.
3. Delete a file in the source and try `--delete` with `-n` first.
4. Build the `--link-dest` script for two "days" and check with `ls -li` that unchanged files share inodes.

## Where you'll use it

- **Server migrations:** a bulk rsync while the old server is live, then a short downtime and a final `rsync --delete` to catch the last changes.
- **Backups** of configs, home directories and file shares; feeding off-site copies.
- **Deployments** of static sites and artifacts (`rsync -az --delete build/ web:/var/www/site/`).
- **Kubernetes/containers:** less common directly, but backup tools for volumes (Velero with restic/kopia) use the same "only send changed chunks" idea.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `rsync: command not found` (on the remote side) | Not installed there | Install rsync on both ends |
| It asks for a password from cron | The key isn't used or installed | `-e "ssh -i KEY"`; test by hand **as the same user** |
| Files end up in `dest/src/` | Trailing-slash rule | `src/` vs `src` |
| Hidden files weren't copied | You used `src/*` | Use `src/` |
| Owner/group not preserved | Not root on the receiving side | Run the receiver as root, or accept it |
| `--delete` removed things you needed | Wrong or empty source path | Always `-n` first; check paths in scripts (`${dir:?}`) |
| Jobs pile up | A run is still going when the next starts | `flock -n` |
| SELinux labels are wrong after a restore | Not copied with `-X` | `-aAX`, or `restorecon -R` afterwards (topic 073) |

## Quick recap

- rsync sends only differences, over SSH; it needs rsync on both ends. `-a` keeps metadata, `-P` resumes, `-n` dry-runs.
- **`src/` = the contents; `src` = the directory itself.** `src/*` skips dotfiles.
- `--delete` mirrors (dry-run it first). `-aAXH` for ACLs, SELinux labels and hard links. `--link-dest` gives versioned snapshots.
- Automate with a dedicated restricted key + a timer/cron + `flock` + logs, and **test restores** (3-2-1).

**Interview questions**

1. *rsync vs scp?* rsync transfers only the differences, can resume, can mirror (`--delete`) and preserves all metadata. scp copies whole files every time.
2. *What does the trailing slash on the source mean?* `src/` copies the directory's contents into the destination; `src` copies the directory itself, creating `dest/src`.
3. *Why isn't an rsync `--delete` mirror a good backup on its own?* It faithfully copies deletions, corruption and ransomware damage to the backup on the next run. You need multiple dated versions and off-site copies.
