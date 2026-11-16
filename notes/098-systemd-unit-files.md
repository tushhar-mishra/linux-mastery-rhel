# 098 · systemd Unit Files in Depth: Writing, Overriding and Hardening Services

> **You need first:** [097 · Namespaces and cgroups](097-namespaces-and-cgroups.md) (and topic 037 systemd services)
> **Next:** [099 · Virtual machines vs containers](099-vms-vs-containers.md)

---

## What it is

Topic 037 showed how to **use** units (`start`, `enable`, `status`) and wrote a first small service. This topic is about **writing production-grade units**:
- run your own application reliably;
- restart it on failure;
- order it after its dependencies;
- limit its resources (cgroups, topic 097);
- confine what it can touch (sandboxing).

| Term | Meaning |
|---|---|
| **Unit** | Anything systemd manages, described by a file: `.service`, `.socket`, `.timer`, `.mount`, `.target`, `.path`, `.slice`, `.scope` |
| **Drop-in** | A small `.conf` file in `NAME.service.d/` that changes some settings of a unit without copying it |
| **Dependency** | "Also start (or stop) that other unit" |
| **Ordering** | "Start after / before that other unit": a separate thing from dependency |
| **Sandboxing** | Unit settings that use namespaces, capabilities and seccomp to restrict a service |
| **Socket activation** | systemd holds the listening socket and starts the service on the first connection |
| **Transient unit** | A unit created on the fly with `systemd-run`, with no file on disk |

## Why it exists

Before systemd, services were started by shell scripts in `/etc/init.d` that each re-implemented backgrounding, PID files, restarts and logging, usually badly. A unit file **declares** what you want, and systemd does the rest consistently: process tracking via cgroups, logs to the journal, restarts, resource limits and security confinement. Podman's **Quadlet** (topic 101), timers (topic 039) and Kubernetes' kubelet on a node are all just units.

## Analogy

A unit file is a **job description for a hired worker** (your program):
- who they report after (ordering) and who they need on site (dependencies);
- what tools they may use (capabilities);
- which rooms they may enter (sandboxing);
- how much they may spend (resource limits);
- what to do if they collapse (restart policy).

systemd is the **manager** who enforces the description to the letter.

## How it works inside

### Where units live (highest priority first)

| Path | Owner | Notes |
|---|---|---|
| `/etc/systemd/system/` | The administrator | Your units and overrides. **Wins** |
| `/run/systemd/system/` | Runtime / generated | Lost at reboot |
| `/usr/lib/systemd/system/` | Packages | **Never edit**: updates overwrite it |
| `~/.config/systemd/user/` | Per-user units (`systemctl --user`) | Need `loginctl enable-linger USER` to run without a login session |

**Drop-in rules:**
- Most settings in a drop-in **replace** the original value.
- **List** settings (`ExecStart=`, `ExecStartPre=`, `Environment=`, `After=`…) **append** to it.
- To replace a list, first **reset** it with an empty assignment (`ExecStart=` on its own line).

### Anatomy of a service

```ini
# /etc/systemd/system/myapp.service
[Unit]
Description=My application API
Documentation=https://wiki.example.com/myapp
Wants=network-online.target
After=network-online.target postgresql.service
Requires=postgresql.service

[Service]
Type=exec
User=myapp
Group=myapp
WorkingDirectory=/opt/myapp
EnvironmentFile=-/etc/sysconfig/myapp          # "-" = don't fail if the file is missing
ExecStartPre=/opt/myapp/bin/check-config
ExecStart=/opt/myapp/bin/server --port 8080
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=5s
TimeoutStopSec=30s

[Install]
WantedBy=multi-user.target
```

| Section | Purpose |
|---|---|
| `[Unit]` | Description, docs, **dependencies and ordering** (for any unit type) |
| `[Service]` (or `[Socket]`, `[Timer]`, `[Mount]`…) | Type-specific behaviour |
| `[Install]` | What `systemctl enable` does: `WantedBy=multi-user.target` creates a symlink in `multi-user.target.wants/` |

