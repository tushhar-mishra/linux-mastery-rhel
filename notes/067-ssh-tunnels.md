# 067 · SSH Tunnels: Local, Remote and Dynamic Port Forwarding, Jump Hosts

> **You need first:** [066 · SSH server hardening](066-ssh-server-hardening.md)
> **Next:** [068 · rsync and backups](068-rsync-and-backups.md)

---

## What it is

SSH can carry **other TCP connections** inside its encrypted channel. This is called **port forwarding** or **tunnelling**.

| Type | Flag | Where the listening port opens | Typical use |
|---|---|---|---|
| **Local** | `-L [bind:]lport:target:tport` | On the SSH **client** (your machine) | Reach a service that only the SSH server can reach (a database, an admin web page) |
| **Remote** | `-R [bind:]rport:target:tport` | On the SSH **server** | Expose something on your side to the server side ("reverse tunnel") |
| **Dynamic** | `-D [bind:]port` | On the client, as a **SOCKS proxy** | Send many apps/destinations out through the SSH server |

- **SOCKS** (from "SOCKetS") is a general proxy protocol that browsers and tools like curl understand.
- A **jump host** (or **bastion**) is a hardened SSH server you pass through to reach private machines: `ssh -J bastion target`.

Useful flags: `-N` (don't run a remote command, just tunnel), `-f` (go to the background after login), `-g` (let other hosts use a local forward), `-J` (jump host), `-o ExitOnForwardFailure=yes` (fail if the tunnel can't be created).

## Why it exists

Production services are usually **not** exposed to the internet: databases, admin dashboards, Kubernetes APIs on private networks. Tunnels give you secure, temporary access through the one thing that is exposed (SSH on a bastion) without opening extra firewall holes or setting up a VPN.

## Analogy

The SSH connection is a **private pneumatic tube** between your office and a remote office.
- **Local forward:** you put a **mail slot on your desk** (`localhost:5555`). Anything dropped in it shoots through the tube, and a clerk at the remote office walks it to the database room (`db:5432`).
- **Remote forward:** the remote office gets a **mail slot** that leads back through the tube to a room in **your** building.
- **Dynamic forward:** a **general mail slot**: each item carries its own address label (SOCKS), and the remote clerk delivers it anywhere they can reach.

The tube is private (encrypted), but **the clerk's walk** from the remote office to the final room happens in the open: SSH only encrypts client ↔ SSH server.

## How it works inside

- **`-L 5555:db.internal:5432`**: your `ssh` client listens on `localhost:5555`. When an app connects there, the client opens a "direct-tcpip" **channel** inside the existing SSH connection. The **SSH server** then opens a normal TCP connection to `db.internal:5432` and relays bytes both ways. **`db.internal` is resolved and connected from the SSH server's point of view.**
- **`-R 9000:localhost:80`**: **sshd** listens on port 9000 on the server. Connections there travel back through the tunnel, and your client connects to `localhost:80` on **your** side.
- **`-D 1080`**: the client runs a SOCKS server on port 1080. Each SOCKS request names its destination, and sshd connects to it. TCP only.
- By default, listeners bind to **127.0.0.1** (only the local machine can use them). `-g` (client) or `GatewayPorts` (sshd) allow other hosts.
- Ports below 1024 need root to listen on.
- The server's `AllowTcpForwarding`, `PermitOpen` and `PermitListen` settings can forbid or limit tunnels (topic 066).

## Commands

### Local forward: reach a private database

```bash
ssh -f -N -L 5432:db.internal:5432 alice@bastion
psql -h localhost -p 5432 -U app appdb          # really talks to db.internal through bastion
```
- On your machine, `localhost:5432` now leads to `db.internal:5432` as seen from `bastion`. The bastion → db leg is **not** encrypted by SSH (the database protocol may add its own TLS).

```bash
ssh -f -N -L 8080:localhost:80 alice@server3    # reach server3's OWN port 80 (localhost = server3 here)
curl -s http://localhost:8080 | head -3
```

### Jump host (bastion)

```bash
ssh -J alice@bastion alice@10.0.5.20
```
- Connects to the bastion, then opens a tunnel from it to `10.0.5.20:22`, and runs a full SSH session **end-to-end encrypted** to the inner host. The bastion only forwards bytes; it never sees your inner session's keys.

```
# ~/.ssh/config
Host bastion
    HostName bastion.example.com
    User alice
Host 10.0.5.*
    User alice
    ProxyJump bastion
```
```bash
ssh 10.0.5.20 ; scp file 10.0.5.20:/tmp/      # both go through the bastion automatically
```

### Remote forward: show a local service to the other side

```bash
ssh -f -N -R 9000:localhost:3000 alice@server1   # server1's localhost:9000 → your localhost:3000
```
- For other hosts to reach `server1:9000`, set `GatewayPorts yes` (or `clientspecified`) in **server1's** sshd config and open its firewall.

### Dynamic forward: a SOCKS proxy

```bash
ssh -f -N -D 1080 alice@bastion
curl --proxy socks5h://localhost:1080 http://internal-dashboard.corp/
```
- `socks5h` = do the DNS lookup **through** the proxy, so internal names resolve on the far side. In a browser, set SOCKS v5 host `localhost` port `1080` and enable "proxy DNS".

### Make a tunnel easy and persistent

```
# ~/.ssh/config
Host db-tunnel
    HostName bastion.example.com
    User alice
    LocalForward 5432 db.internal:5432
    ExitOnForwardFailure yes
    ServerAliveInterval 30
```
```bash
ssh -f -N db-tunnel
```
For always-on tunnels, run `ssh -N db-tunnel` as a systemd service with `Restart=always` (topic 037), or use `autossh`, with a dedicated, restricted key.

