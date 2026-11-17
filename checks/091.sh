TITLE="Stratis"
STEP_1="Pool, filesystem, fstab"
step_1() {
  check "a Stratis pool exists" "sudo stratis pool create pool1 /dev/vdb" bash -c 'stratis pool list 2>/dev/null | awk "NR>1" | grep -q .'
  check "a Stratis filesystem is mounted" "sudo stratis filesystem create pool1 fs1; mount /dev/stratis/pool1/fs1 /stratis" bash -c 'findmnt -rno SOURCE | grep -q "^/dev/mapper/stratis"'
  check "fstab waits for stratis-fstab-setup@POOL-UUID" "x-systemd.requires=stratis-fstab-setup@UUID.service,x-systemd.after=stratis-fstab-setup@UUID.service" grep -q 'x-systemd.after=stratis-fstab-setup@' /etc/fstab
  check "fstab doesn't use the old stratisd.service dependency" "Remove x-systemd.requires=stratisd.service" not grep -q 'x-systemd.requires=stratisd.service' /etc/fstab
}
STEP_2="The ordering cycle"
step_2() {
  check "this boot had no systemd ordering cycle" "Fix fstab as in step 1 and reboot" not bash -c 'journalctl -b --no-pager -q 2>/dev/null | grep -qi "ordering cycle"'
}
STEP_3="Snapshot restore"
step_3() {
  quiz "Which command made the snapshot?" "stratis\s+(filesystem|fs)\s+snapshot" "stratis filesystem snapshot POOL FS SNAPNAME"
}
STEP_4="add-data"
step_4() {
  check "a pool has at least two data devices" "sudo stratis pool add-data pool1 /dev/vdc" bash -c '[ "$(stratis blockdev list 2>/dev/null | grep -ciw data)" -ge 2 ]'
}
