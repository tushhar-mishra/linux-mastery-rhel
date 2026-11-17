TITLE="Ansible"
STEP_1="Idempotency"
step_1() {
  check "ansible is installed" "sudo dnf install -y ansible-core" command -v ansible-playbook
  quiz "What did the second run report for changed=?" "^\s*(changed=)?0\s*$" "Modules only change what differs from the desired state."
}
STEP_2="firewalld + seport"
step_2() {
  check_match "http is allowed by the firewall" "ansible.posix.firewalld: service=http permanent=true immediate=true state=enabled" "\bhttp\b" firewall-cmd --list-services
  check_match "8082/tcp is labelled http_port_t" "community.general.seport: ports=8082 proto=tcp setype=http_port_t state=present" "^http_port_t\s+tcp\s+.*\b8082\b" semanage port -l
}
STEP_3="Template with validate"
step_3() {
  quiz "Which placeholder does validate: use for the temporary file?" "%s" "validate: 'nginx -t -c %s' tests the new file before it replaces the old one."
}
STEP_4="Catching drift"
step_4() {
  quiz "Which two options preview changes without making them?" "--check.*--diff|--diff.*--check" "ansible-playbook site.yml --check --diff"
}
