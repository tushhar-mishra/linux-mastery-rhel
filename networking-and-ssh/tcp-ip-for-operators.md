# TCP/IP for Operators: Sockets, Connection States, Netfilter & the Packet Path

> **Track:** **[Internals]** · **[Production Practice]** · **[Interview Knowledge]** · **Verified:** demos on RHEL 10.2 UBI containers (iproute2, nftables 1.1.5, kernel 6.12; Oct 2026). Kernel defaults quoted are upstream defaults; confirm on your hosts with `sysctl`.
> **Prerequisites:** [IP addressing](ip-addressing-fundamentals.md) · [NetworkManager & nmcli](networkmanager-nmcli.md) · [Routing](routing.md) · [firewalld](../firewall-and-selinux/firewalld.md) · [Processes & system calls (fds, sockets)](../processes-and-resource-management/processes-and-system-calls.md)
> **Next:** [Packet capture](packet-capture.md) · [Namespaces & cgroups (container networking)](../containers-and-virtualization/namespaces-and-cgroups.md) · [Linux → Kubernetes bridge](../advanced-rhel-and-career-notes/linux-foundations-of-kubernetes.md)

## 1. Why This Matters

RHCSA networking is configuration: addresses, routes, DNS, firewall zones. Production incidents are about **behavior**: connections that hang, time out or get reset, port exhaustion, sockets stuck in `CLOSE_WAIT`, a firewall rule that silently drops traffic, a black-holed MTU. This note gives you the mental model and the commands to tell those apart in minutes.

## 2. The Layers You Actually Debug

| Layer | Linux objects | Tools |
|---|---|---|
| L2 link | Interfaces, MAC addresses, neighbor (ARP/ND) table, bridges, bonds, veth | `ip -br link`, `ip neigh`, `bridge link`, `ethtool` |
| L3 network | Addresses, routing tables, policy rules, ICMP, MTU | `ip -br addr`, `ip route get`, `ip rule`, `ping`, `tracepath` |
| L4 transport | **Sockets**, TCP states, ports, UDP | `ss`, `nstat`, `/proc/net/snmp` |
| Filtering/NAT | netfilter hooks, nftables rules, conntrack | `nft list ruleset`, `firewall-cmd`, `conntrack` |
| Name resolution | nsswitch, `/etc/hosts`, `resolv.conf`, DNS | `getent`, `dig` |
| L7 | HTTP, TLS, SSH… | `curl -v`, `openssl s_client`, app logs |

