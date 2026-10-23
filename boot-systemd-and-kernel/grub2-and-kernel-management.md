# GRUB2, Kernel Arguments & Kernel Packages

> **Sessions:** S49, S52 (kernel install), S53 (boot parameters) · **Objectives:** *Modify the system bootloader* · *Install and update software packages* (kernels) **[RHCSA Core]**
> **Related:** [Boot process](boot-process.md) · [Boot recovery](boot-recovery.md) · [Kernel modules & parameters](kernel-modules-and-parameters.md) · [Kernel compilation](kernel-compilation.md)

## 1. Overview

On RHEL, each installed kernel gets a **Boot Loader Specification (BLS)** entry in `/boot/loader/entries/`. GRUB2's `grub.cfg` reads them with the `blscfg` command, so `grub.cfg` contains **no per-kernel `menuentry` blocks**. Manage entries, the default kernel and kernel arguments with **`grubby`**. Use `/etc/default/grub` + `grub2-mkconfig` for global GRUB settings such as the timeout.

## 2. Key Files

| File | Purpose |
|---|---|
| `/boot/loader/entries/<machine-id>-<ver>.conf` | One BLS entry per kernel (title, linux, initrd, options) |
| `/boot/grub2/grub.cfg` | Main GRUB config (generated; **don't edit by hand**) |
| `/boot/efi/EFI/redhat/grub.cfg` | **Stub** on UEFI that points to `/boot/grub2/grub.cfg`; don't overwrite |
| `/boot/grub2/grubenv` | Saved state: `saved_entry`, `kernelopts` etc. (`grub2-editenv list`) |
| `/etc/default/grub` | Input for `grub2-mkconfig` (timeout, `GRUB_CMDLINE_LINUX` …) |
| `/etc/kernel/cmdline` | Kernel arguments applied to newly installed kernels |

## 3. Default Kernel

```bash
grubby --default-kernel                 # /boot/vmlinuz-6.12.0-…
grubby --default-index                  # index of the default entry
grubby --info=ALL | grep -E '^(index|kernel|title)'   # list entries
ls /boot/loader/entries/
grubby --set-default /boot/vmlinuz-6.12.0-55.9.1.el10_0.x86_64
grub2-editenv list                      # saved_entry=…
```

`grub2-set-default <index|entry-id>` also works, but `grubby --set-default <kernel path>` is clearer.

## 4. Kernel Arguments **[RHCSA Core]**

```bash
cat /proc/cmdline                                        # current boot
grubby --info=DEFAULT | grep args
grubby --update-kernel=ALL --args="audit=1"              # add to ALL kernels (persistent)
grubby --update-kernel=ALL --remove-args="rhgb quiet"    # remove
grubby --update-kernel=/boot/vmlinuz-<ver> --args="systemd.unit=multi-user.target"   # one kernel
```

**Alternative (global defaults):** edit `GRUB_CMDLINE_LINUX` in `/etc/default/grub`, then run `grub2-mkconfig -o /boot/grub2/grub.cfg`. On RHEL 9.3 and later, add `--update-bls-cmdline` so existing BLS entries pick up the new arguments.

**One boot only:** GRUB menu → `e` → edit the `linux` line → Ctrl+X.

| Common argument | Effect |
|---|---|
| `rhgb quiet` | Graphical splash, fewer messages (RHEL default) |
| `systemd.unit=<target>` | Boot into a specific target |
| `rd.break` | Stop in the initramfs before switch-root (password reset) |
| `enforcing=0` | SELinux permissive for this boot (troubleshooting) |
| `selinux=0` | Disable SELinux entirely ⚠️ (requires relabel when re-enabling) |
| `rd.lvm.lv=VG/LV` | LVs to activate in the initramfs (root, swap) |
| `crashkernel=…` | Memory reserved for kdump |
| `fsck.mode=force` | Force filesystem checks at boot |
| `mem=2G` | Limit usable RAM (testing) |

## 5. GRUB Settings (timeout etc.)

```bash
vi /etc/default/grub                 # GRUB_TIMEOUT=5, GRUB_DEFAULT=saved …
grub2-mkconfig -o /boot/grub2/grub.cfg       # BOTH BIOS and UEFI on RHEL 9/10
```

> ⚠️ Don't write `grub2-mkconfig -o /boot/efi/EFI/redhat/grub.cfg` on RHEL 9/10; that file is the UEFI stub.

## 6. Kernel Packages **[RHCSA Core: installing/updating]**

| Package | Content |
|---|---|
| `kernel` | Meta-package (no files) pulling in the parts below |
| `kernel-core` | Kernel image, initramfs tooling, minimal module set |
| `kernel-modules-core` / `kernel-modules` | Core / common additional drivers |
| `kernel-modules-extra` | Rare or niche drivers |
| `kernel-devel` | Headers and Makefiles to build out-of-tree modules (`/usr/src/kernels/<ver>`) |
| `kernel-headers` | Userspace API headers (for building programs) |
| `kernel-debug` | Debug-enabled kernel variant |
| `kernel-tools` | `cpupower`, `turbostat` and similar (`tuned`, `perf` are separate packages) |
| `kernel-abi-stablelists` | Stable kernel ABI symbol lists (formerly `kernel-abi-whitelists`) |

```bash
rpm -q kernel                       # all installed kernels
dnf check-update kernel ; dnf update kernel     # new kernel installed ALONGSIDE old ones
dnf --showduplicates list kernel    # available versions
dnf install kernel-<version>        # specific version
grep installonly_limit /etc/dnf/dnf.conf        # how many kernels are kept (default 3)
dnf remove $(dnf repoquery --installonly --latest-limit=-2 -q)   # keep the newest 2 ⚠️ not the running one
```

Kernels are **installed, not upgraded in place**: the old one stays as a fallback, and the new one becomes the default automatically.

## 7. Reinstalling the Bootloader **[Advanced]**

| Firmware | Command |
|---|---|
| UEFI (Secure Boot-friendly) | `dnf reinstall grub2-efi-x64 shim-x64` then `grub2-mkconfig -o /boot/grub2/grub.cfg` |
| BIOS | `grub2-install /dev/sda` then `grub2-mkconfig -o /boot/grub2/grub.cfg` |

Don't use `grub2-install` on UEFI systems with Secure Boot; it bypasses the signed shim chain.

## 8. RHCSA Exam Focus **[RHCSA Core]**

- "Add kernel argument X to all kernels / make it persistent": `grubby --update-kernel=ALL --args="X"`, then verify with `grubby --info=ALL` and after a reboot `cat /proc/cmdline`.
- "Set the default kernel": `grubby --set-default /boot/vmlinuz-<ver>`; verify `grubby --default-kernel`.
- "Update the kernel": `dnf update kernel`, reboot, `uname -r`.

## 9. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `grep menuentry grub.cfg` shows nothing | BLS layout | `grubby --info=ALL`; `ls /boot/loader/entries` |
| Argument added in `/etc/default/grub` has no effect | BLS entries not updated | `grubby --update-kernel=ALL --args=…` or `grub2-mkconfig … --update-bls-cmdline` |
| UEFI system drops to `grub>` after `grub2-mkconfig` | Stub overwritten | Restore stub: `dnf reinstall grub2-efi-x64`; regenerate `/boot/grub2/grub.cfg` |
| New kernel not default | `GRUB_DEFAULT`/saved entry | `grubby --set-default …` |
| `/boot` full during kernel update | Too many kernels | Lower `installonly_limit`; remove old kernels |

## 10. Interview Questions

| Question | Answer |
|---|---|
| What is BLS? | Boot Loader Specification: one config file per kernel in `/boot/loader/entries/`, read by GRUB's `blscfg`. |
| How do you make a kernel argument persistent? | `grubby --update-kernel=ALL --args="…"`. |
| Why does RHEL keep several kernels? | `installonly` packages: a fallback if a new kernel fails to boot. |
| Where's the real GRUB config on UEFI? | `/boot/grub2/grub.cfg`; the ESP copy is a stub. |

## 11. Course Corrections

| Course | Correction |
|---|---|
| `grub2-mkconfig -o /boot/efi/EFI/redhat/grub.cfg` for UEFI | Use `/boot/grub2/grub.cfg` for both on RHEL 9/10 |
| `awk -F\' '$1=="menuentry " …' /etc/grub2.cfg` / `grep '^menuentry'` | No menuentry lines with BLS; use `grubby --info=ALL` |
| `update-grub` | Ubuntu command; RHEL: `grubby` / `grub2-mkconfig` |
| `GRUB_CMDLINE_LINUX="quiet splash …"` | RHEL default is `rhgb quiet` |
| `dnf install kernel-5.14.0-162.6.1.el10` | 5.14 is RHEL 9; RHEL 10 kernels are 6.12 |
| `kernel-abi-whitelists` | Renamed `kernel-abi-stablelists` |
| `kernel-tools` includes `tuned-adm`, `perf` | Those come from `tuned` and `perf` packages |

## 12. Quick Revision

```bash
grubby --default-kernel | --set-default /boot/vmlinuz-V | --info=ALL | --update-kernel=ALL --args="X" | --remove-args="X"
/etc/default/grub → grub2-mkconfig -o /boot/grub2/grub.cfg [--update-bls-cmdline] · grub2-editenv list
rpm -q kernel · dnf update kernel · installonly_limit · cat /proc/cmdline · uname -r
