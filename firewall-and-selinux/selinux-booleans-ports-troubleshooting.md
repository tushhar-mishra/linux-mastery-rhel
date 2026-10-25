# SELinux Booleans, Port Labels & Troubleshooting

> **Sessions:** S76–S77 (port labels and the full troubleshooting workflow **supplemented**) · **Objectives:** *Use Boolean settings to modify system SELinux settings* · *Manage SELinux port labels* **[RHCSA Core]**
> **Related:** [SELinux fundamentals](selinux-fundamentals.md) · [File contexts](selinux-file-contexts.md) · [firewalld](firewalld.md) · [SSH hardening (port change)](../networking-and-ssh/ssh-server-hardening.md) · [auditd](auditd.md)

## 1. Overview

When SELinux blocks a legitimate action, the fix is almost always one of three things:

| Cause | Fix |
|---|---|
| Wrong **file label** | `semanage fcontext` + `restorecon` ([file contexts](selinux-file-contexts.md)) |
| Optional behavior **off** | Turn on a **Boolean** (`setsebool -P`) |
| Service on a **non-standard port** | Add a **port label** (`semanage port -a`) |

Only in rare cases do you need a custom policy module (`audit2allow`). **Never** disable SELinux as a fix.

## 2. Booleans **[RHCSA Core]**

Booleans are on/off switches built into the policy for optional behaviors.

```bash
getsebool -a | grep httpd                       # current values
getsebool httpd_enable_homedirs
semanage boolean -l | grep httpd_enable_homedirs   # (current, default) + description
semanage boolean -l -C                          # booleans you changed from default
setsebool httpd_enable_homedirs on              # runtime only (lost at reboot)
setsebool -P httpd_enable_homedirs on           # persistent (use this in the exam)
```

| Boolean | Allows |
|---|---|
| `httpd_enable_homedirs` | Apache serving `~/public_html` |
| `httpd_can_network_connect` | httpd making outbound network connections (proxies, APIs) |
| `httpd_can_network_connect_db` | httpd connecting to database ports |
| `httpd_use_nfs` / `httpd_use_cifs` | httpd reading NFS / CIFS content |
| `samba_enable_home_dirs` / `samba_export_all_rw` | Samba sharing homes / any directory read-write |
| `ftpd_anon_write`, `ftpd_full_access` | vsftpd write access |
| `use_nfs_home_dirs` | Home directories on NFS |
| `ssh_sysadm_login` | SSH logins for `sysadm_u` users |

**Finding the right boolean:** `semanage boolean -l | grep -i <service>`; `sealert` usually names it. Service policy man pages (`man httpd_selinux`, `man ftpd_selinux`) come from the `selinux-policy-doc` package, if it's installed.

## 3. Port Labels **[RHCSA Core]** (supplemented)

Confined services may only bind to ports with the right type, e.g. `http_port_t` for httpd and `ssh_port_t` for sshd.

```bash
semanage port -l | grep -w http_port_t     # http_port_t tcp 80, 81, 443, 488, 8008, 8009, 8443, 9000
semanage port -a -t http_port_t -p tcp 82  # allow httpd on 82
semanage port -m -t http_port_t -p tcp 8080   # port already has ANOTHER type → modify instead of add
semanage port -d -t http_port_t -p tcp 82  # remove a local definition
semanage port -l -C                        # only your custom port labels
```

**Example: Apache on port 82:**

```bash
sed -i 's/^Listen 80$/Listen 82/' /etc/httpd/conf/httpd.conf
systemctl restart httpd            # fails: "AH00072: make_sock: could not bind to address [::]:82" (Permission denied)
semanage port -a -t http_port_t -p tcp 82
firewall-cmd --permanent --add-port=82/tcp ; firewall-cmd --reload
systemctl restart httpd ; ss -tlnp | grep :82 ; curl http://SERVER:82/
```

A non-standard port always needs three things: **service config + SELinux port label + firewall rule**.

## 4. Troubleshooting Workflow

````
1. Reproduce the failure and note the time / service
2. Rule out the basics: is the service running, DAC permissions, firewall, config syntax
3. Look for AVC denials
4. Read the explanation (sealert / audit2why)
5. Apply the right fix: label → boolean → port → (rarely) custom module
6. Verify, and confirm the system is enforcing
````

### Finding denials

```bash
ausearch -m AVC,USER_AVC -ts recent             # last 10 minutes
ausearch -m AVC -c httpd -ts today              # by command name
grep AVC /var/log/audit/audit.log | tail
journalctl -t setroubleshoot --since -10min     # setroubleshoot summaries (needs setroubleshoot-server)
sealert -a /var/log/audit/audit.log             # explanations + suggested commands
sealert -l <ID>                                 # details for one alert ID from the journal
```

### Reading an AVC record

````
type=AVC msg=audit(…): avc:  denied  { getattr } for  pid=32400 comm="httpd"
  path="/var/www/html/testfile" scontext=system_u:system_r:httpd_t:s0
  tcontext=unconfined_u:object_r:samba_share_t:s0 tclass=file permissive=0
````

