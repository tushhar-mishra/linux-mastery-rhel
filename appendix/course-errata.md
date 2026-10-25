# Appendix: Course Errata

> Corrections to the source course's slides and examples, moved out of the individual notes so the notes read as a
> clean reference. Each note's content already reflects these corrections; this appendix records **what the course
> said** and **why it was changed**, which is useful if you study from the original course materials.
> Inline `⚠️ Course correction` callouts that explain a common misconception were kept inside the notes.

## Command Line Assistant (RHEL Lightspeed)

Note: [`advanced-rhel-and-career-notes/rhel-lightspeed-command-line-assistant.md`](../advanced-rhel-and-career-notes/rhel-lightspeed-command-line-assistant.md)

| Course | Correction |
|---|---|
| Presented as a general troubleshooting tool | Not available in the exam environment; verify outputs; don't send sensitive data |
| Exact subcommands (`chat --interactive`, `-a a,b`, `history --filter`) | Syntax varies by version; check `c --help` |

## Arithmetic in Bash: $(( )), let, expr & bc

Note: [`bash-scripting-and-automation/arithmetic.md`](../bash-scripting-and-automation/arithmetic.md)

| Course | Correction |
|---|---|
| "Modulus doesn't work with decimals in bc" | Works with `scale=0` (`22.5 % 8.5` → 5.5); with `bc -l` the result is ~0 |
| `pi=$(echo "h=10;4*a(1)" \| bc -l)` | `scale=10` was intended; `h=10` just sets an unused variable |
| ``x=`echo "12+5" \| bc` `` | `x=$(echo "12+5" \| bc)` |
| `($num2)^($num1)` with decimals | bc `^` needs an integer exponent |
| Calculator without input validation / divide-by-zero check | Validate input; guard against 0 |

## Conditionals: if/elif/else, test, [[ ]], File Tests & case

Note: [`bash-scripting-and-automation/conditionals-and-tests.md`](../bash-scripting-and-automation/conditionals-and-tests.md)

| Course | Correction |
|---|---|
| `if [20 -eq 12]`, `if [$num -gt 25]` … | Spaces required inside brackets |
| `[ -e $filename ]` (unquoted) throughout file tests | Quote; empty input wrongly reports "exists" |
| `[ $var1 == $var2 ]` | `[ "$var1" = "$var2" ]` |
| "You MUST quote the right side" for `<`/`>` | Quoting matters for `==` patterns; `<`/`>` compare either way |
| `-a` / `-o` as alternatives | Obsolescent; use `&&`/`\|\|` |
| `echo -e "…\c"` prompts | `read -rp "…"` |

## Loops: for, while, until, break/continue & Processing Input

Note: [`bash-scripting-and-automation/loops.md`](../bash-scripting-and-automation/loops.md)

| Course | Correction |
|---|---|
| `for file in *.txt` without a guard | Add `[ -e "$file" ] \|\| continue` |
| `while [ $i -le 5 ]` (unquoted) | Quote, or use `(( i <= 5 ))` |
| No `break`/`continue`, file-processing or pipe-subshell coverage | Added (exam objective: process files and command-line input) |

## Bash Scripting Basics: Scripts, Shebang, Output & Variables

Note: [`bash-scripting-and-automation/script-basics-and-variables.md`](../bash-scripting-and-automation/script-basics-and-variables.md)

| Course | Correction |
|---|---|
| `echo $SHELL` = "shell you are currently using" | Login shell; use `ps -p $$ -o comm=` |
| `#!/bin/sh` = "Bourne shell" | On RHEL it's bash in POSIX mode |
| "System vs user-defined variables" | The real distinction is shell (local) vs exported (environment) |
| "Errors in one line don't prevent others" | Syntax errors abort the whole block; use `bash -n`, `set -e` |
| ``x=`cmd` `` | Prefer `x=$(cmd)` |

## Script Input: read, Positional Parameters & Argument Handling

Note: [`bash-scripting-and-automation/script-input-and-arguments.md`](../bash-scripting-and-automation/script-input-and-arguments.md)

| Course | Correction |
|---|---|
| `read name` everywhere | `read -r` (and `IFS= read -r` for full lines) |
| `$@` "as a list" vs `$*` "as a single string" | Only true when quoted |
| `echo "Password: $password"` in examples | Never print secrets (demo only) |
| backup.sh copies without checking the destination | Check `[ -d "$dest" ]`; errors to stderr; non-zero exit |
| Hard-coded `admin`/`1234` in login.sh | Demo only; never store credentials in scripts |

## The RHEL 10 Boot Process

Note: [`boot-systemd-and-kernel/boot-process.md`](../boot-systemd-and-kernel/boot-process.md)

| Course | Correction |
|---|---|
| "UEFI verifies GRUB" | Firmware verifies **shim**, which verifies GRUB/kernel |
| Kernel examples `5.14.0-362.el10` | RHEL 9 kernel; RHEL 10 is 6.12 (`6.12.0-55.9.1.el10_0` as in the slides) |
| "initramfs drivers for all hardware" | Only what's needed to mount root; the rest load later via udev |
| "Switch from initramfs root (/sysroot) to /" | Real root is mounted at `/sysroot` and becomes `/` |
| "7 targets" | 7 runlevel compatibility links; systemd has many targets |
| "Secure Boot enabled by default", "systemd-boot" in RHEL 10 | Secure Boot is a firmware setting; GRUB2 is RHEL's standard bootloader |
| Wayland/GDM `WaylandEnable=false` | Xorg server is removed in RHEL 10; no Xorg session to fall back to |

## Boot Recovery: Root Password Reset, GRUB Password, Boot Loops, Broken fstab, Kernel Panic

Note: [`boot-systemd-and-kernel/boot-recovery.md`](../boot-systemd-and-kernel/boot-recovery.md)

| Course | Correction |
|---|---|
| `rd.break` "get a root shell… reset the password" | Must `mount -o remount,rw /sysroot`, `chroot /sysroot` and `touch /.autorelabel` |
| `init=/bin/bash` then `exec /sbin/shutdown -r now` | systemd isn't running; `exec /sbin/init` or `reboot -f` |
| `init=/bin/bash` only "for RHEL 6" | Still works as an alternative on RHEL 10 |
| Rescue ISO "press 3 (Continue)" | 3 = Skip to shell; 1 = Continue (auto-mount at `/mnt/sysroot`) |
| `chroot /mnt/sysimage` | RHEL 8+ rescue mounts at `/mnt/sysroot` |
| GRUB password: `grub2-mkconfig` "for BIOS systems" | Not needed after `grub2-setpassword`; `/boot/grub2/grub.cfg` is used on BIOS and UEFI |
| `dracut -f /boot/initramfs-$(uname -r).img $(uname -r)` from rescue | Use the explicit installed version (`--kver`) |
| Boot-loop fix via rescue/emergency targets | Needs root's password; use `systemd.unit=multi-user.target` or `rd.break` |

## GRUB2, Kernel Arguments & Kernel Packages

