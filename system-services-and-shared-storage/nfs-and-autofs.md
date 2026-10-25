# NFS & autofs

> **Sessions:** S97 · **Objectives:** *Mount and unmount network file systems using NFS* · *Configure autofs* **[RHCSA Core]** · NFS server **[Advanced/Optional]**
> **Related:** [Mounting & fstab](../storage-and-filesystems/mounting-and-fstab.md) · [firewalld](../firewall-and-selinux/firewalld.md) · [SELinux booleans](../firewall-and-selinux/selinux-booleans-ports-troubleshooting.md) · [Local users (home directories)](../users-groups-and-permissions/local-users.md) · [Central identity (directory users)](../users-groups-and-permissions/central-identity-nss-sssd.md)

## 1. Overview

**NFS** shares directories over the network; clients mount them like local filesystems. RHEL defaults to **NFSv4.2**, which uses **TCP 2049** only. NFSv3 additionally needs rpcbind (111) and mountd. **autofs** mounts shares **on demand** when a path is accessed and unmounts them after an idle timeout. That avoids boot hangs and keeps many mounts manageable.

| Package | Provides |
|---|---|
| `nfs-utils` | Server (`nfs-server.service`, `exportfs`) and client tools (`mount.nfs`, `showmount`) |
| `autofs` | `autofs.service`, `/etc/auto.master`, maps |

## 2. NFS Server **[Advanced/Optional]**

````bash
dnf install -y nfs-utils
mkdir -p /srv/nfs/public /srv/nfs/private
echo 'PRIVATE NFS DATA' > /srv/nfs/private/private.txt
chmod 755 /srv/nfs/public ; chmod 770 /srv/nfs/private      # set ownership as the share requires
vi /etc/exports
````

`````
/srv/nfs/public   192.168.1.0/24(ro,sync)
/srv/nfs/private  192.168.1.110(rw,sync,root_squash)
`````

| Option | Meaning |
|---|---|
| `ro` / `rw` | Read-only / read-write |
| `sync` / `async` | Write to disk before replying (safe) / reply first (faster, risk) |
| `root_squash` (default) | Client root → `nobody` |
| `no_root_squash` | Client root stays root ⚠️ |
| `all_squash`, `anonuid=`, `anongid=` | Map every user to an anonymous UID/GID |
| `sec=sys` / `sec=krb5p` | AUTH_SYS (UIDs trusted) / Kerberos with encryption |

> ⚠️ No space between the client and its options: `host(rw)`. Writing `host (rw)` grants **rw to everyone** and ro to the host.

````bash
systemctl enable --now nfs-server
exportfs -arv                  # (re)export all; exportfs -v to list; exportfs -u … to unexport
firewall-cmd --permanent --add-service=nfs
firewall-cmd --permanent --add-service={rpc-bind,mountd}   # only for NFSv3 clients / showmount
firewall-cmd --reload
````

**SELinux:** NFS can export any SELinux label (booleans `nfs_export_all_ro` / `nfs_export_all_rw` are on by default). No relabeling is needed for NFS itself.

## 3. NFS Client: Manual & Persistent Mounts **[RHCSA Core]**

````bash
dnf install -y nfs-utils
showmount -e 192.168.1.109                       # list exports (needs NFSv3 services on the server)
mkdir -p /mnt/public
mount -t nfs 192.168.1.109:/srv/nfs/public /mnt/public       # negotiates NFSv4.2
mount 192.168.1.109:/ /mnt/nfsroot              # NFSv4 pseudo-root: browse all exports
findmnt -t nfs4 ; df -hT /mnt/public ; umount /mnt/public
````

`````
# /etc/fstab
192.168.1.109:/srv/nfs/public  /mnt/public  nfs  defaults,_netdev  0 0
`````

`systemctl daemon-reload ; mount -a`. Useful options: `ro`, `vers=4.2`, `_netdev` (wait for network), `nofail`, `soft` (return errors instead of hanging; risky for writes; default is `hard`).

## 4. autofs **[RHCSA Core]**

````bash
dnf install -y autofs nfs-utils
systemctl enable --now autofs
````

### 4.1 Indirect map (mount points under a common directory)

````bash
cat > /etc/auto.master.d/shares.autofs <<'EOF'
/shares  /etc/auto.shares  --timeout=60
EOF
cat > /etc/auto.shares <<'EOF'
public   -ro,sync  192.168.1.109:/srv/nfs/public
private  -rw,sync  192.168.1.109:/srv/nfs/private
EOF
systemctl restart autofs
ls /shares                 # empty: nothing mounted yet (not browsable by default)
cd /shares/public ; df -hT .   # access triggers the mount
````

