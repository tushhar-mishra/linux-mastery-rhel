# Linux & RHCSA Knowledge Base (RHEL 10)

Topic-organized notes for **RHCSA (EX200, RHEL 10)**, Linux administration interviews, and production troubleshooting. Organized by **technical topic**, not by lecture.

- **Baseline:** RHEL 10.x · EX200 objectives as published by Red Hat (verified Oct 2026)
- **Source course:** 104-session RHCSA course (RHEL 10), consolidated, corrected and supplemented
- **Start here:** [EX200 objectives map](rhcsa-exam-labs/exam-objectives-map.md) → [practice lab](rhcsa-exam-labs/practice-lab-setup.md) → [sample exam](rhcsa-exam-labs/sample-exam-with-solutions.md)

## Label Legend

| Label | Meaning |
|---|---|
| **[RHCSA Core]** | Maps to a current official EX200 objective |
| **[Production Practice]** | Real-world administration and troubleshooting |
| **[Interview Knowledge]** | Conceptual depth and scenario reasoning |
| **[Advanced/Optional]** | Useful, but outside current EX200 scope |

## Topic Index

### Exam & labs
- [EX200 objectives map (RHEL 10)](rhcsa-exam-labs/exam-objectives-map.md)
- [Practice lab setup (Vagrant/VirtualBox/KVM)](rhcsa-exam-labs/practice-lab-setup.md)
- [Sample exam with corrected solutions](rhcsa-exam-labs/sample-exam-with-solutions.md)

### Linux fundamentals
- [RHCSA exam & Red Hat certification path](linux-fundamentals/rhcsa-exam-and-certification.md)
- [RHEL 9 vs RHEL 10](linux-fundamentals/rhel-9-vs-rhel-10.md)
- [UNIX/Linux history & architecture](linux-fundamentals/unix-linux-history-and-architecture.md)
- [Virtualization & RHEL 10 lab setup](linux-fundamentals/virtualization-and-lab-setup.md)
- [Filesystem hierarchy (RHEL 10)](linux-fundamentals/filesystem-hierarchy.md)

### Shell & command line
- [Shell basics & command syntax](shell-and-command-line/shell-basics-and-command-syntax.md)
- [Getting help & system documentation](shell-and-command-line/getting-help-and-documentation.md)
- [Working with files & directories](shell-and-command-line/files-and-directories.md)
- [Quoting, arguments & control operators](shell-and-command-line/quoting-and-control-operators.md)
- [Shell variables, environment & positional parameters](shell-and-command-line/shell-variables-and-environment.md)
- [Command substitution, subshells & shell options](shell-and-command-line/command-substitution-and-shell-options.md)
- [Command history](shell-and-command-line/command-history.md)
- [Shell expansion & globbing](shell-and-command-line/shell-expansion-and-globbing.md)

### Files & text processing
- [Viewing & creating file contents](files-and-text-processing/viewing-and-creating-file-contents.md)
- [Archiving & compression](files-and-text-processing/archiving-and-compression.md)
- [I/O redirection & pipes](files-and-text-processing/io-redirection-and-pipes.md)
- [Text filters & pipelines](files-and-text-processing/text-filters.md)
- [Finding files: find & locate](files-and-text-processing/finding-files.md)
- [awk](files-and-text-processing/awk.md)
- [grep & regular expressions](files-and-text-processing/grep-and-regular-expressions.md)
- [vi & vim](files-and-text-processing/vi-and-vim.md)

### Users, groups & permissions
- [Local user accounts](users-groups-and-permissions/local-users.md)
- [Passwords, aging & account locking](users-groups-and-permissions/passwords-and-aging.md)
- [Shell startup (profile) files](users-groups-and-permissions/shell-startup-files.md)
- [Groups & group membership](users-groups-and-permissions/groups.md)
- [File permissions, ownership & umask](users-groups-and-permissions/file-permissions.md)
- [Special permissions (SUID, SGID, sticky) & ACLs](users-groups-and-permissions/special-permissions-and-acls.md)
- [sudo & privileged access](users-groups-and-permissions/sudo-and-privileged-access.md)
- [Inodes, hard links & symbolic links](users-groups-and-permissions/links.md)
- [PAM & authselect](users-groups-and-permissions/pam-and-authselect.md)

### Processes & resource management
- [Processes, signals & job control](processes-and-resource-management/processes-and-signals.md)
- [top & process monitoring](processes-and-resource-management/top-and-process-monitoring.md)
- [System resource monitoring (free, vmstat, iostat, mpstat, sar)](processes-and-resource-management/system-resource-monitoring.md)
- [Process priority & nice/renice](processes-and-resource-management/process-priority-and-nice.md)

