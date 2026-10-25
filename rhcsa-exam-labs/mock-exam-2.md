# RHCSA 10 Mock Exam 2 (Full Objective Coverage, with Grader)

> **Track:** **[RHCSA Core]** · Covers the objectives the [first sample exam](sample-exam-with-solutions.md) didn't test (sudo, IPv6, scripts with arguments, SELinux booleans and custom file contexts, NFS fstab mounts, journal persistence, `at`, default target, kernel arguments, password aging, collaboration directories, VFAT/ext4 labels, partition deletion, Flatpak).
> **Format:** two nodes, 2.5 hours target (the official page doesn't state a duration; train faster than you'll need). No internet except where a task says so; use `man`, `--help`, `/usr/share/doc`.
> **Grading:** run [`graders/mock2-server1.sh`](graders/mock2-server1.sh) and [`graders/mock2-server2.sh`](graders/mock2-server2.sh) **after a reboot** of each node.
> **Environment:** the two-VM lab from [practice lab setup](practice-lab-setup.md) (`server1` 192.168.56.10, `server2` 192.168.56.11), RHEL 10 DVD ISO attached to both, `server2` with two extra empty disks (`vdb` 10 GiB, `vdc` 2 GiB; `sdb`/`sdc` on VirtualBox). Adjust interface and disk names to your lab.

## 0. Lab Services Setup (run once, not graded)

On **server2** (it provides NFS and time to server1):

```bash
sudo -i
dnf install -y nfs-utils chrony
mkdir -p /exports/share /exports/homes/remuser1
echo "shared data" > /exports/share/README
useradd -u 3101 remuser1 ; chown remuser1: /exports/homes/remuser1
cat > /etc/exports.d/mock2.exports <<'EOF'
/exports/share  192.168.56.0/24(rw,sync)
/exports/homes  192.168.56.0/24(rw,sync)
EOF
systemctl enable --now nfs-server ; exportfs -arv
echo 'allow 192.168.56.0/24' >> /etc/chrony.conf ; echo 'local stratum 8' >> /etc/chrony.conf
systemctl restart chronyd
firewall-cmd --permanent --add-service={nfs,ntp} ; firewall-cmd --reload
parted -s /dev/vdc mklabel gpt mkpart old 1MiB 500MiB     # a partition you'll be asked to delete
```

On **server1**, create the directory-user equivalent of `remuser1` so autofs homes have a matching UID: `useradd -u 3101 remuser1`.

