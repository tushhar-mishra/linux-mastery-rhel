TITLE="SSH"
STEP_1="alice's key"
step_1() {
  check "alice exists" "sudo useradd alice" user_exists alice
  local h; h=$(getent passwd alice | cut -d: -f6)
  check "alice has an Ed25519 key pair" "As alice: ssh-keygen -t ed25519" test -f "$h/.ssh/id_ed25519" -a -f "$h/.ssh/id_ed25519.pub"
  check "the private key is mode 600" "chmod 600 ~/.ssh/id_ed25519" test "$(file_mode "$h/.ssh/id_ed25519")" = 600
  check "alice can log in to server2 with the key, no password" "ssh-copy-id alice@server2, then ssh alice@server2 true" runuser -u alice -- ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new 192.168.56.11 true
}
STEP_2="Permissions on server2"
step_2() {
  quiz "Which sshd message did /var/log/secure on server2 show for the 777 directory?" "bad ownership or modes|Authentication refused" "Authentication refused: bad ownership or modes for directory /home/alice/.ssh"
}
STEP_3="An alias in ~/.ssh/config"
step_3() {
  local h; h=$(getent passwd alice | cut -d: -f6)
  check "alice's ~/.ssh/config defines a Host alias" "Host s2 / HostName 192.168.56.11 / User alice" grep -qiE '^\s*Host\s+\S' "$h/.ssh/config"
  check "~/.ssh/config is mode 600 (or 644)" "chmod 600 ~/.ssh/config" bash -c "[[ \$(stat -c %a '$h/.ssh/config') =~ ^(600|640|644)$ ]]"
}
STEP_4="Changed host key"
step_4() {
  quiz "Which command removes server2's old host key from known_hosts?" "ssh-keygen\s+-R" "ssh-keygen -R server2 (and -R 192.168.56.11)."
}
