# 037 · systemd: Services, Targets and Your First Unit File

> **You need first:** [036 · Resource monitoring](036-resource-monitoring.md)
> **Next:** [038 · Logging: journald, rsyslog and logrotate](038-logging-journald-rsyslog-logrotate.md)

---

## What it is

**systemd** is **PID 1**: the first program the kernel starts, and the manager of everything else on RHEL, Ubuntu, Debian, Fedora and most modern distros.

It manages **units**. A unit is anything systemd controls, described by a small text file:

| Unit type | Suffix | Example |
|---|---|---|
| **Service** | `.service` | `sshd.service`: a program to run and supervise |
| **Target** | `.target` | `multi-user.target`: a named group of units = a "system state" |
| **Timer** | `.timer` | Run a service on a schedule (topic 039) |
| **Socket** | `.socket` | Start a service when a connection arrives |
| **Mount** | `.mount` | A mounted filesystem (topic 048) |
| **Path** | `.path` | Start a service when a file changes |
| Device, slice, scope, swap… | | Hardware, resource groups, swap areas |

**`systemctl`** is the command to control systemd. **`journalctl`** reads its logs (topic 038).

## Why it exists

Before systemd, services were started by shell scripts run one after another at boot ("SysV init"). That was slow, couldn't restart crashed services, and had no reliable way to find all of a service's processes. systemd:
- starts things **in parallel**, ordered only where needed;
- **supervises** services and restarts them on failure;
- tracks every process of a service in a **cgroup** (control group: a kernel feature that groups processes and can limit their resources, topic 097), so "stop the service" really stops all of it;
- captures every service's output into one **journal**;
- gives one consistent tool for everything.

## Analogy

systemd is the **building manager**. Each unit file is a **job card** ("run the boiler; if it stops, restart it after 5 seconds; it needs the water supply running first"). A **target** is a **building mode**: "night mode" (rescue: minimum services), "office hours" (multi-user: everything for a server), "office hours + reception desk" (graphical: plus the desktop). `systemctl` is the manager's radio.

## How it works inside

### Where unit files live (highest priority first)

| Path | Who owns it |
|---|---|
| `/etc/systemd/system/` | **You**, the admin. Your units and overrides win |
| `/run/systemd/system/` | Generated at runtime; gone after a reboot |
| `/usr/lib/systemd/system/` | **Packages**. Never edit these; updates overwrite them (Ubuntu also uses `/lib/systemd/system/`) |

systemd reads unit files into memory. **After you edit files by hand, run `systemctl daemon-reload`**, or systemd keeps using the old version.

### start vs enable: two completely different things

- **`start`** = run it **now**. Forgotten at reboot.
- **`enable`** = start it **at boot**. Technically, it creates a **symlink** (topic 008) from the target's "wants" directory to the unit, as the unit's `[Install]` section says:
  `/etc/systemd/system/multi-user.target.wants/sshd.service → /usr/lib/systemd/system/sshd.service`
- **`enable --now`** does both. "Running but not enabled" is a classic cause of a service vanishing after a reboot.

### Targets: system states

| Target | What runs | Old "runlevel" |
|---|---|---|
| `poweroff.target` | Shut down | 0 |
| `rescue.target` | Single user: all local filesystems mounted, minimal services, root password needed | 1 |
| `multi-user.target` | Text mode, networking, all normal services. **Servers use this** | 2, 3, 4 |
| `graphical.target` | multi-user + the graphical login screen | 5 |
| `reboot.target` | Reboot | 6 |
| `emergency.target` | Bare minimum: root filesystem **read-only**, nothing else; root password needed | — |
| `default.target` | A symlink to whichever target is used at boot | — |

At boot, systemd starts `default.target` and pulls in everything it "wants", recursively, ordering them by their `After=`/`Before=` rules.

`isolate` switches to a target **now**, stopping everything that target doesn't need. `set-default` changes which target is used **at boot**.

### What systemd does when you start a service

1. Reads the unit and its dependencies; starts those first if they're ordered before it.
2. Creates a cgroup for it (`/sys/fs/cgroup/system.slice/sshd.service/`).
3. Forks a child and sets it up: user, environment, working directory, limits, security settings. Then it runs (execve) `ExecStart=`.
4. Connects the program's stdout/stderr to the **journal**.
5. Watches it. If it exits unexpectedly and `Restart=` says so, it starts it again.

## Commands

### Managing services

