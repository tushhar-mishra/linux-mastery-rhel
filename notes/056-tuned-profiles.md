# 056 · tuned: Workload Tuning Profiles

> **You need first:** [055 · Kernel modules and sysctl](055-kernel-modules-and-sysctl.md)
> **Next:** [057 · Boot recovery](057-boot-recovery.md)

---

## What it is

**tuned** is a service that applies **tuning profiles**: ready-made bundles of settings (sysctl values, CPU power settings, disk settings, transparent huge pages, and so on) that suit a type of workload: maximum throughput, low latency, power saving, running as a VM, hosting VMs.

- **`tuned-adm`** is the command to list, choose and check profiles.
- It's installed and running by default on RHEL. On Ubuntu it's available (`apt install tuned`) but not used by default.

## Why it exists

Tuning a server by hand means knowing dozens of kernel knobs and how they interact. tuned packages expert-chosen combinations: one command (`tuned-adm profile throughput-performance`) applies them consistently, they survive reboots, and you can check that nothing has drifted (`tuned-adm verify`).

## Analogy

tuned is the **driving-mode switch in a modern car**: Eco, Comfort, Sport. One switch changes engine mapping, gearbox timing and suspension together. You can also create your own mode based on "Sport" with softer suspension (a custom profile using `include=`).

## How it works inside

- The `tuned` daemon reads the active profile's `tuned.conf` and, through **plugins** (`[sysctl]`, `[cpu]`, `[disk]`, `[vm]`, `[script]`…), applies each setting: it writes the sysctl values, sets the CPU frequency governor (the policy that decides how fast the CPU clocks), sets disk readahead, and so on.
- Profiles can **include** others: a custom profile inherits a base and overrides only what you change. Several profiles can be active together, and later ones win.
- **Static mode** (default): settings are applied when the profile is activated or tuned starts. **Dynamic mode** (off by default, `dynamic_tuning = 0` in `/etc/tuned/tuned-main.conf`) adjusts some settings as load changes.
- **`recommend`** looks at the machine (is it a VM? which hypervisor? a laptop?) and suggests a profile. On a VM that's usually `virtual-guest`; on bare-metal servers `throughput-performance`.
- The choice is saved in `/etc/tuned/active_profile` and survives reboots.

### Common profiles

| Profile | For |
|---|---|
| `balanced` | A middle ground (typical desktop default) |
| `powersave` | Lowest power use |
| `throughput-performance` | Server throughput (typical bare-metal server default) |
| `latency-performance` | Low latency: keeps the CPU from sleeping |
| `network-latency` / `network-throughput` | Network-focused versions |
| `virtual-guest` | RHEL running **as a VM** (includes `vm.swappiness=30`) |
| `virtual-host` | A machine **hosting** KVM VMs |
| `hpc-compute`, `accelerator-performance`, `aws`, `optimize-serial-console` | Specialised |

### Files

| Path | Contents |
|---|---|
| `/usr/lib/tuned/profiles/` (older releases: `/usr/lib/tuned/<name>/`) | Shipped profiles: don't edit |
| `/etc/tuned/profiles/<name>/tuned.conf` (older: `/etc/tuned/<name>/`) | **Your** custom profiles (they win over shipped ones) |
| `/etc/tuned/active_profile`, `/etc/tuned/profile_mode` | The current profile; `auto` (recommended) or `manual` |
| `/var/log/tuned/tuned.log` | Log |

## Commands

```bash
sudo systemctl enable --now tuned
tuned-adm active
tuned-adm recommend
```
```
Current active profile: virtual-guest
virtual-guest
```

```bash
tuned-adm list
```
```
Available profiles:
- accelerator-performance     - Throughput performance based tuning with disabled higher latency STOP states
- balanced                    - General non-specialized tuned profile
- latency-performance         - Optimize for deterministic performance at the cost of increased power consumption
- powersave                   - Optimize for low power consumption
- throughput-performance      - Broadly applicable tuning that provides excellent performance across a variety of common server workloads
- virtual-guest               - Optimize for running inside a virtual guest
- virtual-host                - Optimize for running KVM guests
...
Current active profile: virtual-guest
```

