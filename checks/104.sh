TITLE="cloud-init"
STEP_1="A NoCloud boot"
step_1() {
  if ! command -v cloud-init >/dev/null; then manual "Run these checks inside the cloud-image VM you booted (cloud-init isn't installed here)."; return; fi
  check_match "cloud-init finished without errors" "sudo cloud-init status --long; read /var/log/cloud-init.log" "status: done" cloud-init status
}
STEP_2="Reading what happened"
step_2() {
  quiz "Which cloud-init command shows how long each stage took?" "analyze (show|blame)" "cloud-init analyze show (or blame)."
}
STEP_3="Schema validation"
step_3() {
  quiz "Which command validates user-data before booting?" "cloud-init schema" "cloud-init schema -c user-data --annotate"
}
STEP_4="Once per instance"
step_4() {
  quiz "Which command makes cloud-init run as if it were the first boot again?" "cloud-init clean" "cloud-init clean --logs (then reboot)."
}
