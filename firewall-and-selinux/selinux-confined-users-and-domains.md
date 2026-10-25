# SELinux Targeted Policy: Confined Domains & Confined Users

> **Sessions:** S73–S74 · **[Advanced/Optional]** (beyond the RHEL 10 objectives; strengthens *list and identify process context* and troubleshooting) **[Interview Knowledge]**
> **Related:** [SELinux fundamentals](selinux-fundamentals.md) · [File contexts](selinux-file-contexts.md) · [Booleans, ports & troubleshooting](selinux-booleans-ports-troubleshooting.md) · [MLS & MCS](selinux-mls-and-mcs.md) · [sudo](../users-groups-and-permissions/sudo-and-privileged-access.md)

## 1. Overview

RHEL's default **targeted** policy confines **system services** in their own domains (`httpd_t`, `sshd_t`, `named_t`, …). Everything else, including interactive users, runs in **unconfined** domains that are mostly limited only by DAC. Administrators can additionally **confine users** by mapping Linux accounts to restricted SELinux users.

```bash
sestatus | grep -E 'Loaded policy|Current mode'     # targeted / enforcing
ps -eZ | grep -E 'httpd|sshd|unconfined'            # domains of running processes
```

## 2. Confined vs Unconfined Processes

| Domain | Typical processes | Restriction |
|---|---|---|
| Service-specific (`httpd_t`, `sshd_t`, `chronyd_t`) | Daemons started by systemd from labeled executables (`httpd_exec_t` …) | Only what the policy allows |
| `init_t` | systemd (PID 1) | Broad |
| `unconfined_service_t` | Services whose executable has a generic type (e.g., `bin_t`, third-party software in `/opt`) | Almost unrestricted |
| `unconfined_t` | Logged-in users' shells (mapped to `unconfined_u`) | Almost unrestricted (DAC still applies) |

Domain transitions happen on exec: systemd (`init_t`) runs `/usr/sbin/httpd` (`httpd_exec_t`) → `httpd_t`; running a `bin_t` program → `unconfined_service_t`.

```bash
seinfo -aunconfined_domain_type -x | wc -l     # how many unconfined domains (setools-console)
seinfo -adomain -x | wc -l                     # all domains
```

## 3. Lab: Confinement in Action (httpd)

```bash
dnf install -y httpd ; systemctl enable --now httpd
echo 'Hello from RHEL' > /var/www/html/testfile
ls -Z /var/www/html/testfile               # httpd_sys_content_t
curl -s -o /dev/null -w '%{http_code}\n' http://localhost/testfile   # 200

chcon -t samba_share_t /var/www/html/testfile
curl -s -o /dev/null -w '%{http_code}\n' http://localhost/testfile   # 403 — DAC allows, SELinux denies
ausearch -m AVC -ts recent | grep testfile  # scontext=…httpd_t … tcontext=…samba_share_t

restorecon -v /var/www/html/testfile       # back to httpd_sys_content_t → 200
```

**Demonstration only: an unconfined service.** Relabeling `/usr/sbin/httpd` to `bin_t` makes systemd start it in `unconfined_service_t`, and the `samba_share_t` file becomes readable (DAC only). Restore it immediately: `restorecon -v /usr/sbin/httpd; systemctl restart httpd`. Never weaken production services this way. It shows why software in generic locations runs unconfined.

## 4. SELinux Users

```bash
semanage login -l          # Linux login → SELinux user (+ MLS/MCS range)
semanage user -l           # SELinux users → allowed roles
seinfo -u ; seinfo -r      # users / roles in the policy (setools-console)
```

| SELinux user | Role(s) | GUI | Network | `su` / `sudo` | Typical use |
|---|---|---|---|---|---|
| `unconfined_u` | `unconfined_r` | ✔ | ✔ | ✔ / ✔ | **Default** for all logins (incl. root) |
| `guest_u` | `guest_r` | ✘ | ✘ | ✘ / ✘ | Terminal-only restricted accounts |
| `xguest_u` | `xguest_r` | ✔ | Web browser only | ✘ / ✘ | Kiosk / guest desktops |
| `user_u` | `user_r` | ✔ | ✔ | ✘ / ✘ | Unprivileged users |
| `staff_u` | `staff_r` (+ `sysadm_r` via sudo) | ✔ | ✔ | ✘ / ✔ | Operators who sometimes administer |
| `sysadm_u` | `sysadm_r` | — | ✔ | ✔ | Dedicated admins (SSH login off by default: `ssh_sysadm_login`) |
| `system_u` | `system_r`, `object_r` | — | — | — | System processes and files (not for people) |

