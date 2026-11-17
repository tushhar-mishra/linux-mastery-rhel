TITLE="LUKS encryption"
STEP_1="An encrypted disk"
step_1() {
  check "a LUKS device exists" "sudo cryptsetup luksFormat /dev/vdb" bash -c 'blkid -t TYPE=crypto_LUKS -o device | grep -q .'
  quiz "Which command backed up the LUKS header?" "luksHeaderBackup" "cryptsetup luksHeaderBackup DEV --header-backup-file FILE (store it off the disk)."
}
STEP_2="Auto-unlock at boot"
step_2() {
  check "/etc/crypttab has an entry" "name UUID=… /root/keyfile luks" bash -c 'grep -Ev "^\s*(#|$)" /etc/crypttab | grep -q .'
  check "the mapping is open" "sudo cryptsetup open DEV NAME (or reboot to test crypttab)" bash -c 'for n in $(awk "!/^\s*#/ && NF{print \$1}" /etc/crypttab); do [ -e /dev/mapper/$n ] || exit 1; done'
  check "fstab mounts a /dev/mapper device" "/dev/mapper/NAME /secure xfs defaults 0 0" bash -c 'grep -Ev "^\s*#" /etc/fstab | grep -q "^/dev/mapper/"'
  check "a key file is in a keyslot with mode 400 or 600" "chmod 400 /root/keyfile" bash -c 'k=$(awk "!/^\s*#/ && NF{print \$3}" /etc/crypttab | head -1); [ -f "$k" ] && [[ $(stat -c %a "$k") =~ ^[46]00$ ]]'
}
STEP_3="New passphrase"
step_3() {
  quiz "Did changing the passphrase re-encrypt the data? (yes/no)" "^\s*no" "luksChangeKey only rewraps the master key in one keyslot."
}
STEP_4="Header restore"
step_4() {
  quiz "Which command put the header back?" "luksHeaderRestore" "cryptsetup luksHeaderRestore DEV --header-backup-file FILE"
}
