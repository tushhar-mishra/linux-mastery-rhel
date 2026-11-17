TITLE="SELinux confined users"
STEP_1="Confined vs unconfined"
step_1() {
  quiz "Which domain do unconfined processes run in?" "unconfined_t|unconfined_service_t" "Users and generically labelled services; ps -eZ | grep -c unconfined counts them."
}
STEP_2="httpd confinement"
step_2() { manual "You showed that httpd_t can't read a file that DAC allows (for example a user_home_t file)."; }
STEP_3="guest1 and staff1"
step_3() {
  check_match "guest1 is mapped to guest_u" "sudo useradd -Z guest_u guest1   (or semanage login -a -s guest_u guest1)" "^guest1\s+guest_u" semanage login -l
  check_match "staff1 is mapped to staff_u" "sudo useradd -Z staff_u staff1" "^staff1\s+staff_u" semanage login -l
}
STEP_4="staff_u with the sysadm role"
step_4() {
  check "a sudo rule switches staff1 to sysadm_r/sysadm_t" "staff1 ALL=(ALL) TYPE=sysadm_t ROLE=sysadm_r ALL in a sudoers drop-in" bash -c 'grep -rhsE "staff1.*TYPE=sysadm_t.*ROLE=sysadm_r|staff1.*ROLE=sysadm_r.*TYPE=sysadm_t" /etc/sudoers /etc/sudoers.d/ | grep -q .'
}
