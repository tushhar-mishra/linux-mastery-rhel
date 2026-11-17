# 079 · NFS and autofs: Network File Shares

> **You need first:** [078 · Web servers](078-web-servers-apache-and-nginx.md)
> **Next:** [080 · Samba](080-samba.md)

---

## What it is

- **NFS** (Network File System) lets a server **export** (share) directories, which clients then **mount** over the network as if they were local filesystems (topic 048). RHEL defaults to **NFSv4.2**, which needs only **TCP port 2049**.
- **autofs** mounts shares **automatically, on demand**: the moment someone touches a path such as `/shares/projects` or `/home/guests/alice`, and unmounts them again after a period of no use.

| Package | Provides |
|---|---|
| `nfs-utils` | Server (`nfs-server.service`, `exportfs`) and client tools (`mount.nfs`, `showmount`) |
| `autofs` | `autofs.service`, `/etc/auto.master`, map files |

Ubuntu: `nfs-kernel-server` (server) and `nfs-common` (client); `autofs` is the same.

## Why it exists

Many machines need the **same files**: shared home directories that follow users to any server, shared project data, build artifacts, media, Kubernetes persistent volumes that several pods can mount at once (ReadWriteMany). NFS is the simplest, most widespread way to do that on Linux. autofs avoids two classic problems with static mounts: **boots hanging** while waiting for an NFS server, and hundreds of mounts sitting permanently mounted.

## Analogy

NFS is a **shared filing room in another building**. With a normal mount you **permanently connect a corridor** to it from your office (fstab). With autofs, there's a **magic door**: it only builds the corridor when you open the door, and quietly removes it after you've been away for a while.

## How it works inside

### NFS

1. The server's kernel NFS daemon (`nfsd`) serves the directories listed in **`/etc/exports`** to the allowed clients, with the options given.
2. The client mounts `server:/export`. Each file operation (`open`, `read`, `write`) becomes an **RPC** (Remote Procedure Call) over TCP 2049. The client caches data and attributes, much like the local page cache.
3. **Identity is by number.** With the default security (`sec=sys`, also called AUTH_SYS), the client simply **sends the user's UID/GID**, and the server **trusts** it. So UIDs must match across machines (topics 022, 030), or files show the wrong owners and access is wrong. NFSv4 additionally maps users by name@domain (`/etc/idmapd.conf`).
4. **root_squash** (the default) turns a client's **root** into the anonymous user `nobody` on the server, so a client's root can't own the server's files.
5. **`hard` mounts** (the default): if the server goes away, processes accessing the share **hang** (often in `D` state, topic 033) and retry forever until it comes back. This protects data integrity, but it's why a dead NFS server freezes `df` and `ls`, and makes the load average spike.
6. **NFSv3** additionally needs `rpcbind` (port 111) and `mountd`. NFSv4 uses a single port and a "pseudo-root" tree of all exports.

### autofs

1. `autofs.service` reads the **master map** (`/etc/auto.master` + `/etc/auto.master.d/*.autofs`), which lists **mount points** and the **map files** describing them.
2. For each mount point, it creates a special **autofs filesystem** that the kernel watches.
3. When a program accesses `/shares/public`, the kernel tells the automounter, which looks up the key `public` in the map, mounts the share there, and lets the program continue. The first access takes a moment; later accesses are normal.
4. After `--timeout` seconds without use, it unmounts it.

| Map type | Master line | Map line | Result |
|---|---|---|---|
| **Indirect** | `/shares /etc/auto.shares` | `public -ro server:/srv/nfs/public` | `/shares/public` |
| **Wildcard** | `/home/guests /etc/auto.guests` | `* -rw server:/home/guests/&` | `/home/guests/<anyname>`: `*` matches any key, `&` inserts it |
| **Direct** | `/- /etc/auto.direct` | `/mnt/data -rw server:/srv/data` | An absolute path |

autofs creates the key directories itself. **Don't pre-create** `/shares/public`.

## Commands

### NFS server

```bash
sudo dnf install -y nfs-utils
sudo mkdir -p /srv/nfs/public /srv/nfs/private
echo "shared hello" | sudo tee /srv/nfs/public/readme.txt
sudo vi /etc/exports
```
```
/srv/nfs/public   192.168.56.0/24(ro,sync)
/srv/nfs/private  192.168.56.10(rw,sync,root_squash)
```

| Option | Meaning |
|---|---|
| `ro` / `rw` | Read-only / read-write |
| `sync` / `async` | Write to disk **before** replying (safe) / reply first (faster, risky) |
| `root_squash` (default) | The client's root becomes `nobody` |
| `no_root_squash` | The client's root stays root ⚠️ |
| `all_squash`, `anonuid=`, `anongid=` | Map **every** user to one anonymous UID/GID |
| `sec=sys` / `sec=krb5p` | Trust client UIDs / Kerberos with encryption |

