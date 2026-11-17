TITLE="LVM VG operations"
STEP_1="pvmove under load"
step_1() {
  check "no pvmove is in progress" "sudo pvmove (resumes) or sudo pvmove --abort" not bash -c 'lvs -a --noheadings -o lv_name | grep -q pvmove'
  quiz "Did the checksums match after the move? (yes/no)" "^\s*yes" "pvmove copies extents with a temporary mirror, online and consistently."
}
STEP_2="Interrupted pvmove"
step_2() {
  quiz "What did you run to resume the move after the reboot?" "^\s*(sudo\s+)?pvmove\s*$" "Plain pvmove resumes any unfinished moves (or --abort rolls them back)."
}
STEP_3="Moving a VG between hosts"
step_3() {
  quiz "On a RHEL 9/10 host, which command lets LVM see an imported disk's VG?" "vgimportdevices|lvmdevices" "The devices file hides unknown disks: vgimportdevices VG (or lvmdevices --adddev)."
}
STEP_4="Merging VGs"
step_4() {
  quiz "Which command merges VG 'small2' into 'small1'?" "vgmerge\s+small1\s+small2" "vgmerge DEST SRC; SRC must be inactive and have the same extent size."
}
