TITLE="Your first commands"
STEP_2="Exit statuses"
step_2() {
  quiz "What did 'echo \$?' print after 'ls /etc/hosts'?" "^\s*0\s*$" "0 means success."
  quiz "And after 'ls /nope'?" "^\s*2\s*$" "ls returns 2 for a serious problem such as a missing path; anything non-zero means failure."
}
STEP_3="What kind of command is it?"
step_3() {
  quiz "What kind of command is 'cd'? (builtin, alias, keyword or file)" "builtin" "cd must change the shell's own directory, so it can only be a builtin."
  quiz "And 'ls'?" "alias" "On RHEL and Ubuntu, ls is an alias for 'ls --color=auto'; the file behind it is /usr/bin/ls."
}
