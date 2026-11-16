# 078 · Web Servers: Apache httpd and nginx, Reverse Proxies and Load Balancing

> **You need first:** [077 · auditd](077-auditd.md)
> **Next:** [079 · NFS and autofs](079-nfs-and-autofs.md)

---

## What it is

A **web server** listens on ports 80/443 and answers HTTP requests (topic 070). The two dominant open-source ones:

| | **Apache httpd** | **nginx** ("engine-x") |
|---|---|---|
| Package / service on RHEL | `httpd` | `nginx` |
| Package / service on Ubuntu | `apache2` | `nginx` |
| Main config | `/etc/httpd/conf/httpd.conf` + `conf.d/*.conf` | `/etc/nginx/nginx.conf` + `conf.d/*.conf` |
| Design | Modules, `.htaccess` per-directory overrides, process/thread pools (the **MPM**, Multi-Processing Module; `event` by default) | Event-driven: a few worker processes, each handling thousands of connections |
| Typical role today | Traditional app hosting (PHP), enterprise setups | **Reverse proxy**, load balancer, TLS terminator, static files, Kubernetes ingress |

Key roles:
- **Static file server:** sends files from a **DocumentRoot** (`/var/www/html`).
- **Virtual hosts** (server blocks in nginx): several websites on one IP, chosen by the `Host` header.
- **Reverse proxy:** receives client requests and **forwards** them to backend applications (a Python/Java/Node app on `localhost:8080`), then returns the answer. Clients never talk to the app directly.
- **Load balancer:** a reverse proxy that spreads requests across **several** backends.
- **TLS termination:** the proxy handles HTTPS and talks plain HTTP (or new TLS) to the backends.

## Why it exists

Application servers shouldn't face the internet directly. A reverse proxy in front gives one place for TLS certificates, compression, caching, rate limits, security headers, logging and load balancing, and lets you restart or scale backends without clients noticing. This pattern is **everywhere**: classic VMs, Docker Compose stacks and Kubernetes ingress controllers (very often nginx).

## Analogy

The web server is a **hotel reception desk**. Guests (clients) never wander into the kitchen (the app). They give their request to reception. Reception answers simple questions itself (static files), and passes meal orders through the kitchen hatch (proxying to the backend). With several kitchens, reception sends each order to whichever kitchen is free (load balancing). The receptionist also checks IDs at the door (TLS) and keeps the guest book (access logs).

## How it works inside

### What happens for a request

1. The server's **master process** (running as root, so it may bind ports below 1024) has opened sockets on 80/443. It starts **worker processes** that run as an unprivileged user (`apache` or `nginx`).
2. A worker accepts the connection, and does the TLS handshake if it's HTTPS (picking the certificate by **SNI**).
3. It reads the request and chooses the **virtual host** by the `Host` header (or SNI); the **first** defined vhost is the default for unknown names.
4. It matches the URL path against **locations** / **directories**:
   - **static:** map the path into the DocumentRoot, check permissions (DAC + SELinux `httpd_sys_content_t`), send the file;
   - **proxy:** open (or reuse) a connection to the backend, forward the request (adding `X-Forwarded-For` / `X-Forwarded-Proto` headers so the app knows the real client), relay the response.
5. It writes a line to the **access log**, and to the **error log** on errors.

**Graceful reload** (`systemctl reload`): the master re-reads the configuration and starts **new** workers; old workers finish their current requests and then exit, so no connections are dropped. Always **test the config first** (`apachectl configtest`, `nginx -t`); a broken config won't load.

### On RHEL, every web server needs three things right

1. **Firewall:** open `http`/`https` (topic 071).
2. **SELinux:** content labelled `httpd_sys_content_t` (073); non-standard ports labelled `http_port_t` (074); **proxying needs `setsebool -P httpd_can_network_connect on`** (nginx runs in the same `httpd_t` domain as Apache).
3. **Permissions:** content readable by the `apache`/`nginx` user; owned by root or a deploy user, **not** writable by the web server (except upload directories).

## Commands

### Apache httpd

```bash
sudo dnf install -y httpd
sudo systemctl enable --now httpd
sudo firewall-cmd --permanent --add-service=http --add-service=https ; sudo firewall-cmd --reload
echo '<h1>Hello from Apache</h1>' | sudo tee /var/www/html/index.html
curl -s localhost
```

| Path | Purpose |
|---|---|
| `/etc/httpd/conf/httpd.conf` | Main config (`Listen`, `User`, `DocumentRoot`, `Include conf.d/*.conf`) |
| `/etc/httpd/conf.d/*.conf` | Your sites, `ssl.conf` |
| `/etc/httpd/conf.modules.d/` | Which modules load |
| `/var/www/html` | Default DocumentRoot |
| `/var/log/httpd/access_log`, `error_log` | Logs |

Ubuntu: `/etc/apache2/`, sites in `sites-available/` enabled with `a2ensite`, modules with `a2enmod`, logs in `/var/log/apache2/`.

