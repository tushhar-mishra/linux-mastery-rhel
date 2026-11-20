# 081 · DNS Server with BIND: Zones, Records and Testing

> **You need first:** [080 · Samba](080-samba.md)
> **Next:** [082 · FTP with vsftpd](082-ftp-vsftpd.md)

---

## What it is

**BIND** (Berkeley Internet Name Domain) is the classic DNS **server** software. Its daemon is **`named`** ("name daemon"). Topic 063 covered the DNS **client** side; this topic runs the server.

DNS servers play two different roles:

| Role | What it does | Example |
|---|---|---|
| **Authoritative** | Holds the **real records** for a domain (a **zone**) and answers questions about it | The servers listed as `NS` for `example.com` |
| **Recursive / caching resolver** | Answers clients' questions about **any** name by asking around, then **caches** the answers | Your company's DNS, `1.1.1.1`, `8.8.8.8` |

Words:
- **Zone**: the part of the DNS tree a server is authoritative for (`example.lan`), stored in a **zone file**.
- **Forward zone**: name → address (A/AAAA). **Reverse zone**: address → name (PTR), under `in-addr.arpa` (IPv4) or `ip6.arpa` (IPv6).
- **Primary** (older word: master): the server holding the editable zone file. **Secondary** (older word: slave): a copy that pulls the zone from the primary by **zone transfer** (AXFR = full, IXFR = incremental).
- **SOA** (Start of Authority): the zone's header record, including its **serial number**.

## Why it exists

Every organisation needs **internal names** (`db1.corp.example`, `git.internal`) that don't exist on the public internet, plus a reliable, caching resolver for its machines. Running a DNS server (BIND, or Unbound, CoreDNS, PowerDNS, or AD DNS) is a core infrastructure job, and knowing how zones and records work is essential for debugging any DNS problem, including cloud DNS (Route 53) and Kubernetes' CoreDNS.

## Analogy

The DNS hierarchy is a **chain of reception desks**. The **root** desk only knows which desk handles `.com`; the `.com` desk only knows which desk handles `example.com`; `example.com`'s own desk (the **authoritative** server) holds the actual staff list (the zone file). A **resolver** is a **personal assistant** who runs between desks for you and writes the answers in a notebook (cache) until they expire (TTL).

## How it works inside

### Recursion

When a resolver gets "what's `www.example.com`?" and has nothing cached:
1. It asks a **root** server (there are 13 named root server identities, A–M, each served by many machines via anycast) → "ask the `.com` servers".
2. It asks a `.com` server → "ask `ns1.example.com`" (a **referral**, possibly with **glue** records: the addresses of name servers that live inside the zone they serve).
3. It asks `ns1.example.com` (authoritative) → `A 93.184.215.14`.
4. It caches each answer for its **TTL** and replies to the client.

Asking for the final answer is a **recursive** query; each step returning only a referral is **iterative**. DNS uses **UDP 53**, and **TCP 53** for zone transfers and large answers.

### The SOA record and its timers

| Field | Meaning |
|---|---|
| **Serial** | The zone's version number. **Must increase on every change** (convention: `YYYYMMDDnn`). Secondaries only copy the zone when the serial goes up |
| Refresh | How often secondaries check the serial |
| Retry | Retry interval if a refresh fails |
| Expire | When secondaries stop answering if they can't reach the primary |
| Minimum | **Negative-caching TTL**: how long resolvers remember that a name does **not** exist (NXDOMAIN) |

### Record types

