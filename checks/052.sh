TITLE="LVM snapshots and recovery"
STEP_1="Restoring a file from a snapshot"
step_1() {
  quiz "Which mount option did you need to mount an XFS snapshot alongside its origin?" "nouuid" "The snapshot has the same filesystem UUID as the origin, which XFS refuses without nouuid."
}
STEP_2="Overflowing a snapshot"
step_2() {
  quiz "What did lvs or dmesg say about the overflowed snapshot?" "invalid|inactive|100|overflow|full" "A full classic snapshot becomes invalid; it can only be removed."
}
STEP_3="Merging"
step_3() {
  quiz "After lvconvert --merge, were your changes to the origin gone? (yes/no)" "^\s*yes" "Merging rolls the origin back to the moment the snapshot was taken."
}
STEP_4="vgcfgrestore"
step_4() {
  quiz "Which command lists the archived metadata versions of a VG?" "vgcfgrestore\s+(--list|-l)" "vgcfgrestore --list VG, then vgcfgrestore -f FILE VG."
}
