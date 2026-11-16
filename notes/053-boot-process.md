# 053 · The Boot Process: From Power Button to Login Prompt

> **You need first:** [052 · LVM snapshots](052-lvm-snapshots-and-recovery.md)
> **Next:** [054 · GRUB and kernel packages](054-grub-and-kernel-packages.md)

---

## What it is

Booting is a **relay race**. Each runner does one small job and hands over to the next:

```
Power on → UEFI firmware → shim → GRUB2 → kernel + initramfs → systemd (in initramfs)
→ mount the real root → switch-root → systemd (PID 1) on the real root → default.target → login prompt
```

New words:
- **Bootloader**: the small program that loads the kernel. On RHEL and Ubuntu it's **GRUB2** (GRand Unified Bootloader, version 2).
- **ESP** (EFI System Partition): a small **VFAT** partition (mounted at `/boot/efi`) that UEFI firmware can read. It holds the boot programs.
- **initramfs** (initial RAM filesystem): a small, temporary root filesystem packed into one file. The kernel unpacks it into RAM and uses it to find and mount the **real** root filesystem.
- **Secure Boot**: a UEFI feature that only runs boot programs carrying a trusted **digital signature** (a cryptographic proof of who built a file and that it wasn't changed; topic 064).
- **shim**: a tiny first-stage loader signed by Microsoft's key (which all PC firmware trusts). It in turn checks the signatures on GRUB and the kernel, so Linux can boot with Secure Boot on.

## Why it exists

Each stage solves a chicken-and-egg problem:
- Firmware only knows how to read a simple VFAT partition, not XFS or LVM → it loads a small program from the ESP.
- GRUB can read `/boot` and offers a menu of kernels → it loads the chosen kernel.
- The kernel can't mount a root filesystem that sits on LVM, inside encryption, or needs a special driver until it has the right tools → the **initramfs** provides exactly those tools.
- systemd then starts everything else.

Knowing the stages tells you **where** a boot is failing and **which tool** fixes it. That's the core skill for "server won't boot" incidents.

## Analogy

Starting a big factory in the morning:
1. The **security guard** (firmware) checks the building and unlocks the front office.
2. The **receptionist** (shim) checks the manager's ID badge (Secure Boot signature).
3. The **shift manager** (GRUB) picks which production plan to run today (which kernel) and the special instructions (kernel arguments).
4. The **chief engineer** (kernel) arrives with a **toolbox** (initramfs), needed to open the locked warehouse (root on LVM/encryption).
5. Once the warehouse is open, the engineer moves in for good (switch-root), and the **plant supervisor** (systemd) starts every machine in the right order.

## How it works inside

### Stage by stage

| # | Stage | What happens | Key files / tools |
|---|---|---|---|
| 1 | **Firmware (UEFI)** | POST (Power-On Self-Test: checks hardware), initialises devices, reads its **boot entries** from NVRAM (the firmware's small settings memory), finds the ESP | `efibootmgr -v` |
| 2 | **shim** | Signed by Microsoft; verifies GRUB's signature (Red Hat's key) | `/boot/efi/EFI/redhat/shimx64.efi` |
| 3 | **GRUB2** | Reads its config, shows the menu (one entry per installed kernel), loads the chosen **kernel** and **initramfs** into RAM with the **kernel arguments** | `/boot/grub2/grub.cfg`, `/boot/loader/entries/*.conf` |
| 4 | **Kernel** | Decompresses itself; sets up the CPU, memory and built-in drivers; unpacks the initramfs into RAM; runs its `/init` | `/boot/vmlinuz-<version>`, `/proc/cmdline` |
| 5 | **initramfs** | A mini system running **systemd** (`initrd.target`). Loads storage drivers, assembles RAID, activates LVM, unlocks encryption (asking for a passphrase if needed), and mounts the real root at **`/sysroot`** | `/boot/initramfs-<version>.img`, built by **dracut** |
| 6 | **switch-root** | Makes `/sysroot` the new `/`, frees the initramfs, and starts the real systemd | `rd.break` stops just before this |
| 7 | **systemd (PID 1)** | Starts units towards `default.target`: sysinit → basic → multi-user (→ graphical), mounting fstab entries and starting services in parallel | `/etc/systemd/system/default.target` |
| 8 | **Login** | getty on consoles (topic 003), the graphical login screen, sshd | |

**Old BIOS + MBR machines:** firmware → MBR boot code in sector 0 → GRUB's core image → then the same from stage 3.

### Files in /boot

| File | Purpose |
|---|---|
| `vmlinuz-<ver>` | The compressed kernel ("vm" = virtual memory, "z" = compressed) |
| `initramfs-<ver>.img` | The initramfs for that kernel |
| `initramfs-<ver>kdump.img` | The initramfs used when capturing kernel crashes (topic 103) |
| `vmlinuz-0-rescue-*` / `initramfs-0-rescue-*` | A **rescue** kernel with a generic initramfs containing all drivers: a fallback when normal entries fail |
| `config-<ver>` | The kernel's build configuration |
| `System.map-<ver>` | The kernel's symbol table (for debugging) |
| `grub2/` | GRUB's config and modules |
| `loader/entries/` | **BLS** boot entries: one file per kernel (topic 054) |
| `efi/` | Mount point of the ESP |

### Secure Boot's chain of trust

Firmware trusts keys in its `db` database (and blocks those in `dbx`) → it runs **shim** (Microsoft-signed) → shim checks **GRUB** and the **kernel** (Red Hat-signed), plus any keys you enrol yourself as **MOKs** (Machine Owner Keys) → the kernel only loads **signed modules**. Secure Boot is switched on or off **in the firmware**. Unsigned custom kernels or third-party drivers won't load until you sign them with an enrolled MOK.

### Ubuntu differences

Same stages. Ubuntu builds the initramfs with **initramfs-tools** (`update-initramfs -u`) instead of dracut, and generates a classic `grub.cfg` with `update-grub` (no BLS entries). Ubuntu's ESP path is `/boot/efi/EFI/ubuntu/`.

## Commands

```bash
ls /sys/firmware/efi >/dev/null 2>&1 && echo UEFI || echo BIOS
mokutil --sb-state
```
```
UEFI
SecureBoot enabled
```

```bash
cat /proc/cmdline
```
```
BOOT_IMAGE=(hd0,gpt2)/vmlinuz-6.12.0-55.el10.x86_64 root=/dev/mapper/rhel-root ro crashkernel=1G-4G:192M,4G-64G:256M,64G-:512M resume=/dev/mapper/rhel-swap rd.lvm.lv=rhel/root rd.lvm.lv=rhel/swap rhgb quiet
```
- The **kernel arguments** this boot used:
  - `root=`: which device becomes `/`.
  - `ro`: mount it read-only first (systemd remounts it read-write after checks).
  - `rd.lvm.lv=`: which LVs the initramfs must activate (the `rd.` prefix = for dracut, the initramfs).
  - `crashkernel=`: memory reserved for crash capture.
  - `resume=`: where to resume from hibernation.
  - `rhgb quiet`: graphical splash screen, fewer messages.

```bash
sudo efibootmgr -v
```
```
BootCurrent: 0001
BootOrder: 0001,0000
Boot0000* UiApp	FvVol(...)
Boot0001* Red Hat Enterprise Linux	HD(1,GPT,…)/File(\EFI\redhat\shimx64.efi)
```
- The firmware's boot entries and their order. The RHEL entry points at shim on the ESP.

```bash
ls /boot ; ls /boot/loader/entries/
lsinitrd /boot/initramfs-$(uname -r).img | grep -E 'lvm|xfs' | head
```
- `lsinitrd` lists what's inside an initramfs (drivers, tools, config).

### How long did booting take, and why?

```bash
systemd-analyze
```
```
Startup finished in 2.104s (firmware) + 1.512s (loader) + 1.201s (kernel) + 2.874s (initrd) + 9.640s (userspace) = 17.333s
multi-user.target reached after 9.601s in userspace.
```
- The time spent in each stage.

```bash
systemd-analyze blame | head -3
systemd-analyze critical-chain
```
```
5.102s NetworkManager-wait-online.service
1.240s dnf-makecache.service
 812ms kdump.service
```
- `blame` = slowest units. `critical-chain` = the chain of units that actually delayed reaching the target.

### Boot messages

```bash
journalctl -b            # everything from this boot
journalctl -b -1 -p err  # errors from the PREVIOUS boot (needs a persistent journal, topic 038)
journalctl -k -b         # kernel messages this boot (same idea as dmesg)
```

### Shut down and reboot

```bash
sudo systemctl reboot
sudo systemctl poweroff
sudo shutdown -r +5 "Rebooting for kernel update in 5 minutes"
sudo shutdown -c                        # cancel a scheduled shutdown
```
- During shutdown, systemd stops services in reverse dependency order, unmounts filesystems, and syncs disks. Pulling the power skips all of that, so the journal (topic 047) has to recover the filesystems.

### Try it
1. Read your `/proc/cmdline` and explain every argument.
2. Run `systemd-analyze`, `blame` and `critical-chain`. What's slowest on your VM?
3. Reboot and watch the console in the VM window: GRUB menu → kernel messages → systemd's "[ OK ] Started …" lines.
4. `lsinitrd | less` and find the LVM and XFS pieces in your initramfs.

## Where you'll use it

- **"Server won't boot" incidents:** identify the stage from what's on the console, then fix that stage (table below; topic 057 has the procedures).
- **Cloud instances:** you can't see a monitor, so use the provider's **serial console** or "get system log" screenshot to find which stage failed.
- **Kernel arguments** for tuning or debugging (topic 054).
- **Boot-time optimisation** with `systemd-analyze`, for VMs and containers that must start fast.
- **Immutable / image-based systems** (RHEL image mode with `bootc`, Fedora CoreOS, Bottlerocket for Kubernetes nodes) use the same chain but ship the whole OS as one read-only image.

## When it breaks

| What you see | Failing stage | Where to look |
|---|---|---|
| "No bootable device", or the firmware menu | Firmware | Boot order, `efibootmgr`, is the ESP present? |
| A `grub>` or `grub rescue>` prompt | GRUB | Missing/corrupt `grub.cfg`, ESP or `/boot` files (topic 057) |
| "Secure Boot violation" | shim/GRUB/kernel | An unsigned component; enrol a MOK or sign it |
| Kernel panic: "VFS: Unable to mount root fs" | Kernel/initramfs | Missing or broken initramfs, wrong `root=` |
| `dracut-initqueue timeout` → dracut emergency shell | initramfs | The root device wasn't found: LVM, encryption, driver, or a wrong UUID |
| "Give root password for maintenance" / emergency mode | systemd | A bad fstab entry, a failed mount or unit (topic 048) |
| Reboots in a loop | systemd | `default.target` → `reboot.target` |
| Boot is very slow | systemd | `systemd-analyze blame` (often a wait-online or a missing network mount) |

## Quick recap

- UEFI → shim (Secure Boot) → GRUB2 (menu, kernel arguments) → kernel + **initramfs** (finds and mounts the real root at `/sysroot`) → switch-root → systemd PID 1 → `default.target`.
- `/boot`: `vmlinuz-*`, `initramfs-*` (built by dracut; Ubuntu: initramfs-tools), `loader/entries/`; the ESP is VFAT at `/boot/efi`.
- `cat /proc/cmdline`, `efibootmgr -v`, `mokutil --sb-state`, `lsinitrd`, `systemd-analyze blame`, `journalctl -b -1`.
- Match the symptom to the stage, then fix that stage.

**Interview questions**

1. *Walk me through the Linux boot process.* Firmware (UEFI) runs shim from the ESP, which verifies and runs GRUB. GRUB loads the kernel and initramfs with arguments. The kernel unpacks the initramfs, whose systemd activates storage and mounts the real root at /sysroot, then switch-root hands over to systemd as PID 1, which starts units until default.target is reached.
2. *What is the initramfs for?* It's a temporary root filesystem in RAM containing just the drivers and tools (LVM, RAID, encryption, filesystem drivers) needed to find and mount the real root filesystem.
3. *A server stops at a `dracut-initqueue timeout`. What does that tell you?* The kernel and initramfs loaded fine, but the initramfs couldn't find the root device: wrong UUID or `rd.lvm.lv`, a missing driver, a failed disk or an encryption problem.
