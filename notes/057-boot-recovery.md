# 057 · Boot Recovery: Root Password Reset, Broken fstab, Boot Loops, Rescue Media

> **You need first:** [056 · tuned profiles](056-tuned-profiles.md)
> **Next:** [058 · How networks work](058-how-networks-work.md)

---

## What it is

The procedures for getting into a machine that **won't boot** or that **nobody can log into**. They all work by **interrupting the boot process** (topic 053) at the right stage and fixing things by hand.

New words:
- **chroot** ("change root"): run a shell whose `/` is a different directory. From a rescue environment, `chroot /sysroot` lets you work **inside** the installed system as if it had booted normally.
- **SELinux label**: a security tag on every file that SELinux (a mandatory access-control system, topic 072) checks on every access. Files created from a rescue shell can get the **wrong** label, so we ask for a full **relabel** at the next boot.
- **Console access**: you need the machine's real console: the physical screen, the VM console window, a cloud provider's serial console, or a remote-management card such as iLO/iDRAC (built-in management cards on HPE and Dell servers). SSH won't help when the system isn't up.

## Why it exists

Root passwords get lost. Someone sets the wrong default target. An fstab typo or a removed disk stops the boot. A new kernel panics. These happen in real life, and on RHEL 10, where **root has no password by default**, the usual emergency shell often refuses you ("the root account is locked"). Knowing these procedures turns a "rebuild the server" disaster into a 5-minute fix.

## Analogy

The boot is a **relay race** (topic 053). Recovery is **stopping the race at a chosen handover** so you can fix the runner who keeps tripping. `rd.break` stops it at the handover from the initramfs to the real system: the toolbox is open, the warehouse (root filesystem) is reachable, and nobody has checked any ID badges yet.

## How it works inside

- `rd.break` is a kernel argument read by **dracut** (the initramfs). It drops you into a root shell **inside the initramfs**, after the real root filesystem has been mounted (read-only) at `/sysroot` but **before** switch-root. No password is asked, because no login system is running yet.
- `init=/bin/bash` tells the kernel to run bash **instead of systemd** as PID 1. You get a root shell straight away, but no services, no systemd, and normal reboot commands don't work.
- **Why `/.autorelabel`?** `passwd` writes a **new** `/etc/shadow`. Created from the initramfs, where SELinux policy isn't loaded, that file gets no proper SELinux label. Once the system boots normally with SELinux enforcing, login programs can't read the mislabelled shadow file, so **nobody can log in**. The file `/.autorelabel` tells the system to relabel every file at the next boot (it takes a few minutes, then reboots by itself).
- **Rescue media** (the installation DVD/ISO) boots a complete, independent Linux from the DVD. It can mount your disks and chroot into them even when your bootloader or kernel is broken.

### Choose the least invasive entry point

