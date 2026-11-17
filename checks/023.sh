TITLE="Passwords and aging"
STEP_1="Setting a password"
step_1() {
  check "temp1 exists" "sudo useradd temp1" user_exists temp1
  check_match "temp1 has a usable password (passwd -S shows PS or P)" "sudo passwd temp1" "^temp1 (PS|P) " passwd -S temp1
}
STEP_2="Forced change"
step_2() {
  check "temp1 has changed the forced password (last-change day isn't 0)" "sudo chage -d 0 temp1, then su - temp1 and change it when asked" bash -c '[ "$(getent shadow temp1 | cut -d: -f3)" != 0 ]'
}
STEP_3="Lock and unlock"
step_3() {
  check_match "temp1 is unlocked again" "sudo usermod -U temp1" "^temp1 (PS|P) " passwd -S temp1
}
STEP_4="Account expiry"
step_4() {
  check_match "temp1's account expired on 2026-01-01" "sudo chage -E 2026-01-01 temp1" "Account expires\s*:\s*Jan 0?1, 2026" chage -l temp1
  quiz "What did 'su - temp1' tell you?" "expired" "Your account has expired; please contact your system administrator. Expiry blocks every login method, SSH keys included."
}
