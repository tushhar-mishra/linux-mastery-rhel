# IP Addressing Fundamentals (IPv4 & IPv6)

> **[Interview Knowledge]** · foundation for *Configure IPv4 and IPv6 addresses* **[RHCSA Core]**
> **Related:** [NetworkManager & nmcli](networkmanager-nmcli.md) · [Routing](routing.md) · [Virtualization & lab setup](../linux-fundamentals/virtualization-and-lab-setup.md) · [TCP/IP for operators](tcp-ip-for-operators.md)

## 1. Overview

An **IP address** identifies a network interface and, together with its prefix (subnet mask), tells hosts which addresses are **local** (delivered directly) and which must go through a **gateway** (router). DNS translates names like `www.example.com` into IP addresses.

## 2. IPv4

32 bits, written as 4 decimal octets: `192.168.1.10`. The **prefix** `/24` (mask `255.255.255.0`) says how many leading bits are the network part.

### 2.1 Historical classes (classful addressing)

| Class | 1st octet | Default mask | Networks | Hosts/network | Use |
|---|---|---|---|---|---|
| A | 1–126 | /8 | 126 | 16,777,214 | Very large networks |
| B | 128–191 | /16 | 16,384 | 65,534 | Medium |
| C | 192–223 | /24 | 2,097,152 | 254 | Small |
| D | 224–239 | — | — | — | Multicast |
| E | 240–255 | — | — | — | Experimental |

Modern networks use **CIDR** (classless): any prefix length, e.g. `10.20.0.0/22`.

### 2.2 Subnetting quick math (supplemented)

- Hosts per subnet = 2^(32 − prefix) − 2 (network and broadcast addresses).
- `/24` → 254 hosts, `/25` → 126, `/26` → 62, `/27` → 30, `/30` → 2, `/31` → 2 (point-to-point, RFC 3021), `/32` → single host.
- Example: `192.168.10.70/26` → network `192.168.10.64`, broadcast `192.168.10.127`, hosts `.65–.126`.

`````bash
ipcalc 192.168.10.70/26        # network, broadcast, host range (ipcalc package)
`````

### 2.3 Special IPv4 ranges

| Range | Purpose |
|---|---|
| `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16` | **Private** (RFC 1918), not routed on the internet; reach it via NAT |
| `127.0.0.0/8` | Loopback (`127.0.0.1`) |
| `169.254.0.0/16` | Link-local (auto-assigned when DHCP fails on some OSes, "APIPA") |
| `100.64.0.0/10` | Carrier-grade NAT (shared address space) |
| `224.0.0.0/4` | Multicast (e.g., `224.0.0.5` OSPF) |
| `192.0.2.0/24`, `198.51.100.0/24`, `203.0.113.0/24` | Documentation/examples |
| `0.0.0.0` / `255.255.255.255` | "This host / any" / limited broadcast |

## 3. IPv6

128 bits, 8 groups of 4 hex digits: `2001:0db8:85a3:0000:0000:8a2e:0370:7334`.

**Shortening rules:** drop leading zeros in each group, and replace **one** run of all-zero groups with `::` → `2001:db8:85a3::8a2e:370:7334`. Usually `/64` per LAN.

| Type | Prefix / example | Notes |
|---|---|---|
| Global unicast | `2000::/3` (e.g., `2001:db8::/32` is documentation) | Internet-routable |
| Unique local (ULA) | `fc00::/7` (in practice `fd00::/8`) | Private, like RFC 1918 |
| Link-local | `fe80::/10` | Every IPv6 interface has one; not routed |
| Multicast | `ff00::/8` | Replaces broadcast |
| Loopback / unspecified | `::1` / `::` | |

**Address configuration:**

- **SLAAC** builds an address from the router-advertised prefix plus an interface ID: EUI-64 (from the MAC) or stable-privacy (default on modern NetworkManager).
- **DHCPv6** assigns addresses and options from a server.
- **Static** addresses are set by hand.

