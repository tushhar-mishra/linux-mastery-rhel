TITLE="HTTP and curl"
STEP_1="Reading curl -v"
step_1() {
  quiz "Which curl -v lines are the request you sent: '>' or '<'?" "^\s*>\s*$|greater|>" "> = sent to the server, < = received, * = curl's own notes (DNS, TCP, TLS)."
}
STEP_2="Redirects"
step_2() {
  quiz "Status code for http://redhat.com WITHOUT -L?" "^\s*30[1278]\s*$" "A redirect to https://; -L follows it to the final 200."
}
STEP_3="Timing phases"
step_3() {
  quiz "Which -w variable marks the first byte of the response?" "time_starttransfer" "time_namelookup, time_connect, time_appconnect, time_starttransfer, time_total."
}
STEP_4="python3 -m http.server"
step_4() {
  quiz "What status did the missing file get?" "^\s*404\s*$" "404 Not Found; the existing one got 200."
}