```bash
systemctl status sshd
```
```
● sshd.service - OpenSSH server daemon
     Loaded: loaded (/usr/lib/systemd/system/sshd.service; enabled; preset: enabled)
     Active: active (running) since Mon 2026-11-16 08:51:02 UTC; 6h ago
       Docs: man:sshd(8)
             man:sshd_config(5)
   Main PID: 1050 (sshd)
      Tasks: 1 (limit: 23062)
     Memory: 5.6M (peak: 22.1M)
        CPU: 1.204s
     CGroup: /system.slice/sshd.service
             └─1050 "sshd: /usr/sbin/sshd -D [listener] 0 of 10-100 startups"

Nov 16 13:02:11 server1 sshd-session[4120]: Accepted publickey for alice from 192.168.56.1 port 51022 ssh2
```

| Line | Meaning |
|---|---|
| `Loaded:` | Which file defines it; **enabled** = starts at boot; `preset` = the distro's default |
| `Active:` | `active (running)`, `inactive (dead)`, `failed`, `activating`… and since when |
| `Main PID` | The main process |
| `Tasks` / `Memory` / `CPU` | Resource use, measured through the cgroup |
| `CGroup:` | Every process belonging to the service |
| The last lines | The newest log entries from the journal |

| Command | Effect |
|---|---|
| `systemctl start` / `stop` / `restart SVC` | Now only |
| `systemctl reload SVC` | Re-read config without restarting (if the service supports it) |
| `systemctl enable` / `disable SVC` | At boot / not at boot |
| `systemctl enable --now SVC` | Enable **and** start |
| `systemctl disable --now SVC` | Disable **and** stop |
| `systemctl is-active` / `is-enabled` / `is-failed SVC` | One-word answers (good for scripts) |
| `systemctl mask SVC` / `unmask SVC` | Make it **impossible** to start (links the unit to `/dev/null`) |
| `systemctl --failed` | Every failed unit |
| `systemctl list-units --type=service` | Loaded services and their state |
| `systemctl list-unit-files --type=service` | Every service and whether it's enabled |
| `systemctl cat SVC` | Show the unit file plus overrides |
| `systemctl show SVC -p Restart,User` | Show specific properties |
| `systemctl edit SVC` | Create an override (drop-in) file |
| `systemctl daemon-reload` | Reload unit files after editing |
| `journalctl -u SVC -e` / `-f` | That service's logs (jump to end / follow) |

```bash
sudo dnf install -y nginx
sudo systemctl enable --now nginx
systemctl is-enabled nginx ; systemctl is-active nginx
```
```
Created symlink '/etc/systemd/system/multi-user.target.wants/nginx.service' → '/usr/lib/systemd/system/nginx.service'.
enabled
active
```
- The symlink line is exactly what "enable" does. (Reaching nginx from **another** machine also needs a firewall rule, topic 071.)

### Overriding a packaged unit safely

```bash
sudo systemctl edit nginx
```
This opens an editor for `/etc/systemd/system/nginx.service.d/override.conf`. Add, for example:
```ini
[Service]
Restart=on-failure
RestartSec=5s
```
Save, and systemd reloads automatically. `systemctl cat nginx` now shows the original **plus** your override. Never edit files in `/usr/lib/systemd/system/`. Topic 098 covers overrides in depth.

### Targets

```bash
systemctl get-default
sudo systemctl set-default multi-user.target
```
```
graphical.target
Removed '/etc/systemd/system/default.target'.
Created symlink '/etc/systemd/system/default.target' → '/usr/lib/systemd/system/multi-user.target'.
```

```bash
sudo systemctl isolate multi-user.target      # switch now (the desktop stops)
sudo systemctl isolate graphical.target
systemctl list-dependencies multi-user.target | head
```

**Choosing a target for one boot only:** at the boot menu, edit the kernel line and add `systemd.unit=rescue.target` (or `multi-user.target`, `emergency.target`). Topics 053 and 057 show how. On RHEL 10, rescue and emergency mode ask for **root's password**; if root is locked you'll see "the root account is locked", and you need the recovery method in topic 057.

`init 3`, `telinit 5` and `runlevel` still work as compatibility shims, but use `systemctl`.

### Your first unit file

A tiny script turned into a supervised service:

```bash
sudo tee /usr/local/bin/heartbeat.sh >/dev/null <<'EOF'
#!/bin/bash
while true; do
  echo "heartbeat from $(hostname) at $(date +%T)"
  sleep 10
done
EOF
sudo chmod 755 /usr/local/bin/heartbeat.sh

sudo tee /etc/systemd/system/heartbeat.service >/dev/null <<'EOF'
[Unit]
Description=Heartbeat demo service
After=network.target

[Service]
Type=exec
ExecStart=/usr/local/bin/heartbeat.sh
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now heartbeat
journalctl -u heartbeat -n 3
```
```
Nov 16 15:10:01 server1 systemd[1]: Started heartbeat.service - Heartbeat demo service.
Nov 16 15:10:01 server1 heartbeat.sh[5120]: heartbeat from server1.example.com at 15:10:01
Nov 16 15:10:11 server1 heartbeat.sh[5120]: heartbeat from server1.example.com at 15:10:11
```

