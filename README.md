# Linux Mastery Knowledge Base (RHEL 10): RHCSA → Internals → Production → SRE

A single source of truth for learning Linux on RHEL 10, from the first shell command to the kernel mechanisms behind containers and Kubernetes. It works two ways:

- **As a curriculum:** follow [**CURRICULUM.md**](docs/curriculum.md): phases 0–9 in strict prerequisite order, each with labs and exit criteria. Track progress with the [**ROADMAP**](docs/roadmap.md) checklist.
- **As a reference library:** the topic folders below, each note self-contained (concepts → mechanism → commands → labs → troubleshooting → interview questions → quick revision).

| Start here | Then |
|---|---|
| 1. [CURRICULUM](docs/curriculum.md): what to study, in which order, and why | 3. [COVERAGE](docs/coverage.md): every EX200 objective → notes → practice tasks |
| 2. [Practice lab setup](notes/rhcsa-exam-labs/practice-lab-setup.md): two disposable RHEL 10 VMs | 4. [Mock exam 2](notes/rhcsa-exam-labs/mock-exam-2.md) and [mock exam 3](notes/rhcsa-exam-labs/mock-exam-3.md), graded by scripts after reboot |

**Baseline:** RHEL 10.x · EX200 objectives (62, in 10 categories) re-checked against Red Hat's exam page on 26 Oct 2026 · Known limits and unverified details: [GAPS](docs/known-gaps.md).

## Labels Used in Every Note

| Label | Meaning |
|---|---|
| **[RHCSA Core]** | Maps to a current EX200 objective |
| **[Interview Knowledge]** | Core fundamentals and the "why" behind them |
| **[Internals]** | How the kernel and system work underneath (processes, memory, I/O, networking, cgroups) |
| **[Production Practice]** | Real-world administration, hardening and troubleshooting |
| **[Advanced/Optional]** | Useful, outside EX200, lower priority |

Every note's header lists its **prerequisites**, related notes and, for newer notes, **how its content was verified** (RHEL 10.2 lab).

## Maintenance Tools

```bash
python3 tools/check_notes.py      # broken links, missing anchors, unclosed code fences, stale "planned" markers → must print 0 problems
python3 tools/build_roadmap.py    # regenerate ROADMAP.md from CURRICULUM.md; fails if any note isn't scheduled
bash notes/rhcsa-exam-labs/graders/mock2-server1.sh   # exam graders (read-only; run as root after a reboot)
```

## Topic Index (reference library)

The **Study** column is the note's position in the [curriculum](docs/curriculum.md).

### Exam & labs

| Study | Note |
|---|---|
| 0.5 | [RHCSA Practice Lab Setup (VirtualBox/KVM + Vagrant)](notes/rhcsa-exam-labs/practice-lab-setup.md) |
| 6.6 | [EX200 Objectives Map (RHEL 10)](notes/rhcsa-exam-labs/exam-objectives-map.md) |
| 6.7 | [RHCSA 10 Sample Exam: Corrected Solutions & Verification](notes/rhcsa-exam-labs/sample-exam-with-solutions.md) |
| 6.8 | [RHCSA 10 Mock Exam 2 (Full Objective Coverage, with Grader)](notes/rhcsa-exam-labs/mock-exam-2.md) |
| 6.9 | [RHCSA 10 Mock Exam 3: Break-Fix (with Break Script & Grader)](notes/rhcsa-exam-labs/mock-exam-3.md) |

### Linux fundamentals

| Study | Note |
|---|---|
| 0.1 | [RHCSA Exam (EX200) & Red Hat Certification Path](notes/linux-fundamentals/rhcsa-exam-and-certification.md) |
| 0.2 | [RHEL 9 vs RHEL 10](notes/linux-fundamentals/rhel-9-vs-rhel-10.md) |
| 0.3 | [UNIX/Linux History & Architecture](notes/linux-fundamentals/unix-linux-history-and-architecture.md) |
| 0.4 | [Virtualization & RHEL 10 Lab Setup](notes/linux-fundamentals/virtualization-and-lab-setup.md) |
| 1.3 | [Filesystem Hierarchy (RHEL 10)](notes/linux-fundamentals/filesystem-hierarchy.md) |

