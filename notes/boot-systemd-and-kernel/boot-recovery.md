# Boot Recovery: Root Password Reset, GRUB Password, Boot Loops, Broken fstab, Kernel Panic

> **Objective:** *Interrupt the boot process in order to gain access to a system* **[RHCSA Core]**
> **Related:** [Boot process](boot-process.md) · [systemd targets & services](systemd-targets-and-services.md) · [GRUB2 & kernel management](grub2-and-kernel-management.md) · [Mounting & fstab](../storage-and-filesystems/mounting-and-fstab.md) · [Filesystem check & repair](../storage-and-filesystems/filesystem-check-and-repair.md) · [LVM fundamentals](../storage-and-filesystems/lvm-fundamentals.md)

## 1. Overview

When a system won't boot or you can't log in, choose the least invasive entry point:

| Situation | Entry point |
|---|---|
| Forgotten/locked root password | **`rd.break`** (initramfs shell, no password), or `init=/bin/bash` |
| Root password lost **and** GRUB is password-protected (password unknown) | **Installation media → Troubleshooting → Rescue** |
| Wrong default target (boot loop) | GRUB `e` → `systemd.unit=multi-user.target` |
| Broken `/etc/fstab`, failed mount | Emergency shell (root password) or `rd.break` |
| Latest kernel panics | Older kernel or **rescue** entry in the GRUB menu |
| Missing/corrupt initramfs | Rescue entry or older kernel → `dracut` |
| GRUB/ESP broken, nothing boots | Installation media → Rescue |

> **RHEL 10:** root is disabled by default, so emergency/rescue targets may refuse access ("root account is locked"). `rd.break`, `init=/bin/bash` and installation-media rescue don't need root's password. Interrupting the boot needs console access: physical, VM console, serial, or out-of-band (iLO/iDRAC).

## 2. Reset the Root Password **[RHCSA Core]**

### 2.1 Method A: `rd.break` (preferred)

```text
1. Reboot. At the GRUB menu press any arrow key to stop the countdown, select the entry, press  e
2. On the line starting with  linux  append:  rd.break
   (optionally remove "rhgb quiet" to see messages; on serial/cloud consoles keep the right console=)
3. Ctrl+X to boot → you get:  switch_root:/#
```

```bash
mount -o remount,rw /sysroot     # real root is mounted READ-ONLY at /sysroot
chroot /sysroot                  # work inside the installed system
passwd root                      # set a new password (also unlocks a disabled root)
touch /.autorelabel              # ESSENTIAL: SELinux relabel on next boot (/etc/shadow lost its context)
exit                             # leave chroot
exit                             # continue boot (relabel runs, then the system reboots by itself)
```

The relabel can take minutes and reboots automatically. Then log in as root with the new password.

### 2.2 Method B: `init=/bin/bash`

```text
GRUB → e → at the end of the  linux  line append:  rw init=/bin/bash   → Ctrl+X
```

```bash
# (if "rw" wasn't added: mount -o remount,rw /)
passwd root
touch /.autorelabel
exec /sbin/init            # continue normal boot (relabel, then reboot)
#   or: sync ; /usr/sbin/reboot -f
```

> ⚠️ `shutdown -r now` / `systemctl reboot` don't work here: systemd isn't running as PID 1.

## 3. GRUB Password (protecting the boot menu)

A GRUB password stops people with console access from editing boot entries (`e`) or using the GRUB command line (`c`), which blocks the `rd.break` / `init=/bin/bash` routes. **Booting the normal entries stays unrestricted.**

```bash
ls -l /boot/grub2/user.cfg        # absent = no GRUB password
grub2-setpassword                 # prompts twice; stores a PBKDF2 hash in /boot/grub2/user.cfg (user "root")
cat /boot/grub2/user.cfg          # GRUB2_PASSWORD=grub.pbkdf2.sha512.10000.…
reboot                            # at the menu: e or c → asks for username root + GRUB password
```

**Remove it:**

```bash
cp /boot/grub2/user.cfg /root/user.cfg.bak ; rm -f /boot/grub2/user.cfg
```

- On RHEL 9/10 the file is `/boot/grub2/user.cfg` on both BIOS and UEFI; `grub2-mkconfig` isn't needed after setting or removing it.
- **Limits:** it doesn't stop booting from other media or removing the disk. Combine it with a firmware (BIOS/UEFI) password, Secure Boot and disk encryption (LUKS).

**Resetting the root password on a GRUB-protected system:**

- If you know the GRUB password, authenticate at `e`, then use §2.
- If you don't, use installation media (§6.2).

## 4. Fix a Boot Loop (default = reboot.target)

```text
GRUB → e → append to the linux line:  systemd.unit=multi-user.target  → Ctrl+X
```

```bash
systemctl set-default multi-user.target     # or graphical.target
systemctl get-default ; reboot
```

## 5. Fix a Broken `/etc/fstab`

**Symptom:** "You are in emergency mode… Give root password for maintenance", often after a typo or a missing disk.

- **With root's password:** log in, then `mount -o remount,rw /`, `vi /etc/fstab`, `systemctl daemon-reload`, `mount -a`, `reboot`.
- **Without it:** use the `rd.break` route (§2.1): `mount -o remount,rw /sysroot` → `chroot /sysroot` → `vi /etc/fstab` → `touch /.autorelabel` → `exit` ×2.

**Prevention:** run `findmnt --verify` and `mount -a` before every reboot, and add `nofail` for optional mounts.

## 6. Kernel Panic, Missing initramfs, Rescue Media **[Production Practice]**

**Typical messages:** `Kernel panic - not syncing: VFS: Unable to mount root fs`, `dracut-initqueue timeout`, dropping into a dracut emergency shell.

### 6.1 Boot another kernel and rebuild

