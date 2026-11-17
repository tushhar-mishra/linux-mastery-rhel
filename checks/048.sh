TITLE="Mounting and fstab"
STEP_1="/data by UUID, /logs by LABEL"
step_1() {
  check "/data is mounted and is XFS" "sudo mount -a after adding the fstab line" test "$(fs_type /data)" = xfs
  check "/data is in fstab by UUID=" "UUID=… /data xfs defaults 0 0" bash -c '[[ "$(grep -Ev "^\s*(#|$)" /etc/fstab | awk "\$2==\"/data\"{print \$1}")" == UUID=* ]]'
  check "/logs is mounted and is ext4" "sudo mount -a" test "$(fs_type /logs)" = ext4
  check "/logs is in fstab by LABEL=" "LABEL=LOGS /logs ext4 defaults 0 2" bash -c '[[ "$(grep -Ev "^\s*(#|$)" /etc/fstab | awk "\$2==\"/logs\"{print \$1}")" == LABEL=* ]]'
  check "findmnt --verify finds no errors" "sudo findmnt --verify --verbose" findmnt --verify
}
STEP_2="Files under a mount point"
step_2() {
  quiz "Where did the file you put in /data before mounting go?" "under|hidden|still there|beneath|covered" "It's still on the root filesystem, hidden under the mount. Unmount /data to see it again."
}
STEP_3="VFAT owned by a user"
step_3() {
  local mp; mp=$(findmnt -rno TARGET -t vfat | grep -v '^/boot' | head -1)
  check "a VFAT filesystem (not /boot/efi) is mounted" "sudo mount -o uid=\$(id -u $LEARNER),gid=\$(id -g $LEARNER) LABEL=USB /mnt/usb" test -n "$mp"
  [ -n "$mp" ] || return 0
  check_match "it is mounted with uid=$(id -u "$LEARNER")" "Add uid=… (and gid=…) to the mount options" "uid=$(id -u "$LEARNER")" findmnt -no OPTIONS "$mp"
  check "you can write to it" "Remount with uid= of your user" runuser -u "$LEARNER" -- bash -c "touch '$mp/.check-$$' && rm -f '$mp/.check-$$'"
}
STEP_4="Catching an fstab typo"
step_4() {
  quiz "Which command caught your fstab typo before a reboot?" "findmnt\s+--verify|mount -a" "findmnt --verify (and mount -a) catch most mistakes without rebooting."
  check "fstab is clean again" "Fix the typo, then sudo findmnt --verify" findmnt --verify
}
