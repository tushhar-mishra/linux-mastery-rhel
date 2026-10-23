# Compiling a Custom Kernel

> **Sessions:** S52 · **[Advanced/Optional]** · unsupported by Red Hat for production; useful for learning and kernel development
> **Related:** [GRUB2 & kernel management](grub2-and-kernel-management.md) · [Kernel modules & parameters](kernel-modules-and-parameters.md) · [Boot recovery](boot-recovery.md)

## 1. Overview

| | Packaged kernel (`dnf`) | Self-compiled kernel |
|---|---|---|
| Source | Red Hat, built and signed | kernel.org (or patched source) |
| Support | Fully supported, security errata | Unsupported; you maintain it |
| Secure Boot | Signed: boots normally | **Unsigned: won't boot** until signed with an enrolled key |
| Use | Production | Testing new features/drivers, learning, kernel development |

## 2. Preparation

```bash
uname -r ; rpm -q kernel                      # current kernels (keep them as fallback!)
# take a VM snapshot first
dnf group install -y "Development Tools"
dnf install -y ncurses-devel bc flex bison openssl-devel elfutils-libelf-devel dwarves perl
df -h /usr/src /boot                          # builds need ~20+ GB; /boot needs room for kernel + initramfs
```

## 3. Build & Install

```bash
cd /usr/src
curl -LO https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.15.8.tar.xz
tar -xf linux-6.15.8.tar.xz && cd linux-6.15.8

cp /boot/config-$(uname -r) .config     # start from the RHEL configuration
make olddefconfig                       # accept defaults for options new to this version
make menuconfig                         # optional: adjust features (ncurses UI)

make -j"$(nproc)"                       # compile kernel + modules (10–60+ min)
make modules_install                    # → /lib/modules/6.15.8/
make install                            # → /boot (vmlinuz, System.map, config) + initramfs + BLS entry via kernel-install
```

- If the RHEL config enables module signing with RHEL's keys, generate your own keys or disable those options before building.
- `make install` on RHEL runs `kernel-install`, which creates the initramfs and the BLS entry. `grub2-mkconfig` isn't required.

## 4. Boot & Verify

```bash
grubby --info=ALL | grep -E '^(index|kernel)'
grubby --set-default /boot/vmlinuz-6.15.8    # optional: make it default
reboot
uname -r                                     # 6.15.8
```

Keep the RHEL kernel as the default until the new one has proven itself; pick the custom kernel once from the GRUB menu first.

## 5. Secure Boot

With Secure Boot enabled, the firmware/shim refuses an unsigned kernel. Either:

- sign the kernel image (e.g., `pesign`) and its modules with your own key, and enroll that key with `mokutil --import` (confirm in MOK Manager at reboot); or
- test on a VM with Secure Boot disabled.

## 6. Removing a Custom Kernel

```bash
kernel-install remove 6.15.8          # removes its BLS entry and /boot files
rm -rf /lib/modules/6.15.8
grubby --default-kernel               # confirm a RHEL kernel is default
```

## 7. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Build stops: missing `pahole`/BTF errors | `dwarves` not installed | `dnf install dwarves` |
| `No rule to make target 'certs/rhel.pem'` | RHEL signing-key paths in config | Set `CONFIG_SYSTEM_TRUSTED_KEYS=""` (`scripts/config --set-str …`) |
| New kernel won't boot ("invalid signature") | Secure Boot | Sign + enroll key, or disable Secure Boot (lab) |
| Kernel panic: can't mount root | Missing storage/LVM drivers or initramfs | Boot the RHEL kernel; check config; rebuild initramfs with `dracut --kver 6.15.8` |
| `/boot` full | Large unstripped modules in initramfs | `make INSTALL_MOD_STRIP=1 modules_install`; remove old kernels |

## 8. Interview Questions

| Question | Answer |
|---|---|
| Why not compile kernels on production RHEL? | Loses Red Hat support, security errata, kABI guarantees and Secure Boot signing. |
| What does `make modules_install` do? | Installs `.ko` files into `/lib/modules/<version>/` and runs `depmod`. |
| How do you base a custom build on the distro config? | `cp /boot/config-$(uname -r) .config; make olddefconfig`. |

## 9. Course Corrections

| Course | Correction |
|---|---|
| `dnf groupinstall` | `dnf group install` |
| `cd linux-6.8` vs `linux-6.15.8` | Use the version you downloaded |
| `make menuconfig` from scratch | Start from `/boot/config-$(uname -r)` + `make olddefconfig` |
| Dependencies list | Add `dwarves` and `perl` |
| No Secure Boot mention | Unsigned custom kernels won't boot with Secure Boot on |
| `make install` "updates GRUB" | On RHEL it creates a BLS entry via `kernel-install` |
| Removal not covered | `kernel-install remove <ver>` + delete `/lib/modules/<ver>` |
| "Add as many CPU cores as possible (e.g. 24)" | `make -j"$(nproc)"` uses whatever is available |

## 10. Quick Revision

```bash
dnf group install "Development Tools" ; dnf install ncurses-devel bc flex bison openssl-devel elfutils-libelf-devel dwarves perl
tar xf linux-X.tar.xz ; cp /boot/config-$(uname -r) .config ; make olddefconfig ; make -j$(nproc)
make modules_install ; make install ; grubby --info=ALL ; reboot ; uname -r
remove: kernel-install remove X ; rm -rf /lib/modules/X · Secure Boot needs signing
