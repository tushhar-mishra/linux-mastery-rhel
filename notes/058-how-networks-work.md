# 058 · How Networks Work: The Big Picture

> **You need first:** [057 · Boot recovery](057-boot-recovery.md)
> **Next:** [059 · IP addressing and subnetting](059-ip-addressing-and-subnetting.md)

---

## What it is

A **network** is a set of devices that can send each other data. Everything in this Part (SSH, web servers, DNS, firewalls, Kubernetes networking) builds on a few ideas:

| Word | Plain meaning |
|---|---|
| **Bit / byte** | A bit is one 0 or 1. A byte is 8 bits. Network speeds are in **bits** per second (1 Gbit/s ≈ 125 MB/s) |
| **NIC** (Network Interface Card) | The hardware (or virtual device) that sends and receives data. In Linux it's an **interface** named like `eth0`, `enp0s3`, `ens160` |
| **MAC address** (Media Access Control) | A 48-bit hardware address burned into each NIC, written `52:54:00:ab:cd:ef`. Only meaningful on the **local** network |
| **IP address** (Internet Protocol) | A logical address like `192.168.56.10` that identifies a device across networks (topic 059) |
| **Packet** | A chunk of data plus headers saying where it's from and where it's going |
| **Frame** | A packet wrapped for the local link, with MAC addresses in its header |
| **Switch** | Connects devices on **one local network** (a LAN, Local Area Network). Forwards frames by **MAC** address |
| **Router** | Connects **different networks** together. Forwards packets by **IP** address. Your "gateway" is the router your machine sends all non-local traffic to |
| **Port** | A number (0–65535) that identifies **which program** on a machine should get the data: 22 = SSH, 80 = HTTP, 443 = HTTPS |
| **Protocol** | An agreed set of rules for talking: IP, TCP, UDP, HTTP, DNS… |
| **TCP** (Transmission Control Protocol) | Reliable, ordered, connection-based delivery (web, SSH, databases) |
| **UDP** (User Datagram Protocol) | Fast, no connection, no guarantee of delivery (DNS queries, video, time sync) |
| **ICMP** (Internet Control Message Protocol) | Control and error messages: `ping`, "destination unreachable" |
| **ARP** (Address Resolution Protocol) | Finds the MAC address that belongs to an IP on the local network |
| **DHCP** (Dynamic Host Configuration Protocol) | Hands out IP addresses and settings automatically |
| **DNS** (Domain Name System) | Turns names like `example.com` into IP addresses (topic 063) |
| **Loopback** (`lo`, `127.0.0.1`) | A virtual interface that only talks to the same machine |

## Why it exists

Servers almost never work alone. Users reach your web server, your app talks to a database, nodes in a cluster talk to each other, and every one of those conversations crosses this machinery. When something is "unreachable", you must know **which layer** failed: cable/link, IP address, route, firewall, port, or the application. This topic gives you the mental map that every later networking topic, and Kubernetes networking, depends on.

## Analogy

Sending data is like **posting a letter between office buildings in different cities**:
- The **letter** is your data (an HTTP request).
- The **envelope with an apartment number** is TCP/UDP: the **port** says which resident (program) gets it.
- The **outer envelope with the street address** is the IP header: the **IP address** gets it to the right building, even across cities.
- The **local courier's delivery slip** is the Ethernet frame: the **MAC address** gets it to the next door on this street only. At every post office (router), a new slip is written for the next leg, but the street address stays the same.
- A **switch** is the **mail room inside a building**, delivering by door number (MAC). A **router** is the **post office** sending letters on to other cities (networks). Your **gateway** is your nearest post office.
- **ARP** is shouting in the hallway: "Who lives at 192.168.1.1? Tell me your door number!"
- **DNS** is the **phone book**: name → street address.
- **TCP** is **registered mail with numbered pages**: the receiver confirms each part and asks for missing pages. **UDP** is a **postcard**: fast and cheap, but nobody confirms it arrived.

## How it works inside

