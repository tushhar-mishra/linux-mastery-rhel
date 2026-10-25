# Coverage Checklist

> Maps every RHCSA objective and every target skill to **where it's taught** and **where it's practised**, with a box to tick when you can do it **without notes**.
> Objectives copied verbatim from Red Hat's EX200 page (RHEL 10), re-checked 26 Oct 2026. Red Hat may change them at any time; re-check before booking.
> Practice codes: **S** = [sample exam](../notes/rhcsa-exam-labs/sample-exam-with-solutions.md) (N1/N2 = node, task #) · **M2** = [mock exam 2](../notes/rhcsa-exam-labs/mock-exam-2.md) · **M3** = [mock exam 3](../notes/rhcsa-exam-labs/mock-exam-3.md) · **Sc** = [production scenario](../notes/troubleshooting-and-interviews/production-scenarios.md) · **IQ** = [interview bank](../notes/troubleshooting-and-interviews/interview-question-bank.md)

## 1. RHCSA (EX200) Objectives, RHEL 10

### Understand and use essential tools

| ✓ | Objective | Learn | Practise |
|---|---|---|---|
| ☐ | Access a shell prompt and issue commands with correct syntax | [Shell basics](../notes/shell-and-command-line/shell-basics-and-command-syntax.md), [quoting](../notes/shell-and-command-line/quoting-and-control-operators.md) | All tasks |
| ☐ | Use input-output redirection (>, >>, \|, 2>, etc.) | [Redirection](../notes/files-and-text-processing/io-redirection-and-pipes.md) | S N1-9, M2 A8 |
| ☐ | Use grep and regular expressions to analyze text | [grep & regex](../notes/files-and-text-processing/grep-and-regular-expressions.md), [text filters](../notes/files-and-text-processing/text-filters.md) | S N1-9, M2 A8, grep §12 |
| ☐ | Access remote systems using SSH | [SSH](../notes/networking-and-ssh/ssh-remote-access.md) | M2 A20–A21 |
| ☐ | Log in and switch users in multi-user targets | [SSH §4](../notes/networking-and-ssh/ssh-remote-access.md#4-logging-in-and-switching-users-rhcsa-core), [sudo §5](../notes/users-groups-and-permissions/sudo-and-privileged-access.md#5-using-sudo) | M3 (root reset, `su -` tests), M2 A7 |
| ☐ | Archive, compress, unpack, and uncompress files using tar, gzip, and bzip2 | [Archiving](../notes/files-and-text-processing/archiving-and-compression.md) | S N1-11, M2 A9 |
| ☐ | Create and edit text files | [vi](../notes/files-and-text-processing/vi-and-vim.md), [creating files](../notes/files-and-text-processing/viewing-and-creating-file-contents.md) | All config tasks |
| ☐ | Create, delete, copy, and move files and directories | [Files & directories](../notes/shell-and-command-line/files-and-directories.md) | S N1-8, M2 A8 |
| ☐ | Create hard and soft links | [Links](../notes/users-groups-and-permissions/links.md) | M2 A22 |
| ☐ | List, set, and change standard ugo/rwx permissions | [File permissions](../notes/users-groups-and-permissions/file-permissions.md) | M2 A6, M3 §7 |
| ☐ | Locate, read, and use system documentation including man, info, and files in /usr/share/doc | [Getting help](../notes/shell-and-command-line/getting-help-and-documentation.md) | Help §5 drills; every mock (no internet) |

### Manage software

| ✓ | Objective | Learn | Practise |
|---|---|---|---|
| ☐ | Configure access to RPM repositories | [RPM & DNF §2](../notes/logs-scheduling-and-packages/rpm-and-dnf-package-management.md#2-repositories-rhcsa-core) | S N1-2, S N2-2, M2 A2 |
| ☐ | Install and remove RPM software packages | [RPM & DNF §3–4](../notes/logs-scheduling-and-packages/rpm-and-dnf-package-management.md#3-dnf-commands-rhcsa-core) | S N1-3, M2 A11 |
| ☐ | Configure access to Flatpak repositories | [Flatpak](../notes/logs-scheduling-and-packages/flatpak.md) | S N2-5 (user), M2 A18 (system) |
| ☐ | Install and remove Flatpak software packages | [Flatpak](../notes/logs-scheduling-and-packages/flatpak.md) | S N2-5, M2 A18 |

### Create simple shell scripts

| ✓ | Objective | Learn | Practise |
|---|---|---|---|
| ☐ | Conditionally execute code (use of: if, test, [], etc.) | [Conditionals](../notes/bash-scripting-and-automation/conditionals-and-tests.md) | M2 A10, IQ F2 |
| ☐ | Use Looping constructs (for, etc.) to process file, command line input | [Loops](../notes/bash-scripting-and-automation/loops.md) | M2 A10 |
| ☐ | Process script inputs ($1, $2, etc.) | [Script input](../notes/bash-scripting-and-automation/script-input-and-arguments.md) | M2 A10 |
| ☐ | Processing output of shell commands within a script | [Command substitution](../notes/shell-and-command-line/command-substitution-and-shell-options.md) | M2 A10, S N1-13 |

### Operate running systems

| ✓ | Objective | Learn | Practise |
|---|---|---|---|
| ☐ | Boot, reboot, and shut down a system normally | [Boot process §5](../notes/boot-systemd-and-kernel/boot-process.md#5-shutting-down--rebooting-rhcsa-core) | Every mock (reboot test) |
| ☐ | Boot systems into different targets manually | [Targets](../notes/boot-systemd-and-kernel/systemd-targets-and-services.md#2-targets) | M3 |
| ☐ | Interrupt the boot process in order to gain access to a system | [Boot recovery §2](../notes/boot-systemd-and-kernel/boot-recovery.md#2-reset-the-root-password-rhcsa-core) | S N2-1, M2 B1, M3 |
| ☐ | Identify CPU/memory intensive processes and kill processes | [Processes](../notes/processes-and-resource-management/processes-and-signals.md), [top](../notes/processes-and-resource-management/top-and-process-monitoring.md) | M2 A19 |
| ☐ | Adjust process scheduling | [nice/renice](../notes/processes-and-resource-management/process-priority-and-nice.md) | M2 A19 |
| ☐ | Manage tuning profiles | [tuned](../notes/containers-and-virtualization/tuned-profiles.md) | S N2-7, M2 A15, M3 |
| ☐ | Locate and interpret system log files and journals | [System logging](../notes/logs-scheduling-and-packages/system-logging.md) | M3 (diagnosis), Sc 6–7 |
| ☐ | Preserve system journals | [System logging §4](../notes/logs-scheduling-and-packages/system-logging.md#4-persistent-journal-rhcsa-core) | M2 A14, M3, Sc 7 |
| ☐ | Start, stop, and check the status of network services | [systemd services §3](../notes/boot-systemd-and-kernel/systemd-targets-and-services.md#3-service-essentials-supplemented-rhcsa-core) | S N1-3, M2 A11, M3 |
| ☐ | Securely transfer files between systems | [SSH §3.5](../notes/networking-and-ssh/ssh-remote-access.md#35-secure-file-transfer-rhcsa-core), [rsync](../notes/networking-and-ssh/rsync-and-remote-backups.md) | M2 A20 |

### Configure local storage

| ✓ | Objective | Learn | Practise |
|---|---|---|---|
| ☐ | List, create, and delete partitions on GPT disks | [Disks & partitioning](../notes/storage-and-filesystems/disks-and-partitioning.md) | S N2-3, M2 B2–B4, M2 B6 |
| ☐ | Create and remove physical volumes | [LVM §4, §7](../notes/storage-and-filesystems/lvm-fundamentals.md#41-prepare-pvs) | S N2-6, M2 B4 |
| ☐ | Assign physical volumes to volume groups | [LVM §4.2](../notes/storage-and-filesystems/lvm-fundamentals.md#42-create-a-vg-and-lvs) | S N2-6, M2 B4 |
| ☐ | Create and delete logical volumes | [LVM](../notes/storage-and-filesystems/lvm-fundamentals.md) | S N2-6, M2 B4–B5 |
| ☐ | Configure systems to mount file systems at boot by universally unique ID (UUID) or label | [fstab §4](../notes/storage-and-filesystems/mounting-and-fstab.md#4-etcfstab-rhcsa-core) | S N2-6, M2 B2–B5 |
| ☐ | Add new partitions and logical volumes, and swap to a system non-destructively | [Swap](../notes/storage-and-filesystems/swap.md), [LVM §8](../notes/storage-and-filesystems/lvm-fundamentals.md#8-rhcsa-exam-patterns-rhcsa-core) | S N2-3, M2 B3 |

### Create and configure file systems

| ✓ | Objective | Learn | Practise |
|---|---|---|---|
| ☐ | Create, mount, unmount, and use VFAT, ext4, and XFS file systems | [Filesystems](../notes/storage-and-filesystems/filesystems-and-mkfs.md), [mounting](../notes/storage-and-filesystems/mounting-and-fstab.md) | M2 B2 (VFAT), B4 (XFS), B5 (ext4) |
| ☐ | Mount and unmount network file systems using NFS | [NFS §3](../notes/system-services-and-shared-storage/nfs-and-autofs.md#3-nfs-client-manual--persistent-mounts-rhcsa-core) | M2 A17 |
| ☐ | Configure autofs | [autofs §4](../notes/system-services-and-shared-storage/nfs-and-autofs.md#4-autofs-rhcsa-core) | S N1-5, M2 A17 |
| ☐ | Extend existing logical volumes | [LVM §5](../notes/storage-and-filesystems/lvm-fundamentals.md#5-extending-online-rhcsa-core) | S N2-4, M2 B4, Sc 8 |
| ☐ | Diagnose and correct file permission problems | [Permissions §4](../notes/users-groups-and-permissions/file-permissions.md#4-diagnosing-permission-problems-rhcsa-core), [ACLs](../notes/users-groups-and-permissions/special-permissions-and-acls.md), [SELinux contexts](../notes/firewall-and-selinux/selinux-file-contexts.md) | M3 §7, Sc 2, Sc 4 |

### Deploy, configure, and maintain systems

| ✓ | Objective | Learn | Practise |
|---|---|---|---|
| ☐ | Schedule tasks using at, cron and systemd timer units | [Job scheduling](../notes/logs-scheduling-and-packages/job-scheduling.md) | S N1-6, S N1-13, M2 A14, Sc 6 |
| ☐ | Start and stop services and configure services to start automatically at boot | [systemd services](../notes/boot-systemd-and-kernel/systemd-targets-and-services.md) | S N1-3, M2 A11, M3 |
| ☐ | Configure systems to boot into a specific target automatically | [Targets](../notes/boot-systemd-and-kernel/systemd-targets-and-services.md#2-targets) | M2 A13, M3 |
| ☐ | Configure time service clients | [chrony](../notes/system-services-and-shared-storage/chrony-time-sync.md) | S N1-7, M2 A16, M3 |
| ☐ | Install and update software packages from Red Hat Content Delivery Network, a remote repository, or from the local file system | [RPM & DNF](../notes/logs-scheduling-and-packages/rpm-and-dnf-package-management.md), [kernels](../notes/boot-systemd-and-kernel/grub2-and-kernel-management.md#6-kernel-packages-rhcsa-core-installingupdating) | S N1-2, M2 A2 |
| ☐ | Modify the system bootloader | [GRUB2](../notes/boot-systemd-and-kernel/grub2-and-kernel-management.md) | M2 A13 |

### Manage basic networking

| ✓ | Objective | Learn | Practise |
|---|---|---|---|
| ☐ | Configure IPv4 and IPv6 addresses | [nmcli](../notes/networking-and-ssh/networkmanager-nmcli.md) | S N1-1 (IPv4), M2 A1 (IPv6) |
| ☐ | Configure hostname resolution | [nmcli §9](../notes/networking-and-ssh/networkmanager-nmcli.md#9-hostname--name-resolution-supplemented-rhcsa-core) | S N1-1, M2 A1 |
| ☐ | Configure network services to start automatically at boot | [nmcli §10](../notes/networking-and-ssh/networkmanager-nmcli.md#10-network-services-at-boot) | M2 A11 |
| ☐ | Restrict network access using firewalld and firewall-cmd | [firewalld](../notes/firewall-and-selinux/firewalld.md) | S N1-3, M2 A11, M3 |

### Manage users and groups

| ✓ | Objective | Learn | Practise |
|---|---|---|---|
| ☐ | Create, delete, and modify local user accounts | [Local users](../notes/users-groups-and-permissions/local-users.md) | S N1-4, S N1-10, M2 A3 |
| ☐ | Change passwords and adjust password aging for local user accounts | [Passwords & aging](../notes/users-groups-and-permissions/passwords-and-aging.md) | M2 A3–A4 |
| ☐ | Create, delete, and modify local groups and group memberships | [Groups](../notes/users-groups-and-permissions/groups.md) | S N1-4, M2 A3 |
| ☐ | Configure privileged access | [sudo](../notes/users-groups-and-permissions/sudo-and-privileged-access.md) | M2 A5, M3 §3, Sc 5 |

### Manage security

| ✓ | Objective | Learn | Practise |
|---|---|---|---|
| ☐ | Configure firewall settings using firewall-cmd/firewalld | [firewalld](../notes/firewall-and-selinux/firewalld.md) | S N1-3, M2 A11, M3 |
| ☐ | Manage default file permissions | [umask](../notes/users-groups-and-permissions/file-permissions.md#33-umask-default-permissions-rhcsa-core) | S N1-12, M2 A7 |
| ☐ | Configure key-based authentication for SSH | [SSH §3.3](../notes/networking-and-ssh/ssh-remote-access.md#33-key-based-authentication-rhcsa-core) | M2 A21 |
| ☐ | Set enforcing and permissive modes for SELinux | [SELinux §2](../notes/firewall-and-selinux/selinux-fundamentals.md#2-modes-rhcsa-core) | Every mock (must stay enforcing) |
| ☐ | List and identify SELinux file and process context | [SELinux §3](../notes/firewall-and-selinux/selinux-fundamentals.md#3-security-contexts-rhcsa-core) | M3, Sc 2 |
| ☐ | Restore default file contexts | [File contexts](../notes/firewall-and-selinux/selinux-file-contexts.md) | M2 A11, M3, Sc 2 |
| ☐ | Manage SELinux port labels | [Port labels](../notes/firewall-and-selinux/selinux-booleans-ports-troubleshooting.md#3-port-labels-rhcsa-core-supplemented) | S N1-3, M2 A11, M3, Sc 3 |
| ☐ | Use Boolean settings to modify system SELinux settings | [Booleans](../notes/firewall-and-selinux/selinux-booleans-ports-troubleshooting.md#2-booleans-rhcsa-core) | M2 A12 |

**Coverage status:** all 62 objectives have a teaching note and are practised in at least one mock exam task or scenario.

## 2. Linux Internals

| ✓ | Concept | Where | Lab / evidence |
|---|---|---|---|
| ☐ | User vs kernel space, system calls, errno | [Processes & syscalls §3](../notes/processes-and-resource-management/processes-and-system-calls.md#3-system-calls-the-only-door-into-the-kernel) | `strace -c`, `strace -f` |
| ☐ | fork (COW), exec, wait, exit, zombies, orphans, PID 1 | [§4](../notes/processes-and-resource-management/processes-and-system-calls.md#4-process-lifecycle-fork-exec-wait-exit) | Zombie demo, Sc 17 |
| ☐ | Credentials, set-UID, capabilities | [§5](../notes/processes-and-resource-management/processes-and-system-calls.md#5-credentials--privilege) | `grep Cap /proc/self/status` |
| ☐ | File descriptors, open file descriptions, limits | [§6](../notes/processes-and-resource-management/processes-and-system-calls.md#6-file-descriptors) | Sc 9, Sc 13 |
| ☐ | Signals: delivery, masks, process groups, sessions | [§7](../notes/processes-and-resource-management/processes-and-system-calls.md#7-signals-in-depth) | SigIgn demo |
| ☐ | Virtual memory, page faults, page cache, anon vs file | [Memory §2–4](../notes/processes-and-resource-management/memory-management.md#2-virtual-memory-the-core-idea) | mmap demo, page cache lab |
| ☐ | RSS/PSS/USS, reclaim, PSI, overcommit, OOM (global vs cgroup) | [Memory §5–8](../notes/processes-and-resource-management/memory-management.md#5-per-process-memory-vsz-rss-pss-uss) | Sc 15 |
| ☐ | Scheduler basics: nice weights, run queue, load average semantics | [nice](../notes/processes-and-resource-management/process-priority-and-nice.md), [top §2](../notes/processes-and-resource-management/top-and-process-monitoring.md#2-the-summary-area), [cgroups §3.3](../notes/containers-and-virtualization/namespaces-and-cgroups.md#33-cpu-quota-and-throttling-verified) | Sc 16 |
| ☐ | VFS, page cache writeback, fsync, journaling semantics | [Storage I/O §3–5](../notes/storage-and-filesystems/storage-io-path.md#3-vfs-one-interface-for-every-filesystem) | Dirty-pages demo |
| ☐ | Block layer, schedulers, device mapper stack | [Storage I/O §6–7](../notes/storage-and-filesystems/storage-io-path.md#6-the-block-layer--io-schedulers) | `dmsetup ls --tree` |
| ☐ | Boot chain, initramfs, switch-root | [Boot process](../notes/boot-systemd-and-kernel/boot-process.md) | M3 |
| ☐ | systemd unit model, dependencies vs ordering, cgroup tracking | [systemd unit files](../notes/boot-systemd-and-kernel/systemd-unit-files.md) | Unit labs 1–6 |
| ☐ | TCP lifecycle, listen queues, ephemeral ports | [TCP/IP §4–6](../notes/networking-and-ssh/tcp-ip-for-operators.md#4-tcp-connection-lifecycle) | Sc 14, Sc 21 |
| ☐ | Netfilter hooks, nftables, conntrack, NAT | [TCP/IP §11](../notes/networking-and-ssh/tcp-ip-for-operators.md#11-netfilter-nftables--conntrack) | nft lab |
| ☐ | Namespaces (8 types), cgroup v2 controllers, overlayfs | [Namespaces & cgroups](../notes/containers-and-virtualization/namespaces-and-cgroups.md) | Build a container by hand |
| ☐ | SELinux type enforcement, domain transitions, MCS | [SELinux](../notes/firewall-and-selinux/selinux-fundamentals.md), [MCS](../notes/firewall-and-selinux/selinux-mls-and-mcs.md) | `ps -eZ`, passwd demo |
| ☐ | Inodes, links, directory semantics | [Links](../notes/users-groups-and-permissions/links.md), [files & directories](../notes/shell-and-command-line/files-and-directories.md) | `ls -li`, `lsof +L1` |

## 3. Production Troubleshooting

| ✓ | Situation | Method / note | Scenario |
|---|---|---|---|
| ☐ | System won't boot / emergency mode | [Boot recovery](../notes/boot-systemd-and-kernel/boot-recovery.md), [method §5.1](../notes/troubleshooting-and-interviews/troubleshooting-methodology.md#51-the-system-doesnt-boot) | Sc 1, M3 |
| ☐ | Service won't start / 203/EXEC / port bind | [systemd unit files §15](../notes/boot-systemd-and-kernel/systemd-unit-files.md#15-troubleshooting) | Sc 3, Sc 12 |
| ☐ | Permission denied (DAC/ACL/SELinux/capabilities) | [Permissions §4](../notes/users-groups-and-permissions/file-permissions.md#4-diagnosing-permission-problems-rhcsa-core) | Sc 2, Sc 4 |
| ☐ | Disk full (blocks, inodes, deleted-open, thin pool) | [FHS §7](../notes/linux-fundamentals/filesystem-hierarchy.md#7-troubleshooting-production-practice) | Sc 9, Sc 10, Sc 24 |
| ☐ | Slow server (CPU, memory, I/O, throttling) | [Performance §2](../notes/advanced-rhel-and-career-notes/performance-and-observability.md#2-the-first-60-seconds-on-a-slow-linux-host) | Sc 16, Sc 18 |
| ☐ | Memory pressure / OOM kills | [Memory §11](../notes/processes-and-resource-management/memory-management.md#11-troubleshooting) | Sc 15 |
| ☐ | fd exhaustion / socket leaks | [Processes §6.3](../notes/processes-and-resource-management/processes-and-system-calls.md#63-limits-too-many-open-files-emfileenfile), [TCP/IP §4](../notes/networking-and-ssh/tcp-ip-for-operators.md#4-tcp-connection-lifecycle) | Sc 13, Sc 14 |
| ☐ | Unreachable service (bind, firewall, route, DNS, TLS, MTU) | [TCP/IP §16](../notes/networking-and-ssh/tcp-ip-for-operators.md#16-troubleshooting-flow-service-x-is-unreachable) | Sc 19, Sc 20, Sc 21, Sc 22 |
| ☐ | Hung processes / D state / NFS | [Processes §10](../notes/processes-and-resource-management/processes-and-system-calls.md#10-troubleshooting) | Sc 18 |
| ☐ | Scheduled job didn't run | [Job scheduling §9](../notes/logs-scheduling-and-packages/job-scheduling.md#9-troubleshooting) | Sc 6, Sc 11 |
| ☐ | Lost logs / audit trail | [System logging](../notes/logs-scheduling-and-packages/system-logging.md), [auditd](../notes/firewall-and-selinux/auditd.md) | Sc 7 |
| ☐ | Package/kernel update failures | [GRUB2 & kernels](../notes/boot-systemd-and-kernel/grub2-and-kernel-management.md) | Sc 23 |
| ☐ | Crashes (cores, kernel panics) | [Performance §7](../notes/advanced-rhel-and-career-notes/performance-and-observability.md#7-crashes-core-dumps--kernel-dumps) | Lab 5 there |

## 4. DevOps / SRE / Platform Interview Readiness

| ✓ | Area | Prepared by | Status |
|---|---|---|---|
| ☐ | "What happens when…" deep dives (ls, boot, curl) | IQ A1, A2, D1 | Covered |
| ☐ | Linux troubleshooting rounds (live or verbal) | [Method](../notes/troubleshooting-and-interviews/troubleshooting-methodology.md), Sc 1–24, IQ B–D | Covered |
| ☐ | Processes, memory, storage, networking internals | Phase 7 notes, IQ B–D | Covered |
| ☐ | Containers & Kubernetes node fundamentals | [Namespaces & cgroups](../notes/containers-and-virtualization/namespaces-and-cgroups.md), [K8s bridge](../notes/advanced-rhel-and-career-notes/linux-foundations-of-kubernetes.md), IQ B4, D5 | Linux side covered; Kubernetes itself → [GAPS](known-gaps.md) |
| ☐ | Security & hardening | IQ E2–E3, [SSH hardening](../notes/networking-and-ssh/ssh-server-hardening.md), [auditd](../notes/firewall-and-selinux/auditd.md), [systemd sandboxing](../notes/boot-systemd-and-kernel/systemd-unit-files.md#10-sandboxing-hardening) | Covered |
| ☐ | Scripting / live coding (bash, awk) | IQ F1–F3, [robust scripts](../notes/bash-scripting-and-automation/robust-scripts.md) | Covered for bash; Python/Go → [GAPS](known-gaps.md) |
| ☐ | Automation & configuration management | [Ansible starter](../notes/bash-scripting-and-automation/ansible-starter.md), IQ E4 | Starter only → [GAPS](known-gaps.md) (RHCE depth) |
| ☐ | Observability (metrics, logs, tracing) | [Performance & observability](../notes/advanced-rhel-and-career-notes/performance-and-observability.md), IQ E5 | Host level covered; fleet stacks → [GAPS](known-gaps.md) |
| ☐ | System design for operations (patching, logging, HA) | IQ E4–E5 | Introductory → [GAPS](known-gaps.md) |
| ☐ | Cloud platforms, networking at scale, CI/CD | — | Not covered → [GAPS](known-gaps.md) |
