# 062 · Network Bonding (Link Aggregation and Failover)

> **You need first:** [061 · Routing](061-routing.md)
> **Next:** [063 · Name resolution and the DNS client](063-name-resolution-and-dns-client.md)

---

## What it is

**Bonding** combines two or more network cards (**ports**) into **one logical interface** (the **controller**, for example `bond0`). Depending on the **mode**, the bond gives you:
- **Failover:** if one cable, NIC or switch dies, traffic keeps flowing over another;
- **Aggregation:** many connections spread across several links for more total bandwidth.

It's done by the kernel's `bonding` driver and configured through NetworkManager. **Network teaming (teamd) is removed in RHEL 10**; bonding is the replacement. Older documents say "master/slave"; NetworkManager now says "controller/port" (nmcli accepts both).

Related ideas:
- **LACP** (Link Aggregation Control Protocol, IEEE 802.3ad): a protocol that lets the server and the switch agree on a bundle of links.
- **VLAN** (Virtual LAN): separate logical networks on one physical link, using tags.
- **Bridge**: a software switch inside Linux, used to connect VMs and containers.

## Why it exists

A single NIC, cable or switch port is a **single point of failure**. Servers in data centres are connected to **two switches**, so a failure or switch maintenance doesn't take them offline. Bonding makes the OS treat the two links as one: the IP address lives on `bond0`, and the bond decides which physical link carries the traffic.

## Analogy

Bonding is a **two-lane bridge with one name**. Cars (packets) are addressed to "the bridge", not to a lane. In **active-backup** mode, one lane is open and the other waits; if the open lane collapses, traffic switches to the spare. In **802.3ad** mode, both lanes are used and the traffic police (LACP, agreed with the switch) assign each car to a lane, but one car still only drives in one lane.

## How it works inside

- The bond has **one MAC address and one IP**. The kernel sends each outgoing frame out of one port, chosen by the **mode**.
- **Link monitoring:** with `miimon=100`, the driver checks every 100 ms whether each port's link is up (MII = Media Independent Interface, the NIC's link status). A failed port is taken out within that interval.
- In **active-backup**, when the active port fails, the bond moves traffic to a backup and sends **gratuitous ARP** (unrequested ARP announcements) so switches learn the new path immediately. You lose a packet or two.
- **A single TCP connection never goes faster than one port** (except in balance-rr, which can reorder packets). Aggregation only helps when there are **many** flows, because a **hash** of addresses/ports picks the port for each flow.

### Modes

| Mode | Name | Behaviour | Switch configuration |
|---|---|---|---|
| 0 | `balance-rr` | Round-robin, packet by packet | Static port-channel |
| 1 | **`active-backup`** | One active port, others standby | **None**: the safest choice, best for VMs |
| 2 | `balance-xor` | Port chosen by hash | Static port-channel |
| 3 | `broadcast` | Every packet on every port | Special cases only |
| 4 | **`802.3ad`** | LACP dynamic aggregation | **LACP configured on the switch** |
| 5 | `balance-tlb` | Adaptive transmit load balancing | None |
| 6 | `balance-alb` | Adaptive transmit + receive balancing | None |

## Commands

### Build an active-backup bond

```bash
nmcli dev status                          # find the two NICs to bond, e.g. enp0s9 and enp0s10
sudo nmcli con delete "Wired connection 2" "Wired connection 3"   # remove old profiles on those NICs

sudo nmcli con add type bond con-name bond0 ifname bond0 \
     bond.options "mode=active-backup,miimon=100" \
     ipv4.method manual ipv4.addresses 192.168.57.10/24 connection.autoconnect yes

sudo nmcli con add type ethernet con-name bond0-p1 ifname enp0s9  port-type bond controller bond0
sudo nmcli con add type ethernet con-name bond0-p2 ifname enp0s10 port-type bond controller bond0
sudo nmcli con up bond0
```

| `bond.options` | Meaning |
|---|---|
| `mode=` | See the table above |
| `miimon=100` | Check the link every 100 ms |
| `primary=enp0s9` | The preferred active port (active-backup) |
| `fail_over_mac=active` | Helps on hypervisors that block MAC changes |
| `lacp_rate=fast`, `xmit_hash_policy=layer3+4` | 802.3ad tuning (hash on IPs + ports for better spreading) |

### Verify

