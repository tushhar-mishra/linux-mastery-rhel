# RHCSA 10 Sample Exam: Corrected Solutions & Verification

> Practice exam covering many **[RHCSA Core]** objectives
> **Related:** [Objectives map](exam-objectives-map.md) · [Practice lab setup](practice-lab-setup.md) · [Exam strategy](../linux-fundamentals/rhcsa-exam-and-certification.md) · [Mock exam 2](mock-exam-2.md) · [Mock exam 3 (break-fix)](mock-exam-3.md) · [Coverage](../../docs/coverage.md)

## 0. Ground Rules (as in the real exam)

- Work on the assigned node; read every task completely (names, sizes, paths, users are exact).
- **Everything must survive a reboot.** Reboot near the end and re-verify.
- Leave SELinux enforcing and firewalld running.
- Check the official EX200 page for current duration, scoring and rules; scores and passing thresholds can change.

## Node 1

### 1. Static networking and hostname

IP 192.168.56.50/24, gateway 192.168.56.1, DNS 192.168.56.1, domain training.lab, hostname nodeA.training.lab.

```bash
nmcli con show                                     # find the profile for the interface (e.g. ens160)
nmcli con mod ens160 ipv4.addresses 192.168.56.50/24 ipv4.gateway 192.168.56.1 \
      ipv4.dns 192.168.56.1 ipv4.dns-search training.lab ipv4.method manual connection.autoconnect yes
nmcli con up ens160
hostnamectl hostname nodeA.training.lab
# verify
ip -br a ; ip route ; cat /etc/resolv.conf ; hostname
```

### 2. Local repositories

```bash
cat > /etc/yum.repos.d/local.repo <<'EOF'
[OSBase]
name=OS Base
baseurl=file:///mnt/OSBase
enabled=1
gpgcheck=0

[StreamApps]
name=App Stream
baseurl=file:///mnt/StreamApps
enabled=1
gpgcheck=0
EOF
dnf clean all ; dnf repolist          # both enabled
```

Use `gpgcheck=1` + `gpgkey=` if a key is provided.

### 3. Apache on port 8082 (SELinux + firewall)

```bash
dnf install -y httpd
sed -i 's/^Listen 80$/Listen 8082/' /etc/httpd/conf/httpd.conf
semanage port -a -t http_port_t -p tcp 8082          # (-m if 8082 already has another type)
firewall-cmd --permanent --add-port=8082/tcp ; firewall-cmd --reload
restorecon -Rv /var/www/html
systemctl enable --now httpd ; systemctl restart httpd
curl http://192.168.56.50:8082/                      # (from another host too)
```

### 4. Users and groups

```bash
groupadd opsmgrs
useradd -G opsmgrs adam ; useradd -G opsmgrs linda
useradd -s /sbin/nologin steve
for u in adam linda steve; do echo 'Train@123' | passwd --stdin "$u"; done
id adam ; id linda ; getent passwd steve           # verify groups and shell
```

### 5. autofs for a remote home

```bash
dnf install -y autofs nfs-utils
echo '/rhome  /etc/auto.rhome' > /etc/auto.master.d/rhome.autofs
echo '*  -rw,sync  192.168.56.80:/export/rhome/&' > /etc/auto.rhome      # wildcard serves any user
systemctl enable --now autofs ; systemctl restart autofs
su - remuser21 -c pwd          # → /rhome/remuser21 (user must exist with matching UID, e.g. from LDAP)
```

A single-user map line (`remuser21 -rw,sync 192.168.56.80:/export/rhome/remuser21`) is also valid.

### 6. Cron job for adam

```bash
crontab -e -u adam    →   30 12 * * * /bin/echo "sample text"
crontab -l -u adam
```

### 7. NTP client

```bash
vi /etc/chrony.conf        # comment out "pool …"; add:  server time.training.lab iburst
systemctl enable chronyd ; systemctl restart chronyd     # restart is required to load the change
chronyc sources -v         # ^* time.training.lab (after a short time)
```

### 8. Find files owned by steve

```bash
mkdir -p /root/found.steve
find / -user steve -type f -exec cp -a {} /root/found.steve/ \; 2>/dev/null
ls -l /root/found.steve
```

### 9. Lines containing "Listen"

```bash
grep Listen /etc/httpd/conf/httpd.conf > /root/apache_listens      # exactly as asked (no -n/-i unless requested)
cat /root/apache_listens
```

### 10. User with a specific UID

```bash
useradd -u 3456 roger ; echo 'Train@456' | passwd --stdin roger ; id roger
```

### 11. tar backup

```bash
tar -czf /root/localbackup.tar.gz /opt/localdata ; tar -tzf /root/localbackup.tar.gz | head ; file /root/localbackup.tar.gz
```

