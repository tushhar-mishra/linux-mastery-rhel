# firewalld: Zones, Services, Ports, NAT & Rich Rules

> **Sessions:** S69–S70 · **Objectives:** *Configure firewall settings using firewall-cmd/firewalld* · *Restrict network access using firewall-cmd/firewalld* **[RHCSA Core]**
> **Related:** [SELinux fundamentals](selinux-fundamentals.md) · [NetworkManager](../networking-and-ssh/networkmanager-nmcli.md) · [Routing (forwarding)](../networking-and-ssh/routing.md) · [SSH hardening (port change)](../networking-and-ssh/ssh-server-hardening.md) · [systemd services](../boot-systemd-and-kernel/systemd-targets-and-services.md)

## 1. Overview

A **firewall** filters network traffic according to rules: what may enter (incoming), leave (outgoing) and pass through (forwarding). On RHEL the kernel's **netfilter** does the filtering. Rules are written into **nftables** by the **firewalld** daemon, which you control with **`firewall-cmd`** (CLI), **`firewall-config`** (GUI) or Cockpit.

````
firewall-cmd / firewall-config / Cockpit ──D-Bus──► firewalld ──► nftables ──► kernel netfilter
````

**Defaults:** firewalld is installed and enabled. Incoming connections are allowed only for services in the zone (public: `ssh`, `dhcpv6-client`, `cockpit`); replies to your own connections and all outgoing traffic are allowed.

| RHEL | Firewall stack |
|---|---|
| 6 | `iptables` service + `/etc/sysconfig/iptables` |
| 7 | firewalld (iptables backend); iptables-services optional (with firewalld masked) |
| 8 / 9 | firewalld with **nftables** backend; `iptables` command is a compatibility layer (deprecated in 9) |
| 10 | firewalld + nftables: use `firewall-cmd` (or `nft` for low-level work) |

## 2. Key Concepts

| Concept | Meaning |
|---|---|
| **Zone** | A trust level with its own allowed services/ports; each interface or source network belongs to one zone |
| **Service** | Named set of ports/protocols/helpers (`http` = 80/tcp), defined in XML |
| **Port** | Raw `port/protocol` opening (`8080/tcp`) |
| **Source** | Network/IP bound to a zone (`192.168.1.0/24` → `internal`); source bindings take precedence over interface bindings |
| **Runtime vs permanent** | Runtime = active now, lost on reload/reboot. Permanent = saved, applied after `--reload` |
| **Rich rule** | Detailed rule: source/destination, service/port, accept/reject/drop, log, rate limit |
| **Masquerade / forward-port** | NAT for routing; port redirection |
| **Policy** | Rules between zones (forwarded traffic) **[Advanced]** |

### Predefined zones

| Zone | Default behavior for incoming traffic |
|---|---|
| `drop` | Silently drop everything |
| `block` | Reject with ICMP prohibited |
| `public` | **Default.** Only selected services (untrusted networks) |
| `external` | Masquerading on; for router uplinks |
| `dmz` | Limited services for public-facing hosts |
| `work`, `home`, `internal` | Increasing trust; selected services |
| `trusted` | Accept everything |

### Files

