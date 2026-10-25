# Time Synchronization with chrony (NTP)

> **Objective:** *Configure time service clients* **[RHCSA Core]**
> **Related:** [firewalld](../firewall-and-selinux/firewalld.md) · [systemd services](../boot-systemd-and-kernel/systemd-targets-and-services.md) · [System logging (timestamps)](../logs-scheduling-and-packages/system-logging.md)

## 1. Overview

Accurate time is essential for logs, Kerberos/IdM authentication, TLS certificates, cron and clustering. RHEL uses **chrony** (`chronyd` daemon, `chronyc` client), which handles VMs, laptops and intermittent networks better than the old ntpd. NTP uses **UDP port 123**.

| File / command | Purpose |
|---|---|
| `/etc/chrony.conf` | Configuration |
| `chronyd.service` | Daemon (installed and enabled by default) |
| `chronyc` | Query and control |
| `timedatectl` | Time zone, NTP on/off, sync status |

## 2. Client Configuration **[RHCSA Core]**

`````bash
dnf install -y chrony                       # normally preinstalled
vi /etc/chrony.conf
`````

`````
# comment out the default pool if the task specifies a server:
#pool 2.rhel.pool.ntp.org iburst
server classroom.example.com iburst         # (or an IP)
`````

`````bash
systemctl enable --now chronyd
systemctl restart chronyd
chronyc sources -v                          # wait a few seconds; look for ^*
chronyc tracking                            # Leap status: Normal, small System time offset
timedatectl                                 # System clock synchronized: yes ; NTP service: active
`````

### Reading `chronyc sources`

`````
MS Name/IP address         Stratum Poll Reach LastRx Last sample
^* 192.168.10.5                  3   6   377    12   -450ns[ -300ns] +/- 10ms
`````

| Symbol | Meaning |
|---|---|
| `^*` | Currently selected source (synchronized) |
| `^+` | Acceptable, combined with the selected source |
| `^-` | Acceptable, not combined |
| `^?` | Unreachable / not yet usable |
| `^x` | Considered a falseticker |
| `Reach 377` | Last 8 polls all answered (octal) |

### timedatectl

`````bash
timedatectl                                 # local/universal time, time zone, sync status
timedatectl list-timezones | grep Kolkata
timedatectl set-timezone Asia/Kolkata
timedatectl set-ntp true                    # enable NTP sync (starts chronyd)
`````

## 3. Server Configuration **[Advanced/Optional]**

`````
# /etc/chrony.conf on the time server
pool 2.rhel.pool.ntp.org iburst      # upstream sources (or internal stratum-1/2 servers)
allow 192.168.10.0/24                # clients allowed to query
allow 10.0.0.0/8
#local stratum 10                    # ONLY for isolated networks without upstream time
`````

`````bash
systemctl restart chronyd
firewall-cmd --permanent --add-service=ntp ; firewall-cmd --reload
chronyc clients                      # clients that have queried this server
`````

## 4. Key Directives

| Directive | Meaning |
|---|---|
| `server HOST iburst` | One NTP server; `iburst` = fast initial sync |
| `pool NAME iburst` | Pool name resolving to several servers |
| `prefer` | Prefer this source |
| `makestep 1.0 3` | Step (jump) the clock if off by > 1 s during the first 3 updates (RHEL default) |
| `rtcsync` | Keep the hardware clock in sync |
| `driftfile /var/lib/chrony/drift` | Learned clock frequency error |
| `allow` / `deny` | Serve time to these networks |
| `local stratum 10` | Serve own clock when unsynchronized (isolated labs only) |

## 5. Useful Commands

`````bash
chronyc sources -v ; chronyc sourcestats ; chronyc tracking ; chronyc activity
chronyc makestep                     # step the clock now (instead of slewing)
chronyc burst 4/4                    # quick burst of measurements
chronyc ntpdata                      # detailed per-source data
chronyd -Q 'server 192.168.10.5 iburst'   # one-off query: show offset, don't change the clock
`````

## 6. Production Practices **[Production Practice]**

- Use at least 3–4 sources (or a pool) for redundancy; keep all hosts on the same internal time hierarchy.
- In VMs use **either** hypervisor time sync **or** chronyd, not both, to avoid time jumping.
- Restrict `allow` to required networks; open UDP 123 only where needed.
- Avoid `local stratum` on networks with real time sources.

## 7. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `^?` for the server | Unreachable: firewall, DNS, wrong name | Check name resolution, UDP 123 on the server, `chronyd -Q` |
| `System clock synchronized: no` | NTP off / no usable source | `timedatectl set-ntp true`; check `chronyc sources` |
| Large offset not corrected | Slewing slowly | `chronyc makestep` |
| Time jumps in a VM | Two sync mechanisms | Disable one (hypervisor tools or chronyd) |
| Config change ignored | Not restarted | `systemctl restart chronyd` |
| Persistent big drift | Bad drift file / hardware | `rm /var/lib/chrony/drift; systemctl restart chronyd` |

## 8. Interview Questions

| Question | Answer |
|---|---|
| chrony vs ntpd? | chrony syncs faster, handles intermittent connectivity and VMs better; it's RHEL's default. |
| What does `^*` mean? | The source currently used for synchronization. |
| What port does NTP use? | UDP 123. |
| What does `iburst` do? | Sends a quick burst of requests at startup for fast initial sync. |
| How do you make a host an NTP server? | `allow <network>` in chrony.conf + open the `ntp` firewall service. |

## 9. Quick Revision

`````bash
/etc/chrony.conf: server HOST iburst | pool NAME iburst | allow NET | local stratum 10
systemctl enable --now chronyd ; systemctl restart chronyd
chronyc sources -v (^*) | tracking | clients | makestep | burst 4/4 · chronyd -Q 'server X iburst'
timedatectl | set-timezone Z | set-ntp true · firewall: ntp (UDP 123)
`````

## 10. Cross-References

- [firewalld](../firewall-and-selinux/firewalld.md)
- [systemd services](../boot-systemd-and-kernel/systemd-targets-and-services.md)
- [System logging (timestamps)](../logs-scheduling-and-packages/system-logging.md)
