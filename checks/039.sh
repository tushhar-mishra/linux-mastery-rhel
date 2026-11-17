TITLE="Job scheduling: cron and timers"
STEP_1="at"
step_1() {
  check "/tmp/at-test was written by the at job" "echo 'date > /tmp/at-test' | at now + 1 minute; wait a minute (atd must be running)" test -s /tmp/at-test
}
STEP_2="A cron job, removed again"
step_2() {
  check "/tmp/cron-test has at least 2 lines (the job ran twice)" "* * * * * date >> /tmp/cron-test 2>&1 in crontab -e; wait 2 minutes" bash -c '[ $(wc -l < /tmp/cron-test) -ge 2 ]'
  check "the job is no longer in your crontab" "crontab -e and delete the line" not bash -c "crontab -l -u '$LEARNER' 2>/dev/null | grep -q cron-test"
}
STEP_3="cron's PATH"
step_3() {
  quiz "Where did you find cron's error about the missing command?" "/var/log/cron|journal|mail|syslog" "RHEL logs cron runs in /var/log/cron (and the journal); the job's own output goes to local mail unless redirected."
}
STEP_4="A systemd timer"
step_4() {
  local t; t=$(grep -lE '^\s*OnCalendar\s*=\s*\*:0/2' /etc/systemd/system/*.timer 2>/dev/null | head -1)
  check "a timer in /etc/systemd/system runs every 2 minutes (OnCalendar=*:0/2)" "Create NAME.timer + NAME.service (topic 039), then systemctl enable --now NAME.timer" test -n "$t"
  [ -n "$t" ] && check "$(basename "$t") is active" "sudo systemctl enable --now $(basename "$t")" unit_active "$(basename "$t")"
  [ -n "$t" ] && check "its service has run (journal has entries)" "Wait 2 minutes, then journalctl -u $(basename "$t" .timer).service" bash -c "journalctl -u $(basename "$t" .timer).service --no-pager -q 2>/dev/null | grep -q ."
}