Note: [`boot-systemd-and-kernel/grub2-and-kernel-management.md`](../boot-systemd-and-kernel/grub2-and-kernel-management.md)

| Course | Correction |
|---|---|
| `grub2-mkconfig -o /boot/efi/EFI/redhat/grub.cfg` for UEFI | Use `/boot/grub2/grub.cfg` for both on RHEL 9/10 |
| `awk -F\' '$1=="menuentry " …' /etc/grub2.cfg` / `grep '^menuentry'` | No menuentry lines with BLS; use `grubby --info=ALL` |
| `update-grub` | Ubuntu command; RHEL: `grubby` / `grub2-mkconfig` |
| `GRUB_CMDLINE_LINUX="quiet splash …"` | RHEL default is `rhgb quiet` |
| `dnf install kernel-5.14.0-162.6.1.el10` | 5.14 is RHEL 9; RHEL 10 kernels are 6.12 |
| `kernel-abi-whitelists` | Renamed `kernel-abi-stablelists` |
| `kernel-tools` includes `tuned-adm`, `perf` | Those come from `tuned` and `perf` packages |

## Compiling a Custom Kernel

Note: [`boot-systemd-and-kernel/kernel-compilation.md`](../boot-systemd-and-kernel/kernel-compilation.md)

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

## Kernel Modules & Kernel Parameters (sysctl)

Note: [`boot-systemd-and-kernel/kernel-modules-and-parameters.md`](../boot-systemd-and-kernel/kernel-modules-and-parameters.md)

| Course | Correction |
|---|---|
| `/etc/modules` for boot loading | Debian; RHEL uses `/etc/modules-load.d/*.conf` |
| `blacklist` "prevents loading" | Only automatic loading; add `install … /bin/false` |
| `modules_disabled` as a toggle | One-way until reboot |
| `update-grub` / "quiet splash" | Ubuntu; RHEL uses `grubby` and `rhgb quiet` |
| `MODULE_LICENSE("Proprietary")`, `init_module()`/`cleanup_module()` | Use `"GPL"` and `module_init()`/`module_exit()` |
| `ftp ftp.kernel.org` | FTP service retired; use https://www.kernel.org |
| `yum install kernel-devel kernel-headers` | `dnf install kernel-devel-$(uname -r) kernel-headers` |

## systemd Targets & Service Management

Note: [`boot-systemd-and-kernel/systemd-targets-and-services.md`](../boot-systemd-and-kernel/systemd-targets-and-services.md)

| Course | Correction |
|---|---|
| "Runlevel 2 = multi-user, no network" | On RHEL, runlevels 2/3/4 all map to `multi-user.target` |
| Boot-loop fix via `rescue.target` / `emergency.target` | Needs root's password (locked by default on RHEL 10); `systemd.unit=multi-user.target` is simpler |
| "Find the line starting with linux or linux16" | RHEL 10 uses `linux`; `linux16` was BIOS-era |
| Chroot from live media to fix `default.target` | Works, but the GRUB override is faster |

## Cockpit: The RHEL Web Console

Note: [`containers-and-virtualization/cockpit-web-console.md`](../containers-and-virtualization/cockpit-web-console.md)

| Course | Correction |
|---|---|
| Install + open firewall as required steps | Usually preinstalled; `cockpit` already allowed in the public zone |
| "Login as root" | root is in `/etc/cockpit/disallowed-users`; use a sudo user |
| "Add New Host" from the host selector | Deprecated and disabled by default in RHEL 10 |
| RHEL 8 docs references | RHEL 10 web console documentation applies |

## RHEL Image Builder (osbuild-composer)

Note: [`containers-and-virtualization/image-builder.md`](../containers-and-virtualization/image-builder.md)

| Course | Correction |
|---|---|
| `composer-cli compose download <UUID>` | No such command; `composer-cli compose image <UUID>` |
| `net-tools` in the blueprint | Deprecated; use `iproute` tools |
| Password hash in the blueprint with the clear-text password in a comment | Never record the clear-text password; prefer SSH keys |
| `edge-installer.iso` as an example type | RHEL for Edge types belong to RHEL 8/9; check `compose types` |

## KVM Virtualization on RHEL 10 (libvirt, virsh, virt-install, Cockpit)

Note: [`containers-and-virtualization/kvm-virtualization.md`](../containers-and-virtualization/kvm-virtualization.md)

| Course | Correction |
|---|---|
| "Developed by Red Hat" | Developed by Qumranet (acquired by Red Hat 2008) |
| `systemctl enable --now libvirtd virtqemud` | Use modular daemons; `libvirtd` is deprecated |
| `egrep -c '(vmx\|svm)'` | `grep -Ec` |
| `virt-install --ram … --cdrom ubuntu … --disk rhel10-vm…` | `--memory`, add `--osinfo`, consistent names |
| `--graphics vnc,listen=0.0.0.0` | `listen=127.0.0.1` |
| Kickstart `ks=http://…` | `inst.ks=` |
| `virsh undefine --remove-all-storage` | Add `--nvram` for UEFI VMs |
| Xen table: "AWS → Xen" | AWS Nitro is KVM-based |
| RHEL 7.3 installer and RHV/VDSM diagram | Outdated; RHV reached end of life |
| virt-manager as the GUI | Deprecated in RHEL 10; use the web console |

## Podman Containers on RHEL 10

Note: [`containers-and-virtualization/podman-containers.md`](../containers-and-virtualization/podman-containers.md)

| Course | Correction |
|---|---|
| "Podman version 3+ / Podman2" | RHEL 10 ships Podman 5.x |
| CNI "still supported"; rootless via slirp4netns | Podman 5: netavark only; rootless default networking is pasta |
| "Rootless is the default mode on RHEL 10" | Depends on who runs podman |
| `/run/user/1000` fix by `chown` + exporting `XDG_RUNTIME_DIR` | Use a real login session |
| `yum module install container-tools` (RHEL 8 & 9) | No module on RHEL 9/10: `dnf install container-tools` |
| `subscription-manager attach --auto` | Not needed (Simple Content Access) |
| `-v /html/:/usr/local/apache2/htdocs/` | Add `:Z` |
| `podman stop -a` / `rm -a` "for pods" | `podman pod stop -a` / `podman pod rm -a` |
| `podman generate systemd … --new` while the container still exists | Deprecated; use Quadlet; remove the manual container first |
| `journalctl --user` run as root | Run as the user |
| `podman generate kube` | `podman kube generate` |
| `buildah bud`; `yum` inside images; UBI 8 images; short names | `buildah build`; `dnf`/`microdnf`; UBI 10; fully qualified names |
| Rootless "cannot mount container filesystems" | `podman unshare podman mount` |
| Third-party rsyslog images | Prefer trusted images (UBI, official) |

## Tuning Profiles with tuned

Note: [`containers-and-virtualization/tuned-profiles.md`](../containers-and-virtualization/tuned-profiles.md)