**There must be no space between a client and its options:** `host(rw)`. Writing `host (rw)` means "the host gets the defaults (read-only), and **everyone** gets rw".

```bash
sudo systemctl enable --now nfs-server
sudo exportfs -arv
sudo firewall-cmd --permanent --add-service=nfs
sudo firewall-cmd --permanent --add-service={rpc-bind,mountd}   # only for NFSv3 clients / showmount
sudo firewall-cmd --reload
```
```
exporting 192.168.56.10:/srv/nfs/private
exporting 192.168.56.0/24:/srv/nfs/public
```
- `exportfs -a` = export all, `-r` = re-read `/etc/exports`, `-v` = verbose. `exportfs -v` lists the active exports with all their options.
- SELinux: NFS can export any label by default (booleans `nfs_export_all_ro/rw` are on).

### NFS client: manual and permanent mounts

```bash
sudo dnf install -y nfs-utils
showmount -e 192.168.56.11
sudo mkdir -p /mnt/public
sudo mount -t nfs 192.168.56.11:/srv/nfs/public /mnt/public
findmnt /mnt/public
```
```
Export list for 192.168.56.11:
/srv/nfs/public  192.168.56.0/24
/srv/nfs/private 192.168.56.10
TARGET      SOURCE                         FSTYPE OPTIONS
/mnt/public 192.168.56.11:/srv/nfs/public  nfs4   rw,relatime,vers=4.2,rsize=262144,wsize=262144,namlen=255,hard,fatal_neterrors=none,proto=tcp,timeo=600,retrans=2,sec=sys,...
```
- `vers=4.2` was negotiated. `hard` = retry forever if the server disappears. `rsize/wsize` = the transfer block size. `sec=sys` = UID-based trust.
- The mount says `rw` although the export is `ro`: these are the **client's** mount options. The server still enforces its export, so a write fails with `Read-only file system`. Mount with `-o ro` if you want the client side to say so too.

```
# /etc/fstab
192.168.56.11:/srv/nfs/public  /mnt/public  nfs  defaults,_netdev,nofail  0 0
```
```bash
sudo systemctl daemon-reload && sudo mount -a
```
- `_netdev` = wait for the network; `nofail` = don't stop the boot if the server is down (topic 048). Other options: `ro`, `vers=4.2`, `soft` (return errors instead of hanging; risky for writes).

### autofs

```bash
sudo dnf install -y autofs
sudo systemctl enable --now autofs
```

**Indirect map:**
```bash
echo '/shares  /etc/auto.shares  --timeout=60' | sudo tee /etc/auto.master.d/shares.autofs
sudo tee /etc/auto.shares <<'EOF'
public   -ro,sync  192.168.56.11:/srv/nfs/public
private  -rw,sync  192.168.56.11:/srv/nfs/private
EOF
sudo systemctl restart autofs
ls /shares                 # empty: nothing is mounted yet
ls /shares/public          # touching it triggers the mount
findmnt /shares/public
```
```

readme.txt
TARGET         SOURCE                        FSTYPE OPTIONS
/shares/public 192.168.56.11:/srv/nfs/public nfs4   ro,relatime,vers=4.2,...
```
- Keys aren't listed until used, unless you set `browse_mode = yes` in `/etc/autofs.conf`.

**Wildcard map for home directories:**
```bash
echo '/home/guests  /etc/auto.guests' | sudo tee /etc/auto.master.d/guests.autofs
echo '*  -rw,sync  nfs1.example.com:/home/guests/&' | sudo tee /etc/auto.guests
sudo systemctl restart autofs
su - guest1 ; pwd
```
```
/home/guests/guest1
```
- `*` = any key that's accessed; `&` = that key substituted into the remote path. One line serves every user, and users are typically directory (LDAP/IdM) users with matching UIDs (topic 030).

**Direct map:**
```bash
echo '/-  /etc/auto.direct' | sudo tee /etc/auto.master.d/direct.autofs
echo '/mnt/data  -rw,sync  192.168.56.11:/srv/nfs/private' | sudo tee /etc/auto.direct
sudo systemctl restart autofs ; ls /mnt/data
```

```bash
sudo automount -m              # print the effective maps
journalctl -u autofs -b
```

### Try it
1. Make server2 an NFS server exporting `/srv/nfs/public` (ro) and `/srv/nfs/private` (rw to server1 only).
2. On server1, mount it by hand, then via fstab with `_netdev,nofail`, and reboot to test.
3. Replace the fstab entry with an autofs indirect map; watch it mount on access and unmount after the timeout (`--timeout=30`).
4. As root on server1, create a file in the rw share and check its owner on server2 (`nobody`: root_squash).
5. Stop nfs-server on server2 while server1 has the share mounted; try `ls` and `df` on server1 (they hang). Start it again.

