# 055 · Kernel Modules and Kernel Parameters (sysctl)

> **You need first:** [054 · GRUB and kernel packages](054-grub-and-kernel-packages.md)
> **Next:** [056 · tuned profiles](056-tuned-profiles.md)

---

## What it is

- A **kernel module** is a piece of kernel code (usually a **driver**, the code that operates a piece of hardware, or a feature such as a filesystem or firewall helper) that can be **loaded into the running kernel and removed** without rebooting. Files end in `.ko` ("kernel object"), usually compressed as `.ko.xz`, and live in `/lib/modules/$(uname -r)/`.
- **Kernel parameters** come in two kinds:
  1. **Boot-time arguments** on the kernel command line (topic 054).
  2. **Runtime tunables**: hundreds of settings under **`/proc/sys/`**, read and changed with **`sysctl`**, for example `vm.swappiness` (topic 050) or `net.ipv4.ip_forward`.

## Why it exists

- **Modules:** the kernel would be huge if every driver for every possible device were built in. Modules let it load only what this machine needs, add support for new hardware without rebuilding, and unload buggy or unwanted drivers.
- **sysctl:** the kernel's defaults suit a typical machine. Real workloads need tuning: a router must forward packets, a busy database wants different memory behaviour, a container host needs specific network settings, and security baselines restrict features. sysctl changes these **live**, with no reboot.

## Analogy

The kernel is a **power drill**. Modules are **interchangeable drill bits and attachments**: snap one on when you need it, take it off when you don't. sysctl settings are the **dials on the drill** (speed, torque, direction) that you can turn while it's running.

## How it works inside

### Modules

- When hardware appears, the kernel announces it. **udev** (topic 046) matches the device's ID against `modules.alias` and runs `modprobe` to load the right driver automatically. That's why you rarely load modules by hand.
- **`modprobe`** reads `modules.dep` (built by `depmod`) and loads the module's **dependencies first**. **`insmod`** loads one file and nothing else, so it fails with `Unknown symbol` if a dependency is missing.
- Loading means the kernel links the module's code into itself: a bug in a module can crash the whole machine (Linux is monolithic, topic 001).
- **Secure Boot:** only **signed** modules are accepted (`Key was rejected by service` otherwise). Third-party drivers must be signed with a key you've enrolled (MOK, topic 053).
- Modules needed **to reach the root filesystem** (storage, LVM, encryption drivers) must also be inside the **initramfs**. Changing their options or blacklisting them requires rebuilding it (`dracut -f`).

### sysctl

- Every file under `/proc/sys/` is one tunable. The dotted name maps to the path: `net.ipv4.ip_forward` ⇔ `/proc/sys/net/ipv4/ip_forward`. Reading the file shows the value; writing it changes the kernel **immediately**, and the change is **lost at reboot**.
- At boot, `systemd-sysctl.service` applies every file in `/usr/lib/sysctl.d/`, `/run/sysctl.d/` and **`/etc/sysctl.d/`** (plus `/etc/sysctl.conf`), sorted by file name. **Later files win.** A file in `/etc/sysctl.d/` overrides one with the **same name** in `/usr/lib/sysctl.d/`.
- **tuned** profiles (topic 056) can also set sysctl values. Keep each value in **one** place to avoid confusion.

## Commands

### See what's loaded

```bash
lsmod | head -5
```
```
Module                  Size  Used by
nft_fib_inet           12288  1
nf_conntrack          196608  4 nft_ct,nf_nat,nft_chain_nat,...
xfs                  2617344  2
virtio_net            110592  0
```
- `Size` = memory used. `Used by` = a reference count, then the modules that depend on it. A module that's in use can't be unloaded.

```bash
modinfo xfs | head -8
```
```
filename:       /lib/modules/6.12.0-55.el10.x86_64/kernel/fs/xfs/xfs.ko.xz
license:        GPL
description:    SGI XFS with ACLs, security attributes, realtime, quota, no debug enabled
alias:          fs-xfs
depends:        libcrc32c
retpoline:      Y
intree:         Y
signer:         Red Hat Enterprise Linux kernel signing key
```
- `depends:` = what must load first. `signer:` = who signed it (needed for Secure Boot). `intree: Y` = part of the official kernel source.

```bash
modinfo -p bonding         # the parameters a module accepts
```

### Load and unload

