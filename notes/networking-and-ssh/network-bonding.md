# Network Bonding on RHEL 10

> **[Advanced/Optional]** · production high availability; replaces teaming on RHEL 10
> **Related:** [NetworkManager & nmcli](networkmanager-nmcli.md) · [Routing](routing.md) · [Packet capture](packet-capture.md)

## 1. Overview

**Bonding** combines two or more NICs (**ports**) into one logical interface (**controller**, e.g. `bond0`) for **failover** and/or **aggregate throughput**. It's implemented by the kernel `bonding` driver and managed through NetworkManager. **Teaming (teamd, NetworkManager-team) is removed in RHEL 10**; bonding is the supported replacement.

Terminology: NetworkManager now uses **controller/port** (older docs and options: master/slave; both spellings are still accepted by nmcli).

## 2. Bonding Modes

| Mode | Name | Behavior | Switch requirement |
|---|---|---|---|
| 0 | `balance-rr` | Round-robin packets across ports | Static EtherChannel/port-channel |
| 1 | **`active-backup`** | One active port, others standby | **None** (safest; best for VMs) |
| 2 | `balance-xor` | Port chosen by hash (MAC/IP/port) | Static EtherChannel |
| 3 | `broadcast` | Every packet on all ports | Special cases only |
| 4 | **`802.3ad`** | LACP dynamic aggregation | **LACP configured on the switch** |
| 5 | `balance-tlb` | Adaptive transmit load balancing | None |
| 6 | `balance-alb` | Adaptive transmit + receive load balancing | None |

A single TCP flow never exceeds one port's speed (except balance-rr, which can reorder packets). Aggregation helps with **many** flows.

## 3. Configure with nmcli

```bash
nmcli dev status                          # identify the port NICs (e.g., ens224, ens256)
nmcli con show                            # delete/disable existing profiles on those NICs first:
nmcli con delete "Wired connection 1"     # (or: nmcli con mod <old> connection.autoconnect no)

nmcli con add type bond con-name bond0 ifname bond0 \
      bond.options "mode=active-backup,miimon=100" \
      ipv4.addresses 192.168.1.100/24 ipv4.gateway 192.168.1.1 ipv4.dns 192.168.1.1 \
      ipv4.method manual connection.autoconnect yes

nmcli con add type ethernet con-name bond0-port1 ifname ens224 port-type bond controller bond0
nmcli con add type ethernet con-name bond0-port2 ifname ens256 port-type bond controller bond0
#   (older equivalent syntax: … master bond0 / slave-type bond)

nmcli con up bond0                        # ports with autoconnect come up with the controller
nmcli con up bond0-port1 ; nmcli con up bond0-port2
```

| Option (`bond.options`) | Meaning |
|---|---|
| `mode=` | See §2 |
| `miimon=100` | Link check every 100 ms |
| `primary=ens224` | Preferred active port (active-backup) |
| `fail_over_mac=active` | Useful on some hypervisors that filter MAC changes |
| `lacp_rate=fast`, `xmit_hash_policy=layer3+4` | 802.3ad tuning |

## 4. Verify & Test Failover

```bash
nmcli dev status                          # bond0 connected; ports connected
cat /proc/net/bonding/bond0               # Mode, Currently Active Slave, MII Status per port
ip -br addr show bond0
ping 192.168.1.1                          # keep running in another terminal
nmcli dev disconnect ens224               # take down the ACTIVE port (check /proc/net/bonding/bond0)
cat /proc/net/bonding/bond0               # other port now active; ping loses ≤1–2 packets
nmcli dev connect ens224
journalctl -u NetworkManager -b | grep -i bond0
```

For load-balancing modes, generate several parallel flows (e.g., `iperf3 -P 4`) and watch each port with `ip -s link show ens224` or `tcpdump -i ens224`.

## 5. Related Layer-2 Constructs **[Advanced]**

```bash
nmcli con add type vlan con-name vlan10 ifname bond0.10 dev bond0 id 10 ipv4.method manual ipv4.addresses 10.10.10.5/24
nmcli con add type bridge con-name br0 ifname br0          # for VMs; add ports with port-type bridge controller br0
```

**Migrating teams before upgrading to RHEL 10:** RHEL 9 provides a `team2bond` utility to convert team configurations to bonds.

## 6. Production Practices **[Production Practice]**

- Connect ports to **different switches** (active-backup) or an MLAG/stacked pair (802.3ad).
- Match the bond mode with the switch configuration: LACP on both sides, or none.
- In VMs, prefer `active-backup`; the hypervisor already provides redundancy for the virtual NIC.
- Monitor `/proc/net/bonding/bond0` and link events; alert on a degraded bond.

## 7. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Port NIC keeps its own IP / bond has no ports | Old profile on the port NIC autoconnects | Delete/disable it; bring up the port profiles |
| 802.3ad bond: "Partner MAC 00:00:00…", low speed | Switch not configured for LACP | Configure LACP on the switch, or use active-backup |
| No failover | `miimon` 0 / link not detected (virtual NIC) | `miimon=100`; test by disconnecting the active port |
| Duplicate packets / MAC flapping | balance-rr/xor without switch config | Use active-backup or configure the switch |
| `teamd` not found | Removed in RHEL 10 | Bonding |

## 8. Interview Questions

| Question | Answer |
|---|---|
| Bonding vs teaming on RHEL 10? | Teaming is removed; bonding (kernel driver, NetworkManager-managed) is the supported option. |
| Which mode needs no switch configuration and gives HA? | `active-backup` (mode 1). |
| What does 802.3ad require? | LACP configured on the switch ports. |
| Does bonding double the speed of a single download? | No; a single flow uses one port (except balance-rr). |
| How do you see which port is active? | `cat /proc/net/bonding/bond0`. |

## 9. Quick Revision

```bash
nmcli con add type bond con-name bond0 ifname bond0 bond.options "mode=active-backup,miimon=100" ipv4.method manual ipv4.addresses …
nmcli con add type ethernet con-name bond0-portN ifname NIC port-type bond controller bond0
nmcli con up bond0 · cat /proc/net/bonding/bond0 · nmcli dev disconnect ACTIVE_PORT (test)
modes: 0 rr · 1 active-backup · 2 xor · 3 broadcast · 4 802.3ad(LACP) · 5 tlb · 6 alb
```

## 10. Cross-References

- [NetworkManager & nmcli](networkmanager-nmcli.md)
- [Routing](routing.md)
- [Packet capture](packet-capture.md)
