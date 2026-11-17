TITLE="Text filters and sed"
STEP_1="Counting login shells"
step_1() {
  local top; top=$(cut -d: -f7 /etc/passwd | sort | uniq -c | sort -rn | awk 'NR==1{print $2}')
  quiz "Which login shell is the most common in /etc/passwd?" "^\s*${top//\//\\/}\s*$" "cut -d: -f7 /etc/passwd | sort | uniq -c | sort -rn"
}
STEP_2="tr"
step_2() {
  local up; up=$(tr 'a-z' 'A-Z' < /etc/hostname | head -1)
  quiz "Your hostname in uppercase?" "^\s*${up//./\\.}\s*$" "tr 'a-z' 'A-Z' < /etc/hostname (tr only reads stdin)."
}
STEP_3="sed -i on a copy"
step_3() {
  check "/tmp/s exists" "sudo cp /etc/ssh/sshd_config /tmp/s && sudo chown \$USER /tmp/s" test -f /tmp/s
  check "/tmp/s has the line 'Port 2222'" "sed -i 's/^#Port 22\$/Port 2222/' /tmp/s" grep -qx 'Port 2222' /tmp/s
  check "only that one line differs from the original" "Start again from a fresh copy if other lines changed" bash -c "[ \$(diff /etc/ssh/sshd_config /tmp/s | grep -c '^[<>]') -eq 2 ]"
}
STEP_4="Printing a range"
step_4() {
  quiz "Which sed command prints lines 5 to 8?" "sed -n '?5,8p'?" "-n turns off automatic printing; 5,8p prints only that range. head -8 | tail -4 does the same."
}
