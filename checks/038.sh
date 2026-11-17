TITLE="Logging: journald, rsyslog and logrotate"
STEP_1="Warnings this boot"
step_1() { manual "journalctl -b -p warning: you identified the most serious message and what it means."; }
STEP_2="Persistent journal"
step_2() {
  check "the journal is persistent (/var/log/journal exists)" "sudo mkdir -p /var/log/journal && sudo systemd-tmpfiles --create --prefix /var/log/journal && sudo systemctl restart systemd-journald" test -d /var/log/journal
  check "the journal holds more than one boot (you rebooted)" "Reboot, then journalctl --list-boots" bash -c '[ "$(journalctl --list-boots --no-pager 2>/dev/null | grep -c .)" -ge 2 ]'
}
STEP_3="An rsyslog rule"
step_3() {
  check "/etc/rsyslog.d/test.conf sends local5 to /var/log/local5.log" "echo 'local5.* /var/log/local5.log' | sudo tee /etc/rsyslog.d/test.conf; sudo systemctl restart rsyslog" grep -qE '^\s*local5\.\*\s+-?/var/log/local5\.log' /etc/rsyslog.d/test.conf
  check "/var/log/local5.log (or a rotated copy) contains your 'hello'" "logger -p local5.info hello" bash -c 'grep -qs hello /var/log/local5.log* || zgrep -qs hello /var/log/local5.log*'
}
STEP_4="logrotate"
step_4() {
  check "a logrotate config covers /var/log/local5.log" "Create /etc/logrotate.d/local5 (topic example)" bash -c 'grep -ls "/var/log/local5.log" /etc/logrotate.d/* | grep -q .'
  check "the log has been rotated at least once (-f)" "sudo logrotate -f /etc/logrotate.d/local5" bash -c 'ls /var/log/local5.log?* >/dev/null 2>&1'
}
