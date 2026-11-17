TITLE="SELinux MLS and MCS"
STEP_1="Two containers"
step_1() {
  quiz "Which part of the two containers' ps -eZ labels differed?" "categor|c[0-9]+|mcs|level|s0:" "Both run as container_t; each has its own pair of MCS categories, like s0:c123,c456."
}
STEP_2="A :Z volume"
step_2() {
  quiz "Which type did the host directory get after ':Z'?" "container_file_t" "Plus the container's own categories, so only that container can use it."
}
STEP_3="setrans.conf"
step_3() {
  quiz "What does setrans.conf translate?" "level|categor|name|human|label" "Raw levels/categories (s0:c0.c1023) into readable names (SystemLow-SystemHigh)."
}
