TITLE="Special permissions, ACLs and attributes"
STEP_1="The shared team directory"
step_1() {
  check "/shared/projects exists, group projects" "Follow the recipe in the topic: groupadd projects; mkdir -p /shared/projects; chgrp projects …" test "$(stat -c %G /shared/projects 2>/dev/null)" = projects
  check "/shared/projects has SGID and the sticky bit" "sudo chmod 3770 /shared/projects" bash -c '[ "$(stat -c %a /shared/projects)" = 3770 ] || [ "$(stat -c %a /shared/projects)" = 3775 ]'
  check "a default ACL gives the group rwX" "sudo setfacl -d -m g:projects:rwX /shared/projects" bash -c "getfacl -p /shared/projects 2>/dev/null | grep -q '^default:group:projects:rwx'"
  check "files inside belong to group projects" "Create files as your test users; SGID should give them group projects" bash -c '[ -z "$(find /shared/projects -mindepth 1 ! -group projects | head -1)" ] && [ -n "$(find /shared/projects -mindepth 1 | head -1)" ]'
}
STEP_2="SUID on a copy of id"
step_2() {
  check "/tmp/myid was deleted afterwards" "sudo rm /tmp/myid" not test -e /tmp/myid
  quiz "What euid did /tmp/myid show when you ran it as a normal user?" "euid=0|^\s*0\s*$|root" "SUID root: the process runs with the file owner's effective UID, 0."
}
STEP_3="ACL mask"
step_3() {
  quiz "After shrinking the mask to r--, what did getfacl show next to the user entry?" "#effective:\s*r--|effective.*r--" "The mask caps named users, named groups and the owning group."
}
STEP_4="Immutable"
step_4() {
  quiz "What did even root get when editing the immutable file?" "operation not permitted|not permitted" "chattr +i blocks writes, renames and deletes for everyone, including root, until chattr -i."
}
