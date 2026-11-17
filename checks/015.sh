TITLE="Command history"
STEP_1="!\$"
step_1() {
  quiz "Where did 'cd !\$' take you after 'ls /etc/ssh'?" "^\s*/etc/ssh/?\s*$" "!\$ is the last argument of the previous command."
}
STEP_2="Quick substitution"
step_2() {
  quiz "What command did '^chronyd^sshd' run?" "systemctl status sshd" "It repeats the last command with the first 'chronyd' replaced by 'sshd'."
}
STEP_3="Ctrl+R"
step_3() { manual "Ctrl+R found an earlier command containing 'tail' (press Ctrl+R again for older matches)."; }
STEP_4="Deleting a secret"
step_4() {
  check "SECRET123 is not in your saved history file" "history -d N, then history -w (or log out cleanly) so the file is rewritten" not grep -q SECRET123 "$LHOME/.bash_history"
}
