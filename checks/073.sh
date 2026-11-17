TITLE="SELinux file contexts"
STEP_1="restorecon"
step_1() {
  check "nothing under /var/www/html has the wrong label" "sudo restorecon -Rv /var/www/html" bash -c '[ -z "$(restorecon -Rn /var/www/html 2>/dev/null)" ]'
}
STEP_2="A rule for /srv/web"
step_2() {
  check_match "a local fcontext rule covers /srv/web" "sudo semanage fcontext -a -t httpd_sys_content_t '/srv/web(/.*)?'" "^/srv/web" semanage fcontext -l -C
  check_match "/srv/web is labelled httpd_sys_content_t" "sudo restorecon -Rv /srv/web" "httpd_sys_content_t" ls -Zd /srv/web
}
STEP_3="chcon is temporary"
step_3() {
  quiz "What happened to the chcon label after restorecon?" "revert|back|reset|undone|restored|gone" "restorecon applied the rules again, so the chcon change disappeared."
}
STEP_4="Dry run on /etc"
step_4() {
  quiz "Which restorecon option makes it a dry run?" "-n" "-n: report only, change nothing (-R recursive, -v verbose)."
}