```bash
cat /proc/net/bonding/bond0
```
```
Ethernet Channel Bonding Driver: v6.12.0-264.16.1.el10_3.x86_64

Bonding Mode: fault-tolerance (active-backup)
Primary Slave: None
Currently Active Slave: enp0s9
MII Status: up
MII Polling Interval (ms): 100
...

Slave Interface: enp0s9
MII Status: up
Speed: 1000 Mbps
Duplex: full
Link Failure Count: 0

Slave Interface: enp0s10
MII Status: up
Speed: 1000 Mbps
Duplex: full
Link Failure Count: 0
```
- The mode, which port is **currently active**, each port's link status, and how many times each port has failed.

### Test failover

```bash
ping 192.168.57.11                        # in another window, keep it running
sudo nmcli dev disconnect enp0s9          # take down the ACTIVE port
grep 'Currently Active' /proc/net/bonding/bond0
```
```
Currently Active Slave: enp0s10
```
- The ping continues, losing at most a packet or two. Then `sudo nmcli dev connect enp0s9`.

### 802.3ad (LACP)

```bash
sudo nmcli con mod bond0 bond.options "mode=802.3ad,miimon=100,lacp_rate=fast,xmit_hash_policy=layer3+4"
sudo nmcli con up bond0
```
- The switch ports **must** be configured as an LACP port-channel too. Otherwise `/proc/net/bonding/bond0` shows a partner MAC of `00:00:00:00:00:00` and traffic misbehaves. Read the file with `sudo cat`: the partner details are hidden from normal users. Without LACP on the switch you also see each port in its **own** "Aggregator ID" (1 and 2), which means only one link carries traffic.

### VLANs and bridges on top

```bash
sudo nmcli con add type vlan con-name vlan10 ifname bond0.10 dev bond0 id 10 \
     ipv4.method manual ipv4.addresses 10.10.10.5/24          # tagged VLAN 10 over the bond
sudo nmcli con add type bridge con-name br0 ifname br0         # a software switch (for VMs, topic 100)
```

**Migrating from teaming:** on RHEL 9, before upgrading, convert team configs with the `team2bond` tool.

### Try it
1. Add two extra NICs to a lab VM (on the same host-only network), build `bond0` in active-backup mode, and give it an IP.
2. Ping it continuously from another VM while you disconnect the active port. Count lost packets.
3. Read `/proc/net/bonding/bond0` before and after.

## Where you'll use it

- **Bare-metal servers** in data centres: two NICs to two switches (active-backup, or 802.3ad with MLAG/stacked switches).
- **Hypervisors and Kubernetes nodes on bare metal:** a bond for redundancy, VLANs on top for separate traffic types, bridges for VMs.
- **VMs:** usually **not** needed; the hypervisor already gives the virtual NIC redundancy. If you do bond in a VM, use active-backup.
- **Cloud:** you don't bond; the provider handles NIC redundancy.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| A port NIC keeps its own IP; the bond has no ports | An old profile on the port NIC autoconnects | Delete or disable it; bring up the port profiles |
| 802.3ad: partner MAC `00:00:…`, poor speed | The switch isn't configured for LACP | Configure LACP on the switch, or use active-backup |
| No failover happens | `miimon=0`, or the virtual NIC never reports link down | `miimon=100`; test by disconnecting the active port |
| Duplicate packets, switch logs "MAC flapping" | balance-rr/xor without a matching switch config | Use active-backup, or configure the switch |
| `teamd: command not found` | Teaming is removed on RHEL 10 | Use bonding |
| One download is no faster with two links | Expected: one flow uses one port | Aggregation helps many parallel flows |

## Quick recap

- A bond = several ports, one logical interface (`bond0`), one IP. Configure it with `nmcli con add type bond …` plus `type ethernet … port-type bond controller bond0`.
- `active-backup` (mode 1) = failover with no switch configuration; `802.3ad` (mode 4) = LACP, which needs switch configuration.
- `miimon=100` monitors links; check `/proc/net/bonding/bond0`; test by disconnecting the active port.
- One flow never exceeds one port. Teaming is gone in RHEL 10.

**Interview questions**

1. *Which bonding mode gives high availability without switch configuration?* `active-backup` (mode 1): one port carries traffic, and another takes over if it fails.
2. *Does bonding two 1 Gbit links make a single download 2 Gbit/s?* No. Each flow is hashed to one port, so one connection is limited to one link's speed; aggregation helps when there are many flows.
3. *What does 802.3ad require?* LACP configured on the switch ports that form the bundle, matching the bond on the server.
