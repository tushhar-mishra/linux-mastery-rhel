TITLE="PAM and authselect"
STEP_1="authselect and the sshd stack"
step_1() {
  if is_rhel; then
    quiz "Which authselect profile is current?" "$(authselect current 2>/dev/null | awk -F': ' '/Profile ID/{print $2}')" "authselect current shows the profile (local or sssd) and its enabled features."
  else
    quiz "Which file does /etc/pam.d/sshd include for authentication on Ubuntu?" "common-auth" "Ubuntu's shared stacks are the common-* files, managed by pam-auth-update."
  fi
}
STEP_2="Password length"
step_2() {
  check "pwquality requires at least 12 characters" "minlen = 12 in /etc/security/pwquality.conf (or a file in pwquality.conf.d/)" bash -c "grep -hE '^\s*minlen\s*=\s*([2-9][0-9]|1[2-9])' /etc/security/pwquality.conf /etc/security/pwquality.conf.d/*.conf 2>/dev/null | grep -q ."
}
STEP_3="faillock"
step_3() {
  if is_rhel; then check_match "authselect has the with-faillock feature" "sudo authselect enable-feature with-faillock" "with-faillock" authselect current; fi
  check "faillock.conf has deny = 3" "deny = 3 in /etc/security/faillock.conf" grep -qE '^\s*deny\s*=\s*3\b' /etc/security/faillock.conf
  quiz "Which command showed the failures for your test user?" "faillock\s+--user" "faillock --user NAME shows them; add --reset to clear."
}
STEP_4="Limits"
step_4() {
  check "a nofile limit is set for a user in limits.conf or limits.d" "e.g. echo 'testuser - nofile 4096' | sudo tee /etc/security/limits.d/90-testuser.conf" bash -c "grep -hE '^\s*[^#[:space:]]+\s+(soft|hard|-)\s+nofile\s+[0-9]+' /etc/security/limits.conf /etc/security/limits.d/*.conf 2>/dev/null | grep -q ."
}