On **server1**, just before you start (for A19; processes don't survive reboots):

```bash
cp /usr/bin/yes /usr/local/bin/cpuhog ; cp "$(readlink -f /usr/bin/python3)" /usr/local/bin/memhog
nohup cpuhog > /dev/null 2>&1 &
nohup memhog -c 'import time; b = bytearray(300*1024*1024); time.sleep(10**6)' > /dev/null 2>&1 &
```

---

## Part A: server1

| # | Task |
|---|---|
| A1 | Configure the private interface persistently: keep IPv4 `192.168.56.10/24`; **add** IPv6 `fd00:56::10/64`. Set the hostname `server1.lab.example.com`. Make `server2.lab.example.com` (alias `server2`) resolve to `192.168.56.11` without DNS. |
| A2 | Mount the RHEL 10 DVD persistently at `/mnt/iso` and configure repositories with IDs `lab-baseos` and `lab-appstream` from it, with GPG checking enabled using `/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release`. |
| A3 | Create group `admins` (GID 3000). Create user `alex` (UID 2001, supplementary group `admins`) and user `sam` with **no interactive shell** whose **account** expires on 2027-12-31. Both passwords: `Lab@2026`. |
| A4 | `alex` must change his password every 60 days and be warned 10 days before. All users created **from now on** must change passwords every 90 days. |
| A5 | Members of `admins` may run any command as root **without a password**. User `oper` (create it) may run only `systemctl restart httpd` and `systemctl status httpd` as root. |
| A6 | Create `/srv/team`: group owner `admins`; owner and group full access; others none; new files automatically belong to `admins`; users can delete only their own files; new files inside must be readable and writable by group `admins` regardless of the creator's umask. |
| A7 | Files created by `alex` must default to mode `640` and directories to `750`. |
| A8 | Copy the lines of `/etc/services` that **begin** with `ssh` or `http` followed by whitespace to `/root/services.txt`, in their original order. Write the absolute paths of all **regular files** under `/usr/share/doc` larger than **100 KiB** and owned by root to `/root/bigdocs.txt`, sorted. |
| A9 | Create `/root/etc.tar.xz` (xz-compressed tar of `/etc`) and `/root/log.tar.bz2` (bzip2-compressed tar of `/var/log`). |
| A10 | Write `/usr/local/bin/userinfo`: for each username argument print `NAME: exists UID=<uid> SHELL=<shell>` or `NAME: missing`; exit 0 if all exist, 1 if any is missing; with no arguments print a usage message to stderr and exit 2. |
| A11 | Install Apache. Serve `/srv/web/index.html` containing exactly `mock2` on TCP port **8888** as the only listener, reachable from server2, starting at boot. Keep SELinux enforcing. |
| A12 | Allow Apache to make outbound network connections, persistently (SELinux). |
| A13 | Boot into the multi-user (text) target by default. Add the kernel argument `audit_backlog_limit=8192` to all installed kernels persistently. |
| A14 | Preserve the system journal across reboots. Create a systemd timer `diskreport.timer` that runs `/usr/local/bin/diskreport` (which appends `df -h` output to `/var/log/diskreport.log`) every 15 minutes, starting at boot. Schedule a one-time `at` job for root tomorrow at 09:00 running `logger mock2-at-job`. |
| A15 | Apply the tuned profile that tuned recommends for this system. |
| A16 | Use server2 as the **only** time source. |
| A17 | Mount `server2:/exports/share` persistently at `/mnt/share` (NFS). Configure autofs so that `/remote/homes/<user>` mounts `server2:/exports/homes/<user>` on access for any user. |
| A18 | *(Needs internet; skip offline.)* Add the Flathub remote **system-wide** as `flathub` and install `org.gnome.Calculator` system-wide. |
| A19 | *(Graded before reboot with `graders/mock2-processes.sh`.)* Identify the process using the most CPU and set its nice value to **15** without restarting it. Identify the process using the most memory and terminate it. |
| A20 | Copy `/exports/share/README` from server2 to `/root/README.server2` on server1 using an encrypted protocol. |
| A21 | User `alex` on server1 must be able to log in to `alex@server2` with SSH **keys**, without a password prompt. |
| A22 | Create a **hard link** `/root/hosts.hard` to `/etc/hosts` and a **symbolic link** `/root/fstab.link` pointing to `/etc/fstab`. |

## Part B: server2

| # | Task |
|---|---|
| B1 | *(Practice; reboot first.)* Reset the root password to `Root@2026` using the boot loader, with SELinux enforcing afterwards. |
| B2 | On `vdb` (empty, GPT): partition 1 GiB as **VFAT** with label `DOCS`, mounted at `/mnt/docs` **by label**; writable by user `alex`'s UID 2001 (create `alex` with UID 2001 and password `Lab@2026` on server2 too). |
| B3 | On `vdb`: add a 512 MiB swap partition, active at boot **by UUID**, without removing existing swap. |
| B4 | On `vdb`: a 4 GiB partition as an LVM PV; volume group `vgexam` with **8 MiB** extents; logical volume `lvdata` of **50 extents**, XFS, mounted at `/data` **by UUID**. Then extend `lvdata` to **600 MiB** (filesystem included). |
| B5 | In `vgexam`, create `lvlogs` (200 MiB, **ext4**, label `LOGS`) mounted at `/logs` **by label**. |
| B6 | Delete the existing partition on `vdc`. |

---

## Solutions

<details><summary>A1 Networking</summary>

```bash
nmcli -t -f NAME,DEVICE con show --active          # find the profile for the 192.168.56.10 interface, e.g. "System eth1"
nmcli con mod "System eth1" ipv6.method manual ipv6.addresses fd00:56::10/64 connection.autoconnect yes
nmcli con up "System eth1"
hostnamectl hostname server1.lab.example.com
echo '192.168.56.11 server2.lab.example.com server2' >> /etc/hosts
ip -6 -br addr ; getent hosts server2
```

</details>

<details><summary>A2 Repositories</summary>

```bash
mkdir -p /mnt/iso
echo '/dev/sr0 /mnt/iso iso9660 ro,nofail 0 0' >> /etc/fstab ; systemctl daemon-reload ; mount -a
cat > /etc/yum.repos.d/lab.repo <<'EOF'
[lab-baseos]
name=Lab BaseOS
baseurl=file:///mnt/iso/BaseOS
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release

[lab-appstream]
name=Lab AppStream
baseurl=file:///mnt/iso/AppStream
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
EOF
dnf clean all ; dnf repolist
```

</details>

<details><summary>A3–A4 Users, groups, aging</summary>

```bash
groupadd -g 3000 admins
useradd -u 2001 -G admins alex
useradd -s /sbin/nologin -e 2027-12-31 sam
for u in alex sam; do echo 'Lab@2026' | passwd --stdin "$u"; done
chage -M 60 -W 10 alex
sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS\t90/' /etc/login.defs
chage -l alex ; chage -l sam | grep 'Account expires' ; grep ^PASS_MAX_DAYS /etc/login.defs
```

</details>

<details><summary>A5 Privileged access</summary>

```bash
useradd oper
echo '%admins ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/admins
echo 'oper ALL=(root) /usr/bin/systemctl restart httpd, /usr/bin/systemctl status httpd' > /etc/sudoers.d/oper
chmod 0440 /etc/sudoers.d/admins /etc/sudoers.d/oper ; visudo -c
sudo -l -U oper
```

</details>

<details><summary>A6–A7 Collaboration directory & umask</summary>

```bash
mkdir -p /srv/team ; chgrp admins /srv/team ; chmod 3770 /srv/team      # SGID + sticky, rwxrws--T
setfacl -m d:g:admins:rwX /srv/team ; getfacl /srv/team
echo 'umask 027' >> /home/alex/.bashrc
su - alex -c 'umask; cd /tmp; touch f; mkdir d; ls -ld f d'           # -rw-r----- / drwxr-x---
```

</details>

<details><summary>A8–A9 Text processing & archives</summary>

```bash
grep -E '^(ssh|http)[[:space:]]' /etc/services > /root/services.txt
find /usr/share/doc -type f -size +100k -user root | sort > /root/bigdocs.txt
tar -cJf /root/etc.tar.xz /etc ; tar -cjf /root/log.tar.bz2 /var/log
file /root/etc.tar.xz /root/log.tar.bz2
```

`-size +100k` means "more than 100 KiB, rounded up to whole KiB" ([finding files](../files-and-text-processing/finding-files.md#21-tests)).

</details>

<details><summary>A10 Script</summary>

```bash
cat > /usr/local/bin/userinfo <<'EOF'
#!/bin/bash
if [ "$#" -eq 0 ]; then
    echo "Usage: $0 USER..." >&2
    exit 2
fi
rc=0
for u in "$@"; do
    if entry=$(getent passwd "$u"); then
        uid=$(echo "$entry" | cut -d: -f3)
        shell=$(echo "$entry" | cut -d: -f7)
        echo "$u: exists UID=$uid SHELL=$shell"
    else
        echo "$u: missing"
        rc=1
    fi
done
exit "$rc"
EOF
chmod 755 /usr/local/bin/userinfo
userinfo alex nobody-here ; echo $?        # alex: exists UID=2001 SHELL=/bin/bash / nobody-here: missing / 1
```

</details>

<details><summary>A11–A12 Apache, SELinux, firewall</summary>

```bash
dnf install -y httpd
mkdir -p /srv/web ; echo mock2 > /srv/web/index.html
semanage fcontext -a -t httpd_sys_content_t '/srv/web(/.*)?' ; restorecon -Rv /srv/web
sed -i 's/^Listen 80$/Listen 8888/' /etc/httpd/conf/httpd.conf
sed -i 's|^DocumentRoot "/var/www/html"|DocumentRoot "/srv/web"|' /etc/httpd/conf/httpd.conf
cat > /etc/httpd/conf.d/srvweb.conf <<'EOF'
<Directory "/srv/web">
    Require all granted
</Directory>
EOF
semanage port -l | grep -w 8888 || true                # already assigned to another type? then use -m instead of -a
semanage port -a -t http_port_t -p tcp 8888
firewall-cmd --permanent --add-port=8888/tcp ; firewall-cmd --reload
apachectl configtest && systemctl enable --now httpd
setsebool -P httpd_can_network_connect on
curl http://server1.lab.example.com:8888/            # mock2 (also from server2)
```

</details>

<details><summary>A13 Boot target & kernel argument</summary>

```bash
systemctl set-default multi-user.target
grubby --update-kernel=ALL --args="audit_backlog_limit=8192"
grubby --info=ALL | grep -E '^(kernel|args)'
```

</details>

<details><summary>A14 Journal, timer, at</summary>

```bash
mkdir -p /var/log/journal ; systemd-tmpfiles --create --prefix /var/log/journal ; systemctl restart systemd-journald
cat > /usr/local/bin/diskreport <<'EOF'
#!/bin/bash
df -h >> /var/log/diskreport.log
EOF
chmod 755 /usr/local/bin/diskreport
cat > /etc/systemd/system/diskreport.service <<'EOF'
[Unit]
Description=Disk usage report
[Service]
Type=oneshot
ExecStart=/usr/local/bin/diskreport
EOF
cat > /etc/systemd/system/diskreport.timer <<'EOF'
[Unit]
Description=Disk usage report every 15 minutes
[Timer]
OnCalendar=*:0/15
Persistent=true
[Install]
WantedBy=timers.target
EOF
systemctl daemon-reload ; systemctl enable --now diskreport.timer ; systemctl list-timers diskreport.timer
dnf install -y at ; systemctl enable --now atd
echo 'logger mock2-at-job' | at 09:00 tomorrow ; atq
```

</details>

<details><summary>A15–A16 tuned & chrony</summary>

```bash
systemctl enable --now tuned ; tuned-adm profile "$(tuned-adm recommend)" ; tuned-adm active
sed -i 's/^pool /#pool /' /etc/chrony.conf ; echo 'server server2.lab.example.com iburst' >> /etc/chrony.conf
systemctl enable chronyd ; systemctl restart chronyd ; chronyc sources -v
```

</details>

<details><summary>A17 NFS & autofs</summary>

```bash
dnf install -y nfs-utils autofs
mkdir -p /mnt/share
echo 'server2.lab.example.com:/exports/share /mnt/share nfs defaults,_netdev 0 0' >> /etc/fstab
systemctl daemon-reload ; mount -a ; df -hT /mnt/share
echo '/remote/homes /etc/auto.homes' > /etc/auto.master.d/homes.autofs
echo '* -rw,sync server2.lab.example.com:/exports/homes/&' > /etc/auto.homes
systemctl enable --now autofs ; systemctl restart autofs
ls /remote/homes/remuser1 ; findmnt /remote/homes/remuser1
```

</details>

<details><summary>A18 Flatpak</summary>

```bash
dnf install -y flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install -y flathub org.gnome.Calculator ; flatpak list --app
```

</details>

<details><summary>A19–A22 Processes, file transfer, SSH keys, links</summary>

```bash
ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -3        # cpuhog on top
renice -n 15 -p "$(pgrep -x cpuhog)" ; ps -o pid,ni,comm -C cpuhog
ps -eo pid,comm,%mem,rss --sort=-%mem | head -3         # memhog on top
kill "$(pgrep -x memhog)" ; pgrep -x memhog || echo gone  # SIGTERM first; -9 only if it survives

scp alex@server2:/exports/share/README /root/README.server2    # or: sftp / rsync -e ssh
# (any server2 account that can read the file works; root SSH login may be disabled)

su - alex
ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519      # (or with a passphrase + ssh-agent)
ssh-copy-id alex@server2                               # asks alex's server2 password once
ssh -o BatchMode=yes alex@server2 hostname             # no prompt → done
exit

ln /etc/hosts /root/hosts.hard ; ln -s /etc/fstab /root/fstab.link
ls -li /etc/hosts /root/hosts.hard ; ls -l /root/fstab.link     # same inode, link count 2 / l… -> /etc/fstab
```

</details>

<details><summary>B1 Root password</summary>

GRUB `e` → append `rd.break` → Ctrl+X → `mount -o remount,rw /sysroot ; chroot /sysroot ; passwd root ; touch /.autorelabel ; exit ; exit`. See [boot recovery §2](../boot-systemd-and-kernel/boot-recovery.md#2-reset-the-root-password-rhcsa-core).

</details>

<details><summary>B2–B6 Storage</summary>

```bash
useradd -u 2001 alex ; echo 'Lab@2026' | passwd --stdin alex
lsblk ; parted /dev/vdb unit MiB print free
parted -s /dev/vdb mklabel gpt
parted -s /dev/vdb mkpart docs fat32 1MiB 1025MiB
parted -s /dev/vdb mkpart swap2 linux-swap 1025MiB 1537MiB
parted -s /dev/vdb mkpart lvm 1537MiB 5633MiB ; parted -s /dev/vdb set 3 lvm on
udevadm settle ; lsblk /dev/vdb

# B2 VFAT by label, writable by UID 2001
mkfs.vfat -n DOCS /dev/vdb1 ; mkdir -p /mnt/docs
echo 'LABEL=DOCS /mnt/docs vfat defaults,uid=2001,gid=2001,umask=022 0 0' >> /etc/fstab

# B3 swap by UUID
mkswap /dev/vdb2
echo "UUID=$(blkid -s UUID -o value /dev/vdb2) none swap defaults 0 0" >> /etc/fstab

# B4 LVM with 8 MiB extents, 50 extents, XFS by UUID, then grow to 600 MiB
pvcreate /dev/vdb3 ; vgcreate -s 8M vgexam /dev/vdb3
lvcreate -n lvdata -l 50 vgexam ; mkfs.xfs /dev/vgexam/lvdata ; mkdir -p /data
echo "UUID=$(blkid -s UUID -o value /dev/vgexam/lvdata) /data xfs defaults 0 0" >> /etc/fstab

# B5 ext4 by label
lvcreate -n lvlogs -L 200M vgexam ; mkfs.ext4 -L LOGS /dev/vgexam/lvlogs ; mkdir -p /logs
echo 'LABEL=LOGS /logs ext4 defaults 0 2' >> /etc/fstab

systemctl daemon-reload ; mount -a ; swapon -a ; findmnt --verify
lvextend -r -L 600M /dev/vgexam/lvdata
df -hT /data /logs /mnt/docs ; swapon --show

# B6 delete the partition on vdc
parted /dev/vdc print ; parted -s /dev/vdc rm 1 ; lsblk /dev/vdc
```

</details>

## Grading

```bash
sudo bash graders/mock2-processes.sh   # on server1, BEFORE rebooting (A19 only)
# reboot both nodes, then:
sudo bash graders/mock2-server1.sh      # on server1
sudo bash graders/mock2-server2.sh      # on server2  (VirtualBox: bash graders/mock2-server2.sh /dev/sdb /dev/sdc)
```

Each check prints `PASS`/`FAIL` with what it looked at; the summary gives a score. A task only counts if it survived the reboot.

## Cross-References

- [Objectives map](exam-objectives-map.md) · [Coverage checklist](../COVERAGE.md) · [Mock exam 3 (break-fix)](mock-exam-3.md)
- Every task links back to its note through the [objectives map](exam-objectives-map.md)
