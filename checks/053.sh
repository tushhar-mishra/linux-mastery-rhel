TITLE="The boot process"
STEP_1="Kernel command line"
step_1() {
  local r; r=$(tr ' ' '\n' < /proc/cmdline | grep '^root=' | head -1)
  [ -n "$r" ] && quiz "What does root= say on your kernel command line?" "${r//\//\\/}" "The device the initramfs must find and mount as / (via /sysroot)."
}
STEP_2="systemd-analyze"
step_2() {
  local u; u=$(systemd-analyze blame 2>/dev/null | awk 'NR==1{print $2}')
  [ -n "$u" ] && quiz "Which unit is at the top of systemd-analyze blame?" "${u//./\\.}" "blame sorts units by how long they took to start (they start in parallel, so it isn't the critical path)."
}
STEP_3="Watching a boot"
step_3() { manual "You watched GRUB → kernel messages → systemd's [ OK ] lines on the console."; }
STEP_4="Inside the initramfs"
step_4() {
  quiz "Which dracut module puts LVM support into the initramfs?" "^\s*lvm\s*$" "lsinitrd lists the modules; 'lvm' brings lvm.conf and the activation tools."
}
