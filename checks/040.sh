TITLE="Script basics"
STEP_1="hello.sh"
step_1() {
  local f; f=$(find "$LHOME" -maxdepth 2 -name hello.sh -type f 2>/dev/null | head -1)
  check "hello.sh exists in your home (or ~/bin)" "Create ~/bin/hello.sh as in the topic" test -n "$f"
  [ -n "$f" ] || return 0
  check "it starts with a #! line" "First line: #!/bin/bash" bash -c "head -1 '$f' | grep -q '^#!'"
  check "it is executable" "chmod +x $f" test -x "$f"
  check "it has no syntax errors (bash -n)" "bash -n $f shows the line" bash -n "$f"
}
STEP_2="./ vs source"
step_2() {
  quiz "Where were you after running the 'cd /tmp' script with ./script.sh?" "same|where i (was|started)|original|home|unchanged|didn.?t change" "It ran in a child process; the cd happened there, not in your shell."
  quiz "And after 'source script.sh'?" "^\s*/tmp\s*$" "source runs it in your current shell, so its cd changes your directory."
}
STEP_3="disk-report.sh"
step_3() {
  local f; f=$(find "$LHOME" -maxdepth 2 -name disk-report.sh -type f 2>/dev/null | head -1)
  check "disk-report.sh exists in your home (or ~/bin)" "Write it from the topic" test -n "$f"
  [ -n "$f" ] && check "it has no syntax errors" "bash -n $f" bash -n "$f"
  [ -n "$f" ] && check "it runs with threshold 90 without errors" "as yourself: bash $f 90 ; echo \$?" timeout 20 runuser -u "$LEARNER" -- bash "$f" 90
}
STEP_4="Syntax check"
step_4() {
  quiz "What kind of message did bash -n print for the stray fi?" "syntax error|unexpected" "bash -n parses without running: syntax error near unexpected token 'fi'."
}
