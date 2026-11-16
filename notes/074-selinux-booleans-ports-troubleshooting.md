# 074 · SELinux Booleans, Port Labels and the Troubleshooting Workflow

> **You need first:** [073 · SELinux file contexts](073-selinux-file-contexts.md)
> **Next:** [075 · SELinux confined users](075-selinux-confined-users.md)

---

## What it is

When SELinux blocks something **legitimate**, the fix is almost always one of three things:

| Cause | Fix | Topic |
|---|---|---|
| A file has the **wrong label** | `semanage fcontext` + `restorecon` | 073 |
| An optional behaviour is **switched off** | Turn on a **boolean** with `setsebool -P` | here |
| A service uses a **non-standard port** | Add a **port label** with `semanage port -a` | here |

- A **boolean** is an on/off switch built into the policy for optional behaviour, such as "may the web server make outbound network connections?" or "may it serve users' home directories?"
- A **port label** gives a network port a type (`http_port_t`, `ssh_port_t`, `postgresql_port_t`). A confined service may only listen on ports of its type.

Only rarely do you need a **custom policy module** (`audit2allow`). **Never** disable SELinux as a fix.

## Why it exists

The policy authors can't know your setup. Booleans let them ship safe defaults (web server can't connect out, can't read NFS) while letting you switch on what you need **without writing policy**. Port labels make "this service may only listen on its ports" enforceable, which blocks a hijacked service from opening a backdoor listener.

## Analogy

The SELinux rulebook (topic 072) has **optional clauses with tick-boxes**: "☐ kitchen staff may use the back door" (a boolean). And every **door** in the building has a coloured sign: kitchen staff may only use **green** doors (port labels). Opening the kitchen on a new door means **painting that door green** (`semanage port -a`), not firing the guard.

## How it works inside

- **Booleans** are compiled into the policy as conditional rules. `setsebool NAME on` flips the switch in the **running** kernel policy immediately. **`-P`** also writes it into the policy store on disk, so it survives reboots. Without `-P`, the change is lost at reboot.
- **Ports:** when a process calls `bind()` (topic 095) to start listening on a port, SELinux checks whether its domain may `name_bind` to that port's type. sshd (`sshd_t`) may bind `ssh_port_t` (22). If you move it to 2222, which is unlabelled (or labelled as something else), the bind is denied: "Permission denied" at startup. `semanage port -a` adds your port to the type, permanently.
- A port can have **only one type**. If 8080 is already `http_cache_port_t`, use `-m` (modify), not `-a`.
- **Denials** are logged to `/var/log/audit/audit.log` as `AVC` records (topic 077). **setroubleshoot** (if installed) turns them into human-readable explanations with suggested fixes.
- **`dontaudit` rules** deliberately hide some expected, harmless denials from the log. If something fails only when enforcing and you see no AVC, those hidden denials are a suspect.

## Commands

### Booleans

```bash
getsebool -a | grep httpd | head -5
```
```
httpd_anon_write --> off
httpd_builtin_scripting --> on
httpd_can_check_spam --> off
httpd_can_connect_ftp --> off
httpd_can_network_connect --> off
```

```bash
sudo semanage boolean -l | grep httpd_can_network_connect
```
```
httpd_can_network_connect      (off  ,  off)  Allow httpd to can network connect
httpd_can_network_connect_db   (off  ,  off)  Allow httpd to can network connect db
```
- `(current, default)` plus a description. `semanage boolean -l -C` lists only booleans you changed.

```bash
sudo setsebool -P httpd_can_network_connect on
getsebool httpd_can_network_connect
```
```
httpd_can_network_connect --> on
```

| Boolean | Allows |
|---|---|
| `httpd_can_network_connect` | The web server opening outbound connections (**reverse proxies, API calls**, topic 078) |
| `httpd_can_network_connect_db` | The web server connecting to database ports |
| `httpd_enable_homedirs` | Serving `~user/public_html` |
| `httpd_use_nfs` / `httpd_use_cifs` | The web server reading NFS / SMB content |
| `samba_enable_home_dirs`, `samba_export_all_ro/rw` | Samba sharing homes / any directory (topic 080) |
| `ftpd_anon_write`, `ftpd_full_access` | FTP write access (topic 082) |
| `use_nfs_home_dirs` | Home directories on NFS (topic 079) |
| `container_manage_cgroup` | Containers running systemd inside |

