TITLE="SSH server hardening"
STEP_1="00-local.conf"
step_1() {
  check "/etc/ssh/sshd_config.d/00-local.conf exists" "sudo vi /etc/ssh/sshd_config.d/00-local.conf" test -f /etc/ssh/sshd_config.d/00-local.conf
  check_match "the effective PermitRootLogin is no" "PermitRootLogin no in 00-local.conf; check with sudo sshd -T" "^permitrootlogin no$" sshd -T
  check_match "the effective MaxAuthTries is 3" "MaxAuthTries 3" "^maxauthtries 3$" sshd -T
  check "sshd's configuration is valid" "sudo sshd -t" sshd -t
}
STEP_2="Keys only"
step_2() {
  check_match "password authentication is off" "PasswordAuthentication no (after testing keys!)" "^passwordauthentication no$" sshd -T
}
STEP_3="AllowGroups"
step_3() {
  check_match "AllowGroups includes sshusers" "AllowGroups sshusers" "^allowgroups .*sshusers" sshd -T
  check "you are in sshusers (so you can still log in)" "sudo usermod -aG sshusers $LEARNER" in_group "$LEARNER" sshusers
}
STEP_4="Port 2222 and back"
step_4() {
  check_match "sshd listens on port 22 again" "Remove Port 2222, sudo systemctl restart sshd" "^port 22$" sshd -T
  quiz "Which three things did port 2222 need on RHEL?" "semanage.*firewall|firewall.*semanage|selinux.*firewall|firewall.*selinux" "An SELinux port label (semanage port -a -t ssh_port_t), a firewall rule, and the Port line (+ restart)."
}