```bash
sudo modprobe --show-depends nf_conntrack_ftp
sudo modprobe nf_conntrack_ftp          # loads its dependencies too
lsmod | grep conntrack_ftp
sudo modprobe -r nf_conntrack_ftp       # unload (and now-unused dependencies)
```
```
insmod /lib/modules/6.12.0-55.el10.x86_64/kernel/net/netfilter/nf_conntrack.ko.xz
insmod /lib/modules/6.12.0-55.el10.x86_64/kernel/net/netfilter/nf_conntrack_ftp.ko.xz
```

| Command | Purpose |
|---|---|
| `lsmod` | List loaded modules |
| `modinfo MOD` | Details: file, description, signer, dependencies, parameters |
| `modprobe MOD` / `modprobe -r MOD` | Load / unload, with dependencies |
| `insmod FILE.ko` / `rmmod MOD` | Load one file / unload one module (no dependency handling) |
| `depmod -a` | Rebuild the dependency and alias lists after adding modules |

### Make module settings permanent

| Goal | File |
|---|---|
| Load a module at every boot | `/etc/modules-load.d/<name>.conf` (one module name per line) |
| Set a module parameter | `/etc/modprobe.d/<name>.conf` → `options MOD param=value` |
| Stop automatic loading | `/etc/modprobe.d/<name>.conf` → `blacklist MOD` |
| Stop it loading **at all** | Also add `install MOD /bin/false` |

```bash
echo br_netfilter | sudo tee /etc/modules-load.d/k8s.conf           # Kubernetes nodes need this
echo 'options bonding max_bonds=2' | sudo tee /etc/modprobe.d/bonding.conf
cat /sys/module/bonding/parameters/max_bonds                         # a loaded module's current value

sudo tee /etc/modprobe.d/blacklist-usb-storage.conf <<'EOF'
blacklist usb_storage
install usb_storage /bin/false
EOF
sudo dracut -f            # only needed if the module is also in the initramfs
```
- `blacklist` alone only stops **automatic** loading by alias; another module or a manual `modprobe` can still pull it in. `install … /bin/false` blocks everything.
- At boot you can also blacklist with the kernel arguments `modprobe.blacklist=MOD` or `rd.driver.blacklist=MOD` (rescue situations).

**Hardening switch:** `echo 1 > /proc/sys/kernel/modules_disabled` blocks **all** module loading and unloading **until the next reboot**. It can't be undone without rebooting.

### sysctl: read and change

```bash
sysctl net.ipv4.ip_forward
cat /proc/sys/net/ipv4/ip_forward
sudo sysctl -w net.ipv4.ip_forward=1
```
```
net.ipv4.ip_forward = 0
0
net.ipv4.ip_forward = 1
```
- `ip_forward=1` makes the machine pass network packets between its interfaces, acting as a **router** (Part 8). Container hosts and Kubernetes nodes need this.

```bash
sysctl -a 2>/dev/null | wc -l ; sysctl -a 2>/dev/null | grep -E '^vm\.(swappiness|dirty_ratio)'
```
```
1092
vm.dirty_ratio = 20
vm.swappiness = 30
```

### Make sysctl values permanent

```bash
sudo tee /etc/sysctl.d/90-k8s.conf <<'EOF'
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sudo sysctl --system
```
```
* Applying /usr/lib/sysctl.d/10-default-yama-scope.conf ...
* Applying /usr/lib/sysctl.d/50-default.conf ...
* Applying /etc/sysctl.d/90-k8s.conf ...
net.ipv4.ip_forward = 1
...
```
- `--system` loads every file in order and prints each one, so you can see which file set which value. `sysctl -p FILE` loads one file.
- The `net.bridge.*` keys only exist once `br_netfilter` is loaded, which is why the module file and the sysctl file go together.

| Useful tunable | Meaning |
|---|---|
| `net.ipv4.ip_forward` | 1 = route packets between interfaces |
| `net.ipv4.conf.all.rp_filter` | Reverse-path filtering: drop packets with spoofed source addresses |
| `vm.swappiness` | Swap vs cache balance (topic 050) |
| `vm.dirty_ratio`, `vm.dirty_background_ratio` | When cached writes are flushed to disk (topic 094) |
| `fs.file-max` | System-wide maximum number of open files |
| `kernel.pid_max` | Highest PID number (limits the number of processes) |
| `net.core.somaxconn` | Max queue of pending connections per listening socket (topic 095) |
| `kernel.dmesg_restrict` | Only privileged users may read `dmesg` |

