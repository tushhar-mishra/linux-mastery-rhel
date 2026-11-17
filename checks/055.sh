TITLE="Kernel modules and sysctl"
STEP_2="Loading and unloading"
step_2() {
  check "nf_conntrack_ftp is unloaded (or held by something else, e.g. firewalld's ftp helper)" "sudo modprobe -r nf_conntrack_ftp" bash -c '! grep -q "^nf_conntrack_ftp " /proc/modules || [ "$(awk "\$1==\"nf_conntrack_ftp\"{print \$3}" /proc/modules)" -gt 0 ]'
}
STEP_3="Blacklisting pcspkr"
step_3() {
  check "pcspkr is blacklisted in /etc/modprobe.d/" "echo 'blacklist pcspkr' | sudo tee /etc/modprobe.d/pcspkr.conf" bash -c 'grep -qsE "^\s*blacklist\s+pcspkr\b" /etc/modprobe.d/*.conf'
  check "pcspkr is not loaded" "Reboot after blacklisting it (and remove it now: sudo modprobe -r pcspkr)" not grep -q '^pcspkr ' /proc/modules
}
STEP_4="A permanent sysctl"
step_4() {
  check "net.ipv4.ip_forward = 1 is set in /etc/sysctl.d/" "echo 'net.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.d/90-forward.conf" bash -c 'grep -qsE "^\s*net\.ipv4\.ip_forward\s*=\s*1" /etc/sysctl.d/*.conf'
  check "it is active now" "sudo sysctl --system" test "$(sysctl -n net.ipv4.ip_forward)" = 1
}
