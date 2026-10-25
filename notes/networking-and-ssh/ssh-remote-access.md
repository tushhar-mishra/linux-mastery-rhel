# SSH: Remote Access, Keys, File Transfer & Switching Users

> **Objectives:** *Access remote systems using SSH* · *Log in and switch users in multi-user targets* · *Configure key-based authentication for SSH* · *Securely transfer files between systems* **[RHCSA Core]**
> **Related:** [SSH server hardening](ssh-server-hardening.md) · [Cryptography basics](cryptography-basics.md) · [rsync & remote backups](rsync-and-remote-backups.md) · [NetworkManager](networkmanager-nmcli.md) · [sudo](../users-groups-and-permissions/sudo-and-privileged-access.md) · [Local users](../users-groups-and-permissions/local-users.md)

## 1. Overview

**SSH (Secure Shell)** provides encrypted remote login, remote command execution, file transfer and tunneling over TCP port **22**. It replaced Telnet, rlogin and rsh, which send everything (including passwords) in clear text. RHEL 10 ships **OpenSSH 9.9**: client `openssh-clients`, server `openssh-server` (`sshd.service`, enabled by default).

## 2. Key Concepts

### 2.1 Host keys vs user keys

| | Host keys | User keys |
|---|---|---|
| Belong to | The **server** | A **user** |
| Location | `/etc/ssh/ssh_host_{ed25519,ecdsa}_key` (+ `.pub`) | `~/.ssh/id_ed25519` (+ `.pub`) |
| Prove | "This really is server X" (anti-MITM) | "This really is user Y" (login without a password) |
| Client side record | `~/.ssh/known_hosts` | Server side record: `~/.ssh/authorized_keys` |

### 2.2 Files

| File | Purpose | Mode |
|---|---|---|
| `~/.ssh/` | User's SSH directory | `700` |
| `~/.ssh/id_ed25519` / `.pub` | Private / public key | `600` / `644` |
| `~/.ssh/authorized_keys` | Public keys allowed to log in **as this user** | `600` |
| `~/.ssh/known_hosts` | Trusted host keys of servers you've connected to | `600`/`644` |
| `~/.ssh/config` | Per-user client settings (aliases, ports, keys) | `600` |
| `/etc/ssh/ssh_config`, `/etc/ssh/ssh_config.d/` | System-wide client settings | |
| `/etc/ssh/sshd_config`, `/etc/ssh/sshd_config.d/` | Server settings (see [hardening](ssh-server-hardening.md)) | |

### 2.3 What happens on connect

1. TCP connection; key exchange creates shared **session keys** (all traffic is then encrypted symmetrically).
2. The server proves its identity with its **host key**; the client checks `known_hosts`.
3. The user authenticates: **public key**, password, or other methods.
4. An encrypted session runs a shell, a command, file transfer, or tunnels.

## 3. Using the SSH Client

### 3.1 Connecting

````bash
ssh alice@192.168.1.20                 # login (user@host)
ssh -p 2222 alice@server               # non-default port
ssh -i ~/.ssh/deploy_key alice@server  # specific key
ssh alice@server 'uptime; df -h /'     # run a remote command and return
ssh -t alice@server 'sudo systemctl restart httpd'   # force a TTY (sudo prompt)
exit   # or Ctrl+D / logout
````

### 3.2 Host key verification (`known_hosts`)

The first connection shows the server's key fingerprint (usually **ED25519** on RHEL 10) and asks for confirmation; answering `yes` stores it.

````bash
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub   # on the SERVER: show its fingerprint to compare
ssh-keygen -R server.example.com                   # remove a stale entry after a legitimate reinstall
````

`WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!` means the key differs from the stored one: a reinstalled server, or a man-in-the-middle. Verify before removing the old entry.

### 3.3 Key-based authentication **[RHCSA Core]**

````bash
ssh-keygen                               # RHEL 10 default: Ed25519 → ~/.ssh/id_ed25519(.pub); set a passphrase
ssh-keygen -t rsa -b 4096                # RSA if required by policy/legacy systems
ssh-copy-id alice@server                 # appends the public key to ~alice/.ssh/authorized_keys with correct modes
ssh alice@server                         # logs in with the key (passphrase if set, no account password)
````

