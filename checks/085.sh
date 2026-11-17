TITLE="LVM thin provisioning and striping"
STEP_1="A thin pool"
step_1() {
  check "a thin pool exists" "sudo lvcreate -L 3G -T VG/pool" bash -c 'lvs --noheadings -o segtype | grep -qw thin-pool'
  check "it has at least two thin LVs" "sudo lvcreate -V 2G -T VG/pool -n thin1 (and thin2)" test "$(lvs --noheadings -o segtype | grep -cw thin)" -ge 2
}
STEP_2="A full pool"
step_2() {
  quiz "What did the filesystem on the full pool do (see dmesg)?" "error|shut|read.?only|i/o|queue" "Writes failed (or queued) and XFS shut down the filesystem; extend the pool, then repair."
}
STEP_3="Thin snapshots"
step_3() {
  quiz "Which option activates a thin snapshot that has the 'skip activation' flag?" "-K|--ignoreactivationskip" "lvchange -ay -K VG/snap (thin snapshots are created with activation skip set)."
}
STEP_4="A striped LV"
step_4() {
  check "a striped LV with 2 stripes exists" "sudo lvcreate --type striped -i 2 -I 64k -L 1G -n stripe VG" bash -c 'lvs --noheadings -o segtype,stripes | awk "\$1==\"striped\" && \$2>=2" | grep -q .'
}
