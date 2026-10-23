# Boot Recovery: Root Password Reset, Boot Loops, Broken fstab, Kernel Panic

> **Sessions:** S50–S51 (S67 extends root/GRUB password recovery) · **Objective:** *Interrupt the boot process in order to gain access to a system* **[RHCSA Core]**
> **Related:** [Boot process](boot-process.md) · [systemd targets & services](systemd-targets-and-services.md) · [GRUB2 & kernel management](grub2-and-kernel-management.md) · [Mounting & fstab](../storage-and-filesystems/mounting-and-fstab.md) · [Filesystem check & repair](../storage-and-filesystems/filesystem-check-and-repair.md)

## 1. Overview

When a system won't boot or you can't log in, choose the least invasive entry point:

| Situation | Entry point |
|---|---|
| Forgotten/locked root password | **`rd.break`** (initramfs shell, no password) |
| Wrong default target (boot loop) | GRUB `e` → `systemd.unit=multi-user.target` |
| Broken `/etc/fstab`, failed mount | Emergency shell (root password) or `rd.break` |
| Latest kernel panics | Older kernel or **rescue** entry in the GRUB menu |
| Missing/corrupt initramfs | Rescue entry or older kernel → `dracut` |
| GRUB/ESP broken, nothing boots | **Installation media → Troubleshooting → Rescue** |

> **RHEL 10:** root is disabled by default, so emergency/rescue targets may refuse access ("root account is locked"). `rd.break` and installation-media rescue don't need root's password.

## 2. Reset the Root Password with `rd.break` **[RHCSA Core]**

`````text
1. Reboot. At the GRUB menu press any arrow key to stop the countdown, select the entry, press  e
2. On the line starting with  linux  append:  rd.break
   (optionally remove "rhgb quiet" to see messages; on serial/cloud consoles keep the right console=)
3. Ctrl+X to boot → you get:  switch_root:/#
`````

`````bash
mount -o remount,rw /sysroot     # real root is mounted READ-ONLY at /sysroot
chroot /sysroot                  # work inside the installed system
passwd root                      # set a new password (also unlocks a disabled root)
touch /.autorelabel              # ESSENTIAL: SELinux relabel on next boot (/etc/shadow lost its context)
exit                             # leave chroot
exit                             # continue boot (relabel runs, then the system reboots by itself)
`````

The relabel can take minutes and reboots automatically. Then log in as root with the new password.

**Alternative:** append `init=/bin/bash` instead of `rd.break` → `mount -o remount,rw /` → `passwd root` → `touch /.autorelabel` → `exec /sbin/init` (or `/usr/sbin/reboot -f`).

## 3. Fix a Boot Loop (default = reboot.target)

`````text
GRUB → e → append to the linux line:  systemd.unit=multi-user.target  → Ctrl+X
`````

`````bash
systemctl set-default multi-user.target     # or graphical.target
systemctl get-default ; reboot
`````

## 4. Fix a Broken `/etc/fstab`

**Symptom:** "You are in emergency mode… Give root password for maintenance", often after a typo or a missing disk.

- **With root's password:** log in, then `mount -o remount,rw /`, `vi /etc/fstab`, `systemctl daemon-reload`, `mount -a`, `reboot`.
- **Without it:** use the `rd.break` route (§2): `mount -o remount,rw /sysroot` → `chroot /sysroot` → `vi /etc/fstab` → `touch /.autorelabel` → `exit` ×2.

**Prevention:** run `findmnt --verify` and `mount -a` before every reboot, and add `nofail` for optional mounts.

## 5. Kernel Panic, Missing or Corrupt initramfs **[Production Practice]**

**Typical messages:** `Kernel panic - not syncing: VFS: Unable to mount root fs`, `dracut-initqueue timeout`, dropping into a dracut emergency shell.

### 5.1 Boot another kernel and rebuild

`````text
GRUB menu → choose an older kernel or the "0-rescue" entry
`````

`````bash
rpm -q kernel                                   # installed versions
ls /lib/modules                                 # module trees per version
dracut -f --kver 6.12.0-55.9.1.el10_0.x86_64    # rebuild THAT kernel's initramfs (explicit version!)
dracut -f --regenerate-all                      # or rebuild all
lsinitrd /boot/initramfs-6.12.0-55.9.1.el10_0.x86_64.img | head   # inspect contents
reboot
`````