**`ExecStart=` is not a shell command line.** It has no pipes, redirection, globbing or `&&`. The first word must be an absolute path (or an executable in systemd's fixed search path). For shell features, use `/usr/bin/bash -c '…'`, or better, a script.

### Service types: when is it "started"?

| `Type=` | systemd considers it started when… | Use for |
|---|---|---|
| `simple` (default) | Right after `fork()`, **before** the program runs | Legacy default: a missing binary still "starts successfully", then fails |
| **`exec`** | After `execve()` succeeded | **Recommended** for long-running foreground programs: start errors are reported |
| `forking` | The process forks and the parent exits (old-style daemons); use `PIDFile=` | Programs that background themselves |
| `oneshot` | The process **exits** successfully | Scripts and setup tasks; add `RemainAfterExit=yes` to stay "active" |
| `notify` | The program sends `READY=1` via `sd_notify()` | Daemons with systemd support (many RHEL services) |

The program must **stay in the foreground** for `simple`/`exec`/`notify`. If it daemonises itself, systemd thinks it exited. Use its foreground flag (`httpd -DFOREGROUND`) or `Type=forking`.

### Dependencies vs ordering (the most misunderstood part)

| Directive | Meaning |
|---|---|
| `Wants=B` | Start B too; don't care if it fails |
| `Requires=B` | Start B too; if B fails (with ordering) or stops, this unit is stopped / not started |
| `Requisite=B` | B must **already** be active |
| `BindsTo=B` | Like Requires, plus stop whenever B stops (devices, mounts) |
| `PartOf=B` | Stop/restart along with B (one direction) |
| `Conflicts=B` | Starting one stops the other |
| `After=B` / `Before=B` | **Ordering only** |

What happens with a dependency `dep.service` that always fails:

| Unit | Directives | Result |
|---|---|---|
| app1 | `Requires=dep` (no `After=`) | **active**: both started in parallel; dep's failure didn't stop app1 |
| app2 | `Requires=dep` + `After=dep` | **inactive**: app2 waited, saw dep fail, didn't start |
| app3 | `Wants=dep` + `After=dep` | **active**: it waited, but a Wants failure doesn't matter |

**Rule: pair a dependency with `After=`.**

**Network ordering:**
- `After=network.target` only means "after the network management stack started", not that addresses exist.
- Services that bind to a specific IP or contact a remote server at start need `Wants=` + `After=network-online.target` (on RHEL, satisfied by `NetworkManager-wait-online.service`).

### Restart policy and start limits

| `Restart=` | Restarts when the process… |
|---|---|
| `no` (default) | Never |
| `on-failure` | Exits non-zero, is killed by a signal, times out, or misses the watchdog |
| `on-abnormal` | Signal, timeout, watchdog (not a clean non-zero exit) |
| `always` | Exits for any reason (except `systemctl stop`) |

Crash loops are throttled: more than `StartLimitBurst=` starts (default 5) within `StartLimitIntervalSec=` (default 10 s) → systemd gives up with **`start-limit-hit`**. Clear it with `systemctl reset-failed UNIT`.

### Stopping

On `systemctl stop`:
1. systemd runs `ExecStop=` (if set).
2. It sends `KillSignal=` (SIGTERM) to **every process in the unit's cgroup** (`KillMode=control-group`).
3. It waits `TimeoutStopSec=` (default 90 s).
4. Then it sends SIGKILL.

Because systemd tracks the whole **cgroup**, it also stops children the daemon forgot about, which `kill PID` can't do.

### Environment, users, directories

| Directive | Purpose |
|---|---|
| `Environment=KEY=value`, `EnvironmentFile=` | Variables (systemd doesn't read `~/.bashrc` or `/etc/profile`) |
| `User=`, `Group=`, `SupplementaryGroups=` | Run unprivileged |
| `DynamicUser=yes` | A throwaway UID allocated for the service's lifetime |
| `StateDirectory=`, `CacheDirectory=`, `LogsDirectory=`, `RuntimeDirectory=` | Create `/var/lib/NAME`, `/var/cache/NAME`, `/var/log/NAME`, `/run/NAME` owned by the service user |
| `WorkingDirectory=` | The current directory |
| `StandardOutput=journal` (default) | stdout/stderr → `journalctl -u NAME` |

**"Works in my shell, fails as a service"**: the service has a different environment (systemd's `PATH`, no profile files), user, working directory, no terminal, different limits (`LimitNOFILE=`), its own SELinux domain, and maybe sandboxing.

### Resource control (cgroups)

| Directive | cgroup file (topic 097) | Effect |
|---|---|---|
| `MemoryMax=512M` | `memory.max` | Hard limit → OOM kill inside the unit |
| `MemoryHigh=400M` | `memory.high` | Throttle and reclaim first |
| `MemorySwapMax=0` | `memory.swap.max` | No swap |
| `CPUQuota=50%` | `cpu.max` | At most half of one CPU |
| `CPUWeight=` (1–10000, default 100) | `cpu.weight` | Share under contention |
| `TasksMax=` | `pids.max` | Process/thread limit |
| `IOWeight=`, `IOReadBandwidthMax=` | `io.weight`, `io.max` | Disk share and caps |
| `LimitNOFILE=` | (an rlimit, topic 092) | Open files per process |
| `Nice=`, `OOMScoreAdjust=` | (per process) | Priority, OOM bias (topic 093) |

### Sandboxing

| Directive | Effect |
|---|---|
| `NoNewPrivileges=yes` | Set-UID binaries and file capabilities can't raise privileges |
| `ProtectSystem=strict` | The whole filesystem is read-only, except `/dev`, `/proc`, `/sys` and `ReadWritePaths=` |
| `ProtectHome=yes` | `/home`, `/root`, `/run/user` are inaccessible |
| `PrivateTmp=yes` | A private `/tmp` and `/var/tmp` |
| `PrivateDevices=yes` | A minimal `/dev` |
| `ProtectKernelTunables=`, `ProtectKernelModules=`, `ProtectControlGroups=` | No writes to `/proc/sys`, no module loading, read-only cgroupfs |
| `CapabilityBoundingSet=` / `AmbientCapabilities=` | Keep only the needed capabilities (e.g. `CAP_NET_BIND_SERVICE` to bind port 80 as non-root) |
| `RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX` | Limit socket types |
| `SystemCallFilter=@system-service` | A seccomp allow-list of syscall groups |

These use the **same kernel features as containers**. Add them one at a time and test: too strict shows up as `Permission denied`, `Read-only file system` or exit code `226/NAMESPACE`.

## Commands

### Overrides

```bash
sudo systemctl edit httpd          # creates /etc/systemd/system/httpd.service.d/override.conf
sudo systemctl edit --full httpd   # a full copy in /etc (you now own all future changes)
systemctl cat httpd                # the unit plus all drop-ins, in order
sudo systemctl revert httpd        # remove local overrides
sudo systemctl daemon-reload       # after editing files directly
```
Replacing `ExecStart=` correctly:
```ini
[Service]
ExecStart=
ExecStart=/usr/sbin/httpd $OPTIONS -DFOREGROUND -f /etc/httpd/conf/alt.conf
```
Without the empty line:
```
myapp.service: Service has more than one ExecStart= setting, which is only allowed for Type=oneshot services. Refusing.
     Loaded: bad-setting (Reason: Unit myapp.service has a bad unit file setting.)
```

### Type=simple vs Type=exec

```
Type=simple, ExecStart=/usr/bin/nonexistent  → systemctl start returns 0; moments later the unit is "failed"
Type=exec,   ExecStart=/usr/bin/nonexistent  → "Job for t-exec.service failed because the control process exited with error code." (rc=1)
```

### Dependencies and boot timing

```bash
systemctl list-dependencies myapp            # what it pulls in
systemctl list-dependencies --reverse sshd   # what pulls sshd in
systemd-analyze critical-chain myapp.service # the time-critical chain at boot
systemd-analyze verify /etc/systemd/system/myapp.service
```

### Crash loop

```bash
journalctl -u crashy -n 5
```
```
crashy.service: Main process exited, code=exited, status=1/FAILURE
crashy.service: Scheduled restart job, restart counter is at 3.
crashy.service: Start request repeated too quickly.
crashy.service: Failed with result 'start-limit-hit'.
```
```bash
sudo systemctl reset-failed crashy
```

### Resource limits

```bash
sudo systemd-run --unit=memtest -p MemoryMax=50M -p MemorySwapMax=0 --wait python3 -c "b=bytearray(200*1024*1024)"
```
```
Running as unit: memtest.service; invocation ID: 3f…
Finished with result: oom-kill
Main processes terminated with: code=killed/status=KILL
```
```bash
sudo systemctl set-property httpd MemoryMax=1G CPUWeight=200    # persistent drop-in under /etc/systemd/system.control/
systemctl show httpd -p MemoryCurrent -p CPUUsageNSec -p TasksCurrent
systemd-cgtop
```

### Sandboxing score

```bash
systemd-analyze security | head -5
systemd-analyze security myapp.service | tail -3
```
```
UNIT                         EXPOSURE PREDICATE HAPPY
auditd.service                    8.9 EXPOSED   🙁
chronyd.service                   3.9 OK        🙂
...
→ Overall exposure level for myapp.service: 9.6 UNSAFE 😨
```
- A bare unit scores 9.6 (UNSAFE). Adding `DynamicUser=yes`, `ProtectSystem=strict`, `ProtectHome=yes`, `PrivateTmp=yes` and `NoNewPrivileges=yes` brings it down a lot.

### A hardened example

```ini
# /etc/systemd/system/static-web.service
[Unit]
Description=Static web server (hardened demo)
After=network-online.target
Wants=network-online.target

[Service]
Type=exec
DynamicUser=yes
ExecStart=/usr/bin/python3 -m http.server 8080 --directory /srv/www
Restart=on-failure
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictAddressFamilies=AF_INET AF_INET6
CapabilityBoundingSet=
SystemCallFilter=@system-service
MemoryMax=256M
TasksMax=50

[Install]
WantedBy=multi-user.target
```

### Templates, sockets, transient units

**Templates:** `name@.service` runs as `name@INSTANCE.service`, and `%i` is the instance (`getty@tty1.service`, `container-web@blue.service`).

**Socket activation:**
```ini
# /etc/systemd/system/echo.socket
[Socket]
ListenStream=127.0.0.1:7777
Accept=yes                       # one service instance per connection
[Install]
WantedBy=sockets.target

# /etc/systemd/system/echo@.service
[Service]
ExecStart=/usr/bin/cat
StandardInput=socket
```
```bash
sudo systemctl enable --now echo.socket
echo hello-socket | nc 127.0.0.1 7777      # → hello-socket
```
RHEL examples: `cockpit.socket`, libvirt's `virtqemud.socket`.

**Transient units:**
```bash
sudo systemd-run --unit=job1 -p MemoryMax=1G /usr/local/bin/batch.sh
sudo systemd-run --scope -p CPUQuota=20% tar czf /tmp/big.tgz /var/log
sudo systemd-run --on-calendar='*-*-* 03:00' /usr/local/bin/cleanup.sh     # a transient timer
```

### Reading `systemctl status`

```
● myapp.service - My application API
     Loaded: loaded (/etc/systemd/system/myapp.service; enabled; preset: disabled)
    Drop-In: /etc/systemd/system/myapp.service.d
             └─override.conf
     Active: active (running) since Tue 2026-11-17 12:49:56 UTC; 5min ago
   Main PID: 1234 (server)
      Tasks: 9 (limit: 4915)
     Memory: 48.2M (max: 512.0M available: 463.8M peak: 52.0M)
        CPU: 1.204s
     CGroup: /system.slice/myapp.service
             └─1234 /opt/myapp/bin/server --port 8080
```
- `Loaded`: the file, enabled state, and preset (`bad-setting` = a config error).
- `Drop-In`: overrides in effect.
- `Active`: running / exited / `failed (Result: exit-code | signal | timeout | oom-kill | start-limit-hit)`.
- `Memory … max`: the cgroup limit.
- `CGroup`: everything systemd tracks.

**systemd's own exit codes** (not your program's):

| Code | Meaning |
|---|---|
| `203/EXEC` | Couldn't execute: wrong path, not executable, missing `#!` interpreter, wrong SELinux label (e.g. a script in `/home`) |
| `200/CHDIR` | `WorkingDirectory` doesn't exist |
| `217/USER` | `User=` doesn't exist |
| `226/NAMESPACE` | Sandbox setup failed (a path in `ReadWritePaths=` is missing, etc.) |

### Try it
1. Create the two `nonexistent` units (`simple` vs `exec`) and compare what `systemctl start` reports.
2. Reproduce the app1/app2/app3 dependency table with a failing `dep.service`.
3. Override `ExecStart=` of a test service, first without the reset line (see `bad-setting`), then correctly.
4. Make a crash loop with `ExecStart=/usr/bin/false`, `Restart=on-failure`, `StartLimitBurst=3`; watch `journalctl -fu`, then `reset-failed`.
5. Deploy the hardened `static-web.service` and compare `systemd-analyze security` with an unhardened copy.

## Where you'll use it

- **Deploying your own apps** on VMs: a unit file is the simplest production-grade supervisor.
- **Containers at boot:** Podman **Quadlet** files (`.container`) are turned into units by a generator (topic 101).
- **Kubernetes nodes:** kubelet and containerd/CRI-O are systemd services. Their drop-ins and `journalctl -u kubelet` are the first stop in node debugging.
- **Raising limits** (`LimitNOFILE`, `TasksMax`) for databases and proxies via `systemctl edit`.
- **Security hardening** reviews with `systemd-analyze security`.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `Loaded: bad-setting` | Invalid unit (duplicate ExecStart, relative path, typo) | `systemd-analyze verify UNIT`; `journalctl -u UNIT` |
| `status=203/EXEC` | Wrong path, not executable, missing interpreter, SELinux label | `ls -lZ`; move it to `/usr/local/bin`; `restorecon`; `ausearch -m avc` |
| `start` succeeded but the unit failed moments later | `Type=simple` with a program that dies at start | `Type=exec`; read the journal |
| Exits immediately with status 0 | The program daemonised itself | Foreground flag, or `Type=forking` + `PIDFile=` |
| `start-limit-hit` | A throttled crash loop | Fix the crash; `reset-failed` |
| Starts before the network or DB is ready | Missing `After=`, or `network.target` used instead of `network-online.target` | Add ordering; app-level retries |
| Changes are ignored | Edited `/usr/lib/…`, or no `daemon-reload` | `systemctl edit`; `daemon-reload` |
| `stop` hangs for 90 s | The process ignores SIGTERM | Fix its signal handling; tune `TimeoutStopSec=` |
| Works by hand, fails as a service | Environment, user, limits, sandbox or SELinux domain differ | `systemctl show UNIT`; `systemd-run --pty -p … CMD` to reproduce |
| A user unit stops at logout | Linger is off | `loginctl enable-linger USER` |

## Quick recap

- Units in `/etc/systemd/system` override `/usr/lib/systemd/system`. Use `systemctl edit` (drop-ins); list settings append, so reset with `ExecStart=` first.
- `Type=exec` for foreground programs; `oneshot` + `RemainAfterExit` for scripts; `notify` for daemons that support it.
- Dependencies (`Wants`/`Requires`) ≠ ordering (`After`): use both. `network-online.target` for network-dependent starts.
- `Restart=on-failure` + start limits; stop = SIGTERM to the whole cgroup → `TimeoutStopSec` → SIGKILL.
- Limits: `MemoryMax`, `CPUQuota`, `TasksMax`, `LimitNOFILE`. Hardening: `DynamicUser`, `NoNewPrivileges`, `ProtectSystem=strict`, `PrivateTmp`, capabilities, `SystemCallFilter`; measure with `systemd-analyze security`.

**Interview questions**

1. *`Requires=` vs `After=`?* `Requires=` is a dependency (start that unit too, and fail together); `After=` is only ordering. Without `After=`, both start in parallel, so the failure of the required unit may not stop yours.
2. *How do you change the `ExecStart=` of a vendor unit?* `systemctl edit UNIT`, then add an empty `ExecStart=` line to clear the list, followed by the new `ExecStart=`. Never edit `/usr/lib/systemd/system`.
3. *How does systemd make sure all of a service's processes are stopped?* Each service runs in its own cgroup; on stop, systemd sends SIGTERM to every process in it, waits `TimeoutStopSec=`, then sends SIGKILL to whatever is left.
