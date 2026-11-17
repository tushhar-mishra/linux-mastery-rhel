TITLE="Variables and environment"
STEP_1="Local vs exported"
step_1() {
  quiz "What was between the brackets before 'export x'?" "^\s*(\[\s*\]|empty|nothing|blank)" "A plain shell variable isn't copied to child processes."
  quiz "And after 'export x'?" "^\s*\[?1\]?\s*$" "Exported variables are copied into every child's environment."
}
STEP_2="bash vs source"
step_2() {
  check "~/setx.sh exists and sets y=5" "printf '#!/bin/bash\\ny=5\\n' > ~/setx.sh" grep -q 'y=5' "$LHOME/setx.sh"
  quiz "What did 'echo \$y' print after 'source setx.sh'?" "^\s*5\s*$" "source runs the script in your current shell, so y stays set. 'bash setx.sh' ran in a child: nothing."
}
STEP_3="Parameter expansion"
step_3() {
  quiz "Which expansion of \$file prints just 'sshd_config'?" '^\s*"?\$\{file##\*/\}"?\s*$' "\${file##*/} removes the longest match of '*/' from the front (like basename)."
  quiz "Which expansion prints just '/etc/ssh'?" '^\s*"?\$\{file%/\*\}"?\s*$' "\${file%/*} removes the shortest '/*' from the end (like dirname)."
}
STEP_4="Breaking PATH"
step_4() {
  check_match "your login PATH is healthy again (contains /usr/bin)" "Log out and back in, or PATH=/usr/local/bin:/usr/bin:/usr/sbin" "(^|:)/usr/bin(:|$)" runuser -l "$LEARNER" -c 'echo $PATH'
  quiz "What error did 'ls' give with PATH=/nope?" "command not found|no such file" "bash searched only /nope and found no ls. Builtins like cd and echo still worked."
}