| Course | Correction |
|---|---|
| Tuned "dynamically adjusts settings" by default | Dynamic tuning is disabled by default |
| `[vm] swappiness=10` | Use `[sysctl] vm.swappiness=10` |
| `sudo` for `tuned-adm active/list/recommend` | Not required (needed for changes) |
| "Fix verify mismatch with `sysctl -w`" | Find what overrides the setting; `sysctl -w` is only temporary |
| `systemctl restart tuned` to see a new profile | Not required; `tuned-adm list` reads profiles directly |

## Hardware Virtualization vs Containers (OS Virtualization)

Note: [`containers-and-virtualization/virtualization-vs-containers.md`](../containers-and-virtualization/virtualization-vs-containers.md)

| Course | Correction |
|---|---|
| "Kubernetes" listed among container engines | It's an orchestrator |
| Type 1 diagram with a host OS beneath the hypervisor | That layout describes Type 2 (or KVM, where Linux *is* the hypervisor) |
| Containers "medium isolation" without explanation | Shared kernel is the key limitation; SELinux/seccomp/user namespaces mitigate it |

## awk

Note: [`files-and-text-processing/awk.md`](../files-and-text-processing/awk.md)

- `awk '$2 > 25' data.txt` also prints the **header** (string comparison). Use `NR>1 && $2 > 25`.
- `awk '$9 == 404 …' access.log` assumes the Apache/Nginx combined log format.
- `dmesg` may require root, depending on `kernel.dmesg_restrict`.

## Finding Files: `find` & `locate`

Note: [`files-and-text-processing/finding-files.md`](../files-and-text-processing/finding-files.md)

- `-size -500k` effectively means ≤ 499 KiB (rounding up), and `-size 100k` means "rounds up to exactly 100 KiB," not "exactly 100 KB."
- `-mtime +7` means 8 or more days, not "more than 7."
- `find … | xargs rm -f` breaks on filenames with spaces; `-exec … {} +` is equally efficient.
- `find /var/log -name "*.log" -mtime +7 -exec rm …` is risky in production; use logrotate.

## firewalld: Zones, Services, Ports, NAT & Rich Rules

Note: [`firewall-and-selinux/firewalld.md`](../firewall-and-selinux/firewalld.md)

| Course | Correction |
|---|---|
| RHEL 8/9/10 "no support for iptables" | RHEL 8/9 ship an iptables-nft compatibility command (deprecated in 9); use firewall-cmd/nft |
| RHEL 7: "remove firewalld to use iptables" | Install `iptables-services` and mask firewalld |
| "XDP … under firewalld in RHEL 10" | firewalld manages nftables; XDP is separate eBPF technology |
| `--change-interface` without `--permanent` | Runtime only; use `nmcli … connection.zone` |
| Ports "1024–65535 unreserved" | Registered 1024–49151, dynamic 49152–65535 |
| `dnf remove firewalld` exercise | Lab only; don't remove on servers |
| ICMP block inversion "reverses allow/block" | With an empty block list it **rejects all ICMP**; listed types become allowed |

## SELinux Booleans, Port Labels & Troubleshooting

Note: [`firewall-and-selinux/selinux-booleans-ports-troubleshooting.md`](../firewall-and-selinux/selinux-booleans-ports-troubleshooting.md)

| Course | Correction |
|---|---|
| Port labels not covered | Added (§3), an exam objective |
| `dnf install setroubleshoot` for sealert | The tool is in `setroubleshoot-server` |
| `policycoreutils-python` | `policycoreutils-python-utils` |
| `policycoreutils-gui` / `system-config-selinux` | May not be available on RHEL 10; use CLI tools |

## SELinux Targeted Policy: Confined Domains & Confined Users

Note: [`firewall-and-selinux/selinux-confined-users-and-domains.md`](../firewall-and-selinux/selinux-confined-users-and-domains.md)

| Course | Correction |
|---|---|
| staff_u + sudo shows `staff_u:staff_r:staff_t` after `sudo -i` | Expected `staff_u:sysadm_r:sysadm_t`; that output means the transition failed |
| `__default__ → user_u` affects "newly created users" | Affects all users without explicit mappings (existing users at next login) |
| No warning about admins | Map admins explicitly first; `user_u` can't su/sudo |
| Table: `root` SELinux user used for the root account | The root login maps to `unconfined_u` by default |
| `adduser` | Same as `useradd` on RHEL |
| Relabeling `/usr/sbin/httpd` to `bin_t` | Demo only; restore immediately |

## SELinux File Contexts: chcon, semanage fcontext & restorecon

Note: [`firewall-and-selinux/selinux-file-contexts.md`](../firewall-and-selinux/selinux-file-contexts.md)

| Course | Correction |
|---|---|
| `chcon` = "temporary (non-persistent)" | Survives reboot but is undone by `restorecon`/relabel |
| `ls -lZ /testdir/file.txt` → `user_home_t` | A new top-level `/testdir` is `default_t` (no rule) |
| tar without `--selinux` → "may revert to default_t" | Files get the default label for their location |
| `star` for SELinux-aware archives | May not be in RHEL 10 repos; use `tar --selinux --xattrs` |
| `policycoreutils-python`, `libselinux-python` | `policycoreutils-python-utils`, `python3-libselinux` |

## SELinux Fundamentals: Modes, Contexts & Domain Transitions

Note: [`firewall-and-selinux/selinux-fundamentals.md`](../firewall-and-selinux/selinux-fundamentals.md)

| Course | Correction |
|---|---|
| Disabled = "edit /etc/selinux/config" | On RHEL 9/10 use the `selinux=0` kernel argument to fully disable; relabel when re-enabling |
| `dnf install selinux-policy … policycoreutils` | Already installed; `semanage` needs `policycoreutils-python-utils`, `sealert` needs `setroubleshoot-server` |
| Staff mapping Step 4 "verify in a new SSH session" using `su - student` | `su` inherits the caller's context; use `ssh student@localhost` |
| "unconfined_t by default on Fedora" | Same on RHEL (targeted policy) |
| `semanage login -m` for a new user | `-a` adds; `-m` modifies an existing mapping |

## SELinux MLS & MCS (Security Levels and Categories)

Note: [`firewall-and-selinux/selinux-mls-and-mcs.md`](../firewall-and-selinux/selinux-mls-and-mcs.md)

| Course | Correction |
|---|---|
| Alice "categories {ProjectA, Engineering}" with range `s2:c100` | Two categories need two category numbers (e.g., `s2:c100,c101`) |
| Bob "categories {Engineering}" with range `s1` | `s1` has no categories; use `s1:c101` |
| MLS presented without MCS | Targeted policy uses MCS by default (containers, VMs) |
| Enabling MLS steps | Add `fixfiles -F onboot` (or `/.autorelabel`) and user range mappings; test environment only |

## Flatpak on RHEL 10

Note: [`logs-scheduling-and-packages/flatpak.md`](../logs-scheduling-and-packages/flatpak.md)

