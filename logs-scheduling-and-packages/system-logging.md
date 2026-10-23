# System Logging: journald, rsyslog & logrotate

> **Sessions:** S55 · **Objectives:** *Locate and interpret system log files and journals* · *Preserve system journals* **[RHCSA Core]**
> **Related:** [Job scheduling](job-scheduling.md) · [Filesystem hierarchy (/var/log)](../linux-fundamentals/filesystem-hierarchy.md) · [systemd targets & services](../boot-systemd-and-kernel/systemd-targets-and-services.md) · [grep & regex](../files-and-text-processing/grep-and-regular-expressions.md)

## 1. Overview

````
kernel / services / applications ──► systemd-journald (binary journal: /run/log/journal or /var/log/journal)
                                            │  imjournal
                                            ▼
                                        rsyslogd ──► text files in /var/log (messages, secure, cron, maillog …)
                                                 └─► remote syslog servers
logrotate (logrotate.timer) rotates/compresses the text files
````

- **journald** collects everything with rich metadata (unit, PID, UID, priority, boot ID).
- **rsyslog** writes classic text logs and forwards to central servers.
- **logrotate** keeps text logs from filling the disk.

## 2. Key Log Files on RHEL 10

| File | Content |
|---|---|
| `/var/log/messages` | General system messages (everything not routed elsewhere) |
| `/var/log/secure` | Authentication and authorization: sshd, sudo, su, logins |
| `/var/log/cron` | crond / anacron activity |
| `/var/log/maillog` | Mail server |
| `/var/log/boot.log` | Service startup messages |
| `/var/log/dnf.log`, `dnf.rpm.log`, `dnf.librepo.log` | Package operations |
| `/var/log/audit/audit.log` | auditd records, including **SELinux AVC denials** |
| `/var/log/httpd/`, `sssd/`, `samba/`, `libvirt/`, `firewalld` | Service-specific logs |
| `/var/log/sa/` | sysstat history (`sar`) |
| `/var/log/wtmp` / `/var/log/btmp` / `/run/utmp` | Login history (`last`) / failed logins (`lastb`) / current sessions (`who`, `w`) |

Not present on RHEL 10 by default: `/var/log/syslog`, `auth.log`, `kern.log`, `daemon.log`, `dpkg.log` (Debian), `/var/log/dmesg`, `faillog`/`tallylog` (replaced by `faillock`), `yum.log`. Use `dmesg` or `journalctl -k` for kernel messages.

## 3. journalctl **[RHCSA Core]**

| Task | Command |
|---|---|
| Everything (oldest first, pager) | `journalctl` |
| Jump to end / newest first | `journalctl -e` / `journalctl -r` |
| Last N lines / follow | `journalctl -n 20` / `journalctl -f` |
| One unit | `journalctl -u sshd` (several: `-u a -u b`) |
| This boot / previous boot / list boots | `journalctl -b` / `-b -1` / `--list-boots` |
| Kernel only | `journalctl -k` |
| By priority | `journalctl -p err` (that level and more severe); range `-p warning..err` |
| Time window | `--since "2026-10-23 09:00" --until "1 hour ago"`, `--since today` |
| By process / user / executable | `_PID=2472`, `_UID=1000`, `journalctl /usr/sbin/sshd` |
| Search text | `journalctl -g 'Failed password'` |
| Explanations | `journalctl -x` (often `-xe`: explain + jump to end) |
| Output formats | `-o verbose`, `-o json-pretty`, `-o short-iso`; `--no-pager` for scripts |
| Disk use / cleanup | `--disk-usage`; `--vacuum-size=500M`, `--vacuum-time=2weeks`, `--vacuum-files=5` |

**Priorities:** 0 emerg · 1 alert · 2 crit · 3 err · 4 warning · 5 notice · 6 info · 7 debug.

Non-root users see only their own journal entries unless they're in `wheel`, `adm` or `systemd-journal`.

## 4. Persistent Journal **[RHCSA Core]**

