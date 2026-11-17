TITLE="SSH tunnels"
STEP_1="A local forward"
step_1() {
  quiz "Which ssh option opened the local forward?" "-L\s*8000:localhost:8000|-L" "-L LOCALPORT:TARGET:TARGETPORT: listen here, connect from the server."
}
STEP_2="Jump host"
step_2() {
  quiz "Which ~/.ssh/config keyword sends a connection through a jump host?" "proxyjump" "ProxyJump bastion (ssh -J on the command line)."
}
STEP_3="SOCKS proxy"
step_3() {
  quiz "Which ssh option starts a SOCKS proxy?" "^\s*-D" "ssh -D 1080 host; curl --proxy socks5h://localhost:1080 … resolves names on the far side."
}
STEP_4="Cleaning up"
step_4() {
  check "no ssh tunnels (-L, -R, -D) are left running" "ss -tlnp | grep ssh, then kill the PIDs" not pgrep -f '^ssh .*-[fN]*[LRD] ?[0-9]'
}
