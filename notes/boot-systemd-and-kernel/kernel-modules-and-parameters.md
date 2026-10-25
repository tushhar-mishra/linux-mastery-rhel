# Kernel Modules & Kernel Parameters (sysctl)

> **[Production Practice]** (no named RHEL 10 objective; underpins drivers, networking, tuning)
> **Related:** [GRUB2 & kernel arguments](grub2-and-kernel-management.md) · [Boot process](boot-process.md) · [Swap (vm.swappiness)](../storage-and-filesystems/swap.md) · [Kernel compilation](kernel-compilation.md)

## 1. Overview

- **Kernel modules** (`.ko`, usually compressed `.ko.xz`) are drivers and features loaded into the running kernel on demand. They live in `/lib/modules/$(uname -r)/`. udev auto-loads most of them when hardware appears.
- **Kernel parameters** come in two kinds:
  1. **Boot-time arguments** on the kernel command line (see [GRUB2 & kernel arguments](grub2-and-kernel-management.md)).
  2. **Runtime tunables** under `/proc/sys/`, managed with **`sysctl`**.

## 2. Module Commands

| Command | Purpose |
|---|---|
| `lsmod` | Loaded modules: Module, Size (bytes in memory), Used by (reference count + dependents) |
| `modinfo <mod>` | File path, description, license, signer, `depends:`, parameters |
| `modprobe <mod>` | Load **with dependencies** (from `modules.dep`) |
| `modprobe -r <mod>` | Unload with now-unused dependencies |
| `modprobe --show-depends <mod>` | Show what would be loaded |
| `insmod /path/mod.ko` | Load one file; **no dependency handling** |
| `rmmod <mod>` | Unload one module |
| `depmod -a` | Rebuild `modules.dep`/`modules.alias` after adding modules |

````bash
lsmod | grep -w xfs
modinfo -F filename xfs ; modinfo -F depends nf_conntrack_ftp
modprobe nf_conntrack_ftp          # also loads nf_conntrack, nf_defrag_ipv4/ipv6
lsmod | grep nf_conntrack
modprobe -r nf_conntrack_ftp
````

`insmod` fails with `Unknown symbol in module` when a dependency isn't loaded, which is why you normally use `modprobe`.

## 3. Persistence & Configuration

| Goal | File |
|---|---|
| Load at boot | `/etc/modules-load.d/<name>.conf` (one module per line) |
| Set module parameters | `/etc/modprobe.d/<name>.conf` → `options <mod> param=value` |
| Prevent automatic loading | `/etc/modprobe.d/<name>.conf` → `blacklist <mod>` |
| Prevent loading **entirely** | add `install <mod> /bin/false` |

````bash
echo nf_conntrack > /etc/modules-load.d/conntrack.conf
echo 'options bonding max_bonds=2' > /etc/modprobe.d/bonding.conf
modinfo -p bonding                        # available parameters
cat /sys/module/bonding/parameters/max_bonds   # current value of a loaded module

cat > /etc/modprobe.d/blacklist-firewire.conf <<'EOF'
blacklist firewire_ohci
install firewire_ohci /bin/false
EOF
dracut -f      # if the module is in the initramfs (early boot)
````

**Boot-time alternatives:** kernel arguments `modprobe.blacklist=mod` and `rd.driver.blacklist=mod`.

