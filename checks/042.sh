TITLE="Conditionals"
STEP_1="check.sh"
step_1() {
  local f; f=$(find "$LHOME" -maxdepth 2 -name check.sh -type f 2>/dev/null | head -1)
  check "check.sh exists" "Write ~/check.sh" test -n "$f"
  [ -n "$f" ] || return 0
  check_match "check.sh /etc prints yes" "Test with [ -d \"\$1\" ]" "^yes$" runuser -u "$LEARNER" -- bash "$f" /etc
  check "check.sh /etc exits 0" "exit 0 on yes" runuser -u "$LEARNER" -- bash "$f" /etc
  check "check.sh /nope exits 1" "exit 1 on no" bash -c "runuser -u '$LEARNER' -- bash '$f' /nope >/dev/null 2>&1; [ \$? -eq 1 ]"
  check "check.sh with no argument exits 2" "Usage error = exit 2" bash -c "runuser -u '$LEARNER' -- bash '$f' >/dev/null 2>&1; [ \$? -eq 2 ]"
}
STEP_2="The quoting trap"
step_2() {
  quiz "Which words were printed: wrong, right, or both?" "both|wrong.*right|right.*wrong" "Unquoted, [ -e \$f ] became [ -e ], which is true, so 'wrong' printed. Quoted, [ -e \"\" ] is false, so 'right' printed too."
}
STEP_3="case menu"
step_3() { manual "Inputs 1, 2 and 3 ran date, uptime and df -h; anything else printed an error."; }
STEP_4="Create a user only if missing"
step_4() {
  quiz "Which command tells you whether a user exists (exit status 0 = yes)?" "id|getent passwd" "id USER or getent passwd USER; send the output to /dev/null and test the exit status."
}
