# 069 · Time Synchronisation with chrony (NTP)

> **You need first:** [068 · rsync and backups](068-rsync-and-backups.md)
> **Next:** [070 · HTTP and curl](070-http-and-curl.md)

---

## What it is

- **NTP** (Network Time Protocol): the standard way computers set their clocks from time servers over the network (**UDP port 123**).
- **chrony** is RHEL's NTP implementation: the `chronyd` daemon plus the `chronyc` control tool. It replaced the older `ntpd`, and copes better with VMs, laptops and flaky networks. Ubuntu uses `systemd-timesyncd` by default (a simple client) and offers chrony as a package.
- **`timedatectl`**: the tool for time zone and NTP on/off.
- **Stratum**: how many steps a server is from a reference clock (GPS, atomic clock = stratum 0; servers directly connected to it = stratum 1; and so on).
- **UTC** (Coordinated Universal Time): the world reference time. Servers usually run in UTC; the time zone only changes how it's displayed.

## Why it exists

Computer clocks drift (seconds per day). Wrong time silently breaks things:
- **Logs** across servers can't be correlated during incidents.
- **Kerberos / Active Directory / IdM** logins fail with more than ~5 minutes of skew (topic 030).
- **TLS certificates** appear "not yet valid" or "expired" (topic 064).
- **Distributed systems** (databases, etcd, Kafka) and **cron jobs** misbehave.
- Auth tokens (JWTs, one-time passwords, cloud API signatures) are rejected.

## Analogy

Every server has a cheap **wristwatch** that drifts. chrony is the habit of **checking it against the station clock** several times a day and nudging it, gently so nobody notices (**slewing**: slightly speeding up or slowing down), or, if it's way off at startup, **resetting it at once** (**stepping**).

## How it works inside

1. chronyd sends NTP requests to the configured servers. Each reply contains timestamps, from which it calculates the **offset** (how far off your clock is) and the **round-trip delay**.
2. It filters and combines several sources, rejecting liars ("falsetickers"), and selects the best one.
3. It corrects the system clock:
   - **slewing**: running the clock slightly faster or slower until it's right. Time never jumps backwards, which is safe for applications;
   - **stepping**: jumping the clock at once. RHEL's default `makestep 1.0 3` steps only if the clock is more than 1 second off during the first 3 updates (that is, at boot).
4. It learns your hardware clock's **drift rate** and stores it in `/var/lib/chrony/drift`, so it stays accurate even between polls.
5. `rtcsync` keeps the **hardware clock** (RTC, Real-Time Clock: the battery-backed clock on the motherboard) in line with system time.

## Commands

### Configure a client

```bash
sudo vi /etc/chrony.conf
```
```
# comment out the default pool if you must use a specific server:
#pool 2.rhel.pool.ntp.org iburst
server ntp1.example.com iburst
server ntp2.example.com iburst
makestep 1.0 3
rtcsync
driftfile /var/lib/chrony/drift
```
```bash
sudo systemctl enable --now chronyd
sudo systemctl restart chronyd
```

| Directive | Meaning |
|---|---|
| `server HOST iburst` | One NTP server. `iburst` = send a burst of requests at startup for a fast first sync |
| `pool NAME iburst` | A DNS name that resolves to several servers |
| `prefer` | Prefer this source |
| `makestep 1.0 3` | Step if off by more than 1 s during the first 3 updates |
| `rtcsync` | Keep the hardware clock in sync |
| `allow NET` / `deny NET` | Serve time to these networks (server role) |
| `local stratum 10` | Serve your own clock even when unsynchronised: **isolated labs only** |

### Check it

```bash
chronyc sources -v
```
```
  .-- Source mode  '^' = server, '=' = peer, '#' = local clock.
 / .- Source state '*' = current best, '+' = combined, '-' = not combined,
| /             'x' = may be in error, '~' = too variable, '?' = unusable.
||                                                 .- xxxx [ yyyy ] +/- zzzz
||      Reachability register (octal) -.           |  xxxx = adjusted offset,
||      Log2(Polling interval) --.      |          |  yyyy = measured offset,
||                                \     |          |  zzzz = estimated error.
||                                 |    |           \
MS Name/IP address         Stratum Poll Reach LastRx Last sample
===============================================================================
^* ntp1.example.com              2   6   377    12   -450us[ -310us] +/-   10ms
^+ ntp2.example.com              2   6   377    13   +210us[ +350us] +/-   14ms
```

