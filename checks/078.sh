TITLE="Web servers: Apache and nginx"
STEP_1="Static site from /srv/static"
step_1() {
  check "nginx is installed and running" "sudo dnf install -y nginx && sudo systemctl enable --now nginx" unit_active nginx
  check "an nginx config serves root /srv/static" "root /srv/static; in a server block under /etc/nginx/conf.d/" bash -c 'grep -rqsE "^\s*root\s+/srv/static\s*;" /etc/nginx/'
  check_match "/srv/static is labelled httpd_sys_content_t" "sudo semanage fcontext -a -t httpd_sys_content_t '/srv/static(/.*)?'; sudo restorecon -Rv /srv/static" "httpd_sys_content_t" ls -Zd /srv/static
  check "nginx -t passes" "sudo nginx -t" nginx -t
}
STEP_2="Load balancing"
step_2() {
  check "an upstream block is configured" "upstream backends { server 127.0.0.1:8081; server 127.0.0.1:8082; }" bash -c 'grep -rqsE "^\s*upstream\s+\S+\s*\{" /etc/nginx/'
}
STEP_3="The proxy boolean"
step_3() {
  check_match "httpd_can_network_connect is on" "sudo setsebool -P httpd_can_network_connect on" "--> on" getsebool httpd_can_network_connect
  quiz "What did nginx's error log say before you set the boolean?" "13: Permission denied|permission denied" "connect() to 127.0.0.1:8081 failed (13: Permission denied): SELinux, not the file system."
}
STEP_4="TLS and the redirect"
step_4() {
  check "nginx listens on 443" "listen 443 ssl; with ssl_certificate / ssl_certificate_key" bash -c 'ss -Htlnp "sport = :443" | grep -q nginx'
  check_match "http:// redirects to https://" "return 301 https://\$host\$request_uri; in the port-80 server" "^HTTP/[0-9.]+ 30[18].*|^[Ll]ocation: https://" curl -4 -sI http://localhost/
}
