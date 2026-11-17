TITLE="The filesystem tree"
STEP_2="Disk-backed vs RAM-backed filesystems"
step_2() {
  quiz "Name a filesystem type from 'df -hT' that lives in RAM." "^\s*(tmpfs|devtmpfs|ramfs)\s*$" "tmpfs (/run, /dev/shm, often /tmp) and devtmpfs (/dev) use memory, not disk."
}
STEP_3="/proc"
step_3() {
  quiz "Which /proc file shows the seconds since boot?" "uptime" "/proc/uptime: seconds since boot, and idle seconds summed over all CPUs."
}
STEP_4="Package ownership"
step_4() {
  quiz "Which package owns /usr/bin/ls?" "^\s*coreutils" "rpm -qf /usr/bin/ls (Ubuntu: dpkg -S /usr/bin/ls)."
}
