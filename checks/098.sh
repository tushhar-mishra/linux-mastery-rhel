TITLE="systemd unit files"
STEP_1="simple vs exec"
step_1() {
  quiz "Which type made 'systemctl start' fail immediately for a missing program?" "^\s*(type=)?exec\s*$" "Type=exec waits until execve() succeeded; Type=simple returns as soon as it forked."
}
STEP_2="Dependencies vs ordering"
step_2() {
  quiz "Which unit stayed inactive because it had both Requires=dep and After=dep?" "app2|after" "With After= it waited for dep, saw it fail, and wasn't started (dependency failed)."
}
STEP_3="Resetting ExecStart="
step_3() {
  quiz "What did systemctl show when you added a second ExecStart= without the empty reset line?" "bad-setting|more than one ExecStart|bad" "Type=simple/exec units may have only one ExecStart=; first add an empty 'ExecStart=' in the drop-in."
}
STEP_4="A crash loop"
step_4() {
  quiz "Which command cleared the 'start request repeated too quickly' state?" "reset-failed" "systemctl reset-failed UNIT, then start it again after fixing the cause."
}
STEP_5="Hardened static-web"
step_5() {
  check "static-web.service exists" "Create /etc/systemd/system/static-web.service from the topic" test -f /etc/systemd/system/static-web.service
  local lvl; lvl=$(systemd-analyze security static-web.service --no-pager 2>/dev/null | grep -m1 'Overall exposure level' | grep -oE '[0-9]+[.][0-9]+' | head -1)
  [ -n "$lvl" ] && note "exposure level: $lvl"
  check "its exposure level is below 5 (medium or better)" "Add the hardening options from the topic, daemon-reload, and run systemd-analyze security again" bash -c "awk -v l='${lvl:-10}' 'BEGIN{exit !(l+0 < 5)}'"
}
