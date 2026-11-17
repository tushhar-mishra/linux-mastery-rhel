TITLE="VMs vs containers"
STEP_1="systemd-detect-virt"
step_1() {
  quiz "What does systemd-detect-virt print on this machine?" "^\s*$(systemd-detect-virt 2>/dev/null)\s*$" "kvm, oracle (VirtualBox), microsoft (Hyper-V) … or none on bare metal; podman inside a container."
}
STEP_2="One kernel"
step_2() {
  quiz "Did uname -r inside a container match the host's? (yes/no)" "^\s*yes" "Containers share the host kernel; only a VM boots its own."
}
STEP_3="Same process, two views"
step_3() {
  quiz "Was the container's /proc/PID/ns/net the same as your shell's? (yes/no)" "^\s*no" "Different inode = a separate network namespace."
}
