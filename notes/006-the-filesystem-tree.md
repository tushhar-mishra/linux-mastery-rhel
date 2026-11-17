# 006 · The Filesystem Tree: Where Everything Lives

> **You need first:** [005 · Getting help](005-getting-help.md)
> **Next:** [007 · Files and directories](007-files-and-directories.md)

---

## What it is

Linux keeps **all** files in **one single tree** of folders that starts at **`/`**, called "root" (not to be confused with the root *user*). There are no drive letters like `C:` or `D:`.

- A **directory** is the Linux word for a folder.
- A **path** is the address of a file in the tree, such as `/etc/ssh/sshd_config`. Each `/` separates one directory level.
- A **filesystem** is the way data is organised on a disk (formats like XFS or ext4, topic 047). It also means one formatted disk area.
- **Mounting** means attaching a filesystem (a disk, a USB stick, a network share) at a directory in the tree. That directory is called the **mount point**. After mounting, the disk's contents appear inside that directory (topic 048).

The layout follows the **FHS** (Filesystem Hierarchy Standard), so `/etc`, `/var/log` and `/home` mean the same thing on RHEL, Ubuntu and almost every other distro.

## Why it exists

A standard layout means:
- You always know where to look: config in `/etc`, logs in `/var/log`, programs in `/usr/bin`.
- Packages from different vendors don't collide.
- Admins can put fast-growing parts (like `/var`) on their own disks, so a runaway log file can't fill the whole system.

One tree with mount points means programs don't care which physical disk a file lives on. `/home/alice/report.txt` works the same whether `/home` is a local SSD, a second disk or a network share.

## Analogy

The tree is a **big office building**. `/` is the main entrance. Each floor has a fixed job: `/etc` is the **rules and settings office**, `/var/log` is the **records room**, `/home` holds **private offices** for each employee, `/usr` is the **tool store**, `/tmp` is the **scrap-paper bin**. Mounting a disk is like **connecting an annex building through a door** on one floor. People walk through the door without noticing they've changed buildings.

## How it works inside

### One tree built from many filesystems

At boot, the kernel mounts the main filesystem at `/` (topic 053). Other filesystems are then mounted on top of directories in it: `/boot` from a small partition, maybe `/home` from another disk, and several **virtual filesystems** that live only in RAM and are made by the kernel on the fly.

When a program opens `/home/alice/notes.txt`, the kernel walks the path one part at a time: `/` → `home` → `alice` → `notes.txt`. At each step it checks "is something mounted here?" and, if so, continues inside that filesystem. This lookup is done by the kernel's **VFS** (Virtual File System) layer (topic 094).

### Virtual filesystems: files that aren't on any disk

| Directory | What it really is |
|---|---|
| `/proc` | The kernel's live view of **processes** (running programs) and kernel state. `/proc/cpuinfo`, `/proc/meminfo` and `/proc/<PID>/` are generated when you read them. `/proc/sys/` holds tunable kernel settings (topic 055) |
| `/sys` | A structured view of **devices and drivers** (sysfs). For example, `/sys/class/net/` lists network cards |
| `/dev` | **Device files** (topic 003). `/dev/sda` is a whole disk, `/dev/null` is a black hole that discards everything written to it, `/dev/zero` gives endless zero bytes, `/dev/urandom` gives random bytes. A helper called **udev** creates these files as hardware appears |
| `/run` | Runtime data since boot (process ID files, sockets). It is a **tmpfs** (a filesystem stored in RAM), so it is **empty after every reboot** |

Never back up or copy `/proc`, `/sys`, `/dev` or `/run`. They aren't real data.

### The /usr merge

Long ago `/bin` and `/usr/bin` were separate. Modern distros (RHEL since version 7, Ubuntu since 20.04 for new installs) moved everything into `/usr`. The old names became **symbolic links** (shortcuts, topic 008): `/bin → /usr/bin`, `/sbin → /usr/sbin`, `/lib → /usr/lib`, `/lib64 → /usr/lib64`. This puts the whole operating system in one place (`/usr`), which can be made read-only or swapped out as a unit.

On RHEL 10, `/usr/sbin` is still a separate directory. (Fedora merged it into `/usr/bin`; RHEL 10 did not.)

### Directory reference

