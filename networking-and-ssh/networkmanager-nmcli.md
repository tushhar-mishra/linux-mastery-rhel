# NetworkManager & nmcli: IPv4, IPv6, DNS & Hostname

> **Sessions:** S60 (hostname resolution **supplemented**) · **Objectives:** *Configure IPv4 and IPv6 addresses* · *Configure hostname resolution* · *Configure network services to start automatically at boot* **[RHCSA Core]**
> **Related:** [IP fundamentals](ip-addressing-fundamentals.md) · [Routing](routing.md) · [Bonding](network-bonding.md) · [SSH](ssh-remote-access.md) · [systemd services](../boot-systemd-and-kernel/systemd-targets-and-services.md)

## 1. Overview

On RHEL 10, **NetworkManager** (`NetworkManager.service`, enabled by default) owns network configuration. You manage it with **`nmcli`** (CLI), **`nmtui`** (text UI), Cockpit, or the GNOME settings. Configuration is stored as **keyfiles** in `/etc/NetworkManager/system-connections/*.nmconnection`.

**RHEL 10 changes:**

| Removed / deprecated | Use instead |
|---|---|
| `ifcfg` files (`/etc/sysconfig/network-scripts/`) | Keyfiles (`.nmconnection`) |
| `ifup` / `ifdown` | `nmcli con up` / `down` |
| teamd / NetworkManager-team | Bonding ([note](network-bonding.md)) |
| `dhclient` | NetworkManager's internal DHCP client |
| net-tools (`ifconfig`, `route`, `netstat`), deprecated, not installed by default | `ip`, `ss` |

## 2. Key Concepts

| Term | Meaning |
|---|---|
| **Device** | A network interface (`ens160`, `bond0`) |
| **Connection (profile)** | A named set of settings applied to a device; several may exist, but one is active per device |
| `connection.autoconnect` | Activate the profile automatically at boot / when the device appears |
| `ipv4.method` / `ipv6.method` | `auto` (DHCP/SLAAC), `manual` (static), `disabled`, `link-local`, `shared` (ipv4) / `dhcp`, `ignore` (ipv6) |

Interface names like `ens160` come from **predictable naming** (firmware/PCI location), so they stay stable across reboots.

## 3. Viewing

````bash
nmcli general status ; nmcli dev status          # (= nmcli d s) devices and their active connection
nmcli con show                                   # (= nmcli c s) all profiles; --active / -a only active
nmcli con show ens160                            # all properties of a profile
nmcli -g ipv4.addresses,ipv4.gateway,ipv4.dns con show ens160   # selected values
nmcli dev show ens160                            # runtime state: IP4.ADDRESS, IP4.ROUTE, IP4.DNS …
ip -br addr ; ip addr show ens160 ; ip route ; ip -6 route
cat /etc/NetworkManager/system-connections/ens160.nmconnection   # (root; mode 600)
````

## 4. Static IPv4 **[RHCSA Core]**

### Modify the existing profile (typical exam task)

````bash
nmcli con mod ens160 ipv4.addresses 192.168.1.50/24 ipv4.gateway 192.168.1.1 \
      ipv4.dns "192.168.1.1 8.8.8.8" ipv4.dns-search example.com \
      ipv4.method manual connection.autoconnect yes
nmcli con up ens160                       # apply (re-activate)
ip -br addr show ens160 ; ip route ; cat /etc/resolv.conf
````

### Create a new profile

````bash
nmcli con add type ethernet con-name static2 ifname ens160 \
      ip4 192.168.1.50/24 gw4 192.168.1.1            # ip4/gw4 shortcuts set method manual
nmcli con mod static2 ipv4.dns "8.8.8.8 8.8.4.4"
nmcli con up static2
````

When you create a profile with the full property names (`ipv4.addresses`, `ipv4.gateway`), also set `ipv4.method manual`.

### Other common changes