Find a boolean: `semanage boolean -l | grep -i SERVICE`, or read `sealert`'s suggestion. Per-service SELinux man pages (`man httpd_selinux`) come from the `selinux-policy-doc` package.

### Port labels

```bash
sudo semanage port -l | grep -w http_port_t
```
```
http_port_t                    tcp      80, 81, 443, 488, 8008, 8009, 8443, 9000
```

```bash
sudo semanage port -a -t http_port_t -p tcp 8888     # add
sudo semanage port -m -t http_port_t -p tcp 8080     # 8080 already belongs to another type → modify
sudo semanage port -d -t http_port_t -p tcp 8888     # delete your definition
sudo semanage port -l -C                             # only your customisations
```

**A non-standard port always needs three things:** the service config + the SELinux port label + the firewall rule (topic 071). Example with the web server (topic 078):
```bash
sudo sed -i 's/^Listen 80$/Listen 8888/' /etc/httpd/conf/httpd.conf
sudo systemctl restart httpd
```
```
Job for httpd.service failed because the control process exited with error code.
```
```bash
sudo journalctl -u httpd -n 3 --no-pager
```
```
httpd[6120]: (13)Permission denied: AH00072: make_sock: could not bind to address [::]:8888
httpd[6120]: (13)Permission denied: AH00072: make_sock: could not bind to address 0.0.0.0:8888
```
```bash
sudo semanage port -a -t http_port_t -p tcp 8888
sudo firewall-cmd --permanent --add-port=8888/tcp && sudo firewall-cmd --reload
sudo systemctl restart httpd && ss -tln | grep 8888
```

### The troubleshooting workflow

```
1. Reproduce the failure; note the time and the service.
2. Rule out the basics: is the service running? DAC permissions? firewall? config syntax?
3. Look for AVC denials.
4. Read the explanation (sealert / audit2why).
5. Apply the right fix: label → boolean → port → (rarely) custom module.
6. Verify, and confirm the system is still enforcing.
```

```bash
sudo ausearch -m AVC,USER_AVC -ts recent              # last 10 minutes
sudo ausearch -m AVC -c httpd -ts today               # only httpd, today
sudo journalctl -t setroubleshoot --since -10min      # summaries
sudo sealert -a /var/log/audit/audit.log              # full explanations + suggested commands
```

### Reading an AVC record

```
type=AVC msg=audit(1763317001.120:520): avc:  denied  { name_connect } for  pid=1210 comm="httpd"
  dest=8080 scontext=system_u:system_r:httpd_t:s0
  tcontext=system_u:object_r:http_cache_port_t:s0 tclass=tcp_socket permissive=0
```

| Field | Meaning |
|---|---|
| `denied { name_connect }` | The permission refused (here: connect out to a port) |
| `comm` / `pid` | Which process |
| `path` / `name` / `dest` | The target (a file path, or a port) |
| `scontext` | The **source domain** (`httpd_t`) |
| `tcontext` | The **target's type** (`http_cache_port_t`) |
| `tclass` | The object class (`file`, `dir`, `tcp_socket`…) |
| `permissive=0` | It was really blocked (1 = only logged) |

Here the web server (as a reverse proxy) tried to connect to port 8080 → the fix is `setsebool -P httpd_can_network_connect on`.

```bash
sudo ausearch -m AVC -ts recent | audit2why
```
```
	Was caused by:
	The boolean httpd_can_network_connect was set incorrectly.
	Allow access by executing:
	# setsebool -P httpd_can_network_connect 1
```

### Custom modules: the last resort

```bash
sudo ausearch -m AVC -c myapp --raw | audit2allow -M myapp_local
cat myapp_local.te                    # REVIEW exactly what it would allow
sudo semodule -i myapp_local.pp
sudo semodule -l | grep myapp_local ; sudo semodule -r myapp_local   # list / remove
```
- Only for genuinely custom applications, after labels, booleans and ports have been ruled out. **Never** `audit2allow` a mislabelled file: that permanently teaches the policy to allow a wrong access.

