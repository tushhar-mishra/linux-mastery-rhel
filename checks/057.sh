TITLE="Boot recovery"
STEP_1="Root password with rd.break"
step_1() {
  check "no relabel is pending (/.autorelabel is gone after the relabel boot)" "Reboot once and let the relabel finish" not test -e /.autorelabel
  is_rhel && check_match "SELinux is enforcing" "sudo setenforce 1, and SELINUX=enforcing in /etc/selinux/config" "Enforcing" getenforce
  manual "You logged in as root with the new password after the relabel."
}
STEP_2="A reboot loop"
step_2() {
  check_match "the default target is multi-user or graphical again" "sudo systemctl set-default multi-user.target" "^(multi-user|graphical)\.target$" systemctl get-default
}
STEP_3="A bad fstab line"
step_3() {
  check "fstab passes findmnt --verify" "Remove or fix the bad UUID line" findmnt --verify
}
STEP_4="GRUB password removed"
step_4() {
  check "no GRUB password is set any more" "sudo rm /boot/grub2/user.cfg (that's where grub2-setpassword writes it)" not test -s /boot/grub2/user.cfg
}