### Shared libraries (user-space "modules")

| | Static library (`.a`) | Shared library (`.so`) |
|---|---|---|
| Linked | Into the program at build time | At run time by the dynamic loader `ld.so` (topic 001) |
| Where | — | `/usr/lib64` on 64-bit RHEL (`/usr/lib/x86_64-linux-gnu` on Ubuntu) |
| Tools | — | `ldd PROGRAM`, `ldconfig -p`, extra paths in `/etc/ld.so.conf.d/` + `ldconfig` |

### Try it
1. `lsmod | wc -l`, then `modinfo` a couple of modules and read their dependencies and signer.
2. Load `nf_conntrack_ftp` with modprobe, see its dependencies in `lsmod`, then unload it.
3. Blacklist a harmless module (for example `pcspkr`, the PC speaker), reboot, and confirm it's not loaded.
4. Set `net.ipv4.ip_forward=1` with `-w`, reboot (gone), then make it permanent in `/etc/sysctl.d/`.

## Where you'll use it

- **Kubernetes node prep:** load `overlay` and `br_netfilter` via `/etc/modules-load.d/`; set `ip_forward` and `bridge-nf-call-iptables` via `/etc/sysctl.d/`. These are in every kubeadm guide.
- **Performance tuning:** network buffers, `somaxconn`, dirty-page ratios for databases, `vm.max_map_count` for Elasticsearch.
- **Security hardening (CIS/STIG):** disable unused filesystems and USB storage (`install … /bin/false`); restrict `dmesg` and `ptrace`; turn on reverse-path filtering.
- **Hardware support:** extra drivers from `kernel-modules-extra`; vendor drivers that must be signed under Secure Boot.
- **Containers:** sysctls in `net.*` can be set per container or pod (namespaced); `vm.*` and most `kernel.*` are host-wide.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `modprobe: FATAL: Module X not found` | Not installed for this kernel | `dnf install kernel-modules-extra`; check the name with `modinfo` |
| `insmod: … Unknown symbol in module` | A dependency isn't loaded | Use `modprobe` |
| `rmmod: ERROR: Module X is in use` | Something still uses it | `lsmod` (Used by); stop the user or unload dependents first |
| `could not insert … Operation not permitted` | Not root, or `modules_disabled=1` | Use root; reboot if disabled |
| `Key was rejected by service` | Secure Boot and an unsigned module | Sign it and enrol the key with `mokutil` |
| A blacklisted module still loads | `blacklist` only stops alias autoloading, or it's in the initramfs | Add `install MOD /bin/false`; `dracut -f` |
| `sysctl: cannot stat /proc/sys/net/bridge/…` | The module providing that key isn't loaded | Load it (`br_netfilter`) first |
| A sysctl value reverts after reboot | It was only set with `-w` | Put it in `/etc/sysctl.d/*.conf` |
| A sysctl value differs from your file | Another file sorts later, or tuned sets it | `sysctl --system` output; `tuned-adm active` |

## Quick recap

- Modules: `lsmod`, `modinfo`, `modprobe [-r]` (with dependencies) vs `insmod`/`rmmod`. udev loads most automatically.
- Permanent: `/etc/modules-load.d/` (load at boot), `/etc/modprobe.d/` (`options`, `blacklist`, `install MOD /bin/false`); `dracut -f` if it's in the initramfs.
- sysctl: `/proc/sys/a/b/c` = `a.b.c`; `sysctl -w` (now) vs a file in `/etc/sysctl.d/` + `sysctl --system` (permanent, later files win).
- Secure Boot requires signed modules.

**Interview questions**

1. *`modprobe` vs `insmod`?* `modprobe` finds the module by name under `/lib/modules` and loads its dependencies first; `insmod` loads one `.ko` file by path with no dependency handling.
2. *How do you make a sysctl change survive a reboot?* Put `key = value` in a file under `/etc/sysctl.d/` and apply it with `sysctl --system` (`sysctl -w` alone is lost at reboot).
3. *How do you stop a kernel module from ever loading?* In `/etc/modprobe.d/`, add `blacklist MOD` and `install MOD /bin/false`, and rebuild the initramfs if the module is included there.
