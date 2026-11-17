TITLE="Inodes and links"
STEP_2="After deleting f"
step_2() {
  check "f was deleted (lab done in your home directory)" "Do the lab in your home directory: touch f; ln f g; ln -s f s; then rm f" not test -e "$LHOME/f"
  check "g is still a regular file, now with 1 link" "g should be a hard link to f, made with 'ln f g'" test -f "$LHOME/g" -a "$(stat -c %h "$LHOME/g" 2>/dev/null)" = 1
  check "s is a symlink that is now broken" "s should be a symlink, made with 'ln -s f s'" bash -c "test -L '$LHOME/s' && ! test -e '$LHOME/s'"
  quiz "Which one still works: g or s?" "^\s*g\s*$" "g is another name for the same inode, so the data lives on. s only stored the name 'f', which no longer exists."
}
STEP_3="The 2 + subdirectories rule"
step_3() {
  quiz "What link count does 'ls -ld /etc' show?" "^\s*$(stat -c %h /etc)\s*$" "A directory has 2 links (its name and its own '.') plus one per subdirectory (each one's '..')."
}
STEP_4="Time zone link"
step_4() {
  local tz; tz=$(readlink /etc/localtime | sed 's|.*zoneinfo/||')
  quiz "Which time zone does /etc/localtime point to?" "${tz//\//\\/}" "/etc/localtime is a symlink into /usr/share/zoneinfo."
}