| Path | Content |
|---|---|
| `/usr/lib/firewalld/{zones,services}/*.xml` | Shipped defaults (don't edit) |
| `/etc/firewalld/{zones,services}/*.xml` | Your permanent configuration (overrides) |
| `/etc/firewalld/firewalld.conf` | Daemon settings (`DefaultZone`, logging) |

## 3. Status & Information

````bash
systemctl status firewalld ; firewall-cmd --state          # running
firewall-cmd --get-default-zone ; firewall-cmd --get-active-zones   # zones in use + their interfaces/sources
firewall-cmd --list-all                                    # default zone: services, ports, rich rules …
firewall-cmd --list-all --zone=internal ; firewall-cmd --list-all-zones
firewall-cmd --list-services ; --list-ports ; --list-rich-rules
firewall-cmd --get-services | tr ' ' '\n' | grep -x http   # available service names
firewall-cmd --info-service=http                           # ports of a service
firewall-cmd --check-config                                # validate permanent XML
````

## 4. Opening Services & Ports **[RHCSA Core]**

````bash
# Recommended pattern: permanent + reload
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --permanent --add-port=8080/tcp
firewall-cmd --permanent --add-port=60000-60010/udp
firewall-cmd --reload
firewall-cmd --list-all                                    # verify

# Alternative: change runtime, test, then save
firewall-cmd --add-service=http ; curl http://SERVER/      # test from another host
firewall-cmd --runtime-to-permanent

# Remove
firewall-cmd --permanent --remove-service=cockpit ; firewall-cmd --permanent --remove-port=8080/tcp ; firewall-cmd --reload
````

Without `--zone=`, commands act on the **default zone**. Prefer **services** over raw ports: they're named, documented and may include several ports and helpers.

## 5. Zones, Interfaces & Sources

````bash
firewall-cmd --set-default-zone=internal                         # persistent immediately
nmcli con mod ens160 connection.zone internal ; nmcli con up ens160   # persistent zone for an NM interface
firewall-cmd --permanent --zone=internal --add-source=192.168.1.0/24 ; firewall-cmd --reload   # traffic FROM this net uses internal
firewall-cmd --zone=home --change-interface=ens33                # runtime-only interface move
firewall-cmd --permanent --new-zone=myoffice ; firewall-cmd --reload   # custom zone
````

## 6. Custom Services

````bash
firewall-cmd --permanent --new-service=myapp
firewall-cmd --permanent --service=myapp --set-short="My App" --add-port=7575/tcp
firewall-cmd --reload
firewall-cmd --permanent --add-service=myapp ; firewall-cmd --reload
cat /etc/firewalld/services/myapp.xml
````

Or copy and edit XML: `cp /usr/lib/firewalld/services/ssh.xml /etc/firewalld/services/myapp.xml`, adjust, then `--reload`.

## 7. Port Forwarding & Masquerading

````bash
# Redirect incoming 7070/tcp to local port 9090
firewall-cmd --permanent --add-forward-port=port=7070:proto=tcp:toport=9090
# Forward incoming 9090/tcp to another host (needs masquerading)
firewall-cmd --permanent --add-masquerade                 # also turns on IPv4 forwarding
firewall-cmd --permanent --add-forward-port=port=9090:proto=tcp:toport=9090:toaddr=192.168.0.143
firewall-cmd --reload ; firewall-cmd --list-all ; firewall-cmd --query-masquerade
# Allow routing between interfaces of the same zone
firewall-cmd --permanent --add-forward ; firewall-cmd --reload
````

Forward-port rules apply to **incoming** traffic. Test from another machine, not from the firewall host itself.

## 8. Rich Rules

````bash
# Allow SSH only from one subnet
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.0/24" service name="ssh" accept'
firewall-cmd --permanent --remove-service=ssh            # (then nobody else can reach SSH)

# Reject one host from SSH
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.0.194" port port="22" protocol="tcp" reject'

# Log and limit
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" service name="http" log prefix="HTTP " level="info" limit value="5/m" accept'

firewall-cmd --reload ; firewall-cmd --list-rich-rules
firewall-cmd --permanent --remove-rich-rule='<exact same rule text>' ; firewall-cmd --reload
````

Actions: `accept` / `reject` (sends an error) / `drop` (silent). Rich rules are useful for "allow service X only from network Y".

## 9. ICMP Control

````bash
firewall-cmd --get-icmptypes
firewall-cmd --permanent --add-icmp-block=echo-request ; firewall-cmd --reload   # block ping
firewall-cmd --query-icmp-block=echo-request
firewall-cmd --permanent --remove-icmp-block=echo-request ; firewall-cmd --reload
firewall-cmd --permanent --add-icmp-block-inversion      # listed ICMP types become the ONLY allowed ones; all others rejected
````

## 10. Other Operations

````bash
firewall-cmd --panic-on / --panic-off      # drop ALL traffic immediately ⚠️ (cuts SSH) [Advanced]
nft list ruleset | less                     # inspect generated nftables rules (read-only) [Advanced]
dnf install -y firewall-config ; firewall-config   # GUI (writes the same configuration)
systemctl disable --now firewalld           # lab only; better: keep it and open what's needed
````

### Inter-zone policies **[Advanced]**

````bash
firewall-cmd --permanent --new-policy int2ext
firewall-cmd --permanent --policy int2ext --add-ingress-zone internal --add-egress-zone external --set-target ACCEPT
firewall-cmd --reload
````

## 11. Common Ports

| Service | Port | Service | Port |
|---|---|---|---|
| FTP | 20, 21/tcp | DNS | 53/tcp+udp |
| SSH | 22/tcp | DHCP | 67, 68/udp |
| Telnet | 23/tcp | HTTP / HTTPS | 80 / 443/tcp |
| SMTP | 25/tcp | POP3 / IMAP | 110 / 143/tcp |
| NFS | 2049/tcp | Samba | 445/tcp |

Port ranges: 0–1023 well-known (binding needs root), 1024–49151 registered, 49152–65535 dynamic. Linux uses 32768–60999 for outgoing client ports.

## 12. RHCSA Exam Focus **[RHCSA Core]**

- Open exactly what the task needs (service or port), **`--permanent` + `--reload`**, then verify with `--list-all`. Rules must survive a reboot.
- Non-standard ports for a service usually need **both** a firewall rule and an SELinux port label (`semanage port`, S76).
- Restrict access: rich rules with `source address=` or `--add-source` to a zone.
- Don't stop firewalld to "fix" a task.

## 13. Production Practices **[Production Practice]**

- Keep the default zone strict (public); add only required services.
- Prefer source-based zones or rich rules for admin services (SSH, Cockpit) from management networks.
- Manage firewall state as code (Ansible `firewall` system role) and review `--list-all-zones` regularly.
- Remove unused default services (e.g., `cockpit`, `dhcpv6-client`) when not needed.

## 14. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Works now, gone after reboot/reload | Runtime-only change | `--permanent` + `--reload`, or `--runtime-to-permanent` |
| Added `--permanent`, still blocked | Not reloaded | `firewall-cmd --reload` |
| Rule in wrong zone | Interface/source in another zone | `--get-active-zones`; use `--zone=` |
| `Error: INVALID_SERVICE: example` | Service not defined | Create it (§6) and reload |
| Service reachable locally (`curl localhost`) but not remotely | Firewall (or service bound to 127.0.0.1) | `--list-all`; `ss -tlnp` |
| Firewall open, still refused | SELinux port label / service not listening | `semanage port -l`; `ss -tlnp`; `ausearch -m avc` |
| Port forward "doesn't work" | Tested from the firewall host | Test from another machine; check masquerade |

## 15. Interview Questions

| Question | Answer |
|---|---|
| firewalld vs iptables? | firewalld is a dynamic manager (zones, services, D-Bus) generating nftables rules on RHEL 8+; iptables was the older static rule tool. |
| Runtime vs permanent? | Runtime is active now and lost on reload; permanent is stored and applied after reload. |
| How do you allow HTTP only from 10.0.0.0/8? | Rich rule with `source address="10.0.0.0/8" service name="http" accept` (without opening http to everyone). |
| `drop` vs `block` zone? | drop silently discards; block rejects with an ICMP message. |
| What does masquerading do? | Source NAT: rewrites the source address of forwarded traffic to the firewall's own address. |

## 16. Course Corrections

| Course | Correction |
|---|---|
| RHEL 8/9/10 "no support for iptables" | RHEL 8/9 ship an iptables-nft compatibility command (deprecated in 9); use firewall-cmd/nft |
| RHEL 7: "remove firewalld to use iptables" | Install `iptables-services` and mask firewalld |
| "XDP … under firewalld in RHEL 10" | firewalld manages nftables; XDP is separate eBPF technology |
| `--change-interface` without `--permanent` | Runtime only; use `nmcli … connection.zone` |
| Ports "1024–65535 unreserved" | Registered 1024–49151, dynamic 49152–65535 |
| `dnf remove firewalld` exercise | Lab only; don't remove on servers |
| ICMP block inversion "reverses allow/block" | With an empty block list it **rejects all ICMP**; listed types become allowed |

## 17. Quick Revision

````bash
firewall-cmd --state | --get-default-zone | --set-default-zone=Z | --get-active-zones | --list-all [--zone=Z] | --list-all-zones
--permanent --add-service=S | --add-port=P/tcp | --remove-… ; --reload ; --runtime-to-permanent
--permanent --zone=Z --add-source=NET · nmcli con mod C connection.zone Z
--new-service=S ; --service=S --add-port=P/tcp · --add-forward-port=port=A:proto=tcp:toport=B[:toaddr=IP] · --add-masquerade · --add-forward
--add-rich-rule='rule family="ipv4" source address="NET" service name="ssh" accept|reject|drop' · --add-icmp-block=echo-request
