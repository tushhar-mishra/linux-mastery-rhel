TITLE="auditd"
STEP_1="Identity watches"
step_1() {
  command -v auditctl >/dev/null || { manual "Install auditd first (RHEL: package audit; Ubuntu: apt install auditd)."; return; }
  check_match "rules with the key 'identity' are loaded" "Put the rules in /etc/audit/rules.d/50-identity.rules, then sudo augenrules --load" "identity" auditctl -l
  check_match "ausearch finds an identity event (your usermod)" "sudo usermod -s /bin/sh SOMEUSER (and back), then ausearch -k identity -i" "type=SYSCALL|PATH|CONFIG_CHANGE" ausearch -k identity -i
}
STEP_2="root_cmds"
step_2() {
  command -v auditctl >/dev/null || return 0
  check_match "the root_cmds rules are loaded" "Add the two -S execve … -k root_cmds rules and load them" "root_cmds" auditctl -l
  check_match "a root_cmds event carries your auid ($LEARNER)" "Run a command with sudo, then ausearch -k root_cmds -i" "auid=$LEARNER" ausearch -k root_cmds -i
}
STEP_3="aureport"
step_3() {
  quiz "Which aureport option lists failed authentications?" "-au.*--failed|--failed.*-au" "aureport -au --failed"
}
STEP_4="Lost events"
step_4() {
  command -v auditctl >/dev/null || { manual "Install auditd first (RHEL: package audit; Ubuntu: apt install auditd)."; return; }
  quiz "What does 'auditctl -s' show for 'lost' on this machine?" "^\s*$(auditctl -s | awk '/^lost/{print $2}')\s*$" "Events dropped because the backlog overflowed; non-zero means you're missing audit records."
}
