# Apache HTTP Server (httpd) on RHEL 10

> **[Advanced/Optional]** (frequently used in exam tasks for SELinux labels/ports and firewall rules)
> **Related:** [firewalld](../firewall-and-selinux/firewalld.md) · [SELinux file contexts](../firewall-and-selinux/selinux-file-contexts.md) · [SELinux ports & booleans](../firewall-and-selinux/selinux-booleans-ports-troubleshooting.md) · [systemd services](../boot-systemd-and-kernel/systemd-targets-and-services.md)

## 1. Install & Start

```bash
dnf install -y httpd
systemctl enable --now httpd
firewall-cmd --permanent --add-service=http ; firewall-cmd --reload
curl http://localhost/
```

| Path | Purpose |
|---|---|
| `/etc/httpd/conf/httpd.conf` | Main config |
| `/etc/httpd/conf.d/*.conf` | Sites, vhosts, ssl.conf |
| `/etc/httpd/conf.modules.d/` | Module loading (MPM: event by default) |
| `/var/www/html` | Default DocumentRoot (`httpd_sys_content_t`) |
| `/var/log/httpd/access_log`, `error_log` | Logs |

## 2. A Basic Site

```bash
echo '<h1>Hello from RHEL.</h1>' > /var/www/html/index.html
ls -lZ /var/www/html/index.html      # root:root 644, httpd_sys_content_t
```

Content should be **readable** by Apache, not owned or writable by it. Only upload or cache directories need write access (`httpd_sys_rw_content_t`).

## 3. Name-Based Virtual Hosts

```apache
# /etc/httpd/conf.d/00-default.conf — first vhost = default for unmatched names
<VirtualHost *:80>
    ServerName server1.example.com
    DocumentRoot /var/www/html
</VirtualHost>

# /etc/httpd/conf.d/example.conf
<VirtualHost *:80>
    ServerName example.com
    ServerAlias www.example.com
    DocumentRoot /var/www/example
    ErrorLog  /var/log/httpd/example_error.log
    CustomLog /var/log/httpd/example_access.log combined
</VirtualHost>
```

```bash
mkdir -p /var/www/example ; echo '<h1>example.com works</h1>' > /var/www/example/index.html
apachectl configtest && systemctl reload httpd
curl -H 'Host: example.com' http://localhost/      # or add example.com to the client's /etc/hosts
```

## 4. Content Outside `/var/www` (SELinux + Directory)

```apache
<VirtualHost *:80>
    ServerName site2.example.com
    DocumentRoot /srv/web
    <Directory /srv/web>
        Require all granted
    </Directory>
</VirtualHost>
```

```bash
semanage fcontext -a -t httpd_sys_content_t '/srv/web(/.*)?'
restorecon -Rv /srv/web
```

## 5. Non-Standard Port

```bash
echo 'Listen 8081' > /etc/httpd/conf.d/port8081.conf      # + a <VirtualHost *:8081> if needed
semanage port -a -t http_port_t -p tcp 8081               # (-m if already assigned elsewhere)
firewall-cmd --permanent --add-port=8081/tcp ; firewall-cmd --reload
systemctl restart httpd ; ss -tlnp | grep 8081
```

## 6. HTTPS

```bash
dnf install -y mod_ssl                 # adds conf.d/ssl.conf and a localhost certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/pki/tls/private/example.key -out /etc/pki/tls/certs/example.crt \
  -subj "/CN=example.com"
chmod 600 /etc/pki/tls/private/example.key
```

```apache
# /etc/httpd/conf.d/ssl-example.conf
<VirtualHost *:443>
    ServerName example.com
    DocumentRoot /var/www/example
    SSLEngine on
    SSLCertificateFile    /etc/pki/tls/certs/example.crt
    SSLCertificateKeyFile /etc/pki/tls/private/example.key
</VirtualHost>

# redirect HTTP → HTTPS (in the port-80 vhost)
<VirtualHost *:80>
    ServerName example.com
    Redirect permanent / https://example.com/
</VirtualHost>
```

```bash
firewall-cmd --permanent --add-service=https ; firewall-cmd --reload
apachectl configtest && systemctl restart httpd
curl -k https://example.com/
```

TLS versions and ciphers follow RHEL's **system-wide crypto policy** (TLS 1.2+ by default). To pin explicitly: `SSLProtocol -all +TLSv1.2 +TLSv1.3`. Public certificates: certbot (EPEL) or your organization's CA.

## 7. Hardening & Tuning

| Setting | Purpose |
|---|---|
| `ServerTokens Prod`, `ServerSignature Off` | Hide version details |
| `Options -Indexes` | No directory listings |
| Least privilege | Content root-owned; write only where needed (`httpd_sys_rw_content_t`) |
| Booleans | Enable only needed ones (`httpd_can_network_connect`, `httpd_enable_homedirs`…) |
| `AddOutputFilterByType DEFLATE text/html text/css application/json` | Compression (mod_deflate is part of `httpd`) |
| MPM event (default) | Check with `httpd -V \| grep MPM` |

## 8. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| 403 Forbidden | SELinux label, Unix perms, missing `Require all granted`, no index + `-Indexes` | `ls -Z`, `restorecon`, `ausearch -m avc`, check `<Directory>` |
| `AH00072: make_sock: could not bind to address …:8081` | SELinux port label missing / port in use | `semanage port -a -t http_port_t …`; `ss -tlnp` |
| Wrong site shown | Name-based vhost order / Host header | First vhost is the default; check `ServerName`, `/etc/hosts` |
| httpd fails to start after SSL changes | Key/cert path, permissions, mismatched pair | `journalctl -u httpd`; `apachectl configtest` |
| Works locally, not remotely | Firewall | `firewall-cmd --list-all` |

## 9. Interview Questions

| Question | Answer |
|---|---|
| reload vs restart? | reload re-reads config gracefully without dropping connections; restart stops/starts. |
| What's needed to serve content from `/srv/web`? | DocumentRoot + `<Directory>` with `Require all granted` + `httpd_sys_content_t` label. |
| How does name-based hosting work? | The `Host` header selects the vhost with a matching ServerName/ServerAlias. |
| Port 8081 for Apache? | `Listen 8081`, SELinux `http_port_t`, firewall rule, restart. |

## 10. Quick Revision

```bash
dnf install httpd ; systemctl enable --now httpd ; firewall http/https · apachectl configtest ; systemctl reload httpd
<VirtualHost *:80> ServerName DocumentRoot </VirtualHost> · <Directory /srv/web> Require all granted
semanage fcontext -a -t httpd_sys_content_t '/srv/web(/.*)?' ; restorecon -Rv · semanage port -a -t http_port_t -p tcp PORT
mod_ssl · /etc/pki/tls/{certs,private} · Redirect permanent / https://… · logs /var/log/httpd/
```

## 11. Cross-References

- [firewalld](../firewall-and-selinux/firewalld.md)
- [SELinux file contexts](../firewall-and-selinux/selinux-file-contexts.md)
- [SELinux ports & booleans](../firewall-and-selinux/selinux-booleans-ports-troubleshooting.md)
- [systemd services](../boot-systemd-and-kernel/systemd-targets-and-services.md)
