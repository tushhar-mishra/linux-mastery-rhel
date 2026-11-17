TITLE="XFS quotas"
STEP_1="User limits"
step_1() {
  check "an XFS filesystem is mounted with user, group and project quotas" "UUID=… /shared xfs defaults,uquota,gquota,pquota 0 0, then umount + mount" bash -c 'findmnt -rno OPTIONS -t xfs | grep -q usrquota && findmnt -rno OPTIONS -t xfs | grep -q grpquota && findmnt -rno OPTIONS -t xfs | grep -q prjquota'
  check_match "a user has a 150 MiB hard block limit" "sudo xfs_quota -x -c 'limit bsoft=100m bhard=150m USER' /shared" "150M" bash -c 'for m in $(findmnt -rno TARGET -t xfs -O usrquota); do xfs_quota -x -c "report -uh" "$m"; done'
}
STEP_2="Inode limit"
step_2() {
  quiz "How many of 'touch f{1..20}' succeeded with an inode hard limit of 15?" "^\s*1[0-5]\s*$" "The user's existing files count too, so fewer than 15 new files fit; the rest failed with 'Disk quota exceeded'."
}
STEP_3="Project quota"
step_3() {
  check "/etc/projid has the webapp project" "echo 'webapp:11' | sudo tee -a /etc/projid" grep -qE '^webapp:' /etc/projid
  check "/etc/projects maps it to a directory" "echo '11:/shared/webapp' | sudo tee -a /etc/projects" grep -qE "^$(awk -F: '/^webapp:/{print $2}' /etc/projid):/" /etc/projects
  check_match "the project has a block limit" "sudo xfs_quota -x -c 'project -s webapp' /shared; sudo xfs_quota -x -c 'limit -p bhard=… webapp' /shared" "webapp" bash -c 'for m in $(findmnt -rno TARGET -t xfs -O prjquota); do xfs_quota -x -c "report -pbh" "$m"; done'
}