`/etc/systemd/journald.conf` → `Storage=auto` (default): the journal is **persistent only if `/var/log/journal/` exists**; otherwise it lives in `/run/log/journal/` and is lost at reboot.

```bash
# Method 1 — create the directory
mkdir -p /var/log/journal
systemd-tmpfiles --create --prefix /var/log/journal   # correct ownership, ACLs, SELinux context
systemctl restart systemd-journald                   # (or: journalctl --flush)

# Method 2 — explicit setting (drop-in)
mkdir -p /etc/systemd/journald.conf.d
printf '[Journal]\nStorage=persistent\n' > /etc/systemd/journald.conf.d/persistent.conf
systemctl restart systemd-journald

# Verify
ls /var/log/journal/                                 # <machine-id>/ directory
journalctl --list-boots                              # after a reboot: more than one boot listed
```

Size limits (same file): `SystemMaxUse=1G`, `MaxRetentionSec=1month`.

## 5. rsyslog

Config: `/etc/rsyslog.conf` + `/etc/rsyslog.d/*.conf`. Service: `rsyslog`. Rules: `selector  action`.

**Selector** = `facility.priority`:

| Facilities | `auth`/`authpriv`, `cron`, `daemon`, `kern`, `mail`, `syslog`, `user`, `local0`–`local7`, `*` |
|---|---|
| Priority forms | `.crit` (crit **and higher**), `.=crit` (exactly), `.!crit` (below crit), `.none` (exclude), `.*` (all) |

**Actions:**

| Action | Meaning |
|---|---|
| `/var/log/file` | Write to file |
| `user1,user2` / `*` | Message to those users' / all logged-in terminals |
| `@host:514` / `@@host:514` | Forward via UDP / **TCP** |
| `\|/path/to/pipe` | Write to a named pipe |
| `-/var/log/file` | Legacy "no sync" prefix (ignored by modern rsyslog) |

```bash
cat > /etc/rsyslog.d/local4.conf <<'EOF'
local4.*        /var/log/alllocal4
local4.=crit    /var/log/onlycrit
local4.crit     /var/log/critandabove
authpriv.*      @@192.168.1.100:514
EOF
rsyslogd -N1                       # syntax check
systemctl restart rsyslog
logger -p local4.crit "Test critical log"     # generate a test message
tail /var/log/onlycrit
```

**Remote receiver** **[Advanced]**: enable `module(load="imtcp")` and `input(type="imtcp" port="514")`, open the firewall port (`firewall-cmd --permanent --add-port=514/tcp`), and use TLS for production.

## 6. logrotate

- Main config `/etc/logrotate.conf`; per-service files in `/etc/logrotate.d/`.
- Runs daily via **`logrotate.timer`** (`systemctl list-timers logrotate.timer`).

| Option | Meaning |
|---|---|
| `daily`/`weekly`/`monthly` | Rotation interval |
| `rotate N` | Keep N old logs |
| `size 100M` | Rotate when bigger than size (ignores interval) |
| `minsize 1M` | Rotate at the interval only if at least this big |
| `compress` / `delaycompress` | gzip old logs / skip compressing the newest old log |
| `dateext` | Suffix `-YYYYMMDD` (RHEL default) instead of `.1` |
| `create 0640 root root` | New empty log with mode/owner |
| `missingok`, `notifempty` | Don't error on a missing log / skip empty logs |
| `postrotate … endscript` | Command after rotation (e.g., reload the service) |

```bash
cat > /etc/logrotate.d/myapp <<'EOF'
/var/log/myapp/*.log {
    weekly
    rotate 8
    compress
    missingok
    notifempty
    create 0640 root root
}
EOF
logrotate -d /etc/logrotate.d/myapp     # dry run (debug)
logrotate -f /etc/logrotate.conf        # force rotation now
cat /var/lib/logrotate/logrotate.status # last rotation times
```

## 7. Login Records

```bash
who ; w            # current sessions (/run/utmp)
last | head        # login/reboot history (/var/log/wtmp)
lastb | head       # failed logins (/var/log/btmp, root)
faillock --user alice          # pam_faillock counters ; faillock --user alice --reset
```