```text
GRUB menu → choose an older kernel or the "0-rescue" entry
```

```bash
rpm -q kernel                                   # installed versions
ls /lib/modules                                 # module trees per version
dracut -f --kver 6.12.0-55.9.1.el10_0.x86_64    # rebuild THAT kernel's initramfs (explicit version!)
dracut -f --regenerate-all                      # or rebuild all
lsinitrd /boot/initramfs-6.12.0-55.9.1.el10_0.x86_64.img | head   # inspect contents
reboot
```

> ⚠️ Avoid `dracut -f … $(uname -r)` here. When you're booted from the rescue entry or rescue media, `uname -r` reports **that** kernel, not the broken one.

### 6.2 Rescue from installation media

```text
Boot the RHEL DVD/ISO → Troubleshooting → "Rescue a Red Hat Enterprise Linux system"
   1) Continue        → system mounted read-write at /mnt/sysroot (simplest)
   2) Read-only mount
   3) Skip to shell   → mount it yourself (below)
```

**Option 1 (Continue):**

```bash
chroot /mnt/sysroot
passwd root ; touch /.autorelabel                    # password reset
rpm -q kernel ; dracut -f --kver <installed-version> # initramfs repair
rm -f /boot/grub2/user.cfg                           # (only if you must remove an unknown GRUB password)
exit ; exit                                          # leave chroot and rescue shell → reboot (remove the ISO)
```

**Option 3 (Skip to shell), manual:**

```bash
vgscan ; vgchange -ay ; lvscan                       # activate LVM (default RHEL layout: rhel/root)
mkdir -p /mnt/sysroot
mount /dev/mapper/rhel-root /mnt/sysroot
mount /dev/sda2 /mnt/sysroot/boot                    # if /boot must be changed (check lsblk)
chroot /mnt/sysroot
passwd root ; touch /.autorelabel ; exit
umount -R /mnt/sysroot ; reboot
```

GRUB repair from rescue: `dnf reinstall grub2-efi-x64 shim-x64` (UEFI) or `grub2-install /dev/sda` (BIOS), then `grub2-mkconfig -o /boot/grub2/grub.cfg` (needs repos/media).

### 6.3 Capture panics for analysis **[Advanced]**

`kdump` (enabled by default on many installs, `crashkernel=` argument) saves a vmcore to `/var/crash/` when the kernel panics. Analyze with the `crash` tool or send it to Red Hat support.

## 7. RHCSA Exam Focus **[RHCSA Core]**

- Practice §2.1 until you can do it from memory: **`rd.break` → remount rw → chroot → passwd → touch /.autorelabel → exit, exit**.
- If the exam console uses a serial or cloud image, keep its `console=` arguments when editing.
- After any boot-time fix, confirm the system reaches the **intended default target** after a normal reboot.

## 8. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Can't log in after resetting the password | `/.autorelabel` skipped → `/etc/shadow` has the wrong SELinux label | Repeat with `touch /.autorelabel` (or `restorecon -v /etc/shadow` from a root shell) |
| `passwd: Authentication token manipulation error` | `/sysroot` still read-only, or not chrooted | `mount -o remount,rw /sysroot`; `chroot /sysroot` |
| `rd.break` shell doesn't appear | Edited the wrong line, or typed outside the `linux` line | Append to the end of the `linux …` line |
| "Cannot open access to console, the root account is locked" | Emergency/rescue needs root's password | Use `rd.break` |
| `e` asks for username/password | GRUB password set | Enter it, or use installation media |
| `System has not been booted with systemd…` after `init=/bin/bash` | systemd isn't PID 1 | `exec /sbin/init` or `reboot -f` |
| Rescue entry missing | Not generated / removed | Older kernel or installation media |
| Panic persists after `dracut` | Rebuilt the wrong version | `dracut -f --kver <correct version>` |

## 9. Interview Questions

| Question | Answer |
|---|---|
| How do you reset a lost root password on RHEL? | GRUB `e` → `rd.break` → `mount -o remount,rw /sysroot` → `chroot /sysroot` → `passwd` → `touch /.autorelabel` → exit twice. |
| Why `/.autorelabel`? | The new `/etc/shadow` is created without the correct SELinux context; the relabel fixes it so logins work. |
| How do you stop console users from doing that? | GRUB password (`grub2-setpassword`), firmware password, Secure Boot, LUKS, physical security. |
| GRUB password unknown and root password lost? | Boot installation media → Rescue → chroot → passwd → autorelabel. |
| How do you recover from a missing initramfs? | Boot another kernel or rescue media, then `dracut -f --kver <ver>`. |

## 10. Quick Revision

````
PASSWORD: e → linux … rd.break → Ctrl+X → mount -o remount,rw /sysroot → chroot /sysroot → passwd root → touch /.autorelabel → exit → exit
ALT: linux … rw init=/bin/bash → passwd → touch /.autorelabel → exec /sbin/init
GRUB PW: grub2-setpassword → /boot/grub2/user.cfg · remove: rm user.cfg
LOOP: e → systemd.unit=multi-user.target → systemctl set-default multi-user.target
FSTAB: emergency (root pw) or rd.break → fix → daemon-reload → mount -a
PANIC: older/rescue kernel → dracut -f --kver V | media: Troubleshooting → Rescue → 1) Continue → chroot /mnt/sysroot
````

## 11. Cross-References

- [Boot process](boot-process.md)
- [systemd targets & services](systemd-targets-and-services.md)
- [GRUB2 & kernel management](grub2-and-kernel-management.md)
- [Mounting & fstab](../storage-and-filesystems/mounting-and-fstab.md)
- [Filesystem check & repair](../storage-and-filesystems/filesystem-check-and-repair.md)
- [LVM fundamentals](../storage-and-filesystems/lvm-fundamentals.md)
