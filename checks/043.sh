TITLE="Loops"
STEP_3="Pipes and subshells"
step_3() {
  quiz "Which counter kept its value: 'ps | while read' or 'done < <(ps …)'?" "<\s*<|process substitution|second|done <" "The pipe ran the loop in a subshell, so its counter vanished; done < <(cmd) runs it in your shell."
}
STEP_4="until"
step_4() {
  check "/tmp/ready exists (you created it from another terminal)" "touch /tmp/ready" test -e /tmp/ready
}