### Layers: each one wraps the one above (encapsulation)

| TCP/IP layer | OSI layer (the 7-layer teaching model) | Job | Address used | Example |
|---|---|---|---|---|
| **Application** | 7 Application (5–6 Session/Presentation) | The actual conversation | Names, URLs | HTTP, DNS, SSH, TLS |
| **Transport** | 4 Transport | Which program; reliable or not | **Port** | TCP, UDP |
| **Internet** | 3 Network | Which machine, across networks | **IP address** | IPv4, IPv6, ICMP |
| **Link** | 2 Data link (+1 Physical) | The next hop on this local link | **MAC address** | Ethernet, Wi-Fi, ARP |

When you send data, each layer adds its own **header** in front:

```
[ Ethernet hdr | IP hdr | TCP hdr | HTTP data ]  ← one frame on the wire
   MAC→MAC       IP→IP    port→port
```

The receiver peels the headers off in reverse. Engineers say "a layer-2 problem" (cabling, MAC, switch, VLAN), "layer 3" (IP, routing), "layer 4" (ports, firewall, TCP), "layer 7" (the application). A **VLAN** (Virtual LAN) splits one physical switch into separate logical networks.

### The journey of one request from your laptop to a web server

1. **Name → IP.** Your machine asks DNS (or `/etc/hosts`) for the IP of `www.example.com` (topic 063).
2. **Local or remote?** It compares the destination IP with its own address and **subnet** (topic 059). Same subnet → deliver directly. Different → send to the **default gateway** (router).
3. **IP → MAC.** To put a frame on the wire it needs the **MAC** of the next hop (the server itself if local, otherwise the gateway). It checks its **ARP cache**; if empty, it broadcasts an ARP request: "Who has 192.168.1.1?" The owner replies with its MAC.
4. **TCP handshake.** The kernel picks a random **source port** (an "ephemeral" port, say 51022) and sends **SYN** to destination port 443 → the server replies **SYN-ACK** → the client sends **ACK**. The connection is open (topic 095 goes deep).
5. **Data flows**, wrapped as shown above. Each **router** on the way reads the destination IP, chooses the next hop from its **routing table** (topic 061), writes a **new Ethernet header** for the next link, and decreases the **TTL** (Time To Live: a hop counter that stops packets looping forever).
6. The server's NIC receives the frame. The kernel strips the headers, finds which program owns port 443 (a **socket**: a program's endpoint for network communication), and hands it the data.
7. The reply comes back the same way, addressed to your IP and your ephemeral port.

### TCP vs UDP

| | TCP | UDP |
|---|---|---|
| Connection | Yes (3-way handshake) | No |
| Delivery | Guaranteed, in order: lost data is resent | Best effort: may be lost or reordered |
| Speed / overhead | More overhead | Very little |
| Used by | HTTP(S), SSH, databases, SMTP | DNS queries, NTP (time), video/voice, VXLAN overlays, QUIC (HTTP/3) |

### Well-known ports

| Port | Service | Port | Service |
|---|---|---|---|
| 22/tcp | SSH | 443/tcp | HTTPS |
| 25/tcp | SMTP (mail) | 3306/tcp | MySQL |
| 53/udp+tcp | DNS | 5432/tcp | PostgreSQL |
| 67-68/udp | DHCP | 6443/tcp | Kubernetes API |
| 80/tcp | HTTP | 2049/tcp | NFS |
| 123/udp | NTP (time) | 10250/tcp | kubelet |

Ports below 1024 are **privileged**: only root (or a process with the right capability) may listen on them. The full list is in `/etc/services`.

### DHCP in four steps (DORA)

**D**iscover (client broadcasts "any DHCP server?") → **O**ffer (server offers an address) → **R**equest (client asks for it) → **A**cknowledge (server confirms, with a **lease** time, the gateway and DNS servers). On RHEL, NetworkManager's built-in DHCP client does this (topic 060).

### Interfaces in Linux

