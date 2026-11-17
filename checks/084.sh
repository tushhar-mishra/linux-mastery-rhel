TITLE="Multipath"
STEP_1="Two paths, one WWID"
step_1() {
  quiz "Which ID did the two disks have in common?" "wwid|scsi.?id|serial" "/usr/lib/udev/scsi_id -g -u -d /dev/sdX prints the WWID."
}
STEP_2="multipathd and LVM on top"
step_2() {
  check "multipathd is running" "sudo mpathconf --enable --with_multipathd y" unit_active multipathd
  check_match "a multipath map has 2 paths" "Check both iSCSI portals are logged in; multipath -ll" "status=(active|enabled)" multipath -ll
  check "LVM uses a /dev/mapper multipath device" "pvcreate /dev/mapper/mpatha, not /dev/sdX" bash -c 'pvs --noheadings -o pv_name 2>/dev/null | grep -qE "/dev/mapper/|mpath"'
}
STEP_3="Path failure"
step_3() { manual "Your dd loop kept running without errors while one path was down."; }
STEP_4="A friendly alias"
step_4() {
  check "/etc/multipath.conf defines an alias" "multipaths { multipath { wwid …  alias data1 } }" grep -qE '^\s*alias\s+\S+' /etc/multipath.conf
}