A socket is a file descriptor (`ls -l /proc/PID/fd` shows `socket:[inode]`), so everything from the [processes note](../processes-and-resource-management/processes-and-system-calls.md#6-file-descriptors) applies: fd limits, inheritance, `ss -p` mapping sockets to processes.

## 3. End to End: What Happens on `curl https://api.example.com/health`

1. **Name resolution.** glibc reads `/etc/nsswitch.conf` (`hosts: files dns myhostname` on RHEL), checks `/etc/hosts`, then sends DNS queries (UDP 53; TCP for large answers) to the servers in `/etc/resolv.conf`, applying `search` domains and `options ndots/timeout/attempts`. RHEL doesn't run a local caching resolver by default, so every lookup goes to the configured servers.
2. **Route lookup.** The kernel picks the longest-prefix route (`ip route get 203.0.113.10`), giving an outgoing interface, next hop (gateway) and source address.
3. **Neighbor resolution.** For the next hop it needs a MAC address: ARP (IPv4) or Neighbor Discovery (IPv6), cached in `ip neigh`.
4. **TCP connect.** `socket()` + `connect()`: the kernel picks an **ephemeral source port**, sends **SYN**, receives **SYN-ACK**, sends **ACK**: the 3-way handshake. Outgoing packets pass the netfilter **output** and **postrouting** hooks (firewall, NAT).
5. **TLS.** ClientHello (with **SNI**: the hostname) → server certificate chain → the client verifies the chain against the trust store (`/etc/pki/ca-trust/`) **and** that the certificate matches the hostname → keys are agreed; HTTP is then encrypted.
6. **HTTP** request/response over the established connection.
7. **Teardown.** FIN/ACK exchanges; the side that closes first ends up in **TIME_WAIT**.

Time each phase from the client (verified output format):

```bash
curl -sS -o /dev/null -w 'dns=%{time_namelookup} connect=%{time_connect} tls=%{time_appconnect} ttfb=%{time_starttransfer} total=%{time_total} code=%{http_code}\n' https://www.redhat.com/
# dns=0.453051 connect=0.498890 tls=0.651510 ttfb=0.735526 total=0.736675 code=301
```

The values are cumulative: here DNS took 453 ms (slow resolver), TCP 46 ms, TLS 153 ms, server processing ~84 ms. Whichever phase dominates tells you where to look.

## 4. TCP Connection Lifecycle

```
 client                                  server (listening)
 SYN-SENT     ── SYN ──────────────────► SYN-RECV       (SYN queue)
 ESTABLISHED  ◄─ SYN-ACK ──────────────
              ── ACK ──────────────────► ESTABLISHED    (accept queue → accept())
              … data …
 FIN-WAIT-1   ── FIN ──────────────────► CLOSE-WAIT     ← app must now call close()
 FIN-WAIT-2   ◄─ ACK ──────────────────
 TIME-WAIT    ◄─ FIN ────────────────── LAST-ACK       (after the app closes)
 (2×MSL)      ── ACK ──────────────────► CLOSED
```

| State | Meaning | When it's a problem |
|---|---|---|
| `LISTEN` | Server socket waiting for connections | — |
| `SYN-SENT` | Client sent SYN, no answer yet | Many = destination unreachable or **dropped** by a firewall |
| `SYN-RECV` | Server got SYN, sent SYN-ACK, waiting for ACK | Many = SYN flood or the return path is broken |
| `ESTABLISHED` | Open connection | Count vs expectations (pool sizes, leaks) |
| **`CLOSE-WAIT`** | Peer closed; **our application hasn't called `close()`** | **Always an application bug** when it accumulates (leaked sockets → fd exhaustion) |
| `FIN-WAIT-2` | We closed; waiting for the peer's FIN | Peer app stuck (it's in CLOSE-WAIT on the other side) |
| **`TIME-WAIT`** | We closed first; kept briefly so delayed packets don't corrupt a new connection | Huge numbers on a **client** making many short connections can exhaust ephemeral ports |

Verified: a server that accepts but never closes, with clients that connect and close:

```
State      Recv-Q Send-Q Local Address:Port  Peer Address:Port
CLOSE-WAIT 1      0          127.0.0.1:9000     127.0.0.1:41538     ← server side: app never closed
FIN-WAIT-2 0      0          127.0.0.1:41538    127.0.0.1:9000      ← client side waiting for the server's FIN
```

When the server process was killed, the kernel closed its sockets and the clients moved to `TIME-WAIT`.

## 5. Server Side: Listen Queues

A listening socket has two queues: the **SYN queue** (half-open, `SYN-RECV`) and the **accept queue** (completed handshakes waiting for the app to call `accept()`). The accept queue's size is `min(backlog passed to listen(), net.core.somaxconn)` (`somaxconn` default 4096 on current kernels).

```bash
ss -ltn
# State  Recv-Q Send-Q Local Address:Port
# LISTEN 0      5          127.0.0.1:9000     ← for LISTEN sockets: Recv-Q = connections waiting in the accept queue, Send-Q = its maximum
nstat -az TcpExtListenOverflows TcpExtListenDrops   # counters: connections dropped because the accept queue was full
```

If `Recv-Q` sits at `Send-Q` and the overflow counters rise, the application isn't accepting fast enough (saturated worker pool, blocked event loop) or the backlog is too small. Clients see slow connects or timeouts. `net.ipv4.tcp_syncookies = 1` (default) lets the server survive SYN floods.

## 6. Ports and Ephemeral Port Exhaustion

