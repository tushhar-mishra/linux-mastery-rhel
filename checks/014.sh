TITLE="Command substitution, subshells and options"
STEP_2="Quoting \$( )"
step_2() {
  quiz "Which form kept the three names on separate lines: echo \$(…) or echo \"\$(…)\"?" 'quot|"|second|2' "Unquoted, the output is word-split and echo joins the words with spaces. Quoted, the newlines survive."
}
STEP_3="Syntax check and trace"
step_3() {
  quiz "Which bash option checks a script's syntax without running it?" "^\s*(bash )?-n\s*$" "bash -n parses only. bash -x then traces each command as it runs."
}
STEP_4="set -e in a child shell"
step_4() {
  quiz "After 'set -e' and 'false' in the child bash, where did you end up?" "original|parent|first|outer|previous|my (old|first) shell" "set -e made the child shell exit at the failing command; you were back in the shell that started it."
}
