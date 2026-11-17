TITLE="Users and accounts"
STEP_1="testuser"
step_1() {
  check "testuser exists with UID 3000" "sudo useradd -u 3000 -c 'Test User' testuser" test "$(id -u testuser 2>/dev/null)" = 3000
  check "testuser's comment is 'Test User'" "sudo usermod -c 'Test User' testuser" test "$(getent passwd testuser | cut -d: -f5)" = "Test User"
}
STEP_2="/etc/skel"
step_2() {
  check "/home/newbie/welcome.txt exists (copied from /etc/skel)" "echo hi | sudo tee /etc/skel/welcome.txt; sudo useradd -m newbie" test -f /home/newbie/welcome.txt
}
STEP_3="-G without -a"
step_3() {
  check "testuser is in 'users'" "sudo usermod -G users testuser" in_group testuser users
  check "testuser is no longer in 'wheel' (removed by -G without -a)" "That's the point of the step: usermod -G replaced the list" not in_group testuser wheel
}
STEP_4="Cleaning up"
step_4() {
  check "testuser is deleted" "sudo userdel -r testuser" not user_exists testuser
  check "newbie is deleted" "sudo userdel -r newbie" not user_exists newbie
  check "no files without an owner are left on /" "sudo find / -xdev -nouser   (then delete or chown what it lists)" bash -c '[ -z "$(find / -xdev -nouser 2>/dev/null | head -1)" ]'
}
