# 059 · IP Addressing and Subnetting (IPv4 and IPv6)

> **You need first:** [058 · How networks work](058-how-networks-work.md)
> **Next:** [060 · NetworkManager and nmcli](060-networkmanager-and-nmcli.md)

---

## What it is

An **IP address** identifies a network interface. The **prefix** (or **subnet mask**) says which part of the address is the **network** and which part is the **host**. Together they tell a machine which destinations are **local** (send directly) and which need the **gateway** (router).

- **IPv4**: 32 bits, written as 4 decimal numbers from 0 to 255 ("octets"): `192.168.56.10`.
- **IPv6**: 128 bits, written as 8 groups of 4 hexadecimal digits: `2001:db8::10`.
- **CIDR** (Classless Inter-Domain Routing) notation: address/prefix, for example `192.168.56.10/24` = "the first 24 bits are the network".
- **Subnet**: a block of addresses sharing the same network part, like `192.168.56.0/24`.
- **Subnetting**: splitting a bigger block into smaller subnets.

## Why it exists

Routing works on **blocks** of addresses, not single ones: "send everything for 10.20.0.0/16 to that router". The prefix makes that possible. Subnetting lets you size networks (a /24 for an office, a /30 between two routers, a /16 for a Kubernetes pod network), keep groups apart, and avoid overlaps that silently break routing. IPv6 exists because IPv4's ~4.3 billion addresses ran out.

## Analogy

An IP address is a **full postal address**: `192.168.56` is the **street** (network) and `.10` the **house number** (host). The prefix says **where the street name ends and the house number begins**. Houses on the same street hand letters over directly; anything for another street goes to the post office (gateway). Subnetting is **splitting a long street into shorter named streets**.

## How it works inside

### The prefix as a bit mask

`192.168.56.10/24`:
```
address  11000000.10101000.00111000.00001010   (192.168.56.10)
mask     11111111.11111111.11111111.00000000   (255.255.255.0 = /24: 24 ones)
network  11000000.10101000.00111000.00000000   (192.168.56.0)   = address AND mask
```
- **Network address** = all host bits 0 (`192.168.56.0`). It names the subnet.
- **Broadcast address** = all host bits 1 (`192.168.56.255`): "everyone on this subnet".
- Usable hosts = everything in between: `.1`–`.254`.

**Is a destination local?** The kernel computes "destination AND my mask". If the result equals my network address, the destination is on my subnet (deliver directly, using ARP); otherwise it goes to the gateway. A **wrong prefix** therefore makes a machine think nearby hosts are far away (or the reverse), which is a very common misconfiguration.

### Subnet maths

Hosts per subnet = 2^(32 − prefix) − 2 (subtracting the network and broadcast addresses).

| Prefix | Mask | Addresses | Usable hosts | Typical use |
|---|---|---|---|---|
| /32 | 255.255.255.255 | 1 | 1 (a single host) | Host routes, firewall rules for one IP |
| /31 | 255.255.255.254 | 2 | 2 (point-to-point, RFC 3021) | Router links |
| /30 | 255.255.255.252 | 4 | 2 | Old-style router links |
| /29 | 255.255.255.248 | 8 | 6 | Tiny server segments |
| /28 | 255.255.255.240 | 16 | 14 | |
| /27 | 255.255.255.224 | 32 | 30 | |
| /26 | 255.255.255.192 | 64 | 62 | |
| /25 | 255.255.255.128 | 128 | 126 | |
| **/24** | 255.255.255.0 | 256 | **254** | The classic LAN |
| /22 | 255.255.252.0 | 1024 | 1022 | |
| /16 | 255.255.0.0 | 65,536 | 65,534 | VPCs, pod networks |
| /8 | 255.0.0.0 | 16.7 million | | |

**Worked example:** `192.168.10.70/26`. A /26 block is 64 addresses, so blocks start at .0, .64, .128, .192. 70 falls in the **.64** block → network `192.168.10.64`, broadcast `192.168.10.127`, hosts `.65–.126`.

**Old "classes"** (A = /8, B = /16, C = /24, based on the first number) are history. Modern networks are classless (CIDR), but you'll still hear "a class C".

### Special IPv4 ranges

