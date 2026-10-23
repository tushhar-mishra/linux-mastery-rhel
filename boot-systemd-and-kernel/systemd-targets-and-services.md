# systemd Targets & Service Management

> **Sessions:** S50 (targets; service essentials **supplemented**) · **Objectives:** *Boot systems into different targets manually* · *Configure systems to boot into a specific target automatically* · *Start, stop, and check the status of network services* · *Start and stop services and configure services to start automatically at boot* **[RHCSA Core]**
> **Related:** [Boot process](boot-process.md) · [Boot recovery](boot-recovery.md) · [Processes & signals](../processes-and-resource-management/processes-and-signals.md)

## 1. Overview

**systemd** is PID 1 on RHEL. It manages **units**: services, mounts, sockets, timers, targets and more. A **target** is a unit that groups other units to define a system state, replacing SysV runlevels. `systemctl` controls everything.

## 2. Targets

| Target | Purpose | Runlevel link |
|---|---|---|
| `poweroff.target` | Shut down | 0 |
| `rescue.target` | Single-user: root FS + local filesystems mounted, minimal services, **root password** required | 1 |
| `multi-user.target` | Text mode, networking, all normal services (servers) | 2, 3, 4 |
| `graphical.target` | multi-user + display manager (GUI) | 5 |
| `reboot.target` | Reboot | 6 |
| `emergency.target` | Most minimal: root mounted **read-only**, no other filesystems or services, root password required | — |
| `default.target` | Symlink to the target used at boot | — |

````bash
systemctl get-default                       # e.g. graphical.target
systemctl set-default multi-user.target     # persistent (relinks /etc/systemd/system/default.target)
systemctl isolate multi-user.target         # switch NOW (stops units not needed by it)
systemctl isolate graphical.target
systemctl rescue ; systemctl emergency      # shortcuts
systemctl list-units --type=target          # active targets
systemctl list-units --type=target --all
systemctl list-dependencies multi-user.target
ls -l /usr/lib/systemd/system/runlevel*.target   # compatibility symlinks
````

`isolate` works only for targets with `AllowIsolate=yes`; normal system targets have it.

### Choosing a target at boot (one time) **[RHCSA Core]**

1. At the GRUB menu, highlight the entry and press **`e`**.
2. Go to the line starting with **`linux`** and append, for example, `systemd.unit=multi-user.target` (or `rescue.target` / `emergency.target`). Short aliases: `rescue`/`single`/`1`, `emergency`, `3`, `5`.
3. Press **Ctrl+X** to boot. The change isn't saved.

> **RHEL 10:** `rescue` and `emergency` ask for **root's password**; with root disabled you may see "Cannot open access to console, the root account is locked". Use `systemd.unit=multi-user.target` (normal login) when possible, or the `rd.break` method in [boot recovery](boot-recovery.md).

### Legacy compatibility

`init 3`, `telinit 5` and `runlevel` still work as compatibility shims; `/etc/inittab` is no longer used. Use `systemctl` for everything.

## 3. Service Essentials (supplemented) **[RHCSA Core]**

| Command | Effect |
|---|---|
| `systemctl status sshd` | State, PID, recent log lines |
| `systemctl start` / `stop` / `restart` | Now only |
| `systemctl reload sshd` | Re-read config without restarting (if supported) |
| `systemctl enable sshd` | Start at boot (creates `.wants/` symlinks) |
| `systemctl disable sshd` | Don't start at boot |
| `systemctl enable --now httpd` | Enable **and** start (exam favorite) |
| `systemctl disable --now cups` | Disable and stop |
| `systemctl is-active` / `is-enabled` / `is-failed svc` | Quick checks (scripts) |
| `systemctl mask svc` / `unmask` | Make a unit impossible to start (link to `/dev/null`) |
| `systemctl list-units --type=service [--state=failed]` | Loaded/active services |
| `systemctl list-unit-files --type=service` | Enabled/disabled state of all services |
| `systemctl cat svc` / `systemctl show svc -p Restart` | Show unit file / properties |
| `systemctl edit svc` | Create a drop-in override (`/etc/systemd/system/svc.service.d/override.conf`) |
| `systemctl daemon-reload` | Reload unit files after editing them |
| `journalctl -u svc -e` / `-f` | Service logs (end / follow) |

**Unit file locations (precedence high → low):** `/etc/systemd/system/` (admin) → `/run/systemd/system/` (runtime) → `/usr/lib/systemd/system/` (packages; don't edit).

````bash
dnf install -y httpd
systemctl enable --now httpd
systemctl is-enabled httpd ; systemctl is-active httpd    # enabled / active
firewall-cmd --permanent --add-service=http ; firewall-cmd --reload   # network services need firewall access too
````

## 4. RHCSA Exam Focus **[RHCSA Core]**

- "Boot into multi-user by default": `systemctl set-default multi-user.target`, verify with `get-default`.
- "Service X must start at boot": `systemctl enable --now X` and verify `is-enabled` **and** `is-active`.
- Boot into a target once from GRUB with `systemd.unit=`.
- **Never** set `default.target` to `poweroff.target` or `reboot.target`.

## 5. Production Practices **[Production Practice]**

- Servers: `multi-user.target`; install a GUI only when needed.
- Customize services with `systemctl edit` drop-ins, never by editing `/usr/lib/systemd/system/*`.
- Check `systemctl --failed` after boots and changes.
- Mask services that must never run (e.g., conflicting firewall services).

## 6. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| System reboots endlessly | `default.target` → `reboot.target` | GRUB `e` → `systemd.unit=multi-user.target` → log in → `systemctl set-default multi-user.target` |
| Service enabled but not running | Started? Failed? | `systemctl status svc`, `journalctl -u svc -b` |
| `Failed to start … Unit is masked` | Masked | `systemctl unmask svc` |
| Changes to a unit file ignored | systemd caches unit files | `systemctl daemon-reload` |
| `Operation refused, unit may not be isolated` | Target lacks `AllowIsolate=yes` | Use a standard target |
| Rescue mode refuses access | Root account locked (RHEL 10) | `rd.break` method; or set a root password beforehand |

## 7. Interview Questions

| Question | Answer |
|---|---|
| Rescue vs emergency target? | Rescue mounts local filesystems and starts basic services; emergency mounts only root read-only, with almost nothing started. |
| `systemctl enable` vs `start`? | enable = at boot (symlinks); start = now. `--now` does both. |
| `isolate` vs `set-default`? | isolate switches immediately; set-default changes the boot default. |
| What does `mask` do? | Links the unit to `/dev/null` so it can't be started, even as a dependency. |
| Why `daemon-reload`? | systemd re-reads unit files only when told to. |

## 8. Course Corrections

| Course | Correction |
|---|---|
| "Runlevel 2 = multi-user, no network" | On RHEL, runlevels 2/3/4 all map to `multi-user.target` |
| Boot-loop fix via `rescue.target` / `emergency.target` | Needs root's password (locked by default on RHEL 10); `systemd.unit=multi-user.target` is simpler |
| "Find the line starting with linux or linux16" | RHEL 10 uses `linux`; `linux16` was BIOS-era |
| Chroot from live media to fix `default.target` | Works, but the GRUB override is faster |

## 9. Quick Revision

````bash
systemctl get-default | set-default multi-user.target | isolate graphical.target | rescue | emergency
GRUB: e → linux … systemd.unit=multi-user.target → Ctrl+X
systemctl status|start|stop|restart|reload|enable|disable [--now] svc | is-active | is-enabled | mask | unmask
systemctl edit svc ; daemon-reload ; --failed ; journalctl -u svc
