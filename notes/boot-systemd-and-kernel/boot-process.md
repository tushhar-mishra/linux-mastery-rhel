# The RHEL 10 Boot Process

> **Objectives:** *Boot, reboot, and shut down a system normally* · supports *Boot into targets* / *Interrupt the boot process* / *Modify the bootloader* **[RHCSA Core]**
> **Related:** [systemd targets & services](systemd-targets-and-services.md) · [GRUB2 & kernel management](grub2-and-kernel-management.md) · [Boot recovery](boot-recovery.md) · [Disks & partitioning (GPT, ESP)](../storage-and-filesystems/disks-and-partitioning.md)

## 1. Overview

````
Power on → firmware (UEFI) POST → NVRAM boot entry → ESP: shimx64.efi → grubx64.efi
→ GRUB2 menu (BLS entries) → kernel (vmlinuz) + initramfs → systemd in initramfs (initrd.target)
→ mount real root at /sysroot → switch-root → systemd (PID 1) on real root → default.target → login
````

Knowing each stage tells you **where** a boot failure happens and **which tool** fixes it.

## 2. Stages

| # | Stage | What happens | Key files / tools |
|---|---|---|---|
| 1 | **Firmware (UEFI)** | POST, hardware init, reads boot entries from NVRAM | `efibootmgr -v` |
| 2 | **Shim** | First-stage loader signed by Microsoft's UEFI CA (Secure Boot); verifies GRUB | `/boot/efi/EFI/redhat/shimx64.efi` |
| 3 | **GRUB2** | Shows the menu; loads the kernel and initramfs with kernel arguments | `/boot/efi/EFI/redhat/grub.cfg` (stub) → `/boot/grub2/grub.cfg`, `/boot/grub2/grubenv`, **BLS entries** `/boot/loader/entries/*.conf` |
| 4 | **Kernel** | Initializes CPU, memory, built-in drivers; unpacks initramfs | `/boot/vmlinuz-<ver>`, `/proc/cmdline` |
| 5 | **initramfs** | Minimal root filesystem with **only what's needed to reach the real root**: storage, LVM, RAID, LUKS, filesystem drivers. Runs systemd (`initrd.target`) | `/boot/initramfs-<ver>.img` (built by `dracut`) |
| 6 | **Switch root** | Real root mounted at `/sysroot`, then switch-root makes it `/` | `rd.break` stops just before this |
| 7 | **systemd (PID 1)** | `/sbin/init` → `/usr/lib/systemd/systemd`; reaches `default.target` (sysinit → basic → multi-user → graphical) | `/etc/systemd/system/default.target` |
| 8 | **Login** | getty on consoles, GDM for graphical, sshd | |

**Legacy BIOS (MBR) boot** **[Advanced]**: firmware → MBR boot code → GRUB core (`/boot/grub2/i386-pc`) → same from stage 3.

### Files in `/boot`

| File | Purpose |
|---|---|
| `vmlinuz-<ver>` | Compressed kernel image |
| `initramfs-<ver>.img` | Initial RAM filesystem for that kernel |
| `initramfs-<ver>kdump.img` | initramfs used by kdump (crash capture) |
| `vmlinuz-0-rescue-*` / `initramfs-0-rescue-*` | **Rescue** kernel and a generic (all-drivers) initramfs: a fallback when normal entries fail |
| `config-<ver>` | Kernel build configuration |
| `System.map-<ver>`, `symvers-<ver>.xz` | Kernel symbol table / symbol versions (debugging, module builds) |
| `grub2/` | GRUB config, environment, modules |
| `loader/entries/` | **BLS** boot entries (one `.conf` per kernel) |
| `efi/` | Mount point of the EFI System Partition (VFAT) |

## 3. Secure Boot **[Interview Knowledge]**

- **Chain of trust:** firmware (`db` keys) → **shim** (Microsoft-signed) → GRUB and kernel (Red Hat-signed, checked by shim against embedded keys and enrolled **MOKs**) → kernel modules (signed).
- `db` = allowed signatures, `dbx` = revoked; PK/KEK only authorize changes to these databases.
- Secure Boot is a **firmware setting**; RHEL supports it but doesn't switch it on.

````bash
ls /sys/firmware/efi && echo UEFI || echo BIOS   # boot mode
mokutil --sb-state                                # SecureBoot enabled/disabled
mokutil --list-enrolled | head                    # enrolled MOK keys
mokutil --import my_signing_key.der               # enroll own key (confirm at next boot in MOK Manager)
````

