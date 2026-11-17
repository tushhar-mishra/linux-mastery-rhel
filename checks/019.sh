TITLE="awk"
STEP_1="Users with bash"
step_1() {
  quiz "How many users have /bin/bash as their shell?" "^\s*$(awk -F: '$7=="/bin/bash"' /etc/passwd | wc -l)\s*$" "awk -F: '\$7==\"/bin/bash\" {print \$1, \$7}' /etc/passwd"
}
STEP_2="df over 10%"
step_2() {
  quiz "Which field of 'df -hP' holds Use%? (a number)" "^\s*\\\$?5\s*$" "awk 'NR>1 && \$5+0 > 10' — '+0' turns '42%' into the number 42."
}
STEP_3="Memory per user"
step_3() {
  quiz "What did that ps | awk line show?" "memory|rss|ram" "Total resident memory (RSS) per user, in MB. Shared pages are counted once per process, so it overstates."
}
STEP_4="Dedupe keeping order"
step_4() {
  quiz "The awk program that removes duplicate lines but keeps their order:" "!\s*[A-Za-z_]+\[\\\$0\]\+\+" "awk '!seen[\$0]++' prints a line only the first time it's seen."
}
