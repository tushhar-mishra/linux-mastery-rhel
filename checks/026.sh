TITLE="File permissions and umask"
STEP_1="Directory x without r"
step_1() {
  check "/tmp/perm exists and holds a file" "mkdir /tmp/perm && echo hi > /tmp/perm/f" bash -c '[ -d /tmp/perm ] && [ $(find /tmp/perm -maxdepth 1 -type f | wc -l) -ge 1 ]'
  check "/tmp/perm ends the lab as mode 711" "chmod 711 /tmp/perm" test "$(file_mode /tmp/perm)" = 711
  quiz "With the directory at 711, could user B read the file by its exact name? (yes/no)" "^\s*yes" "x on a directory lets you reach names you already know; without r you just can't list them (if the file itself is readable)."
}
STEP_2="Owner class wins"
step_2() {
  quiz "Could you, the owner, read your own file with mode 077? (yes/no)" "^\s*no" "The kernel picks the first matching class (owner) and stops; the group and other bits aren't consulted."
}
STEP_3="umask by hand"
step_3() {
  quiz "With umask 0027, what mode does a new FILE get?" "^\s*0?640\s*$" "666 with the 027 bits switched off = 640."
  quiz "With umask 0033, what mode does a new file get?" "^\s*0?644\s*$" "666 AND NOT 033 = 644 (not 633: it isn't subtraction)."
}
STEP_4="namei"
step_4() {
  quiz "Which permission must every directory on a path give you, to reach a file inside?" "^\s*(x|execute|search)" "x (search) on each parent directory; namei -l shows them all at once."
}
