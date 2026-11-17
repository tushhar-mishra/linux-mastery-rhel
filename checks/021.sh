TITLE="Archiving and compression"
STEP_1="Three archives"
step_1() {
  check "/tmp/proj exists with some files" "mkdir /tmp/proj && cp /etc/hosts /etc/services /tmp/proj/" bash -c '[ $(find /tmp/proj -type f | wc -l) -ge 1 ]'
  local n; n=$(find /tmp "$LHOME" -maxdepth 2 \( -name '*.tar.gz' -o -name '*.tgz' -o -name '*.tar.bz2' -o -name '*.tar.xz' \) 2>/dev/null | wc -l)
  note "archives found in /tmp and your home: $n"
  check "gzip, bzip2 and xz archives exist (in /tmp or your home)" "tar -czf proj.tar.gz -C /tmp proj; tar -cjf proj.tar.bz2 …; tar -cJf proj.tar.xz …" test "$n" -ge 3
}
STEP_2="file ignores extensions"
step_2() {
  quiz "Does 'file' trust the file name's extension? (yes/no)" "^\s*no" "file reads the content's magic bytes, so a renamed archive is still recognised."
}
STEP_3="Extracting one file"
step_3() {
  check "/tmp/restore holds at least one extracted file" "mkdir -p /tmp/restore; tar -xf proj.tar.gz -C /tmp/restore proj/hosts" bash -c '[ $(find /tmp/restore -type f | wc -l) -ge 1 ]'
}
STEP_4="Option order"
step_4() {
  quiz "Why did 'tar -cvfz x.tar.gz /tmp/proj' go wrong?" "f.*(argument|next|name|z)|z.*(file|name)|archive (called|named) z" "-f takes the next word as the archive name, so tar wrote an archive called 'z'. Keep f last: -czvf."
}