- Physical NICs get **predictable names** based on hardware location: `enp0s3` (PCI bus 0, slot 3), `ens160`, `eno1`. Clouds often still show `eth0`.
- `lo` = loopback. Virtual interfaces you'll meet later: bonds (`bond0`, topic 062), bridges (`br0`, `virbr0`, `docker0`, `cni0`), veth pairs (container cables), VLANs (`eth0.100`), tunnels (`vxlan`, `wg0`).

## Commands

```bash
ip -br link
```
```
lo               UNKNOWN        00:00:00:00:00:00 <LOOPBACK,UP,LOWER_UP>
enp0s3           UP             08:00:27:3a:11:c2 <BROADCAST,MULTICAST,UP,LOWER_UP>
enp0s8           UP             08:00:27:9e:44:10 <BROADCAST,MULTICAST,UP,LOWER_UP>
```
- `-br` = brief. Columns: interface, state, **MAC address**, flags. `LOWER_UP` = the cable/link is connected (layer 1/2 OK). `UP` = enabled by software.

```bash
ip -br addr
```
```
lo               UNKNOWN        127.0.0.1/8 ::1/128
enp0s3           UP             10.0.2.15/24 fe80::a00:27ff:fe3a:11c2/64
enp0s8           UP             192.168.56.10/24 fe80::a00:27ff:fe9e:4410/64
```
- The IP addresses on each interface. `/24` is the subnet size (topic 059). `fe80::…` is an automatic IPv6 link-local address.

```bash
ip route
```
```
default via 10.0.2.2 dev enp0s3 proto dhcp src 10.0.2.15 metric 100
10.0.2.0/24 dev enp0s3 proto kernel scope link src 10.0.2.15 metric 100
192.168.56.0/24 dev enp0s8 proto kernel scope link src 192.168.56.10 metric 101
```
- "`10.0.2.0/24` and `192.168.56.0/24` are directly connected; for **everything else** (`default`), send it to the gateway `10.0.2.2`." Topic 061 explains routing in depth.

```bash
ip neigh
```
```
10.0.2.2 dev enp0s3 lladdr 52:54:00:12:35:02 REACHABLE
192.168.56.11 dev enp0s8 lladdr 08:00:27:51:aa:07 STALE
```
- The **ARP cache**: IP → MAC for neighbours on local links. `REACHABLE` = recently confirmed. `STALE` = cached, will re-check on next use. `FAILED` = nobody answered.

```bash
ping -c 2 192.168.56.11
```
```
64 bytes from 192.168.56.11: icmp_seq=1 ttl=64 time=0.48 ms
64 bytes from 192.168.56.11: icmp_seq=2 ttl=64 time=0.51 ms
```
- ICMP echo request/reply: "is the host reachable at layer 3?" `ttl=64` = the remaining hop count. Note that many firewalls block ping, so **no reply doesn't always mean down**.

```bash
tracepath -n 1.1.1.1
```
```
 1?: [LOCALHOST]                      pmtu 1500
 1:  10.0.2.2                                              0.4ms
 2:  192.168.1.1                                           1.9ms
 3:  100.64.0.1                                            8.2ms
...
```
- Shows each **router hop** on the way. `pmtu 1500` = the largest packet size the path allows (MTU, Maximum Transmission Unit; topic 095). `traceroute` is similar.

```bash
ss -tuln
```
```
Netid State  Recv-Q Send-Q Local Address:Port  Peer Address:Port
udp   UNCONN 0      0          127.0.0.1:323        0.0.0.0:*
tcp   LISTEN 0      128          0.0.0.0:22         0.0.0.0:*
tcp   LISTEN 0      128             [::]:22            [::]:*
```
- **Which ports are open** (listening) on this machine. `-t` TCP, `-u` UDP, `-l` listening only, `-n` numbers instead of names. `0.0.0.0:22` = SSH listening on **all** IPv4 addresses; `127.0.0.1:323` = chrony, reachable only locally. Add `-p` (as root) to see the program. Topic 095 covers `ss` in depth.