````bash
nmcli con mod ens160 +ipv4.addresses 192.168.1.55/24     # add a second address
nmcli con mod ens160 -ipv4.addresses 192.168.1.55/24     # remove it
nmcli con mod ens160 +ipv4.dns 1.1.1.1 ; nmcli con mod ens160 -ipv4.dns 1.1.1.1
nmcli con mod ens160 ipv4.ignore-auto-dns yes            # with DHCP: use only your DNS servers
nmcli con mod ens160 ipv4.method auto ipv4.addresses "" ipv4.gateway "" ipv4.dns ""   # back to DHCP
nmcli con mod static2 connection.autoconnect no
````

## 5. Static IPv6 **[RHCSA Core]**

````bash
nmcli con mod ens160 ipv6.addresses 'fddb:fe2a:ad1e::c0a8:8/64' ipv6.gateway 'fddb:fe2a:ad1e::1' \
      ipv6.dns '2001:4860:4860::8888' ipv6.method manual
nmcli con up ens160
ip -6 addr show ens160 ; ip -6 route
ping fddb:fe2a:ad1e::1            # ping handles IPv6 (ping -6 optional)
nmcli con mod ens160 ipv6.method disabled   # turn IPv6 off for a profile
````

IPv6 is configured independently of IPv4 and the hostname.

## 6. Activating, Reloading, Deleting

| Command | Effect |
|---|---|
| `nmcli con up NAME` | Activate / re-apply a profile (use after `mod`) |
| `nmcli con down NAME` | Deactivate (a profile with autoconnect may come back on reboot) |
| `nmcli dev reapply ens160` | Apply changes without a full down/up (some settings) |
| `nmcli dev disconnect ens160` / `connect ens160` | Stop/start the device (no autoconnect until reconnected) |
| `nmcli con reload` | Re-read keyfiles after **manual** edits |
| `nmcli con load /etc/NetworkManager/system-connections/x.nmconnection` | Load one edited file |
| `nmcli con delete NAME` | Delete a profile (and its file) |
| `nmcli dev delete bond0` | Delete a **software** device (bond, bridge, VLAN) |

> ⚠️ Changing the profile you're connected through over SSH can cut your session. Use the console, or chain the change with `nmcli con up` in one command line.

## 7. Keyfile Anatomy

````ini
[connection]
id=ens160                 # profile name
uuid=ddf36091-…           # unique ID
type=ethernet
interface-name=ens160     # device this profile binds to
autoconnect-priority=-999 # lower = less preferred among candidate profiles

[ipv4]
method=manual
address1=192.168.1.50/24,192.168.1.1   # address,gateway
dns=192.168.1.1;8.8.8.8;
dns-search=example.com;

[ipv6]
addr-gen-mode=default     # eui64 or stable-privacy
method=auto
````

When editing by hand, keep the mode at `600` (root:root), then run `nmcli con reload` and `nmcli con up`.

## 8. Interactive Tools

````bash
nmcli con edit ens160        # nmcli> print · set ipv4.method manual · set ipv4.addresses … · save · quit
nmtui                        # menu-driven: Edit a connection / Activate / Set hostname
````

**Per-user profiles:** `nmcli con mod NAME connection.permissions user:alice` (several: `user:alice,bob`). Only those users can activate the profile.

## 9. Hostname & Name Resolution (supplemented) **[RHCSA Core]**

````bash
hostnamectl                                   # static/transient hostname, OS, kernel
hostnamectl hostname server1.example.com      # set (persistent, /etc/hostname); older form: set-hostname
hostname                                      # current
````

| File | Role |
|---|---|
| `/etc/hosts` | Static name → IP map, checked first by default |
| `/etc/nsswitch.conf` | Lookup order: `hosts: files dns myhostname` (managed by authselect) |
| `/etc/resolv.conf` | DNS servers and search domains, **generated by NetworkManager** from profile settings |

````bash
echo '192.168.1.20  server2.example.com server2' >> /etc/hosts
getent hosts server2               # resolves via nsswitch (files + DNS): best test
dnf install -y bind-utils
dig server2.example.com +short ; host www.redhat.com ; nslookup www.redhat.com   # DNS only (ignores /etc/hosts)
````

> Set DNS with `nmcli … ipv4.dns`. Manual edits to `/etc/resolv.conf` are overwritten when NetworkManager re-applies a connection.

## 10. Network Services at Boot

