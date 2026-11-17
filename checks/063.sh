TITLE="Name resolution and the DNS client"
STEP_1="/etc/hosts vs dig"
step_1() {
  check "server2 is in /etc/hosts" "echo '192.168.56.11 server2.example.com server2' | sudo tee -a /etc/hosts" bash -c 'grep -Ev "^\s*#" /etc/hosts | grep -qw server2'
  quiz "Did 'dig server2' find it? (yes/no)" "^\s*no" "dig asks DNS servers directly and never reads /etc/hosts; getent uses nsswitch, so it does."
}
STEP_2="TTL"
step_2() {
  quiz "What happened to the TTL on the second dig?" "decreas|lower|smaller|count(ed|s)? down|less" "The resolver serves the cached answer and counts its remaining lifetime down."
}
STEP_3="Comparing resolvers"
step_3() {
  quiz "Which dig line shows how long the query took?" "query time" ";; Query time: N msec"
}
STEP_4="A dead nameserver"
step_4() {
  check "10.255.255.1 is no longer a nameserver" "Remove it from the connection's ipv4.dns and run nmcli con up" not grep -q '^nameserver 10\.255\.255\.1' /etc/resolv.conf
  quiz "How long did each lookup take with the dead server first?" "[0-9]+\s*s|second|timeout" "Each try waits for the timeout (5 s by default) before asking the next server."
}
