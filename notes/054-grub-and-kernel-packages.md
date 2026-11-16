# 054 · GRUB, Kernel Arguments and Kernel Packages

> **You need first:** [053 · The boot process](053-boot-process.md)
> **Next:** [055 · Kernel modules and sysctl](055-kernel-modules-and-sysctl.md)

---

## What it is

- **GRUB2** is the bootloader that shows the boot menu and starts a kernel (topic 053).
- **BLS** (Boot Loader Specification) is the layout RHEL uses: **one small text file per installed kernel** in `/boot/loader/entries/`. GRUB reads them with its `blscfg` command, so `grub.cfg` itself contains no per-kernel entries.
- **`grubby`** is RHEL's tool for changing boot entries: the default kernel and kernel arguments.
- **Kernel arguments** (the kernel command line) are settings passed to the kernel at boot: `root=`, `quiet`, `systemd.unit=…`.
- **Kernel packages:** each kernel version is installed **next to** the older ones (not upgraded in place), so you can always boot the previous one.

## Why it exists

- **Choosing a kernel:** if a new kernel breaks something (a driver, performance), boot the old one and make it the default.
- **Kernel arguments** change behaviour at boot: disable a feature, reserve crash-dump memory, boot into a rescue target, enable auditing early, tune security settings.
- **Keeping several kernels** is your safety net for every update.

## Analogy

GRUB is a **restaurant menu board**. Each BLS file is **one dish card** (which kernel, which initramfs, which instructions). `grubby` is the **manager rewriting dish cards**: "make dish 2 today's special" (default kernel), "add 'no salt' to every dish" (a kernel argument for all kernels). The restaurant keeps the last three versions of each recipe (installed kernels) in case the new one is bad.

## How it works inside

| File | Purpose |
|---|---|
| `/boot/loader/entries/<machine-id>-<ver>.conf` | One BLS entry per kernel: `title`, `linux`, `initrd`, `options` (its arguments) |
| `/boot/grub2/grub.cfg` | Main GRUB config, **generated**: never edit by hand |
| `/boot/efi/EFI/redhat/grub.cfg` | A small **stub** on UEFI that just points to `/boot/grub2/grub.cfg`. Don't overwrite it |
| `/boot/grub2/grubenv` | Saved state: which entry is the default (`saved_entry`) |
| `/etc/default/grub` | Settings for `grub2-mkconfig`: menu timeout, `GRUB_CMDLINE_LINUX` default arguments |
| `/etc/kernel/cmdline` | Arguments applied to **newly installed** kernels |

A BLS entry looks like this:
```
title Red Hat Enterprise Linux (6.12.0-55.el10.x86_64) 10.1 (Coughlan)
version 6.12.0-55.el10.x86_64
linux /vmlinuz-6.12.0-55.el10.x86_64
initrd /initramfs-6.12.0-55.el10.x86_64.img
options root=/dev/mapper/rhel-root ro crashkernel=… rd.lvm.lv=rhel/root rd.lvm.lv=rhel/swap rhgb quiet
grub_users $grub_users
grub_arg --unrestricted
grub_class rhel
```

**Installing a new kernel** (`dnf update kernel`): the package scripts build an initramfs for it (with dracut), write a new BLS entry, and make it the **default**. The old kernels stay. dnf keeps **3** by default (`installonly_limit=3` in `/etc/dnf/dnf.conf`) and removes the oldest beyond that, **never the running one**. The new kernel is used only after a **reboot**.

**Ubuntu:** no BLS and no grubby. Edit `/etc/default/grub`, then run `sudo update-grub`. Kernels are the `linux-image-*` packages, and `apt autoremove` cleans old ones.

## Commands

### The default kernel