```bash
grep -wE '^(ssh|http|https|domain)' /etc/services | head -6
```
```
ssh             22/tcp
http            80/tcp          www www-http
https           443/tcp
domain          53/tcp
domain          53/udp
```

```bash
ethtool enp0s3 | grep -E 'Speed|Duplex|Link detected'
```
```
	Speed: 1000Mb/s
	Duplex: Full
	Link detected: yes
```
- Layer 1: is a cable plugged in, and at what speed?

`ifconfig`, `route`, `netstat` and `arp` (the old "net-tools" package) are **deprecated** and not installed on RHEL 10. Use `ip` and `ss`.

### Try it
1. On both lab VMs, run `ip -br link`, `ip -br addr`, `ip route`. Draw the two VMs, their interfaces, IPs and the gateway on paper.
2. Ping server2 from server1, then run `ip neigh` and find server2's MAC. Compare it with `ip link` on server2.
3. Run `ss -tuln` and identify every listening port using `/etc/services`.
4. `tracepath -n 8.8.8.8` and count the hops.

## Where you'll use it

- **Every "can't connect" incident:** walk up the layers: link up? IP correct? route to the destination? ARP resolving the gateway? port listening? firewall? application?
- **Cloud networking:** VPCs (Virtual Private Clouds) and subnets, route tables, internet/NAT gateways and security groups are these same concepts, managed through an API.
- **Kubernetes:** every pod gets an IP; Services use ports; nodes route pod traffic; kube-proxy rewrites addresses with NAT; CNI plugins (Container Network Interface) build interfaces, bridges and routes. It's all layers 2–4.
- **Interviews:** "What happens when you type a URL into a browser?" is this topic plus DNS, TLS and HTTP (topics 063, 064, 070).

## When it breaks

| Symptom | Likely layer | First check |
|---|---|---|
| Interface shows `NO-CARRIER` / no `LOWER_UP` | 1–2: cable, virtual NIC disconnected | `ip -br link`, `ethtool`, the VM's network settings |
| No IP address on the interface | 3: DHCP failed or static config missing | `ip -br addr`; NetworkManager logs (topic 060) |
| Can reach the local subnet but nothing beyond it | 3: missing or wrong default gateway | `ip route`; `ip neigh` (gateway `FAILED`?) |
| Ping by IP works, by name fails | DNS | topic 063 |
| Host pings, but the port is refused or times out | 4: service not listening, or a firewall | `ss -tlnp` on the server; firewall (topic 071) |
| Works from the server itself, not from outside | Service bound to `127.0.0.1`, or a firewall | `ss -tlnp` (check the listen address); topic 071 |
| Small requests work, big ones hang | MTU problem | `tracepath` (pmtu) — topic 095 |

## Quick recap

- Layers: **link** (MAC, switch, ARP) → **IP** (addresses, routers, gateway) → **transport** (ports; TCP reliable, UDP fast) → **application** (HTTP, DNS, SSH). Each wraps the one above.
- Local destination → deliver directly (ARP for the MAC); remote → send to the **default gateway**.
- `ip -br link`, `ip -br addr`, `ip route`, `ip neigh`, `ping`, `tracepath`, `ss -tuln`, `ethtool`. Forget `ifconfig`/`netstat`.
- Debug from the bottom up: link → IP → route → ARP → port → firewall → app.

**Interview questions**

1. *MAC address vs IP address?* A MAC address identifies a NIC on the local link and is used by switches; it gets replaced at every router hop. An IP address identifies a host across networks and is used by routers; it stays the same end to end (unless NAT changes it).
2. *TCP vs UDP?* TCP is connection-oriented, reliable and ordered (handshake, acknowledgements, retransmission). UDP sends independent datagrams with no guarantee and very little overhead.
3. *What does ARP do?* It finds the MAC address belonging to an IP address on the local network, by broadcasting a request that the owner of the IP answers. Results are cached in the neighbour table (`ip neigh`).
