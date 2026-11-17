TITLE="iSCSI"
STEP_1="The target (on server2)"
step_1() {
  if ! command -v targetcli >/dev/null; then manual "Run this step on server2, where targetcli is installed."; return; fi
  check_match "a target exports a LUN with an ACL" "targetcli: backstores/block create …; /iscsi create IQN; luns create; acls create INITIATOR-IQN; saveconfig" "acls.*\[Mapped LUNs: [1-9]" targetcli ls /iscsi
  check "the target service is enabled" "sudo systemctl enable --now target" unit_enabled target
}
STEP_2="The initiator (on server1)"
step_2() {
  check_match "an iSCSI session is logged in" "iscsiadm -m discovery -t st -p server2; iscsiadm -m node -T IQN -l" "tcp:" iscsiadm -m session
  check "fstab mounts it with _netdev" "UUID=… /mnt/iscsi xfs _netdev 0 0" bash -c 'grep -Ev "^\s*#" /etc/fstab | grep -q _netdev'
  check "the iscsi service is enabled (logs in at boot)" "sudo systemctl enable iscsi" unit_enabled iscsi
}
STEP_3="Wrong initiator name"
step_3() {
  quiz "What did the login fail with after you changed the initiator name?" "authori[sz]ation|auth" "The target's ACL lists IQNs; an unknown initiator gets an authorization failure."
}
STEP_4="Logged out and cleaned up"
step_4() {
  check "no iSCSI session remains" "sudo iscsiadm -m node -T IQN -u" not iscsiadm -m session
  check "no node records remain" "sudo iscsiadm -m node -T IQN -o delete" not bash -c 'iscsiadm -m node 2>/dev/null | grep -q .'
}
