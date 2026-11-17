TITLE="NetworkManager and nmcli"
STEP_1="The 'lab' profile"
step_1() {
  command -v nmcli >/dev/null || { manual "This step uses NetworkManager (nmcli). Ubuntu Server uses netplan instead: see the Ubuntu part of topic 060."; return; }
  check "a connection profile named 'lab' exists" "sudo nmcli con mod 'OLD NAME' connection.id lab" nmcli -t con show lab
  check_match "lab uses a static address 192.168.56.10/24" "sudo nmcli con mod lab ipv4.method manual ipv4.addresses 192.168.56.10/24" "^192\.168\.56\.10/24" nmcli -g ipv4.addresses con show lab
  check_match "lab sets DNS 1.1.1.1" "sudo nmcli con mod lab ipv4.dns 1.1.1.1" "1\.1\.1\.1" nmcli -g ipv4.dns con show lab
  check_match "lab is active" "sudo nmcli con up lab" "activated" nmcli -g GENERAL.STATE con show lab
}
STEP_2="A second address, removed again"
step_2() {
  command -v nmcli >/dev/null || { manual "This step uses NetworkManager (nmcli). Ubuntu Server uses netplan instead: see the Ubuntu part of topic 060."; return; }
  check "lab has exactly one IPv4 address again" "sudo nmcli con mod lab -ipv4.addresses ADDR/24; sudo nmcli con up lab" test "$(nmcli -g ipv4.addresses con show lab | tr ',' '\n' | grep -c .)" = 1
}
STEP_3="An IPv6 ULA address"
step_3() {
  command -v nmcli >/dev/null || { manual "This step uses NetworkManager (nmcli). Ubuntu Server uses netplan instead: see the Ubuntu part of topic 060."; return; }
  check_match "lab has an fd00:56:: address" "sudo nmcli con mod lab ipv6.method manual ipv6.addresses fd00:56::10/64; sudo nmcli con up lab" "^fd00[\]?:56[\]?:" nmcli -g ipv6.addresses con show lab
  check "server2 answers on fd00:56::11" "Configure fd00:56::11/64 on server2 the same way" ping -6 -c1 -W2 fd00:56::11
}
STEP_4="Keyfiles"
step_4() {
  command -v nmcli >/dev/null || { manual "This step uses NetworkManager (nmcli). Ubuntu Server uses netplan instead: see the Ubuntu part of topic 060."; return; }
  check "the keyfile lab.nmconnection exists" "NetworkManager writes /etc/NetworkManager/system-connections/lab.nmconnection" bash -c 'grep -l "^id=lab$" /etc/NetworkManager/system-connections/*.nmconnection 2>/dev/null | grep -q .'
}