- Every TCP connection is identified by the 4-tuple **(src IP, src port, dst IP, dst port)**.
- Outgoing connections take a source port from `net.ipv4.ip_local_port_range` (default `32768 60999`, about 28,000 ports).
- A client opening many short connections to **the same destination IP:port** can run out of ports while they sit in TIME-WAIT. Symptoms: `connect: Cannot assign requested address` (`EADDRNOTAVAIL`), intermittent failures under load.
- Fixes, in order of preference: **reuse connections** (keep-alive, connection pools), spread over more destination IPs, widen the port range, and `net.ipv4.tcp_tw_reuse` (default `2` = loopback only; `1` lets new outgoing connections reuse TIME-WAIT ports when it's safe). Never shorten TIME-WAIT by unsupported hacks.
- `tcp_fin_timeout` (60 s) controls FIN-WAIT-2 for orphaned sockets, **not** TIME-WAIT.

## 7. Failure Signatures: Refused vs Timeout vs Unreachable

| Client sees | What happened on the wire | Typical cause |
|---|---|---|
| `Connection refused` (immediately) | Server host answered the SYN with **RST** | Nothing listening on that port, service bound to another address (e.g., 127.0.0.1), or a firewall **reject** rule |
| Connection **timeout** (after seconds) | SYN got no answer at all | Firewall **drop**, host down, wrong route, return path broken, SYN queue full |
| `No route to host` | ICMP host-unreachable, or ARP/ND failed | Host down on the local subnet, firewall rejecting with ICMP (firewalld's default reject), no route |
| `Network is unreachable` | No matching route locally | Missing default route / wrong subnet |
| `Connection reset by peer` mid-stream | RST on an established connection | App crashed/closed abruptly, idle timeout on a middlebox, load balancer |
| Hangs after connecting (TLS or big responses stall) | Large packets dropped | **MTU / PMTUD black hole** (§9) |

Verified with nftables: a `drop` rule produced `TimeoutError … 3.0 s`; a `reject with tcp reset` rule produced `ConnectionRefusedError [Errno 111]` in `0.0 s`; no listener produced `Connection refused`. **`drop` vs `reject` is the difference between a timeout and an instant error**, a key clue in firewall debugging.

## 8. `ss`: Socket Statistics

```bash
ss -tlnp                      # TCP listeners + owning process (needs root to see other users' processes)
ss -ulnp                      # UDP listeners
ss -tanp                      # all TCP sockets with process
ss -s                         # summary: totals per state (estab, timewait, orphaned…)
ss -tan state close-wait      # filter by state (also: established, time-wait, syn-sent …)
ss -tan '( dport = :443 or sport = :443 )'
ss -ti dst 10.0.0.15          # per-connection internals: rtt, cwnd, retrans, mss, delivery rate
ss -tm                        # socket memory (skmem: receive/send buffers)
nstat -az | grep -iE 'retrans|overflow|drop'   # protocol counters (or: netstat -s from net-tools, not installed by default)
```

| `ss -i` field | Meaning |
|---|---|
| `rtt:12.3/4.1` | Smoothed round-trip time / variance (ms) |
| `cwnd:10` | Congestion window (segments) |
| `retrans:0/5` | Current / total retransmissions: packet loss on the path |
| `mss:1448` | Maximum segment size (reveals MTU) |

## 9. MTU and Path MTU Discovery

An interface's **MTU** (usually 1500 bytes on Ethernet; often 9000 on storage networks; lower inside tunnels/VPNs/overlays) limits packet size. TCP normally avoids fragmentation by setting **DF** (don't fragment); routers that can't forward a large packet send back ICMP "fragmentation needed", and the sender lowers its packet size (**PMTUD**). If a firewall drops that ICMP, large packets vanish silently: the **black hole**. Small requests work, while TLS handshakes or large responses hang.

```bash
ip link show eth0 | grep -o 'mtu [0-9]*'
ping -M do -s 1472 -c 3 HOST     # 1472 + 8 (ICMP) + 20 (IP) = 1500: must pass on a 1500-MTU path
ping -M do -s 1473 -c 3 HOST     # one byte too many: "message too long" locally, or loss/ICMP errors on the path
tracepath HOST                   # reports "pmtu N" along the path
```

Fixes: allow ICMP type 3 code 4 (IPv4) / ICMPv6 packet-too-big through firewalls; set the correct MTU (`nmcli con mod X 802-3-ethernet.mtu 1450`); MSS clamping on the router.

## 10. Neighbor Table (ARP/ND)

```bash
ip neigh                      # 172.17.0.1 dev eth0 lladdr 52:54:1a:70:6b:b2 REACHABLE   (verified format)
ip neigh flush dev eth0       # force re-resolution (lab)
arping -D -I eth0 192.168.1.50   # duplicate address detection: is someone else using this IP? (iputils)
```

States: `REACHABLE` (recently confirmed), `STALE` (cached, will re-verify on use), `INCOMPLETE`/`FAILED` (no answer: host down, wrong VLAN, or wrong subnet). A gateway in `FAILED` explains "everything off-subnet times out".

## 11. Netfilter, nftables & Conntrack

### 11.1 Hooks: where packets can be filtered or NATed

```
 incoming ─► PREROUTING ─► routing decision ─┬─► INPUT ─► local process
           (DNAT here)                         │
                                               └─► FORWARD ─► POSTROUTING ─► out   (router/container host)
 local process ─► OUTPUT ─► routing ─► POSTROUTING (SNAT/masquerade here) ─► out
```

- **INPUT**: traffic to this host (where firewalld zones mostly act).
- **FORWARD**: traffic routed through this host (routers, container/VM hosts, Kubernetes nodes).
- **PREROUTING/OUTPUT DNAT**: change the destination (port forwarding, `podman -p 8080:80`, Kubernetes Service ClusterIPs with kube-proxy in iptables/nftables mode).
- **POSTROUTING SNAT/masquerade**: change the source (containers and VMs reaching the internet through the host's address).

### 11.2 nftables structure

```bash
nft list ruleset                  # everything (firewalld's rules live in "table inet firewalld")
nft list tables
```

Verified minimal lab ruleset:

```
table inet lab {                                   ← table: a namespace for chains; family inet = IPv4+IPv6
	chain input {                                  ← base chain attached to a hook
		type filter hook input priority filter; policy accept;
		tcp dport 9002 drop                        ← rule: match + verdict
		tcp dport 9003 reject with tcp reset
	}
}
```

```bash
nft add table inet lab
nft add chain inet lab input '{ type filter hook input priority 0; }'
nft add rule inet lab input tcp dport 9002 drop
nft delete table inet lab
```

On RHEL, manage the host firewall with **firewalld**; use `nft` to **read** what firewalld generated and for lab experiments. Don't mix hand-written rules with firewalld unless you know their priorities.

### 11.3 Connection tracking

Stateful firewalls rely on **conntrack**, a kernel table of flows. Each packet is classified as `new`, `established`, `related` (e.g., ICMP errors, FTP data) or `invalid`. firewalld's "allow replies" behavior is `ct state established,related accept`. NAT is recorded per flow, so replies are translated back automatically.

```bash
cat /proc/sys/net/netfilter/nf_conntrack_count /proc/sys/net/netfilter/nf_conntrack_max
conntrack -L | head ; conntrack -S        # (conntrack-tools package) list flows / per-CPU stats incl. drops
dmesg | grep -i 'nf_conntrack: table full'   # → new connections dropped: raise nf_conntrack_max or reduce flows
```

## 12. Network Namespaces, veth & Bridges (Container Networking in 6 Commands)

A **network namespace** is a separate network stack: its own interfaces, addresses, routes, firewall rules and sockets. A **veth pair** is a virtual cable: whatever enters one end exits the other. Verified:

```bash
ip netns add red
ip link add veth-host type veth peer name veth-red
ip link set veth-red netns red                                  # move one end into the namespace
ip addr add 10.200.0.1/24 dev veth-host ; ip link set veth-host up
ip -n red addr add 10.200.0.2/24 dev veth-red ; ip -n red link set veth-red up ; ip -n red link set lo up
ping -c1 10.200.0.2                                             # host → namespace works
ip netns exec red ping -c1 8.8.8.8                              # "Network is unreachable": no default route yet
ip netns del red
```

To give the namespace internet access you'd add a default route via `10.200.0.1`, enable `net.ipv4.ip_forward`, and masquerade its traffic in POSTROUTING. That is exactly what Podman (netavark) and Kubernetes CNI plugins do, usually with a **bridge** (`podman0`, `cni0`) joining many veths. Each container has its own namespace (`readlink /proc/PID/ns/net` → `net:[inode]`; two processes share a network namespace when the inode matches).

## 13. DNS Troubleshooting

```bash
getent hosts api.example.com      # what applications get (nsswitch: files → dns)
dig api.example.com +short        # DNS only, bypasses /etc/hosts
dig @10.0.0.53 api.example.com    # ask a specific server
dig +trace example.com            # follow the delegation from the root [Advanced]
cat /etc/resolv.conf              # nameserver (max 3), search, options ndots:N timeout:N attempts:N
```

- `getent` OK but `dig` fails → the name is only in `/etc/hosts`.
- Slow first byte everywhere → a dead first `nameserver` (each lookup waits `timeout` before trying the next).
- Short names resolve unexpectedly → `search` domains; with `ndots:5` (Kubernetes pods) every external name is tried with each search suffix first.
- Negative answers (NXDOMAIN) are cached by resolvers for the SOA minimum TTL ([DNS note](../system-services-and-shared-storage/dns-bind.md)).

## 14. TLS Troubleshooting

```bash
openssl s_client -connect www.redhat.com:443 -servername www.redhat.com </dev/null 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates          # verified: subject, issuer, notBefore/notAfter
curl -v https://host/ 2>&1 | grep -iE 'SSL|subject|issuer|expire|verify'
trust list | head ; update-ca-trust                      # system trust store (/etc/pki/ca-trust/source/anchors/ for private CAs)
update-crypto-policies --show                            # DEFAULT / FUTURE / FIPS: affects allowed TLS versions & ciphers
```

Typical failures: expired certificate, hostname mismatch (wrong SNI or certificate), private CA not in the trust store, incomplete chain on the server, protocol/cipher mismatch with a strict crypto policy.

## 15. Labs

1. **Phases of a request.** Use the `curl -w` line against three sites; identify the slowest phase for each.
2. **CLOSE_WAIT leak.** Reproduce §4 with the Python server that never closes; watch `ss -tan state close-wait` grow, then check `ls /proc/PID/fd | wc -l`.
3. **Drop vs reject.** In a lab VM, add a firewalld rich rule with `drop` and one with `reject` on two ports; connect with `curl` and time both.
4. **Accept queue overflow.** Write a server with `listen(1)` that sleeps before `accept()`; open 20 connections; watch `ss -ltn` Recv-Q and `nstat -az TcpExtListenOverflows`.
5. **Namespace networking.** Build §12, then add a default route, `ip_forward=1` and an nftables masquerade rule so the namespace can reach the internet.
6. **MTU black hole (2 VMs).** Set the MTU to 1400 on one side, block ICMP fragmentation-needed with a rule, and reproduce "small requests work, large ones hang"; then fix it.

## 16. Troubleshooting Flow: "Service X is unreachable"

```
1. Is it listening, and on which address?   ss -tlnp | grep :PORT        (0.0.0.0 vs 127.0.0.1)
2. Local test works?                        curl -v http://127.0.0.1:PORT/
3. Local firewall/SELinux?                  firewall-cmd --list-all ; ausearch -m avc -ts recent
4. Route and neighbor from the client?      ip route get SERVER ; ip neigh
5. Does the SYN arrive? Does a SYN-ACK leave?   tcpdump -nn -i any port PORT (on the server)
6. Refused / timeout / reset?               → §7 signatures
7. Name resolution correct?                 getent hosts NAME vs dig NAME
8. TLS?                                     openssl s_client …
```

## 17. Interview Questions

| Question | Answer |
|---|---|
| Walk through `curl https://example.com`. | DNS via nsswitch/resolv.conf → route lookup → ARP for the gateway → TCP handshake from an ephemeral port → TLS (SNI, chain + hostname verification) → HTTP → FIN teardown, TIME_WAIT on the closer. |
| CLOSE_WAIT vs TIME_WAIT? | CLOSE_WAIT: the peer closed and our app hasn't (leak/bug). TIME_WAIT: we closed first; normal and short-lived, but many can exhaust client ports. |
| "Connection refused" vs timeout? | Refused = RST (no listener or reject); timeout = packets dropped or no route/host. |
| What does Recv-Q mean on a LISTEN socket? | Connections waiting in the accept queue; if it reaches Send-Q (the backlog), new connections are dropped. |
| How do you find which process owns a port? | `ss -tlnp 'sport = :PORT'` (root) or `lsof -i :PORT`. |
| Why can't a client open new connections under load? | Ephemeral port exhaustion (TIME_WAIT) → reuse connections, more destination IPs, wider port range, `tcp_tw_reuse`. |
| What's PMTUD and how does it fail? | Discovering the largest packet size via ICMP "fragmentation needed"; blocking that ICMP creates black holes where large packets disappear. |
| Where does NAT happen in netfilter? | DNAT in PREROUTING/OUTPUT, SNAT/masquerade in POSTROUTING; conntrack remembers translations for replies. |
| How do containers get networking? | Each has a network namespace; a veth pair connects it to a host bridge; the host routes/NATs (forwarding + masquerade) and DNATs published ports. |
| `getent hosts` vs `dig`? | getent follows nsswitch (`/etc/hosts`, DNS…), as applications do; dig queries DNS only. |

## 18. Quick Revision

```
curl -w dns/connect/tls/ttfb · getent hosts vs dig · ip route get · ip neigh (REACHABLE/STALE/FAILED)
SYN → SYN-ACK → ACK · FIN: closer → TIME-WAIT ; other side CLOSE-WAIT until app close() (leak!)
LISTEN Recv-Q/Send-Q = accept queue/backlog (somaxconn 4096) · nstat TcpExtListenOverflows · syncookies
ephemeral 32768–60999 · EADDRNOTAVAIL · tcp_tw_reuse (2 = loopback) · tcp_fin_timeout ≠ TIME-WAIT
refused = RST · timeout = drop · no route to host = ICMP/ARP · reset by peer · MTU black hole (ping -M do -s 1472, tracepath)
ss -tlnp -tanp -s -ti 'state close-wait' · nstat -az
netfilter: PREROUTING(DNAT) INPUT FORWARD OUTPUT POSTROUTING(SNAT) · nft list ruleset · conntrack (established,related) · nf_conntrack_max
netns + veth + bridge + forward + masquerade = container networking · readlink /proc/PID/ns/net
TLS: openssl s_client -servername ; x509 -dates ; update-ca-trust ; update-crypto-policies
```

## 19. Cross-References

- [IP addressing](ip-addressing-fundamentals.md) · [Routing (policy routing, rp_filter)](routing.md) · [NetworkManager](networkmanager-nmcli.md) · [Bonding](network-bonding.md)
- [firewalld (zones → nftables)](../firewall-and-selinux/firewalld.md) · [Packet capture](packet-capture.md) · [SSH tunneling](ssh-port-forwarding.md)
- [DNS with BIND](../system-services-and-shared-storage/dns-bind.md) · [Cryptography basics](cryptography-basics.md)
- [Namespaces & cgroups](../containers-and-virtualization/namespaces-and-cgroups.md) · [Linux → Kubernetes bridge](../advanced-rhel-and-career-notes/linux-foundations-of-kubernetes.md)
