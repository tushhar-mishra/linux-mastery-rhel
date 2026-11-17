TITLE="KVM virtualisation"
STEP_1="Host and first VM"
step_1() {
  if ! grep -qE 'vmx|svm' /proc/cpuinfo; then manual "This machine has no hardware virtualisation (vmx/svm), so it can't run KVM guests; do this lab on a host that does."; return; fi
  check "libvirt is running" "sudo dnf install -y qemu-kvm libvirt virt-install && sudo systemctl enable --now virtqemud.socket" bash -c 'systemctl is-active --quiet virtqemud.socket || systemctl is-active --quiet libvirtd'
  check "at least one VM is defined" "virt-install … (topic 100)" bash -c '[ -n "$(virsh list --all --name | grep .)" ]'
}
STEP_2="Snapshot and revert"
step_2() {
  quiz "Which virsh command reverts a VM to a snapshot?" "snapshot-revert" "virsh snapshot-revert VM SNAPNAME"
}
STEP_3="A second disk"
step_3() {
  quiz "Which virsh command attaches a disk to a running VM?" "attach-disk" "virsh attach-disk VM /var/lib/libvirt/images/data.qcow2 vdb --subdriver qcow2 --persistent"
}
STEP_4="sVirt labels"
step_4() {
  quiz "Which SELinux type does a running VM's disk image get?" "svirt_image_t" "svirt_image_t plus the VM's MCS categories; the qemu process runs as svirt_t."
}