## 4. Communication Types

| Type | Meaning | IPv4 | IPv6 |
|---|---|---|---|
| Unicast | One-to-one | ✔ | ✔ |
| Broadcast | One-to-all on the subnet (e.g., ARP requests) | ✔ | ✘ (uses multicast) |
| Multicast | One-to-group | ✔ | ✔ |
| Anycast | One-to-nearest of many with the same address | ✔ (e.g., 8.8.8.8) | ✔ |

## 5. IPv4 vs IPv6

| Feature | IPv4 | IPv6 |
|---|---|---|
| Size / notation | 32-bit, dotted decimal | 128-bit, hex with colons |
| Address space | ~4.3 billion | ~3.4 × 10³⁸ |
| Header | 20–60 bytes (variable) | 40 bytes (fixed) + extension headers |
| Configuration | Static, DHCP | Static, SLAAC, DHCPv6 |
| Broadcast | Yes | No (multicast) |
| NAT | Common | Normally unnecessary |
| IPsec | Optional | Optional (once mandatory in early standards, now recommended) |
| ARP | ARP | Neighbor Discovery (ICMPv6) |
| Loopback | `127.0.0.1` | `::1` |

## 6. Allocation Methods

| Method | Description |
|---|---|
| Static | Admin sets address, prefix, gateway, DNS: servers, routers |
| DHCP | Server leases addresses + options (gateway, DNS) |
| DHCP reservation | DHCP always gives the same address to a MAC: "static via DHCP" |
| Link-local / APIPA | Self-assigned 169.254.x.x / fe80:: when nothing else works |
| SLAAC | IPv6 self-configuration from router advertisements |
| DHCPv6 | Stateful IPv6 address assignment |

## 7. VM Network Modes (VMware / VirtualBox)

| Mode | VM ↔ Host | VM ↔ VM | VM → Internet | Notes |
|---|---|---|---|---|
| NAT (VMware NAT, VirtualBox **NAT Network**) | ✔ | ✔ | ✔ | Private subnet behind the host; inbound from LAN needs port forwarding |
| VirtualBox plain **NAT** | Host → VM only via port forwarding | ✘ | ✔ | Each VM isolated |
| Bridged | ✔ | ✔ | ✔ | VM is a full LAN citizen with its own LAN IP |
| Host-only | ✔ | ✔ | ✘ | Isolated lab network with the host |
| Internal (VirtualBox) / LAN segment (VMware) | ✘ | ✔ (same segment) | ✘ | Isolated VM-only networks |

**Lab tip:** NAT (internet) + host-only (stable lab addresses).

## 8. Interview Questions

| Question | Answer |
|---|---|
| What are the private IPv4 ranges? | `10/8`, `172.16/12`, `192.168/16`. |
| How many hosts in a /26? | 62. |
| Why does IPv6 have no broadcast? | It uses multicast (e.g., all-nodes `ff02::1`) and Neighbor Discovery instead. |
| What's a link-local address? | Valid only on the local link (`169.254/16`, `fe80::/10`), never routed. |
| Shorten `2001:0db8:0000:0000:0000:0000:0000:0001`. | `2001:db8::1`. |

## 9. Quick Revision

`````
RFC1918: 10/8 172.16/12 192.168/16 · loopback 127/8 ::1 · link-local 169.254/16 fe80::/10 · ULA fd00::/8 · multicast 224/4 ff00::/8
hosts = 2^(32-prefix) - 2 · /24=254 /25=126 /26=62 /27=30 /30=2
IPv6: drop leading zeros, one :: · SLAAC / DHCPv6 / static · no broadcast, ND instead of ARP
`````

## 10. Cross-References

- [NetworkManager & nmcli](networkmanager-nmcli.md)
- [Routing](routing.md)
- [Virtualization & lab setup](../linux-fundamentals/virtualization-and-lab-setup.md)