| Range | Purpose |
|---|---|
| `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16` | **Private** (RFC 1918). Not routed on the internet; reach the internet through **NAT** (Network Address Translation: a router rewrites private source addresses to its own public one) |
| `127.0.0.0/8` | **Loopback** (`127.0.0.1` = this machine) |
| `169.254.0.0/16` | **Link-local**: self-assigned when DHCP fails. Also used by clouds for the **metadata service** at `169.254.169.254` (topic 104) |
| `100.64.0.0/10` | Carrier-grade NAT (shared address space) |
| `224.0.0.0/4` | Multicast |
| `192.0.2.0/24`, `198.51.100.0/24`, `203.0.113.0/24` | Reserved for documentation and examples |
| `0.0.0.0` | "Any address" (as in "listen on all interfaces") or "default route" (`0.0.0.0/0`) |
| `255.255.255.255` | Broadcast to the local link |

### IPv6

128 bits, 8 groups of 4 hex digits: `2001:0db8:0000:0000:0000:8a2e:0370:7334`.
**Shortening rules:** drop leading zeros in each group, and replace **one** run of all-zero groups with `::` → `2001:db8::8a2e:370:7334`. A LAN normally gets a **/64**.

| Type | Prefix | Meaning |
|---|---|---|
| Global unicast | `2000::/3` | Internet-routable |
| Unique local (ULA) | `fc00::/7` (in practice `fd00::/8`) | Private, like RFC 1918 |
| **Link-local** | `fe80::/10` | Every IPv6 interface has one automatically; never routed |
| Multicast | `ff00::/8` | Replaces broadcast (e.g. `ff02::1` = all nodes on the link) |
| Loopback / unspecified | `::1` / `::` | |

**How IPv6 hosts get addresses:**
- **SLAAC** (Stateless Address Autoconfiguration): the router advertises the /64 prefix and the host builds its own address. NetworkManager uses a stable, privacy-friendly interface ID by default.
- **DHCPv6**: a server hands out addresses and options.
- **Static**: set by hand.

IPv6 replaces ARP with **Neighbor Discovery** (ND, using ICMPv6) and has **no broadcast**.

| | IPv4 | IPv6 |
|---|---|---|
| Size | 32-bit (~4.3 billion) | 128-bit (~3.4 × 10³⁸) |
| Written as | Dotted decimal | Hex groups with `:` |
| Find neighbours | ARP | Neighbor Discovery (ICMPv6) |
| Broadcast | Yes | No (multicast) |
| NAT | Common | Normally not needed |
| Header | 20–60 bytes | 40 bytes fixed + extensions |

### Communication types

**Unicast** = one-to-one. **Broadcast** = one-to-all on the subnet (IPv4 only, for example ARP). **Multicast** = one-to-a-group. **Anycast** = one-to-the-nearest-of-many sharing one address (public DNS resolvers like `1.1.1.1` and `8.8.8.8`).

### How addresses are assigned

| Method | Description |
|---|---|
| **Static** | Set by hand: servers, routers |
| **DHCP** | Leased automatically, with the gateway and DNS servers |
| **DHCP reservation** | DHCP always gives the same IP to the same MAC: "static via DHCP" |
| **SLAAC / DHCPv6** | IPv6 automatic methods |
| **Link-local** | Self-assigned when nothing else works |

## Commands

```bash
ip -4 -br addr ; ip -6 -br addr
```
```
lo               UNKNOWN        127.0.0.1/8
enp0s8           UP             192.168.56.10/24
lo               UNKNOWN        ::1/128
enp0s8           UP             fe80::a00:27ff:fe9e:4410/64
```

```bash
sudo dnf install -y ipcalc        # not in a minimal install; Ubuntu's ipcalc is a different program with other options
ipcalc 192.168.10.70/26
```
```
Address:	192.168.10.70
Network:	192.168.10.64/26
Netmask:	255.255.255.192 = 26
Broadcast:	192.168.10.127

Address space:	Private Use
HostMin:	192.168.10.65
HostMax:	192.168.10.126
Hosts/Net:	62
```
- `ipcalc` (`dnf install ipcalc`; Ubuntu has `ipcalc` with slightly different output) does the subnet maths for you. Check your mental arithmetic with it.

