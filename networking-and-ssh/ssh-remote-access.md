# SSH Remote Access, Login & Switching Users

> **Sessions:** S3 (basics) · **To be extended:** S64–68 (SSH options, login restrictions, recovery, rsync backups)
> **Related:** [Filesystem hierarchy](../linux-fundamentals/filesystem-hierarchy.md) · [Lab setup](../linux-fundamentals/virtualization-and-lab-setup.md) · [Shell basics](../shell-and-command-line/shell-basics-and-command-syntax.md) · firewalld (`firewall-and-selinux/`, planned) · users/sudo (`users-groups-and-permissions/`, planned)

## 1. Overview

**SSH** (Secure Shell, OpenSSH on RHEL) provides encrypted remote login, remote command execution and file transfer over TCP **port 22**. The server daemon is `sshd` (package `openssh-server`, unit `sshd.service`); the client is `ssh` (package `openssh-clients`). RHEL 10 ships **OpenSSH 9.9**.

**How a connection works:**
1. TCP connect to port 22.
2. Key exchange establishes an encrypted channel.
3. The client verifies the **server host key** against `~/.ssh/known_hosts`.
4. The user authenticates (public key, password, …).
5. A shell or command runs.

## 2. Key Concepts

| Concept | Detail |
|---|---|
| Host keys | Server identity: `/etc/ssh/ssh_host_*_key`. Fingerprint shown on first connect, stored in the client's `~/.ssh/known_hosts` |
| User keys | Private key `~/.ssh/id_ed25519` (keep secret, mode 600). Public key `~/.ssh/id_ed25519.pub`, appended to the server's `~/.ssh/authorized_keys` |
| Key authentication | The server checks that the client can **sign** a challenge with the private key matching an authorized public key. The private key never leaves the client |
| Default key type | `ssh-keygen` on RHEL 10 creates **Ed25519** by default (RSA in FIPS mode, where Ed25519 isn't allowed) |
| Root login | OpenSSH default `PermitRootLogin prohibit-password` (keys only). The RHEL 10 installer also disables password-based root SSH by default |
| Config layout | `/etc/ssh/sshd_config` begins with `Include /etc/ssh/sshd_config.d/*.conf`. For most options **the first value read wins**, so drop-ins override the main file |
| Crypto policy | OpenSSH follows RHEL system-wide crypto policies (`update-crypto-policies --show`) |

## 3. Commands & Procedures

### 3.1 Prepare the server **[RHCSA Core]**

```bash
rpm -q openssh-server                     # installed? (default on RHEL)
sudo dnf install -y openssh-server        # if missing
sudo systemctl enable --now sshd          # start now + at boot
systemctl status sshd                     # active (running), enabled
ss -tlnp | grep ':22'                     # LISTEN 0.0.0.0:22 users:(("sshd",…))

sudo firewall-cmd --list-services         # 'ssh' is allowed in the default zone on RHEL
sudo firewall-cmd --permanent --add-service=ssh   # only if missing
sudo firewall-cmd --reload
```

### 3.2 Find the server's IP

```bash
ip -br addr                     # compact: ens160  UP  192.168.122.10/24 …
ip addr show                    # full detail
hostname -I                     # just the addresses
nmcli -g IP4.ADDRESS device show ens160
```

Interface names depend on the hypervisor: `ens160`/`ens192` (VMware), `enp0s3` (VirtualBox), `enp1s0` (KVM virtio). `dynamic` in `ip addr` output means the address came from DHCP.

### 3.3 Connect

```bash
ssh user@192.168.122.10                 # interactive login
ssh -p 2222 user@127.0.0.1              # non-default port (e.g., VirtualBox port-forward)
ssh user@host 'df -h; uptime'           # run a command remotely, then exit
ssh -v user@host                        # verbose; -vvv for maximum detail when debugging
exit                                    # or Ctrl+D to log out
```

**First connection:** verify the fingerprint, then type `yes`. It's saved in `~/.ssh/known_hosts`.

**Windows clients:** Windows 10/11 include the OpenSSH client (`ssh` in PowerShell). PuTTY also works but uses its own `.ppk` key format (convert keys with PuTTYgen).

### 3.4 Key-based authentication **[RHCSA Core]**

Run these on the **client**, as the user who will log in:

```bash
ssh-keygen                               # Ed25519 by default on RHEL 10 (OpenSSH 9.x)
ssh-keygen -t ed25519 -C "user@laptop"   # explicit type + comment
ssh-keygen -t rsa -b 4096                # only when RSA is required (FIPS, legacy systems)

ssh-copy-id user@server                  # appends pubkey to server ~/.ssh/authorized_keys; sets perms
ssh user@server                          # should log in without the account password
```

If `ssh-copy-id` isn't available:

```bash
cat ~/.ssh/id_ed25519.pub | ssh user@server \
  'mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'
```

**Passphrase vs. "passwordless":** an empty passphrase means anyone who copies the private key gets access. Use a passphrase together with `ssh-agent`:

```bash
eval "$(ssh-agent -s)"; ssh-add          # passphrase typed once per session
```

**Required permissions** (sshd's `StrictModes` refuses keys if these are too open):

| Path | Mode | Owner |
|---|---|---|
| `~` (home) | not group/world-writable | user |
| `~/.ssh/` | `700` | user |
| `~/.ssh/authorized_keys` | `600` | user |
| `~/.ssh/id_*` (private) | `600` | user |

### 3.5 Secure file transfer **[RHCSA Core]**

```bash
scp file.txt user@server:/tmp/              # copy to remote
scp -r user@server:/etc/ssh ./ssh-backup    # recursive copy from remote
sftp user@server                            # interactive: put, get, ls, cd, lcd
rsync -avz --progress dir/ user@server:/backup/dir/   # incremental, resumable (S68)
```

On OpenSSH 9.0+, `scp` uses the SFTP protocol internally (`scp -O` forces the legacy protocol for old servers).

### 3.6 Change sshd settings safely **[Production Practice]**

```bash
sudo tee /etc/ssh/sshd_config.d/40-local.conf >/dev/null <<'EOF'
PasswordAuthentication no
EOF
sudo sshd -t                                     # syntax check: no output = OK
sudo sshd -T | grep -i passwordauthentication    # confirm the EFFECTIVE value
sudo systemctl reload sshd
```

> ⚠️ **Lock-out risk:** Before disabling password authentication or changing the port, **keep your current session open** and test key login from a second terminal. Changing the port also requires SELinux (`semanage port -a -t ssh_port_t -p tcp <port>`) and firewalld updates (S64–65, S76).

## 4. Logging In and Switching Users **[RHCSA Core]**

Objective: *Log in and switch users in multi-user targets.*

| Action | Command | Notes |
|---|---|---|
| Console login | Text console on `multi-user.target`; `Ctrl+Alt+F2`…`F6` switches virtual terminals on GUI systems | `tty` shows your terminal |
| Who am I? | `whoami`, `id` | `id` shows UID, GID and groups (check for `wheel`) |
| Who's logged in? | `who`, `w` | `pts/N` = SSH or terminal emulator; `ttyN` = console |
| Login history | `last`, `sudo lastb` (failed logins) | Also `/var/log/secure`, `journalctl -u sshd` |
| Switch user, login shell | `su - alice` | Fresh environment, home directory, profile files (**preferred**) |
| Switch user, keep environment | `su alice` | Keeps the caller's environment and `PATH` (source of confusing errors) |
| Root login shell via sudo | `sudo -i` | Uses **your** password; requires `wheel`/sudoers |
| One command as another user | `sudo -u alice cmd` | |
| Return | `exit` or `Ctrl+D` | |
| Current target | `systemctl get-default` | `multi-user.target` (text) vs `graphical.target` (S50) |

> **RHEL 10:** if root was left disabled at install, `su -` fails with an authentication failure. Use `sudo -i`, or set a root password (`sudo passwd root`) if your lab or a task requires it.

## 5. RHCSA Exam Focus

- Key-based auth for a **specific user** to a **specific host**, with key permissions correct.
- `sshd` enabled and the firewall allowing `ssh`. Verify with an actual login.
- Use `su - user` (not `su user`) when testing user environments, umask and permissions.
- Trap: generating keys as **root** when the task says user `alice`. The keys end up in `/root/.ssh`.
- Trap: `authorized_keys` created by root (wrong owner). Fix with `chown -R alice:alice ~alice/.ssh`.

## 6. Troubleshooting **[Production Practice]**

Diagnostic sequence: **client verbose → reachability → service → firewall → auth logs → effective config.**

```bash
ssh -vvv user@host                       # client side: where does it stop?
ping -c2 host; nc -zv host 22            # reachability and port (nc from the nmap-ncat package)
sudo systemctl status sshd; sudo ss -tlnp | grep sshd
sudo firewall-cmd --list-all
sudo journalctl -u sshd -e               # or: sudo tail -f /var/log/secure
sudo sshd -T | less                      # effective server configuration
```

| Error | Meaning | Fix |
|---|---|---|
| `Connection refused` | Host reachable, nothing listening on that port | Start/enable `sshd`; check `Port` and `ss -tlnp` |
| `Connection timed out` / `No route to host` | Packets dropped or unroutable | Firewall (`firewall-cmd`), wrong IP, VM network mode, routing |
| `Permission denied (publickey)` | Key not accepted and passwords disabled | Wrong user, key not in `authorized_keys`, bad perms/ownership, wrong SELinux context on `~/.ssh` (`restorecon -Rv ~/.ssh`) |
| `Permission denied, please try again` (as root) | Root password login disabled by policy | Log in as the admin user, then `sudo -i`; or use keys |
| `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!` | Host key differs from `known_hosts` | If expected (reinstall), `ssh-keygen -R host`; if not, **investigate a possible MITM** |
| Login hangs about 10–30 s before the prompt | Reverse-DNS or GSSAPI delays | Fix DNS or `/etc/hosts`; set `UseDNS no` or `GSSAPIAuthentication no` as appropriate |

Server-side clues for key failures appear in `journalctl -u sshd`, e.g. `Authentication refused: bad ownership or modes for directory /home/alice/.ssh`.

## 7. Tips & Best Practices

- Prefer **Ed25519** keys with passphrases plus `ssh-agent`. Use one key per device or person.
- Disable password authentication on internet-facing servers **after** confirming key access works.
- Use `~/.ssh/config` aliases:

```
  Host lab
      HostName 192.168.122.10
      User alice
      Port 22
```

  Then just run `ssh lab`.
- Never copy private keys between machines casually; never put them in Git.
- Treat host key change warnings as security events.

## 8. Interview Questions

| Question | Answer |
|---|---|
| How does SSH key authentication work? | The server holds the public key in `authorized_keys`. The client proves possession of the private key by signing a challenge; the private key never crosses the network. |
| What is `known_hosts` for? | It pins server host keys so the client detects impersonation (MITM) on later connections. |
| "Connection refused" vs "timed out"? | Refused: host reachable, port closed (service down). Timed out: packets dropped (firewall, routing, host down). |
| You get `Permission denied (publickey)`. Steps? | `ssh -vvv` to see which keys were offered → check the server's `authorized_keys` contents, ownership and modes (700/600) → SELinux context → `journalctl -u sshd` → `sshd -T` for `PubkeyAuthentication`/`AuthorizedKeysFile`. |
| `su` vs `su -` vs `sudo -i`? | `su` keeps the environment; `su -` starts a clean login shell; `sudo -i` gives a root login shell using your own password and is auditable via sudo logs. |
| Why disable root password SSH? | Root is a known username for brute-force attacks. Keys plus named admin accounts give accountability and stronger authentication. |
| scp vs rsync? | scp copies everything every time. rsync transfers only differences, preserves attributes (`-a`), can resume and delete — better for backups and syncs. |

## 9. Quick Revision

```bash
systemctl enable --now sshd; firewall-cmd --list-services
ssh-keygen; ssh-copy-id user@host; ssh user@host
chmod 700 ~/.ssh; chmod 600 ~/.ssh/authorized_keys
scp / sftp / rsync -avz
sshd -t && sshd -T | grep -i <option>; systemctl reload sshd
ssh-keygen -R host        # stale host key
su - user | sudo -i | id | who | w | last
```

## 10. Cross-References

- [Shell basics (first commands, `whoami` vs `who am i`)](../shell-and-command-line/shell-basics-and-command-syntax.md)
- [I/O redirection (`sudo tee`)](../files-and-text-processing/io-redirection-and-pipes.md)
- Firewall rules: `firewall-and-selinux/` (S69–70, planned)
- SELinux port labels for a non-standard SSH port: `firewall-and-selinux/` (S76, planned)
- sudo and the wheel group: `users-groups-and-permissions/` (S27, planned)
- Advanced SSH options, login restrictions, rsync backups: this file, extended in S64–68
- SSH port forwarding: this file (S84) **[Advanced/Optional]**
