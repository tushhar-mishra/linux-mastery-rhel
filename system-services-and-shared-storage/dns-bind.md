# DNS with BIND (named): Concepts, Zones & Testing

> **Sessions:** S101 · **[Advanced/Optional]** (the client side, *Configure hostname resolution*, is **[RHCSA Core]**: see [NetworkManager §9](../networking-and-ssh/networkmanager-nmcli.md))
> **Related:** [NetworkManager (client DNS)](../networking-and-ssh/networkmanager-nmcli.md) · [firewalld](../firewall-and-selinux/firewalld.md) · [IP fundamentals](../networking-and-ssh/ip-addressing-fundamentals.md)

## 1. DNS Concepts

**DNS** maps names to addresses (**forward lookup**: A/AAAA) and addresses to names (**reverse lookup**: PTR in `in-addr.arpa` / `ip6.arpa`).

**Hierarchy:** root (`.`) → TLDs (`com`, `org`, `in`) → domains (`example.com`) → hosts/subdomains (`www.example.com.`). The trailing dot makes an **FQDN** absolute. There are 13 logical root server identities (A–M), each anycast to many machines.

| Record | Purpose |
|---|---|
| `SOA` | Start of Authority: primary NS, admin mailbox, serial, timers |
| `NS` | Authoritative name servers for the zone |
| `A` / `AAAA` | Name → IPv4 / IPv6 |
| `PTR` | IP → name (reverse zone) |
| `CNAME` | Alias → canonical name (not allowed at the zone apex) |
| `MX` | Mail servers (with preference) |
| `TXT` | Text (SPF, verification) |
| `SRV` | Service location (e.g., `_ldap._tcp`) |
| Glue | A/AAAA records the parent zone publishes for name servers inside the delegated zone |

**SOA timers:**

| Field | Meaning |
|---|---|
| Serial | Zone version; **must increase** on every change (e.g., `YYYYMMDDnn`) |
| Refresh | How often secondaries check the serial |
| Retry | Retry interval if refresh fails |
| Expire | When secondaries stop answering without contact |
| Minimum | **Negative-caching TTL** (how long NXDOMAIN answers are cached) |

| Server role | Behavior |
|---|---|
| Recursive / caching resolver | Resolves queries for clients (root → TLD → authoritative), caches results; may use **forwarders** |
| Authoritative primary | Holds the editable zone files |
| Authoritative secondary | Copies zones from the primary via **AXFR/IXFR** |

DNS uses **UDP 53** and **TCP 53** (zone transfers, large responses, DNSSEC).

## 2. Install BIND

```bash
hostnamectl hostname dns-primary.nehraclasses.lan
dnf install -y bind bind-utils
cp -a /etc/named.conf /etc/named.conf.bak
```

## 3. `/etc/named.conf`

```c
options {
    listen-on port 53 { 127.0.0.1; 192.168.229.137; };   // or comment out = all interfaces
    listen-on-v6 port 53 { ::1; };
    directory       "/var/named";
    allow-query     { localhost; 192.168.229.0/24; };
    recursion yes;                                        // no for public authoritative-only servers
    allow-recursion { localhost; 192.168.229.0/24; };
    // forwarders { 1.1.1.1; 8.8.8.8; };                  // optional upstream resolvers
    dnssec-validation yes;
};

zone "nehraclasses.lan" IN {
    type primary;                    // "master" is the older keyword (still accepted)
    file "nehraclasses.lan.db";
    allow-update { none; };
};

zone "229.168.192.in-addr.arpa" IN {
    type primary;
    file "nehraclasses.lan.rev";
    allow-update { none; };
};
```

## 4. Zone Files

```dns
; /var/named/nehraclasses.lan.db
$TTL 86400
@   IN SOA dns-primary.nehraclasses.lan. admin.nehraclasses.lan. (
        2026102501 ; Serial
        3600       ; Refresh
        1800       ; Retry
        604800     ; Expire
        86400 )    ; Minimum (negative TTL)
@            IN NS    dns-primary.nehraclasses.lan.
@            IN MX 10 mail.nehraclasses.lan.
dns-primary  IN A     192.168.229.137
www          IN A     192.168.229.50
mail         IN A     192.168.229.60
ftp          IN CNAME www.nehraclasses.lan.
```

```dns
; /var/named/nehraclasses.lan.rev
$TTL 86400
@   IN SOA dns-primary.nehraclasses.lan. admin.nehraclasses.lan. (
        2026102501 3600 1800 604800 86400 )
@    IN NS  dns-primary.nehraclasses.lan.
137  IN PTR dns-primary.nehraclasses.lan.
50   IN PTR www.nehraclasses.lan.
60   IN PTR mail.nehraclasses.lan.
```

- `@` = the zone name. Names **without** a trailing dot get the zone appended (`www` → `www.nehraclasses.lan.`). **Forgetting the dot** on a full name produces `mail.nehraclasses.lan.nehraclasses.lan.`.
- The admin mailbox `admin.nehraclasses.lan.` means `admin@nehraclasses.lan`.

