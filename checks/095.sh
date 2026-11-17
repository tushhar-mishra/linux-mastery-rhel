TITLE="TCP/IP deep dive"
STEP_1="Slowest phases"
step_1() {
  quiz "Which curl -w variable ends with the TLS handshake?" "time_appconnect" "time_connect = TCP done; time_appconnect = TLS done."
}
STEP_2="CLOSE-WAIT"
step_2() {
  quiz "Which side piled up CLOSE-WAIT sockets: the clients or the server?" "server" "The server never called close() after the clients closed."
}
STEP_3="Drop vs reject"
step_3() {
  quiz "Which rule made curl wait until it timed out: drop or reject?" "^\s*drop\s*$" "drop sends nothing back; reject answers at once (connection refused)."
}
STEP_4="Accept-queue overflow"
step_4() {
  quiz "Which nstat counter rose when the accept queue overflowed?" "ListenOverflows|ListenDrops" "TcpExtListenOverflows (and TcpExtListenDrops)."
}
