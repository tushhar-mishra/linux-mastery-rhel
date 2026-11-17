TITLE="Routing"
STEP_1="ip route get"
step_1() {
  local dev; dev=$(ip route get 8.8.8.8 2>/dev/null | grep -o 'dev [^ ]*' | awk '{print $2}')
  [ -n "$dev" ] && quiz "Which interface does 'ip route get 8.8.8.8' use?" "^\s*${dev}\s*$" "The default route's interface; a local address would use its own interface, 127.0.0.1 uses lo."
}
STEP_2="A permanent static route"
step_2() {
  command -v nmcli >/dev/null || { manual "This step uses NetworkManager (nmcli). Ubuntu Server uses netplan instead: see the Ubuntu part of topic 060."; return; }
  check "some connection profile has a permanent static route" "sudo nmcli con mod CONN +ipv4.routes '10.99.0.0/24 192.168.56.11'; sudo nmcli con up CONN" bash -c 'for c in $(nmcli -g UUID con show); do [ -n "$(nmcli -g ipv4.routes con show "$c")" ] && exit 0; done; exit 1'
}
STEP_3="The router lab"
step_3() {
  quiz "Which sysctl must be 1 on the Linux router?" "net\.ipv4\.ip_forward|ip_forward" "Without it the kernel drops packets that aren't addressed to itself."
}
STEP_4="Forwarding off"
step_4() {
  quiz "With ip_forward=0 on the router, where did the pings stop?" "router|first|hop 1|1" "The router received them but wouldn't pass them on."
}
