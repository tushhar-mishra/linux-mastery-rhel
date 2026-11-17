TITLE="RAID with mdadm"
STEP_1="RAID 1"
step_1() {
  check_match "a RAID 1 array is running" "sudo mdadm -C /dev/md0 -l 1 -n 2 DISK1 DISK2" "raid1" cat /proc/mdstat
  check "it is in /etc/mdadm.conf" "sudo mdadm --detail --scan | sudo tee -a /etc/mdadm.conf" grep -qE '^ARRAY' /etc/mdadm.conf
  check "its filesystem is in fstab by UUID" "UUID=… /raid xfs defaults 0 0" bash -c 'for m in $(awk "/^md/{print \$1}" /proc/mdstat); do u=$(blkid -s UUID -o value /dev/$m); [ -n "$u" ] && grep -q "$u" /etc/fstab && exit 0; done; exit 1'
}
STEP_2="Fail and rebuild"
step_2() {
  check_match "every array is healthy again ([UU…], no _)" "mdadm --add the replacement and wait for the rebuild" "^\s+[0-9]+ blocks .*\[U+\]" cat /proc/mdstat
  check "no array shows a missing member" "Watch cat /proc/mdstat until the recovery finishes" not grep -q '_' <(grep -oE '\[[U_]+\]' /proc/mdstat)
}
STEP_3="RAID 5 with a spare"
step_3() {
  quiz "What did /proc/mdstat show while the spare took over?" "recover|rebuild|resync|%" "A recovery progress bar; the failed disk is marked (F) and the spare becomes active."
}
STEP_4="md127"
step_4() {
  quiz "Which name did the array get without its ARRAY line?" "md127" "Without a config entry, mdadm assembles it with a high number (md127)."
}
