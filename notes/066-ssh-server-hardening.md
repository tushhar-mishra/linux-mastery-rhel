# 066 · SSH Server Configuration and Hardening

> **You need first:** [065 · SSH](065-ssh.md)
> **Next:** [067 · SSH tunnels](067-ssh-tunnels.md)

---

## What it is

**Hardening** means reducing a system's attack surface: turning off what you don't need and tightening what you keep. The SSH server (`sshd`) is the front door of every Linux server, and on internet-facing machines it gets brute-force login attempts within minutes of going online.

sshd's settings live in `/etc/ssh/sshd_config` plus **drop-in files** in `/etc/ssh/sshd_config.d/*.conf`.

## Why it exists

Defaults are a compromise between convenience and safety. Production servers should allow **only keys**, **no direct root login**, **only the right users and groups**, and log everything. A weak SSH setup leads directly to compromised servers: botnets constantly try common usernames and leaked passwords.

## Analogy

sshd is the **building's main entrance**. Hardening is: no master key handed out at the door (no root login), **ID cards only, no passwords shouted through the door** (key-only), a **guest list** (AllowGroups), a **sign** warning that visitors are monitored (banner), and a **limit on attempts** before the guard closes the door (MaxAuthTries).

## How it works inside

- `/etc/ssh/sshd_config` begins with `Include /etc/ssh/sshd_config.d/*.conf`. The drop-ins are read in **alphabetical order**, **before** the rest of the main file.
- **For most keywords, the FIRST value sshd sees wins.** So a setting in `00-local.conf` beats the same keyword in `50-redhat.conf` and in the main file. (This is the opposite of most config files.)
- `sshd -T` prints the **effective** configuration: exactly what sshd will use after all includes. Always check it.
- `sshd -t` checks the syntax. Reloading sshd (`systemctl reload sshd`) applies changes to **new** connections; **existing sessions stay open**. That's what saves you if you lock yourself out: keep a session open and test from a **new** one.

| Drop-in on RHEL | Origin |
|---|---|
| `01-permitrootlogin.conf` | Created by the installer if you allowed root password login over SSH |
| `40-redhat-crypto-policies.conf` | The system-wide crypto policy (topic 064) |
| `50-redhat.conf` | Red Hat defaults (for example `X11Forwarding yes`) |

On Ubuntu the structure is the same (`/etc/ssh/sshd_config.d/`); the service is called `ssh`, and on 24.04 the **socket** (`ssh.socket`) owns the listening port. After changing `Port`, run `sudo systemctl daemon-reload && sudo systemctl restart ssh.socket` (restarting `ssh` alone keeps the old port), then confirm with `ss -tln`. There's no SELinux step; open the port with `ufw` instead.

### Two other gates on RHEL (explained fully later)

- **SELinux** (topic 072) only lets sshd listen on ports labelled `ssh_port_t`. To move SSH to another port, you must label that port first (`semanage port`, topic 074).
- **firewalld** (topic 071) must allow the port, or connections time out.

## Commands

### The safe edit routine

```bash
sudo vi /etc/ssh/sshd_config.d/00-local.conf
sudo sshd -t                               # syntax check: no output means OK
sudo sshd -T | grep -Ei '^(permitrootlogin|passwordauthentication|port|allowgroups|banner|maxauthtries)'
sudo systemctl reload sshd
# now open a NEW terminal and log in again BEFORE closing the old one
```
```
port 22
permitrootlogin no
maxauthtries 3
passwordauthentication no
banner /etc/ssh/sshd-banner
allowgroups sshusers
allowgroups wheel
```
- `sshd -T` prints the **effective** settings after all files are merged. List keywords such as `AllowGroups` come out one value per line. Cloud images often ship `50-cloud-init.conf` with `PasswordAuthentication yes`; your `00-local.conf` still wins because it is read first.

### A hardened baseline

```
# /etc/ssh/sshd_config.d/00-local.conf
PermitRootLogin no
PasswordAuthentication no            # ONLY after key logins are confirmed working
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AllowGroups sshusers wheel
MaxAuthTries 3
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 2
X11Forwarding no
AllowTcpForwarding no                # unless you need tunnels (topic 067)
Banner /etc/ssh/sshd-banner
```

