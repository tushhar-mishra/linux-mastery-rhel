# SSH Port Forwarding (Tunneling)

> **Sessions:** S84 · **[Advanced/Optional]** · common in production and interviews
> **Related:** [SSH remote access](ssh-remote-access.md) · [SSH server hardening](ssh-server-hardening.md) · [firewalld](../firewall-and-selinux/firewalld.md) · [Packet capture](packet-capture.md)

## 1. Overview

SSH can carry other TCP connections through its encrypted channel:

| Type | Flag | Listener is on | Typical use |
|---|---|---|---|
| **Local** | `-L [bind:]lport:target:tport` | SSH **client** | Reach a service behind the SSH server (DB, web admin) |
| **Remote** | `-R [bind:]rport:target:tport` | SSH **server** | Expose a service from the client side to the server side (reverse tunnel) |
| **Dynamic** | `-D [bind:]port` | SSH **client** (SOCKS4/5 proxy) | Route many applications/destinations through the SSH server |

Useful flags: `-N` (no remote command), `-f` (background after authentication), `-g` (allow other hosts to use local forwards), `-J` (jump host), `-o ExitOnForwardFailure=yes`.

> Only the path **between SSH client and SSH server** is encrypted. From the SSH server to the target, traffic travels as normal (possibly unencrypted) traffic.

## 2. Local Forwarding (`-L`)

```bash
# server1 → tunnel → server3; server3 itself reaches its own port 80
ssh -f -N -L localhost:5555:localhost:80 alice@server3
curl http://localhost:5555                # on server1

# Via a jump host: server1 → server2 (SSH) → server3:80 (plain HTTP from server2!)
ssh -f -N -L 5555:server3:80 alice@server2
```

The **target** (`server3:80`) is resolved and connected **from the SSH server's point of view**.

### Let other hosts use the tunnel (GatewayPorts, client side)

```bash
ssh -g -f -N -L 5555:server3:80 alice@server3      # listens on all interfaces of server1
firewall-cmd --permanent --add-port=5555/tcp ; firewall-cmd --reload   # on server1
```

Permanent form: `GatewayPorts yes` in the **client's** `~/.ssh/config` or `/etc/ssh/ssh_config`.

## 3. Remote Forwarding (`-R`)

```bash
# On server3 (web server), publish its port 80 as port 5555 on server1:
ssh -f -N -R localhost:5555:localhost:80 alice@server1
# On server1:
curl http://localhost:5555
```

Making the remote listener reachable by **other** hosts requires `GatewayPorts yes` (or `clientspecified`) in **server1's `sshd_config`**, plus a firewall opening there.

## 4. Dynamic Forwarding (SOCKS)

```bash
ssh -f -N -D 8080 alice@server3                     # local SOCKS proxy on 127.0.0.1:8080
curl --proxy socks5h://localhost:8080 http://server3/   # socks5h = DNS resolution through the proxy
# Browser: SOCKS host localhost, port 8080 (SOCKS v5), "proxy DNS" enabled
```

The destination sees connections coming **from the SSH server**. OpenSSH's SOCKS proxy forwards **TCP only**.

## 5. Making Tunnels Persistent

```
# ~/.ssh/config
Host web-tunnel
    HostName server3
    User alice
    LocalForward 5555 localhost:80
    ExitOnForwardFailure yes
    ServerAliveInterval 30
```

```bash
ssh -f -N web-tunnel
```

For always-on tunnels, use a systemd service running `ssh -N web-tunnel` with `Restart=always`, or `autossh` (EPEL), with a restricted key.

## 6. Server-Side Controls (`sshd_config`)

| Option | Effect |
|---|---|
| `AllowTcpForwarding yes\|no\|local\|remote` | Permit forwarding (default yes) |
| `GatewayPorts no\|yes\|clientspecified` | Who may connect to remote-forward listeners |
| `PermitOpen host:port …` | Restrict local-forward destinations |
| `PermitListen port …` | Restrict remote-forward listen ports |
| `Match User tunnel` + `ForceCommand /bin/false` | Tunnel-only accounts **[Advanced]** |

## 7. Managing & Closing Tunnels

```bash
pgrep -af 'ssh .* -[LRD]'                  # find tunnel processes
ss -tlnp | grep -E ':5555|:8080'           # listening forward ports
kill <PID>                                  # (no need for -9)
pkill -f 'ssh -f -N -L localhost:5555'
ssh -M -S ~/.ssh/ctl-%r@%h -fN -L 5555:localhost:80 alice@server3 ; ssh -S ~/.ssh/ctl-%r@%h -O exit alice@server3   # control socket [Advanced]
```

## 8. Troubleshooting

| Message | Cause | Fix |
|---|---|---|
| `bind [127.0.0.1]:5555: Address already in use` | Port busy | Another tunnel/app; choose another port |
| `channel N: open failed: connect failed: Connection refused` | Target not listening, or wrong target from the server's view | Test from the SSH server: `curl target:port` |
| `open failed: administratively prohibited` | `AllowTcpForwarding no` / `PermitOpen` | Adjust sshd_config (if allowed) |
| `Warning: remote port forwarding failed for listen port` | Port in use or not permitted on the server | Change the port; check `PermitListen` |
| Other hosts can't use the tunnel | Listener on 127.0.0.1 only / firewall | `-g` or GatewayPorts; open the firewall |
| `Privileged ports can only be forwarded by root` | Local port < 1024 | Use ports ≥ 1024 |

## 9. Interview Questions

| Question | Answer |
|---|---|
| `-L` vs `-R`? | `-L` opens a listener on the client forwarding to a target reachable from the server; `-R` opens a listener on the server forwarding to a target reachable from the client. |
| Is the whole path encrypted? | Only client ↔ SSH server; the last hop to the target isn't encrypted by SSH. |
| What does `-D` create? | A local SOCKS proxy that sends connections out through the SSH server. |
| How do you stop users from tunneling? | `AllowTcpForwarding no` (and related options) in sshd_config. |

## 10. Quick Revision

```bash
ssh -fN -L [bind:]LPORT:TARGET:TPORT user@server · ssh -fN -R [bind:]RPORT:TARGET:TPORT user@server · ssh -fN -D 8080 user@server
-g / GatewayPorts (client for -L, sshd for -R) · -J jump · ExitOnForwardFailure · curl --proxy socks5h://localhost:8080 URL
sshd: AllowTcpForwarding · PermitOpen · PermitListen · close: kill PID / pkill -f / -O exit
```

## 11. Cross-References

- [SSH remote access](ssh-remote-access.md)
- [SSH server hardening](ssh-server-hardening.md)
- [firewalld](../firewall-and-selinux/firewalld.md)
- [Packet capture](packet-capture.md)