**Virtual hosts:**
```apache
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
sudo mkdir -p /var/www/example ; echo 'example.com works' | sudo tee /var/www/example/index.html
sudo apachectl configtest && sudo systemctl reload httpd
curl -H 'Host: example.com' http://localhost/
```
```
Syntax OK
example.com works
```

**Content outside /var/www** (needs a `<Directory>` permission block **and** an SELinux label):
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
sudo semanage fcontext -a -t httpd_sys_content_t '/srv/web(/.*)?' ; sudo restorecon -Rv /srv/web
```

**HTTPS:**
```bash
sudo dnf install -y mod_ssl
```
```apache
<VirtualHost *:443>
    ServerName example.com
    DocumentRoot /var/www/example
    SSLEngine on
    SSLCertificateFile    /etc/pki/tls/certs/example.crt
    SSLCertificateKeyFile /etc/pki/tls/private/example.key
</VirtualHost>
<VirtualHost *:80>
    ServerName example.com
    Redirect permanent / https://example.com/
</VirtualHost>
```
- The private key must be `chmod 600`. TLS versions follow RHEL's crypto policy (TLS 1.2+). Real certificates come from your CA, or from Let's Encrypt via `certbot` (EPEL).

**Reverse proxy:**
```apache
<VirtualHost *:80>
    ServerName app.example.com
    ProxyPreserveHost On
    ProxyPass        / http://127.0.0.1:8080/
    ProxyPassReverse / http://127.0.0.1:8080/
