TITLE="Performance and observability"
STEP_1="Baseline vs stress"
step_1() {
  quiz "Which vmstat column revealed the --io stress?" "^\s*(wa|b|bo)\b" "wa and b rise with I/O waits; r and us with CPU; free/si/so with memory."
}
STEP_2="PSI"
step_2() {
  check "PSI is enabled (/proc/pressure/memory exists)" "On RHEL: sudo grubby --update-kernel=ALL --args=psi=1, then reboot" test -r /proc/pressure/memory
}
STEP_3="perf"
step_3() {
  check "perf is installed" "sudo dnf install -y perf" command -v perf
  quiz "Which perf command shows the recorded profile?" "perf report" "perf report reads perf.data; perf top is the live view."
}
STEP_4="execsnoop"
step_4() {
  check "bcc-tools are installed" "sudo dnf install -y bcc-tools  (run /usr/share/bcc/tools/execsnoop)" test -x /usr/share/bcc/tools/execsnoop
}
STEP_5="A core dump"
step_5() {
  check "coredumpctl has recorded a crash" "sleep 100 & kill -SEGV \$!; then coredumpctl list" bash -c 'coredumpctl list --no-pager 2>/dev/null | awk "NR>1" | grep -q .'
}