**Check your work:** on your lab VM, from the notes folder, run `sudo ./checks/check 079` for every step, or `sudo ./checks/check 079 STEP` for one (topic 002 shows how to get the notes there).

## Where you'll use it

- **Shared home directories** across many servers (with central identity, topic 030).
- **Shared application data:** CMS uploads, build caches, ML datasets.
- **Kubernetes:** NFS is a very common **ReadWriteMany** storage backend (the NFS CSI driver; cloud services like EFS and Filestore are NFS). Pods hanging in `ContainerCreating` with mount errors, or stuck processes in `D` state on nodes, often trace back to NFS.
- **Backups and archives** to a NAS (Network Attached Storage).

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `mount.nfs: access denied by server while mounting` | The client isn't in the exports, or `exportfs -r` wasn't run | Check `/etc/exports`; `exportfs -arv` |
| `mount.nfs: Connection timed out` / `No route to host` | Firewall or network | Open the `nfs` service on the server; `ping`; routing |
| `showmount: … RPC: Unable to receive` | rpcbind/mountd blocked (NFSv3 only) | Open `rpc-bind`,`mountd`, or skip showmount (v4 mounts still work) |
| Files owned by `nobody` | root_squash, or a UID / NFSv4 ID-domain mismatch | Expected for root; align UIDs; set `Domain=` in `/etc/idmapd.conf` |
| `Permission denied` writing | Exported `ro`, Unix permissions on the server, root_squash | Check export options and directory permissions |
| `ls`/`df` hang, load average climbs, processes in `D` | The NFS server is unreachable (hard mount) | Restore the server or network; `umount -f -l` as a last resort |
| An autofs path is empty / doesn't mount | A map typo, autofs not restarted, the key not accessed | `automount -m`; `journalctl -u autofs`; `ls /base/key` |
| Boot hangs on an NFS fstab entry | No `_netdev`/`nofail`, server down | Add the options, or use autofs |
| Stale file handle | The export was recreated or moved on the server | Unmount and remount |

## Quick recap

- Server: `/etc/exports` `DIR CLIENT(rw,sync)` (no space before the bracket!) → `exportfs -arv` → `nfs-server` → firewall `nfs`.
- Client: `mount -t nfs SRV:/EXP DIR`; fstab with `nfs defaults,_netdev,nofail`. NFSv4.2 on TCP 2049.
- Trust is by **UID** (`sec=sys`): keep UIDs consistent. root_squash makes client root = `nobody`. Hard mounts hang if the server dies.
- autofs: `/etc/auto.master.d/X.autofs` + a map; indirect (`key -opts SRV:/path`), wildcard (`* … /home/&`), direct (`/-`). Mounts on access.

**Interview questions**

1. *What is root_squash?* An export option (the default) that maps the client's root user to the anonymous `nobody` user on the server, so root on a client can't act as root on the server's files.
2. *Why do processes hang when an NFS server goes down?* NFS mounts are `hard` by default: operations are retried until the server answers, leaving processes stuck in uninterruptible sleep (`D` state) rather than returning errors that could corrupt data.
3. *Why use autofs instead of fstab for NFS?* Shares are mounted only when accessed and unmounted when idle, the boot never waits on network servers, and one wildcard map can serve every user's home directory.

**Scenario question** (answer out loud first, then compare)

> *"An NFS server went down for 10 minutes. Now `df` hangs on every client and the load average is 50. What's happening, and what do you do?"*

**Model answer:**
1. NFS mounts are **hard** by default: every process touching the mount (including `df`, which `stat`s every filesystem) waits forever in **D** state for the server. Each counts toward the load average.
2. Once the server is back, the clients usually recover by themselves. Check `rpcinfo -p server`, `showmount -e server` and `mount | grep nfs`.
3. If the server is gone for good: `umount -f -l /mnt/share` (lazy, forced) to detach it, then fix fstab or the automounter.
4. Avoid hanging tools while you work: `df -x nfs4`, or `df -l` (local filesystems only).
5. Prevention:
   - mount through autofs, so idle shares aren't mounted;
   - `nofail,_netdev` in fstab;
   - monitoring on the NFS server;
   - consider `soft` only for read-only, non-critical data (`soft` can return I/O errors mid-write).

**Likely follow-ups:**
- *What's root_squash?* The client's root is mapped to `nobody` on the server.
- *Why must UIDs match between NFS clients and server?* With `sec=sys` the server trusts the numeric UID the client sends.