### Hidden denials

```bash
sudo semodule -DB      # disable dontaudit rules (logs EVERYTHING; noisy)
# reproduce, then ausearch …
sudo semodule -B       # restore normal behaviour
```

### Debug without turning everything off

```bash
sudo semanage permissive -a httpd_t     # only httpd's domain is permissive
# reproduce, collect all its AVCs, fix them …
sudo semanage permissive -d httpd_t
```

### Packages

| Package | Provides |
|---|---|
| `policycoreutils` | `restorecon`, `setsebool`, `semodule`, `fixfiles` |
| `libselinux-utils` | `getenforce`, `setenforce`, `getsebool`, `matchpathcon` |
| `policycoreutils-python-utils` | **`semanage`**, `audit2allow`, `audit2why` |
| `setroubleshoot-server` | `sealert` |
| `setools-console` | `seinfo`, `sesearch` (query the policy) |
| `selinux-policy-doc` | `*_selinux` man pages |

### Try it
1. Move your web server to port 8888: watch it fail, read the AVC, add the label and the firewall rule, and succeed.
2. Configure the web server as a reverse proxy to `localhost:3000` (topic 078), see the 503 and the `name_connect` denial, then fix it with the boolean.
3. Run `audit2why` on a denial and compare its advice with `sealert`'s.
4. Export your customisations: `sudo semanage export > selinux-local.txt`.

## Where you'll use it

- **Reverse proxies** (nginx/Apache → app servers): `httpd_can_network_connect` is the #1 boolean in production.
- **Custom ports** for any service: label first.
- **Configuration management:** Ansible's `seboolean`, `seport` and `sefcontext` modules (or the `selinux` system role) keep these settings in code; `semanage export/import` copies them between hosts.
- **Incident response:** "it broke after an update / a move / a port change" → `ausearch -m AVC -ts recent` within the first minute.

## When it breaks

| Symptom | Likely SELinux cause | Fix |
|---|---|---|
| A service can't start on a custom port | The port isn't labelled | `semanage port -a/-m` |
| A reverse proxy returns 502/503; the backend is fine | `httpd_can_network_connect` is off | `setsebool -P httpd_can_network_connect on` |
| A web app can't reach its database | `httpd_can_network_connect_db` is off | `setsebool -P … on` |
| 403 for files in the DocumentRoot | Wrong file type | `restorecon -Rv` (topic 073) |
| Works when permissive, fails when enforcing, no AVC visible | Hidden by dontaudit | `semodule -DB`, reproduce, `semodule -B` |
| `ValueError: Port tcp/8080 already defined` | The port belongs to another type | `semanage port -m` |
| A boolean reverted after reboot | It was set without `-P` | `setsebool -P` |

## Quick recap

- Fixes in order: **label** (073) → **boolean** (`setsebool -P`) → **port** (`semanage port -a/-m`) → custom module (rarely, reviewed).
- Booleans: `getsebool -a`, `semanage boolean -l [-C]`, always `-P`. Ports: `semanage port -l`, `-a`/`-m`/`-d`, `-l -C`.
- A new port = service config + SELinux label + firewall.
- Find denials: `ausearch -m AVC -ts recent`, `sealert -a`, `audit2why`. Debug one domain with `semanage permissive -a DOMAIN`.

**Interview questions**

1. *What is an SELinux boolean?* A switch in the policy that turns an optional behaviour on or off (for example `httpd_can_network_connect`) without writing policy. `setsebool -P` makes the change permanent.
2. *What's needed to run Apache on port 8888 on RHEL?* The `Listen 8888` directive, `semanage port -a -t http_port_t -p tcp 8888`, a firewall rule for 8888/tcp, and a restart.
3. *When is `audit2allow` appropriate?* Rarely: for custom applications, once labels, booleans and ports have been ruled out, and only after reviewing the generated rules. Never for mislabelled files.