```bash
sudo grubby --default-kernel
sudo grubby --info=ALL | grep -E '^(index|kernel|title)'
```
```
/boot/vmlinuz-6.12.0-55.el10.x86_64
index=0
kernel="/boot/vmlinuz-6.12.0-55.el10.x86_64"
title="Red Hat Enterprise Linux (6.12.0-55.el10.x86_64) 10.1 (Coughlan)"
index=1
kernel="/boot/vmlinuz-6.12.0-40.el10.x86_64"
title="Red Hat Enterprise Linux (6.12.0-40.el10.x86_64) 10.0 (Coughlan)"
index=2
kernel="/boot/vmlinuz-0-rescue-…"
title="Red Hat Enterprise Linux (0-rescue-…) 10.1 (Coughlan)"
```

```bash
sudo grubby --set-default /boot/vmlinuz-6.12.0-40.el10.x86_64     # roll back to the older kernel
sudo grub2-editenv list
```
```
The default is /boot/loader/entries/…-6.12.0-40.el10.x86_64.conf with index 1 and kernel /boot/vmlinuz-6.12.0-40.el10.x86_64
saved_entry=…-6.12.0-40.el10.x86_64
```

### Kernel arguments

```bash
cat /proc/cmdline                                           # what the RUNNING kernel got
sudo grubby --update-kernel=ALL --args="audit=1"            # add to ALL kernels (permanent)
sudo grubby --update-kernel=ALL --remove-args="rhgb quiet"  # show all boot messages
sudo grubby --info=DEFAULT | grep args
```
```
args="ro crashkernel=… rd.lvm.lv=rhel/root rd.lvm.lv=rhel/swap audit=1"
```
- Takes effect at the next boot; confirm with `cat /proc/cmdline` afterwards.

```bash
sudo grubby --update-kernel=/boot/vmlinuz-6.12.0-55.el10.x86_64 --args="systemd.unit=multi-user.target"
```
- For one specific kernel only.

**Global defaults instead:** edit `GRUB_CMDLINE_LINUX` in `/etc/default/grub`, then:
```bash
sudo grub2-mkconfig -o /boot/grub2/grub.cfg --update-bls-cmdline
```
- `--update-bls-cmdline` pushes the new arguments into the existing BLS entries. On RHEL 9/10, always write to `/boot/grub2/grub.cfg`, **never** to the ESP stub.

**For one boot only:** at the GRUB menu, highlight an entry, press **`e`**, edit the line starting with `linux`, then press **Ctrl+X** to boot. Nothing is saved, which is perfect for troubleshooting (topic 057).

| Common argument | Effect |
|---|---|
| `rhgb quiet` | Splash screen, fewer messages (RHEL default) |
| `systemd.unit=multi-user.target` / `rescue.target` / `emergency.target` | Boot into a specific target (topic 037) |
| `rd.break` | Stop inside the initramfs before switch-root (password reset, topic 057) |
| `init=/bin/bash` | Start a shell instead of systemd (last-resort recovery) |
| `enforcing=0` | SELinux permissive for this boot (topic 072) |
| `rd.lvm.lv=VG/LV` | LVs the initramfs activates |
| `crashkernel=…` | Memory reserved for crash dumps (kdump) |
| `fsck.mode=force fsck.repair=yes` | Force filesystem checks (topic 051) |
| `console=ttyS0,115200` | Send console output to a serial port (cloud serial consoles) |
| `mem=2G` | Limit usable RAM (testing) |

### GRUB settings (timeout and so on)

```bash
sudo vi /etc/default/grub        # e.g. GRUB_TIMEOUT=5
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
```

### Kernel packages

| Package | Contents |
|---|---|
| `kernel` | A meta-package (no files) that pulls in the parts below |
| `kernel-core` | The kernel image and a minimal set of modules |
| `kernel-modules-core` / `kernel-modules` | Core / common extra drivers |
| `kernel-modules-extra` | Rare drivers |
| `kernel-devel` | Headers and Makefiles to build extra modules (`/usr/src/kernels/<ver>`) |
| `kernel-headers` | Headers for building normal programs |
| `kernel-tools` | Tools like `cpupower`, `turbostat` |

```bash
rpm -q kernel
sudo dnf update kernel
sudo dnf --showduplicates list kernel
uname -r                                           # still the old one until you reboot
```
```
kernel-6.12.0-40.el10.x86_64
kernel-6.12.0-55.el10.x86_64
```

