TITLE="systemd services and targets"
STEP_1="Enabled services"
step_1() {
  quiz "How many service unit files are enabled on this machine?" "^\s*$(systemctl list-unit-files --type=service --state=enabled --no-legend 2>/dev/null | wc -l)\s*$" "systemctl list-unit-files --type=service --state=enabled"
}
STEP_2="A web server that survives reboot"
step_2() {
  check "nginx or httpd is enabled" "sudo systemctl enable --now nginx   (or httpd)" bash -c 'systemctl is-enabled --quiet nginx 2>/dev/null || systemctl is-enabled --quiet httpd 2>/dev/null'
  check "nginx or httpd is running" "sudo systemctl start nginx; journalctl -u nginx for errors" bash -c 'systemctl is-active --quiet nginx 2>/dev/null || systemctl is-active --quiet httpd 2>/dev/null'
  check "it has been running since the last boot (you rebooted)" "Reboot once and run this check again" bash -c 's=$(systemctl show -p ActiveEnterTimestampMonotonic --value nginx httpd 2>/dev/null | sort -n | tail -1); [ -n "$s" ] && [ "$s" -gt 0 ] && [ "$s" -lt 300000000 ]'
}
STEP_3="The heartbeat service restarts"
step_3() {
  check "heartbeat.service exists in /etc/systemd/system" "Create it from the topic" test -f /etc/systemd/system/heartbeat.service
  check_match "it has Restart= set" "Restart=always (or on-failure) in [Service]" "^Restart=(always|on-failure|on-abnormal)" systemctl show -p Restart heartbeat
  check "heartbeat has restarted at least once (you killed it)" "sudo systemctl kill -s KILL heartbeat, wait a few seconds" bash -c '[ "$(systemctl show -p NRestarts --value heartbeat)" -ge 1 ]'
}
STEP_4="Mask and unmask"
step_4() {
  check "nginx is not masked any more" "sudo systemctl unmask nginx" bash -c '[ "$(systemctl is-enabled nginx 2>/dev/null)" != masked ]'
  quiz "Why did 'systemctl mask heartbeat' fail?" "exist|already|/etc/systemd/system|own (unit )?file" "The mask is a /dev/null symlink in /etc/systemd/system, and your heartbeat.service file already occupies that name."
}
