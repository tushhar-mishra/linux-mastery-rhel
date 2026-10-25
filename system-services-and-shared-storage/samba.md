# Samba (SMB) Server & CIFS Client

> **Sessions:** S98 · **[Advanced/Optional]** · common in mixed Windows/Linux environments
> **Related:** [Groups (SGID collaboration)](../users-groups-and-permissions/groups.md) · [SELinux file contexts](../firewall-and-selinux/selinux-file-contexts.md) · [SELinux booleans](../firewall-and-selinux/selinux-booleans-ports-troubleshooting.md) · [Mounting & fstab](../storage-and-filesystems/mounting-and-fstab.md)

## 1. Overview

**SMB (Server Message Block)** is the Windows file/printer sharing protocol. **CIFS** was an old SMB1 dialect, and the name lives on in Linux's `mount -t cifs`. Use **SMB2/SMB3** (SMB3 supports encryption); SMB1 is disabled by default. **Samba 4.x** on RHEL provides SMB file servers and AD integration.

| Package | Provides |
|---|---|
| `samba` (+ `samba-common`) | Server: `smb.service` (TCP 445/139), `nmb.service` (NetBIOS names, UDP 137/138, optional) |
| `samba-client` | `smbclient` |
| `cifs-utils` | `mount.cifs` (client mounts) |

## 2. Server Setup

````bash
dnf install -y samba samba-client
cp -a /etc/samba/smb.conf /etc/samba/smb.conf.default
firewall-cmd --permanent --add-service=samba ; firewall-cmd --reload
````

### 2.1 Guest (anonymous) share

````bash
mkdir -p /srv/samba/anonymous
chown nobody:nobody /srv/samba/anonymous ; chmod 0755 /srv/samba/anonymous
semanage fcontext -a -t samba_share_t '/srv/samba(/.*)?' ; restorecon -Rv /srv/samba
````

````ini
# /etc/samba/smb.conf
[global]
    workgroup = WORKGROUP
    server string = Samba Server %v
    netbios name = rhel10
    security = user
    map to guest = bad user

[Anonymous]
    path = /srv/samba/anonymous
    browseable = yes
    writable = yes
    guest ok = yes
````

### 2.2 Authenticated group share

````bash
groupadd securedgroup ; useradd -G securedgroup demo
mkdir -p /srv/samba/secured
chown root:securedgroup /srv/samba/secured ; chmod 2770 /srv/samba/secured   # SGID: files keep the group
restorecon -Rv /srv/samba
smbpasswd -a demo                 # Samba password (separate from the Linux password)
pdbedit -L                        # list Samba users
````

````ini
[secured]
    path = /srv/samba/secured
    valid users = @securedgroup
    guest ok = no
    writable = yes
    browseable = yes
    force group = securedgroup     # optional: always create files with this group
    create mask = 0660
    directory mask = 2770
````

````bash
testparm                          # validate smb.conf
systemctl enable --now smb        # (+ nmb for NetBIOS browsing)
smbclient -L //localhost -U demo  # list shares
````

### SELinux booleans

| Boolean | Allows |
|---|---|
| `samba_enable_home_dirs` | Sharing users' home directories (`[homes]`) |
| `samba_export_all_ro` / `samba_export_all_rw` | Share any path read-only / read-write without relabeling (broad) |
| `samba_share_nfs` | Sharing NFS-mounted directories |
| `use_samba_home_dirs` | (Client) home directories on CIFS |

## 3. Windows Access

Use `\\rhel10` or `\\192.168.229.132` in Explorer / Run. Log in as `demo` for the secured share. Windows' workgroup (`net config workstation`) only matters for network browsing.

## 4. Linux Client

````bash
dnf install -y cifs-utils samba-client
smbclient -L //192.168.229.132 -U demo                  # list shares
smbclient //192.168.229.132/secured -U demo             # FTP-like shell: ls, get, put
mkdir -p /mnt/secured
mount -t cifs -o username=demo //192.168.229.132/secured /mnt/secured   # prompts for the password
````

### Persistent mount with a credentials file

````bash
cat > /root/.smbcred <<'EOF'
username=demo
password=redhat
domain=WORKGROUP
EOF
chmod 600 /root/.smbcred
echo '//192.168.229.132/secured /mnt/secured cifs credentials=/root/.smbcred,_netdev,nofail,vers=3.1.1,uid=1001,gid=1001 0 0' >> /etc/fstab
systemctl daemon-reload ; mount -a ; df -hT /mnt/secured
````

`uid=`/`gid=` set the local owner of files; `multiuser` + `sec=krb5` provides per-user access **[Advanced]**.

## 5. Troubleshooting

| Error / symptom | Cause | Fix |
|---|---|---|
| `mount error(112): Host is down` | Firewall, server down, SMB version mismatch | Open `samba`; try `vers=3.0` |
| `mount error(13): Permission denied` | Wrong password / not in `valid users` / no `smbpasswd` entry | `pdbedit -L`; check `valid users` |
| `mount: … unknown filesystem type 'cifs'` | `cifs-utils` missing | `dnf install cifs-utils` |
| `NT_STATUS_BAD_NETWORK_NAME` | Wrong share name | `smbclient -L` |
| Access denied despite correct perms | SELinux label | `ls -Z`; `samba_share_t` via semanage + restorecon; `ausearch -m avc` |
| Guest share asks for a password | `map to guest` / `guest ok` missing | Fix smb.conf; `testparm` |
| Logs | — | `journalctl -u smb`, `/var/log/samba/`, `dmesg \| grep -i cifs` |

## 6. Interview Questions

| Question | Answer |
|---|---|
| SMB vs CIFS? | SMB is the protocol family; CIFS was an SMB1 dialect (obsolete). Use SMB2/3. |
| Why `smbpasswd -a`? | Samba keeps its own password database (tdbsam), separate from `/etc/shadow`. |
| How do you share a custom directory with SELinux enforcing? | `semanage fcontext -a -t samba_share_t 'DIR(/.*)?'` + `restorecon -Rv DIR`. |
| How do you mount a share securely at boot? | fstab with `credentials=` file (mode 600), `_netdev`, SMB3. |

## 7. Quick Revision

````bash
dnf install samba samba-client cifs-utils · /etc/samba/smb.conf [global]/[share] · testparm · systemctl enable --now smb (nmb)
smbpasswd -a U · pdbedit -L · firewall samba · semanage fcontext -a -t samba_share_t 'DIR(/.*)?' ; restorecon -Rv
smbclient -L //SRV -U U · mount -t cifs -o credentials=F //SRV/SHARE MNT · fstab credentials=,_netdev,nofail,vers=3.1.1
````

## 8. Cross-References

- [Groups (SGID collaboration)](../users-groups-and-permissions/groups.md)
- [SELinux file contexts](../firewall-and-selinux/selinux-file-contexts.md)
- [SELinux booleans](../firewall-and-selinux/selinux-booleans-ports-troubleshooting.md)
- [Mounting & fstab](../storage-and-filesystems/mounting-and-fstab.md)