Unsigned custom kernels or third-party modules (e.g., DKMS) won't load with Secure Boot on until you sign them with a key enrolled through MOK.

## 4. Inspecting a Boot

````bash
cat /proc/cmdline                     # arguments the running kernel booted with
uname -r ; hostnamectl                # kernel version (6.12.0-…el10… on RHEL 10)
efibootmgr -v                         # UEFI boot entries and order
grubby --info=DEFAULT                 # default boot entry
systemd-analyze                       # firmware/loader/kernel/initrd/userspace times
systemd-analyze blame | head          # slowest units
systemd-analyze critical-chain        # dependency chain that delayed boot
journalctl -b                         # messages from this boot; -b -1 = previous (needs persistent journal)
journalctl -k -b                      # kernel messages this boot (also: dmesg)
````

## 5. Shutting Down & Rebooting **[RHCSA Core]**

````bash
systemctl reboot            # = reboot
systemctl poweroff          # = poweroff / shutdown -h now
shutdown -r +5 "Maintenance in 5 minutes"   # scheduled, with wall message ; shutdown -c cancels
systemctl halt              # stop the OS without powering off
````

## 6. RHEL 10 Notes

| Topic | Fact |
|---|---|
| Kernel | 6.12 series (`6.12.0-…el10…`) |
| Bootloader | GRUB2 with BLS entries, via shim on UEFI. systemd-boot is not the standard RHEL bootloader **[Advanced/Optional]** |
| Image mode | RHEL can be deployed as a bootable container image (`bootc`); updates are atomic and the OS image is read-only. Check with `bootc status` **[Advanced/Optional]** |
| Root account | Disabled by default, so rescue/emergency targets that ask for root's password may refuse access (see [boot recovery](boot-recovery.md)) |

## 7. Troubleshooting by Stage

| Symptom | Stage | Where to look |
|---|---|---|
| No boot device / firmware menu | Firmware | Boot order, `efibootmgr`, ESP present? |
| `grub>` or `grub rescue>` prompt | GRUB | Missing/corrupt `grub.cfg`, ESP or `/boot` files ([recovery](boot-recovery.md)) |
| Secure Boot violation | Shim/GRUB/kernel | Unsigned component; MOK |
| Kernel panic "VFS: Unable to mount root fs" | Kernel/initramfs | Missing/broken initramfs, wrong `root=` |
| `dracut-initqueue timeout` → dracut emergency shell | initramfs | Root device not found (LVM/LUKS/driver), wrong `rd.lvm.lv=` / UUID |
| "Give root password for maintenance" | systemd | fstab error, failed mount, failed unit |
| Boot loops | systemd | `default.target` → `reboot.target` |

## 8. Interview Questions

| Question | Answer |
|---|---|
| Walk through the RHEL boot process. | UEFI → shim → GRUB2 (BLS) → kernel + initramfs → systemd in initramfs mounts root at /sysroot → switch-root → systemd PID 1 → default.target. |
| What's the initramfs for? | A temporary root with just enough drivers/tools (LVM, LUKS, storage) to find and mount the real root filesystem. |
| What does shim do? | A Microsoft-signed first-stage loader that lets distro-signed GRUB/kernels boot under Secure Boot (and supports MOK). |
| Where are GRUB menu entries on RHEL? | BLS files in `/boot/loader/entries/`; `grub.cfg` loads them via `blscfg`. |
| How do you find what slowed the boot? | `systemd-analyze blame` and `critical-chain`. |

## 9. Quick Revision

````
UEFI → shim → GRUB2 (BLS /boot/loader/entries) → vmlinuz + initramfs (dracut) → initrd.target → /sysroot → switch-root → systemd → default.target
cat /proc/cmdline · uname -r · efibootmgr -v · grubby --info=DEFAULT · mokutil --sb-state
systemd-analyze [blame|critical-chain] · journalctl -b [-1] · journalctl -k
systemctl reboot|poweroff|halt · shutdown -r +5 / -c
````

## 10. Cross-References

- [systemd targets & services](systemd-targets-and-services.md)
- [GRUB2 & kernel management](grub2-and-kernel-management.md)
- [Boot recovery](boot-recovery.md)
- [Disks & partitioning (GPT, ESP)](../storage-and-filesystems/disks-and-partitioning.md)
