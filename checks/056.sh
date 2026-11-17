TITLE="tuned profiles"
STEP_1="Recommended vs active"
step_1() {
  quiz "Which profile does tuned-adm recommend on this machine?" "^\s*$(tuned-adm recommend 2>/dev/null)\s*$" "It depends on the hardware and virtualisation (a VM gets virtual-guest)."
}
STEP_2="throughput-performance"
step_2() {
  quiz "What was vm.swappiness under throughput-performance?" "^\s*10\s*$" "throughput-performance sets vm.swappiness = 10 (virtual-guest sets 30)."
}
STEP_3="Your db-tuned profile"
step_3() {
  check "/etc/tuned/profiles/db-tuned/tuned.conf exists" "sudo mkdir -p /etc/tuned/profiles/db-tuned and write tuned.conf (topic 056)" test -f /etc/tuned/profiles/db-tuned/tuned.conf
  check "it includes a base profile" "include=throughput-performance (or virtual-guest) under [main]" grep -qE '^\s*include\s*=' /etc/tuned/profiles/db-tuned/tuned.conf
  check_match "db-tuned is the active profile" "sudo tuned-adm profile db-tuned" "db-tuned" tuned-adm active
  quiz "What did tuned-adm verify report after your manual sysctl -w?" "fail|not|differ|mismatch" "verify compares the live values with the profile and reports the ones that drifted."
}