| Directory | What goes there | Notes |
|---|---|---|
| `/` | Top of the tree | XFS filesystem on LVM by default on RHEL |
| `/boot` | Kernel files (`vmlinuz-*`), the initramfs (a small start-up filesystem), and bootloader (GRUB) config | Own small partition. Topic 053 |
| `/boot/efi` | EFI System Partition, read by UEFI firmware | Formatted **VFAT** (a FAT filesystem) on UEFI machines |
| `/etc` | **Configuration** for this machine. Almost all plain text | Back up before editing. Some say the name stands for "editable text configuration", but it historically meant "et cetera" |
| `/home` | Users' personal directories (`/home/alice`) | Often its own filesystem in production |
| `/root` | The root user's home directory | Not the same as `/` |
| `/usr` | Installed software: `bin` (programs), `sbin` (admin programs), `lib`/`lib64` (libraries), `share` (docs, man pages, data) | Managed by the package tool. Don't hand-edit |
| `/usr/local` | Software you build or install yourself, outside the package tool | Package updates don't touch it |
| `/opt` | Self-contained third-party apps (`/opt/vendor/app`) | |
| `/var` | **Variable data**: logs, caches, queues, databases, container images | Grows. Often its own filesystem |
| `/var/log` | Log files: `messages` (general), `secure` (logins and authentication), `cron`, `dnf.log`, `audit/audit.log` | **Ubuntu** uses `/var/log/syslog` and `/var/log/auth.log` instead of `messages` and `secure` |
| `/var/lib` | Application state: databases, `containers/` (Podman), `docker/`, `rpm/` | |
| `/var/spool` | Queues: cron jobs, mail, print jobs | |
| `/var/cache` | Downloaded package caches and similar | Safe to clean |
| `/tmp` | Short-lived temporary files. Anyone can write here, but only the owner can delete their own files (the "sticky bit", topic 027) | On RHEL it is on disk by default and cleaned **by age** (not necessarily at reboot). Many other distros make it a RAM tmpfs |
| `/var/tmp` | Temporary files that should survive a reboot | Cleaned by age, more slowly than `/tmp` |
| `/srv` | Data this server serves (web, FTP) | Empty by default |
| `/mnt` | Spot for temporary manual mounts | |
| `/media` | Removable media | GNOME desktops mount USB sticks under `/run/media/<user>/` |

### Important files you'll meet later

| File | Purpose | Topic |
|---|---|---|
| `/etc/os-release` | Which distro and version | 001 |
| `/etc/passwd`, `/etc/shadow`, `/etc/group` | Users, password hashes, groups | 022–024 |
| `/etc/sudoers`, `/etc/sudoers.d/` | Who may act as admin | 028 |
| `/etc/fstab` | Which filesystems to mount at boot | 048 |
| `/etc/hostname`, `/etc/hosts`, `/etc/resolv.conf` | Machine name, static name list, DNS servers | 060, 063 |
| `/etc/ssh/sshd_config` | SSH server settings | 066 |
| `/etc/yum.repos.d/*.repo` | Where to download software (RHEL). Ubuntu: `/etc/apt/sources.list.d/` | 031 |
| `/etc/systemd/system/` | Your own service definitions and overrides | 037 |
| `/etc/selinux/config` | SELinux mode at boot | 072 |

## Commands

```bash
ls /
```
```
afs  bin  boot  dev  etc  home  lib  lib64  media  mnt  opt  proc  root  run  sbin  srv  sys  tmp  usr  var
```
- The top level of the tree.

```bash
ls -ld /bin /sbin /lib /lib64
```
```
lrwxrwxrwx. 1 root root 7 Oct  1 12:00 /bin -> usr/bin
lrwxrwxrwx. 1 root root 8 Oct  1 12:00 /sbin -> usr/sbin
lrwxrwxrwx. 1 root root 7 Oct  1 12:00 /lib -> usr/lib
lrwxrwxrwx. 1 root root 9 Oct  1 12:00 /lib64 -> usr/lib64
```
- `-d` shows the entry itself, not what's inside it. The first letter `l` and the `->` arrow mean **symbolic link**. These are the /usr merge shortcuts.

