TITLE="Compiling a kernel"
STEP_1="The custom kernel"
step_1() {
  quiz "Which make target fills new config options with defaults?" "olddefconfig" "make olddefconfig, after copying /boot/config-\$(uname -r) to .config."
}
STEP_2="Booting it once"
step_2() {
  quiz "What did uname -r end with when you booted your kernel?" "-lab" "The LOCALVERSION you set (CONFIG_LOCALVERSION=\"-lab\")."
}
STEP_3="Removing it cleanly"
step_3() {
  check "no -lab kernel remains in /boot" "sudo kernel-install remove VERSION-lab; sudo rm -rf /lib/modules/VERSION-lab" bash -c '! ls /boot/vmlinuz-*-lab* >/dev/null 2>&1'
  check "no -lab module tree remains" "sudo rm -rf /lib/modules/*-lab" bash -c '! ls -d /lib/modules/*-lab* >/dev/null 2>&1'
  is_rhel && check "the default kernel is a RHEL one" "sudo grubby --set-default /boot/vmlinuz-\$(rpm -q --last kernel | head -1 | sed 's/^kernel-//; s/ .*//')" bash -c 'grubby --default-kernel | grep -qv -- -lab'
}
STEP_4="Secure Boot"
step_4() {
  quiz "Which command shows whether Secure Boot is on?" "mokutil\s+--sb-state" "mokutil --sb-state"
}
