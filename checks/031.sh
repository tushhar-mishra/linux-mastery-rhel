TITLE="Packages: rpm, dnf and apt"
STEP_1="Installing and listing files"
step_1() {
  if is_rhel; then check "htop is installed" "sudo dnf install -y epel-release && sudo dnf install -y htop" rpm -q htop
  else check "htop is installed" "sudo apt install -y htop" dpkg -s htop; fi
  quiz "Which command lists the files an installed RPM put on disk?" "rpm\s+-ql" "rpm -ql PACKAGE (Ubuntu: dpkg -L PACKAGE)."
}
STEP_2="rpm -V"
step_2() {
  is_rhel || { manual "On Ubuntu, use debsums -c instead of rpm -V."; return; }
  check_match "rpm -V reports your change to sshd_config" "Add a comment line to /etc/ssh/sshd_config, then rpm -V openssh-server" "c /etc/ssh/sshd_config" rpm -V openssh-server
  quiz "Which letter in rpm -V's output means the checksum changed?" "^\s*5\s*$" "S = size, 5 = checksum (digest), T = modification time, c = a config file."
}
STEP_3="Undo"
step_3() {
  is_rhel || { manual "On Ubuntu, remove the package with apt remove (apt has no transaction undo)."; return; }
  check_match "dnf history contains an undo transaction" "dnf history list, then sudo dnf history undo ID" "history undo" dnf history list
}
STEP_4="Offline DVD repo"
step_4() {
  is_rhel || return 0
  check_match "a DVD repository is configured" "A .repo file with baseurl=file:///mnt/dvd/BaseOS (and AppStream) (topic 031)" "dvd" dnf repolist --all
  check "zsh is installed" "sudo dnf --disablerepo='*' --enablerepo='dvd-*' install zsh" rpm -q zsh
}
