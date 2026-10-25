# systemd Unit Files: Writing, Overriding & Hardening Services

> **Track:** **[Production Practice]** · **[Internals]** · supports *Start and stop services and configure services to start automatically at boot* and *systemd timer units* **[RHCSA Core]** · **Verified:** systemd 257 (RHEL 10.2 `ubi-init` container, Oct 2026)
> **Prerequisites:** [systemd targets & service management](systemd-targets-and-services.md) · [Processes & system calls](../processes-and-resource-management/processes-and-system-calls.md) · [System logging (journal)](../logs-scheduling-and-packages/system-logging.md)
> **Next:** [Job scheduling (timers)](../logs-scheduling-and-packages/job-scheduling.md#6-systemd-timers-supplemented-rhcsa-core) · [Namespaces & cgroups](../containers-and-virtualization/namespaces-and-cgroups.md) · [Podman Quadlet](../containers-and-virtualization/podman-containers.md#9-start-containers-at-boot-quadlet)

## 1. Why This Matters

The RHCSA mostly asks you to *use* units (`enable --now`, `set-default`). Production work means *writing* them: running your own application reliably, restarting it on failure, ordering it after its dependencies, limiting its resources, and confining what it can touch. Containers in Quadlet, timers and socket-activated services are all just units.

## 2. Where Units Live (precedence high → low)

| Path | Owner | Notes |
|---|---|---|
| `/etc/systemd/system/` | Administrator | Your units and overrides. **Wins** |
| `/run/systemd/system/` | Runtime (transient, generated) | Lost at reboot |
| `/usr/lib/systemd/system/` | Packages | **Never edit**; updates overwrite it |
| `~/.config/systemd/user/`, `/etc/systemd/user/` | Per-user units (`systemctl --user`) | Need `loginctl enable-linger USER` to run without a login |

**Drop-ins** (`NAME.service.d/*.conf`) change selected settings without copying the whole unit:

```bash
systemctl edit httpd          # creates /etc/systemd/system/httpd.service.d/override.conf, reloads on save
systemctl edit --full httpd   # full copy in /etc/systemd/system/ (you now own all future changes)
systemctl cat httpd           # the unit plus all drop-ins, in order
systemctl revert httpd        # remove local overrides
systemctl daemon-reload       # after editing files directly
```

**Drop-in semantics:** most settings in a drop-in **replace** the original value; **list settings** (`ExecStart=`, `ExecStartPre=`, `Environment=`, `After=`…) **append**. To replace a list, reset it with an empty assignment first. Verified:

```ini
# /etc/systemd/system/svc.service.d/override.conf
[Service]
ExecStart=                      # ← required: clears the original ExecStart
ExecStart=/usr/bin/sleep 2000
```

Without the empty line: `Service has more than one ExecStart= setting, which is only allowed for Type=oneshot services. Refusing.` and `Loaded: bad-setting`.

## 3. Anatomy of a Service Unit

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
EnvironmentFile=-/etc/sysconfig/myapp          # leading "-": don't fail if missing
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
| `[Unit]` | Description, documentation, **dependencies and ordering** (any unit type) |
| `[Service]` (or `[Socket]`, `[Timer]`, `[Mount]`, `[Path]`…) | Type-specific behavior |
| `[Install]` | What `systemctl enable` does: `WantedBy=multi-user.target` creates `/etc/systemd/system/multi-user.target.wants/myapp.service` → symlink |

**`ExecStart=` is not a shell command line.** No pipes, redirection, globbing or `&&`; variables use `${VAR}`/`$VAR` from the unit's environment. If you need shell features: `ExecStart=/usr/bin/bash -c '…'` or, better, a script. The first word must be an absolute path or an executable name found in systemd's fixed search path (`systemd-analyze verify` rejects `relative/path`, verified).

## 4. Service Types

| `Type=` | systemd considers the service started when… | Use for |
|---|---|---|
| `simple` (default) | Immediately after `fork()`, **before** the binary is executed | Legacy default. A missing binary still "starts successfully", then fails |
| `exec` | After `execve()` succeeded | **Recommended** for long-running foreground programs: start errors are reported to `systemctl start` |
| `forking` | The started process forks and the parent exits (classic daemons); use `PIDFile=` | Old-style daemons that background themselves |
| `oneshot` | The process **exits** (successfully) | Scripts and setup tasks; with `RemainAfterExit=yes` the unit stays "active" afterwards |
| `notify` | The program sends `READY=1` via `sd_notify()` | Daemons that support systemd notification (e.g., many RHEL services) |
| `dbus` | The program acquires its D-Bus name (`BusName=`) | D-Bus services |

Verified difference:

```
Type=simple, ExecStart=/usr/bin/nonexistent  → systemctl start … rc=0, then the unit shows "failed"
Type=exec,   ExecStart=/usr/bin/nonexistent  → "Job for t-exec.service failed because the control process exited with error code." rc=1
```

The program must **stay in the foreground** for `simple`/`exec`/`notify`. If it daemonizes itself, systemd thinks it exited (use `forking` or the program's foreground flag, e.g. `httpd -DFOREGROUND`).

## 5. Dependencies vs Ordering (the most misunderstood part)

**Dependencies** say *what else to start* (or stop); **ordering** says *in which order*. They are independent.

| Directive | Meaning |
|---|---|
| `Wants=B` | Start B too; don't care if it fails |
| `Requires=B` | Start B too; if B is stopped or (with ordering) fails, this unit is stopped/not started |
| `Requisite=B` | B must **already** be active; don't start it |
| `BindsTo=B` | Like Requires, plus stop this unit whenever B stops (devices, mounts) |
| `PartOf=B` | Stop/restart this unit when B is stopped/restarted (one direction only) |
| `Conflicts=B` | Starting one stops the other |
| `After=B` / `Before=B` | **Ordering only**: start this after/before B, if both are being started |

Verified with a dependency `dep.service` that always fails:

| Unit | Directives | Result |
|---|---|---|
| app1 | `Requires=dep` (no `After=`) | **active**: both started in parallel; the failure didn't stop app1 |
| app2 | `Requires=dep` + `After=dep` | **inactive**: app2 waited for dep, saw it fail, didn't start |
| app3 | `Wants=dep` + `After=dep` | **active**: waited, but a Wants failure doesn't matter |

**Rule:** almost always pair a dependency with `After=`.

**Network ordering:** `After=network.target` only means "after the network *management* stack started", not that addresses are configured. Services that must bind to a specific IP or reach a remote server at startup need `Wants=network-online.target` + `After=network-online.target` (on RHEL, satisfied by `NetworkManager-wait-online.service`).

```bash
systemctl list-dependencies myapp            # what it pulls in
systemctl list-dependencies --after myapp    # what it's ordered after
systemctl list-dependencies --reverse sshd   # what pulls sshd in
systemd-analyze critical-chain myapp.service # time-critical ordering chain at boot
```

## 6. Restart Policy & Start Limits

| `Restart=` | Restarts when the process… |
|---|---|
| `no` (default) | Never |
| `on-failure` | Exits non-zero, is killed by a signal, times out, or the watchdog fires |
| `on-abnormal` | Signal, timeout, watchdog (not a clean non-zero exit) |
| `always` | Exits for any reason (except `systemctl stop`) |

Crash loops are throttled: if a unit starts more than `StartLimitBurst=` times (default 5) within `StartLimitIntervalSec=` (default 10 s), systemd gives up. Verified (`Burst=3`): `Scheduled restart job, restart counter is at 3.` → `Start request repeated too quickly.` → `failed`. Clear with `systemctl reset-failed myapp`.

## 7. Stopping: Signals, Timeouts, KillMode

On `systemctl stop`: run `ExecStop=` if defined, then send `KillSignal=` (SIGTERM) to **every process in the unit's cgroup** (`KillMode=control-group`, the default), wait `TimeoutStopSec=` (default 90 s), then SIGKILL. Verified: a service that ignores SIGTERM with `TimeoutStopSec=3` stops after 3.0 s with `Killing process … with signal SIGKILL` and `Failed with result 'timeout'`.

Because systemd tracks the whole **cgroup**, it can stop children the daemon forgot about; that's something `kill PID` can't do.

## 8. Environment, Users & Directories

| Directive | Purpose |
|---|---|
| `Environment=KEY=value` / `EnvironmentFile=/etc/sysconfig/x` | Variables (systemd doesn't read `~/.bashrc` or `/etc/profile`) |
| `User=` / `Group=` / `SupplementaryGroups=` | Run unprivileged |
| `DynamicUser=yes` | Allocate a transient UID for the service's lifetime (verified: `uid=63722(du)`) |
| `StateDirectory=` / `CacheDirectory=` / `LogsDirectory=` / `RuntimeDirectory=` | Create `/var/lib/NAME`, `/var/cache/NAME`, `/var/log/NAME`, `/run/NAME` owned by the service user |
| `WorkingDirectory=` | cwd (exit status 200/CHDIR if missing) |
| `StandardOutput=journal` (default) | stdout/stderr go to the journal: `journalctl -u NAME` |

A common surprise: "works in my shell, fails as a service". The service has a different environment (no profile files, `PATH` is systemd's), user, cwd, no TTY, limits (`LimitNOFILE=`), SELinux domain, and possibly sandboxing.

## 9. Resource Control (cgroups)

Every service runs in its own **cgroup** (`/sys/fs/cgroup/system.slice/NAME.service/`), so limits are enforced by the kernel for all of its processes:

| Directive | cgroup file | Effect |
|---|---|---|
| `MemoryMax=512M` | `memory.max` | Hard limit → **OOM kill** inside the cgroup |
| `MemoryHigh=400M` | `memory.high` | Throttle + reclaim before the hard limit |
| `MemorySwapMax=0` | `memory.swap.max` | Forbid swap use |
| `CPUQuota=50%` | `cpu.max` | At most half of one CPU (throttling) |
| `CPUWeight=` (1–10000, default 100) | `cpu.weight` | Relative share under contention |
| `TasksMax=` | `pids.max` | Process/thread limit (fork bombs) |
| `IOWeight=`, `IOReadBandwidthMax=` | `io.weight`, `io.max` | Disk I/O share and caps |
| `LimitNOFILE=` | (rlimit, not cgroup) | Open-file limit per process |
| `Nice=`, `OOMScoreAdjust=` | (per process) | Scheduling priority, OOM bias |

Verified: `systemd-run --unit=memtest2 -p MemoryMax=50M -p MemorySwapMax=0 --wait python3 -c "b=bytearray(200*1024*1024)"` → `A process of this unit has been killed by the OOM killer.` / `Failed with result 'oom-kill'`. (Without `MemorySwapMax=0`, the same run used 24 MiB of swap and succeeded.)

```bash
systemctl set-property httpd MemoryMax=1G CPUWeight=200    # persistent drop-in in /etc/systemd/system.control/
systemd-cgtop                                              # live resource use per unit
systemctl show httpd -p MemoryCurrent -p CPUUsageNSec -p TasksCurrent
```

Details of the cgroup interface: [namespaces & cgroups](../containers-and-virtualization/namespaces-and-cgroups.md).

## 10. Sandboxing (Hardening)

| Directive | Effect |
|---|---|
| `NoNewPrivileges=yes` | Set-UID binaries and file capabilities can't raise privileges |
| `ProtectSystem=strict` | Whole filesystem read-only except `/dev`, `/proc`, `/sys` and paths in `ReadWritePaths=` (verified: `touch /etc/x` → `Read-only file system`) |
| `ProtectHome=yes` | `/home`, `/root`, `/run/user` inaccessible |
| `PrivateTmp=yes` | Private `/tmp` and `/var/tmp` (files appear under `/tmp/systemd-private-*`) |
| `PrivateDevices=yes` | Minimal `/dev` |
| `ProtectKernelTunables=yes`, `ProtectKernelModules=yes`, `ProtectControlGroups=yes` | No writes to `/proc/sys`, no module loading, read-only cgroupfs |
| `CapabilityBoundingSet=CAP_NET_BIND_SERVICE` / `AmbientCapabilities=` | Keep only the capabilities needed (e.g., bind port 80 as non-root) |
| `RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX` | Limit socket types |
| `SystemCallFilter=@system-service` | seccomp allow-list of syscall groups |

These use the same kernel features as containers (mount namespaces, capabilities, seccomp). Measure with:

```bash
systemd-analyze security                 # table of all services with an exposure score
systemd-analyze security myapp.service   # per-setting breakdown (verified: a bare unit scores 9.6 UNSAFE; DynamicUser alone → 8.2 EXPOSED)
```

Add settings one at a time and test; overly strict sandboxing shows up as `Permission denied`/`Read-only file system` or exit codes like `226/NAMESPACE`.

## 11. Templates, Sockets & Transient Units

**Templates:** `name@.service` is instantiated as `name@INSTANCE.service`; `%i` is the instance (`getty@tty1.service`, `echo@0-127.0.0.1:7777-….service`).

**Socket activation:** systemd listens; the service starts on the first connection (on-demand start, zero-downtime restarts, parallel boot). Verified example:

```ini
# echo.socket
[Socket]
ListenStream=127.0.0.1:7777
Accept=yes                       # one service instance per connection (inetd style)
[Install]
WantedBy=sockets.target

# echo@.service
[Service]
ExecStart=/usr/bin/cat
StandardInput=socket
```

`systemctl enable --now echo.socket` → a client sending `hello-socket` gets `hello-socket` back. Examples on RHEL: `cockpit.socket`, `sshd.socket` (optional), libvirt's `virtqemud.socket`.

**Transient units** (no files): `systemd-run --unit=job1 -p MemoryMax=1G /usr/local/bin/batch.sh`, `systemd-run --scope -p CPUQuota=20% cmd`, `systemd-run --on-calendar=… cmd` (transient timer).

## 12. Reading `systemctl status`

```
● myapp.service - My application API
     Loaded: loaded (/etc/systemd/system/myapp.service; enabled; preset: disabled)
    Drop-In: /etc/systemd/system/myapp.service.d
             └─override.conf
     Active: active (running) since Sun 2026-10-25 20:49:56 UTC; 5min ago
   Main PID: 1234 (server)
      Tasks: 9 (limit: 4915)
     Memory: 48.2M (max: 512.0M available: 463.8M peak: 52.0M)
        CPU: 1.204s
     CGroup: /system.slice/myapp.service
             └─1234 /opt/myapp/bin/server --port 8080
```

| Line | Read it as |
|---|---|
| `Loaded:` | Unit file path; `enabled`/`disabled`/`static` (no `[Install]`)/`masked`; vendor preset; `bad-setting` = configuration error |
| `Drop-In:` | Overrides in effect |
| `Active:` | `active (running)`, `active (exited)` (oneshot + RemainAfterExit), `failed (Result: exit-code / signal / timeout / oom-kill / start-limit-hit)` |
| `Main PID:`, `CGroup:` | The process tree systemd tracks |

**Exit-status codes from systemd itself** (not your program): `203/EXEC` (couldn't exec: path, permissions, SELinux label, missing interpreter), `200/CHDIR`, `217/USER` (user doesn't exist), `226/NAMESPACE` (sandbox setup failed).

## 13. RHCSA & Production Patterns

```bash
# Turn a script into a boot-time service (RHCSA-style)
install -m 0755 myscript.sh /usr/local/bin/myscript.sh     # not in /home: SELinux typically blocks systemd from executing home-labeled files (203/EXEC)
cat > /etc/systemd/system/myscript.service <<'EOF'
[Unit]
Description=My script
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/myscript.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now myscript.service
systemctl status myscript ; journalctl -u myscript -b

# Raise a vendor service's open-file limit without touching /usr/lib
systemctl edit httpd      # [Service]  LimitNOFILE=65536
systemctl restart httpd ; cat /proc/$(systemctl show -p MainPID --value httpd)/limits | grep 'open files'
```

## 14. Labs

1. **Type matters.** Create the two `nonexistent` units from §4 and compare `systemctl start` results.
2. **Ordering.** Reproduce the §5 table with a failing `dep.service`. Then make `dep` succeed slowly (`ExecStart=/usr/bin/sleep 5`, `Type=oneshot`) and observe app1 vs app2 start times (`journalctl -o short-precise`).
3. **Override correctly.** Change `ExecStart=` of a test service through `systemctl edit`, first without the empty reset line (observe `bad-setting`), then correctly.
4. **Crash loop.** `ExecStart=/usr/bin/false` + `Restart=on-failure`, `StartLimitBurst=3`. Watch `journalctl -fu`, then `systemctl reset-failed`.
5. **Resource limit.** Reproduce the OOM kill with `systemd-run -p MemoryMax=50M -p MemorySwapMax=0`. Inspect `systemctl status` (Result: oom-kill).
6. **Harden.** Write a unit for `python3 -m http.server 8080 --directory /srv/www` with `DynamicUser=yes`, `ProtectSystem=strict`, `ProtectHome=yes`, `PrivateTmp=yes`, `NoNewPrivileges=yes`. Compare `systemd-analyze security` before and after.

## 15. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Loaded: bad-setting` | Invalid unit (duplicate ExecStart, relative path, typo) | `systemd-analyze verify UNIT`; `journalctl -u UNIT` |
| `status=203/EXEC` | Wrong path, not executable, missing `#!` interpreter, SELinux label (e.g., script in `/home`) | `ls -lZ` the file; move to `/usr/local/bin`; `restorecon`; `ausearch -m avc` |
| Unit "active" briefly then "failed", start returned success | `Type=simple` with a program that dies at startup | Use `Type=exec`; read the journal |
| Service exits immediately with status 0 | Program daemonized itself | Foreground flag, or `Type=forking` + `PIDFile=` |
| `start-limit-hit` | Crash loop throttled | Fix the crash; `systemctl reset-failed` |
| Starts before the network/DB is ready | Missing `After=`, or `network.target` instead of `network-online.target` | Add the ordering; consider app-level retries |
| Changes ignored | Edited `/usr/lib/…` or no `daemon-reload` | `systemctl edit`; `daemon-reload` |
| `systemctl stop` hangs for 90 s | Process ignores SIGTERM | Fix signal handling; tune `TimeoutStopSec=` |
| "Works by hand, not as a service" | Environment, user, limits, sandbox, SELinux domain differ | Compare with `systemd-run --pty --property=… CMD` or `systemctl show UNIT` |
| User unit stops at logout | Linger off | `loginctl enable-linger USER` |

## 16. Interview Questions

| Question | Answer |
|---|---|
| `Requires=` vs `After=`? | Requires is a dependency (start it too, fail together); After is only ordering. Without After, both start in parallel. |
| `Type=simple` vs `exec` vs `forking` vs `notify`? | When systemd considers the service started: after fork, after exec, after the parent exits, or after READY=1. |
| How do you change ExecStart of a vendor unit? | `systemctl edit UNIT`, reset with `ExecStart=` then set the new value; never edit `/usr/lib/systemd/system`. |
| `enable` vs `start`? | enable creates `[Install]` symlinks for boot; start runs it now. |
| Why `network-online.target`? | `network.target` doesn't mean addresses are configured; network-online waits for NetworkManager to report connectivity. |
| How does systemd stop all of a service's processes? | Through its cgroup (KillMode=control-group): SIGTERM to all, then SIGKILL after TimeoutStopSec. |
| How do you limit a service to 1 GiB of RAM? | `MemoryMax=1G` (cgroup memory.max); over the limit, the cgroup's OOM killer acts. |
| How do you harden a service? | Run as a dedicated/dynamic user, NoNewPrivileges, ProtectSystem/ProtectHome, PrivateTmp, minimal capabilities, syscall filter; measure with `systemd-analyze security`. |
| What is socket activation? | systemd owns the listening socket and starts the service on demand, passing it the socket. |

## 17. Quick Revision

```
/etc/systemd/system > /run > /usr/lib · systemctl edit [--full] / cat / revert · daemon-reload · lists append → reset "ExecStart="
[Unit] Description After/Before Wants/Requires/BindsTo/PartOf/Conflicts · [Service] Type ExecStart(no shell) Restart · [Install] WantedBy
Type: simple(fork) exec(exec) forking(PIDFile) oneshot(RemainAfterExit) notify(READY=1) · Requires+After together · network-online.target
Restart=on-failure RestartSec · StartLimitBurst/IntervalSec → start-limit-hit · reset-failed
stop: SIGTERM to cgroup → TimeoutStopSec (90 s) → SIGKILL · KillMode=control-group
User/DynamicUser · StateDirectory/RuntimeDirectory · Environment/EnvironmentFile · journal
MemoryMax/MemoryHigh/CPUQuota/CPUWeight/TasksMax/IOWeight · LimitNOFILE · OOMScoreAdjust · systemctl set-property · systemd-cgtop
NoNewPrivileges ProtectSystem=strict ProtectHome PrivateTmp CapabilityBoundingSet SystemCallFilter · systemd-analyze security|verify|critical-chain
203/EXEC 200/CHDIR 217/USER 226/NAMESPACE · templates %i · .socket Accept= · systemd-run [--scope] -p …
```

## 18. Cross-References

- [systemd targets & service management](systemd-targets-and-services.md) · [Boot process](boot-process.md)
- [Job scheduling (timer units)](../logs-scheduling-and-packages/job-scheduling.md) · [System logging (journalctl -u)](../logs-scheduling-and-packages/system-logging.md)
- [Processes & system calls (signals, capabilities)](../processes-and-resource-management/processes-and-system-calls.md) · [Memory management (OOM)](../processes-and-resource-management/memory-management.md)
- [Namespaces & cgroups](../containers-and-virtualization/namespaces-and-cgroups.md) · [Podman Quadlet](../containers-and-virtualization/podman-containers.md) · [SELinux confined domains](../firewall-and-selinux/selinux-confined-users-and-domains.md)