```bash
ipcalc -S 26 10.0.0.0/24          # split a /24 into /26 subnets (RHEL's ipcalc)
```
```
[Split networks]
Network:	10.0.0.0/26
Network:	10.0.0.64/26
Network:	10.0.0.128/26
Network:	10.0.0.192/26

Total:  	4
Hosts/Net:	62
```

```bash
ip route get 192.168.56.11 ; ip route get 8.8.8.8
```
```
192.168.56.11 dev enp0s8 src 192.168.56.10 uid 1000
8.8.8.8 via 10.0.2.2 dev enp0s3 src 10.0.2.15 uid 1000
```
- The kernel's real decision: `192.168.56.11` is **local** (no `via`); `8.8.8.8` goes **via the gateway**.

```bash
python3 -c "import ipaddress as i; n=i.ip_network('10.96.0.0/12'); print(n.num_addresses, n[0], n[-1])"
```
```
1048576 10.96.0.0 10.111.255.255
```
- A handy one-liner for big ranges (this one is the default Kubernetes Service CIDR).

### Try it
1. By hand, work out the network, broadcast and host range of `172.16.45.200/20`. Check with `ipcalc`.
2. Split `10.10.0.0/16` into /24s: how many do you get? (256)
3. Shorten `2001:0db8:0000:0000:0000:0000:0000:0001`. (`2001:db8::1`)
4. On your VM, change nothing, but compute whether `192.168.56.200` and `192.168.57.5` are local to `192.168.56.10/24`. Confirm with `ip route get`.

## Where you'll use it

- **Cloud design:** choosing a VPC CIDR (e.g. `10.0.0.0/16`) and subnets per availability zone (/20s or /24s). **Overlapping ranges** make VPC peering, VPNs and on-prem links impossible, so plan early.
- **Kubernetes:** the **pod CIDR** (e.g. `10.244.0.0/16`, a /24 per node) and the **service CIDR** (e.g. `10.96.0.0/12`) must not overlap with each other or with your corporate networks. A classic outage cause.
- **Firewall rules and security groups:** "allow 22 from `10.20.0.0/16` only".
- **Containers:** Docker's default bridge `172.17.0.0/16` sometimes collides with corporate 172.16/12 ranges, breaking access to internal sites from hosts running Docker.
- **Troubleshooting:** a wrong prefix (`/16` instead of `/24`) makes hosts ARP for addresses that should go through the router.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| Can reach some "local" hosts but not others | Wrong prefix length | Correct the prefix (topic 060) |
| Two machines fight over an address (intermittent drops) | Duplicate IP | `arping -D -I IFACE IP` checks for duplicates |
| Got a `169.254.x.x` address | DHCP failed | Check the DHCP server and the link; NetworkManager logs |
| VPN/peering/Kubernetes traffic goes to the wrong place | Overlapping CIDR ranges | Re-plan the address ranges |
| IPv6 works locally only | Only a link-local `fe80::` address, no global one | Check router advertisements / DHCPv6 / static config |
| Containers can't reach a 172.17.x.x internal site | Docker's bridge overlaps it | Change Docker's `bip` / default address pools |

## Quick recap

- IPv4 = 32 bits; prefix /N = N network bits. Network = all host bits 0, broadcast = all host bits 1. Hosts = 2^(32−N) − 2. /24 = 254, /26 = 62, /30 = 2.
- Private: `10/8`, `172.16/12`, `192.168/16`. Loopback `127/8`. Link-local `169.254/16` (and the cloud metadata IP).
- IPv6 = 128 bits, `::` shortening, /64 per LAN, `fe80::` link-local, SLAAC/DHCPv6, no broadcast (ND instead of ARP).
- `ip -br addr`, `ipcalc`, `ip route get` show the kernel's "local or via gateway" decision.

**Interview questions**

1. *What are the private IPv4 ranges?* `10.0.0.0/8`, `172.16.0.0/12` and `192.168.0.0/16` (RFC 1918).
2. *How many usable hosts in a /26?* 62: 64 addresses minus the network and broadcast addresses.
3. *Why must the Kubernetes pod and service CIDRs not overlap with your corporate network?* Routing would be ambiguous: traffic for corporate addresses in that range would be sent into the cluster (or the reverse), breaking connectivity.