**Manual alternative** (when `ssh-copy-id` isn't available):

````bash
cat ~/.ssh/id_ed25519.pub | ssh alice@server \
  'mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && restorecon -Rv ~/.ssh'
````

Never copy a public key *over* `authorized_keys` with `scp`; that deletes existing keys.

### 3.4 ssh-agent (passphrase once per session)

````bash
eval "$(ssh-agent -s)"         # usually started automatically in desktop sessions
ssh-add                        # add default keys (asks the passphrase once)
ssh-add -l                     # fingerprints of loaded keys   (ssh-add -L: full public keys)
ssh -A alice@jump              # agent forwarding: use only with trusted hosts [Advanced]
````

### 3.5 Secure File Transfer **[RHCSA Core]**

````bash
# scp — copy (OpenSSH 9 uses the SFTP protocol underneath)
scp report.txt alice@server:/tmp/                 # local → remote
scp alice@server:/etc/hosts ./hosts.server        # remote → local
scp -r project/ alice@server:~/                   # directory
scp -P 2222 file alice@server:/tmp/               # port: capital -P

# sftp — interactive / batch
sftp alice@server            # ls, cd, lcd, get, put, mkdir, bye

# rsync over SSH — efficient, resumable (see rsync note)
rsync -av project/ alice@server:/srv/project/
````

### 3.6 Client configuration (`~/.ssh/config`)

````
Host web1
    HostName 192.168.1.20
    User alice
    Port 2222
    IdentityFile ~/.ssh/id_ed25519
````

Then just `ssh web1`, `scp file web1:/tmp/`.

### 3.7 Forwarding **[Advanced]**

````bash
ssh -L 8080:localhost:80 alice@server     # local forward: http://localhost:8080 → server's port 80
ssh -R 9000:localhost:22 alice@public      # remote forward: public:9000 → this machine's port 22
ssh -D 1080 alice@server                   # dynamic SOCKS proxy
ssh -J alice@bastion alice@internal        # jump host (ProxyJump)
ssh -X alice@server xclock                 # X11 forwarding (server needs xauth; RHEL enables X11Forwarding)
````

## 4. Logging In and Switching Users **[RHCSA Core]**

| Method | How |
|---|---|
| Local text console | `Ctrl+Alt+F2`…`F6` (tty2–6), log in; `tty` shows the terminal |
| Graphical login | GDM (`graphical.target`) |
| Remote | `ssh user@host` |

````bash
whoami ; id ; who ; w ; last | head      # identity, sessions, history
su - alice          # switch to alice with a full LOGIN environment (needs alice's password, none if root)
su alice            # switch user but keep the caller's environment (non-login)
sudo -i             # root login shell using YOUR password (wheel/sudoers)
sudo -u alice cmd   # one command as alice
exit                # return to the previous user
````

On RHEL 10 the root account is often **disabled** (no password) at installation; administrators use `sudo`. Direct root SSH login is controlled by `PermitRootLogin` (see [hardening](ssh-server-hardening.md)).

## 5. Server Basics

````bash
dnf install -y openssh-server            # normally preinstalled
systemctl enable --now sshd ; systemctl status sshd
ss -tlnp | grep sshd                     # listening on 0.0.0.0:22 / [::]:22
firewall-cmd --list-services             # 'ssh' allowed in the public zone by default
sshd -t                                  # syntax check after config changes ; systemctl reload sshd
````

## 6. RHCSA Exam Focus **[RHCSA Core]**

- "Configure key-based login from serverA (user X) to serverB (user Y)": `ssh-keygen` as X on A → `ssh-copy-id Y@serverB` → test `ssh Y@serverB` without a password prompt.
- Transfer files with `scp`/`sftp`/`rsync`, and verify on the other side (`ls -l`, checksums).
- Know `su -` vs `su` vs `sudo -i`.

## 7. Production Practices **[Production Practice]**

- Use keys with passphrases + agent; disable password authentication on internet-facing servers ([hardening](ssh-server-hardening.md)).
- Distribute and rotate keys centrally (IdM, configuration management); remove keys of departed users.
- Use a bastion/jump host and `~/.ssh/config` instead of exposing every server.
- Verify host fingerprints out of band for first connections to critical systems.

## 8. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Connection refused` | sshd not running / wrong port | `systemctl status sshd`; `ss -tlnp`; `-p PORT` |
| `Connection timed out` | Firewall / routing | `firewall-cmd --list-all`; network path |
| `Permission denied (publickey)` | Key not in `authorized_keys`, wrong modes/owner, or SELinux label | `ssh -v`; `chmod 700 ~/.ssh; chmod 600 ~/.ssh/authorized_keys`; `restorecon -Rv ~/.ssh`; check `/var/log/secure` on the server |
| Still asks for a password with keys | Wrong key offered / key not loaded | `ssh -v` (which keys are tried); `-i`; `ssh-add` |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | Host key changed | Verify; then `ssh-keygen -R host` |
| `Too many authentication failures` | Agent offers too many keys | `ssh -o IdentitiesOnly=yes -i KEY …` |
| scp fails with odd output | Remote shell startup files print text | Guard interactive output in `~/.bashrc` |

Debugging: `ssh -v` / `-vvv` on the client; `journalctl -u sshd` or `/var/log/secure` on the server.

## 9. Interview Questions

| Question | Answer |
|---|---|
| How does key-based SSH login work? | The server holds your public key in `authorized_keys`; you prove possession of the private key by signing a challenge. The private key never leaves your machine. |
| Host key vs user key? | Host keys authenticate the server (`known_hosts`); user keys authenticate the user (`authorized_keys`). |
| What do you do when the host key changed? | Verify why (reinstall vs attack) via a trusted channel before removing the old entry. |
| `scp -P` vs `ssh -p`? | Same purpose (port); scp uses capital `-P` because `-p` preserves times/modes. |
| `su -` vs `su`? | `su -` starts a login shell with the target user's environment; `su` keeps the current environment. |

## 10. Quick Revision

````bash
ssh [-p P] [-i KEY] user@host ['cmd'] · ssh -v · ssh-keygen [-t ed25519] · ssh-copy-id user@host · ssh-keygen -R host · ssh-keygen -lf KEY.pub
~/.ssh 700 · authorized_keys 600 · private key 600 · restorecon -Rv ~/.ssh
scp f u@h:/dir/ · scp u@h:/f . · scp -r -P P · sftp u@h · rsync -av src/ u@h:/dst/
ssh-agent / ssh-add [-l] · ~/.ssh/config Host alias · -L -R -D -J -X
su - user · su user · sudo -i · who · w · last · tty
````

## 11. Cross-References

- [SSH server hardening](ssh-server-hardening.md)
- [Cryptography basics](cryptography-basics.md)
- [rsync & remote backups](rsync-and-remote-backups.md)
- [NetworkManager](networkmanager-nmcli.md)
- [sudo](../users-groups-and-permissions/sudo-and-privileged-access.md)
- [Local users](../users-groups-and-permissions/local-users.md)