Running programs from home and `/tmp` is controlled by booleans: `guest_exec_content`, `xguest_exec_content`, `user_exec_content`, `staff_exec_content`.

## 5. Mapping Users

```bash
useradd -Z staff_u alice                         # create with a mapping
semanage login -a -s user_u bob                  # map an existing user (-m to change, -d to remove)
semanage login -l | grep -E 'alice|bob'
ssh alice@localhost 'id -Z'                      # staff_u:staff_r:staff_t:s0-s0:c0.c1023 (needs a REAL login; su keeps the caller's context)
```

### Confine all regular users

```bash
semanage login -a -s staff_u admin1              # FIRST: explicitly map administrators
semanage login -m -s user_u -r s0 __default__    # everyone without an explicit mapping → user_u (at next login)
```

> ⚠️ `user_u` users can't use `su` or `sudo`. Changing `__default__` affects **existing** users too, so map admins first or you lose admin access. The Linux `root` login has its own mapping (unconfined_u by default).

### Confined administrators

```bash
# Option A: sysadm_u (direct admin role)
setsebool -P ssh_sysadm_login on                 # allow SSH logins for sysadm_u
useradd -G wheel -Z sysadm_u admin2

# Option B: staff_u + sudo role transition
useradd -G wheel -Z staff_u admin3
echo 'admin3 ALL=(ALL) TYPE=sysadm_t ROLE=sysadm_r ALL' > /etc/sudoers.d/admin3 ; visudo -c
ssh admin3@localhost
sudo -i ; id -Z                                  # expected: staff_u:sysadm_r:sysadm_t:s0-s0:c0.c1023
```

A confined admin still needs DAC privileges (root via sudo). SELinux roles **limit** what root can do; they don't grant extra rights.

## 6. Production Practices **[Production Practice]**

- Default unconfined users are normal on general-purpose servers; confined users suit high-security, kiosk and multi-user systems.
- Roll out confinement gradually: test with one account, keep a console session, have a recovery plan (`rd.break` / rescue).
- Install third-party services into standard paths, or label them properly, so they run confined rather than as `unconfined_service_t`.

## 7. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `id -Z` unchanged after mapping | Tested with `su -` | Log in via SSH/console |
| Confined user can't `sudo` | `user_u`/`guest_u` | Map to `staff_u` (+ sudo role rule) |
| `sudo -i` still shows `staff_t` | Missing/incorrect `TYPE=sysadm_t ROLE=sysadm_r` | Fix the sudoers rule; `visudo -c` |
| `sysadm_u` can't SSH in | `ssh_sysadm_login` off | `setsebool -P ssh_sysadm_login on` |
| Users can't run scripts in home | `*_exec_content` boolean off | `setsebool -P user_exec_content on` (policy decision) |
| Third-party daemon in `unconfined_service_t` | Generic executable label | Accept, or install a proper policy/labels |

## 8. Interview Questions

| Question | Answer |
|---|---|
| What does "targeted" mean? | Selected services are confined; users and other processes run unconfined. |
| Why might a service run as `unconfined_service_t`? | Its executable has a generic type (e.g., `bin_t`), so there's no transition to a specific domain. |
| How do you confine a user? | Map them to `user_u`/`staff_u`/`guest_u` with `semanage login` (or `useradd -Z`). |
| `user_u` vs `staff_u`? | user_u can't su/sudo; staff_u can sudo (and transition to sysadm_r if configured). |
| Why doesn't `su -` show the new SELinux user? | `su` keeps the caller's context; mappings apply at real logins. |

## 9. Quick Revision

```bash
ps -eZ | grep DOMAIN · *_exec_t → domain transition · bin_t service → unconfined_service_t
semanage login -l | semanage user -l | seinfo -u/-r · useradd -Z staff_u U · semanage login -a|-m|-d -s SEUSER U
semanage login -m -s user_u -r s0 __default__ (map admins first!) · setsebool -P ssh_sysadm_login on
sudoers: U ALL=(ALL) TYPE=sysadm_t ROLE=sysadm_r ALL · verify with a real login: ssh U@localhost 'id -Z'
```

## 10. Cross-References

- [SELinux fundamentals](selinux-fundamentals.md)
- [File contexts](selinux-file-contexts.md)
- [Booleans, ports & troubleshooting](selinux-booleans-ports-troubleshooting.md)
- [MLS & MCS](selinux-mls-and-mcs.md)
- [sudo](../users-groups-and-permissions/sudo-and-privileged-access.md)