### Shell & command line

| Study | Note |
|---|---|
| 1.1 | [Shell Basics & Command Syntax](notes/shell-and-command-line/shell-basics-and-command-syntax.md) |
| 1.2 | [Getting Help & System Documentation](notes/shell-and-command-line/getting-help-and-documentation.md) |
| 1.4 | [Working with Files & Directories](notes/shell-and-command-line/files-and-directories.md) |
| 1.5 | [Quoting, Arguments & Control Operators](notes/shell-and-command-line/quoting-and-control-operators.md) |
| 1.6 | [Shell Variables, Environment & Positional Parameters](notes/shell-and-command-line/shell-variables-and-environment.md) |
| 1.7 | [Shell Expansion & File Globbing](notes/shell-and-command-line/shell-expansion-and-globbing.md) |
| 1.8 | [Command Substitution, Subshells & Shell Options](notes/shell-and-command-line/command-substitution-and-shell-options.md) |
| 1.9 | [Command History](notes/shell-and-command-line/command-history.md) |

### Files & text processing

| Study | Note |
|---|---|
| 1.10 | [Viewing & Creating File Contents](notes/files-and-text-processing/viewing-and-creating-file-contents.md) |
| 1.11 | [vi & vim](notes/files-and-text-processing/vi-and-vim.md) |
| 1.12 | [I/O Redirection & Pipes](notes/files-and-text-processing/io-redirection-and-pipes.md) |
| 1.13 | [grep & Regular Expressions](notes/files-and-text-processing/grep-and-regular-expressions.md) |
| 1.14 | [Text Filters & Pipelines](notes/files-and-text-processing/text-filters.md) |
| 1.15 | [awk](notes/files-and-text-processing/awk.md) |
| 1.16 | [Finding Files: `find` & `locate`](notes/files-and-text-processing/finding-files.md) |
| 1.17 | [Archiving & Compression](notes/files-and-text-processing/archiving-and-compression.md) |

### Users, groups, permissions & identity

| Study | Note |
|---|---|
| 2.1 | [Local User Accounts](notes/users-groups-and-permissions/local-users.md) |
| 2.2 | [Passwords, Aging & Account Locking](notes/users-groups-and-permissions/passwords-and-aging.md) |
| 2.3 | [Groups & Group Membership](notes/users-groups-and-permissions/groups.md) |
| 2.4 | [Shell Startup (Profile) Files](notes/users-groups-and-permissions/shell-startup-files.md) |
| 2.5 | [File Permissions, Ownership & umask](notes/users-groups-and-permissions/file-permissions.md) |
| 2.6 | [Special Permissions (SUID, SGID, Sticky) & ACLs](notes/users-groups-and-permissions/special-permissions-and-acls.md) |
| 2.7 | [Inodes, Hard Links & Symbolic Links](notes/users-groups-and-permissions/links.md) |
| 2.8 | [sudo & Privileged Access](notes/users-groups-and-permissions/sudo-and-privileged-access.md) |
| 2.9 | [PAM & authselect: Authentication Policy on RHEL 10](notes/users-groups-and-permissions/pam-and-authselect.md) |
| 2.10 | [Central Identity: NSS, SSSD & Directory Users (Concepts)](notes/users-groups-and-permissions/central-identity-nss-sssd.md) |

### Processes, memory & resources

