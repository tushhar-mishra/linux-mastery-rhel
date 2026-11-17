TITLE="SELinux fundamentals"
STEP_1="Modes"
step_1() {
  check_match "SELinux is enforcing (you switched back)" "sudo setenforce 1" "^Enforcing$" getenforce
  check_match "and configured to stay enforcing" "SELINUX=enforcing in /etc/selinux/config" "^SELINUX=enforcing" cat /etc/selinux/config
}
STEP_2="File types"
step_2() {
  quiz "What is the SELinux type of /etc/shadow?" "^\s*shadow_t\s*$" "ls -Z /etc/shadow"
  quiz "And of /var/www/html?" "^\s*httpd_sys_content_t\s*$" "The type web servers are allowed to read."
}
STEP_3="Domain transition"
step_3() {
  quiz "Which domain did the passwd process run in?" "^\s*passwd_t\s*$" "unconfined_t ran passwd_exec_t, which transitions to passwd_t."
}
STEP_4="The 403"
step_4() {
  check "httpd is installed" "sudo dnf install -y httpd" rpm -q httpd
  quiz "Which ausearch option finds the denial?" "-m\s*avc|avc" "ausearch -m AVC -ts recent"
}
