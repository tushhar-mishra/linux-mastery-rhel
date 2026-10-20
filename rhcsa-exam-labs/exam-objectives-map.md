# EX200 Objectives Map (RHEL 10)

> Source: Red Hat EX200 exam page (verified Oct 2026; page states the exam is based on RHEL 10).
> Session mapping is provisional and based on course session titles; update it as material arrives.
> Red Hat may add, modify or remove objectives at any time, so re-check the official page before booking.

**Exam rules that apply to every task:** no internet, no personal notes, product documentation (man, info, `/usr/share/doc`) available, and **all configuration must persist after reboot without intervention.**

## 1. Understand and use essential tools

| Objective | Sessions | Notes |
|---|---|---|
| Access a shell prompt and issue commands with correct syntax | 4–6, 9–15 | [shell-basics-and-command-syntax.md](../shell-and-command-line/shell-basics-and-command-syntax.md) |
| Use input-output redirection (`>`, `>>`, `\|`, `2>`, etc.) | 16 | `files-and-text-processing/` |
| Use grep and regular expressions to analyze text | 17, 20 | `files-and-text-processing/` |
| Access remote systems using SSH | 3, 64–65 | [ssh-remote-access.md](../networking-and-ssh/ssh-remote-access.md) |
| Log in and switch users in multi-user targets | 3, 21, 50 | [ssh-remote-access.md](../networking-and-ssh/ssh-remote-access.md#4-logging-in-and-switching-users-rhcsa-core) |
| Archive, compress, unpack, uncompress (tar, gzip, bzip2) | 8 | [archiving-and-compression.md](../files-and-text-processing/archiving-and-compression.md) |
| Create and edit text files | 7, 20 | [viewing-and-creating-file-contents.md](../files-and-text-processing/viewing-and-creating-file-contents.md) (vi: S20, planned) || Create, delete, copy, move files and directories | 6 | [files-and-directories.md](../shell-and-command-line/files-and-directories.md) |
| Create hard and soft links | 28 | `users-groups-and-permissions/` |
| List, set, change standard ugo/rwx permissions | 25 | `users-groups-and-permissions/` |
| Locate, read, use docs: man, info, `/usr/share/doc` | 4–5 | [getting-help-and-documentation.md](../shell-and-command-line/getting-help-and-documentation.md) |
## 2. Manage software

| Objective | Sessions | Notes |
|---|---|---|
| Configure access to RPM repositories | 57 | `logs-scheduling-and-packages/` |
| Install and remove RPM packages | 57 | `logs-scheduling-and-packages/` |
| Configure access to Flatpak repositories | 58 | `logs-scheduling-and-packages/` |
| Install and remove Flatpak packages | 58 | `logs-scheduling-and-packages/` |

## 3. Create simple shell scripts

| Objective | Sessions |
|---|---|
| Conditionally execute code (`if`, `test`, `[ ]`) | 87–90 |
| Looping constructs (`for`, etc.) to process files and command-line input | 91 |
| Process script inputs (`$1`, `$2`, …) | 13, 86–87 | [shell-variables-and-environment.md §6](../shell-and-command-line/shell-variables-and-environment.md#6-positional-parameters-rhcsa-core) |
| Process output of shell commands within a script | 14, 85 | [command-substitution-and-shell-options.md](../shell-and-command-line/command-substitution-and-shell-options.md) |

## 4. Operate running systems

| Objective | Sessions |
|---|---|
| Boot, reboot, shut down normally | 49–50 |
| Boot into different targets manually | 50 |
| Interrupt the boot process to gain access | 51, 67 |
| Identify CPU/memory-intensive processes; kill processes | 29–30 |
| Adjust process scheduling | 30 |
| Manage tuning profiles | 83 |
| Locate and interpret system log files and journals | 55 |
| Preserve system journals | 55 |
| Start, stop, check status of network services | 50, 60 |
| Securely transfer files between systems | 3, 64–68 |

## 5. Configure local storage

| Objective | Sessions |
|---|---|
| List, create, delete partitions on **GPT** disks | 31–33 |
| Create and remove physical volumes | 35 |
| Assign physical volumes to volume groups | 35 |
| Create and delete logical volumes | 35 |
| Mount file systems at boot by UUID or label | 33–34 |
| Add partitions, LVs and swap non-destructively | 33, 35, 42 |

## 6. Create and configure file systems

| Objective | Sessions |
|---|---|
| Create, mount, unmount, use VFAT, ext4, XFS | 33–34 |
| Mount and unmount NFS | 97 |
| Configure autofs | 97 |
| Extend existing logical volumes | 35–36 |
| Diagnose and correct file permission problems | 25–27 |

## 7. Deploy, configure, and maintain systems

| Objective | Sessions |
|---|---|
| Schedule tasks using at, cron and **systemd timer units** | 54 |
| Start/stop services; enable at boot | 50 |
| Boot into a specific target automatically | 50 |
| Configure time service clients | 94 |
| Install/update packages from Red Hat CDN, a remote repo, or the local file system | 57 |
| Modify the system bootloader | 49, 53 |

## 8. Manage basic networking

| Objective | Sessions |
|---|---|
| Configure IPv4 and IPv6 addresses | 60 |
| Configure hostname resolution | 60, 101 |
| Configure network services to start at boot | 60 |
| Restrict network access using firewalld/firewall-cmd | 69–70 |

## 9. Manage users and groups

| Objective | Sessions |
|---|---|
| Create, delete, modify local users | 21 |
| Change passwords; adjust password aging | 22 |
| Create, delete, modify groups and memberships | 24 |
| Configure privileged access | 27 |

## 10. Manage security

| Objective | Sessions |
|---|---|
| Configure firewall settings using firewall-cmd/firewalld | 69–70 |
| Manage default file permissions (umask) | 25–26 |
| Configure key-based SSH authentication | 3, 64–65 |
| Set SELinux enforcing/permissive modes | 71, 76 |
| List and identify SELinux file and process contexts | 72 |
| Restore default file contexts | 76 |
| Manage SELinux port labels | 76 |
| Use Booleans to modify SELinux settings | 76 |

## Changes vs. the Course Slides (RHEL 9-era Objectives)

| Area | Course slide | Current EX200 (RHEL 10) |
|---|---|---|
| Partitioning | MBR and GPT disks | GPT disks only |
| Collaboration | Create set-GID directories | Not listed (still useful for permission troubleshooting) |
| Scheduling | at and cron | at, cron **and systemd timer units** |
| Software | Install from remote repo or local ISO | New **Manage software** category (RPM repos and packages, **Flatpak** repos and packages); installs from CDN, remote repo or local file system |
| Privilege | Configure superuser access | Configure privileged access |
| SELinux | Includes "Diagnose and address routine SELinux policy violations" | Not listed (still essential in practice) |
| Containers | Category 10: Podman, skopeo, Containerfile, systemd, storage | **Removed** |

## Course Sessions Outside the Current Objectives

Labeled **[Advanced/Optional]** in topic notes: LVM snapshots, thin provisioning, striping, VG split/merge, pvmove, RAID, quotas, VDO, Stratis, LUKS, fsck/xfs_repair, kernel compilation, bonding, packet capture, Cockpit, Image Builder, KVM, Podman, SSH tunneling, PAM, NTP server, Apache, FTP, NFS server, Samba, iSCSI, multipathing, DNS server.