```bash
sudo dnf remove $(dnf repoquery --installonly --latest-limit=-2 -q)    # keep only the newest 2
```
- Check `uname -r` first, so you never remove the running kernel. dnf protects it anyway.

### Reinstalling the bootloader

| Firmware | Command |
|---|---|
| UEFI (Secure Boot friendly) | `sudo dnf reinstall grub2-efi-x64 shim-x64` then `sudo grub2-mkconfig -o /boot/grub2/grub.cfg` |
| BIOS | `sudo grub2-install /dev/sda` then `sudo grub2-mkconfig -o /boot/grub2/grub.cfg` |

Don't use `grub2-install` on UEFI with Secure Boot: it bypasses the signed shim chain.

### Try it
1. List your kernels with `grubby --info=ALL`. Set the older one as default, reboot, check `uname -r`, then set it back.
2. Remove `rhgb quiet` from all kernels, reboot, and watch the full boot messages.
3. At the GRUB menu, press `e`, add `systemd.unit=multi-user.target`, boot with Ctrl+X, and confirm it wasn't saved.
4. `cat /boot/loader/entries/*.conf` and match each line to the table above.

## Where you'll use it

- **Kernel updates** in patch cycles: `dnf update kernel` + a planned reboot. Live-patching (kpatch) can apply some security fixes without a reboot.
- **Rollback** after a bad kernel: `grubby --set-default` to the previous one.
- **Tuning and compliance:** arguments like `audit=1`, `mitigations=…`, `transparent_hugepage=never`, IOMMU settings for VMs.
- **Kubernetes/containers:** some node setups need arguments such as `systemd.unified_cgroup_hierarchy=1` on older distros, or hugepages reservations.
- **Cloud images:** `console=ttyS0` makes the provider's serial console show boot output.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `grep menuentry grub.cfg` finds nothing | RHEL uses BLS | `grubby --info=ALL`; `ls /boot/loader/entries` |
| An argument added to `/etc/default/grub` has no effect | The BLS entries weren't updated | `grubby --update-kernel=ALL --args=…`, or `grub2-mkconfig … --update-bls-cmdline` |
| UEFI machine drops to `grub>` after `grub2-mkconfig` | You overwrote the ESP stub | `dnf reinstall grub2-efi-x64`; regenerate `/boot/grub2/grub.cfg` |
| The new kernel isn't the default | A saved entry points elsewhere | `grubby --set-default …` |
| `/boot` full during a kernel update | Too many kernels | Lower `installonly_limit`; remove old kernels |
| The new kernel won't boot | Driver or initramfs problem | Pick the older kernel in the GRUB menu, then `grubby --set-default` it; rebuild the initramfs (`dracut -f --kver VER`) |

## Quick recap

- RHEL: one BLS file per kernel in `/boot/loader/entries/`; manage with **`grubby`** (`--default-kernel`, `--set-default`, `--info=ALL`, `--update-kernel=ALL --args/--remove-args`).
- One-off changes: GRUB menu → `e` → edit the `linux` line → Ctrl+X. Global defaults: `/etc/default/grub` + `grub2-mkconfig -o /boot/grub2/grub.cfg --update-bls-cmdline`.
- Kernels install side by side (`installonly_limit=3`); the new one becomes the default; reboot to use it. Ubuntu: `update-grub`, `linux-image-*`.
- Never write `grub2-mkconfig` output to the ESP stub on UEFI.

**Interview questions**

1. *How do you make a kernel argument permanent on RHEL?* `grubby --update-kernel=ALL --args="…"`, then verify with `grubby --info=ALL` and, after a reboot, `cat /proc/cmdline`.
2. *Why does RHEL keep several kernels installed?* Kernels are "install-only" packages: a new kernel is added alongside the old ones, so if it fails you can boot the previous one from the GRUB menu.
3. *What is BLS?* The Boot Loader Specification: each kernel gets its own small config file in `/boot/loader/entries/`, which GRUB reads with `blscfg`, instead of everything being generated into one big grub.cfg.
