TITLE="Swap"
STEP_1="Partition + file with priorities"
step_1() {
  check "a swap partition is active" "mkswap /dev/vdb2; add to fstab with pri=; swapon -a" bash -c 'swapon --show=TYPE --noheadings | grep -q partition'
  check "a swap file is active" "dd, chmod 600, mkswap, swapon (topic 050)" bash -c 'swapon --show=TYPE --noheadings | grep -q file'
  check "fstab gives swap entries a pri= option" "UUID=… none swap defaults,pri=10 0 0" bash -c 'grep -Ev "^\s*#" /etc/fstab | awk "\$3==\"swap\"" | grep -q "pri="'
  check "the priorities differ" "Use different pri= numbers" bash -c '[ "$(swapon --show=PRIO --noheadings | sort -u | wc -l)" -ge 2 ]'
}
STEP_2="Swapping under pressure"
step_2() {
  quiz "Which vmstat columns showed swap activity?" "si.*so|so.*si|^\s*(si|so)\s*$" "si = swapped in, so = swapped out (per second)."
}
STEP_3="Removing the swap file"
step_3() {
  check "no swap file is active any more" "sudo swapoff /swapfile" not bash -c 'swapon --show=TYPE --noheadings | grep -q file'
  check "no swap file is listed in fstab" "Delete its line from /etc/fstab" not bash -c 'grep -Ev "^\s*#" /etc/fstab | awk "\$3==\"swap\" {print \$1}" | grep -q "^/"'
}
