# FTP with vsftpd

> **Sessions:** S96 · **[Advanced/Optional]** · good practice for SELinux labels/booleans/ports and firewall
> **Related:** [SELinux file contexts](../firewall-and-selinux/selinux-file-contexts.md) · [SELinux booleans & ports](../firewall-and-selinux/selinux-booleans-ports-troubleshooting.md) · [firewalld](../firewall-and-selinux/firewalld.md) · [SSH (SFTP alternative)](../networking-and-ssh/ssh-remote-access.md)

## 1. Overview

**FTP** transfers files using a **control connection (TCP 21)** plus separate **data connections**:

| Mode | Data connection |
|---|---|
| Active | Server connects back **from port 20** to the client |
| Passive (common) | Client connects to a **high port** the server announces |

The firewalld `ftp` service loads a connection-tracking helper that handles these data ports. FTP is **plaintext** (credentials included), so use SFTP (SSH) or FTPS where possible. RHEL's FTP server is **vsftpd**.

## 2. Install & Basics

`````bash
dnf install -y vsftpd ftp            # (client alternatives: lftp, curl ftp://)
cp -a /etc/vsftpd/vsftpd.conf /etc/vsftpd/vsftpd.conf.bak
systemctl enable --now vsftpd
firewall-cmd --permanent --add-service=ftp ; firewall-cmd --reload
`````

| File | Purpose |
|---|---|
| `/etc/vsftpd/vsftpd.conf` | Configuration |
| `/etc/vsftpd/ftpusers` | Users **always** denied (via PAM): root, system accounts |
| `/etc/vsftpd/user_list` | Allow or deny list, depending on `userlist_deny` |
| `/var/ftp/pub` | Default anonymous area |

## 3. Key Options

| Option | Meaning (RHEL default) |
|---|---|
| `anonymous_enable` | Allow anonymous logins (NO) |
| `local_enable` | Allow local users (YES) |
| `write_enable` | Allow any write commands (YES) |
| `anon_upload_enable`, `anon_mkdir_write_enable` | Anonymous upload / mkdir (NO) |
| `anon_root=/path` | Anonymous root directory |
| `chroot_local_user=YES` | Jail local users in their home (recommended) |
| `allow_writeable_chroot=YES` | Permit a writable chroot root (else "refusing to run with writable root") |
| `userlist_enable` + `userlist_deny=YES/NO` | `user_list` is a deny list / an allow-only list |
| `listen_port=21` | Control port |
| `pasv_min_port` / `pasv_max_port` | Passive port range (open it in the firewall if not using the helper) |
| `ssl_enable=YES` (+ cert options) | FTPS |

Apply changes with `systemctl restart vsftpd`.

## 4. Anonymous Download

`````bash
sed -i 's/^anonymous_enable=NO/anonymous_enable=YES/' /etc/vsftpd/vsftpd.conf
systemctl restart vsftpd
cal > /var/ftp/pub/calendar.txt
ftp localhost      # Name: anonymous, password: any (e.g., abc@mail.com) → cd pub → get calendar.txt → bye
`````

## 5. Anonymous Upload (needs extra steps)

`````bash
mkdir -p /var/ftp/upload ; chown ftp:ftp /var/ftp/upload ; chmod 730 /var/ftp/upload
semanage fcontext -a -t public_content_rw_t '/var/ftp/upload(/.*)?' ; restorecon -Rv /var/ftp/upload
setsebool -P ftpd_anon_write on
# vsftpd.conf: anon_upload_enable=YES  (write_enable=YES already)
systemctl restart vsftpd
`````

## 6. Local Users & Access Lists

`````bash
ftp localhost                 # log in as a local user → lands in /home/<user>
# vsftpd.conf: chroot_local_user=YES  (and allow_writeable_chroot=YES if the home is writable)
echo alice >> /etc/vsftpd/user_list      # with userlist_deny=YES → denied
# userlist_deny=NO → ONLY users in user_list may log in
`````

`setsebool -P ftpd_full_access on` is needed if local users must read/write outside normal locations (it's broad, so use it with care).

## 7. Custom Anonymous Root

`````bash
mkdir /ftp ; touch /ftp/{1..10}.txt
chown root:root /ftp ; chmod 755 /ftp                     # chroot root must not be writable by ftp
semanage fcontext -a -t public_content_t '/ftp(/.*)?' ; restorecon -Rv /ftp
# vsftpd.conf: anonymous_enable=YES  anon_root=/ftp
systemctl restart vsftpd
`````

Revert by removing `anon_root`, then `systemctl restart vsftpd` (and `semanage fcontext -d '/ftp(/.*)?'` if cleaning up).

## 8. Non-Standard Port

`````bash
# vsftpd.conf: listen_port=3434
semanage port -a -t ftp_port_t -p tcp 3434
firewall-cmd --permanent --add-port=3434/tcp ; firewall-cmd --reload
systemctl restart vsftpd
ftp localhost 3434
`````

Passive data connections on a non-standard control port aren't tracked by the ftp helper; define `pasv_min_port`/`pasv_max_port` and open that range.

## 9. Clients

`````bash
ftp 192.168.0.150             # commands: ls, cd, lcd, get, mget, put, mput, binary, bye
lftp -u alice 192.168.0.150
curl -O ftp://192.168.0.150/pub/calendar.txt
`````

Modern web browsers no longer support `ftp://`. Use a CLI or GUI client (e.g., FileZilla).

## 10. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `500 OOPS: vsftpd: refusing to run with writable root inside chroot()` | Writable chroot root | Make it non-writable, or `allow_writeable_chroot=YES` |
| `553 Could not create file` (anonymous) | Upload not enabled / dir perms / SELinux | §5 (`public_content_rw_t`, `ftpd_anon_write`) |
| vsftpd won't start on a custom port | No `ftp_port_t` label | `semanage port -a -t ftp_port_t …` |
| Login OK, `ls` hangs | Passive data ports blocked | `ftp` firewall service / pasv range open |
| `530 Login incorrect` for root | `ftpusers` | Intended; use a regular user |
| `530 Permission denied` | `user_list` rules | Check `userlist_deny` and the list |

## 11. Interview Questions

| Question | Answer |
|---|---|
| Active vs passive FTP? | Active: server connects back from port 20; passive: client opens the data connection to a server high port. |
| Why is FTP considered insecure? | Credentials and data travel in clear text; use SFTP/FTPS. |
| `ftpusers` vs `user_list`? | ftpusers always denies (PAM); user_list is a configurable allow/deny list. |
| SELinux types for shared content? | `public_content_t` (read), `public_content_rw_t` (write, with booleans). |

## 12. Quick Revision

`````bash
dnf install vsftpd ; systemctl enable --now vsftpd ; firewall ftp · /etc/vsftpd/{vsftpd.conf,ftpusers,user_list}
anonymous_enable · local_enable · write_enable · anon_upload_enable · anon_root · chroot_local_user · userlist_deny · listen_port
SELinux: public_content_t / public_content_rw_t · ftpd_anon_write · ftpd_full_access · ftp_port_t
`````

## 13. Cross-References

- [SELinux file contexts](../firewall-and-selinux/selinux-file-contexts.md)
- [SELinux booleans & ports](../firewall-and-selinux/selinux-booleans-ports-troubleshooting.md)
- [firewalld](../firewall-and-selinux/firewalld.md)
- [SSH (SFTP alternative)](../networking-and-ssh/ssh-remote-access.md)