### 12. umask for adam (files 400, dirs 500)

```bash
echo 'umask 277' >> /home/adam/.bashrc
su - adam -c 'umask; touch f; mkdir d; ls -ld f d'     # -r-------- f ; dr-x------ d
```

umask math: `666 AND NOT 277 = 400`, `777 AND NOT 277 = 500`.

### 13. systemd timer (every minute)

```bash
mkdir -p /root/logs
cat > /usr/local/bin/event_logger <<'EOF'
#!/bin/bash
ls -l /tmp > /root/logs/events.trc
EOF
chmod +x /usr/local/bin/event_logger

cat > /etc/systemd/system/event_logger.service <<'EOF'
[Unit]
Description=Event Logger

[Service]
Type=oneshot
ExecStart=/usr/local/bin/event_logger
EOF

cat > /etc/systemd/system/event_logger.timer <<'EOF'
[Unit]
Description=Run event_logger every minute

[Timer]
OnCalendar=*-*-* *:*:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now event_logger.timer
systemctl list-timers event_logger.timer ; sleep 65 ; cat /root/logs/events.trc
```

## Node 2

### 1. Reset the root password

```text
GRUB → e → append rd.break to the linux line → Ctrl+X
mount -o remount,rw /sysroot ; chroot /sysroot ; passwd root (TrainRoot@999) ; touch /.autorelabel ; exit ; exit
```

### 2. Repositories

Same as Node 1 with `file:///mnt/BaseOSRepo` and `file:///mnt/AppRepo`.

### 3. 800 MiB swap on /dev/sdb (non-destructive)

```bash
lsblk /dev/sdb ; parted /dev/sdb unit MiB print free   # existing partitions? where is the free space?
# Empty, unlabeled disk only:   parted -s /dev/sdb mklabel gpt
# Create the partition IN THE FREE SPACE shown above (START = end of the last partition, or 1MiB on an empty disk):
parted -s /dev/sdb mkpart swap1 linux-swap STARTMiB $((START+800))MiB
udevadm settle ; lsblk /dev/sdb                      # note the NEW partition's name (sdb1 only if the disk was empty)
NEW=/dev/sdbN                                        # ← the partition you just created, never an existing one
mkswap "$NEW"
echo "UUID=$(blkid -s UUID -o value "$NEW") none swap defaults 0 0" >> /etc/fstab
swapon -a ; swapon --show                            # new area listed, existing swap still listed
```

### 4. Resize LV to 300 MiB

```bash
lvs vgdata ; df -hT | grep lvstore           # current size, free extents, and filesystem type
# Smaller than 300 MiB (any FS):  grow LV + filesystem in one step
lvextend -r -L 300M /dev/vgdata/lvstore
# Larger than 300 MiB and ext4:   shrink filesystem first, then LV (-r does both, in the right order)
#   umount /mnt/lvstore ; lvreduce -r -L 300M /dev/vgdata/lvstore ; mount -a
# Larger than 300 MiB and XFS:    impossible in place (XFS never shrinks): back up, recreate, restore
df -hT | grep lvstore ; lvs vgdata           # verify; extent rounding may give e.g. 304 MiB — fine if the task gives a range
```

### 5. Flatpak remote and app for student

```bash
su - student        # (or log in as student via SSH)
flatpak remote-add --user --if-not-exists flattrain https://dl.flathub.org/repo/flathub.flatpakrepo   # URL given in the task
flatpak install --user -y flattrain com.vscodium.codium
flatpak list --user --app
```

### 6. LV testqa (60 extents × 16 MiB, ext3, persistent)

```bash
pvcreate /dev/sdc
vgcreate -s 16M qavg /dev/sdc
lvcreate -l 60 -n testqa qavg                     # 960 MiB
mkfs.ext3 /dev/qavg/testqa
mkdir -p /mnt/testqa
echo "UUID=$(blkid -s UUID -o value /dev/qavg/testqa) /mnt/testqa ext3 defaults 0 2" >> /etc/fstab
systemctl daemon-reload ; mount -a ; df -hT /mnt/testqa
vgdisplay qavg | grep 'PE Size' ; lvs qavg
```

### 7. Recommended tuned profile

```bash
dnf install -y tuned ; systemctl enable --now tuned
tuned-adm recommend ; tuned-adm profile "$(tuned-adm recommend)" ; tuned-adm active
```

## Final Verification Checklist

```bash
reboot
# then:
ip -br a ; hostname ; dnf repolist ; curl http://localhost:8082 ; id adam linda steve roger
crontab -l -u adam ; chronyc sources ; systemctl list-timers event_logger.timer
swapon --show ; findmnt /mnt/testqa ; lvs ; tuned-adm active ; getenforce ; firewall-cmd --list-all
```
