#!/usr/bin/env bash
# Grader for RHCSA mock exam 2, server1. Run as root AFTER a reboot:  bash mock2-server1.sh
# Read-only: it inspects state and never changes the system.
set -u
pass=0 fail=0
ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); }
check() { local desc=$1; shift; if "$@" >/dev/null 2>&1; then ok "$desc"; else bad "$desc"; fi; }
section() { printf '\n== %s\n' "$1"; }

[[ $EUID -eq 0 ]] || { echo "Run as root." >&2; exit 2; }

section "A1 networking"
check "IPv4 192.168.56.10/24 configured"           bash -c "ip -4 -o addr | grep -q '192.168.56.10/24'"
check "IPv6 fd00:56::10/64 configured"             bash -c "ip -6 -o addr | grep -q 'fd00:56::10/64'"
check "IPv6 set in a NetworkManager profile"       bash -c "grep -rqs 'fd00:56::10/64' /etc/NetworkManager/system-connections/"
check "hostname is server1.lab.example.com"        test "$(hostnamectl hostname 2>/dev/null || hostname)" = server1.lab.example.com
check "server2 resolves to 192.168.56.11"          bash -c "getent hosts server2 | grep -q '^192.168.56.11'"
check "server2.lab.example.com resolves"           bash -c "getent hosts server2.lab.example.com | grep -q '^192.168.56.11'"

section "A2 repositories"
check "/mnt/iso in fstab"                          bash -c "awk '\$2==\"/mnt/iso\"' /etc/fstab | grep -q ."
check "/mnt/iso mounted"                           findmnt /mnt/iso
check "repo lab-baseos enabled"                    bash -c "dnf -q repolist --enabled 2>/dev/null | grep -qw lab-baseos"
check "repo lab-appstream enabled"                 bash -c "dnf -q repolist --enabled 2>/dev/null | grep -qw lab-appstream"
check "gpgcheck=1 in lab repos"                    bash -c "grep -hA6 '^\[lab-' /etc/yum.repos.d/*.repo | grep -q '^gpgcheck *= *1'"

section "A3-A4 users, groups, aging"
check "group admins has GID 3000"                  bash -c "getent group admins | cut -d: -f3 | grep -qx 3000"
check "alex has UID 2001"                          bash -c "id -u alex | grep -qx 2001"
check "alex is in admins"                          bash -c "id -nG alex | tr ' ' '\n' | grep -qx admins"
check "sam has a non-interactive shell"            bash -c "getent passwd sam | cut -d: -f7 | grep -Eq '/(sbin/nologin|bin/false)$'"
check "sam account expires 2027-12-31"             bash -c "chage -l sam | grep 'Account expires' | grep -q 'Dec 31, 2027'"
check "alex max password age 60"                   bash -c "chage -l alex | grep 'Maximum number' | grep -q ': 60$'"
check "alex warning 10 days"                       bash -c "chage -l alex | grep 'warning' | grep -q ': 10$'"
check "PASS_MAX_DAYS 90 for new users"             bash -c "awk '\$1==\"PASS_MAX_DAYS\"{print \$2}' /etc/login.defs | grep -qx 90"
check "alex and sam have passwords set"            bash -c "for u in alex sam; do passwd -S \$u | grep -Eq ' PS? ' || exit 1; done"   # RHEL 10: P, RHEL 9: PS

section "A5 privileged access"
check "sudoers syntax valid"                       visudo -c
check "admins: NOPASSWD ALL"                       bash -c "sudo -l -U alex | grep -q 'NOPASSWD: ALL'"
check "oper may restart httpd"                     bash -c "sudo -l -U oper | grep -q '/usr/bin/systemctl restart httpd'"
check "oper may NOT run arbitrary commands"        bash -c "! sudo -l -U oper | grep -Eq '\) (NOPASSWD: )?ALL$'"

section "A6-A7 collaboration directory, umask"
check "/srv/team group is admins"                  bash -c "stat -c %G /srv/team | grep -qx admins"
check "/srv/team mode 3770"                        bash -c "stat -c %a /srv/team | grep -qx 3770"
check "/srv/team default ACL g:admins rw"          bash -c "getfacl -p /srv/team 2>/dev/null | grep -Eq '^default:group:admins:rw'"
check "alex umask 027 at login"                    bash -c "su - alex -c umask | grep -qx 0027"

section "A8-A9 text processing, archives"
check "/root/services.txt correct"                 bash -c "diff -q <(grep -E '^(ssh|http)[[:space:]]' /etc/services) /root/services.txt"
check "/root/bigdocs.txt correct"                  bash -c "diff -q <(find /usr/share/doc -type f -size +100k -user root | sort) /root/bigdocs.txt"
check "/root/etc.tar.xz is xz"                     bash -c "file /root/etc.tar.xz | grep -qi 'XZ compressed'"
check "/root/etc.tar.xz contains etc/passwd"       bash -c "tar -tJf /root/etc.tar.xz | grep -qx 'etc/passwd'"
check "/root/log.tar.bz2 is bzip2"                 bash -c "file /root/log.tar.bz2 | grep -qi 'bzip2 compressed'"

