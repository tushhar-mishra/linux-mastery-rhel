# Filesystem Hierarchy (RHEL 10)

> **Sessions:** S3 · **Verified:** Oct 2026
> **Related:** [SSH](../networking-and-ssh/ssh-remote-access.md) · storage (`storage-and-filesystems/`) · boot (`boot-systemd-and-kernel/`)

## 1. Overview

Linux uses a **single directory tree** rooted at `/`. Disks, partitions, LVs, network shares and virtual filesystems are *mounted* into it. There are no drive letters. Layout follows the **Filesystem Hierarchy Standard (FHS)**, adapted by RHEL. Knowing where configs, logs, binaries and runtime data live is a prerequisite for every exam task and for troubleshooting.

```bash
man hier                 # classic FHS description
man file-hierarchy       # systemd's description (closer to modern RHEL)
```

## 2. Key Concepts

### /usr merge (UsrMove)

Since RHEL 7, the top-level binary and library directories are **symlinks into `/usr`**:

```bash
$ ls -ld /bin /sbin /lib /lib64
lrwxrwxrwx. 1 root root 7 … /bin   -> usr/bin
lrwxrwxrwx. 1 root root 8 … /sbin  -> usr/sbin
lrwxrwxrwx. 1 root root 7 … /lib   -> usr/lib
lrwxrwxrwx. 1 root root 9 … /lib64 -> usr/lib64
```

- `/usr/sbin` **remains a separate directory on RHEL 10**. Fedora merged it into `/usr/bin`; RHEL 10 did not.
- `/var/run` → `/run` and `/var/lock` → `/run/lock` are also symlinks.

### Static vs. variable, shareable vs. local

| | Static | Variable |
|---|---|---|
| **Shareable** | `/usr`, `/opt` | `/var/mail`, `/srv` |
| **Local** | `/etc`, `/boot` | `/var/run` (→ `/run`), `/var/lock` |

This is why `/usr` can be read-only and why `/var` often gets its own filesystem.

## 3. Directory Reference

