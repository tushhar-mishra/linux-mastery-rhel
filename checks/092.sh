TITLE="Processes and system calls"
STEP_1="strace a pipeline"
step_1() {
  quiz "Why were there two child execve calls?" "ls.*wc|wc.*ls|two|each|both" "bash forked one child for ls and one for wc; each child called execve for its program."
}
STEP_2="fd inheritance"
step_2() {
  quiz "Which fd did the child bash have open to /tmp/fdtest?" "^\s*3\s*$" "Open fds without close-on-exec survive fork and execve."
}
STEP_3="Reaping a zombie"
step_3() {
  quiz "Who reaped the zombie after you killed its parent?" "init|systemd|pid ?1|subreaper" "The orphan was re-parented to PID 1 (or a subreaper), which called wait()."
}
STEP_4="ulimit -n"
step_4() {
  quiz "Which errno did Python report?" "24|EMFILE|too many open files" "OSError: [Errno 24] Too many open files."
}
STEP_5="Deleted but open"
step_5() {
  check "no process still holds a deleted file open" "Kill the holder (lsof +L1 shows it)" not bash -c 'lsof -nP +L1 2>/dev/null | awk "NR>1 && \$1 ~ /python/" | grep -q .'
}