| Line | Meaning |
|---|---|
| `[Unit] Description=` | Human-readable name |
| `After=network.target` | **Order**: start after the network setup step (ordering only, not a requirement) |
| `[Service] Type=exec` | The service counts as started once the program has been successfully launched |
| `ExecStart=` | The command. **Absolute path. Not a shell**: no pipes, `>`, or `&&` (wrap them in a script) |
| `Restart=on-failure` / `RestartSec=3` | If it crashes, restart it after 3 seconds |
| `[Install] WantedBy=multi-user.target` | What `enable` hooks it into |

Now kill it and watch systemd bring it back:
```bash
sudo kill -9 $(systemctl show -p MainPID --value heartbeat)
sleep 4 ; systemctl status heartbeat | grep Active
```
```
     Active: active (running) since Mon 2026-11-16 15:12:04 UTC; 1s ago
```
- The start time is new: it was restarted. Note that `Restart=on-failure` does **not** restart after a clean `systemctl stop`.

Clean up: `sudo systemctl disable --now heartbeat; sudo rm /etc/systemd/system/heartbeat.service; sudo systemctl daemon-reload`.

### Seeing the process tree per service

```bash
systemd-cgls --no-pager | head -15
systemd-cgtop
```
- Processes grouped by service (cgroup), and live resource use per service.

### Try it
1. `systemctl list-unit-files --type=service --state=enabled`: what starts at boot on your machine?
2. Install `nginx` (or `httpd`), `enable --now` it, reboot, and confirm it came back.
3. Build the heartbeat service, kill it with `-9`, and watch it restart.
4. `mask` it, try to `start` it (refused), then `unmask` it.

## Where you'll use it

- **Every service on every modern Linux server:** web servers, databases, agents, Kubernetes' own node agent (`kubelet.service`) and container runtime (`containerd.service`, `crio.service`).
- **"Service not running after a reboot"** → it wasn't enabled.
- **Running your own app** reliably: a unit file with `Restart=`, a dedicated `User=`, and resource limits (topic 098). That's the non-container way to deploy.
- **Containers on RHEL** can be run as systemd services through Podman **Quadlet** (topic 101).
- **Targets:** servers run `multi-user.target`. Desktops run `graphical.target`.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| Service missing after a reboot | Started but never enabled | `systemctl enable --now SVC` |
| `Failed to start …: Unit … is masked` | It was masked | `systemctl unmask SVC` |
| Your edits to a unit are ignored | systemd still has the old file in memory | `systemctl daemon-reload` |
| `Active: failed` | The program exited with an error | `systemctl status SVC`, `journalctl -u SVC -b -e` (topic 038); deep dive in topic 098 |
| `status=203/EXEC` | `ExecStart` path wrong, file not executable, or blocked by SELinux | Check the path, `chmod +x`, `ls -Z` (topic 073) |
| `start request repeated too quickly` | It crashed several times in a row and hit the start limit | Fix the cause, then `systemctl reset-failed SVC` |
| The machine reboots in a loop | `default.target` was set to `reboot.target` | Boot with `systemd.unit=multi-user.target` and `set-default` (topic 057) |
| `Operation refused, unit may not be isolated` | That target doesn't allow isolate | Use a standard target |

## Quick recap

- systemd = PID 1, manages **units** (`.service`, `.target`, `.timer`, `.socket`, `.mount`…). `systemctl` controls them; the journal holds their logs.
- `start` = now; `enable` = at boot (a symlink); `--now` = both. `mask` = forbid. `daemon-reload` after editing files.
- Targets = system states. Servers use `multi-user.target`. `get-default`, `set-default`, `isolate`.
- Your own units go in `/etc/systemd/system/`; override packaged ones with `systemctl edit`, never in `/usr/lib`.

**Interview questions**

1. *`systemctl enable` vs `start`?* `start` runs the service now; `enable` makes it start at boot by creating a symlink in the target's `.wants` directory. `enable --now` does both.
2. *What does `mask` do?* It links the unit to `/dev/null`, so it can't be started at all, even as a dependency of another unit.
3. *Rescue vs emergency target?* Rescue mounts all local filesystems and starts a minimal set of services. Emergency mounts only the root filesystem, read-only, and starts almost nothing.