| Directory | Purpose | RHEL 10 notes |
|---|---|---|
| `/` | Root of the tree | XFS on LVM by default |
| `/boot` | Kernel (`vmlinuz-*`), initramfs, GRUB2 config, BLS entries (`/boot/loader/entries/`) | Separate XFS partition (~1 GiB); **must not be on LVM** in the default layout |
| `/boot/efi` | EFI System Partition | **VFAT**, on UEFI systems |
| `/etc` | Host-specific configuration | Text files; back up before editing |
| `/home` | Regular users' home directories | Often a separate FS in production |
| `/root` | Root user's home | Not the same as `/` |
| `/usr` | Installed software (read-only in principle) | `bin`, `sbin`, `lib`, `lib64`, `libexec`, `share`, `include` |
| `/usr/local` | Locally built software, outside dnf | Not touched by package updates |
| `/usr/share/doc` | Package documentation and examples | **Exam objective**: available offline |
| `/usr/share/man` | Man pages | |
| `/opt` | Third-party self-contained apps | e.g. `/opt/<vendor>/<app>` |
| `/var` | Variable data: logs, caches, spools, databases | Fills up in production; separate FS recommended |
| `/var/log` | Text logs: `messages`, `secure`, `cron`, `maillog`, `boot.log`, `dnf.log`, `audit/audit.log` | There is **no `/var/log/syslog`** on RHEL (that's Debian/Ubuntu) |
| `/var/log/journal` | Persistent systemd journal (if present) | Otherwise the journal is in volatile `/run/log/journal` (see S55) |
| `/var/lib` | Application state (e.g., databases, container storage) | |
| `/var/spool` | Queues: cron jobs, at jobs, mail, print | |
| `/var/tmp` | Temporary files that survive reboot | Age-based cleanup (longer than `/tmp`) |
| `/tmp` | Temporary files, world-writable with **sticky bit** (`1777`) | **On disk by default on RHEL** (not tmpfs); cleaned by age via `systemd-tmpfiles`, not necessarily on reboot |
| `/run` | Runtime data since boot: PID files, sockets, `/run/media/<user>` automounts | **tmpfs**, cleared at every boot |
| `/dev` | Device nodes (devtmpfs, managed by udev) | `sda` (SATA/SCSI/USB), `vda` (virtio VM), `nvme0n1p1` (NVMe), `mapper/*` (LVM/LUKS) |
| `/proc` | Virtual FS: processes and kernel state | `/proc/<PID>/`, `cpuinfo`, `meminfo`, `mounts`, `cmdline`, `/proc/sys/` (sysctl) |
| `/sys` | Virtual FS (sysfs): devices, drivers, kernel objects | `/sys/class/net/`, `/sys/block/` |
| `/media` | Mount points for removable media | GNOME automounts to `/run/media/<user>/<label>` instead |
| `/mnt` | Temporary manual mounts by the admin | |
| `/srv` | Data served by this system (web, FTP) | Empty by default; Apache uses `/var/www` by default |
| `/afs` | Mount point for Andrew File System | Empty unless AFS is used |

### Essential Files

| File | Purpose | Topic note |
|---|---|---|
| `/etc/fstab` | Persistent mounts | storage |
| `/etc/passwd`, `/etc/shadow`, `/etc/group` | Users, password hashes, groups | users |
| `/etc/sudoers`, `/etc/sudoers.d/` | Privileged access (`visudo`) | users |
| `/etc/hostname`, `/etc/hosts`, `/etc/resolv.conf` | Hostname, static names, DNS (resolv.conf is managed by NetworkManager) | networking |
| `/etc/NetworkManager/system-connections/` | Network keyfiles | networking |
| `/etc/ssh/sshd_config`, `/etc/ssh/sshd_config.d/` | SSH server config | [SSH](../networking-and-ssh/ssh-remote-access.md) |
| `/etc/yum.repos.d/*.repo` | Repository definitions | packages |
| `/etc/selinux/config` | SELinux mode at boot | SELinux |
| `/etc/systemd/system/` | Admin unit files and overrides | systemd |
| `/etc/default/grub` | GRUB defaults | boot |
| `/etc/os-release`, `/etc/redhat-release` | OS identification | — |

## 4. Commands

```bash
ls -ld /bin /sbin /lib /lib64     # confirm UsrMove symlinks
readlink -f /bin/ls               # → /usr/bin/ls
findmnt                           # mount tree (source, target, FS type, options)
findmnt /boot                     # what's mounted at /boot
df -hT                            # usage per mounted FS, with type
df -i                             # inode usage (full inodes = "No space left")
lsblk -f                          # block devices, FS, UUID, mount points
du -xsh /var/* 2>/dev/null | sort -h   # largest dirs in /var, same FS only
stat /tmp                         # mode 1777 → sticky bit set
file /etc/passwd /dev/sda /usr/bin/ls  # identify file types
rpm -qf /etc/ssh/sshd_config      # which package owns a file
systemd-tmpfiles --cat-config | grep -E '^[dDqQ] /(var/)?tmp'   # [Advanced] tmp cleanup ages
```

## 5. RHCSA Exam Focus **[RHCSA Core]**

- Know where to edit: `/etc/fstab`, `/etc/yum.repos.d/`, `/etc/ssh/sshd_config.d/`, `/etc/selinux/config`, `/etc/sudoers.d/`, `/etc/hosts`.
- Know where to read: `/var/log/messages`, `/var/log/secure`, `journalctl`, `/usr/share/doc`.
- `/boot/efi` is **VFAT**, a real-world example of a VFAT filesystem objective.
- Use `/mnt` or task-specified mount points; create them with `mkdir -p`.
- `/proc` and `/sys` are virtual: never back them up or copy them.

## 6. Production Practices **[Production Practice]**

- Put `/var`, `/var/log`, `/home` and `/tmp` on **separate filesystems** in production, so a runaway log can't fill `/`. CIS and STIG baselines require this, with `nodev,nosuid,noexec` on `/tmp`.
- Install third-party software in `/opt` or `/usr/local`, never by hand in `/usr/bin`, where it's invisible to `rpm -V` and gets overwritten by updates.
- Keep `/etc` under version control (e.g., etckeeper or Git) on critical hosts.
- Watch both **space and inodes**. Millions of tiny files exhaust inodes while `df -h` looks fine.

## 7. Troubleshooting **[Production Practice]**

| Symptom | Diagnose | Root cause / fix |
|---|---|---|
| "No space left on device" but `df -h` shows free space | `df -i` | Inodes exhausted (many small files, e.g., sessions or cache). Find with `find /path -xdev -type f \| wc -l`; clean up |
| `df` shows full, `du` shows much less | `lsof +L1` | Deleted-but-open files (often rotated logs). Restart the holding process or truncate via `/proc/<pid>/fd/<n>` |
| `/` full | `du -xsh /* \| sort -h` then drill down | Usually `/var/log`, `/var/cache/dnf`, core dumps. `dnf clean all`; `journalctl --vacuum-size=200M` |
| `/boot` full; kernel update fails | `rpm -q kernel`; `df -h /boot` | Too many kernels. `installonly_limit` in `/etc/dnf/dnf.conf` (default 3); remove old kernels with `dnf remove kernel-<old-version>` (**never the running one**: check `uname -r`) |
| Files disappear from `/tmp` | `systemd-tmpfiles --cat-config` | Age-based cleanup. Use `/var/tmp` or a dedicated directory for longer-lived data |
| Filesystem became read-only | `dmesg \| tail`, `journalctl -k` | Kernel remounted it read-only after I/O errors. Check the disk/storage; repair (S48) |

> ⚠️ Run cleanup commands like `rm` against `/var` or `/boot` only after confirming the paths. Never remove the running kernel or `/boot` contents by hand.

## 8. Interview Questions

| Question | Answer |
|---|---|
| `/` vs `/root`? | `/` is the top of the tree; `/root` is root's home directory. |
| `/tmp` vs `/var/tmp`? | Both temporary. `/var/tmp` is meant to survive reboots and has a longer cleanup age. On RHEL, `/tmp` is on disk by default and cleaned by age. |
| `/proc` vs `/sys`? | Both are virtual. `/proc` covers processes and legacy kernel info plus sysctl (`/proc/sys`); `/sys` is the structured device/driver model. |
| Why are `/bin` and `/sbin` symlinks? | UsrMove consolidated the OS into `/usr`, making `/usr` the single, snapshot-able, potentially read-only vendor tree. |
| Disk is full but `du` doesn't add up. Why? | Deleted files still held open by processes, or a mount hiding files underneath. Use `lsof +L1`. |
| Where would you put a custom-built binary? | `/usr/local/bin` (or `/opt/<app>` for self-contained apps). |

## 9. Quick Revision

`/etc` = config · `/var/log` = logs · `/usr/share/doc` = offline docs · `/boot` = kernel + GRUB (`/boot/efi` VFAT) · `/run` = tmpfs runtime · `/proc` and `/sys` virtual · `/bin`→`/usr/bin` · `/usr/sbin` still separate on RHEL 10 · `/tmp` on disk, age-cleaned · `df -i` and `lsof +L1` for "disk full" mysteries.

> ⚠️ **Course corrections applied:**
> - Removed obsolete items from the old diagram: `ifconfig`/`route` (net-tools), `hosts.allow`/`hosts.deny`, `init.d`.
> - `libc.so.6` lives in `/usr/lib64` on x86_64, not `/lib`.
> - `/sbin` binaries are not "root-only."
> - `/var/log/syslog` doesn't exist on RHEL.
> - `/tmp` is not necessarily cleared at reboot.
> - `/media/cdrom` and `/media/usb` aren't created by default.
