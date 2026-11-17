TITLE="Arithmetic"
STEP_1="Inode percentage"
step_1() {
  local p; p=$(df -i / | awk 'NR==2 && $2>0 {printf "%d", $3*100/$2}')
  [ -z "$p" ] && { manual "Your root filesystem reports no inode counts (some filesystems don't)."; return; }
  quiz "What percentage of inodes on / is used (integer)?" "^\s*($((p>0?p-1:0))|$p|$((p+1)))\s*%?\s*$" "used*100/total with \$(( )): multiply first, then divide, or the integer division gives 0."
}
STEP_2="Average with awk"
step_2() {
  quiz "What did seq 1 10 | awk average to?" "^\s*5\.5\s*$" "awk does floating-point maths; bash can't."
}
STEP_3="Octal"
step_3() {
  quiz "How did you fix m=08 so \$((m+1)) works?" "10#" "\$((10#\$m + 1)): force base 10. A leading 0 means octal."
}
STEP_4="bc"
step_4() {
  quiz "8589934592 bytes in GiB, 2 decimals?" "^\s*8\.00\s*$" "echo 'scale=2; 8589934592/1024^3' | bc"
}
