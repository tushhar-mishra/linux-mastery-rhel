TITLE="Shell startup files"
STEP_1="Login vs non-login"
step_1() {
  check "~/.bash_profile exports GREETING" "echo 'export GREETING=hi' >> ~/.bash_profile" grep -q 'GREETING=hi' "$LHOME/.bash_profile"
  quiz "Which one printed 'hi': 'bash' or 'bash -l'?" "-l|login" "Only login shells read ~/.bash_profile."
}
STEP_2="profile.d for everyone"
step_2() {
  check "/etc/profile.d/hello.sh exists" "sudo tee /etc/profile.d/hello.sh <<< 'hello() { echo \"Hello, \$USER\"; }'" test -f /etc/profile.d/hello.sh
  check_match "a login shell has the hello function" "Check the function syntax in /etc/profile.d/hello.sh" "^function$" runuser -l "$LEARNER" -c 'type -t hello'
}
STEP_3="No output from .bashrc"
step_3() {
  check "~/.bashrc doesn't print 'Welcome!' unguarded" "Remove the line, or guard it: [[ \$- == *i* ]] && echo \"Welcome!\"" not grep -Eq '^\s*echo "?Welcome' "$LHOME/.bashrc"
  check "a non-interactive shell prints nothing" "Something in a startup file prints output: find it with bash -lx -c exit" bash -c "[ -z \"\$(runuser -u '$LEARNER' -- bash -c true 2>/dev/null)\" ]"
}
STEP_4="Tracing startup"
step_4() { manual "bash -lx -c exit showed /etc/profile, the profile.d scripts, ~/.bash_profile and ~/.bashrc being read in order."; }