## 8. RHCSA Exam Focus **[RHCSA Core]**

- "Preserve journals across reboots": §4, then verify after a reboot with `journalctl --list-boots`.
- Find evidence fast: `journalctl -u <svc> -b`, `journalctl -p err -b`, `grep … /var/log/secure`, `ausearch -m avc -ts recent` for SELinux.
- Copy matching log lines to a file when asked: `journalctl -u sshd --no-pager > /root/sshd.log`.

## 9. Production Practices **[Production Practice]**

- Make journals persistent on servers and cap their size.
- Forward logs centrally (rsyslog/TCP+TLS, or an agent), because local logs vanish with the host.
- Use `local0`–`local7` facilities for custom applications; rotate application logs with logrotate.
- Protect `/var/log` with its own filesystem so log floods can't fill `/`.

## 10. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `journalctl -b -1` → "Data from the specified boot is not available" | Volatile journal | Make the journal persistent (§4) |
| No entries in `/var/log/messages` | rsyslog stopped / config error | `systemctl status rsyslog`; `rsyslogd -N1` |
| Custom rsyslog rule writes nothing | Wrong facility/priority or no restart | `logger -p …` test; restart rsyslog |
| `/var` full of logs | No rotation / huge journal | `logrotate -f`; `journalctl --vacuum-size=…`; set `SystemMaxUse` |
| Remote logs not arriving | Firewall, SELinux port, UDP vs TCP mismatch | Open the port; match `@`/`@@` with imudp/imtcp |

## 11. Interview Questions

| Question | Answer |
|---|---|
| journald vs rsyslog? | journald: structured binary journal with metadata. rsyslog: text files and forwarding; on RHEL it reads from journald (imjournal). |
| How do you make the journal persistent? | Create `/var/log/journal` (tmpfiles + restart journald) or set `Storage=persistent`. |
| Where do SSH login failures go? | `/var/log/secure` and `journalctl -u sshd`. |
| `.crit` vs `.=crit`? | crit and above vs exactly crit. |
| How does logrotate run on RHEL 9/10? | Via `logrotate.timer`. |

## 12. Course Corrections

| Course | Correction |
|---|---|
| "journalctl shows newest first" | Oldest first; `-r` newest first, `-e` jump to end |
| `journalctl -xe` = "recent errors" | `-x` explanations + `-e` end; errors only = `-p err` |
| logrotate "via /etc/cron.daily/logrotate" | `logrotate.timer` on RHEL 9/10 |
| Rotated names `messages.1`, `.2.gz` | RHEL uses `dateext`: `messages-YYYYMMDD` |
| `/var/log/dmesg`, `faillog`, `tallylog`, `pam_tally2`, `auth.log`, `kern.log`, `dpkg.log`, `yum.log`, `/var/log/syslog` | Not RHEL 10 defaults (see §2) |
| `/var/log/utmp`; "who uses wtmp" | utmp is `/run/utmp` (who/w); wtmp is read by `last` |
| `-/path` "better performance" | Legacy, ignored by rsyslog v8 |
| "rsyslog uses TCP instead of UDP" | Supports both (`@` UDP, `@@` TCP) |

## 13. Quick Revision

```bash
journalctl -e|-r|-f|-n N|-u U|-b [-1]|--list-boots|-k|-p err|--since …|-g PATTERN|-o json-pretty|--disk-usage|--vacuum-size=
persistent: mkdir /var/log/journal ; systemd-tmpfiles --create --prefix /var/log/journal ; systemctl restart systemd-journald
rsyslog: facility.priority action · .=crit .none · @udp @@tcp · rsyslogd -N1 · logger -p local4.crit "msg"
logrotate: /etc/logrotate.conf + .d/ · logrotate -d / -f · logrotate.timer · dateext
/var/log: messages secure cron maillog boot.log dnf.log audit/audit.log · who w last lastb faillock
