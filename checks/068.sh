TITLE="rsync and backups"
STEP_1="The trailing slash"
step_1() {
  quiz "Where did 'rsync -av src dest/' put the files?" "dest/src" "Without a trailing slash the directory itself is copied, creating dest/src/."
}
STEP_2="Only changes move"
step_2() {
  quiz "How many files did the second rsync transfer?" "^\s*2\s*$" "One changed + one new: rsync compares size and mtime and skips the rest."
}
STEP_3="--delete with -n"
step_3() {
  quiz "What did 'rsync -avn --delete' print for the removed file?" "deleting" "'deleting FILE': the dry run shows what a real run would remove."
}
STEP_4="--link-dest snapshots"
step_4() {
  quiz "In ls -li, how did you see that unchanged files were shared between days?" "same inode|inode|link count|2 links|hard link" "Same inode number, and a link count of 2: one file, two names."
}