| Course | Correction |
|---|---|
| "RHEL Workstation may have the Fedora remote" | RHEL provides the `rhel` remote (`redhat-flatpak-repo`) |
| `flatpak export …` / install from the exported path | No such command; offline transfer: `flatpak create-usb` or `flatpak build-bundle` [Advanced] |
| `flatpak --default-system=true` / `--default-user=true` | Not real options; system scope is the default, `--user` selects user scope |
| Q14: `flatpak uninstall --unused` removes VLC and its deps | Uninstall VLC first, then `--unused` |
| Flathub URL `https://flathub.org/repo/flathub.flatpakrepo` | Canonical: `https://dl.flathub.org/repo/flathub.flatpakrepo` |

## Job Scheduling: at, batch, cron, anacron & systemd Timers

Note: [`logs-scheduling-and-packages/job-scheduling.md`](../logs-scheduling-and-packages/job-scheduling.md)

| Course | Correction |
|---|---|
| `@weekly` = `0 0 * * mon` | `0 0 * * 0` (Sunday) |
| `/var/spool/at` "legacy directory" | It's the active at spool on RHEL 10 |
| `rm -rf /tmp/*` in the at example | Unnecessary and dangerous; removed |
| Only `.deny` files explained | `.allow` files take precedence |
| `/etc/crontab` example lines | Need a user field (also in `/etc/cron.d/`) |
| anacron "runs via systemd timer or cron" | On RHEL: `/etc/cron.hourly/0anacron` |
| systemd timers not covered | Added (exam objective) |

## RPM & DNF Package Management

Note: [`logs-scheduling-and-packages/rpm-and-dnf-package-management.md`](../logs-scheduling-and-packages/rpm-and-dnf-package-management.md)

| Course | Correction |
|---|---|
| `dnf module list/enable` as a feature | No modularity on RHEL 10 |
| `yum update all` | Not a command; `dnf upgrade` |
| `yum upgrade` "also removes obsoletes, update doesn't" | In dnf they're the same command |
| `yum upgrade –refresh` | `dnf upgrade --refresh` |
| `rpm -e package.rpm` | `rpm -e <name>` |
| `mount -o loop /dev/sr0 /mnt` | `-o loop` is for ISO files; `mount -o ro /dev/sr0 /mnt` |
| `yum grouplist` / `groupinstall` | `dnf group list` / `dnf group install` |
| `--exclude=openssh*` | Quote it: `--exclude='openssh*'` |
| `subscription-manager attach --auto` / `--pool` | Not needed with Simple Content Access |
| `rhel-9-for-x86_64-…-rpms` | RHEL 10: `rhel-10-for-x86_64-baseos-rpms` / `…-appstream-rpms` |
| Repo name "Red Hat Enterprise Linux 9" / expected `LocalRepo` | Inconsistent with the repo defined; names are free text, IDs must match your file |

## Building RPM Packages

Note: [`logs-scheduling-and-packages/rpm-package-building.md`](../logs-scheduling-and-packages/rpm-package-building.md)

| Course | Correction |
|---|---|
| `install -m 0755 … /etc/profile.d/login-banner.sh` | Mode `0644` (sourced) + interactive guard |
| `License: GPL` | SPDX identifier, e.g. `GPL-3.0-or-later` |
| `sudo rpm -ivh …rpm` | `sudo dnf install ./…rpm` resolves `Requires` |
| Hard-coded `/usr/bin`, `/etc` in `%install`/`%files` | Use `%{_bindir}`, `%{_sysconfdir}` |
| "RPMS/x86_64/…" for a `noarch` build | Output goes to `RPMS/noarch/` |

## System Logging: journald, rsyslog & logrotate

Note: [`logs-scheduling-and-packages/system-logging.md`](../logs-scheduling-and-packages/system-logging.md)

| Course | Correction |
|---|---|
| "journalctl shows newest first" | Oldest first; `-r` newest first, `-e` jump to end |
| `journalctl -xe` = "recent errors" | `-x` explanations + `-e` end; errors only = `-p err` |
| logrotate "via /etc/cron.daily/logrotate" | `logrotate.timer` on RHEL 9/10 |
| Rotated names `messages.1`, `.2.gz` | RHEL uses `dateext`: `messages-YYYYMMDD` |
| `/var/log/dmesg`, `faillog`, `tallylog`, `pam_tally2`, `auth.log`, `kern.log`, `dpkg.log`, `yum.log`, `/var/log/syslog` | Not RHEL 10 defaults (see §2) |
| `/var/log/utmp`; "who uses wtmp" | utmp is `/run/utmp` (who/w); wtmp is read by `last` |
| `-/path` "better performance" | Legacy, ignored by rsyslog v8 |
| "rsyslog uses TCP instead of UDP" | Supports both (`@` UDP, `@@` TCP) |

## Cryptography Basics for Linux Admins

Note: [`networking-and-ssh/cryptography-basics.md`](../networking-and-ssh/cryptography-basics.md)

| Course | Correction |
|---|---|
| DES, 3DES, Blowfish listed as examples | DES/3DES broken/deprecated; Blowfish legacy. Use AES or ChaCha20 |
| DSA listed for asymmetric | Obsolete; removed from modern OpenSSH |
| "Public key encrypts, private key decrypts" (only) | For **signatures** it's the reverse: sign with private, verify with public |

## IP Addressing Fundamentals (IPv4 & IPv6)

Note: [`networking-and-ssh/ip-addressing-fundamentals.md`](../networking-and-ssh/ip-addressing-fundamentals.md)

| Course | Correction |
|---|---|
| Class A "128 networks" | 126 usable (0 and 127 reserved) |
| "Anycast (IPv6)", example 8.8.8.8 | Anycast works in both; 8.8.8.8 is IPv4 anycast |
| "IPv6: IPsec mandatory / security built-in" | Optional in current standards; not enabled by default |
| VM table: NAT "talks to host and other VMs" | True for VMware NAT / VirtualBox NAT Network, not VirtualBox plain NAT |
| Garbled adapter diagram labels | Use the table above |

## Network Bonding on RHEL 10

Note: [`networking-and-ssh/network-bonding.md`](../networking-and-ssh/network-bonding.md)

| Course | Correction |
|---|---|
| Failover test disconnects `ens160` (not a bond port) | Disconnect the active **port** shown in `/proc/net/bonding/bond0` |
| Existing NIC profiles not mentioned | Delete/disable them so they don't compete with the port profiles |
| `master bond0` syntax only | Still accepted; current terms: `port-type bond controller bond0` |
| Modes 5 and 6 missing | Added (balance-tlb, balance-alb) |
| No `miimon` | Set `bond.options "mode=…,miimon=100"` |

## NetworkManager & nmcli: IPv4, IPv6, DNS & Hostname

Note: [`networking-and-ssh/networkmanager-nmcli.md`](../networking-and-ssh/networkmanager-nmcli.md)

