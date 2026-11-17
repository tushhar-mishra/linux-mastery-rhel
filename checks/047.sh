TITLE="Filesystems"
STEP_1="XFS, ext4 and VFAT"
step_1() {
  check "a filesystem labelled DATA is XFS" "sudo mkfs.xfs -L DATA /dev/vdb1" test "$(blkid -t LABEL=DATA -o value -s TYPE 2>/dev/null | head -1)" = xfs
  check "a filesystem labelled LOGS is ext4" "sudo mkfs.ext4 -L LOGS /dev/vdb2" test "$(blkid -t LABEL=LOGS -o value -s TYPE 2>/dev/null | head -1)" = ext4
  check "a filesystem labelled USB is VFAT" "sudo mkfs.vfat -n USB /dev/vdb3" test "$(blkid -t LABEL=USB -o value -s TYPE 2>/dev/null | head -1)" = vfat
}
STEP_2="mkfs warns"
step_2() {
  quiz "What did mkfs.ext4 say about the XFS partition before you answered n?" "contains a xfs|xfs file system|proceed anyway" "mkfs.ext4 noticed an existing filesystem signature and asked before destroying it."
}
STEP_3="Reserved blocks"
step_3() {
  local dev n; dev=$(blkid -t TYPE=ext4 -o device 2>/dev/null | head -1)
  [ -z "$dev" ] && { manual "No ext4 filesystem found to compare with."; return; }
  n=$(tune2fs -l "$dev" 2>/dev/null | awk -F: '/Reserved block count/{gsub(/ /,"",$2); print $2}')
  quiz "What is the Reserved block count of $dev?" "^\s*${n}\s*$" "5% of the blocks by default, kept for root."
}
STEP_4="Relabelling"
step_4() {
  quiz "Which command changes an XFS label (unmounted)?" "xfs_admin\s+-L" "xfs_admin -L NEWLABEL DEVICE. For ext4: e2label DEVICE NEWLABEL (works mounted)."
}
