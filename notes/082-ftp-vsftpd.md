# 082 · FTP with vsftpd (and Why It's Legacy)

> **You need first:** [081 · DNS server with BIND](081-dns-server-bind.md)
> **Next:** [083 · iSCSI](083-iscsi.md)

---

## What it is

**FTP** (File Transfer Protocol) is one of the oldest internet protocols, for uploading and downloading files. It uses **two kinds of connection**:

| Connection | Port | Carries |
|---|---|---|
| **Control** | TCP **21** | Commands and replies (`USER`, `PASS`, `LIST`, `RETR`) |
| **Data** | Separate connections | File contents and directory listings |

| Mode | Who opens the data connection |
|---|---|
| **Active** | The server connects **back** to the client (from port 20) |
| **Passive** (common today) | The client connects to a **high port** the server announces |

**vsftpd** ("very secure FTP daemon") is RHEL's FTP server.

**FTP is plaintext**: usernames, passwords and data travel unencrypted. Prefer **SFTP** (file transfer over SSH, topic 065) or **FTPS** (FTP over TLS). You'll still meet FTP with legacy partners, old devices (printers, scanners, network gear firmware) and some anonymous public mirrors.

## Why it exists

Before SSH and HTTPS, FTP was **the** way to move files between systems, and many business processes ("partner drops a CSV on our FTP server every night") still depend on it. Running it is also an excellent exercise in everything from Part 9: SELinux file labels, booleans, port labels and firewall helpers for a protocol with dynamic ports.

## Analogy

FTP is a **phone call to a warehouse**: one line for talking ("send me file X"), and a **separate delivery truck** for the goods. In active mode, the warehouse **sends its truck to your address** (often blocked by your gate, the client firewall). In passive mode, the warehouse **tells you which loading bay to come to**, and you drive there. And everything is said **out loud on an open line** (no encryption).

## How it works inside

- Because data ports are dynamic, a simple "allow port 21" firewall breaks listings and transfers. **Connection-tracking helpers** solve this: firewalld's `ftp` service loads the `nf_conntrack_ftp` module (topic 055), which reads the control conversation, sees which data port was agreed, and temporarily allows it. (That only works on plaintext FTP; with FTPS the helper can't read the encrypted commands, so you must open a fixed passive range.)
- vsftpd authenticates local users through **PAM** (topic 029). `/etc/vsftpd/ftpusers` lists accounts **always** denied (root, system accounts).
- **Anonymous** FTP maps everyone to the `ftp` user, rooted in `/var/ftp`.
- **chroot** (topic 057) jails users in their home directory, so they can't browse the rest of the server.
- **SELinux** confines vsftpd in `ftpd_t`: shared content must be `public_content_t` (read) or `public_content_rw_t` (write, plus a boolean), and a non-standard port needs `ftp_port_t`.

## Commands

### Install

```bash
sudo dnf install -y vsftpd lftp
sudo cp -a /etc/vsftpd/vsftpd.conf /etc/vsftpd/vsftpd.conf.orig
sudo systemctl enable --now vsftpd
sudo firewall-cmd --permanent --add-service=ftp ; sudo firewall-cmd --reload
```

| File | Purpose |
|---|---|
| `/etc/vsftpd/vsftpd.conf` | Configuration |
| `/etc/vsftpd/ftpusers` | Users **always** denied |
| `/etc/vsftpd/user_list` | An allow or deny list (depends on `userlist_deny`) |
| `/var/ftp/pub` | Default anonymous download area |

| Option | Meaning (RHEL default) |
|---|---|
| `anonymous_enable` | Allow anonymous logins (NO) |
| `local_enable` | Allow local users (YES) |
| `write_enable` | Allow any write command (YES) |
| `anon_upload_enable`, `anon_mkdir_write_enable` | Anonymous upload / mkdir (NO) |
| `anon_root=/path` | The anonymous root directory |
| `chroot_local_user=YES` | Jail local users in their home (recommended) |
| `allow_writeable_chroot=YES` | Allow a writable chroot root (otherwise vsftpd refuses) |
| `userlist_enable` + `userlist_deny=YES/NO` | `user_list` is a deny list / an allow-only list |
| `listen_port` | The control port |
| `pasv_min_port`, `pasv_max_port` | The passive data port range |
| `ssl_enable=YES` (+ certificate options) | FTPS |

Apply changes with `sudo systemctl restart vsftpd`.

### Anonymous download

```bash
sudo sed -i 's/^anonymous_enable=NO/anonymous_enable=YES/' /etc/vsftpd/vsftpd.conf
sudo systemctl restart vsftpd
date | sudo tee /var/ftp/pub/today.txt
curl ftp://localhost/pub/today.txt
lftp -e 'ls pub; bye' localhost
```
```
Mon Nov 16 19:02:11 UTC 2026
-rw-r--r--    1 0        0              29 Nov 16 19:02 today.txt
```