| Study | Note |
|---|---|
| 3.3 | [Processes, Signals & Job Control](notes/processes-and-resource-management/processes-and-signals.md) |
| 3.4 | [top & Process Monitoring](notes/processes-and-resource-management/top-and-process-monitoring.md) |
| 3.5 | [Process Priority & nice/renice](notes/processes-and-resource-management/process-priority-and-nice.md) |
| 3.6 | [System Resource Monitoring: free, vmstat, iostat, mpstat, sar](notes/processes-and-resource-management/system-resource-monitoring.md) |
| 7.1 | [Processes & System Calls: How Programs Actually Run](notes/processes-and-resource-management/processes-and-system-calls.md) |
| 7.2 | [Linux Memory Management](notes/processes-and-resource-management/memory-management.md) |

### Storage & filesystems

| Study | Note |
|---|---|
| 4.1 | [Disks, Device Naming & Partitioning (GPT)](notes/storage-and-filesystems/disks-and-partitioning.md) |
| 4.2 | [Filesystems: Types, Creation & Tuning (XFS, ext4, VFAT)](notes/storage-and-filesystems/filesystems-and-mkfs.md) |
| 4.3 | [Mounting, Mount Options & /etc/fstab](notes/storage-and-filesystems/mounting-and-fstab.md) |
| 4.4 | [LVM Fundamentals: PVs, VGs, LVs & Resizing](notes/storage-and-filesystems/lvm-fundamentals.md) |
| 4.5 | [Swap: Partitions, LVs, Swap Files & Swappiness](notes/storage-and-filesystems/swap.md) |
| 4.6 | [Filesystem Check & Repair (e2fsck, fsck, xfs_repair)](notes/storage-and-filesystems/filesystem-check-and-repair.md) |
| 4.7 | [LVM Snapshots & Metadata Recovery](notes/storage-and-filesystems/lvm-snapshots-and-recovery.md) |
| 7.3 | [The Storage I/O Path: From `write()` to the Disk](notes/storage-and-filesystems/storage-io-path.md) |
| 8.6 | [LUKS Disk Encryption](notes/storage-and-filesystems/luks-encryption.md) |
| 8.6 | [Moving LVM Volume Groups Between Systems](notes/storage-and-filesystems/lvm-moving-vgs-between-systems.md) |
| 8.6 | [LVM Thin Provisioning & Striping](notes/storage-and-filesystems/lvm-thin-provisioning-and-striping.md) |
| 8.6 | [VDO on LVM (Deduplication & Compression)](notes/storage-and-filesystems/lvm-vdo.md) |
| 8.6 | [VG Merge/Split, Renaming & Online Disk Migration (pvmove)](notes/storage-and-filesystems/lvm-vg-merge-split-and-migration.md) |
| 8.6 | [Software RAID with mdadm](notes/storage-and-filesystems/raid-mdadm.md) |
| 8.6 | [Stratis Storage](notes/storage-and-filesystems/stratis.md) |
| 8.6 | [XFS Disk Quotas (User, Group & Project)](notes/storage-and-filesystems/xfs-quotas.md) |

### Boot, systemd & kernel

| Study | Note |
|---|---|
| 3.7 | [systemd Targets & Service Management](notes/boot-systemd-and-kernel/systemd-targets-and-services.md) |
| 3.11 | [The RHEL 10 Boot Process](notes/boot-systemd-and-kernel/boot-process.md) |
| 3.12 | [GRUB2, Kernel Arguments & Kernel Packages](notes/boot-systemd-and-kernel/grub2-and-kernel-management.md) |
| 3.13 | [Boot Recovery: Root Password Reset, GRUB Password, Boot Loops, Broken fstab, Kernel Panic](notes/boot-systemd-and-kernel/boot-recovery.md) |
| 3.14 | [Kernel Modules & Kernel Parameters (sysctl)](notes/boot-systemd-and-kernel/kernel-modules-and-parameters.md) |
| 7.4 | [systemd Unit Files: Writing, Overriding & Hardening Services](notes/boot-systemd-and-kernel/systemd-unit-files.md) |
| 8.10 | [Compiling a Custom Kernel](notes/boot-systemd-and-kernel/kernel-compilation.md) |

