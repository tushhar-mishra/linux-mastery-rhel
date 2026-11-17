TITLE="Cockpit and Lightspeed"
STEP_1="Cockpit on"
step_1() {
  check "cockpit.socket is enabled" "sudo systemctl enable --now cockpit.socket" unit_enabled cockpit.socket
  check "something listens on 9090" "sudo systemctl start cockpit.socket" port_listening 9090
}
STEP_2="An LV made in Cockpit"
step_2() {
  quiz "Which file did Cockpit update so your new filesystem mounts at boot?" "fstab" "/etc/fstab: Cockpit uses the same system tools, so the CLI sees everything it does."
}
STEP_3="GUI and CLI agree"
step_3() { manual "systemctl status showed the service stopping at the moment you clicked Stop in Cockpit."; }
STEP_4="9090 only from the lab subnet"
step_4() {
  check_match "a rich rule allows 9090/cockpit from 192.168.56.0/24" "sudo firewall-cmd --permanent --add-rich-rule='rule family=\"ipv4\" source address=\"192.168.56.0/24\" service name=\"cockpit\" accept'" '192\.168\.56\.0/24.*(cockpit|9090)' firewall-cmd --permanent --list-rich-rules
  check "the open cockpit service is removed from the zone" "sudo firewall-cmd --permanent --remove-service=cockpit && sudo firewall-cmd --reload" not bash -c 'firewall-cmd --permanent --list-services | tr " " "\n" | grep -qx cockpit'
}
