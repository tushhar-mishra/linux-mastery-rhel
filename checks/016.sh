TITLE="Redirection and pipes"
STEP_1="Order of 2>&1"
step_1() {
  check_match "a.txt holds the error for /nope (both streams went to the file)" "ls /etc /nope > a.txt 2>&1   (run in your home directory)" "nope" cat "$LHOME/a.txt"
  check "b.txt doesn't hold the error (it went to your screen)" "ls /etc /nope 2>&1 > b.txt" bash -c "test -s '$LHOME/b.txt' && ! grep -q nope '$LHOME/b.txt'"
}
STEP_2="Heredocs"
step_2() {
  quiz "Which heredoc form keeps \$HOME as literal text?" "'EOF'|quot|<<\s*'" "Quoting the delimiter (<<'EOF') turns off all expansion inside the heredoc."
}
STEP_3="sudo and redirection"
step_3() {
  check "/etc/test1 exists and contains 'test'" "echo test | sudo tee /etc/test1" grep -qx test /etc/test1
  quiz "Why did 'sudo echo test > /etc/test1' fail?" "redirect|your (own )?shell|before sudo|not root|shell opens" "Your own, non-root shell opens /etc/test1 for the > before sudo even starts."
}
STEP_4="noclobber"
step_4() {
  quiz "What error did noclobber give?" "cannot overwrite|clobber" "bash: a.txt: cannot overwrite existing file. >| overrides it once."
}