| Keyword | Meaning |
|---|---|
| `PermitRootLogin` | `no` / `prohibit-password` (keys only; the OpenSSH default) / `yes` |
| `PasswordAuthentication` | Allow password logins |
| `KbdInteractiveAuthentication` | Allow keyboard-interactive (another password-style method) |
| `PubkeyAuthentication` | Allow key logins |
| `AllowUsers` / `DenyUsers` | User patterns (`alice`, `bob@10.0.0.*`) |
| `AllowGroups` / `DenyGroups` | Group membership |
| `MaxAuthTries` | Attempts per connection |
| `LoginGraceTime` | Seconds allowed to finish logging in |
| `ClientAliveInterval` / `CountMax` | Drop dead or idle sessions |
| `Port` | The listening port(s) |
| `Banner` | A text file shown **before** login |
| `Match …` | Conditional block: different rules per user, group or source address |

### Disable direct root login

```bash
sudo grep -r PermitRootLogin /etc/ssh/sshd_config /etc/ssh/sshd_config.d/
echo 'PermitRootLogin no' | sudo tee -a /etc/ssh/sshd_config.d/00-local.conf
sudo sshd -T | grep -i permitrootlogin && sudo systemctl reload sshd
```
- `00-` sorts before the installer's `01-permitrootlogin.conf`, so yours wins. Admins log in as themselves and use `sudo` (topic 028), so every action is logged under a real name.

### Key-only login

1. Install keys for every admin (`ssh-copy-id`) and **test** them.
2. Set `PasswordAuthentication no` and `KbdInteractiveAuthentication no`.
3. `sshd -T` → reload → test from a new session.

### Allow only certain users or groups

```
AllowGroups sshusers wheel
DenyUsers   testuser
```
- sshd checks in this order: **DenyUsers → AllowUsers → DenyGroups → AllowGroups**. A user must pass every check that's configured.
- **Once any `Allow*` line exists, everyone not listed is refused**, including you if you forget yourself.

### Banner

```bash
sudo tee /etc/ssh/sshd-banner <<'EOF'
Authorized users only. All activity is monitored and logged.
EOF
echo 'Banner /etc/ssh/sshd-banner' | sudo tee -a /etc/ssh/sshd_config.d/00-local.conf
sudo sshd -t && sudo systemctl reload sshd
```
- Shown **before** authentication. `/etc/motd` (and `/etc/motd.d/`) is shown **after** login.

### Move SSH to another port (RHEL, with SELinux and firewall)

```bash
sudo semanage port -a -t ssh_port_t -p tcp 2222          # 1. let SELinux allow sshd on 2222
sudo firewall-cmd --permanent --add-port=2222/tcp         # 2. open the firewall
sudo firewall-cmd --reload
echo 'Port 2222' | sudo tee -a /etc/ssh/sshd_config.d/00-local.conf   # 3. configure sshd
sudo sshd -t && sudo systemctl restart sshd
sudo ss -tlnp | grep sshd
ssh -p 2222 alice@server1                                 # 4. test from another terminal
```
- Without step 1, sshd fails with `error: Bind to port 2222 on 0.0.0.0 failed: Permission denied` (SELinux denied it).
- A non-standard port cuts log noise from bots, but it isn't real security on its own.

### Different rules for different sources

```
Match Address 10.0.0.0/8
    PasswordAuthentication yes
Match User backup
    AllowTcpForwarding no
    ForceCommand /usr/local/bin/backup-receive
```
- A `Match` block applies until the next `Match` or the end of the file, so put `Match` blocks **last**.

### Watch the attempts

```bash
sudo journalctl -u sshd --since today | grep -c 'Failed password'
sudo lastb | head          # failed logins
```
- Tools like **fail2ban** (EPEL) block source IPs after repeated failures. firewalld rich rules can rate-limit SSH (topic 071).

### Try it
1. Create `00-local.conf` with `PermitRootLogin no` and `MaxAuthTries 3`. Check `sshd -T`, reload, and test.
2. Switch to key-only login for your lab users, then confirm that `ssh -o PubkeyAuthentication=no user@host` is refused.
3. Add `AllowGroups sshusers`, forget to add yourself, and see what happens (your old session saves you). Fix it.
4. Move SSH to port 2222 with all three steps, then back.