section "A10 script"
check "userinfo is executable"                     test -x /usr/local/bin/userinfo
check "no args -> exit 2"                          bash -c "/usr/local/bin/userinfo >/dev/null 2>&1; test \$? -eq 2"
check "no args -> message on stderr only"          bash -c "test -z \"\$(/usr/local/bin/userinfo 2>/dev/null)\""
check "existing user output format"                bash -c "/usr/local/bin/userinfo root | grep -qx 'root: exists UID=0 SHELL=/bin/bash'"
check "missing user -> 'missing' and exit 1"       bash -c "out=\$(/usr/local/bin/userinfo root no_such_user_x); rc=\$?; test \$rc -eq 1 && echo \"\$out\" | grep -qx 'no_such_user_x: missing'"

section "A11-A12 web, SELinux"
check "httpd enabled"                              systemctl is-enabled httpd
check "httpd active"                               systemctl is-active httpd
check "listening on 8888"                          bash -c "ss -Htln 'sport = :8888' | grep -q ."
check "not listening on 80"                        bash -c "! ss -Htln 'sport = :80' | grep -q ."
check "content served is 'mock2'"                  bash -c "curl -s http://127.0.0.1:8888/ | grep -qx mock2"
check "8888 labeled http_port_t"                   bash -c "semanage port -l | awk '\$1==\"http_port_t\"' | grep -qw 8888"
check "/srv/web fcontext rule"                     bash -c "semanage fcontext -l -C | grep -q '^/srv/web'"
check "/srv/web/index.html labeled"                bash -c "ls -Z /srv/web/index.html | grep -q httpd_sys_content_t"
check "firewall allows 8888/tcp"                   bash -c "firewall-cmd --list-ports | grep -qw 8888/tcp"
check "httpd_can_network_connect on (persistent)"  bash -c "semanage boolean -l -C | grep -E '^httpd_can_network_connect ' | grep -q '(on *, *on)'"
check "SELinux enforcing"                          bash -c "getenforce | grep -qx Enforcing"

section "A13 boot"
check "default target multi-user"                  bash -c "systemctl get-default | grep -qx multi-user.target"
check "kernel arg on all kernels"                  bash -c "a=\$(grubby --info=ALL 2>/dev/null | grep '^args'); test -n \"\$a\" && ! echo \"\$a\" | grep -qv 'audit_backlog_limit=8192'"
check "kernel arg active now"                      bash -c "grep -qw 'audit_backlog_limit=8192' /proc/cmdline"

section "A14 journal, timer, at"
check "persistent journal directory"               test -d /var/log/journal
check "more than one boot recorded"                bash -c "test \$(journalctl --list-boots 2>/dev/null | wc -l) -ge 2"
check "diskreport.timer enabled"                   systemctl is-enabled diskreport.timer
check "diskreport.timer active"                    systemctl is-active diskreport.timer
check "timer schedule every 15 min"                bash -c "systemctl cat diskreport.timer | grep -Eq '^OnCalendar=.*(0/15|00/15|\*:00,15,30,45)'"
check "/usr/local/bin/diskreport executable"       test -x /usr/local/bin/diskreport
check "at job queued for root"                     bash -c "atq | grep -q root"

section "A15-A16 tuned, chrony"
check "recommended tuned profile active"           bash -c "tuned-adm active | grep -q \"\$(tuned-adm recommend)\""
check "chrony uses server2"                        bash -c "grep -Eq '^(server|pool) +server2(\.lab\.example\.com)?( |$)' /etc/chrony.conf"
check "no other active pool/server lines"          bash -c "! grep -E '^(server|pool) ' /etc/chrony.conf | grep -vq server2"
check "chronyd enabled"                            systemctl is-enabled chronyd

section "A17 NFS, autofs"
check "/mnt/share NFS in fstab"                    bash -c "awk '\$2==\"/mnt/share\" && \$3 ~ /^nfs/' /etc/fstab | grep -q ."
check "/mnt/share mounted"                         bash -c "findmnt -t nfs,nfs4 /mnt/share"
check "autofs enabled"                             systemctl is-enabled autofs
check "autofs wildcard home mounts"                bash -c "ls /remote/homes/remuser1 >/dev/null && findmnt /remote/homes/remuser1"

section "A20-A21 file transfer, SSH keys"
check "/root/README.server2 copied"                bash -c "grep -qx 'shared data' /root/README.server2"
check "alex has an SSH key pair"                   bash -c "ls /home/alex/.ssh/id_* 2>/dev/null | grep -q '\.pub$'"
check "alex -> alex@server2 without password"      su - alex -c 'ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new alex@server2 true'

section "A22 links"
check "/root/hosts.hard is a hard link to /etc/hosts" bash -c "test \"\$(stat -c %i /etc/hosts)\" = \"\$(stat -c %i /root/hosts.hard)\""
check "/root/fstab.link -> /etc/fstab (symlink)"      bash -c "test -L /root/fstab.link && test \"\$(readlink -f /root/fstab.link)\" = /etc/fstab"

section "A18 Flatpak (optional)"
if command -v flatpak >/dev/null; then
  check "flathub remote (system)"                  bash -c "flatpak remotes --system | grep -qw flathub"
  check "Calculator installed system-wide"         bash -c "flatpak list --system --app | grep -q org.gnome.Calculator"
else
  printf '  SKIP  flatpak not installed\n'
fi

printf '\nScore: %d passed, %d failed (%d%%)\n' "$pass" "$fail" $(( 100 * pass / (pass + fail) ))
[[ $fail -eq 0 ]]