| Situation | Entry point |
|---|---|
| Lost or locked root password | **`rd.break`** (no password), or `init=/bin/bash` |
| Root password lost **and** the GRUB menu is password-protected (unknown) | **Installation media → Rescue** |
| Wrong default target / reboot loop | GRUB `e` → `systemd.unit=multi-user.target` |
| Broken `/etc/fstab`, failed mount | Emergency shell (needs root's password) or `rd.break` |
| The newest kernel panics | An older kernel or the "0-rescue" entry in the GRUB menu |
| Missing or corrupt initramfs | Rescue entry or older kernel → `dracut` |
| GRUB/ESP broken, nothing boots | Installation media → Rescue |
| Cloud VM, no console interaction possible | Stop the VM, attach its disk to a helper VM, fix it there, reattach |

## Commands

### Reset the root password with rd.break (the standard method)

```text
1. Reboot. At the GRUB menu press an arrow key to stop the countdown, select the entry, press  e
2. Find the line starting with  linux  and append at its END:   rd.break
   (Optionally delete "rhgb quiet" to see messages. On serial/cloud consoles keep the console= argument.)
3. Press Ctrl+X to boot.  You get the prompt:   switch_root:/#
```
```bash
mount -o remount,rw /sysroot     # the real root is mounted READ-ONLY at /sysroot; make it writable
chroot /sysroot                  # now "/" is the installed system
passwd root                      # set a new password (this also enables a disabled root)
touch /.autorelabel              # ESSENTIAL: relabel SELinux at next boot
exit                             # leave the chroot
exit                             # continue booting: relabel runs, then it reboots by itself
```
```
sh-5.2# passwd root
Changing password for user root.
New password:
Retype new password:
passwd: all authentication tokens updated successfully.
```
After the automatic reboot, log in as root with the new password.

### Alternative: init=/bin/bash

```text
GRUB → e → at the end of the  linux  line append:   rw init=/bin/bash   → Ctrl+X
```
```bash
passwd root
touch /.autorelabel
exec /sbin/init           # hand over to systemd and boot normally (or: sync; /usr/sbin/reboot -f)
```
- `systemctl reboot` doesn't work here, because systemd isn't running. If you forgot `rw`, run `mount -o remount,rw /` first.

### Protecting the boot menu: a GRUB password

Anyone with console access can do the above. A GRUB password requires a password before editing entries (`e`) or opening the GRUB command line (`c`). **Normal booting stays unrestricted.**
```bash
sudo grub2-setpassword
cat /boot/grub2/user.cfg
```
```
Enter password:
Confirm password:
GRUB2_PASSWORD=grub.pbkdf2.sha512.10000.8A7D…
```
- Stored as a salted hash (topic 023) in `/boot/grub2/user.cfg`. At the menu, `e` now asks for user `root` and this password.
- Remove it: `sudo rm /boot/grub2/user.cfg`.
- It doesn't stop booting from a USB stick or pulling the disk. Combine it with a firmware password, Secure Boot and disk encryption (topic 088).

### Fix a reboot loop (default target set wrong)

```text
GRUB → e → append to the linux line:  systemd.unit=multi-user.target  → Ctrl+X
```
```bash
sudo systemctl set-default multi-user.target
systemctl get-default
```

### Fix a broken /etc/fstab

Symptom: "You are in emergency mode… Give root password for maintenance" (topic 048).
- **You know root's password:** log in, then `mount -o remount,rw /` → `vi /etc/fstab` (comment out or fix the bad line) → `systemctl daemon-reload` → `mount -a` → `reboot`.
- **You don't (RHEL 10 default):** use `rd.break` → `mount -o remount,rw /sysroot` → `chroot /sysroot` → `vi /etc/fstab` → `touch /.autorelabel` → `exit` twice.
- **Prevention:** `findmnt --verify` and `mount -a` before every reboot; `nofail` on non-essential mounts.

### Kernel panic or missing initramfs

Typical messages: `Kernel panic - not syncing: VFS: Unable to mount root fs`, `dracut-initqueue timeout`.
```text
GRUB menu → pick an OLDER kernel, or the "0-rescue" entry
```
```bash
rpm -q kernel                                  # which versions are installed
sudo dracut -f --kver 6.12.0-55.el10.x86_64    # rebuild THAT kernel's initramfs (name it explicitly!)
lsinitrd /boot/initramfs-6.12.0-55.el10.x86_64.img | head
sudo reboot
```
- Don't use `$(uname -r)` here: you're running the **rescue/old** kernel, so it would rebuild the wrong one.

### Rescue from installation media

```text
Boot the RHEL DVD/ISO → Troubleshooting → "Rescue a Red Hat Enterprise Linux system"
   1) Continue        → your system is mounted read-write at /mnt/sysroot (easiest)
   2) Read-only mount
   3) Skip to shell   → mount it yourself (needed for xfs_repair, which wants it UNmounted)
```
**Option 1:**
```bash
chroot /mnt/sysroot
passwd root ; touch /.autorelabel                 # password reset
dracut -f --kver <installed-version>              # initramfs repair
rm -f /boot/grub2/user.cfg                        # only if you must remove an unknown GRUB password
exit ; exit                                       # reboot (remove the ISO)
```
**Option 3 (manual):**
```bash
vgscan ; vgchange -ay ; lvscan                    # activate LVM (default layout: VG "rhel")
xfs_repair /dev/mapper/rhel-root                  # repair root while it's NOT mounted (topic 051)
mkdir -p /mnt/sysroot ; mount /dev/mapper/rhel-root /mnt/sysroot
mount /dev/vda1 /mnt/sysroot/boot                 # if you need /boot (check lsblk)
chroot /mnt/sysroot
# ... fix things ...
exit ; umount -R /mnt/sysroot ; reboot
```
**Repairing GRUB** from rescue: `dnf reinstall grub2-efi-x64 shim-x64` (UEFI) or `grub2-install /dev/vda` (BIOS), then `grub2-mkconfig -o /boot/grub2/grub.cfg` (topic 054).

### Capturing kernel panics

`kdump` (enabled on many installs, using the `crashkernel=` argument) reserves memory for a second, tiny kernel that saves a memory dump to `/var/crash/` when the main kernel panics. You analyse it with the `crash` tool or send it to support (topic 103).

### Ubuntu notes

Same ideas. In GRUB, edit the `linux` line and use `init=/bin/bash` (or boot the "recovery mode" menu entry, which offers a root shell). There's no `rd.break` (Ubuntu doesn't use dracut) and no `/.autorelabel` (Ubuntu uses AppArmor, which doesn't label files).

### Try it (on a VM with a snapshot!)
1. Reset root's password with `rd.break`. Then do it again **without** `touch /.autorelabel` and see that login fails. Fix it.
2. Set `default.target` to `reboot.target` (`systemctl set-default reboot.target`), reboot, and recover.
3. Add a bad fstab line (a wrong UUID with no `nofail`), reboot, and recover via `rd.break`.
4. Set a GRUB password, try `e`, then remove it.

## Where you'll use it

- **Lost credentials** on lab machines, appliances and inherited servers.
- **Failed changes:** a bad fstab, an SELinux misconfiguration, a broken sudoers file (fix it from `rd.break` + chroot + `visudo`), a broken PAM configuration.
- **Bad kernel updates:** boot the previous kernel, then set it as default (topic 054).
- **Cloud:** the serial console (AWS EC2 Serial Console, Azure Serial Console, GCP serial port) gives you GRUB access; otherwise use the "attach disk to a rescue VM" method.
- **Security awareness:** physical/console access = root. Protect it with GRUB and firmware passwords, Secure Boot and disk encryption.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| Can't log in after resetting the password | Forgot `/.autorelabel`, so `/etc/shadow` has the wrong SELinux label | Redo it with `touch /.autorelabel` (or `restorecon -v /etc/shadow` from a root shell) |
| `passwd: Authentication token manipulation error` | `/sysroot` still read-only, or not chrooted | `mount -o remount,rw /sysroot`; `chroot /sysroot` |
| No `switch_root:/#` shell appears | `rd.break` was added to the wrong line | Append it to the end of the `linux …` line |
| "Cannot open access to console, the root account is locked" | Emergency/rescue mode needs root's password | Use `rd.break` |
| `e` asks for a username and password | A GRUB password is set | Enter it, or use installation media |
| `System has not been booted with systemd` after `init=/bin/bash` | systemd isn't PID 1 | `exec /sbin/init` or `reboot -f` |
| Still panics after `dracut` | You rebuilt the wrong kernel version | `dracut -f --kver <correct version>` |

## Quick recap

- **Password reset:** `e` → append `rd.break` → Ctrl+X → `mount -o remount,rw /sysroot` → `chroot /sysroot` → `passwd root` → **`touch /.autorelabel`** → `exit`, `exit`.
- Alternative: `rw init=/bin/bash` → `passwd` → `touch /.autorelabel` → `exec /sbin/init`.
- Boot loop: `systemd.unit=multi-user.target` once, then `set-default`. Bad fstab: emergency shell or `rd.break`. Bad kernel: older/rescue entry + `dracut -f --kver`.
- Nothing works: installation media → Troubleshooting → Rescue → chroot `/mnt/sysroot`. Protect the console with `grub2-setpassword`.

**Interview questions**

1. *How do you reset a lost root password on RHEL?* At GRUB press `e`, add `rd.break` to the linux line, boot, `mount -o remount,rw /sysroot`, `chroot /sysroot`, `passwd root`, `touch /.autorelabel`, then exit twice.
2. *Why is `touch /.autorelabel` needed?* The new `/etc/shadow` is written from the initramfs without a proper SELinux label. After a normal boot with SELinux enforcing, login can't read it. The relabel fixes every file's label.
3. *How do you prevent someone at the console from resetting the root password?* A GRUB password (`grub2-setpassword`), a firmware password, Secure Boot, full-disk encryption and physical/console access control.
