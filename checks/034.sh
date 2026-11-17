TITLE="top and load average"
STEP_1="Keys in top"
step_1() {
  quiz "Which key in top sorts by memory?" "^\s*(M|shift.?\+?.?m)\s*$" "M sorts by %MEM, P by %CPU, 1 shows each CPU."
}
STEP_2="The CPU burner"
step_2() {
  check "no busy loop is left running" "Kill it: pkill -f '^sh -c while'" not pgrep -f '^sh -c while :; do :; done'
}
STEP_3="I/O wait"
step_3() {
  check "/tmp/big was deleted" "rm /tmp/big" not test -e /tmp/big
  quiz "Which top CPU field rose during the direct-I/O dd?" "^\s*wa\b|wait" "wa = time the CPUs were idle while waiting for I/O."
}
STEP_4="A saved snapshot"
step_4() {
  check "a /tmp/top-*.txt snapshot exists" "top -b -n 1 > /tmp/top-\$(date +%F_%H%M).txt" bash -c 'ls /tmp/top-*.txt >/dev/null 2>&1'
}