### Storage & filesystems
- [Disks, device naming & partitioning (GPT)](storage-and-filesystems/disks-and-partitioning.md)
- [Filesystems: types, creation & tuning (XFS, ext4, VFAT)](storage-and-filesystems/filesystems-and-mkfs.md)
- [Mounting, mount options & /etc/fstab](storage-and-filesystems/mounting-and-fstab.md)
- [LVM fundamentals: PVs, VGs, LVs & resizing](storage-and-filesystems/lvm-fundamentals.md)
- [LVM snapshots & metadata recovery](storage-and-filesystems/lvm-snapshots-and-recovery.md)
- [VG merge/split & online disk migration (pvmove)](storage-and-filesystems/lvm-vg-merge-split-and-migration.md)
- [LVM thin provisioning & striping](storage-and-filesystems/lvm-thin-provisioning-and-striping.md)
- [Moving LVM VGs between systems](storage-and-filesystems/lvm-moving-vgs-between-systems.md)
- [Swap: partitions, LVs, swap files & swappiness](storage-and-filesystems/swap.md)
- [Software RAID with mdadm](storage-and-filesystems/raid-mdadm.md)
- [XFS disk quotas](storage-and-filesystems/xfs-quotas.md)
- [VDO on LVM](storage-and-filesystems/lvm-vdo.md)
- [Stratis](storage-and-filesystems/stratis.md)
- [LUKS disk encryption](storage-and-filesystems/luks-encryption.md)
- [Filesystem check & repair](storage-and-filesystems/filesystem-check-and-repair.md)

### Boot, systemd & kernel
- [The RHEL 10 boot process](boot-systemd-and-kernel/boot-process.md)
- [systemd targets & service management](boot-systemd-and-kernel/systemd-targets-and-services.md)
- [GRUB2, kernel arguments & kernel packages](boot-systemd-and-kernel/grub2-and-kernel-management.md)
- [Boot recovery: root password, GRUB password, boot loops, kernel panic](boot-systemd-and-kernel/boot-recovery.md)
- [Kernel modules & kernel parameters (sysctl)](boot-systemd-and-kernel/kernel-modules-and-parameters.md)
- [Compiling a custom kernel](boot-systemd-and-kernel/kernel-compilation.md)

### Logs, scheduling & packages
- [Job scheduling: at, cron, anacron & systemd timers](logs-scheduling-and-packages/job-scheduling.md)
- [System logging: journald, rsyslog & logrotate](logs-scheduling-and-packages/system-logging.md)
- [RPM & DNF package management](logs-scheduling-and-packages/rpm-and-dnf-package-management.md)
- [Flatpak](logs-scheduling-and-packages/flatpak.md)
- [Building RPM packages](logs-scheduling-and-packages/rpm-package-building.md)

### Networking & SSH
- [IP addressing fundamentals (IPv4 & IPv6)](networking-and-ssh/ip-addressing-fundamentals.md)
- [NetworkManager & nmcli: IPv4, IPv6, DNS & hostname](networking-and-ssh/networkmanager-nmcli.md)
- [Network bonding](networking-and-ssh/network-bonding.md)
- [Routing](networking-and-ssh/routing.md)
- [Packet capture: tcpdump, tshark, Wireshark](networking-and-ssh/packet-capture.md)
- [SSH: remote access, keys, file transfer & switching users](networking-and-ssh/ssh-remote-access.md)
- [SSH server configuration & hardening](networking-and-ssh/ssh-server-hardening.md)
- [SSH port forwarding (tunneling)](networking-and-ssh/ssh-port-forwarding.md)
- [Cryptography basics](networking-and-ssh/cryptography-basics.md)
- [rsync & automated remote backups](networking-and-ssh/rsync-and-remote-backups.md)

### Firewall & SELinux
- [firewalld: zones, services, ports, NAT & rich rules](firewall-and-selinux/firewalld.md)
- [SELinux fundamentals: modes, contexts & domain transitions](firewall-and-selinux/selinux-fundamentals.md)
- [SELinux file contexts: chcon, semanage fcontext & restorecon](firewall-and-selinux/selinux-file-contexts.md)
- [SELinux booleans, port labels & troubleshooting](firewall-and-selinux/selinux-booleans-ports-troubleshooting.md)
- [SELinux confined domains & confined users](firewall-and-selinux/selinux-confined-users-and-domains.md)
- [SELinux MLS & MCS](firewall-and-selinux/selinux-mls-and-mcs.md)

### Containers, virtualization & tuning
- [Cockpit web console](containers-and-virtualization/cockpit-web-console.md)
- [RHEL Image Builder](containers-and-virtualization/image-builder.md)
- [KVM virtualization](containers-and-virtualization/kvm-virtualization.md)
- [Hardware virtualization vs containers](containers-and-virtualization/virtualization-vs-containers.md)
- [Podman containers](containers-and-virtualization/podman-containers.md)
- [Tuning profiles with tuned](containers-and-virtualization/tuned-profiles.md)

### Bash scripting & automation
- [Script basics: shebang, output & variables](bash-scripting-and-automation/script-basics-and-variables.md)
- [Script input: read & positional parameters](bash-scripting-and-automation/script-input-and-arguments.md)
- [Conditionals: if, test, [[ ]], file tests & case](bash-scripting-and-automation/conditionals-and-tests.md)
- [Loops: for, while, until & processing input](bash-scripting-and-automation/loops.md)
- [Arithmetic: $(( )), let, expr & bc](bash-scripting-and-automation/arithmetic.md)

### System services & shared storage
- [Time synchronization with chrony](system-services-and-shared-storage/chrony-time-sync.md)
- [Apache HTTP Server
