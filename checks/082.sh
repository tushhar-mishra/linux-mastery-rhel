TITLE="FTP: vsftpd"
STEP_1="Anonymous download"
step_1() {
  check "vsftpd is running" "sudo systemctl enable --now vsftpd" unit_active vsftpd
  check "anonymous access is enabled" "anonymous_enable=YES in /etc/vsftpd/vsftpd.conf" grep -qE '^\s*anonymous_enable\s*=\s*YES' /etc/vsftpd/vsftpd.conf
  check "curl can list ftp://localhost/" "Check the firewall (service ftp) and vsftpd's log" curl -s --max-time 5 ftp://localhost/
}
STEP_2="Anonymous upload"
step_2() {
  quiz "Which FTP reply code did the upload get after you removed the boolean?" "^\s*553\s*$" "553 Could not create file: SELinux (ftpd_anon_write off) blocked the write."
}
STEP_3="Clear text"
step_3() {
  quiz "Which FTP commands carried the user name and password in your capture?" "USER.*PASS|PASS.*USER" "USER bob / PASS secret: readable by anyone on the path."
}
STEP_4="sftp"
step_4() {
  quiz "Which port and protocol does sftp use?" "22|ssh" "SFTP runs inside SSH on port 22: one encrypted connection."
}