| Record | Purpose |
|---|---|
| `SOA` | Zone header |
| `NS` | The authoritative name servers |
| `A` / `AAAA` | Name → IPv4 / IPv6 |
| `CNAME` | Alias → canonical name (not allowed at the zone's top, the "apex") |
| `MX` | Mail servers, with a preference number (lower = preferred) |
| `PTR` | IP → name (reverse zone) |
| `TXT` | Text: SPF (which servers may send mail for the domain), domain-verification tokens |
| `SRV` | Service locations (`_ldap._tcp.example.lan`) |

## Commands

### Install and configure

```bash
sudo dnf install -y bind bind-utils           # Ubuntu: bind9 bind9-utils (config in /etc/bind/)
sudo cp -a /etc/named.conf /etc/named.conf.orig
```

```c
// /etc/named.conf (key parts)
options {
    listen-on port 53 { 127.0.0.1; 192.168.56.11; };
    listen-on-v6 port 53 { ::1; };
    directory       "/var/named";
    allow-query     { localhost; 192.168.56.0/24; };
    recursion yes;                                   // "no" on public authoritative-only servers
    allow-recursion { localhost; 192.168.56.0/24; };
    // forwarders { 1.1.1.1; 9.9.9.9; };             // optional: send lookups to upstream resolvers
    dnssec-validation yes;
};

zone "example.lan" IN {
    type primary;                                    // "master" is the older keyword
    file "example.lan.db";
    allow-update { none; };
};

zone "56.168.192.in-addr.arpa" IN {
    type primary;
    file "example.lan.rev";
    allow-update { none; };
};
```
- `allow-query` = who may ask; `allow-recursion` = who may use this server as a resolver. **Never run an open resolver** (recursion for the whole internet): attackers abuse open resolvers for DDoS (Distributed Denial of Service) amplification.
- The reverse zone name is the network's octets **reversed** + `.in-addr.arpa`.

### Zone files

```dns
; /var/named/example.lan.db
$TTL 86400
@   IN SOA ns1.example.lan. admin.example.lan. (
        2026111601 ; Serial
        3600       ; Refresh
        1800       ; Retry
        604800     ; Expire
        3600 )     ; Minimum (negative-caching TTL)
@        IN NS     ns1.example.lan.
@        IN MX 10  mail.example.lan.
ns1      IN A      192.168.56.11
server1  IN A      192.168.56.10
server2  IN A      192.168.56.11
www      IN CNAME  server1.example.lan.
mail     IN A      192.168.56.12
```

```dns
; /var/named/example.lan.rev
$TTL 86400
@   IN SOA ns1.example.lan. admin.example.lan. (
        2026111601 3600 1800 604800 3600 )
@    IN NS   ns1.example.lan.
10   IN PTR  server1.example.lan.
11   IN PTR  server2.example.lan.
12   IN PTR  mail.example.lan.
```
- `@` = the zone name itself. `admin.example.lan.` = the admin's email `admin@example.lan`.
- **Names without a trailing dot get the zone appended.** `www` → `www.example.lan.`. Forgetting the dot on a full name gives `server1.example.lan.example.lan.`, a classic bug.

```bash
sudo chown root:named /var/named/example.lan.{db,rev} ; sudo chmod 640 /var/named/example.lan.{db,rev}
sudo restorecon -v /var/named/*                   # SELinux type named_zone_t
sudo named-checkconf
sudo named-checkzone example.lan /var/named/example.lan.db
```
```
zone example.lan/IN: loaded serial 2026111601
OK
```
```bash
sudo systemctl enable --now named
sudo firewall-cmd --permanent --add-service=dns ; sudo firewall-cmd --reload
```

### After editing a zone

```bash
sudo vi /var/named/example.lan.db         # change records AND increase the serial
sudo named-checkzone example.lan /var/named/example.lan.db
sudo rndc reload example.lan
```
```
zone reload queued
```
- If you forgot to increase the serial, you get `zone reload up-to-date` instead, and named keeps serving the old records (and secondaries would never fetch the change).
- `rndc` (Remote Name Daemon Control) controls the running named: `reload`, `flush` (clear the cache), `status`.

### Test it

```bash
dig @192.168.56.11 www.example.lan
dig @192.168.56.11 -x 192.168.56.10 +short
dig @192.168.56.11 example.lan SOA +short
dig @192.168.56.11 example.lan MX +short
```
```
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 2, AUTHORITY: 0, ADDITIONAL: 1
;; ANSWER SECTION:
www.example.lan.	86400	IN	CNAME	server1.example.lan.
server1.example.lan.	86400	IN	A	192.168.56.10
server1.example.lan.
ns1.example.lan. admin.example.lan. 2026111601 3600 1800 604800 3600
10 mail.example.lan.
```
- **`aa`** (authoritative answer) in the flags = this server owns the zone. The CNAME was followed to the A record.

Point clients at it (topic 060):
```bash
sudo nmcli con mod lab ipv4.dns 192.168.56.11 ipv4.dns-search example.lan ipv4.ignore-auto-dns yes
sudo nmcli con up lab ; getent hosts www
```

### Secondary server and caching-only

```c
// on the primary: allow transfers and notify the secondary
zone "example.lan" IN { type primary; file "example.lan.db";
    allow-transfer { 192.168.56.12; }; also-notify { 192.168.56.12; }; };

// on the secondary
zone "example.lan" IN { type secondary; primaries { 192.168.56.11; };
    file "slaves/example.lan.db"; };
```
- A **caching-only** resolver is just the default `named.conf` with `recursion yes` and tight `allow-recursion`, and no zones of your own.

### Try it
1. Make server2 authoritative for `example.lan` with forward and reverse zones. Query it with `dig @server2`.
2. Point server1 at it and use short names (`ping server2`).
3. Change a record **without** bumping the serial and `rndc reload`: does a secondary (if you built one) update? Then bump the serial.
4. Remove a trailing dot on purpose, run `named-checkzone`, and `dig` the broken name.

**Check your work:** on your lab VM, from the notes folder, run `sudo ./checks/check 081` for every step, or `sudo ./checks/check 081 STEP` for one (topic 002 shows how to get the notes there).

## Where you'll use it

- **Internal DNS** for data centres and labs; split-horizon DNS (different answers inside and outside).
- **Cloud DNS** (Route 53, Azure DNS, Cloud DNS) uses the same zones and records, managed through an API or Terraform.
- **Kubernetes:** **CoreDNS** serves the `cluster.local` zone (Services → ClusterIPs) and forwards everything else upstream. "Pods can't resolve" = check CoreDNS, the same way you'd debug named.
- **Mail delivery** (MX, SPF/DKIM/DMARC TXT records), **certificate validation** (Let's Encrypt DNS-01 challenges use TXT records).

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `status: REFUSED` | The client isn't in `allow-query` / `allow-recursion` | Adjust the ACLs |
| `status: SERVFAIL` for your zone | The zone failed to load (syntax, ownership, SELinux) | `journalctl -u named`; `named-checkzone`; `chown root:named`; `restorecon` |
| A change isn't visible | Serial not increased, not reloaded, or a client/resolver cache | Bump the serial; `rndc reload`; `dig @server` directly; wait for the TTL |
| Names like `x.example.lan.example.lan.` | A missing trailing dot | Add `.` after full names |
| Remote clients time out | Firewall, or `listen-on` is 127.0.0.1 only | Open `dns`; fix `listen-on` |
| Clients still use the old DNS | NetworkManager manages resolv.conf | `nmcli … ipv4.dns … ipv4.ignore-auto-dns yes`; `con up` |
| A deleted name still "doesn't exist" after you add it back | Negative caching (SOA minimum) | Wait for it, or flush resolver caches (`rndc flush`) |

## Quick recap

- Authoritative (owns zones) vs recursive/caching resolver (asks around, caches). UDP 53; TCP for transfers and big answers.
- Records: SOA (serial!), NS, A/AAAA, CNAME, MX, PTR, TXT, SRV. Reverse zones live under `in-addr.arpa`.
- BIND: `/etc/named.conf` (options, `zone … { type primary; file …; }`), zone files in `/var/named` (`root:named 640`), `named-checkconf`, `named-checkzone`, `rndc reload`, firewall `dns`.
- **Bump the serial** on every change; watch trailing dots; never run an open resolver.

**Interview questions**

1. *Recursive vs iterative DNS queries?* A recursive query asks the server for the final answer (it does all the work). In iterative queries, each server returns its best referral (root → TLD → authoritative) and the asker follows them.
2. *What is the SOA serial for?* It's the zone's version number. Secondaries compare it and only transfer the zone when it increases, so it must be bumped on every change.
3. *A vs CNAME?* An A record maps a name directly to an IPv4 address; a CNAME makes a name an alias of another (canonical) name, which is then resolved.

**Scenario question** (answer out loud first, then compare)

> *"You added a new A record to a BIND zone and reloaded, but clients still get NXDOMAIN, and the secondary server doesn't have it either. What did you forget?"*

**Model answer:**
1. Check the primary: `dig @primary newhost.example.lan`. If even it doesn't answer, check `named-checkzone example.lan /var/named/example.lan.db` and the journal for load errors.
2. If the primary answers but the secondary doesn't: you didn't **bump the SOA serial**. Secondaries only transfer when the serial increases. Increase it, then `rndc reload`.
3. Clients may be getting a **cached negative answer** from their resolver. The SOA's minimum/negative TTL decides how long that lasts; flush the resolver's cache, or wait.
4. Also check:
   - a missing trailing dot in a name (`www.example.lan` becomes `www.example.lan.example.lan.`);
   - file permissions or SELinux labels on the zone file (`named_zone_t`).

**Likely follow-ups:**
- *Authoritative vs recursive server?* Authoritative owns zones and answers for them; recursive resolvers find answers for clients and cache them.
- *Why is an open resolver dangerous?* It can be abused for DNS amplification attacks.
