TITLE="grep and regular expressions"
STEP_1="Exact uppercase ERROR"
step_1() {
  check "app.log from the topic is in your home directory" "Copy the sample app.log from the topic into ~/app.log" grep -q 'web02 POST' "$LHOME/app.log"
  quiz "How many lines have the level exactly ERROR (uppercase)?" "^\s*2\s*$" "grep -w ERROR (case-sensitive): the db01 and the disk-full lines. The lowercase 'error' line doesn't count."
}
STEP_2="2xx responses"
step_2() {
  quiz "How many 2xx responses?" "^\s*3\s*$" "200, 201 and 200: grep -cE ' 2[0-9]{2} '."
}
STEP_3="Unique hosts"
step_3() {
  quiz "The unique host names, sorted (space-separated):" "^\s*db01[ ,]+web01[ ,]+web02\s*$" "grep -oE '\\b(web|db)[0-9]+\\b' app.log | sort -u"
}
STEP_4="Config without comments"
step_4() {
  quiz "How many active lines (not comments, not blank) are in /etc/ssh/sshd_config?" "^\s*$(grep -Ev '^\s*(#|$)' /etc/ssh/sshd_config | wc -l)\s*$" "grep -Ev '^\\s*(#|\$)' /etc/ssh/sshd_config. Most settings live in sshd_config.d/ drop-ins."
}
STEP_5="Files mentioning your hostname"
step_5() {
  quiz "Name one file under /etc that contains your hostname." "/etc/(hostname|hosts)" "grep -rl \"\$(hostname -s)\" /etc 2>/dev/null"
}
