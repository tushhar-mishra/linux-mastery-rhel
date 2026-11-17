TITLE="Filesystem check and repair"
STEP_1="e2fsck"
step_1() {
  quiz "Which e2fsck option reports problems without changing anything?" "^\s*-n\s*$" "-n answers 'no' to every question: a safe dry run. -f forces a check of a clean filesystem."
}
STEP_2="Backup superblocks"
step_2() {
  quiz "Which backup superblock number did you give e2fsck -b?" "^\s*(8193|24577|40961|57345|73729|32768|98304|163840|229376|294912|819200|884736)\s*$" "dumpe2fs DEVICE | grep -i backup lists them (8193… for 1K blocks, 32768… for 4K blocks)."
  check "no ext4 filesystem on this machine is left with errors" "Unmount it and run e2fsck -f again" bash -c 'for d in $(blkid -t TYPE=ext4 -o device); do findmnt -n "$d" >/dev/null && continue; e2fsck -n "$d" >/dev/null 2>&1 || exit 1; done'
}
STEP_3="XFS"
step_3() {
  quiz "Which xfs_repair option only checks?" "^\s*-n\s*$" "xfs_repair -n reports; plain xfs_repair repairs; -L (zero the log) is the last resort."
}