| Field | Meaning |
|---|---|
| `denied { getattr }` | Permission that was refused |
| `comm` / `pid` | Process |
| `path` / `name` | Target |
| `scontext` | Source **domain** (`httpd_t`) |
| `tcontext` | Target **type** (`samba_share_t`, the wrong label here) |
| `tclass` | Object class (file, dir, tcp_socket …) |
| `permissive=0` | Enforcing (1 = only logged) |

### audit2why / audit2allow **[Advanced]**

```bash
ausearch -m AVC -ts recent | audit2why          # why it was denied (often suggests a boolean)
ausearch -m AVC -c myapp --raw | audit2allow -M mymyapp   # generate a custom module (LAST resort)
cat mymyapp.te                                  # REVIEW what it would allow
semodule -i mymyapp.pp ; semodule -l | grep mymyapp ; semodule -r mymyapp   # install / list / remove
```

Never blindly `audit2allow` everything. Mislabels are fixed with labels, not new allow rules.

### Hidden denials **[Advanced]**

Some denials are suppressed by `dontaudit` rules. `semodule -DB` disables them temporarily; `semodule -B` restores normal behavior.

### Other information tools **[Advanced]**

`avcstat` (AVC statistics), `seinfo` (policy summary: users, roles, types), `sesearch --allow -s httpd_t -t httpd_sys_content_t` (search rules). The last two come from `setools-console`.

## 5. Packages

| Package | Provides |
|---|---|
| `policycoreutils` | `restorecon`, `setsebool`, `semodule`, `load_policy`, `fixfiles` (installed) |
| `libselinux-utils` | `getenforce`, `setenforce`, `getsebool`, `matchpathcon`, `avcstat` (installed) |
| `policycoreutils-python-utils` | **`semanage`**, `audit2allow`, `audit2why`, `chcat` |
| `setroubleshoot-server` | `sealert`, setroubleshootd (started on demand via sedispatch) |
| `setools-console` | `seinfo`, `sesearch`, `sechecker`, `sediff` |
| `selinux-policy-doc` | Per-service `*_selinux` man pages |
| `selinux-policy-mls`, `mcstrans` | MLS policy, level translation |

## 6. RHCSA Exam Focus **[RHCSA Core]**

- Booleans: `setsebool -P` and verify with `getsebool`.
- Ports: `semanage port -a -t <type> -p tcp <port>` (`-m` if already defined) plus the firewall rule; verify with `semanage port -l | grep <port>` and test the service.
- If something fails: `ausearch -m avc -ts recent` → fix the label, boolean or port.
- Make sure `semanage` is available (`dnf install policycoreutils-python-utils` if the task environment allows).
- End state: **enforcing**, everything persistent.

## 7. Production Practices **[Production Practice]**

- Treat AVC denials as configuration bugs to fix, not noise to silence.
- Keep custom modules minimal, reviewed and versioned; prefer booleans and labels.
- Record local customizations: `semanage export > selinux-local.txt` (re-import with `semanage import`).
- Use permissive mode per domain (`semanage permissive -a myapp_t`) rather than system-wide when developing policy.

## 8. Troubleshooting Table

| Symptom | Likely SELinux cause | Fix |
|---|---|---|
| Service can't bind to a custom port | Port not labeled | `semanage port -a/-m` |
| httpd can't serve user home pages | Boolean off + labels | `setsebool -P httpd_enable_homedirs on`; check `user_home_dir_t` perms |
| Web app can't reach a DB/API | `httpd_can_network_connect(_db)` off | `setsebool -P … on` |
| 403 for files in DocumentRoot | Wrong type | `restorecon -Rv` |
| Works in permissive, fails in enforcing | SELinux denial | `ausearch` → label/boolean/port |
| `ValueError: Port tcp/8080 already defined` | Port belongs to another type | `semanage port -m` |
| `setsebool` change lost after reboot | No `-P` | `setsebool -P` |

## 9. Interview Questions

| Question | Answer |
|---|---|
| What's an SELinux Boolean? | A policy switch enabling optional behavior without writing policy (persist with `setsebool -P`). |
| Apache on port 8888: what's needed? | Listen directive, `semanage port -a -t http_port_t -p tcp 8888`, firewall rule, restart. |
| How do you find why SELinux denied something? | `ausearch -m AVC -ts recent`, then `sealert`/`audit2why`. |
| When is `audit2allow` appropriate? | Rarely: for custom applications after labels/booleans/ports are ruled out, and only after reviewing the generated rules. |
| `setsebool` vs `setsebool -P`? | Runtime vs persistent. |

## 10. Quick Revision

```bash
getsebool -a | grep X · semanage boolean -l [-C] · setsebool -P NAME on|off
semanage port -l | grep TYPE · semanage port -a|-m|-d -t TYPE -p tcp PORT · semanage port -l -C
ausearch -m AVC -ts recent [-c CMD] · sealert -a /var/log/audit/audit.log · audit2why · audit2allow -M MOD ; semodule -i MOD.pp (last resort)
fix order: label → boolean → port → module · stay enforcing
```

## 11. Cross-References

- [SELinux fundamentals](selinux-fundamentals.md)
- [File contexts](selinux-file-contexts.md)
- [firewalld](firewalld.md)
- [SSH hardening (port change)](../networking-and-ssh/ssh-server-hardening.md)
