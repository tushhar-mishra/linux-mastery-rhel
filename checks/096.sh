TITLE="Packet capture"
STEP_1="A handshake on lo"
step_1() {
  quiz "Which tcpdump flags mark the SYN-ACK?" "^\s*\[?S\.\]?\s*$" "[S] SYN, [S.] SYN-ACK, [.] ACK, [P.] data, [F.] FIN, [R.] RST."
}
STEP_2="Closed port vs drop"
step_2() {
  quiz "What came back from a closed port?" "rst|\[R" "An immediate [R.] (reset). With a drop rule you saw repeated [S] retransmissions instead."
}
STEP_3="DNS on the wire"
step_3() {
  quiz "Which DNS reply code did tcpdump show for the non-existent name?" "nxdomain" "The reply carries NXDomain (rcode 3)."
}
STEP_4="A pcap file"
step_4() {
  check "a .pcap file exists in /tmp or your home" "sudo tcpdump -i any -nn -w /tmp/capture.pcap port 80" bash -c "find /tmp '$LHOME' -maxdepth 2 \( -name '*.pcap' -o -name '*.pcapng' \) -size +0 2>/dev/null | grep -q ."
  quiz "Which Wireshark display filter shows retransmissions?" "tcp\.analysis\.retransmission" "tcp.analysis.retransmission (also tcp.analysis.flags for all TCP problems)."
}