> ⚠️ Avoid `dracut -f … $(uname -r)` here. When you're booted from the rescue entry or rescue media, `uname -r` reports **that** kernel, not the broken one.

### 5.2 Rescue from installation media

`````text
Boot the RHEL DVD/ISO → Troubleshooting → "Rescue a Red Hat Enterprise Linux system" → 1) Continue
`````

`````bash
chroot /mnt/sysroot             # path is printed by the rescue shell (older releases: /mnt/sysimage)
rpm -q kernel                   # pick the installed version
dracut -f --kver <installed-version>
# GRUB problems: dnf reinstall grub2-efi-x64 shim-x64 ; grub2-mkconfig -o /boot/grub2/grub.cfg (needs repos/media)
# password reset: passwd root ; touch /.autorelabel
exit ; exit                     # leave chroot and the rescue shell → reboot
`````

### 5.3 Capture panics for analysis **[Advanced]**

`kdump` (enabled by default on many installs, `crashkernel=` argument) saves a vmcore to `/var/crash/` when the kernel panics. Analyze with the `crash` tool or send it to Red Hat support.

## 6. RHCSA Exam Focus **[RHCSA Core]**

- Practice §2 until you can do it from memory: **`rd.break` → remount rw → chroot → passwd → touch /.autorelabel → exit, exit**.
- If the exam console uses a serial or cloud image, keep its `console=` arguments when editing.
- After any boot-time fix, confirm the system reaches the **intended default target** after a normal reboot.

## 7. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Can't log in after resetting the password | `/.autorelabel` skipped → `/etc/shadow` has the wrong SELinux label | Repeat with `touch /.autorelabel` (or `restorecon -v /etc/shadow` from a root shell) |
| `passwd: Authentication token manipulation error` | `/sysroot` still read-only, or not chrooted | `mount -o remount,rw /sysroot`; `chroot /sysroot` |
| `rd.break` shell doesn't appear | Edited the wrong line, or typed outside the `linux` line | Append to the end of the `linux …` line |
| "Cannot open access to console, the root account is locked" | Emergency/rescue needs root's password | Use `rd.break` |
| Rescue entry missing | Not generated / removed | Older kernel or installation media |
| Panic persists after `dracut` | Rebuilt the wrong version | `dracut -f --kver <correct version>` |

## 8. Interview Questions

| Question | Answer |
|---|---|
| How do you reset a lost root password on RHEL? | GRUB `e` → `rd.break` → `mount -o remount,rw /sysroot` → `chroot /sysroot` → `passwd` → `touch /.autorelabel` → exit twice. |
| Why `/.autorelabel`? | The new `/etc/shadow` is created without the correct SELinux context; the relabel fixes it so logins work. |
| How do you recover from a missing initramfs? | Boot another kernel or rescue media, then `dracut -f --kver <ver>`. |
| How can you stop a password reset via GRUB on sensitive systems? | Set a GRUB password (`grub2-setpassword`), encrypt disks, and secure firmware/physical access. |

## 9. Course Corrections

| Course | Correction |
|---|---|
| `rd.break` "get a root shell… reset the password" | Must `mount -o remount,rw /sysroot`, `chroot /sysroot` and `touch /.autorelabel` |
| `dracut -f /boot/initramfs-$(uname -r).img $(uname -r)` from rescue | Use the explicit installed version (`--kver`) |
| `chroot /mnt/sysimage` | RHEL 8+ rescue mounts at `/mnt/sysroot` (the shell prints the path) |
| Boot-loop fix via rescue/emergency targets | Needs root's password; use `systemd.unit=multi-user.target` or `rd.break` |
| `init=/bin/bash` only "for RHEL 6" | Still works as an alternative on RHEL 10 |

## 10. Quick Revision

`````
PASSWORD: e → linux … rd.break → Ctrl+X → mount -o remount,rw /sysroot → chroot /sysroot → passwd root → touch /.autorelabel → exit → exit
LOOP: e → systemd.unit=multi-user.target → systemctl set-default multi-user.target
FSTAB: emergency (root pw) or rd.break → fix → daemon-reload → mount -a
PANIC: older/rescue kernel → dracut -f --kver V | media: Troubleshooting → Rescue → chroot /mnt/sysroot
