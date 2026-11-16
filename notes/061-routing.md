# 061 · Routing: Route Tables, Gateways and Static Routes

> **You need first:** [060 · NetworkManager and nmcli](060-networkmanager-and-nmcli.md)
> **Next:** [062 · Network bonding](062-network-bonding.md)

---

## What it is

**Routing** is how the kernel decides **where to send each outgoing packet**. It looks the destination up in the **routing table**: a list of rules like "network X → send out interface Y, via gateway Z".

- A **directly connected** route = a subnet your interface sits on (delivered straight to the neighbour, via ARP).
- A **gateway** (**next hop**) = the router a packet is handed to when the destination isn't local.
- The **default route** (`default`, `0.0.0.0/0`, or `::/0` for IPv6) = "everything else": usually your default gateway.
- A **static route** = a route you add yourself ("to reach 10.10.0.0/16, go via 192.168.56.254").
- **Metric** = a preference number when two routes are otherwise equal (lower wins).
- **IP forwarding** = a Linux machine passing packets **between** its interfaces, i.e. acting as a router.

## Why it exists

Networks are joined by routers. A host with one interface and one gateway needs only the default route, but real servers often have several interfaces (a public network, a private backend network, a storage network), VPNs, or container bridges. Each needs routes so traffic leaves by the **right** interface. A wrong or missing route means "Network is unreachable", or, worse, traffic silently leaving the wrong way, where firewalls drop it.

## Analogy

The routing table is a **sign post at a crossroads**: "City A → left road; City B → right road; anywhere else → main highway (default route)". The **most specific** sign wins: a sign for "B-town, Main Street" beats "B-town". Every router along the way has its own sign post; each only decides the **next** step.

## How it works inside

