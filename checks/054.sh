TITLE="GRUB and kernel packages"
STEP_1="Default kernel"
step_1() {
  is_rhel || { manual "On Ubuntu, check the default in /etc/default/grub and run update-grub."; return; }
  local newest def; newest=$(printf '%s\n' /boot/vmlinuz-* | grep -v rescue | sort -V | tail -1); def=$(grubby --default-kernel 2>/dev/null)
  check "the default kernel is the newest one again" "sudo grubby --set-default $newest" test "$def" = "$newest"
  check "you're running the default kernel (rebooted back)" "Reboot once more" test "/boot/vmlinuz-$(uname -r)" = "$def"
}
STEP_2="Full boot messages"
step_2() {
  check "the running kernel's command line has no rhgb or quiet" "sudo grubby --update-kernel=ALL --remove-args='rhgb quiet', then reboot" not grep -qwE 'rhgb|quiet' /proc/cmdline
}
STEP_3="One-off edits"
step_3() {
  check "the one-off systemd.unit= edit wasn't saved" "Edits made with e at the GRUB menu last one boot only" not grep -q 'systemd.unit=' /proc/cmdline
}
STEP_4="BLS entries"
step_4() {
  quiz "Which line of a BLS entry holds the kernel arguments?" "^\s*options\s*$" "title, version, linux, initrd and options; grubby edits the options line."
}