### Logs, scheduling & packages

| Study | Note |
|---|---|
| 3.1 | [RPM & DNF Package Management](notes/logs-scheduling-and-packages/rpm-and-dnf-package-management.md) |
| 3.2 | [Flatpak on RHEL 10](notes/logs-scheduling-and-packages/flatpak.md) |
| 3.8 | [System Logging: journald, rsyslog & logrotate](notes/logs-scheduling-and-packages/system-logging.md) |
| 3.9 | [Job Scheduling: at, batch, cron, anacron & systemd Timers](notes/logs-scheduling-and-packages/job-scheduling.md) |
| 8.10 | [Building RPM Packages](notes/logs-scheduling-and-packages/rpm-package-building.md) |

### Networking & SSH

| Study | Note |
|---|---|
| 5.1 | [IP Addressing Fundamentals (IPv4 & IPv6)](notes/networking-and-ssh/ip-addressing-fundamentals.md) |
| 5.2 | [NetworkManager & nmcli: IPv4, IPv6, DNS & Hostname](notes/networking-and-ssh/networkmanager-nmcli.md) |
| 5.3 | [Routing on RHEL 10: Routes, Gateways & Static Routing](notes/networking-and-ssh/routing.md) |
| 5.4 | [SSH: Remote Access, Keys, File Transfer & Switching Users](notes/networking-and-ssh/ssh-remote-access.md) |
| 5.5 | [SSH Server Configuration & Hardening](notes/networking-and-ssh/ssh-server-hardening.md) |
| 5.6 | [Cryptography Basics for Linux Admins](notes/networking-and-ssh/cryptography-basics.md) |
| 5.7 | [rsync & Automated Remote Backups](notes/networking-and-ssh/rsync-and-remote-backups.md) |
| 7.5 | [TCP/IP for Operators: Sockets, Connection States, Netfilter & the Packet Path](notes/networking-and-ssh/tcp-ip-for-operators.md) |
| 8.7 | [Network Bonding on RHEL 10](notes/networking-and-ssh/network-bonding.md) |
| 8.7 | [Packet Capture & Network Sniffing: tcpdump, tshark, Wireshark](notes/networking-and-ssh/packet-capture.md) |
| 8.7 | [SSH Port Forwarding (Tunneling)](notes/networking-and-ssh/ssh-port-forwarding.md) |

### Firewall, SELinux & auditing

| Study | Note |
|---|---|
| 5.10 | [firewalld: Zones, Services, Ports, NAT & Rich Rules](notes/firewall-and-selinux/firewalld.md) |
| 5.11 | [SELinux Fundamentals: Modes, Contexts & Domain Transitions](notes/firewall-and-selinux/selinux-fundamentals.md) |
| 5.12 | [SELinux File Contexts: chcon, semanage fcontext & restorecon](notes/firewall-and-selinux/selinux-file-contexts.md) |
| 5.13 | [SELinux Booleans, Port Labels & Troubleshooting](notes/firewall-and-selinux/selinux-booleans-ports-troubleshooting.md) |
| 8.5 | [Linux Auditing with auditd](notes/firewall-and-selinux/auditd.md) |
| 8.5 | [SELinux Targeted Policy: Confined Domains & Confined Users](notes/firewall-and-selinux/selinux-confined-users-and-domains.md) |
| 8.5 | [SELinux MLS & MCS (Security Levels and Categories)](notes/firewall-and-selinux/selinux-mls-and-mcs.md) |

### System services & shared storage