```bash
df -hT
```
```
Filesystem     Type      Size  Used Avail Use% Mounted on
/dev/sda4      xfs        19G  1.3G   18G   7% /
devtmpfs       devtmpfs  940M     0  940M   0% /dev
tmpfs          tmpfs     972M     0  972M   0% /dev/shm
efivarfs       efivarfs  256K   17K  235K   7% /sys/firmware/efi/efivars
tmpfs          tmpfs     389M   11M  378M   3% /run
tmpfs          tmpfs     1.0M     0  1.0M   0% /run/credentials/systemd-journald.service
/dev/sda3      xfs       960M  138M  823M  15% /boot
/dev/sda2      vfat      200M  9.1M  191M   5% /boot/efi
tmpfs          tmpfs     1.0M     0  1.0M   0% /run/credentials/getty@tty1.service
tmpfs          tmpfs     195M  8.0K  195M   1% /run/user/1000
```
- `df` = **d**isk **f**ree. `-h` = human-readable sizes (G, M). `-T` = show the filesystem type.
- `Filesystem` is where the data comes from. `/dev/sda4` is a disk partition (the Vagrant lab's root). After a normal RHEL install, root usually shows as `/dev/mapper/rhel-root`, an LVM volume (topic 049). `tmpfs`/`devtmpfs` live in RAM. `vfat` on `/boot/efi` is the UEFI system partition (topic 053).
- The small `/run/credentials/…` tmpfs mounts are new in RHEL 10: systemd gives some services a private, in-memory folder for secrets they're handed at start. They're harmless; ignore them when you look for real disks. `efivarfs` exposes the firmware's UEFI variables.
- `Size / Used / Avail / Use%` show space. Watch `Use%`: at 100%, programs fail to write.
- `Mounted on` is the mount point in the tree.
- Tip: `df -hT -x tmpfs -x devtmpfs -x efivarfs` hides the in-memory entries.

```bash
df -i /
```
```
Filesystem      Inodes IUsed   IFree IUse% Mounted on
/dev/sda4      9611776 42355 9569421    1% /
```
- `-i` shows **inodes** instead of bytes. An inode is the record that describes one file (topic 008). Each file uses one. If `IUse%` hits 100%, you can't create files even if bytes are free.

```bash
findmnt /boot
```
```
TARGET SOURCE    FSTYPE OPTIONS
/boot  /dev/sda3 xfs    rw,relatime,seclabel,attr2,inode64,logbufs=8,logbsize=32k,noquota
```
- What is mounted at `/boot`. `rw` = read-write. The other options are covered in topic 048. `findmnt` alone prints the whole mount tree.

```bash
du -xsh /var/* 2>/dev/null | sort -h | tail -5
```
```
24K	/var/tmp
2.0M	/var/log
13M	/var/cache
16M	/var/lib
```
- `du` = **d**isk **u**sage: how much space files take. `-s` = one total per argument, `-h` = human-readable, `-x` = stay on this filesystem (don't count other mounts).
- `2>/dev/null` throws away "permission denied" errors (topic 016). `sort -h` orders by human sizes and `tail -5` keeps the last 5, so the biggest end up at the bottom.

```bash
cat /proc/meminfo | head -3
```
```
MemTotal:        1989028 kB
MemFree:         1443288 kB
MemAvailable:    1561688 kB
```
- A virtual file: the kernel generates these numbers at the moment you read them.

```bash
file /etc/passwd /usr/bin/ls /dev/sda /dev/null
```
```
/etc/passwd: ASCII text
/usr/bin/ls: ELF 64-bit LSB pie executable, x86-64, version 1 (SYSV), dynamically linked, interpreter /lib64/ld-linux-x86-64.so.2, …, stripped
/dev/sda:    block special (8/0)
/dev/null:   character special (1/3)
```
- `file` guesses what a file contains. **ELF** (Executable and Linkable Format) is the Linux program format.
- A **block special** file is a block device, like a disk, read in fixed-size chunks. A **character special** file is a byte-stream device. `(8/0)` are the device's major/minor numbers.

```bash
rpm -qf /etc/ssh/sshd_config
```
```
openssh-server-9.9p1-25.el10_2.alma.1.x86_64
```
- Which installed package owns this file (`-q` query, `-f` file). Ubuntu: `dpkg -S /usr/sbin/sshd` → `openssh-server: /usr/sbin/sshd`. (On Ubuntu, `/etc/ssh/sshd_config` itself belongs to no package: the install script generates it, so `dpkg -S` on it says "no path found".)

### Try it
1. Run `ls /` and match each directory to the table above.
2. Run `df -hT` and find which entries are real disks and which are in RAM.
3. Look at `/proc/cpuinfo` and `/proc/uptime`, then run `cat /proc/uptime` again and see it change.
4. Find which package owns `/usr/bin/ls`.

**Check your work:** on your lab VM, from the notes folder, run `sudo ./checks/check 006` for every step, or `sudo ./checks/check 006 STEP` for one (topic 002 shows how to get the notes there).

## Where you'll use it

- **"Where's the config?"** → `/etc/<app>/`. **"Where are the logs?"** → `/var/log/` or the journal (topic 038). **"Where's the data?"** → `/var/lib/<app>/`.
- **Disk full alerts:** almost always `/var` (logs, container images in `/var/lib/containers` or `/var/lib/docker`) or `/tmp`.
- **Containers and Kubernetes:** a container image is just a small tree like this. Volumes are mounted into it at paths like `/data`. `/proc` and `/sys` inside a container show a restricted view.
- **Production layout:** put `/var`, `/var/log`, `/home` and `/tmp` on separate filesystems, so one runaway log can't fill `/`. Security baselines like **CIS** (Center for Internet Security) require this.
- **Install custom software** in `/opt` or `/usr/local`, never by hand into `/usr/bin`. Package updates would overwrite it, and nobody would know it was there.

## When it breaks

| Symptom | What's happening | What to do |
|---|---|---|
| `No space left on device`, but `df -h` shows free space | **Inodes** are used up (millions of tiny files) | `df -i`. Find the directory with the most files and clean it up |
| `df` says the disk is full, but `du` adds up to much less | A deleted file is still held open by a running program, so its space isn't freed yet (topic 008), or files are hidden under a mount point | `lsof +L1` lists deleted-but-open files (topic 020). Restart the program holding them |
| `/` is full | Usually `/var/log`, `/var/cache/dnf`, crash dumps or container images | `du -xsh /var/* \| sort -h`, then dig into the biggest. `dnf clean all`; `journalctl --vacuum-size=200M` (topic 038) |
| `/boot` is full and a kernel update fails | Too many old kernels kept | Remove old kernels with `dnf` (topic 054). **Never** delete files in `/boot` by hand, and never remove the running kernel (`uname -r`) |
| Files vanish from `/tmp` | Automatic age-based cleanup | Use `/var/tmp` or your own directory for longer-lived files |
| A filesystem suddenly becomes read-only | The kernel detected disk errors and protected the data | `dmesg \| tail` or `journalctl -k` for disk errors; check the storage; repair (topic 051) |

## Quick recap

- One tree from `/`. Disks and shares are **mounted** onto directories; there are no drive letters.
- `/etc` = config, `/var/log` = logs, `/var/lib` = app data, `/home` = users, `/usr` = installed software, `/tmp` = temporary.
- `/proc`, `/sys`, `/dev` and `/run` are virtual, made by the kernel. Never back them up.
- `df -h` (space), `df -i` (inodes), `du` (what uses space) and `findmnt` (what's mounted) are your first disk-checking tools.

**Interview questions**

1. *What's the difference between `/` and `/root`?* `/` is the top of the whole tree. `/root` is the home directory of the root user.
2. *`/proc` vs `/sys`?* Both are virtual filesystems made by the kernel. `/proc` shows processes and kernel settings (`/proc/sys`). `/sys` shows the device and driver model.
3. *`df` says the disk is full but `du` doesn't add up. Why?* Usually a deleted file is still open by a process (find it with `lsof +L1`), or files are hidden underneath a mount point.

**Scenario question** (answer out loud first, then compare)

> *"Monitoring says `/` is 95% full. Walk me through finding what's using the space."*

**Model answer:**
1. `df -hT /` to confirm which filesystem and its size. Also `df -i /`: running out of **inodes** gives "No space left" too.
2. `sudo du -xh --max-depth=1 / | sort -h` (`-x` stays on that filesystem), then drill down into the biggest directory, usually `/var` (logs, caches, containers) or `/home`.
3. If `du`'s total is much smaller than `df`'s, look for **deleted files still held open**: `sudo lsof +L1`. Restart or reload the process that holds them.
4. Also check for files **hidden under a mount point** (written before something was mounted on top).
5. Fix the cause (log rotation, a cache limit), not just this instance.

**Likely follow-ups:**
- *Why not delete files in `/proc` to free space?* `/proc` is virtual: it lives in RAM and uses no disk.
- *Where do logs and application data normally live?* `/var/log` and `/var/lib`, which is why `/var` is often a separate filesystem on servers.