For every packet, the kernel:
1. Finds all routes whose destination network contains the packet's destination IP.
2. Picks the **longest prefix match**: `/32` beats `/24` beats `/16` beats `/0` (default).
3. If several have the same prefix length, picks the **lowest metric**.
4. The winning route gives: the outgoing **interface** (`dev`), the **gateway** (`via`, if any) and the preferred **source address** (`src`).
5. If there's a gateway, it ARPs for the **gateway's** MAC (not the final destination's) and sends the frame there (topic 058).

**Replies need a route back.** If host B has no route back to host A's network, A's packets arrive but B's replies go out the wrong way, or nowhere. Half of "routing" problems are a missing **return** route, and many are actually **firewall** problems.

**Policy routing (advanced):** Linux can keep **several routing tables** and choose which one to use based on **rules** (`ip rule`), for example by **source** address. That's how a host with two uplinks sends replies out of the same interface the request came in on.

**Forwarding:** by default Linux **does not** pass packets between its interfaces. Turning it into a router needs `net.ipv4.ip_forward = 1` (topic 055), routes on both sides, and firewall permission to forward (topic 071). Container hosts and Kubernetes nodes are routers in exactly this sense: they forward between pod interfaces and the network.

## Commands

### Read the table

```bash
ip route
```
```
default via 10.0.2.2 dev enp0s3 proto dhcp src 10.0.2.15 metric 100
10.0.2.0/24 dev enp0s3 proto kernel scope link src 10.0.2.15 metric 100
192.168.56.0/24 dev enp0s8 proto kernel scope link src 192.168.56.10 metric 101
```

| Field | Meaning |
|---|---|
| `default` / `192.168.56.0/24` | Destination network |
| `via 10.0.2.2` | Gateway (next hop). Missing = directly connected |
| `dev enp0s3` | Outgoing interface |
| `proto dhcp` / `kernel` / `static` | Who created the route (DHCP, the kernel when an address was added, or you) |
| `scope link` | The destination is reachable directly on this link |
| `src` | The source address to use |
| `metric 100` | Preference: lower wins. NetworkManager uses 100 for wired by default (here 101 for the second NIC) |

```bash
ip route get 10.20.5.7
```
```
10.20.5.7 via 10.0.2.2 dev enp0s3 src 10.0.2.15 uid 1000
```
- **The single most useful routing command:** it shows exactly what the kernel would do for that destination.

```bash
ip -6 route
```

### Temporary routes (lost at reboot)

```bash
sudo ip route add 10.10.0.0/16 via 192.168.56.254 dev enp0s8
sudo ip route replace 10.10.0.0/16 via 192.168.56.253     # add or change
sudo ip route del 10.10.0.0/16
```
- On a remote machine, **never** `ip route del default`: you'll cut your own SSH session. Use `ip route replace default via …`.

### Permanent routes (NetworkManager)

```bash
sudo nmcli con mod lab +ipv4.routes "10.10.0.0/16 192.168.56.254"
sudo nmcli con mod lab +ipv4.routes "172.20.0.0/16 192.168.56.253 50"     # with metric 50
sudo nmcli con mod lab -ipv4.routes "10.10.0.0/16 192.168.56.254"         # remove
sudo nmcli con mod enp0s3 ipv4.gateway 10.0.2.2                           # default gateway
sudo nmcli con mod lab ipv4.never-default yes          # never install a default route from this NIC
sudo nmcli con mod lab ipv4.route-metric 200           # metric for all of this profile's routes
sudo nmcli con up lab ; ip route
```
- The keyfile form: `route1=10.10.0.0/16,192.168.56.254` in the `[ipv4]` section.
- **Multi-homed hosts:** give the **default gateway to one interface only** (`ipv4.never-default yes` on the others), plus specific routes for the private networks.
- Ubuntu netplan: `routes: [{to: 10.10.0.0/16, via: 192.168.56.254}]`.

### Lab: make a Linux VM a router between two subnets

```
[server1 192.168.56.10] ── 192.168.56.0/24 ── [router .1 | 10.99.0.1] ── 10.99.0.0/24 ── [server3 10.99.0.10]
```
On the router (a VM with two NICs, on two separate host-only networks):
```bash
sudo nmcli con mod net-a ipv4.method manual ipv4.addresses 192.168.56.1/24 ipv4.gateway "" ; sudo nmcli con up net-a
sudo nmcli con mod net-b ipv4.method manual ipv4.addresses 10.99.0.1/24   ipv4.gateway "" ; sudo nmcli con up net-b
echo 'net.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.d/90-forward.conf ; sudo sysctl --system
sudo firewall-cmd --permanent --zone=public --add-forward ; sudo firewall-cmd --reload   # allow forwarding (topic 071)
```
On server1 and server3, add a route to the other network via the router:
```bash
sudo nmcli con mod lab +ipv4.routes "10.99.0.0/24 192.168.56.1" ; sudo nmcli con up lab     # server1
sudo nmcli con mod lab +ipv4.routes "192.168.56.0/24 10.99.0.1" ; sudo nmcli con up lab     # server3
tracepath -n 10.99.0.10                                                                       # from server1
```
```
 1:  192.168.56.1                                          0.5ms
 2:  10.99.0.10                                            0.9ms reached
```

### Policy routing (source-based)

```bash
sudo ip route add default via 192.168.56.254 dev enp0s8 table 201     # a separate table
sudo ip rule add from 192.168.56.100/32 table 201                     # traffic FROM .100 uses it
ip rule ; ip route show table 201
ip route get 8.8.8.8 from 192.168.56.100
```
```
0:	from all lookup local
32765:	from 192.168.56.100 lookup 201
32766:	from all lookup main
32767:	from all lookup default
```
- Rules are checked in priority order; `main` is the normal table. Make it permanent with NetworkManager: `+ipv4.routes "0.0.0.0/0 192.168.56.254 table=201"` and `+ipv4.routing-rules "priority 100 from 192.168.56.100 table 201"`.
- A second default route with a higher metric is **not** real failover. It's only used if the first route disappears (for example, its link goes down), not if the gateway stops answering.

### Try it
1. Run `ip route` and `ip route get` for a local IP, a remote IP and `127.0.0.1`.
2. Add a temporary route with `ip route add`, see it, reboot, and see it's gone. Then make it permanent with nmcli.
3. Build the three-VM router lab (or use server2 as the router with a second NIC).
4. Turn `ip_forward` off on the router and watch the pings stop at hop 1.

## Where you'll use it

- **Multi-homed servers** (frontend + backend + storage networks): one default route, specific routes for the rest.
- **VPNs:** the VPN adds routes for the remote networks; "split tunnelling" = only some routes go through it.
- **Cloud:** each subnet has a **route table** (to an internet gateway, a NAT gateway, a peering connection, a firewall appliance): the same idea, managed by the cloud API.
- **Containers and Kubernetes:** nodes route pod CIDRs. Calico installs one route per remote node's pod subnet (`10.244.2.0/24 via 192.168.1.12`); flannel and others use overlays. `ip route` on a node shows them. `net.ipv4.ip_forward=1` is required.
- **Asymmetric routing** combined with `rp_filter` (reverse-path filtering: drop packets arriving on an interface the reply wouldn't use) causes mysterious one-way drops on multi-homed hosts.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `connect: Network is unreachable` | No route (often no default gateway) | `ip route`; set `ipv4.gateway` or add a route |
| A route disappears after reboot | It was added only with `ip route` | Add it to the profile (`+ipv4.routes`) |
| Ping across a Linux router dies after hop 1 | Forwarding disabled, or the firewall blocks forwarding | `sysctl net.ipv4.ip_forward`; `firewall-cmd --add-forward` |
| Packets arrive but replies never come back | The far side has no return route | Add the route on the other host or router |
| Traffic uses the wrong interface | A more specific or lower-metric route | `ip route get DEST`; fix prefixes or metrics |
| Two default routes, random failures | Several interfaces got a gateway (often from DHCP) | `ipv4.never-default yes` on all but one |
| One-way traffic on a multi-homed host | `rp_filter` with asymmetric routing | Fix the routing; or `rp_filter=2` (loose) knowingly |
| traceroute shows `!X` or "packet filtered" | A firewall rejected it | Check the firewall on the router and the target |
| Ping by IP works, by name doesn't | DNS, not routing | topic 063 |

## Quick recap

- The kernel picks the **longest prefix** match, then the **lowest metric**. `default` = everything else → gateway.
- `ip route`, **`ip route get DEST`**, `ip -6 route`. `ip route add/replace/del` are temporary.
- Permanent: `nmcli con mod C +ipv4.routes "NET/P GW [METRIC]"`, `ipv4.gateway`, `ipv4.never-default yes` → `nmcli con up C`.
- A Linux router needs `ip_forward=1`, routes **both ways**, and the firewall's permission to forward. Policy routing = `ip rule` + extra tables.

**Interview questions**

1. *How does Linux choose a route?* It picks the route with the longest matching prefix for the destination; among equal prefixes, the lowest metric. The default route (/0) is used only when nothing more specific matches.
2. *What does a Linux machine need to act as a router?* `net.ipv4.ip_forward=1`, correct routes on both sides (including return routes), and the firewall allowing forwarded traffic.
3. *How do you make a static route permanent on RHEL?* `nmcli con mod CONN +ipv4.routes "NET/PREFIX GATEWAY"`, then `nmcli con up CONN`.
