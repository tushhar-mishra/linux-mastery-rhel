TITLE="firewalld"
STEP_1="Port 8080, permanent"
step_1() {
  check_match "8080/tcp is open permanently in the default zone" "sudo firewall-cmd --permanent --add-port=8080/tcp && sudo firewall-cmd --reload" "8080/tcp" firewall-cmd --permanent --list-ports
  check_match "and in the running configuration" "sudo firewall-cmd --reload" "8080/tcp" firewall-cmd --list-ports
}
STEP_2="SSH only from server2"
step_2() {
  check_match "a rich rule allows ssh from 192.168.56.11" "sudo firewall-cmd --permanent --add-rich-rule='rule family=\"ipv4\" source address=\"192.168.56.11\" service name=\"ssh\" accept'" 'source address="192\.168\.56\.11".*service name="ssh".*accept' firewall-cmd --permanent --list-rich-rules
  check "the general ssh service is removed from the zone" "sudo firewall-cmd --permanent --remove-service=ssh && sudo firewall-cmd --reload" not bash -c 'firewall-cmd --permanent --list-services | tr " " "\n" | grep -qx ssh'
}
STEP_3="Logging denied packets"
step_3() {
  quiz "Which kernel log prefix did the blocked connection show?" "filter_.*REJECT|REJECT|DROP|filter_IN" "Something like 'filter_IN_public_REJECT: IN=eth1 …' (journalctl -k -f)."
  check "LogDenied is back to off" "sudo firewall-cmd --set-log-denied=off" bash -c '[ "$(firewall-cmd --get-log-denied)" = off ]'
}
STEP_4="nftables"
step_4() {
  quiz "Which nft table holds firewalld's rules?" "inet firewalld|firewalld" "nft list table inet firewalld"
}
