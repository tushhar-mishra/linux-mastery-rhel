TITLE="Finding files"
STEP_2="Largest files"
step_2() {
  quiz "Which find option keeps the search on one filesystem?" "^\s*-?xdev|-mount" "-xdev stops find descending into /proc, /sys and other mounts."
}
STEP_3="SUID files"
step_3() {
  quiz "How many SUID files did you find on this machine (find / -xdev -type f -perm -4000)?" "^\s*$(find / -xdev -type f -perm -4000 2>/dev/null | wc -l)\s*$" "Compare the list with a machine built the same way: anything extra deserves a question."
}
STEP_4="Safe deletion with -print0"
step_4() {
  check "/tmp/x exists" "mkdir /tmp/x && touch '/tmp/x/a b.txt' /tmp/x/c.txt" test -d /tmp/x
  check "'a b.txt' and c.txt were deleted" "find /tmp/x -type f -print0 | xargs -0 rm" bash -c 'test ! -e "/tmp/x/a b.txt" -a ! -e /tmp/x/c.txt'
}
STEP_5="locate"
step_5() {
  if is_rhel; then check "plocate is installed" "sudo dnf install -y plocate" rpm -q plocate
  else check "plocate is installed" "sudo apt install -y plocate" dpkg -s plocate; fi
  check "the locate database exists (updatedb has run)" "sudo updatedb" test -s /var/lib/plocate/plocate.db
}
