# 060 · NetworkManager and nmcli: Configuring Interfaces (and netplan on Ubuntu)

> **You need first:** [059 · IP addressing and subnetting](059-ip-addressing-and-subnetting.md)
> **Next:** [061 · Routing](061-routing.md)

---

## What it is

**NetworkManager** is the service that owns network configuration on RHEL (and Fedora, and Ubuntu Desktop). You talk to it with:
- **`nmcli`**: the command-line tool (scriptable; what you'll use on servers);
- **`nmtui`**: a menu-based text UI;
- Cockpit or GNOME Settings: graphical.

Two key words:
- **Device**: a network interface (`enp0s8`, `bond0`).
- **Connection** (or **profile**): a **saved set of settings** (IP, gateway, DNS, autoconnect…) that can be applied to a device. A device can have several profiles, but only one is active at a time.

On RHEL 10, profiles are stored as **keyfiles**: `/etc/NetworkManager/system-connections/<name>.nmconnection`. The old `ifcfg` files (`/etc/sysconfig/network-scripts/`), `ifup`/`ifdown`, network teaming and `dhclient` are **gone**.

**Ubuntu Server** uses **netplan**: YAML files in `/etc/netplan/` that netplan turns into configuration for **systemd-networkd** (or NetworkManager on desktops).

## Why it exists

Servers need **persistent**, correct network settings: the right address, gateway and DNS after every reboot. `ip addr add` changes only the running kernel and is **lost at reboot**. NetworkManager stores the intended configuration, applies it at boot, reacts to link changes (cable plugged in, DHCP renewals), and writes the DNS configuration for you.

## Analogy

A **device** is a **phone**; a **connection profile** is a **SIM card** with a set of settings. You can have several SIM cards for one phone ("office", "home") but only one in at a time. `nmcli con mod` edits the settings on a SIM card; `nmcli con up` puts it in the phone and connects.

## How it works inside

- `NetworkManager.service` starts at boot, reads all keyfiles, and for each device activates the best matching profile with `connection.autoconnect=yes`.
- Activating a profile means NetworkManager tells the kernel (through **netlink**, the kernel's interface for network configuration) to set addresses and routes, runs its **internal DHCP client** if `ipv4.method=auto`, and writes `/etc/resolv.conf` (topic 063).
- **`nmcli con mod` only edits the saved profile.** Nothing changes on the live interface until you **re-activate** it (`nmcli con up NAME`) or reapply (`nmcli dev reapply DEV`).
- **Predictable interface names** (`enp0s3`, `ens160`) come from the hardware location, so they're stable across reboots. Cloud images may still use `eth0`.
- `NetworkManager-wait-online.service` makes the boot target `network-online.target` wait until the network is configured. Services that need the network at startup are ordered after it (topic 098).

### The `ipv4.method` / `ipv6.method` setting

| Value | Meaning |
|---|---|
| `auto` | DHCP (IPv4) / SLAAC+DHCPv6 (IPv6) |
| `manual` | Static addresses you set |
| `disabled` | No IPv4 / IPv6 on this profile |
| `link-local` | Only a self-assigned link-local address |
| `shared` (IPv4) | Share this machine's connection with other machines (NAT + DHCP) |
| `dhcp`, `ignore` (IPv6) | DHCPv6 only / leave IPv6 alone |

## Commands

### Look

```bash
nmcli dev status
```
```
DEVICE  TYPE      STATE                   CONNECTION
enp0s3  ethernet  connected               enp0s3
enp0s8  ethernet  connected               Wired connection 1
lo      loopback  connected (externally)  lo
```

```bash
nmcli con show
```
```
NAME                UUID                                  TYPE      DEVICE
enp0s3              5fb06bd0-0bb0-7ffb-45f1-d6edd65f3e03  ethernet  enp0s3
Wired connection 1  2a6b5c9e-1d6f-3a8b-9e0c-7d1f2e3a4b5c  ethernet  enp0s8
lo                  6d0d1f2e-...                          loopback  lo
```
- Profile names can differ from device names. `Wired connection 1` is an auto-created profile; rename it for clarity with `nmcli con mod "Wired connection 1" connection.id lab`.

```bash
nmcli -g ipv4.method,ipv4.addresses,ipv4.gateway,ipv4.dns con show lab
nmcli dev show enp0s8 | grep -E 'IP4|GENERAL.STATE'
```
```
manual
192.168.56.10/24

GENERAL.STATE:                          100 (connected)
IP4.ADDRESS[1]:                         192.168.56.10/24
IP4.ROUTE[1]:                           dst = 192.168.56.0/24, nh = 0.0.0.0, mt = 101
```
- `con show` = the **saved** settings. `dev show` = what's **live** right now.

### Set a static IPv4 address on an existing profile

```bash
sudo nmcli con mod lab \
     ipv4.method manual \
     ipv4.addresses 192.168.56.10/24 \
     ipv4.gateway 192.168.56.1 \
     ipv4.dns "192.168.56.1 1.1.1.1" \
     ipv4.dns-search example.com \
     connection.autoconnect yes
sudo nmcli con up lab
ip -br addr show enp0s8 ; ip route ; cat /etc/resolv.conf
```
```
Connection successfully activated (D-Bus active path: /org/freedesktop/NetworkManager/ActiveConnection/5)
enp0s8           UP             192.168.56.10/24
...
# Generated by NetworkManager
search example.com
nameserver 192.168.56.1
nameserver 1.1.1.1
```
- With several active connections, NetworkManager **merges** the DNS servers of all of them into `/etc/resolv.conf`. The C library only uses the first **three** `nameserver` lines; if there are more, NetworkManager adds a `# NOTE: the libc resolver may not support more than 3 nameservers` comment, and the extras are silently ignored. Use `ipv4.ignore-auto-dns yes` on connections whose DHCP DNS you don't want, or set `ipv4.dns-priority`.
- **Changing the profile you're connected through over SSH can cut your session.** Use the console, or make the change and the `con up` in one command line.

### Create a new profile

```bash
sudo nmcli con add type ethernet con-name office ifname enp0s8 \
     ipv4.method manual ipv4.addresses 10.20.0.15/24 ipv4.gateway 10.20.0.1 ipv4.dns 10.20.0.2
sudo nmcli con up office
```

### Other common changes

```bash
sudo nmcli con mod lab +ipv4.addresses 192.168.56.20/24     # add a second address
sudo nmcli con mod lab -ipv4.addresses 192.168.56.20/24     # remove it
sudo nmcli con mod lab +ipv4.dns 9.9.9.9
sudo nmcli con mod lab ipv4.ignore-auto-dns yes              # with DHCP: ignore DHCP's DNS, use yours
sudo nmcli con mod lab ipv4.method auto ipv4.addresses "" ipv4.gateway "" ipv4.dns ""   # back to DHCP
sudo nmcli con mod lab 802-3-ethernet.mtu 9000               # jumbo frames (topic 095)
```

### Static IPv6

```bash
sudo nmcli con mod lab ipv6.method manual \
     ipv6.addresses 'fd00:56::10/64' ipv6.gateway 'fd00:56::1' ipv6.dns 'fd00:56::1'
sudo nmcli con up lab
ip -6 -br addr show enp0s8
```
- IPv6 settings are independent of IPv4. `ipv6.method disabled` turns IPv6 off for that profile.

### Activate, reload, delete

| Command | Effect |
|---|---|
| `nmcli con up NAME` | Activate / re-apply a profile (do this after `mod`) |
| `nmcli con down NAME` | Deactivate (it may come back at reboot if autoconnect is on) |
| `nmcli dev reapply DEV` | Apply profile changes without a full down/up (works for many settings) |
| `nmcli con reload` | Re-read keyfiles after editing them **by hand** |
| `nmcli con delete NAME` | Delete a profile (and its file) |
| `nmcli dev disconnect DEV` | Take the device down (no autoconnect until reconnected) |

### The keyfile

```bash
sudo cat /etc/NetworkManager/system-connections/lab.nmconnection
```
```ini
[connection]
id=lab
uuid=2a6b5c9e-1d6f-3a8b-9e0c-7d1f2e3a4b5c
type=ethernet
interface-name=enp0s8

[ethernet]

[ipv4]
address1=192.168.56.10/24
dns=192.168.56.1;1.1.1.1;
dns-search=example.com;
gateway=192.168.56.1
method=manual

[ipv6]
addr-gen-mode=default
method=auto

[proxy]
```
- `address1=IP/prefix`, with the default gateway on its own `gateway=` line (older versions wrote `address1=IP/prefix,gateway`, and that form is still accepted). Settings left at their default (such as `autoconnect=true`) aren't written at all. Keep the file mode **600** (root only). After editing by hand: `nmcli con reload` then `nmcli con up lab`. Prefer `nmcli`; it validates what you type.

### Hostname

```bash
sudo hostnamectl hostname server1.example.com
hostnamectl
```
```
 Static hostname: server1.example.com
...
```
- Written to `/etc/hostname` and permanent. Name resolution (`/etc/hosts`, DNS) is topic 063.

### Interactive helpers

```bash
sudo nmtui                       # menus: Edit a connection / Activate / Set system hostname
sudo nmcli con edit lab          # nmcli> print / set ipv4.addresses ... / save / quit
```

### Ubuntu: netplan

```yaml
# /etc/netplan/01-lab.yaml   (mode 600)
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s8:
      dhcp4: false
      addresses: [192.168.56.10/24]
      routes:
        - to: default
          via: 192.168.56.1
      nameservers:
        addresses: [192.168.56.1, 1.1.1.1]
        search: [example.com]
```
```bash
sudo netplan try        # apply with automatic rollback after 120 s unless you confirm: safe over SSH
sudo netplan apply
networkctl status enp0s8
```
- YAML is indentation-sensitive: **spaces only, no tabs**.

### Try it
1. Rename server1's host-only profile to `lab` and set the static IP `192.168.56.10/24` with DNS `1.1.1.1`. Reboot and confirm everything came back.
2. Add a second address with `+ipv4.addresses`, ping it from server2, then remove it.
3. Add an IPv6 ULA address on both VMs and ping across with `ping fd00:56::11`.
4. Look at the keyfile before and after each change.

**Check your work:** on your lab VM, from the notes folder, run `sudo ./checks/check 060` for every step, or `sudo ./checks/check 060 STEP` for one (topic 002 shows how to get the notes there).

## Where you'll use it

- **Every server build:** static IPs for servers, DHCP for clients.
- **Automation:** Ansible's `community.general.nmcli` module or the RHEL **network** system role write these same profiles. In the cloud, **cloud-init** (topic 104) generates them at first boot.
- **Bonds, VLANs, bridges** for VMs and containers are NetworkManager profiles too (topic 062).
- **Kubernetes nodes:** NetworkManager must be told to **leave CNI interfaces alone** (`cali*`, `flannel*`, `cni0`) via an `unmanaged-devices` setting, otherwise it can interfere with pod networking. Calico's install guide includes this step.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| A change has no effect | The profile wasn't re-activated | `nmcli con up NAME` |
| The old IP comes back after a reboot | You edited a different profile, or another profile autoconnects | `nmcli con show`; delete or disable the duplicate |
| `No suitable device found` | `connection.interface-name` doesn't match a device | `nmcli dev status`; fix `connection.interface-name` |
| DNS settings vanish from `/etc/resolv.conf` | NetworkManager regenerates it | Set DNS through `nmcli … ipv4.dns` |
| `ifup: command not found` / `ifconfig: command not found` | Removed on RHEL 10 | `nmcli con up`; `ip addr` |
| A hand-edited keyfile is ignored | NetworkManager wasn't told, or the mode isn't 600 | `nmcli con reload`; `chmod 600` |
| SSH dropped while changing the network | You changed the live connection | Use the console; `netplan try` on Ubuntu |
| A `169.254.x.x` address, no network | DHCP failed | `journalctl -u NetworkManager`; check the DHCP server or the cable |

## Quick recap

- NetworkManager: **devices** (interfaces) + **connection profiles** (saved settings) in `/etc/NetworkManager/system-connections/*.nmconnection`.
- `nmcli dev status`, `nmcli con show [NAME]`, `nmcli con mod NAME ipv4.method manual ipv4.addresses A/P ipv4.gateway G ipv4.dns "…"` → **`nmcli con up NAME`**.
- `con show` = saved, `dev show` / `ip` = live. `ip addr add` is temporary. `hostnamectl hostname` for the name.
- Ubuntu Server: netplan YAML + `netplan try` / `apply`.

**Interview questions**

1. *Device vs connection in NetworkManager?* A device is the network interface itself. A connection is a saved profile of settings (IPs, gateway, DNS, autoconnect) that can be applied to a device.
2. *How do you set a static IP permanently on RHEL?* `nmcli con mod NAME ipv4.method manual ipv4.addresses IP/PREFIX ipv4.gateway GW ipv4.dns "…" connection.autoconnect yes`, then `nmcli con up NAME`.
3. *Why don't changes made with `ip addr add` survive a reboot?* `ip` only changes the running kernel. The persistent configuration lives in NetworkManager's profiles (or netplan on Ubuntu), which are applied at boot.

**Scenario question** (answer out loud first, then compare)

> *"You changed a server's IP with `nmcli con mod`, but `ip addr` still shows the old address. Then you rebooted remotely and lost the server. What went wrong, and how should it have been done?"*

**Model answer:**
1. `nmcli con mod` only edits the **saved profile**; nothing changes on the interface until `nmcli con up NAME`. So the old IP stayed live.
2. The reboot applied the profile. If the new address, prefix or gateway was wrong, the server came up unreachable.
3. Safe procedure for remote changes:
   - have console access, or schedule an automatic revert (`at now + 5 min` running `nmcli con up` with the old settings, or a backup copy of the keyfile);
   - check the profile first (`nmcli con show NAME | grep ipv4`);
   - apply with `nmcli con up NAME` and reconnect to the **new** address;
   - only then cancel the revert, and test a reboot in a maintenance window.
4. Recover now through the console (VM console, iLO/iDRAC) and fix the profile.

**Likely follow-ups:**
- *Where are NetworkManager profiles stored on RHEL 10?* `/etc/NetworkManager/system-connections/*.nmconnection` (keyfiles); ifcfg files are gone.
- *How does Ubuntu Server do this?* netplan YAML; `netplan try` reverts automatically unless you confirm.