</VirtualHost>
```

### nginx

```bash
sudo dnf install -y nginx
sudo systemctl enable --now nginx
curl -sI localhost | head -2
```
```
HTTP/1.1 200 OK
Server: nginx/1.26.3
```

| Path | Purpose |
|---|---|
| `/etc/nginx/nginx.conf` | Main config (`user`, `worker_processes`, `http {}` block, `include conf.d/*.conf`) |
| `/etc/nginx/conf.d/*.conf` | Your `server {}` blocks |
| `/usr/share/nginx/html` | Default root on RHEL (`/var/www/html` on Ubuntu) |
| `/var/log/nginx/access.log`, `error.log` | Logs |

**A static site:**
```nginx
# /etc/nginx/conf.d/static.conf
server {
    listen 80;
    server_name static.example.com;
    root /srv/static;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
```
- `server_name` selects the vhost. `location` blocks match URL paths. `try_files` = serve the file if it exists, else return 404.

**A reverse proxy with load balancing:**
```nginx
# /etc/nginx/conf.d/app.conf
upstream app_backend {
    least_conn;                          # send to the backend with the fewest active connections
    server 127.0.0.1:8080 max_fails=3 fail_timeout=10s;
    server 10.0.1.12:8080 max_fails=3 fail_timeout=10s;
}

server {
    listen 80;
    server_name app.example.com;
    return 301 https://$host$request_uri;          # force HTTPS
}

server {
    listen 443 ssl;
    http2 on;
    server_name app.example.com;
    ssl_certificate     /etc/pki/tls/certs/app.crt;
    ssl_certificate_key /etc/pki/tls/private/app.key;

    location / {
        proxy_pass http://app_backend;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 5s;
        proxy_read_timeout    60s;
    }

    location /static/ {
        root /srv/app;                    # serve static files directly; don't bother the app
        expires 7d;
    }
}
```
```bash
sudo nginx -t
sudo setsebool -P httpd_can_network_connect on      # let nginx (httpd_t) connect to backends
sudo systemctl reload nginx
```
```
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

| Load-balancing method | Behaviour |
|---|---|
| (default) round-robin | Takes turns |
| `least_conn` | The backend with the fewest active connections |
| `ip_hash` | Same client IP → same backend ("sticky" sessions) |
| `weight=N` on a server | Gets N times more requests |

`max_fails`/`fail_timeout` = **passive** health checks: a backend that keeps failing is skipped for a while. (Active health checks need NGINX Plus or HAProxy.)

**HAProxy** is another very common dedicated load balancer (`dnf install haproxy`), especially for TCP (non-HTTP) load balancing and active health checks.

### Reading logs

```bash
sudo tail -3 /var/log/nginx/access.log
```
```
10.0.0.7 - - [16/Nov/2026:18:30:02 +0000] "GET /api/orders HTTP/2.0" 200 512 "-" "curl/8.12.1"
10.0.0.7 - - [16/Nov/2026:18:30:05 +0000] "POST /api/pay HTTP/2.0" 502 157 "-" "Mozilla/5.0 …"
203.0.113.9 - - [16/Nov/2026:18:30:07 +0000] "GET /.env HTTP/1.1" 404 153 "-" "zgrab/0.x"
```
- Client IP, time, request line (method, path, protocol), **status**, bytes, referer, user agent. The last line is a bot scanning for leaked secrets, which is normal internet background noise.

```bash
awk '$9 ~ /^5/ {print $7}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head    # top 5xx URLs
sudo tail -f /var/log/nginx/error.log
```
```
2026/11/16 18:30:05 [error] 1210#1210: *42 connect() failed (111: Connection refused) while connecting to upstream, client: 10.0.0.7, server: app.example.com, request: "POST /api/pay HTTP/2.0", upstream: "http://10.0.1.12:8080/api/pay"
```
- The error log names the failing **upstream**: here the backend `10.0.1.12:8080` refused the connection, so the app there is down.

### Hardening basics

| Apache | nginx | Purpose |
|---|---|---|
| `ServerTokens Prod`, `ServerSignature Off` | `server_tokens off;` | Hide version numbers |
| `Options -Indexes` | `autoindex off;` (default) | No directory listings |
| `Header always set Strict-Transport-Security "max-age=31536000"` | `add_header Strict-Transport-Security "max-age=31536000" always;` | Force HTTPS in browsers (HSTS) |
| `LimitRequestBody` | `client_max_body_size 10m;` | Cap upload size |

### Try it
1. Install nginx on server1 and serve a static site from `/srv/static` (remember the SELinux label).
2. Run two tiny backends: `python3 -m http.server 8081` and `8082` in different directories (with different `index.html` files). Load-balance them with an `upstream` block and `curl` a few times to see the alternation. Then stop one and watch nginx route around it.
3. Proxy without the SELinux boolean first: see the 502, the `connect() … (13: Permission denied)` in the error log, and the AVC. Then fix it.
4. Add a self-signed certificate (topic 064) and an HTTP→HTTPS redirect.

## Where you'll use it

- **In front of every web application:** TLS, routing by host/path, load balancing, static files, caching, rate limiting.
- **Kubernetes:** the **ingress-nginx** controller is literally nginx reading Ingress objects; Gateway API implementations (Envoy-based ones, NGINX Gateway Fabric) do the same job. Knowing `proxy_pass`, upstreams and 502/504 diagnosis transfers directly.
- **Containers:** an nginx container in front of app containers (Docker Compose) is a classic layout.
- **Incident triage:** 502/503/504 → the proxy is up, but the **backend** is down, slow or unreachable. The proxy's error log names which one.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| **403 Forbidden** | SELinux label, file permissions, a missing `Require all granted` (Apache), no index file | `ls -Z`, `restorecon`, `ausearch -m avc`, check the `<Directory>`/`location` |
| **404** for an existing site | Wrong vhost (`Host` header), wrong root/location | Check `ServerName`/`server_name`; `curl -H 'Host: …'` |
| **502 Bad Gateway** | The backend is down or refused, or **SELinux blocked the proxy connection** | Backend `ss -tlnp`; error log; `setsebool -P httpd_can_network_connect on` |
| **504 Gateway Timeout** | The backend is too slow | Backend performance; `proxy_read_timeout` |
| Won't start: `bind() to 0.0.0.0:8081 failed (13: Permission denied)` | SELinux port label | `semanage port -a -t http_port_t -p tcp 8081` |
| Won't start: `Address already in use` | Another server already holds the port | `ss -tlnp \| grep :80` |
| Fails after a config change | Syntax error | `apachectl configtest` / `nginx -t` before reloading |
| Works locally, not remotely | Firewall, or listening only on 127.0.0.1 | `firewall-cmd --list-all`; `ss -tlnp` |
| The app logs the proxy's IP, not the client's | Missing forwarded headers | `X-Forwarded-For` / `X-Real-IP`, and configure the app to trust the proxy |
| The wrong certificate is served | SNI / server_name mismatch or the default vhost | `openssl s_client -servername NAME` (topic 064) |

## Quick recap

- Apache (`httpd`, `conf.d/*.conf`, `<VirtualHost>`, `apachectl configtest`) and nginx (`nginx`, `conf.d/*.conf`, `server {}`/`location {}`, `nginx -t`). Reload is graceful.
- Reverse proxy = `ProxyPass` / `proxy_pass`; load balancing = an nginx `upstream` (round-robin, `least_conn`, `ip_hash`). Pass `X-Forwarded-*` headers.
- RHEL: firewall + SELinux content labels + port labels + **`httpd_can_network_connect`** for proxying.
- 403 = permissions/labels; 502/504 = backend; read the error log.

**Interview questions**

1. *What is a reverse proxy, and why use one?* A server that receives client requests and forwards them to backend servers. It centralises TLS, routing, load balancing, caching and security, and hides and protects the backends.
2. *nginx returns 502 for a proxied app that works when you curl it directly on the server. What do you check on RHEL?* Whether SELinux allows the proxy to connect (`httpd_can_network_connect`, check AVCs), whether the upstream address and port are right, and the nginx error log for the exact upstream error.
3. *How does a server host several websites on one IP?* Name-based virtual hosting: it picks the site by the HTTP `Host` header (and by SNI for HTTPS certificates).