| Course | Correction |
|---|---|
| `ifup ens256`, `ifconfig`, `cat ifcfg-Myhome1` | Not on RHEL 10: `nmcli con up`, `ip addr`, keyfiles |
| `dnf install NetworkManager` | Preinstalled and enabled |
| "gwv4" | `ipv4.gateway` |
| `connection.permissions alice` | `user:alice` |
| IPv6 needs "static hostname or IPv4 set already" | Not required |
| `ping -6` required | Optional; `ping` detects IPv6 |
| `nmcli con down x ; nmcli con up x` | `nmcli con up x` alone re-applies |
| vnStat for monitoring | EPEL, not RHEL repos |

## Packet Capture & Network Sniffing: tcpdump, tshark, Wireshark

Note: [`networking-and-ssh/packet-capture.md`](../networking-and-ssh/packet-capture.md)

| Course | Correction |
|---|---|
| `tcpdump -i ens160 -f "tcp port 22"` | `-f` isn't a filter flag in tcpdump: `tcpdump -i ens160 tcp port 22` |
| `tshark -I ens160 -w capture.pcap` | `-i` (lowercase) selects the interface; `-I` = monitor mode |
| ettercap/ngrep as standard tools | ettercap isn't in RHEL repos; ngrep is EPEL |
| Telnet server lab | `telnet-server` may be missing on RHEL 10; HTTP/FTP demonstrate plaintext equally |
| "Promiscuous mode captures all packets on the segment" | On switched networks you mostly see your own traffic |

## Routing on RHEL 10: Routes, Gateways & Static Routing

Note: [`networking-and-ssh/routing.md`](../networking-and-ssh/routing.md)

| Course | Correction |
|---|---|
| Keyfile `routes1=10.10.10.0/24,192.168.229.1` | Key is `route1=`; gateway should match the example (`.2`) |
| Second default route "used if 192.168.229.2 becomes unreachable" | No reachability-based failover; only if the preferred route disappears |
| Table 201 "for traffic from 192.168.229.133" | Rule is for `192.168.1.100` |
| Diagram `via 100.0.1` | `via 10.0.0.1` |
| `/etc/sysctl.conf` + `sysctl -p` | Drop-in in `/etc/sysctl.d/`, `sysctl --system` |
| firewalld fix: `--add-masquerade` + `--add-icmp-block-inversion` | Use `--add-forward`. Masquerade NATs (hides) sources. icmp-block-inversion **blocks** all ICMP unless listed |
| `route -n` throughout | Legacy; `ip route` |

## rsync & Automated Remote Backups

Note: [`networking-and-ssh/rsync-and-remote-backups.md`](../networking-and-ssh/rsync-and-remote-backups.md)

| Course | Correction |
|---|---|
| `yum install rsync`, `yum repolist all` | `dnf` |
| `rsync -v ~/backup/* /tmp/backup/` | Use `-a`; `~/backup/` (the glob skips dotfiles) |
| `ssh-keygen` then copy `/root/.ssh/id_rsa.pub` | RHEL 10 default key is `id_ed25519.pub` |
| `scp id_rsa.pub root@…:/root/.ssh/authorized_keys` | Overwrites existing keys; use `ssh-copy-id` |
| `* * * * * bash /root/backup.sh` | Every minute only for tests; add `flock`, logging, a real schedule |
| Root-to-root SSH | Prefer a dedicated backup user with a restricted key |

## SSH Port Forwarding (Tunneling)

Note: [`networking-and-ssh/ssh-port-forwarding.md`](../networking-and-ssh/ssh-port-forwarding.md)

| Course | Correction |
|---|---|
| "Data transmission is encrypted & 100% secured" (jump-host diagram) | server2 → server3 leg isn't encrypted by SSH |
| `kill -9 PID` to close | Plain `kill` is enough |
| "SOCKS5 works with TCP and UDP" | OpenSSH `-D` forwards TCP only |
| `GatewayPorts yes` in `/etc/ssh/ssh_config` (for `-L`) | Correct for local forwards (client side); for `-R` it's `sshd_config` on the server |
| root logins in every example | Use regular users (root SSH login is often disabled) |

## SSH: Remote Access, Keys, File Transfer & Switching Users

Note: [`networking-and-ssh/ssh-remote-access.md`](../networking-and-ssh/ssh-remote-access.md)

| Course | Correction |
|---|---|
| "First connection asks to trust the server's RSA fingerprint" | RHEL 10 has ECDSA/Ed25519 host keys; typically an ED25519 fingerprint |
| scp headings swapped ("remote to local" shows local → remote) | Fixed in §3.5 |
| `ssh-keygen -t rsa -b 4096` as the default | RHEL 10 defaults to Ed25519 |
| "Leave passphrase empty" | Prefer a passphrase + `ssh-agent` (empty only for tightly restricted automation keys) |
| `scp ~/.ssh/id_rsa.pub user@remote:~/.ssh/authorized_keys` | Overwrites existing keys; use `ssh-copy-id` or append (§3.3) |
| X11 test with `firefox &` | Firefox is a Flatpak on RHEL 10; use a simple X client; server needs `xauth` |

## SSH Server Configuration & Hardening

Note: [`networking-and-ssh/ssh-server-hardening.md`](../networking-and-ssh/ssh-server-hardening.md)

| Course | Correction |
|---|---|
| Edit `PermitRootLogin` in the main `sshd_config` | Drop-ins are read first and win; use `00-local.conf` and verify with `sshd -T` |
| SELinux label added after editing the port | Add the label (and firewall rule) **before** restarting sshd |
| Allow/Deny lab results assume earlier directives are gone | Remove previous directives between tests |
| `restart` after every change | `reload` keeps existing sessions; `restart` is needed for port changes |

## System Resource Monitoring: free, vmstat, iostat, mpstat, sar

Note: [`processes-and-resource-management/system-resource-monitoring.md`](../processes-and-resource-management/system-resource-monitoring.md)

| Course | Correction |
|---|---|
| vmstat sample read as current (`cs = 3` "suspiciously low") | The first line is a since-boot average; use `vmstat 2 5` |
| `%steal = 0` → "not a virtualized environment" | It only means no time is being stolen; the sample system was a VM |
| `sar` shown without setup | Needs `systemctl enable --now sysstat` for history |
| "Install stress tool" | Use `stress-ng` (check `dnf info stress-ng`) |

## RHCSA Practice Lab Setup (VirtualBox/KVM + Vagrant)

Note: [`rhcsa-exam-labs/practice-lab-setup.md`](../rhcsa-exam-labs/practice-lab-setup.md)

| Course | Correction |
|---|---|
| Rocky Linux 9 "most close to RHEL 9/10" | Use 10.x images (or RHEL 10 via a Developer Subscription) for RHEL 10 practice |
| Extra disks for "Stratis, VDO, RAID" | Not RHEL 10 objectives; focus on GPT, LVM, swap, filesystems |

## RHCSA 10 Sample Exam: Corrected Solutions & Verification

Note: [`rhcsa-exam-labs/sample-exam-with-solutions.md`](../rhcsa-exam-labs/sample-exam-with-solutions.md)

