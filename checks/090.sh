TITLE="VDO"
STEP_1="A VDO volume"
step_1() {
  check "a VDO LV exists" "sudo lvcreate --type vdo -n vdo1 -L 10G -V 30G VG/vpool" bash -c 'lvs --noheadings -o segtype | grep -qw vdo'
  check "vdostats reports it" "sudo vdostats --human-readable" bash -c 'vdostats 2>/dev/null | grep -q /dev/mapper'
}
STEP_2="Deduplication"
step_2() {
  quiz "Did five copies of the same file use about five times the physical space? (yes/no)" "^\s*no" "VDO stored the blocks once; vdostats' Used barely moved."
}
STEP_3="Random data"
step_3() {
  quiz "How much did VDO save on 500 MB of /dev/urandom data?" "nothing|none|0|no" "Random data has no duplicates and doesn't compress."
}
STEP_4="Freeing space"
step_4() {
  quiz "Which command told VDO about the deleted blocks?" "fstrim" "fstrim sends discards; without them VDO doesn't know the blocks are free."
}
