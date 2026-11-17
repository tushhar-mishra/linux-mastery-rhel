TITLE="Processes and signals"
STEP_1="The two sleeps"
step_1() {
  check "both 'sleep 3366' processes are gone" "pkill -x sleep, or kill PID" not pgrep -f '^sleep 3366$'
}
STEP_2="Job control"
step_2() {
  quiz "Which command sent the stopped job to run in the background?" "^\s*bg" "Ctrl+Z stops it, bg continues it in the background, fg brings it back."
}
STEP_3="The process tree"
step_3() {
  quiz "What PID is at the top of your shell's chain?" "^\s*1\s*$" "PID 1, systemd: every process descends from it."
}
STEP_4="A zombie"
step_4() {
  quiz "Which STAT letter did the zombie show?" "^\s*Z" "Z = zombie (<defunct>): finished, but its parent never called wait()."
}