| Field | Meaning |
|---|---|
| `^*` | The source currently used (you're synchronised) |
| `^+` | A good source, combined with the selected one |
| `^?` | Unreachable or not usable yet |
| `^x` | Judged to be wrong (a "falseticker") |
| `Stratum` | Distance from a reference clock |
| `Poll` | Polling interval as a power of 2 (6 = 64 s) |
| `Reach 377` | Octal record of the last 8 polls: 377 = all 8 answered |
| `Last sample` | The measured offset (here less than a millisecond) and its error margin |

```bash
chronyc tracking
```
```
Reference ID    : C0A80A05 (ntp1.example.com)
Stratum         : 3
System time     : 0.000000312 seconds slow of NTP time
Last offset     : -0.000450123 seconds
...
Frequency       : 12.104 ppm fast
Leap status     : Normal
```
- `System time` = how far off you are now. `Frequency` = how fast your hardware clock drifts (ppm = parts per million). `Leap status: Normal` = synchronised.

```bash
timedatectl
```
```
               Local time: Mon 2026-11-16 17:40:02 UTC
           Universal time: Mon 2026-11-16 17:40:02 UTC
                 RTC time: Mon 2026-11-16 17:40:02
                Time zone: UTC (UTC, +0000)
System clock synchronized: yes
              NTP service: active
          RTC in local TZ: no
```
- `System clock synchronized: yes` is the quick health check.

```bash
timedatectl list-timezones | grep -i kolkata
sudo timedatectl set-timezone Asia/Kolkata         # changes the /etc/localtime symlink (topic 008)
sudo timedatectl set-ntp true                      # turn NTP sync on (starts chronyd)
```

### Useful extras

```bash
sudo chronyc makestep              # jump the clock now instead of slewing slowly
chronyc sourcestats                # statistics per source
chronyd -Q 'server ntp1.example.com iburst'   # one-off: measure the offset, don't change anything
```

### Make a machine an NTP server

```
# /etc/chrony.conf on the time server
pool 2.rhel.pool.ntp.org iburst
allow 192.168.56.0/24
```
```bash
sudo systemctl restart chronyd
sudo firewall-cmd --permanent --add-service=ntp ; sudo firewall-cmd --reload   # topic 071
chronyc clients                    # who has asked us for the time
```

### Try it
1. Make server2 an NTP server for `192.168.56.0/24`; point server1 at it only. Check `chronyc sources` on server1 for `^*`.
2. Set server1's clock 5 minutes wrong (`sudo date -s "+5 min"` after stopping chronyd), start chronyd, and watch it correct (try `chronyc makestep`).
3. Change the time zone and see `ls -l /etc/localtime` change.

**Check your work:** on your lab VM, from the notes folder, run `sudo ./checks/check 069` for every step, or `sudo ./checks/check 069 STEP` for one (topic 002 shows how to get the notes there).

## Where you'll use it

- **Every server**, by default. Larger organisations run internal NTP servers and point all hosts at them; clouds provide their own (AWS `169.254.169.123`, GCP `metadata.google.internal`).
- **Kubernetes:** etcd, certificates and token validation all depend on node clocks agreeing. Skewed nodes cause baffling auth and certificate errors.
- **Incident timelines:** correlating logs across 20 machines only works when clocks agree.
- **VMs:** use **either** the hypervisor's time sync **or** chronyd, not both (time would jump back and forth).

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| The server shows `^?` | Unreachable: firewall (UDP 123), DNS, a wrong name | Resolve the name; open UDP 123 on the server; `chronyd -Q` |
| `System clock synchronized: no` | NTP off, or no usable source | `timedatectl set-ntp true`; check `chronyc sources` |
| A large offset corrects only slowly | Slewing is gradual | `chronyc makestep` |
| Time jumps back and forth in a VM | Two sync mechanisms fighting | Disable one |
| A config change is ignored | chronyd wasn't restarted | `systemctl restart chronyd` |
| Kerberos "Clock skew too great" / TLS "not yet valid" | The clock is wrong | Fix sync first, then retry |
| Logs show the wrong hour | Time zone, not sync | `timedatectl set-timezone` (servers usually stay UTC) |

## Quick recap

- chrony = RHEL's NTP client/server (UDP 123). Config `/etc/chrony.conf` (`server … iburst`, `pool`, `allow`); `systemctl enable --now chronyd`.
- Check: `chronyc sources -v` (`^*` = synced, `Reach 377` = healthy), `chronyc tracking`, `timedatectl`.
- It **slews** (gradual) or **steps** (jump; `makestep`). Time zone with `timedatectl set-timezone`.
- Wrong time breaks logs, Kerberos, TLS, tokens and clusters.

**Interview questions**

1. *Why does accurate time matter on servers?* Log correlation, Kerberos authentication (fails with a few minutes of skew), TLS certificate validity, token expiry, and distributed systems that order events by time.
2. *What does `^*` mean in `chronyc sources`?* That source is the one currently selected for synchronisation.
3. *Slewing vs stepping?* Slewing gradually speeds up or slows down the clock so time never jumps (safe for applications). Stepping sets the clock immediately (used at boot or for large offsets).

**Scenario question** (answer out loud first, then compare)

> *"Kerberos logins are failing and the logs on two servers disagree by several minutes. What do you check?"*

**Model answer:**
1. `timedatectl`: is "System clock synchronized: yes"? Is NTP active?
2. `chronyc tracking`: the current offset and the selected source. `chronyc sources -v`: is any source `^*`, and is `Reach` 377?
3. If no source is reachable: firewall (UDP 123 out), DNS for the pool names, or a wrong `server` line in `/etc/chrony.conf`.
4. Fix the source, then `chronyc makestep` to correct a large offset immediately (chrony normally slews slowly).
5. Kerberos allows about 5 minutes of skew; TLS, tokens and log correlation all suffer too.
6. Check VMs: a paused or migrated VM can jump; chrony must run in every guest.

**Likely follow-ups:**
- *Slew vs step?* Slew adjusts the clock speed gradually; step jumps it (safe at boot, risky for running apps).
- *Does the time zone affect synchronisation?* No. The clock runs in UTC; the time zone only changes how it's displayed.
