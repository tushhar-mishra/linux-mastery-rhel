TITLE="sudo and su"
STEP_1="Group ops and its rule"
step_1() {
  check "group ops exists" "sudo groupadd ops" group_exists ops
  check "ann is in ops" "sudo useradd -G ops ann" in_group ann ops
  check "ben exists and is NOT in ops" "sudo useradd ben" bash -c 'getent passwd ben >/dev/null && ! id -nG ben | tr " " "\n" | grep -qx ops'
  check_match "sudo lets ann restart chronyd without a password" "A drop-in, e.g. visudo -f /etc/sudoers.d/ops:  %ops ALL=(root) NOPASSWD: /usr/bin/systemctl restart chronyd, /usr/bin/systemctl status chronyd" "NOPASSWD: .*systemctl restart chronyd" sudo -l -U ann
  check "sudo -l for ben lists nothing" "ben must not match any rule" not bash -c 'sudo -l -U ben 2>/dev/null | grep -q "may run"'
}
STEP_2="Testing as ann"
step_2() {
  check "ann: 'sudo -n systemctl status chronyd' is allowed" "Check the exact command and path in the rule" runuser -u ann -- sudo -n /usr/bin/systemctl status chronyd
  check "ann: 'sudo -n dnf …' is refused (tested with the harmless 'dnf --version')" "The rule must allow nothing else" not runuser -u ann -- sudo -n dnf --version
}
STEP_3="Drop-in names"
step_3() {
  check "the rule is in a file whose name has no dot" "Rename it back: sudo mv /etc/sudoers.d/ops.conf /etc/sudoers.d/ops" bash -c 'f=$(grep -l "%ops" /etc/sudoers.d/* 2>/dev/null | head -1); [ -n "$f" ] && [[ $(basename "$f") != *.* ]]'
  check "the drop-in is mode 440" "sudo chmod 440 /etc/sudoers.d/ops" bash -c 'f=$(grep -l "%ops" /etc/sudoers.d/* | head -1); [ "$(stat -c %a "$f")" = 440 ]'
  check "visudo -c finds no errors in the drop-in" "sudo visudo -cf /etc/sudoers.d/ops" bash -c 'visudo -cf "$(grep -l "%ops" /etc/sudoers.d/* | head -1)"'
}
STEP_4="Denied attempts"
step_4() {
  local log=/var/log/secure; is_debian && log=/var/log/auth.log
  check_match "the denied attempt by ann is logged (command not allowed)" "As ann, WITHOUT -n: sudo dnf install zsh and type her password; then look in $log or journalctl -t sudo" "ann : command not allowed" bash -c "cat $log 2>/dev/null; journalctl -t sudo --no-pager 2>/dev/null"
}
