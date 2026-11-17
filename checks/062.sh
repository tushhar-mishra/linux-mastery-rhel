TITLE="Network bonding"
STEP_1="bond0 in active-backup"
step_1() {
  check "bond0 exists" "sudo nmcli con add type bond con-name bond0 ifname bond0 bond.options 'mode=active-backup,miimon=100'" test -e /proc/net/bonding/bond0
  check_match "it runs in active-backup mode" "bond.options mode=active-backup" "fault-tolerance \(active-backup\)" cat /proc/net/bonding/bond0
  check "it has two ports" "Add two ethernet profiles with port-type bond controller bond0" test "$(grep -c '^Slave Interface' /proc/net/bonding/bond0 2>/dev/null)" -ge 2
  check_match "bond0 has an IPv4 address" "sudo nmcli con mod bond0 ipv4.method manual ipv4.addresses …; sudo nmcli con up bond0" "inet " ip -4 addr show bond0
}
STEP_2="Failover"
step_2() {
  quiz "About how many pings were lost when you disconnected the active port?" "^\s*~?\s*[0-9]{1,2}\s*$|none|few|zero" "With miimon=100, failover takes about a tenth of a second plus ARP updates: 0–3 lost pings."
}
STEP_3="/proc/net/bonding/bond0"
step_3() {
  check_match "the bond reports a currently active port" "Check the cable/port states" "Currently Active Slave: \S+" cat /proc/net/bonding/bond0
}
