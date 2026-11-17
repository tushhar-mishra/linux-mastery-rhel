TITLE="DNS server: BIND"
STEP_1="Authoritative for example.lan (on server2)"
step_1() {
  if ! command -v named-checkconf >/dev/null; then manual "Run this step on server2, where BIND is installed."; return; fi
  check "named.conf is valid" "sudo named-checkconf" named-checkconf
  check "named is running" "sudo systemctl enable --now named" unit_active named
  check_match "it answers for example.lan" "Add the zone to named.conf, then rndc reload" "SOA" dig @127.0.0.1 example.lan SOA +noall +answer
  check_match "and has a reverse zone for 192.168.56.x" "zone \"56.168.192.in-addr.arpa\" { … }" "PTR" dig @127.0.0.1 -x 192.168.56.10 +noall +answer
}
STEP_2="Short names from server1"
step_2() {
  quiz "Which resolv.conf line lets you type 'ping server2' instead of the full name?" "search" "search example.lan: short names get the domain appended."
}
STEP_3="The serial"
step_3() {
  quiz "Did the secondary update when you changed a record without bumping the serial? (yes/no)" "^\s*no" "Secondaries only transfer the zone when the SOA serial increases."
}
STEP_4="A missing trailing dot"
step_4() {
  if command -v named-checkzone >/dev/null && [ -f /var/named/example.lan.zone ]; then
    check "example.lan's zone file passes named-checkzone again" "Fix the name, bump the serial, rndc reload" named-checkzone example.lan /var/named/example.lan.zone
  fi
  quiz "Without the trailing dot, what did 'www.example.lan' in the zone become?" "www\.example\.lan\.example\.lan" "Names without a final dot get the zone's origin appended."
}
