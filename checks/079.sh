TITLE="NFS and autofs"
STEP_1="The exports (run on server2)"
step_1() {
  if ! grep -qs /srv/nfs /etc/exports /etc/exports.d/*.exports; then manual "Run this step on server2, where /etc/exports lives."; return; fi
  check_match "/srv/nfs/public is exported read-only" "/srv/nfs/public *(ro,sync)" "/srv/nfs/public .*ro" exportfs -v
  check_match "/srv/nfs/private is exported read-write to server1" "/srv/nfs/private 192.168.56.10(rw,sync)" "/srv/nfs/private\s+192\.168\.56\.10.*rw" exportfs -v
  check "nfs-server is enabled" "sudo systemctl enable --now nfs-server" unit_enabled nfs-server
  check_match "the firewall allows nfs" "sudo firewall-cmd --permanent --add-service=nfs && sudo firewall-cmd --reload" "\bnfs\b" firewall-cmd --list-services
}
STEP_2="fstab with _netdev,nofail"
step_2() {
  local e; e=$(grep -Ev '^\s*#' /etc/fstab | awk '$3 ~ /^nfs/')
  [ -z "$e" ] && systemctl is-active --quiet autofs && { manual "You replaced the fstab entry with autofs in step 3; that's fine."; return; }
  check "fstab has an NFS entry" "server2:/srv/nfs/private /mnt/private nfs defaults,_netdev,nofail 0 0" test -n "$e"
  check "it uses _netdev and nofail" "Add _netdev,nofail to its options" bash -c "grep -Ev '^\s*#' /etc/fstab | awk '\$3 ~ /^nfs/' | grep -q _netdev && grep -Ev '^\s*#' /etc/fstab | awk '\$3 ~ /^nfs/' | grep -q nofail"
}
STEP_3="autofs"
step_3() {
  check "autofs is enabled and running" "sudo dnf install -y autofs && sudo systemctl enable --now autofs" bash -c 'systemctl is-enabled --quiet autofs && systemctl is-active --quiet autofs'
  check "a master map in /etc/auto.master.d/ uses --timeout=30" "/mnt/nfs /etc/auto.nfs --timeout=30 in /etc/auto.master.d/nfs.autofs" bash -c 'grep -qsE "timeout[= ]30" /etc/auto.master.d/*.autofs'
}
STEP_4="root_squash"
step_4() {
  quiz "Who owned the file root created on the share, as seen on server2?" "nobody" "root_squash maps the client's root to nobody (UID 65534)."
}
STEP_5="A dead server"
step_5() { manual "ls and df hung on the dead hard mount, and recovered when nfs-server came back."; }