### Find and close tunnels

```bash
pgrep -af 'ssh .*-[LRD]'
ss -tlnp | grep -E ':5432|:1080'
kill 4711
```
```
4711 ssh -f -N -L 5432:db.internal:5432 alice@bastion
LISTEN 0 128 127.0.0.1:5432 0.0.0.0:* users:(("ssh",pid=4711,fd=5))
```

### Server-side controls (sshd_config)

| Option | Effect |
|---|---|
| `AllowTcpForwarding yes\|no\|local\|remote` | Allow tunnels at all (default yes) |
| `GatewayPorts no\|yes\|clientspecified` | Whether other hosts may connect to `-R` listeners |
| `PermitOpen host:port …` | Limit where `-L` tunnels may go |
| `PermitListen port …` | Limit which ports `-R` may open |
| `Match User tunnel` + `ForceCommand /bin/false` | An account that can only tunnel |

### Try it
1. On server2, run a web server on its loopback only (`python3 -m http.server 8000 --bind 127.0.0.1`). From server1, `curl server2:8000` fails; then `ssh -fN -L 8000:localhost:8000 server2` and `curl localhost:8000` works.
2. Add a jump-host config so `ssh server2` goes through a third machine (or through server2 to itself, just for practice).
3. Start a SOCKS proxy and fetch a page through it with `curl --proxy socks5h://`.
4. Find your tunnels with `ss -tlnp` and kill them.

**Check your work:** on your lab VM, from the notes folder, run `sudo ./checks/check 067` for every step, or `sudo ./checks/check 067 STEP` for one (topic 002 shows how to get the notes there).

## Where you'll use it

- **Bastion access** to private subnets in the cloud (`ProxyJump`). Many teams replace this with AWS SSM, GCP IAP or Teleport, which use the same idea.
- **Temporary database or admin-UI access** without opening firewalls.
- **Kubernetes:** reaching a private cluster API through a bastion (`ssh -L 6443:api.internal:6443 bastion`). `kubectl port-forward` is the same concept inside the cluster.
- **Security reviews:** tunnels can bypass firewalls, so production bastions often restrict them with `PermitOpen` or disable them.

## When it breaks

| Message | Cause | Fix |
|---|---|---|
| `bind [127.0.0.1]:5432: Address already in use` | The local port is taken | Use another local port, or stop what's using it |
| `channel 2: open failed: connect failed: Connection refused` | Nothing is listening at the target, **as seen from the SSH server** | Test from the SSH server: `curl target:port`, `nc -zv target port` |
| `open failed: administratively prohibited` | The server forbids forwarding (`AllowTcpForwarding no`, `PermitOpen`) | Ask the admin or adjust the server config |
| `Warning: remote port forwarding failed for listen port` | The port is in use or not allowed on the server | Another port; check `PermitListen` |
| Other hosts can't use the tunnel | The listener is on 127.0.0.1, or a firewall | `-g` / `GatewayPorts`; open the firewall |
| `Privileged ports can only be forwarded by root` | Local port below 1024 | Use 1024 or higher |
| The tunnel drops when idle | A firewall or NAT drops idle connections | `ServerAliveInterval 30` |

## Quick recap

- `-L lport:target:tport` = listen on the **client**, connect to the target **from the server**. `-R` = listen on the **server**, connect from the client. `-D` = SOCKS proxy.
- `-f -N` = background, no remote command. `-J`/`ProxyJump` = through a bastion, end-to-end encrypted.
- Only client ↔ SSH server is encrypted by SSH. Listeners default to 127.0.0.1.
- Servers control tunnels with `AllowTcpForwarding`, `PermitOpen`, `PermitListen`, `GatewayPorts`.

**Interview questions**

1. *`-L` vs `-R`?* `-L` opens a listener on your (client) machine that forwards to a target reachable from the SSH server. `-R` opens a listener on the SSH server that forwards back to a target reachable from your machine.
2. *Is a local-forwarded connection encrypted all the way to the target?* No. Only the client-to-SSH-server leg is encrypted; the SSH server talks to the target over a normal connection.
3. *How does `ssh -J bastion target` differ from SSHing to the bastion and then SSHing again?* `-J` tunnels a direct, end-to-end encrypted SSH session to the target through the bastion, so your keys and session never sit on the bastion. Two hops would mean authenticating from the bastion itself.

**Scenario question** (answer out loud first, then compare)

> *"You need to reach a database admin page on port 8080 that only listens on localhost on a server behind a bastion. You only have SSH access. How?"*

**Model answer:**
1. One command, through the bastion: `ssh -J user@bastion -L 8080:localhost:8080 user@dbserver -N`.
2. `-J` makes an end-to-end SSH session to `dbserver` through the bastion. `-L` opens `localhost:8080` on **your** laptop and forwards it to `localhost:8080` **as seen from dbserver**.
3. Browse `http://localhost:8080`.
4. Put it in `~/.ssh/config` (`ProxyJump bastion`, `LocalForward 8080 localhost:8080`) for repeat use.
5. It only works if the server allows it (`AllowTcpForwarding`, `PermitOpen`); policy may forbid it, so ask first.

**Likely follow-ups:**
- *`-L` vs `-R`?* `-L` listens on the client; `-R` listens on the server and forwards back to your side.
- *Is the traffic encrypted to the target?* Only between you and the SSH server; here the final hop is inside dbserver itself, so nothing crosses the network unencrypted.