```bash
chown root:named /var/named/nehraclasses.lan.{db,rev} ; chmod 640 /var/named/nehraclasses.lan.{db,rev}
restorecon -v /var/named/*         # named_zone_t
named-checkconf
named-checkzone nehraclasses.lan /var/named/nehraclasses.lan.db
named-checkzone 229.168.192.in-addr.arpa /var/named/nehraclasses.lan.rev
systemctl enable --now named
firewall-cmd --permanent --add-service=dns ; firewall-cmd --reload
# after later edits: increase the serial, then
rndc reload                        # (or rndc reload nehraclasses.lan)
```

## 5. Client Configuration & Testing

```bash
nmcli con mod ens160 ipv4.dns 192.168.229.137 ipv4.dns-search nehraclasses.lan ipv4.ignore-auto-dns yes
nmcli con up ens160 ; cat /etc/resolv.conf
dig @192.168.229.137 www.nehraclasses.lan          # query a specific server
dig www.nehraclasses.lan +short
dig -x 192.168.229.137 +short                       # reverse lookup
dig nehraclasses.lan MX ; dig nehraclasses.lan SOA
host ftp.nehraclasses.lan ; nslookup mail.nehraclasses.lan
getent hosts www                                    # through nsswitch (files, then dns) + search domain
```

## 6. Secondary Zone & Caching-Only **[Advanced]**

```c
// primary: allow transfers to the secondary
zone "nehraclasses.lan" IN { type primary; file "nehraclasses.lan.db";
    allow-transfer { 192.168.229.138; }; also-notify { 192.168.229.138; }; };

// secondary
zone "nehraclasses.lan" IN { type secondary; primaries { 192.168.229.137; };
    file "slaves/nehraclasses.lan.db"; };
```

**Caching-only resolver:** default `named.conf` with `recursion yes`, `allow-recursion` and `listen-on` set, and no zones of your own (optionally `forwarders`).

## 7. Production Practices **[Production Practice]**

- Separate authoritative and recursive roles; never run an open resolver (restrict `allow-recursion`).
- At least two authoritative servers; restrict `allow-transfer` (and use TSIG keys).
- Use a real subdomain or `.internal` for private zones; `.local` is reserved for mDNS.
- Automate serial increments; validate with `named-checkzone` before reloading.

## 8. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `status: REFUSED` | Client not in `allow-query`/`allow-recursion` | Adjust ACLs |
| `status: SERVFAIL` for the zone | Zone failed to load (syntax, permissions) | `journalctl -u named`; `named-checkzone`; `chown root:named` |
| Changes not visible | Serial not increased / not reloaded / client cache | Bump the serial; `rndc reload`; query the server directly with `dig @server` |
| Names like `x.domain.domain.` | Missing trailing dot | Add `.` to FQDNs in zone files |
| Remote clients time out | Firewall / listen-on 127.0.0.1 only | `firewall-cmd --add-service=dns`; fix `listen-on` |
| Client still uses the old DNS | resolv.conf managed by NetworkManager | `nmcli … ipv4.dns … ipv4.ignore-auto-dns yes`; `nmcli con up` |

## 9. Interview Questions

| Question | Answer |
|---|---|
| Recursive vs iterative query? | Recursive: the server must return the final answer. Iterative: each server returns the best referral (root → TLD → authoritative). |
| What's the SOA serial for? | Secondaries transfer the zone only when the serial increases. |
| A vs CNAME? | A maps a name to an IP; CNAME aliases one name to another canonical name. |
| What's a PTR record? | Reverse mapping IP → name in `in-addr.arpa`. |
| Why does DNS use TCP? | Zone transfers and responses too large for UDP (e.g., DNSSEC). |

## 10. Course Corrections

| Course | Correction |
|---|---|
| Client: `DNS=192.168.229.137` + restart NetworkManager + edit `/etc/resolv.conf` | RHEL 10: `nmcli con mod … ipv4.dns …` (resolv.conf is generated) |
| SOA "TTL: minimum TTL for records" | Negative-caching TTL |
| "TCP 53 for zone transfers" only | Also large responses/DNSSEC |
| `systemctl restart named` after zone edits | Increase the serial; `rndc reload` |
| `type master` | `type primary` (old keyword still accepted) |
| `.local` domain | Reserved for mDNS; use a real subdomain or `.internal` |
| `chown named:named` zone files | `root:named` 640 is the RHEL convention (named only needs read for primary zones) |

## 11. Quick Revision

````
records: SOA NS A AAAA PTR CNAME MX TXT SRV · SOA: serial refresh retry expire minimum(negative TTL)
dnf install bind bind-utils · /etc/named.conf (options, zone type primary file) · /var/named/*.db *.rev (root:named 640)
named-checkconf · named-checkzone ZONE FILE · systemctl enable --now named · rndc reload · firewall dns
client: nmcli … ipv4.dns IP ipv4.dns-search DOMAIN · dig [@srv] NAME [+short] · dig -x IP · host · nslookup · getent hosts
