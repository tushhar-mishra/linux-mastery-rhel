TITLE="Time synchronisation with chrony"
STEP_1="server2 as the NTP server"
step_1() {
  check "chrony.conf points at 192.168.56.11" "server 192.168.56.11 iburst in /etc/chrony.conf, and remove the pool lines" grep -qE '^\s*server\s+(192\.168\.56\.11|server2)' /etc/chrony.conf
  check_match "it is the selected source (^*)" "On server2: allow 192.168.56.0/24, open firewall service ntp; then chronyc sources" "^\^\*\s+(192\.168\.56\.11|server2)" chronyc -n sources
}
STEP_2="Correcting a wrong clock"
step_2() {
  quiz "Which chronyc command steps the clock immediately?" "makestep" "chronyc makestep; otherwise chrony slews slowly."
  check "the clock is synchronised again" "sudo systemctl start chronyd; chronyc makestep" bash -c 'timedatectl show -p NTPSynchronized --value | grep -qx yes'
}
STEP_3="Time zone"
step_3() {
  quiz "Which command changes the time zone?" "timedatectl\s+set-timezone" "timedatectl set-timezone Europe/London (it repoints /etc/localtime)."
}
