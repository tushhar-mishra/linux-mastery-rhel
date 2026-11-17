TITLE="Central identity: NSS and SSSD"
STEP_1="nsswitch.conf"
step_1() {
  quiz "Which source is listed first on the 'passwd:' line of /etc/nsswitch.conf?" "^\s*$(awk '/^passwd:/{print $2}' /etc/nsswitch.conf)\s*$" "getent asks the sources in order; 'getent -s files' asks only /etc/passwd."
}
STEP_2="Who answered?"
step_2() {
  quiz "Which NSS source answered 'getent hosts localhost'?" "files|myhostname" "files (/etc/hosts) if localhost is listed there, otherwise myhostname, which always knows localhost and the machine's own name."
}
