#!/usr/bin/env bash
# Grader for RHCSA mock exam 3 (break-fix). Run as root after your final reboot. Read-only.
set -u
pass=0 fail=0
ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); }
check() { local desc=$1; shift; if "$@" >/dev/null 2>&1; then ok "$desc"; else bad "$desc"; fi; }
section() { printf '\n== %s\n' "$1"; }
[[ $EUID -eq 0 ]] || { echo "Run as root." >&2; exit 2; }

section "1 boot & access"
check "default target is multi-user"           bash -c "systemctl get-default | grep -qx multi-user.target"
check "fstab is consistent"                     findmnt --verify
check "no bogus /archive entry left active"     bash -c "! grep -Eq '^[^#]*00000000-1111-2222-3333-444444444444' /etc/fstab"
check "system not in maintenance/emergency"     bash -c "systemctl is-system-running | grep -Eqx 'running|degraded'"
check "root password was reset"                 bash -c "test -f /root/.mock3-oldroot && test \"\$(getent shadow root | cut -d: -f2 | sha256sum | cut -d' ' -f1)\" != \"\$(cat /root/.mock3-oldroot)\""
check "root account not locked"                 bash -c "getent shadow root | cut -d: -f2 | grep -q '^\\\$'"

section "2 web server on 8085"
check "httpd enabled"                           systemctl is-enabled httpd
check "httpd active"                            systemctl is-active httpd
check "listening on 8085"                       bash -c "ss -Htln 'sport = :8085' | grep -q ."
check "serves 'mock3'"                          bash -c "curl -s http://127.0.0.1:8085/ | grep -qx mock3"
check "index.html labeled httpd_sys_content_t"  bash -c "ls -Z /var/www/html/index.html | grep -q httpd_sys_content_t"
check "8085 labeled http_port_t"                bash -c "semanage port -l | awk '\$1==\"http_port_t\"' | grep -qw 8085"
check "firewall allows 8085/tcp (permanent)"    bash -c "firewall-cmd --permanent --list-ports | grep -qw 8085/tcp"
check "SELinux enforcing"                       bash -c "getenforce | grep -qx Enforcing"

section "3 sudo for ops"
check "sudoers valid"                           visudo -c
check "opsuser may run any command via sudo"    bash -c "sudo -l -U opsuser | grep -Eq '\(ALL( : ALL)?\) ALL'"

section "4 user deploy"
check "deploy has an interactive shell"         bash -c "getent passwd deploy | cut -d: -f7 | grep -qx /bin/bash"
check "deploy password unlocked"                bash -c "passwd -S deploy | grep -Eq ' PS? '"

section "5 journal persistence"
check "/var/log/journal exists"                 test -d /var/log/journal
check "no volatile Storage override"            bash -c "! systemd-analyze cat-config systemd/journald.conf 2>/dev/null | grep -Eiq '^Storage=volatile'"
check "journal is on disk"                      bash -c "journalctl --header 2>/dev/null | grep -q '/var/log/journal'"

section "6 time & tuning"
check "chronyd enabled"                         systemctl is-enabled chronyd
check "chronyd active"                          systemctl is-active chronyd
check "tuned enabled"                           systemctl is-enabled tuned
check "recommended tuned profile active"        bash -c "tuned-adm active | grep -q \"\$(tuned-adm recommend)\""

section "7 reports permissions"
check "ana can list /srv/reports"               su - ana -c 'ls /srv/reports'
check "ana can read q3.txt"                     su - ana -c 'cat /srv/reports/q3.txt'
check "others cannot read q3.txt"               bash -c "! su - opsuser -c 'cat /srv/reports/q3.txt'"

printf '\nScore: %d passed, %d failed (%d%%)\n' "$pass" "$fail" $(( 100 * pass / (pass + fail) ))
[[ $fail -eq 0 ]]
