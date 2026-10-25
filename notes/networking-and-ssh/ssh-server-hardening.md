# SSH Server Configuration & Hardening

> Supports *Configure key-based authentication for SSH* **[RHCSA Core]** · hardening **[Production Practice]**
> **Related:** [SSH remote access](ssh-remote-access.md) · [sudo](../users-groups-and-permissions/sudo-and-privileged-access.md) · [firewalld](../firewall-and-selinux/firewalld.md) · [SELinux port labels](../firewall-and-selinux/selinux-booleans-ports-troubleshooting.md#3-port-labels-rhcsa-core-supplemented)

## 1. Overview

`sshd` reads `/etc/ssh/sshd_config`. On RHEL that file begins with `Include /etc/ssh/sshd_config.d/*.conf`, and **for each keyword the first value sshd encounters wins**. Drop-in files (read in alphabetical order) therefore override what's set later in the main file.

| Drop-in (examples) | Origin |
|---|---|
| `01-permitrootlogin.conf` | Created by the installer if you allowed root SSH password login |
| `40-redhat-crypto-policies.conf` | System-wide crypto policies |
| `50-redhat.conf` | Red Hat defaults (e.g., `X11Forwarding yes`) |

**Best practice:** put your settings in an early drop-in such as `/etc/ssh/sshd_config.d/00-local.conf`, then check what sshd will actually use:

```bash
sshd -t                                   # syntax check (no output = OK)
sshd -T | grep -Ei 'permitrootlogin|passwordauthentication|^port|allowusers|banner'   # effective settings
systemctl reload sshd                     # apply (existing sessions stay open)
```

> ⚠️ Keep your current session open and test a **new** login before closing it. A mistake can lock you out.

## 2. Common Settings

````
# /etc/ssh/sshd_config.d/00-local.conf
PermitRootLogin no                 # or prohibit-password (keys only; OpenSSH default)
PasswordAuthentication no          # ONLY after key logins are confirmed working
PubkeyAuthentication yes
Banner /etc/ssh/sshd-banner
MaxAuthTries 3
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 2
AllowGroups sshusers wheel
````

| Keyword | Meaning |
|---|---|
| `PermitRootLogin` | `yes` / `no` / `prohibit-password` (keys only) / `forced-commands-only` |
| `PasswordAuthentication` | Allow password logins |
| `PubkeyAuthentication` | Allow key logins (default yes) |
| `Port` | Listening port(s) |
| `Banner` | File shown **before** authentication |
| `AllowUsers` / `DenyUsers` | User patterns (`alice`, `bob@192.168.1.*`) |
| `AllowGroups` / `DenyGroups` | Primary or supplementary group membership |
| `MaxAuthTries`, `LoginGraceTime` | Brute-force limits |
| `ClientAliveInterval/CountMax` | Drop dead sessions |
| `X11Forwarding`, `AllowTcpForwarding` | Forwarding features |
| `Match User/Group/Address …` | Conditional settings block **[Advanced]** |

## 3. Login Banner

```bash
cat > /etc/ssh/sshd-banner <<'EOF'
*******************************************************************
* WARNING: Authorized users only. Activity is monitored and logged. *
*******************************************************************
EOF
echo 'Banner /etc/ssh/sshd-banner' > /etc/ssh/sshd_config.d/00-local.conf
sshd -t && systemctl reload sshd
ssh alice@server            # banner appears before the password/key prompt
```

`/etc/motd` (and `/etc/motd.d/`) is shown **after** login.

## 4. Disable Root Login

```bash
grep -r PermitRootLogin /etc/ssh/sshd_config /etc/ssh/sshd_config.d/   # find every occurrence
echo 'PermitRootLogin no' >> /etc/ssh/sshd_config.d/00-local.conf       # 00- sorts before 01-permitrootlogin.conf
sshd -T | grep -i permitrootlogin                                       # → permitrootlogin no
systemctl reload sshd
ssh root@server            # → Permission denied ; admins log in as themselves and use sudo
```

## 5. Change the SSH Port (with SELinux) **[RHCSA-relevant: SELinux ports]**

```bash
semanage port -l | grep ssh_port_t                   # ssh_port_t tcp 22
semanage port -a -t ssh_port_t -p tcp 2222           # label the new port FIRST (policycoreutils-python-utils)
firewall-cmd --permanent --add-port=2222/tcp ; firewall-cmd --reload
echo 'Port 2222' >> /etc/ssh/sshd_config.d/00-local.conf
sshd -t && systemctl restart sshd
ss -tlnp | grep sshd                                 # listening on 2222
ssh -p 2222 alice@server                             # test from another terminal
firewall-cmd --permanent --remove-service=ssh ; firewall-cmd --reload   # then close 22 (optional)
```

Without the SELinux label: `error: Bind to port 2222 on 0.0.0.0 failed: Permission denied`. Changing the port reduces log noise; it isn't real security on its own.

## 6. Allow / Deny Users and Groups

````
AllowUsers alice bob          # ONLY these users may log in (everyone else, incl. root, denied)
DenyUsers  testuser hacker    # these users may not
AllowGroups admins devops     # only members of these groups
DenyGroups interns guests     # members of these groups may not
````

- sshd evaluates **DenyUsers → AllowUsers → DenyGroups → AllowGroups**; a user must pass every check that's configured.
- Once any `Allow*` directive exists, everyone not matched is denied.
- Patterns: `*`, `?`, `user@host` (e.g., `AllowUsers alice@10.0.0.*`).
- Test each change in isolation: remove the previous directive before testing the next one in a lab.

## 7. Key-Only Login (recommended end state)

1. Install keys for every admin (`ssh-copy-id`) and **test** key logins.
2. `PasswordAuthentication no` (and `KbdInteractiveAuthentication no`) in `00-local.conf`.
3. `sshd -T | grep -i passwordauthentication`; reload; test from a new session.

## 8. More Hardening **[Advanced]**

- **System-wide crypto policies:** `update-crypto-policies --show` (DEFAULT/FUTURE/FIPS) control SSH ciphers and key types. Prefer changing the policy over hand-editing cipher lists.
- **fail2ban** (EPEL) or firewalld rich rules / rate limits against brute force.
- `Match Address 10.0.0.0/8` blocks to allow passwords only from internal networks.
- Audit logins: `/var/log/secure`, `journalctl -u sshd`, `lastb`.

## 9. RHCSA Exam Focus

- Key-based authentication must work for the specified users.
- If a task changes the SSH port: SELinux port label + firewall + config, and test.
- Never lock yourself out: keep a session open; verify with `sshd -t` and `sshd -T`.

## 10. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Setting in `sshd_config` ignored | Overridden by an earlier drop-in (first value wins) | `sshd -T`; put it in `00-local.conf` or edit the drop-in |
| sshd fails to start after a port change | SELinux label missing | `semanage port -a -t ssh_port_t -p tcp PORT` |
| New port times out | Firewall | `firewall-cmd --add-port=PORT/tcp --permanent; --reload` |
| Everyone locked out after `AllowUsers` | Your user not listed | Console access; fix the list |
| Banner not shown | Wrong path / not reloaded | `sshd -T | grep banner`; reload |
| `sshd -t` reports "Bad configuration option" | Typo | Fix the keyword |

## 11. Interview Questions

| Question | Answer |
|---|---|
| How do you disable root SSH login? | `PermitRootLogin no` (check drop-ins with `sshd -T`), reload sshd. |
| What's needed to move SSH to port 2222 on RHEL? | sshd `Port`, SELinux `ssh_port_t` label, firewall rule, restart, test. |
| `PermitRootLogin prohibit-password`? | Root may log in with keys only, never with a password. |
| Why use drop-in files? | Package updates don't overwrite them; settings are easy to audit. Remember the first-match rule. |

## 12. Quick Revision

```bash
/etc/ssh/sshd_config.d/00-local.conf (first value wins) · sshd -t · sshd -T | grep KEY · systemctl reload sshd
PermitRootLogin no|prohibit-password · PasswordAuthentication no (after keys) · Banner FILE · MaxAuthTries 3
Port 2222 → semanage port -a -t ssh_port_t -p tcp 2222 ; firewall-cmd --permanent --add-port=2222/tcp ; --reload ; restart
AllowUsers / DenyUsers / AllowGroups / DenyGroups (Deny→Allow users→Deny→Allow groups)
```

## 13. Cross-References

- [SSH remote access](ssh-remote-access.md)
- [sudo](../users-groups-and-permissions/sudo-and-privileged-access.md)
- [firewalld](../firewall-and-selinux/firewalld.md)
- [SELinux port labels](../firewall-and-selinux/selinux-booleans-ports-troubleshooting.md#3-port-labels-rhcsa-core-supplemented)