### Anonymous upload (needs extra steps)

```bash
sudo mkdir -p /var/ftp/upload ; sudo chown ftp:ftp /var/ftp/upload ; sudo chmod 730 /var/ftp/upload
sudo semanage fcontext -a -t public_content_rw_t '/var/ftp/upload(/.*)?' ; sudo restorecon -Rv /var/ftp/upload
sudo setsebool -P ftpd_anon_write on
# vsftpd.conf:  anon_upload_enable=YES
sudo systemctl restart vsftpd
```

### Local users

```bash
# vsftpd.conf: chroot_local_user=YES  (+ allow_writeable_chroot=YES if the home directory is writable)
echo alice | sudo tee -a /etc/vsftpd/user_list     # with userlist_deny=YES → alice is denied
lftp -u bob localhost
```
- With `userlist_deny=NO`, **only** users listed in `user_list` may log in.
- `setsebool -P ftpd_full_access on` lets local users read and write outside normal locations (broad; use with care).

### FTPS (FTP over TLS) and a fixed passive range

```
ssl_enable=YES
rsa_cert_file=/etc/pki/tls/certs/ftp.crt
rsa_private_key_file=/etc/pki/tls/private/ftp.key
force_local_logins_ssl=YES
force_local_data_ssl=YES
pasv_min_port=40000
pasv_max_port=40100
```
```bash
sudo firewall-cmd --permanent --add-port=40000-40100/tcp ; sudo firewall-cmd --reload
lftp -e 'set ftp:ssl-force true; ls; bye' -u bob localhost
```

### Non-standard port

```bash
# vsftpd.conf: listen_port=3434
sudo semanage port -a -t ftp_port_t -p tcp 3434
sudo firewall-cmd --permanent --add-port=3434/tcp ; sudo firewall-cmd --reload
sudo systemctl restart vsftpd
lftp -p 3434 localhost
```
- The conntrack helper only watches port 21, so with a custom port also set and open a passive range.

### See the problem with plain FTP

```bash
sudo tcpdump -i lo -A -n port 21 | grep -E 'USER|PASS'     # topic 096
```
```
USER bob
PASS S3cretPassw0rd
```
- Anyone on the network path can read credentials. That's why you should use SFTP instead.

### Try it
1. Enable anonymous download and fetch a file with `curl ftp://`.
2. Set up the anonymous upload directory and upload with `curl -T file ftp://localhost/upload/`. Remove the boolean and watch it fail (`553`).
3. Capture a local-user login with tcpdump and see the password in clear text.
4. Compare with `sftp bob@localhost` (encrypted).

## Where you'll use it

- **Legacy integrations** (partners, banks, old ERP systems, network-device firmware). The modern replacement is SFTP, or HTTPS uploads/object storage (S3).
- **Security audits** flag plaintext FTP; the remediation is SFTP/FTPS.
- **Learning:** the clearest real example of why firewalls need connection-tracking helpers and why SELinux has booleans.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `500 OOPS: vsftpd: refusing to run with writable root inside chroot()` | The chroot root is writable | Make it non-writable, or `allow_writeable_chroot=YES` |
| `553 Could not create file` (anonymous) | Upload not enabled, directory permissions, or SELinux | `anon_upload_enable`, `public_content_rw_t`, `ftpd_anon_write` |
| Won't start on a custom port | The port isn't labelled `ftp_port_t` | `semanage port -a -t ftp_port_t …` |
| Login works, `ls` hangs | Data ports blocked (passive range or helper) | Firewall `ftp` service; a passive range for FTPS or custom ports |
| `530 Login incorrect` for root | `ftpusers` denies it | Intended; use a regular user |
| `530 Permission denied` | The `user_list` rules | Check `userlist_deny` and the list |

## Quick recap

- FTP = control on TCP 21 + separate data connections (active/passive). Plaintext: prefer SFTP or FTPS.
- vsftpd: `/etc/vsftpd/vsftpd.conf` (`anonymous_enable`, `local_enable`, `write_enable`, `chroot_local_user`, `userlist_deny`, `pasv_*`, `ssl_enable`), `ftpusers`, `user_list`.
- Firewall `ftp` service loads the conntrack helper. SELinux: `public_content_t` / `public_content_rw_t`, `ftpd_anon_write`, `ftpd_full_access`, `ftp_port_t`.

**Interview questions**

1. *Active vs passive FTP?* In active mode the server opens the data connection back to the client from port 20; in passive mode the client opens it to a high port announced by the server, which works better through client-side firewalls and NAT.
2. *Why is plain FTP insecure, and what do you use instead?* Credentials and data are sent unencrypted, so anyone on the path can read them. Use SFTP (over SSH) or FTPS (FTP over TLS).
3. *Why does a firewall need a "helper" for FTP?* The data connections use ports negotiated inside the control connection; the conntrack helper reads that negotiation and opens the matching data port temporarily.