| Task | Course solution | Correction |
|---|---|---|
| N1-1 | No domain search, no autoconnect | `ipv4.dns-search training.lab`, `connection.autoconnect yes` |
| N1-3 | No firewall step | `--add-port=8082/tcp` + reload |
| N1-5 | `yum`; edit `/etc/auto.master` | `dnf`; `/etc/auto.master.d/*.autofs`; wildcard map |
| N1-7 | `sed 's/^server .*/…/'`; `enable --now` only | Default config uses `pool`; restart chronyd |
| N1-8 | `find … -exec cp -p` | Add `-type f`; `cp -a` |
| N1-9 | `grep -ni` | Exactly what's asked (`grep Listen`) |
| N1-12 | "777 − 277 = 500" | umask is AND NOT (same result here) |
| N1-13 | Script without shebang; no daemon-reload; `WantedBy=multi-user.target` | Add `#!/bin/bash`; `daemon-reload`; `timers.target` |
| N2-1 | "Boot into rescue → mount → passwd" | Full `rd.break` procedure + `/.autorelabel` |
| N2-3 | `mklabel gpt` unconditionally; fstab `/dev/sdb1` | Check the disk first; fstab by UUID |
| N2-4 | `lvresize` + `xfs_growfs` | `lvextend -r` (XFS can't shrink) |
| N2-6 | fstab by device path | `UUID=` |
| N2-7 | No service enable | `systemctl enable --now tuned` |

## Quoting, Arguments & Control Operators

Note: [`shell-and-command-line/quoting-and-control-operators.md`](../shell-and-command-line/quoting-and-control-operators.md)

| Item | Course says | Correct |
|---|---|---|
| S9 Q14 | `echo World` prints no newline | `echo` always adds a newline; `echo -e "World\n"` adds an **extra blank line** |
| S9 Q17 | Double-quoted and unquoted `!!` work | Interactive bash expands `!!` there; use the forms in §2.3 |
| S9 Q8–9 | `set -v` shows the expanded alias | `set -v` shows the line **as typed**; `set -x` shows the expanded command |
| S9 Q12 | `which ls` → `/bin/ls` | `/usr/bin/ls` on RHEL (`/bin` is a symlink) |
| S11 `\` example | Escaped spaces "merge multiple spaces into one" | Escaped spaces are **preserved** (output has 3 spaces) |
| S11 `&& \|\|` | "Ternary-like" | Not equivalent to if/else (§4.2) |
| S11 summary table | `\|\|` rows garbled | Rebuilt in §4 |

## Disks, Device Naming & Partitioning (GPT)

Note: [`storage-and-filesystems/disks-and-partitioning.md`](../storage-and-filesystems/disks-and-partitioning.md)

| Course | Correction |
|---|---|
| `mke2fs /dev/sda` / `mount /dev/sda /testdir` | `sda` is often the OS disk; verify with `lsblk`. Exam tasks use partitions/LVs |
| NVMe "up to 32 GB/s (Gen4)" | Typical NVMe SSD (×4 lanes): ~7–8 GB/s Gen4, ~14 GB/s Gen5 |
| Naming lists only `hd*`/`sd*` | Also `vd*` (virtio), `nvme0n1p1`, `sr0`, `dm-*` / `/dev/mapper/*` |
| `/proc/scsi/scsi`, `lshw` | May be absent/not installed; use `lsblk`, `lsscsi` |
| `badblocks -ws`, `dd` to erase | Destructive; on SSDs use `blkdiscard` |

## Filesystem Check & Repair (e2fsck, fsck, xfs_repair)

Note: [`storage-and-filesystems/filesystem-check-and-repair.md`](../storage-and-filesystems/filesystem-check-and-repair.md)

| Course | Correction |
|---|---|
| "Force unmount (`umount -l`) before repair" | Dangerous; lazy unmount leaves it in use. Fully unmount instead |
| fstab `/dev/sdb /ext3_data ext3 defaults 0 1` | Pass `1` is for root only; data uses `2` (and `UUID=`) |
| One options table for `fsck` | `-A -R -M -t` are front-end options; `-n -y -p -f -c -b` belong to e2fsck |
| "NEVER run fsck on XFS: will damage data" | `fsck.xfs` is a harmless no-op; use `xfs_repair` |
| `xfs_repair -L` as an optional step | Try mounting (log replay) first; `-L` is the last resort |

## LUKS Disk Encryption

Note: [`storage-and-filesystems/luks-encryption.md`](../storage-and-filesystems/luks-encryption.md)

| Course | Correction |
|---|---|
| "LUKS2 stores keys in the kernel" | The master key is stored **encrypted in the on-disk header**; it's only in kernel memory while open |
| crypttab `myfiles /dev/sdb /etc/crypt_file` | Use `UUID=<luks uuid>` (device names can change) |
| Key file made in `/tmp`, then moved | Create it directly in `/etc` with `umask 077`, mode `0400` |
| `luksOpen` / `luksClose` | Still valid; modern form `cryptsetup open` / `close` |
| `luksRemoveKey` without checks | Check `luksDump` first; never remove the last key |
| No header backup | Add `luksHeaderBackup` |
| `chmod 777 /myfiles` | Lab only |

## LVM Fundamentals: PVs, VGs, LVs & Resizing

Note: [`storage-and-filesystems/lvm-fundamentals.md`](../storage-and-filesystems/lvm-fundamentals.md)

| Course | Correction |
|---|---|
| `vgextend VG1 /dev/sdb2` then `lvextend … /dev/VG2/LV2` | Extend the VG that holds the LV: `vgextend VG2 /dev/sdb2` |
| Partition type `8e` | MBR code; on GPT use "Linux LVM" (fdisk alias `lvm`; gdisk `8e00`) |
| `yum install lvm2` / `apt` | RHEL uses `dnf`; `lvm2` is preinstalled |
| fstab `/dev/vgdata/lvdata …` | Stable, but the objective wants `UUID=`/`LABEL=` |
| Dump field discussion | `dump` isn't used on RHEL; field 5 is always `0` |
| fsck pass "always 0 for vfat" | VFAT can use `2` (dosfstools provides `fsck.vfat`); XFS/swap/network → `0` |

## Moving LVM Volume Groups Between Systems

Note: [`storage-and-filesystems/lvm-moving-vgs-between-systems.md`](../storage-and-filesystems/lvm-moving-vgs-between-systems.md)

| Course | Correction |
|---|---|
| Target: `vgscan` → `vgchange -ay` | On RHEL 9/10, add the disk to the devices file first; then `vgimport` **before** activation (an exported VG can't be activated) |
| `vgcfgrestore my_vg` then `vgchange -ay` then `vgimport` | Order: `vgimport` → `vgchange -ay`. `vgcfgrestore` is needed only if metadata is damaged, with `-f <backup file>` |
| "Note the UUID: `blkid /dev/sda`" | For recovery you need the **PV UUID** (`pvs -o +pv_uuid` or the backup file); filesystem UUIDs are different |
| `pvcreate --uuid … -ff` | Destructive last resort; verify the device first |

## LVM Thin Provisioning & Striping

Note: [`storage-and-filesystems/lvm-thin-provisioning-and-striping.md`](../storage-and-filesystems/lvm-thin-provisioning-and-striping.md)

| Course | Correction |
|---|---|
| `vgcreate -s 32M … (required for thin pools)` | PE size isn't required for thin pools; the pool has its own chunk size (`-c`) |
| `lvs -o +seg_monitor` "shows pool usage" | It shows monitoring status; usage is `data_percent`/`metadata_percent` |
| `dd if=/dev/zero … bs=1M count=1024` as a performance test | Add `oflag=direct` or `conv=fdatasync` |
| fstab `/dev/vg_striped/lv_striped …` | Prefer `UUID=` |
| `pvcreate /dev/sda /dev/sdb` | Verify with `lsblk` they aren't the OS disk |

## VDO on LVM (Deduplication & Compression)

Note: [`storage-and-filesystems/lvm-vdo.md`](../storage-and-filesystems/lvm-vdo.md)

| Course | Correction |
|---|---|
| `dnf install lvm2 vdo kmod-kvdo` | `kmod-kvdo` is the RHEL 9 module; RHEL 10 uses in-kernel `dm-vdo` |
| `lvcreate --type vdo --name lv_vdo --size 10G vg_vdo` | Specify `-V` (virtual size) too; `-L` is the physical pool |
| `mkfs.xfs /dev/vg_vdo/lv_vdo` | `mkfs.xfs -K` |
| `echo '…' >> tee -a /etc/fstab` | Writes to a file named `tee`; use `\| tee -a /etc/fstab` or `>> /etc/fstab`, with `UUID=` |
| `cat /dev/urandom > …` / `cat /dev/zero > …` | Fills the whole volume; use `dd … count=N` |

## VG Merge/Split, Renaming & Online Disk Migration (pvmove)

Note: [`storage-and-filesystems/lvm-vg-merge-split-and-migration.md`](../storage-and-filesystems/lvm-vg-merge-split-and-migration.md)

| Course | Correction |
|---|---|
| `ls -l /dev/ \| grep sd*` | Unquoted `sd*` is expanded by the shell first; use `ls -l /dev/sd*` or `lsblk` |
| Migration ends at `vgreduce` | Also `pvremove /dev/sda1` to wipe the label |
| "Create new primary partition" | MBR wording; on GPT just create a partition |
| `md5sum` validation | Fine for copy checks; `sha256sum` preferred |

## Mounting, Mount Options & /etc/fstab

Note: [`storage-and-filesystems/mounting-and-fstab.md`](../storage-and-filesystems/mounting-and-fstab.md)

| Course | Correction |
|---|---|
| `/dev/sdd /newdir xfs defaults 0 0` | Use `UUID=`/`LABEL=` (objective requirement; device names can change) |
| `/etc/mtab` "maintained by mount, don't edit" | It's a symlink to `/proc/self/mounts` |
| `fisk /dev/sda` | Typo: `fdisk` |
| `noacl` (deprecated) | Not supported on XFS; ACLs are always on |
| `mkswap` + `swapon` only | Not persistent; add an fstab swap line and `swapon -a` |
| fstab `ext2 defaults 0 0` | ext filesystems should normally use fsck order `2` (non-root) |

## Software RAID with mdadm

Note: [`storage-and-filesystems/raid-mdadm.md`](../storage-and-filesystems/raid-mdadm.md)

| Course | Correction |
|---|---|
| RAID 5 parity "1011 − 0101 = 0010" | Parity is XOR: `1011 ⊕ 0101 = 1110` |
| RAID 6 diagram: same parity on two disks | Two **different** parities (P and Q) |
| RAID 5 diagram with a dedicated parity disk | Parity is distributed (dedicated = RAID 4); the text pages are correct |
| Infographic: RAID 0 with parity blocks; "No fault tolerance" under Advantages; RAID 1 "power down for rebuilds"; RAID 5 pros under Disadvantages | RAID 0 has no parity; md rebuilds online; labels reversed |
| Practical stops after create/fail/add | Add `/etc/mdadm.conf`, fstab by UUID, `mdmonitor`, `--zero-superblock` when reusing |
| `dnf list install mdadm` | `dnf list --installed mdadm` |

## Stratis Storage

Note: [`storage-and-filesystems/stratis.md`](../storage-and-filesystems/stratis.md)

| Course | Correction |
|---|---|
| fstab `UUID=… /data xfs defaults 0 0` | Add `x-systemd.requires=stratisd.service` |
| Restore: `stratis filesystem snapshot my_pool_2 mysnapshot block` | That creates another snapshot named `block`. Mount the snapshot in place of the original (or copy files back) |
| Delete snapshot: `rm /dev/stratis/my_pool_2/mysnapshot` | Not needed or valid; `umount` then `stratis filesystem destroy` |
| "Introduced in RHEL 8" feature list | Fine; Stratis isn't part of the RHEL 10 objectives |

## Swap: Partitions, LVs, Swap Files & Swappiness

Note: [`storage-and-filesystems/swap.md`](../storage-and-filesystems/swap.md)

| Course | Correction |
|---|---|
| Default swappiness "60 older, 30 RHEL 8+" | Kernel default 60; tuned profiles set 30 (virtual-guest) or 10 (throughput-performance) |
| Range 0–100 | 0–200 on RHEL 10's kernel |
| "Swappiness = how often swap is used" | It weights anonymous-memory reclaim vs page-cache reclaim |
| `fallocate` first | `dd` is the documented, hole-free method |
| Tested on Ubuntu 18.04 / CentOS 7 | Outdated; procedure verified for RHEL 10 |
| `epel-release-latest-9` / `yum install stress` | RHEL 10 → EPEL 10, `dnf`; check `dnf info stress-ng` first |

## XFS Disk Quotas (User, Group & Project)

Note: [`storage-and-filesystems/xfs-quotas.md`](../storage-and-filesystems/xfs-quotas.md)

| Course | Correction |
|---|---|
| fstab `/dev/sda1 /xfsquota …` | Use `UUID=` |
| `chmod 777 /xfsquota` | Lab only; `1777` (sticky) at least |
| Project quota on the mount point itself | Normally a subdirectory |
| `usermod -g admin testuser` "add to group" | Changes the **primary** group, which is what makes group quotas apply |
| Re-enable after `off` | Not possible until remount |

## Apache HTTP Server (httpd) on RHEL 10

Note: [`system-services-and-shared-storage/apache-httpd.md`](../system-services-and-shared-storage/apache-httpd.md)

| Course | Correction |
|---|---|
| `chown -R apache:apache /var/www/html` | Don't give Apache write access to content |
| `dnf install mod_deflate` | Part of the `httpd` package |
| `SSLProtocol all -SSLv2 -SSLv3 -TLSv1 -TLSv1.1` | Crypto policy already enforces TLS 1.2+; if pinning: `-all +TLSv1.2 +TLSv1.3` |
| Cert/key in `/etc/httpd/ssl/` | Prefer `/etc/pki/tls/{certs,private}` (correct labels; key mode 600) |
| Single vhost replaces the default site silently | Define a default vhost first |
| `certbot` from RHEL repos | EPEL |
| "Enable event MPM" | Already the default |

## Time Synchronization with chrony (NTP)

Note: [`system-services-and-shared-storage/chrony-time-sync.md`](../system-services-and-shared-storage/chrony-time-sync.md)

| Course | Correction |
|---|---|
| `chronyc -a makestep` / `-a burst` | `-a` is obsolete: `chronyc makestep`, `chronyc burst 4/4` |
| `nc -vzu host 123` as a test | UDP "connectivity" tests aren't reliable; use `chronyc sources` / `chronyd -Q` |
| "Restart NetworkManager" for chrony issues | Not needed; disrupts networking |
| `server 0.pool.ntp.org …` for pools | Use `pool` for pool names (RHEL default: `pool 2.rhel.pool.ntp.org iburst`) |
| No timedatectl | Added (time zone, `set-ntp`, sync status) |

## DNS with BIND (named): Concepts, Zones & Testing

Note: [`system-services-and-shared-storage/dns-bind.md`](../system-services-and-shared-storage/dns-bind.md)

| Course | Correction |
|---|---|
| Client: `DNS=192.168.229.137` + restart NetworkManager + edit `/etc/resolv.conf` | RHEL 10: `nmcli con mod … ipv4.dns …` (resolv.conf is generated) |
| SOA "TTL: minimum TTL for records" | Negative-caching TTL |
| "TCP 53 for zone transfers" only | Also large responses/DNSSEC |
| `systemctl restart named` after zone edits | Increase the serial; `rndc reload` |
| `type master` | `type primary` (old keyword still accepted) |
| `.local` domain | Reserved for mDNS; use a real subdomain or `.internal` |
| `chown named:named` zone files | `root:named` 640 is the RHEL convention (named only needs read for primary zones) |

## iSCSI Target (targetcli) & Initiator (iscsiadm)

Note: [`system-services-and-shared-storage/iscsi.md`](../system-services-and-shared-storage/iscsi.md)

| Course | Correction |
|---|---|
| Target: `systemctl enable --now iscsid` | Target side needs `target.service`; iscsid is the initiator daemon |
| Login `iscsiadm -m node -T IQN 192.168.229.132 -l` | `-p 192.168.229.132` is required |
| Backstore `/dev/sda`; client `mkfs.ext4 /dev/sda` | `sda` is often the OS disk; use a dedicated device and identify the LUN via `/dev/disk/by-path` |
| Ports "860 and 3260 TCP/UDP" | 3260/tcp |
| `ifconfig` | `ip addr` |
| No fstab / persistence for the client | UUID + `_netdev,nofail`; `iscsi.service` enabled |
| `losetup` before fileio (multipath lab) | Not needed; fileio uses the file directly |

## DM-Multipath (Redundant Storage Paths)

Note: [`system-services-and-shared-storage/multipath.md`](../system-services-and-shared-storage/multipath.md)

| Course | Correction |
|---|---|
| Both paths in 192.168.1.0/24 | Use separate subnets per path |
| `losetup` before the fileio backstore | Not needed |
| Demo-mode ACL attributes (sample `lsblk` shows `RO 1`) | Add `demo_mode_write_protect=0`, or use ACLs |
| `blacklist { devnode "^sda" }` | Blacklist by WWID |
| Custom `devices` block (readsector0, rr_min_io…) | Built-in LIO defaults are fine; legacy options |
| `multipath -F` as routine step | Flushes unused maps; only when needed |

## NFS & autofs

Note: [`system-services-and-shared-storage/nfs-and-autofs.md`](../system-services-and-shared-storage/nfs-and-autofs.md)

| Course | Correction |
|---|---|
| root_squash → `nfsnobody` | `nobody` on RHEL 8+ |
| `semanage fcontext … public_content_t` for NFS exports | Not needed; NFS exports any label (booleans on by default) |
| `rpc-bind` + `mountd` always required | Only for NFSv3 / `showmount` |
| `chmod 777` on exports | Lab only; set ownership/permissions properly |
| Pre-create `/automount/private` and `/public` | autofs manages subdirectories; don't create them |
| Map file `/etc/automount.txt` | Works; convention: `/etc/auto.master.d/NAME.autofs` + `/etc/auto.NAME` |
| `nfs4-acl-tools` required | Optional (NFSv4 ACL tools) |
| No fstab, direct or wildcard maps | Added (exam relevant) |

## Samba (SMB) Server & CIFS Client

Note: [`system-services-and-shared-storage/samba.md`](../system-services-and-shared-storage/samba.md)

| Course | Correction |
|---|---|
| `chcon -t samba_share_t …` (server, and troubleshooting fix) | `semanage fcontext` + `restorecon` (persistent) |
| `dnf install -y samba*` on the client | `cifs-utils` (+ `samba-client`) |
| `mount … -o username=demo,password=redhat` | Exposes the password; use a credentials file |
| `chmod -R 0770` for the group share | `2770` (SGID) or `force group` for consistent group ownership |
| fstab without `nofail` | Add `nofail` for non-critical shares |

## FTP with vsftpd

Note: [`system-services-and-shared-storage/vsftpd-ftp.md`](../system-services-and-shared-storage/vsftpd-ftp.md)

| Course | Correction |
|---|---|
| `listen_port=3434` + firewall only | Also `semanage port -a -t ftp_port_t -p tcp 3434` |
| `semanage fcontext -a -t public_content_t "/ftp"` | `'/ftp(/.*)?'` + `restorecon -Rv /ftp`; chroot root not writable |
| `chcon` (option 1) | Not persistent |
| Anonymous `put test.txt` works by default | Needs upload options, a writable labeled dir and `ftpd_anon_write` |
| Testing via browser (`ftp://`) | Browsers removed FTP support |
| "Data port 20" only | Port 20 is active mode only; passive uses high ports |
| Local users see the whole filesystem | Use `chroot_local_user=YES` |

## PAM & authselect: Authentication Policy on RHEL 10

Note: [`users-groups-and-permissions/pam-and-authselect.md`](../users-groups-and-permissions/pam-and-authselect.md)

| Course | Correction |
|---|---|
| `authselect select sssd with-faillock --force` | Replaces the profile/feature set; use `enable-feature with-faillock` (RHEL 10 may use the `local` profile) |
| pam_listfile in sshd's **auth** section | Key logins skip auth; use the **account** section |
| "Restart sshd" after PAM changes | Not needed; PAM files are read per login |
| `optional`: "only used if no other modules exist" | Its result matters only if it's the only module of that type |
| Control flags table | Add `include`, `substack`, bracket syntax |
| `dnf install pamtester` | EPEL package |
| Editing `/etc/security/pwquality.conf` directly | Prefer `/etc/security/pwquality.conf.d/` drop-ins |
