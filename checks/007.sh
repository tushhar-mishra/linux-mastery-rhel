TITLE="Files and directories"
STEP_1="The ~/lab tree"
step_1() {
  check "~/lab/a, ~/lab/b and ~/lab/c are directories" "mkdir -p ~/lab/{a,b}, then cp -a ~/lab/a ~/lab/c" test -d "$LHOME/lab/a" -a -d "$LHOME/lab/b" -a -d "$LHOME/lab/c"
  check "~/lab/c/f1 exists (copied with cp -a)" "touch ~/lab/a/f1 before the cp -a" test -f "$LHOME/lab/c/f1"
}
STEP_2="mv keeps the inode"
step_2() {
  check "f1 is now in ~/lab/b, not ~/lab/a" "mv ~/lab/a/f1 ~/lab/b/" test -f "$LHOME/lab/b/f1" -a ! -e "$LHOME/lab/a/f1"
  quiz "Did the inode number change after the mv?" "^\s*no" "mv within one filesystem only renames: same inode, same data."
}
STEP_3="A file named -x"
step_3() {
  check "the file '-x' is gone from your home directory" "rm -- -x   (or rm ./-x)" not test -e "$LHOME/-x"
}
STEP_4="rmdir"
step_4() {
  quiz "Why did 'rmdir ~/lab/b' fail?" "not empty|non.?empty|contains|has (a )?file|f1" "rmdir only removes empty directories; ~/lab/b still holds f1."
}
