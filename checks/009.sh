TITLE="Viewing files"
STEP_1="Counting lines"
step_1() {
  quiz "How many lines does /etc/os-release have?" "^\s*$(wc -l < /etc/os-release)\s*$" "wc -l counts newline characters, so it matches cat -n's last number when the file ends with a newline."
}
STEP_2="less"
step_2() { manual "In less: G jumped to the end, ?sshd searched backwards, n repeated the search."; }
STEP_3="tail -F"
step_3() { manual "Your new SSH login appeared live in 'tail -F' of the auth log (/var/log/secure; Ubuntu /var/log/auth.log)."; }
STEP_4="Windows line endings"
step_4() {
  check "~/win.txt exists and has Windows (CRLF) line endings" "cd ~ ; printf 'a\\r\\nb\\r\\n' > win.txt" grep -q $'\r' "$LHOME/win.txt"
  quiz "What does 'cat -A win.txt' show at the end of each line?" '\^M' "^M is the carriage return (\\r), and \$ marks the end of the line."
}
