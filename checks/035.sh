TITLE="Process priority: nice, renice and friends"
STEP_1="Shares in one session"
step_1() {
  quiz "About what %CPU did the nice-10 loop get next to two nice-0 loops on one CPU?" "^\s*~?\s*[3-8]([.,][0-9]+)?\s*%?\s*$" "Weights 1024 : 1024 : 110, so about 5%."
}
STEP_2="Renice limits"
step_2() {
  quiz "Could you renice your own process from 10 back to 0 as a normal user? (yes/no)" "^\s*no" "Only root may lower a nice value, even back to where it was."
}
STEP_3="Two sessions"
step_3() {
  quiz "What share did the nice-19 loop in the second SSH session get?" "half|50|4[0-9]|5[0-9]|same|equal" "Each session is its own cgroup with equal weight, so nice doesn't rank them."
}
STEP_4="Services and CPUWeight"
step_4() {
  check "hogA and hogB are stopped" "sudo systemctl stop hogA hogB" bash -c '! systemctl is-active --quiet hogA && ! systemctl is-active --quiet hogB'
  quiz "Which service got most of the CPU?" "hogb|1000|weight" "The cgroup weight decided: 1000 vs the default 100."
}
STEP_5="Cleanup and I/O scheduler"
step_5() {
  check "no busy loops are left running" "pkill -f '^sh -c while'" not pgrep -f '^sh -c while :; do :; done'
  local d; d=$(lsblk -nso NAME,TYPE "$(findmnt -no SOURCE /)" 2>/dev/null | awk '$2=="disk"{print $1}' | sed 's/^[^a-z]*//' | head -1)
  [ -n "$d" ] && [ -r "/sys/block/$d/queue/scheduler" ] && quiz "Which I/O scheduler does your system disk ($d) use?" "$(sed 's/.*\[\(.*\)\].*/\1/' /sys/block/$d/queue/scheduler)" "The active one is shown in [brackets] in /sys/block/$d/queue/scheduler."
}
