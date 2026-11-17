# 080 · Samba: SMB File Sharing with Windows (and Linux Clients)

> **You need first:** [079 · NFS and autofs](079-nfs-and-autofs.md)
> **Next:** [081 · DNS server with BIND](081-dns-server-bind.md)

---

## What it is

- **SMB** (Server Message Block) is the **Windows** file- and printer-sharing protocol (TCP port **445**). **CIFS** (Common Internet File System) was an old SMB version (SMB1); the name survives in Linux's `mount -t cifs`. Use **SMB2/SMB3** (SMB3 supports encryption). SMB1 is insecure and disabled by default.
- **Samba** is the open-source SMB server for Linux: it shares directories to Windows, macOS and Linux clients, and can also join or even act as an Active Directory domain.

| Package (RHEL) | Provides |
|---|---|
| `samba` | Server: `smb.service` (TCP 445, legacy 139); `nmb.service` (old NetBIOS name browsing, optional) |
| `samba-client` | `smbclient` (an FTP-like test client) |
| `cifs-utils` | `mount.cifs` (mounting shares on Linux) |

## Why it exists

Most offices are mixed: Windows laptops need to reach file shares on Linux servers (and Linux servers need to mount Windows/NAS shares). NFS is the Linux-native choice; SMB is what Windows speaks natively. Samba makes Linux a first-class Windows file server.

## Analogy

Samba is a **bilingual receptionist**: the building's filing system (Linux files, permissions, SELinux) works in Linux, but Windows visitors ask in "SMB". Samba translates both ways, checks the visitor list (Samba users) and leads them to the right cabinet (share).

## How it works inside

- `smbd` listens on 445. A client connects, negotiates the SMB dialect (prefers SMB3), and **authenticates**.
- **Samba keeps its own password database** (`tdbsam`, managed with `smbpasswd`/`pdbedit`), separate from `/etc/shadow`, because SMB uses a different password-hash format. Each Samba user must also exist as a **Linux** user: once authenticated, `smbd` **becomes that Linux user** (a per-client process), so normal Linux permissions apply to every file access.
- **Three gates** decide access: the **share settings** in `smb.conf` (`valid users`, `writable`, `guest ok`) → **Linux DAC** permissions on the directory (topic 026) → **SELinux** (the directory must be labelled `samba_share_t`, topic 073, or a boolean must allow it).
- **Guest access** maps unauthenticated users to a guest account (`nobody`) if `map to guest = bad user` and `guest ok = yes`.
- In an AD domain, Samba (with `winbind` or SSSD, topic 030) uses domain accounts instead of local ones.

## Commands

### Server setup

```bash
sudo dnf install -y samba samba-client
sudo cp -a /etc/samba/smb.conf /etc/samba/smb.conf.orig
sudo firewall-cmd --permanent --add-service=samba ; sudo firewall-cmd --reload
```

**A team share (authenticated, group-based):**
```bash
sudo groupadd -f teamshare
sudo useradd -G teamshare demo
sudo mkdir -p /srv/samba/team
sudo chown root:teamshare /srv/samba/team ; sudo chmod 2770 /srv/samba/team     # SGID (topic 027)
sudo semanage fcontext -a -t samba_share_t '/srv/samba(/.*)?'
sudo restorecon -Rv /srv/samba
sudo smbpasswd -a demo                      # Samba password (separate from Linux)
sudo pdbedit -L
```
```
New SMB password:
Retype new SMB password:
Added user demo.
demo:1002:
```

```ini
# /etc/samba/smb.conf
[global]
    workgroup = WORKGROUP
    server string = Samba %v
    security = user
    map to guest = bad user
    server min protocol = SMB2_10

[team]
    path = /srv/samba/team
    valid users = @teamshare
    writable = yes
    browseable = yes
    guest ok = no
    force group = teamshare
    create mask = 0660
    directory mask = 2770

[public]
    path = /srv/samba/public
    guest ok = yes
    writable = no
    browseable = yes
```
- `valid users = @teamshare` = only members of that group. `force group` + `create mask` keep team files group-owned and group-writable.

```bash
testparm -s | head -20                # validate the config and print the effective settings
sudo systemctl enable --now smb
smbclient -L //localhost -U demo
```
```
	Sharename       Type      Comment
	---------       ----      -------
	team            Disk
	public          Disk
	IPC$            IPC       IPC Service (Samba 4.24.5)
SMB1 disabled -- no workgroup available
```
- The last line is harmless: listing workgroups needs the old SMB1 protocol, which is disabled for security.

| SELinux boolean | Allows |
|---|---|
| `samba_enable_home_dirs` | Sharing home directories (the `[homes]` section) |
| `samba_export_all_ro` / `samba_export_all_rw` | Sharing **any** path without relabelling (broad; prefer labels) |
| `samba_share_nfs` | Re-sharing NFS-mounted directories |

### Windows clients

In Explorer or Run: `\\server1` or `\\192.168.56.10\team`, then log in as `demo`.

### Linux clients

```bash
sudo dnf install -y cifs-utils samba-client
smbclient //192.168.56.10/team -U demo          # FTP-like shell: ls, get, put, quit
sudo mkdir -p /mnt/team
sudo mount -t cifs -o username=demo,vers=3.1.1 //192.168.56.10/team /mnt/team
```