| Study | Note |
|---|---|
| 5.8 | [Time Synchronization with chrony (NTP)](notes/system-services-and-shared-storage/chrony-time-sync.md) |
| 5.9 | [NFS & autofs](notes/system-services-and-shared-storage/nfs-and-autofs.md) |
| 5.14 | [Apache HTTP Server (httpd) on RHEL 10](notes/system-services-and-shared-storage/apache-httpd.md) |
| 8.8 | [DNS with BIND (named): Concepts, Zones & Testing](notes/system-services-and-shared-storage/dns-bind.md) |
| 8.8 | [iSCSI Target (targetcli) & Initiator (iscsiadm)](notes/system-services-and-shared-storage/iscsi.md) |
| 8.8 | [DM-Multipath (Redundant Storage Paths)](notes/system-services-and-shared-storage/multipath.md) |
| 8.8 | [Samba (SMB) Server & CIFS Client](notes/system-services-and-shared-storage/samba.md) |
| 8.8 | [FTP with vsftpd](notes/system-services-and-shared-storage/vsftpd-ftp.md) |

### Containers, virtualization & tuning

| Study | Note |
|---|---|
| 3.10 | [Tuning Profiles with tuned](notes/containers-and-virtualization/tuned-profiles.md) |
| 7.6 | [Namespaces, cgroups & How Containers Are Built](notes/containers-and-virtualization/namespaces-and-cgroups.md) |
| 8.9 | [Cockpit: The RHEL Web Console](notes/containers-and-virtualization/cockpit-web-console.md) |
| 8.9 | [RHEL Image Builder (osbuild-composer)](notes/containers-and-virtualization/image-builder.md) |
| 8.9 | [KVM Virtualization on RHEL 10 (libvirt, virsh, virt-install, Cockpit)](notes/containers-and-virtualization/kvm-virtualization.md) |
| 8.9 | [Podman Containers on RHEL 10](notes/containers-and-virtualization/podman-containers.md) |
| 8.9 | [Hardware Virtualization vs Containers (OS Virtualization)](notes/containers-and-virtualization/virtualization-vs-containers.md) |

### Bash scripting & automation

| Study | Note |
|---|---|
| 6.1 | [Bash Scripting Basics: Scripts, Shebang, Output & Variables](notes/bash-scripting-and-automation/script-basics-and-variables.md) |
| 6.2 | [Script Input: read, Positional Parameters & Argument Handling](notes/bash-scripting-and-automation/script-input-and-arguments.md) |
| 6.3 | [Conditionals: if/elif/else, test, [[ ]], File Tests & case](bash-scripting-and-automation/conditionals-and-tests.md) |
| 6.4 | [Loops: for, while, until, break/continue & Processing Input](notes/bash-scripting-and-automation/loops.md) |
| 6.5 | [Arithmetic in Bash: $(( )), let, expr & bc](notes/bash-scripting-and-automation/arithmetic.md) |
| 8.3 | [Writing Robust, Production-Safe Bash Scripts](notes/bash-scripting-and-automation/robust-scripts.md) |
| 8.4 | [Ansible Starter: Your RHCSA Tasks as Code](notes/bash-scripting-and-automation/ansible-starter.md) |

### Troubleshooting & interviews

| Study | Note |
|---|---|
| 8.1 | [Troubleshooting Methodology](notes/troubleshooting-and-interviews/troubleshooting-methodology.md) |
| 8.12 | [Break-Fix & Production Scenarios (with Solutions)](notes/troubleshooting-and-interviews/production-scenarios.md) |
| 9.2 | [Interview Question Bank (with Model Answers)](notes/troubleshooting-and-interviews/interview-question-bank.md) |

### Advanced RHEL, observability & career

| Study | Note |
|---|---|
| 8.2 | [Performance Analysis & Observability](notes/advanced-rhel-and-career-notes/performance-and-observability.md) |
| 8.11 | [Command Line Assistant (RHEL Lightspeed)](notes/advanced-rhel-and-career-notes/rhel-lightspeed-command-line-assistant.md) |
| 9.1 | [Linux Foundations of Kubernetes (Bridge Note)](notes/advanced-rhel-and-career-notes/linux-foundations-of-kubernetes.md) |

