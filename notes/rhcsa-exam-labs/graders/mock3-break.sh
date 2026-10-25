#!/usr/bin/env bash
# RHCSA mock exam 3: deliberately BREAKS this machine for break-fix practice.
# Use ONLY on a disposable lab VM with a snapshot. It changes the root password to a random value,
# corrupts /etc/fstab, changes the boot target, and misconfigures several services.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run as root." >&2; exit 2; }
[[ -f /etc/rhcsa-lab-ok ]] || { echo "Refusing: this is not marked as a lab VM. Snapshot it, then: touch /etc/rhcsa-lab-ok" >&2; exit 2; }
read -rp "This will break $(hostname). Type BREAK to continue: " answer
[[ $answer == BREAK ]] || { echo "Aborted."; exit 1; }

dnf -y -q install httpd chrony tuned firewalld policycoreutils-python-utils
systemctl enable --now firewalld 2>/dev/null || true

# Fault A: web server (content label, port label, firewall)
echo "mock3" > /var/www/html/index.html
sed -i 's/^Listen .*/Listen 8085/' /etc/httpd/conf/httpd.conf
chcon -t user_home_t /var/www/html/index.html 2>/dev/null || true
firewall-cmd -q --permanent --remove-service=http 2>/dev/null || true
firewall-cmd -q --reload 2>/dev/null || true
systemctl enable httpd 2>/dev/null

# Fault B: sudo for group ops is silently ignored
groupadd -f ops
id opsuser &>/dev/null || useradd -G ops opsuser
echo 'Ops@2026' | passwd --stdin opsuser >/dev/null
echo '%ops ALL=(ALL) ALL' > /etc/sudoers.d/ops.conf
chmod 0440 /etc/sudoers.d/ops.conf

# Fault C: user deploy can't log in
id deploy &>/dev/null || useradd deploy
echo 'Deploy@2026' | passwd --stdin deploy >/dev/null
usermod -s /sbin/nologin -L deploy

# Fault D: journal is volatile
mkdir -p /etc/systemd/journald.conf.d
printf '[Journal]\nStorage=volatile\n' > /etc/systemd/journald.conf.d/50-lab.conf
rm -rf /var/log/journal

# Fault E: no time synchronization, no tuning
systemctl disable --now chronyd 2>/dev/null || true
tuned-adm off 2>/dev/null || true
systemctl disable --now tuned 2>/dev/null || true

# Fault F: analysts can't read their reports
groupadd -f analysts
id ana &>/dev/null || useradd -G analysts ana
mkdir -p /srv/reports
echo "q3 numbers" > /srv/reports/q3.txt
chown -R root:analysts /srv/reports
chmod 0700 /srv/reports ; chmod 0600 /srv/reports/q3.txt

# Fault G: boot (broken fstab, wrong default target, unknown root password)
echo 'UUID=00000000-1111-2222-3333-444444444444 /archive xfs defaults 0 0' >> /etc/fstab
systemctl set-default rescue.target >/dev/null
echo "root:$(head -c 24 /dev/urandom | base64)" | chpasswd
getent shadow root | cut -d: -f2 | sha256sum | cut -d' ' -f1 > /root/.mock3-oldroot   # fingerprint of the random password

echo "Broken. Reboot now and start the exam: see rhcsa-exam-labs/mock-exam-3.md"
