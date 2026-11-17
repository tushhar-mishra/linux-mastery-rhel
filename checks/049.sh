TITLE="LVM"
STEP_1="vgdata and its LVs"
step_1() {
  check "VG vgdata exists" "sudo vgcreate vgdata DISK1 DISK2" vgs vgdata
  check "vgdata has two PVs" "Create it from two disks or partitions" test "$(vgs --noheadings -o pv_count vgdata 2>/dev/null | tr -d ' ')" = 2
  check "lvweb is XFS, mounted on /web" "mkfs.xfs /dev/vgdata/lvweb; mkdir /web; fstab by UUID; mount -a" test "$(fs_type /web)" = xfs
  check "/web is in fstab by UUID=" "echo \"UUID=\$(blkid -s UUID -o value /dev/vgdata/lvweb) /web xfs defaults 0 0\" | sudo tee -a /etc/fstab" bash -c '[[ "$(grep -Ev "^\s*(#|$)" /etc/fstab | awk "\$2==\"/web\"{print \$1}")" == UUID=* ]]'
  check "lvdb (400 MiB) is ext4" "sudo lvcreate -n lvdb -l 100 vgdata; sudo mkfs.ext4 /dev/vgdata/lvdb" test "$(blkid -o value -s TYPE /dev/vgdata/lvdb 2>/dev/null)" = ext4
}
STEP_2="Growing online"
step_2() {
  check "lvweb is now at least 1.4 GiB (lvextend -r -L +500M)" "sudo lvextend -r -L +500M /dev/vgdata/lvweb" bash -c '[ "$(lvs --noheadings --units m --nosuffix -o lv_size vgdata/lvweb 2>/dev/null | cut -d. -f1 | tr -d " ")" -ge 1400 ]'
  check "the filesystem grew too (df shows it)" "Use -r, or run xfs_growfs /web" bash -c '[ "$(df -m --output=size /web | tail -1 | tr -d " ")" -ge 1300 ]'
}
STEP_3="Extent size"
step_3() {
  quiz "What size is an LV of -l 20 in a VG made with -s 16M?" "^\s*320\s*(m|mib|mb)?\s*$" "20 extents × 16 MiB = 320 MiB."
}
STEP_4="Teardown"
step_4() {
  check "vgdata is gone" "umount → fstab → lvremove → vgremove → pvremove" not vgs vgdata
  check "/web and /db are no longer in fstab" "Remove their lines from /etc/fstab, then systemctl daemon-reload" bash -c '! grep -Ev "^\s*(#|$)" /etc/fstab | awk "{print \$2}" | grep -qxE "/web|/db"'
  check "findmnt --verify finds no errors" "Check /etc/fstab for leftovers" findmnt --verify
}
