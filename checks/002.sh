TITLE="Build your practice lab"
STEP_1="The two VMs can reach each other"
step_1() {
  check "server2 (192.168.56.11) answers ping" "Is server2 running? On your host: vagrant status. Both VMs need a 192.168.56.x address (ip -br addr)." ping -c1 -W2 192.168.56.11
  check_match "this VM has an address on the lab network 192.168.56.0/24" "Run 'vagrant reload' if the VM booted without its private-network address (topic 002)." "192\.168\.56\." ip -br addr
}
STEP_2="The snapshot was restored"
step_2() {
  check "/i-was-here is gone after restoring the snapshot" "Restore the snapshot you took before creating the file, then boot the VM again." not test -e /i-was-here
}
STEP_3="Two extra disks are attached"
step_3() {
  local rootdisk extra
  rootdisk=$(lsblk -nso NAME,TYPE "$(findmnt -no SOURCE /)" 2>/dev/null | awk '$2=="disk"{print $1}' | sed 's/^[^a-z]*//' | head -1)
  extra=$(lsblk -dno NAME,TYPE | awk '$2=="disk"{print $1}' | grep -v -e "^${rootdisk:-sda}\$" -e '^zram' | wc -l)
  note "system disk: ${rootdisk:-?}; other disks: $extra"
  check "at least two extra disks are visible in lsblk" "Power the VM off, add two 5 GB disks (VirtualBox: Settings → Storage), boot, then run lsblk." test "$extra" -ge 2
}