```bash
sudo tuned-adm profile throughput-performance      # switch (permanent)
sudo tuned-adm profile virtual-guest network-latency   # combine several (later ones override)
sudo tuned-adm auto_profile                        # go back to the recommended profile
tuned-adm profile_info virtual-guest
sudo tuned-adm verify
```
```
Verification succeeded, current system settings match the preset profile.
See TuneD log file ('/var/log/tuned/tuned.log') for details.
```
- `verify` reports any setting that drifted (for example, someone changed a sysctl by hand).

```bash
sudo tuned-adm off                                 # stop all tuning
```

### A custom profile

```bash
sudo mkdir -p /etc/tuned/profiles/db-tuned
sudo tee /etc/tuned/profiles/db-tuned/tuned.conf <<'EOF'
[main]
summary=Database server: throughput-performance with less swapping
include=throughput-performance

[sysctl]
vm.swappiness=10
vm.dirty_ratio=10
vm.dirty_background_ratio=5

[vm]
transparent_hugepages=never

[disk]
readahead=4096
EOF
tuned-adm list | grep db-tuned
sudo tuned-adm profile db-tuned
sysctl vm.swappiness ; cat /sys/kernel/mm/transparent_hugepage/enabled
```
```
- db-tuned                    - Database server: throughput-performance with less swapping
vm.swappiness = 10
always madvise [never]
```

| Section | What goes there |
|---|---|
| `[main]` | `summary=`, `include=` (inherit a base profile) |
| `[sysctl]` | Any sysctl key (for example `vm.swappiness`) |
| `[cpu]` | `governor`, `energy_perf_bias`, `min_perf_pct` |
| `[vm]` | `transparent_hugepages=always\|madvise\|never` (**THP**: transparent huge pages; topic 093) |
| `[disk]` | `readahead`, I/O scheduler (`elevator`), power settings |
| `[script]` | Run your own script when the profile starts or stops |

Reference: `man tuned.conf`, `man tuned-profiles`.

### Try it
1. Run `tuned-adm recommend` and `tuned-adm active` on your VM. Are they the same?
2. Switch to `throughput-performance`, check `sysctl vm.swappiness`, then switch back with `auto_profile`.
3. Build the `db-tuned` profile, activate it, and confirm the values. Change `vm.swappiness` by hand with `sysctl -w`, then run `tuned-adm verify`.

## Where you'll use it

- **New servers:** apply the recommended profile (or a vendor-recommended one: database and SAP vendors publish tuned profiles).
- **Latency-sensitive workloads** (trading, real-time, network functions): `latency-performance` / `network-latency`.
- **VM fleets:** `virtual-guest` on guests, `virtual-host` on hypervisors.
- **Standardisation:** ship a custom profile with configuration management, so every host is tuned identically, and `verify` catches drift.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| "No current active profile" | `tuned-adm off`, or the service is stopped | `systemctl enable --now tuned`; `tuned-adm profile X` |
| A custom profile isn't listed | Wrong directory or file name (must be `tuned.conf`) | Check the path; `tuned-adm list` |
| `verify` reports `expected 10, got 30` | Something else overrides it (a `/etc/sysctl.d/` file, a script) | Keep each setting in one place; read `tuned.log` |
| The CPU governor setting does nothing | Many VMs have no CPU frequency control | Expected inside VMs |
| Swappiness isn't the kernel default of 60 | The active profile sets it (virtual-guest = 30) | Intended; override in a custom profile |

## Quick recap

- tuned applies **profiles** (sysctl, CPU, disk, THP…) for a workload; they persist across reboots.
- `tuned-adm list | active | recommend | profile NAME | auto_profile | verify | off`.
- Custom profiles: `/etc/tuned/profiles/NAME/tuned.conf` with `include=BASE` plus overrides.
- Keep each setting in either tuned or `/etc/sysctl.d/`, not both.

**Interview questions**

1. *What does tuned do?* It applies workload-specific tuning profiles (kernel sysctls, CPU power, disk and memory settings) consistently and persistently, and can verify the system still matches.
2. *How do you choose a profile?* `tuned-adm recommend` suggests one for the hardware or virtualisation type; apply it with `tuned-adm profile NAME` and check with `tuned-adm active`.
3. *How do you customise a profile without copying it?* Create `/etc/tuned/profiles/NAME/tuned.conf` with `include=base-profile` and only the settings you want to change.