- NetworkManager must be enabled (`systemctl is-enabled NetworkManager`), and profiles need `connection.autoconnect yes`.
- Services (sshd, httpd, …) need `systemctl enable --now SERVICE` plus a firewall opening (S69–70).
- `NetworkManager-wait-online.service` makes `network-online.target` wait for the network; services that need the network at boot order themselves after it.

## 11. RHCSA Exam Focus **[RHCSA Core]**

- Configure exactly the requested address, prefix, gateway, DNS (and IPv6 if asked) on the **existing** profile of the given interface.
- `connection.autoconnect yes` + `nmcli con up` + **reboot test**: `ip -br addr`, `ip route`, `cat /etc/resolv.conf`, `getent hosts NAME`.
- Hostname: `hostnamectl hostname FQDN`; check `/etc/hostname`.
- Watch for typos in prefixes (`/24` vs `255.255.255.0`).

## 12. Production Practices **[Production Practice]**

- Keep one profile per interface, with clear names; delete stale "Wired connection N" profiles.
- Script with `nmcli` (idempotent `mod`) or the RHEL **network** system role (Ansible) rather than editing keyfiles by hand.
- Document static addressing; use DHCP reservations where possible.

## 13. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Change doesn't take effect | Profile not re-activated | `nmcli con up NAME` |
| Old IP comes back after reboot | Edited a different profile, or another profile autoconnects | `nmcli con show`; delete/disable duplicates |
| `Error: Connection activation failed: No suitable device found` | `interface-name` mismatch | `nmcli dev status`; fix `connection.interface-name` |
| DNS resets after editing `/etc/resolv.conf` | NetworkManager manages it | `nmcli con mod … ipv4.dns` |
| Name resolves with `getent` but not `dig` | Name only in `/etc/hosts` | Expected; `dig` queries DNS only |
| `ifup: command not found` / `ifconfig: command not found` | Removed/not installed on RHEL 10 | `nmcli con up`; `ip addr` |
| Manual keyfile edit ignored | NetworkManager not told | `nmcli con reload`; mode 600 |

## 14. Interview Questions

| Question | Answer |
|---|---|
| Device vs connection in NetworkManager? | A device is the interface; a connection is a saved profile of settings applied to it. |
| How do you set a static IP persistently? | `nmcli con mod NAME ipv4.addresses … ipv4.gateway … ipv4.dns … ipv4.method manual` then `nmcli con up NAME`. |
| Where are profiles stored on RHEL 10? | `/etc/NetworkManager/system-connections/*.nmconnection`. |
| How do you test name resolution including `/etc/hosts`? | `getent hosts NAME`. |
| Why not edit `/etc/resolv.conf` directly? | NetworkManager regenerates it. |

## 15. Course Corrections

| Course | Correction |
|---|---|
| `ifup ens256`, `ifconfig`, `cat ifcfg-Myhome1` | Not on RHEL 10: `nmcli con up`, `ip addr`, keyfiles |
| `dnf install NetworkManager` | Preinstalled and enabled |
| "gwv4" | `ipv4.gateway` |
| `connection.permissions vikasnehra` | `user:vikasnehra` |
| IPv6 needs "static hostname or IPv4 set already" | Not required |
| `ping -6` required | Optional; `ping` detects IPv6 |
| `nmcli con down x ; nmcli con up x` | `nmcli con up x` alone re-applies |
| vnStat for monitoring | EPEL, not RHEL repos |

## 16. Quick Revision

````bash
nmcli d s | c s | con show NAME | dev show DEV | -g props · ip -br a · ip r · ip -6 a
nmcli con mod NAME ipv4.addresses A/P ipv4.gateway G ipv4.dns "D1 D2" ipv4.method manual connection.autoconnect yes ; nmcli con up NAME
nmcli con add type ethernet con-name N ifname D ip4 A/P gw4 G · +/-ipv4.addresses · ipv4.ignore-auto-dns yes
ipv6.addresses ipv6.gateway ipv6.dns ipv6.method manual|auto|disabled
nmcli con reload | delete | edit · nmtui · hostnamectl hostname FQDN · /etc/hosts · getent hosts · dig/host (bind-utils)