> ⚠️ `echo 1 > /proc/sys/kernel/modules_disabled` blocks **all** further module loading and unloading **until reboot** (it can't be turned back off). It's a hardening measure, not a toggle.

**Secure Boot:** unsigned or self-signed modules fail with `Key was rejected by service` unless the signing key is enrolled with `mokutil`.

## 4. Runtime Kernel Parameters (`sysctl`)

````bash
sysctl -a | less                        # all tunables (= files under /proc/sys)
sysctl net.ipv4.ip_forward              # read
sysctl -w net.ipv4.ip_forward=1         # set now (lost at reboot)
cat /proc/sys/net/ipv4/ip_forward       # same value, file view
````

**Persistent:**

````bash
cat > /etc/sysctl.d/99-custom.conf <<'EOF'
net.ipv4.ip_forward = 1
vm.swappiness = 10
net.ipv4.conf.all.rp_filter = 1
EOF
sysctl --system                         # apply all sysctl files now
sysctl -p /etc/sysctl.d/99-custom.conf  # or just this one
````

- Files in `/etc/sysctl.d/` override same-named files in `/usr/lib/sysctl.d/`. They're applied in lexical order, so later values win.
- tuned profiles may also set values (e.g., `vm.swappiness`); check with `tuned-adm active` ([tuned](../containers-and-virtualization/tuned-profiles.md)).

| Example tunable | Meaning |
|---|---|
| `net.ipv4.ip_forward` | 1 = route packets between interfaces (router/NAT/container hosts) |
| `net.ipv4.conf.all.rp_filter` | Reverse-path filtering (anti-spoofing) |
| `vm.swappiness` | Swap vs page-cache reclaim balance |
| `kernel.pid_max`, `fs.file-max` | Process / open-file limits |
| `kernel.dmesg_restrict` | Restrict `dmesg` to privileged users |

## 5. Shared Libraries (context)

| | Static (`.a`) | Shared (`.so`) |
|---|---|---|
| Linked | At build time, copied into the binary | At run time by `ld.so` |
| Location (x86_64 RHEL) | — | `/usr/lib64` |
| Tools | — | `ldd /usr/bin/ls`, `ldconfig -p`, `/etc/ld.so.conf.d/` |

## 6. Custom "Hello" Module **[Advanced/Optional]**

````c
/* hello.c */
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>

static int __init hello_init(void) { pr_info("Hello, kernel!\n"); return 0; }
static void __exit hello_exit(void) { pr_info("Goodbye, kernel!\n"); }

module_init(hello_init);
module_exit(hello_exit);
MODULE_LICENSE("GPL");                 /* non-GPL strings taint the kernel and block GPL-only symbols */
MODULE_AUTHOR("Your Name");
MODULE_DESCRIPTION("Simple Hello World Module");
````

````make
# Makefile — recipe lines must start with a TAB
obj-m += hello.o
all:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules
clean:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean
````

````bash
dnf group install -y "Development Tools" ; dnf install -y kernel-devel-$(uname -r)
make ; insmod hello.ko ; dmesg | tail -2 ; lsmod | grep hello ; rmmod hello
````

`kernel-devel` must match the **running** kernel (`uname -r`). With Secure Boot on, sign the module and enroll the key, or loading fails.

## 7. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `modprobe: FATAL: Module X not found` | Not installed for this kernel | `dnf install kernel-modules-extra`; `modinfo X` |
| `insmod: … Unknown symbol in module` | Missing dependency | Use `modprobe` |
| `rmmod: ERROR: Module X is in use` | Used by others or in use | `lsmod` → unload dependents; stop the user of the module |
| `could not insert … Operation not permitted` | `modules_disabled=1`, or not root | Reboot (if disabled); use root |
| `Key was rejected by service` | Secure Boot + unsigned module | Sign it and enroll the key (`mokutil`) |
| Blacklisted module still loads | `blacklist` only stops alias autoload; or it's in the initramfs | `install X /bin/false`; `dracut -f` |
| sysctl value reverts after reboot | Set only with `-w` | Put it in `/etc/sysctl.d/*.conf` |

## 8. Interview Questions

| Question | Answer |
|---|---|
| `modprobe` vs `insmod`? | modprobe resolves dependencies via modules.dep and searches `/lib/modules`; insmod loads one file by path. |
| How do you load a module at every boot? | `/etc/modules-load.d/<name>.conf`. |
| How do you stop a module from ever loading? | `blacklist` plus `install <mod> /bin/false` in `/etc/modprobe.d/`; rebuild the initramfs if needed. |
| How do you make a sysctl persistent? | A file in `/etc/sysctl.d/`, then `sysctl --system`. |
| What's in `/proc/sys`? | Runtime kernel tunables, one file per parameter. |

## 9. Quick Revision

````bash
lsmod | modinfo [-p|-F] M | modprobe [-r] M | insmod F.ko | rmmod M | depmod -a | modprobe --show-depends M
/etc/modules-load.d/*.conf (boot) · /etc/modprobe.d/*.conf: options / blacklist / install M /bin/false · dracut -f
sysctl -a | sysctl KEY | sysctl -w KEY=V | /etc/sysctl.d/99-x.conf + sysctl --system · /proc/sys
````

## 10. Cross-References

- [GRUB2 & kernel arguments](grub2-and-kernel-management.md)
- [Boot process](boot-process.md)
- [Swap (vm.swappiness)](../storage-and-filesystems/swap.md)
- [Kernel compilation](kernel-compilation.md)
