TITLE="How networks work"
STEP_1="Interfaces and the gateway"
step_1() {
  local gw; gw=$(ip route show default | awk 'NR==1{print $3}')
  [ -n "$gw" ] && quiz "What is this machine's default gateway?" "^\s*${gw//./\\.}\s*$" "ip route: the 'default via …' line."
}
STEP_2="ARP"
step_2() {
  quiz "Which command showed server2's MAC address on server1?" "ip\s+n(eigh(bour)?)?|arp" "ip neigh: the kernel's ARP (neighbour) cache."
}
STEP_3="Listening ports"
step_3() {
  quiz "Which program listens on TCP port 22?" "sshd" "ss -tlnp shows the process; /etc/services names the port 'ssh'."
}
STEP_4="tracepath"
step_4() { manual "tracepath -n 8.8.8.8 showed each router hop (NAT inside a VM hides some of them)."; }