**Check your work:** on your lab VM, from the notes folder, run `sudo ./checks/check 066` for every step, or `sudo ./checks/check 066 STEP` for one (topic 002 shows how to get the notes there).

## Where you'll use it

- **Every new server's baseline**, usually applied by Ansible or a hardened image (CIS benchmark, DISA STIG).
- **Cloud instances:** key-only by default; root login disabled; access often through a bastion, or no SSH at all (AWS SSM, GCP IAP).
- **Audits:** `sshd -T` output is the evidence auditors ask for.
- **Kubernetes nodes:** often locked down to admin groups only, or SSH disabled in favour of `kubectl debug node/…`.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| A setting in `sshd_config` is ignored | An earlier drop-in set the same keyword (first value wins) | `sshd -T`; put it in `00-local.conf`, or edit that drop-in |
| sshd won't start after a port change | The SELinux port label is missing | `semanage port -a -t ssh_port_t -p tcp PORT` |
| The new port times out | Firewall | `firewall-cmd --permanent --add-port=PORT/tcp; --reload` |
| Everyone is locked out after `AllowUsers`/`AllowGroups` | You aren't listed | Use your still-open session, or the console; fix the list |
| The banner isn't shown | Wrong path, or not reloaded | `sshd -T \| grep banner`; reload |
| `sshd -t` says "Bad configuration option" | A typo in a keyword | Fix it |
| Users can't log in after `PasswordAuthentication no` | Their keys weren't installed | Install the keys first; re-enable temporarily from the console |

## Quick recap

- Config: `/etc/ssh/sshd_config` + `/etc/ssh/sshd_config.d/*.conf`; **the first value wins**, so use `00-local.conf`. Always `sshd -t` → `sshd -T` → reload → test from a **new** session.
- Baseline: `PermitRootLogin no`, `PasswordAuthentication no` (after keys work), `AllowGroups`, `MaxAuthTries`, banner.
- Port change on RHEL: SELinux label (`semanage port -a -t ssh_port_t`) + firewall + `Port` + restart.
- Allow/deny order: DenyUsers → AllowUsers → DenyGroups → AllowGroups.

**Interview questions**

1. *How do you disable root login over SSH?* Set `PermitRootLogin no` in an early drop-in (or wherever it takes effect), confirm with `sshd -T`, and reload sshd. Admins then log in as themselves and use sudo.
2. *What do you need to move SSH to port 2222 on RHEL?* Label the port for SELinux (`semanage port -a -t ssh_port_t -p tcp 2222`), open it in firewalld, set `Port 2222`, restart sshd, and test before closing your session.
3. *Why use drop-in files, and what's the gotcha?* Package updates don't overwrite them, and they're easy to audit. The gotcha is that sshd uses the first value it sees for a keyword, so an earlier file overrides a later one.

**Scenario question** (answer out loud first, then compare)

> *"Harden SSH on a fleet of RHEL servers to keys only, no root login, and admins only, without anyone getting locked out."*

**Model answer:**
1. Make sure every admin has working key login first (test it).
2. Write `/etc/ssh/sshd_config.d/00-local.conf` (it sorts first, and **the first value wins**):
   - `PermitRootLogin no`
   - `PasswordAuthentication no`
   - `KbdInteractiveAuthentication no`
   - `AllowGroups sshadmins`
   - `MaxAuthTries 3`
3. Add the admins to `sshadmins`, **including yourself**.
4. Validate: `sshd -t` (syntax), then `sshd -T | grep -Ei 'permitroot|passwordauth|allowgroups'` (the effective values).
5. `systemctl reload sshd`, keep the current session open, and test from a **new** session: key works, `-o PubkeyAuthentication=no` is refused, root is refused.
6. Roll out to one server, then in waves, with console access as the fallback.

**Likely follow-ups:**
- *What does moving SSH to another port need on RHEL?* `semanage port -a -t ssh_port_t -p tcp 2222`, a firewall rule, `Port 2222`, and a restart.
- *Is a non-standard port real security?* It cuts log noise from scanners but isn't a control; keys and access rules are.