**Permanent mount with a credentials file** (never put passwords in fstab):
```bash
sudo tee /root/.smb-team <<'EOF'
username=demo
password=S3cret!
domain=WORKGROUP
EOF
sudo chmod 600 /root/.smb-team
echo '//192.168.56.10/team /mnt/team cifs credentials=/root/.smb-team,vers=3.1.1,uid=1001,gid=1001,_netdev,nofail 0 0' | sudo tee -a /etc/fstab
sudo systemctl daemon-reload && sudo mount -a && df -hT /mnt/team
```
- `uid=`/`gid=` set the **local** owner shown for all files (CIFS mounts usually present one owner). `multiuser,sec=krb5` gives true per-user access in Kerberos domains.

### Try it
1. Build the `[team]` share on server1; mount it from server2 by hand, then via fstab with a credentials file.
2. Forget the SELinux label on a new share and see the failure: `NT_STATUS_ACCESS_DENIED` in smbclient, and an AVC in `ausearch`. Fix it with `restorecon`.
3. Remove `demo` from `teamshare` and confirm access is refused.

**Check your work:** on your lab VM, from the notes folder, run `sudo ./checks/check 080` for every step, or `sudo ./checks/check 080 STEP` for one (topic 002 shows how to get the notes there).

## Where you'll use it

- **Office file servers** and NAS-style shares for Windows users.
- **Linux servers mounting Windows shares** (reports dropped by Windows apps, Azure Files over SMB).
- **Kubernetes:** the SMB CSI driver exposes SMB shares (Azure Files, Windows file servers) as persistent volumes.

## When it breaks

| Error / symptom | Cause | Fix |
|---|---|---|
| `mount error(112): Host is down` | Firewall, server down, or an SMB version mismatch | Open `samba`; try `vers=3.0` |
| `mount error(13): Permission denied` | Wrong password, not in `valid users`, or no `smbpasswd` entry | `pdbedit -L`; check `valid users` |
| `unknown filesystem type 'cifs'` | `cifs-utils` missing | `dnf install cifs-utils` |
| `NT_STATUS_BAD_NETWORK_NAME` | Wrong share name | `smbclient -L //server -U user` |
| `NT_STATUS_ACCESS_DENIED` despite the right permissions | SELinux label | `samba_share_t` via semanage + restorecon; `ausearch -m avc` |
| Guest share asks for a password | `map to guest` / `guest ok` missing | Fix smb.conf; `testparm` |
| Files created with the wrong group | No SGID or `force group` | `chmod 2770`; `force group =` |
| Logs | — | `journalctl -u smb`, `/var/log/samba/`, `dmesg \| grep -i cifs` (client) |

## Quick recap

- SMB (TCP 445, use SMB3) = Windows file sharing; Samba serves it from Linux; `mount -t cifs` mounts it on Linux.
- Access = share rules (`valid users`, `writable`) + Linux permissions + SELinux `samba_share_t`.
- Samba passwords are separate: `smbpasswd -a USER`, `pdbedit -L`. Validate with `testparm`.
- Client: `smbclient -L`, `mount -t cifs -o credentials=FILE,vers=3.1.1`, fstab with `_netdev,nofail`.

**Interview questions**

1. *SMB vs CIFS?* SMB is the protocol family; CIFS was an early dialect (SMB1) that's obsolete and insecure. Use SMB2 or SMB3.
2. *Why do you need `smbpasswd -a` when the user already has a Linux password?* SMB authentication uses a different password-hash format, so Samba keeps its own password database, separate from `/etc/shadow`.
3. *A Samba share works with SELinux permissive but not enforcing. What's the fix?* Label the shared directory `samba_share_t` with `semanage fcontext -a -t samba_share_t 'DIR(/.*)?'` and `restorecon -Rv DIR` (or use the appropriate samba boolean).

**Scenario question** (answer out loud first, then compare)

> *"Windows users can see a Samba share but get 'Access denied' opening it. The Linux permissions look correct. What do you check?"*

**Model answer:**
1. `testparm -s`: is the share defined as intended (`path`, `valid users`, `writable`)? Typos are silent otherwise.
2. Is the user in **Samba's** database? `pdbedit -L`. Linux passwords don't count; add with `smbpasswd -a user`.
3. **SELinux**: `ls -Zd /srv/share` should be `samba_share_t`. If not: `semanage fcontext -a -t samba_share_t '/srv/share(/.*)?'` and `restorecon -Rv /srv/share`. Check `ausearch -m avc -c smbd`.
4. Linux permissions **as that user**, including every parent directory (`namei -l`).
5. Test from Linux: `smbclient //server/share -U user -c ls`. The error string (`NT_STATUS_ACCESS_DENIED` vs `NT_STATUS_LOGON_FAILURE`) separates permission problems from authentication ones.

**Likely follow-ups:**
- *Which SMB versions should you allow?* SMB2/3 only; SMB1 is insecure.
- *How do you mount a share on Linux at boot without a password in fstab?* `credentials=/root/.smbcred` (mode 600), plus `_netdev,nofail`.
