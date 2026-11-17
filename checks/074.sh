TITLE="SELinux booleans, ports and troubleshooting"
STEP_1="Port 8888"
step_1() {
  check_match "port 8888/tcp is labelled http_port_t" "sudo semanage port -a -t http_port_t -p tcp 8888" "^http_port_t\s+tcp\s+.*\b8888\b" semanage port -l
  check_match "the firewall allows 8888/tcp permanently" "sudo firewall-cmd --permanent --add-port=8888/tcp && sudo firewall-cmd --reload" "8888/tcp" firewall-cmd --permanent --list-ports
  check "a web server listens on 8888" "Listen 8888 (httpd) or listen 8888 (nginx), then restart" port_listening 8888
}
STEP_2="Reverse proxy boolean"
step_2() {
  check_match "httpd_can_network_connect is on" "sudo setsebool -P httpd_can_network_connect on" "--> on" getsebool httpd_can_network_connect
  check_match "and it is permanent (-P)" "Use setsebool -P" "httpd_can_network_connect\s+\(on\s*,\s*on\)" semanage boolean -l
}
STEP_3="audit2why vs sealert"
step_3() {
  quiz "Which tool explained the denial and suggested the boolean?" "audit2why|sealert" "Both read the AVC; audit2why is short, sealert gives detailed suggestions."
}
STEP_4="Exporting customisations"
step_4() {
  check "selinux-local.txt exists in your home and lists your changes" "sudo semanage export > ~/selinux-local.txt" bash -c "grep -qE 'port|fcontext|boolean' '$LHOME/selinux-local.txt'"
}
