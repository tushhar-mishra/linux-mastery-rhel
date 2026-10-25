# Tuning Profiles with tuned

> **Sessions:** S83 · **Objective:** *Manage tuning profiles* **[RHCSA Core]**
> **Related:** [Kernel parameters (sysctl)](../boot-systemd-and-kernel/kernel-modules-and-parameters.md) · [Swap (swappiness)](../storage-and-filesystems/swap.md) · [Resource monitoring](../processes-and-resource-management/system-resource-monitoring.md) · [systemd services](../boot-systemd-and-kernel/systemd-targets-and-services.md)

## 1. Overview

**tuned** is a daemon that applies **tuning profiles**: coordinated sets of sysctl values, CPU governor/energy settings, disk, scheduler and other options for a workload (throughput, latency, power saving, virtual guest …). `tuned-adm` manages it. It's installed and enabled by default on RHEL.

| Mode | Behavior |
|---|---|
| **Static** (default) | Settings applied when tuned starts or a profile is activated |
| **Dynamic** | tuned monitors load and adjusts some settings. **Disabled by default** (`dynamic_tuning = 0` in `/etc/tuned/tuned-main.conf`) |

## 2. Service & Files

````bash
dnf install -y tuned                  # usually already installed
systemctl enable --now tuned
systemctl status tuned
````

| Path | Content |
|---|---|
| `/usr/lib/tuned/profiles/` (older releases: `/usr/lib/tuned/<name>/`) | Shipped profiles (don't edit) |
| `/etc/tuned/profiles/<name>/tuned.conf` (older: `/etc/tuned/<name>/`) | Your custom profiles (take precedence) |
| `/etc/tuned/active_profile`, `/etc/tuned/profile_mode` | Current profile; `auto` (recommended) or `manual` |
| `/etc/tuned/tuned-main.conf` | Daemon settings (dynamic tuning, intervals) |
| `/var/log/tuned/tuned.log` | Log |

## 3. tuned-adm **[RHCSA Core]**

````bash
tuned-adm list                          # available profiles + current one
tuned-adm active                        # Current active profile: virtual-guest
tuned-adm recommend                     # profile tuned suggests for this hardware/VM
tuned-adm profile throughput-performance   # switch (persistent across reboots)
tuned-adm profile virtual-guest powersave  # several profiles merged (later ones override)
tuned-adm auto_profile                  # return to the recommended profile (mode: auto)
tuned-adm profile_info virtual-guest    # description of a profile
tuned-adm verify                        # do current settings match the profile?
tuned-adm off                           # stop tuning (no profile active)
````

| Profile | Purpose |
|---|---|
| `balanced` | Default compromise between performance and power (typical for desktops) |
| `powersave` | Minimal power use |
| `throughput-performance` | Server throughput (typical bare-metal server default) |
| `latency-performance` | Low latency (CPU stays awake) |
| `network-latency` / `network-throughput` | Network-focused variants |
| `virtual-guest` | RHEL running as a VM (typical VM default; includes swappiness 30) |
| `virtual-host` | KVM hosts |
| `accelerator-performance`, `hpc-compute`, `desktop`, `optimize-serial-console`, `aws` | Specialized |

## 4. Custom Profile

````bash
mkdir -p /etc/tuned/profiles/my-performance
cat > /etc/tuned/profiles/my-performance/tuned.conf <<'EOF'
[main]
summary=Custom high-performance profile based on throughput-performance
include=throughput-performance

[cpu]
governor=performance

[sysctl]
vm.swappiness=10
vm.dirty_ratio=10
vm.dirty_background_ratio=5
kernel.numa_balancing=0

[disk]
readahead=4096
EOF
tuned-adm list | grep my-performance
tuned-adm profile my-performance ; tuned-adm active ; tuned-adm verify
sysctl vm.swappiness kernel.numa_balancing          # confirm values
````

| Section | Notes |
|---|---|
| `[main]` | `summary`, `include=` (inherit a base profile; override only what you change) |
| `[cpu]` | `governor`, `energy_perf_bias`, `min_perf_pct` (Intel pstate) |
| `[sysctl]` | Any sysctl key (e.g., **`vm.swappiness`** belongs here, not under `[vm]`) |
| `[vm]` | `transparent_hugepages=always\|madvise\|never` |
| `[disk]` | `readahead`, `elevator`, APM/spindown options |
| `[script]` | Run a custom script on start/stop **[Advanced]** |

Full option reference: `man tuned.conf`, `man tuned-profiles`.

## 5. RHCSA Exam Focus **[RHCSA Core]**

````bash
systemctl enable --now tuned
tuned-adm recommend                  # e.g. virtual-guest
tuned-adm profile virtual-guest      # set the profile the task asks for (often "the recommended one")
tuned-adm active                     # verify; it persists across reboots
````

## 6. Production Practices **[Production Practice]**

- Start from the recommended profile; customize with `include=` instead of copying whole profiles.
- Measure before and after (latency, throughput, `sar`) and change one variable at a time.
- Keep sysctl settings in **either** tuned profiles **or** `/etc/sysctl.d/`, not both, to avoid confusion about which one wins.

## 7. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `tuned-adm active`: "No current active profile" | `tuned-adm off` or service stopped | `systemctl enable --now tuned`; `tuned-adm profile X` |
| Custom profile not listed | Wrong path/filename (`tuned.conf`) | Check the directory; `tuned-adm list` |
| `verify` reports `expected 0, got 1` | Another mechanism overrides the value (sysctl.d, script) or unsupported hardware option | Find the conflicting setting; check `tuned.log` |
| Governor setting has no effect | VM without cpufreq | Expected in many VMs |
| Swappiness differs from the kernel default | Active profile sets it (e.g., virtual-guest = 30) | Intended; override in a custom profile |

## 8. Interview Questions

| Question | Answer |
|---|---|
| What does tuned do? | Applies workload-specific tuning profiles (sysctl, CPU, disk, power). |
| How do you find and apply the best profile? | `tuned-adm recommend` then `tuned-adm profile <name>`. |
| Static vs dynamic tuning? | Static applies once; dynamic adjusts with load (off by default). |
| How do you create a custom profile? | `/etc/tuned/profiles/NAME/tuned.conf` with `include=` + overrides. |

## 9. Course Corrections

| Course | Correction |
|---|---|
| Tuned "dynamically adjusts settings" by default | Dynamic tuning is disabled by default |
| `[vm] swappiness=10` | Use `[sysctl] vm.swappiness=10` |
| `sudo` for `tuned-adm active/list/recommend` | Not required (needed for changes) |
| "Fix verify mismatch with `sysctl -w`" | Find what overrides the setting; `sysctl -w` is only temporary |
| `systemctl restart tuned` to see a new profile | Not required; `tuned-adm list` reads profiles directly |

## 10. Quick Revision

````bash
systemctl enable --now tuned · tuned-adm list|active|recommend|profile NAME|auto_profile|profile_info|verify|off
custom: /etc/tuned/profiles/NAME/tuned.conf → [main] include= · [sysctl] · [cpu] · [vm] · [disk]