autofs creates and manages `/shares/*` itself; **don't** pre-create the subdirectories.

### 4.2 Wildcard map for home directories (classic exam task)

````bash
echo '/home/guests  /etc/auto.guests' > /etc/auto.master.d/guests.autofs
echo '*  -rw,sync  server.lab.example.com:/home/guests/&' > /etc/auto.guests
systemctl restart autofs
su - ldapuser1 ; pwd       # /home/guests/ldapuser1 mounted automatically at login
````

`*` matches the accessed name and `&` substitutes it.

### 4.3 Direct map (absolute mount points)

````bash
echo '/-  /etc/auto.direct' > /etc/auto.master.d/direct.autofs
echo '/mnt/data  -rw,sync  192.168.1.109:/srv/nfs/private' > /etc/auto.direct
systemctl restart autofs ; ls /mnt/data
````

### 4.4 Inspect

````bash
automount -m                 # dump effective maps
journalctl -u autofs -b
grep -E 'browse_mode|timeout' /etc/autofs.conf   # browse_mode=yes shows keys without mounting
````

## 5. RHCSA Exam Focus **[RHCSA Core]**

- **NFS mount:** `mount -t nfs server:/export /mnt/x`; make it persistent with fstab `nfs defaults,_netdev 0 0`; then `mount -a` + reboot test.
- **autofs:** master entry in `/etc/auto.master.d/*.autofs` + map file; `systemctl enable --now autofs`; test by `cd`-ing into the path. Use **wildcard maps** for user homes.
- Read the task for `rw`/`ro`, the exact mount point and the timeout.

## 6. Production Practices **[Production Practice]**

- Use NFSv4.2 and, where possible, Kerberos (`sec=krb5p`); otherwise trust is based on client IP and UIDs.
- Keep UIDs/GIDs consistent across hosts (central identity: IdM/LDAP).
- Prefer autofs for many or optional mounts; `_netdev,nofail` in fstab for essential ones.
- Never `no_root_squash` except for tightly controlled hosts.

## 7. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `mount.nfs: access denied by server` | Client not in exports / not re-exported | Check `/etc/exports`; `exportfs -arv` |
| `mount.nfs: Connection timed out` / `No route to host` | Firewall / network | `firewall-cmd --add-service=nfs`; ping |
| `showmount: … RPC: Unable to receive` | rpcbind/mountd blocked (NFSv3 only) | Add `rpc-bind`, `mountd` services, or skip showmount (v4 mount still works) |
| Files owned by `nobody` | root_squash, or ID mapping/domain mismatch | Expected for root; check `/etc/idmapd.conf` Domain for v4 |
| `Permission denied` writing | Export `ro`, directory permissions, root_squash | Check export options and Unix perms |
| autofs path empty / not mounting | Typo in map, autofs not restarted, key not accessed | `automount -m`; `journalctl -u autofs`; `cd` into the key |
| Boot hangs on NFS fstab entry | Server down, no `_netdev`/`nofail` | Add options or use autofs |

## 8. Interview Questions

| Question | Answer |
|---|---|
| NFSv3 vs NFSv4? | v4 uses one port (2049), stateful, pseudo-root, better security/ACLs; v3 needs rpcbind/mountd. |
| What is root_squash? | Client root is mapped to `nobody` on the server. |
| Indirect vs direct autofs map? | Indirect: keys under a parent directory (`/shares/key`). Direct: absolute paths (`/-` in the master map). |
| What do `*` and `&` mean in an autofs map? | Wildcard key and substitution of the matched key. |
| Why autofs instead of fstab? | On-demand mounts, no boot hangs, idle unmount, easy wildcard home directories. |

## 9. Quick Revision

````bash
server: /etc/exports "DIR CLIENT(rw,sync)" · exportfs -arv · systemctl enable --now nfs-server · firewall nfs (+rpc-bind,mountd v3)
client: mount -t nfs SRV:/EXP MNT · fstab: SRV:/EXP MNT nfs defaults,_netdev 0 0 · showmount -e SRV
autofs: /etc/auto.master.d/X.autofs "/base /etc/auto.X --timeout=60" · map "key -rw SRV:/path" · "* -rw SRV:/home/&" · "/- /etc/auto.direct"
systemctl enable --now autofs ; restart after edits · automount -m · cd /base/key
````

## 10. Cross-References

- [Mounting & fstab](../storage-and-filesystems/mounting-and-fstab.md)
- [firewalld](../firewall-and-selinux/firewalld.md)
- [SELinux booleans](../firewall-and-selinux/selinux-booleans-ports-troubleshooting.md)
- [Local users (home directories)](../users-groups-and-permissions/local-users.md)
