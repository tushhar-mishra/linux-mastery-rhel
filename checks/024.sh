TITLE="Groups"
STEP_1="Two groups, one command"
step_1() {
  check "groups music and media exist" "sudo groupadd music; sudo groupadd media" bash -c 'getent group music >/dev/null && getent group media >/dev/null'
  local both; both=$(comm -12 <(getent group music | cut -d: -f4 | tr , '\n' | sort) <(getent group media | cut -d: -f4 | tr , '\n' | sort) | head -1)
  check "a user is a member of both" "sudo usermod -aG music,media USER" test -n "$both"
  [ -n "$both" ] && note "member of both: $both"
}
STEP_2="Group lists are set at login"
step_2() {
  quiz "Did the user's OLD session show the new group in 'id -Gn'? (yes/no)" "^\s*no" "A process gets its group list at login; only a new login (or newgrp / su -) sees the change."
}
STEP_3="groupdel on a primary group"
step_3() {
  quiz "Why did groupdel refuse?" "primary" "groupdel: cannot remove the primary group of user '…'."
}
STEP_4="Group admin"
step_4() {
  check "music has a group administrator" "sudo gpasswd -A USER music" bash -c '[ -n "$(getent gshadow music | cut -d: -f3)" ]'
}
