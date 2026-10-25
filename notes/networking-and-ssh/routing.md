# Routing on RHEL 10: Routes, Gateways & Static Routing

> Supports *Configure IPv4 and IPv6 addresses* (default gateway) **[RHCSA Core]** · static/policy routing **[Production Practice]**
> **Related:** [NetworkManager & nmcli](networkmanager-nmcli.md) · [IP fundamentals](ip-addressing-fundamentals.md) · [Kernel parameters (sysctl)](../boot-systemd-and-kernel/kernel-modules-and-parameters.md) · [Packet capture](packet-capture.md) · [firewalld](../firewall-and-selinux/firewalld.md) · [TCP/IP for operators](tcp-ip-for-operators.md)

## 1. Overview

For each outgoing packet the kernel looks up the **routing table**:

- If the destination is in a **directly connected** subnet, the packet is delivered directly (ARP/ND for the neighbor's MAC address).
- Otherwise it goes to the **gateway** (next hop) of the most specific matching route. The **default route** (`0.0.0.0/0`, `::/0`) catches everything else.
- **Most specific prefix wins** (`/24` beats `/16` beats `/0`); among equal prefixes, the lowest **metric** wins.

## 2. Viewing Routes

````bash
ip route                     # = ip route show (IPv4)
ip -6 route
ip route get 8.8.8.8         # which route/interface/source a packet to 8.8.8.8 would use
nmcli dev show ens160 | grep -E 'IP4.(ROUTE|GATEWAY)'
route -n                     # legacy net-tools (deprecated; may not be installed)
````

````
default via 192.168.229.2 dev ens160 proto dhcp src 192.168.229.132 metric 100
192.168.229.0/24 dev ens160 proto kernel scope link src 192.168.229.132 metric 100
````

| Field | Meaning |
|---|---|
| `default` / `192.168.229.0/24` | Destination |
| `via 192.168.229.2` | Gateway (next hop); absent for directly connected routes |
| `dev ens160` | Outgoing interface |
| `proto dhcp` / `kernel` / `static` | Who created the route |
| `scope link` | Destination directly reachable on this link |
| `src` | Preferred source address |
| `metric 100` | Preference (lower wins); NetworkManager uses 100 for wired by default |

## 3. Temporary Routes (`ip route`), lost at reboot

````bash
ip route add 10.10.10.0/24 via 192.168.229.2 dev ens160
ip route replace 10.10.10.0/24 via 192.168.229.254      # add-or-change
ip route del 10.10.10.0/24
ip route add default via 192.168.229.2 dev ens160        # default gateway
````

> ⚠️ `ip route del default` on a remote system can cut your SSH session. Use `ip route replace default via …` instead.

## 4. Persistent Routes (NetworkManager) **[RHCSA Core]**

````bash
nmcli con mod ens160 ipv4.gateway 192.168.229.2                        # default gateway
nmcli con mod ens160 +ipv4.routes "10.10.10.0/24 192.168.229.2"         # static route
nmcli con mod ens160 +ipv4.routes "172.16.0.0/16 192.168.229.3 50"      # with metric 50
nmcli con mod ens160 -ipv4.routes "10.10.10.0/24 192.168.229.2"         # remove
nmcli con mod ens160 ipv4.route-metric 200                              # metric for this profile's routes
nmcli con mod ens161 ipv4.never-default yes                             # never install a default route from this NIC
nmcli con mod ens160 +ipv6.routes "fd00:10::/64 fd00:1::1"
nmcli con up ens160 ; ip route
````

**Keyfile form** (`[ipv4]` section): `route1=10.10.10.0/24,192.168.229.2` (optionally `,metric`), then `nmcli con reload` and `nmcli con up ens160`.

## 5. Lab: Routing Between Two Subnets

````
[Server A 192.168.1.10/24] ── 192.168.1.0/24 ── [Router: 192.168.1.1 | 10.0.0.1] ── 10.0.0.0/24 ── [Server B 10.0.0.10/24]
````

Hypervisor: two host-only/isolated networks (e.g., VMnet2, VMnet3). The router VM has a NIC on each network.

````bash
# Router (persistent addresses, NO default gateway on these NICs)
nmcli con mod ens160 ipv4.method manual ipv4.addresses 192.168.1.1/24 ipv4.gateway "" ; nmcli con up ens160
nmcli con mod ens224 ipv4.method manual ipv4.addresses 10.0.0.1/24   ipv4.gateway "" ; nmcli con up ens224
echo 'net.ipv4.ip_forward = 1' > /etc/sysctl.d/90-ip_forward.conf ; sysctl --system
firewall-cmd --get-active-zones                  # both NICs normally land in "public"
firewall-cmd --permanent --zone=public --add-forward ; firewall-cmd --reload   # allow forwarding within the zone

# Server A
nmcli con mod ens160 ipv4.method manual ipv4.addresses 192.168.1.10/24 +ipv4.routes "10.0.0.0/24 192.168.1.1" ; nmcli con up ens160
# Server B
nmcli con mod ens160 ipv4.method manual ipv4.addresses 10.0.0.10/24 +ipv4.routes "192.168.1.0/24 10.0.0.1" ; nmcli con up ens160

# Test
ping 10.0.0.10            # from A
tracepath 10.0.0.10       # (or traceroute, if installed) shows hop 1 = 192.168.1.1
````

Alternative: on A and B, set the router address as the **default gateway** instead of specific routes.

## 6. Policy Routing **[Advanced]**

Use this when **different source addresses** must use **different gateways** at the same time:

````bash
ip addr add 192.168.1.100/24 dev ens160                       # secondary address
ip route add default via 192.168.1.1 dev ens160 table 201     # separate table
ip rule add from 192.168.1.100/32 table 201                   # traffic FROM .100 uses table 201
ip rule ; ip route show table 201
ip route get 8.8.8.8 from 192.168.1.100
````

Persistent with NetworkManager:

````bash
nmcli con mod ens160 +ipv4.routes "0.0.0.0/0 192.168.1.1 table=201" \
                     +ipv4.routing-rules "priority 100 from 192.168.1.100 table 201"
````

A second default route in the **main** table with a higher metric is **not** failover based on gateway reachability. It's only used if the preferred route disappears (e.g., its link goes down).

## 7. Production Practices **[Production Practice]**

- Keep exactly one default gateway per host (unless you design policy routing deliberately).
- Define static routes in NetworkManager profiles (or Ansible), never only with `ip route`.
- Multi-homed hosts with asymmetric paths can be hit by reverse-path filtering (`net.ipv4.conf.*.rp_filter`); set it to loose mode (`2`) only when you understand the routing.
- Document routes next to firewall rules; most "routing" problems are actually firewall problems.

## 8. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Network is unreachable` | No route (no default gateway) | `ip route`; set `ipv4.gateway` / add a route |
| Route vanishes after reboot | Added with `ip route` | Add it to the profile (`+ipv4.routes`) |
| Ping across router fails; hop 1 replies | Forwarding disabled or firewall | `sysctl net.ipv4.ip_forward`; `firewall-cmd --add-forward` |
| traceroute shows `!X` / "packet filtered" | Firewall rejecting | Check firewalld on the router and target |
| Replies never return | Far side lacks a return route | Add the route on the other host/router |
| Wrong interface used | More specific or lower-metric route | `ip route get DEST`; adjust metrics/prefixes |
| Ping works, names don't | DNS, not routing | `getent hosts`; check `ipv4.dns` |

## 9. Interview Questions

| Question | Answer |
|---|---|
| How does Linux choose a route? | Longest prefix match, then lowest metric. |
| How do you make a static route persistent on RHEL? | `nmcli con mod CON +ipv4.routes "NET/PFX GW"` + `nmcli con up CON`. |
| What does a host need to act as a router? | `net.ipv4.ip_forward = 1`, routes on both sides, firewall forwarding allowed. |
| What's `ip route get` for? | Shows the exact route, interface and source address the kernel would use. |
| When do you need policy routing? | When the routing decision depends on something other than the destination (e.g., source address). |

## 10. Quick Revision

````bash
ip route [show|get DEST] · ip -6 route · ip route add|replace|del NET via GW [dev D] · default via GW
nmcli con mod C ipv4.gateway GW | +ipv4.routes "NET/P GW [METRIC]" | ipv4.never-default yes ; nmcli con up C
keyfile: route1=NET/P,GW · router: /etc/sysctl.d/…ip_forward=1 ; firewall-cmd --permanent --add-forward
policy: ip rule add from SRC table N ; ip route add default via GW table N · nmcli ipv4.routing-rules
````

## 11. Cross-References

- [NetworkManager & nmcli](networkmanager-nmcli.md)
- [IP fundamentals](ip-addressing-fundamentals.md)
- [Kernel parameters (sysctl)](../boot-systemd-and-kernel/kernel-modules-and-parameters.md)
- [Packet capture](packet-capture.md)
- [firewalld](../firewall-and-selinux/firewalld.md)
