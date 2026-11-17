TITLE="Samba"
STEP_1="The [team] share"
step_1() {
  if ! command -v testparm >/dev/null; then manual "Run this step on server1, where Samba is installed."; return; fi
  check_match "a [team] share is defined" "Add a [team] section to /etc/samba/smb.conf" "^\[team\]" testparm -s
  check "smb is running" "sudo systemctl enable --now smb" unit_active smb
  check_match "the firewall allows samba" "sudo firewall-cmd --permanent --add-service=samba && sudo firewall-cmd --reload" "samba" firewall-cmd --list-services
}
STEP_2="The share's SELinux label"
step_2() {
  local p; p=$(testparm -s 2>/dev/null | awk '/^\[team\]/{f=1} f && /path =/{print $3; exit}')
  check "the [team] path is labelled samba_share_t" "sudo semanage fcontext -a -t samba_share_t '$p(/.*)?' && sudo restorecon -Rv $p" bash -c "ls -Zd '$p' | grep -q samba_share_t"
}
STEP_3="Removing a member"
step_3() {
  check "demo is no longer in teamshare" "sudo gpasswd -d demo teamshare" not in_group demo teamshare
}
