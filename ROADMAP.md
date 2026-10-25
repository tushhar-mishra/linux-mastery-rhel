# Study Roadmap (Checklist)

> Generated from [CURRICULUM.md](CURRICULUM.md) by `tools/build_roadmap.py`; edit the curriculum, then regenerate.
> Tick items as you finish them **including their labs**. Don't start a phase until the previous phase's exit criteria
> (in the curriculum) are met without notes. Items marked *optional* in the curriculum can wait for Phase 8.

Milestones: **after Phase 6 → sit the RHCSA (EX200)** · after Phase 8 → production-ready · Phase 9 → interview-ready.

## Phase 0: Orientation & Lab

- [ ] **0.1** [RHCSA exam & certification](linux-fundamentals/rhcsa-exam-and-certification.md)
- [ ] **0.2** [RHEL 9 vs RHEL 10](linux-fundamentals/rhel-9-vs-rhel-10.md)
- [ ] **0.3** [UNIX/Linux history & architecture](linux-fundamentals/unix-linux-history-and-architecture.md)
- [ ] **0.4** [Virtualization & lab setup](linux-fundamentals/virtualization-and-lab-setup.md)
- [ ] **0.5** [Practice lab setup](rhcsa-exam-labs/practice-lab-setup.md)

## Phase 1: The Shell & Text Toolkit

- [ ] **1.1** [Shell basics & command syntax](shell-and-command-line/shell-basics-and-command-syntax.md)
- [ ] **1.2** [Getting help & documentation](shell-and-command-line/getting-help-and-documentation.md)
- [ ] **1.3** [Filesystem hierarchy](linux-fundamentals/filesystem-hierarchy.md)
- [ ] **1.4** [Files & directories](shell-and-command-line/files-and-directories.md)
- [ ] **1.5** [Quoting & control operators](shell-and-command-line/quoting-and-control-operators.md)
- [ ] **1.6** [Variables & environment](shell-and-command-line/shell-variables-and-environment.md)
- [ ] **1.7** [Expansion & globbing](shell-and-command-line/shell-expansion-and-globbing.md)
- [ ] **1.8** [Command substitution & shell options](shell-and-command-line/command-substitution-and-shell-options.md)
- [ ] **1.9** [Command history](shell-and-command-line/command-history.md)
- [ ] **1.10** [Viewing & creating files](files-and-text-processing/viewing-and-creating-file-contents.md)
- [ ] **1.11** [vi & vim](files-and-text-processing/vi-and-vim.md)
- [ ] **1.12** [I/O redirection & pipes](files-and-text-processing/io-redirection-and-pipes.md)
- [ ] **1.13** [grep & regular expressions](files-and-text-processing/grep-and-regular-expressions.md)
- [ ] **1.14** [Text filters](files-and-text-processing/text-filters.md)
- [ ] **1.15** [awk](files-and-text-processing/awk.md)
- [ ] **1.16** [Finding files](files-and-text-processing/finding-files.md)
- [ ] **1.17** [Archiving & compression](files-and-text-processing/archiving-and-compression.md)

## Phase 2: Users, Permissions & Privilege

- [ ] **2.1** [Local users](users-groups-and-permissions/local-users.md)
- [ ] **2.2** [Passwords & aging](users-groups-and-permissions/passwords-and-aging.md)
- [ ] **2.3** [Groups](users-groups-and-permissions/groups.md)
- [ ] **2.4** [Shell startup files](users-groups-and-permissions/shell-startup-files.md)
- [ ] **2.5** [File permissions & umask](users-groups-and-permissions/file-permissions.md)
- [ ] **2.6** [Special permissions & ACLs](users-groups-and-permissions/special-permissions-and-acls.md)
- [ ] **2.7** [Inodes & links](users-groups-and-permissions/links.md)
- [ ] **2.8** [sudo & privileged access](users-groups-and-permissions/sudo-and-privileged-access.md)
- [ ] **2.9** [PAM & authselect](users-groups-and-permissions/pam-and-authselect.md)
- [ ] **2.10** [Central identity (NSS/SSSD)](users-groups-and-permissions/central-identity-nss-sssd.md)

## Phase 3: Operating the System (Software, Processes, Services, Boot)

- [ ] **3.1** [RPM & DNF](logs-scheduling-and-packages/rpm-and-dnf-package-management.md)
- [ ] **3.2** [Flatpak](logs-scheduling-and-packages/flatpak.md)
- [ ] **3.3** [Processes, signals & job control](processes-and-resource-management/processes-and-signals.md)
- [ ] **3.4** [top & monitoring](processes-and-resource-management/top-and-process-monitoring.md)
- [ ] **3.5** [Priority & nice](processes-and-resource-management/process-priority-and-nice.md)
- [ ] **3.6** [Resource monitoring](processes-and-resource-management/system-resource-monitoring.md)
- [ ] **3.7** [systemd targets & services](boot-systemd-and-kernel/systemd-targets-and-services.md)
- [ ] **3.8** [System logging](logs-scheduling-and-packages/system-logging.md)
- [ ] **3.9** [Job scheduling](logs-scheduling-and-packages/job-scheduling.md)
- [ ] **3.10** [tuned profiles](containers-and-virtualization/tuned-profiles.md)
- [ ] **3.11** [Boot process](boot-systemd-and-kernel/boot-process.md)
- [ ] **3.12** [GRUB2 & kernels](boot-systemd-and-kernel/grub2-and-kernel-management.md)
- [ ] **3.13** [Boot recovery](boot-systemd-and-kernel/boot-recovery.md)
- [ ] **3.14** [Kernel modules & sysctl](boot-systemd-and-kernel/kernel-modules-and-parameters.md)

## Phase 4: Storage

- [ ] **4.1** [Disks & partitioning (GPT)](storage-and-filesystems/disks-and-partitioning.md)
- [ ] **4.2** [Filesystems & mkfs](storage-and-filesystems/filesystems-and-mkfs.md)
- [ ] **4.3** [Mounting & fstab](storage-and-filesystems/mounting-and-fstab.md)
- [ ] **4.4** [LVM fundamentals](storage-and-filesystems/lvm-fundamentals.md)
- [ ] **4.5** [Swap](storage-and-filesystems/swap.md)
- [ ] **4.6** [Filesystem check & repair](storage-and-filesystems/filesystem-check-and-repair.md)
- [ ] **4.7** [LVM snapshots & recovery](storage-and-filesystems/lvm-snapshots-and-recovery.md)

## Phase 5: Networking, Remote Access & Security

- [ ] **5.1** [IP addressing](networking-and-ssh/ip-addressing-fundamentals.md)
- [ ] **5.2** [NetworkManager & nmcli](networking-and-ssh/networkmanager-nmcli.md)
- [ ] **5.3** [Routing](networking-and-ssh/routing.md)
- [ ] **5.4** [SSH remote access](networking-and-ssh/ssh-remote-access.md)
- [ ] **5.5** [SSH server hardening](networking-and-ssh/ssh-server-hardening.md)
- [ ] **5.6** [Cryptography basics](networking-and-ssh/cryptography-basics.md)
- [ ] **5.7** [rsync & remote backups](networking-and-ssh/rsync-and-remote-backups.md)
- [ ] **5.8** [chrony](system-services-and-shared-storage/chrony-time-sync.md)
- [ ] **5.9** [NFS & autofs](system-services-and-shared-storage/nfs-and-autofs.md)
- [ ] **5.10** [firewalld](firewall-and-selinux/firewalld.md)
- [ ] **5.11** [SELinux fundamentals](firewall-and-selinux/selinux-fundamentals.md)
- [ ] **5.12** [SELinux file contexts](firewall-and-selinux/selinux-file-contexts.md)
- [ ] **5.13** [SELinux booleans, ports & troubleshooting](firewall-and-selinux/selinux-booleans-ports-troubleshooting.md)
- [ ] **5.14** [Apache httpd](system-services-and-shared-storage/apache-httpd.md)

## Phase 6: Shell Scripting & RHCSA Exam Readiness

- [ ] **6.1** [Script basics](bash-scripting-and-automation/script-basics-and-variables.md)
- [ ] **6.2** [Script input](bash-scripting-and-automation/script-input-and-arguments.md)
- [ ] **6.3** [Conditionals](bash-scripting-and-automation/conditionals-and-tests.md)
- [ ] **6.4** [Loops](bash-scripting-and-automation/loops.md)
- [ ] **6.5** [Arithmetic](bash-scripting-and-automation/arithmetic.md)
- [ ] **6.6** [Objectives map](rhcsa-exam-labs/exam-objectives-map.md)
- [ ] **6.6** [COVERAGE](COVERAGE.md)
- [ ] **6.7** [Sample exam](rhcsa-exam-labs/sample-exam-with-solutions.md)
- [ ] **6.8** [Mock exam 2](rhcsa-exam-labs/mock-exam-2.md)
- [ ] **6.9** [Mock exam 3 (break-fix)](rhcsa-exam-labs/mock-exam-3.md)

## Phase 7: Linux Internals

- [ ] **7.1** [Processes & system calls](processes-and-resource-management/processes-and-system-calls.md)
- [ ] **7.2** [Memory management](processes-and-resource-management/memory-management.md)
- [ ] **7.3** [Storage I/O path](storage-and-filesystems/storage-io-path.md)
- [ ] **7.4** [systemd unit files](boot-systemd-and-kernel/systemd-unit-files.md)
- [ ] **7.5** [TCP/IP for operators](networking-and-ssh/tcp-ip-for-operators.md)
- [ ] **7.6** [Namespaces & cgroups](containers-and-virtualization/namespaces-and-cgroups.md)

## Phase 8: Production Engineering

- [ ] **8.1** [Troubleshooting methodology](troubleshooting-and-interviews/troubleshooting-methodology.md)
- [ ] **8.2** [Performance & observability](advanced-rhel-and-career-notes/performance-and-observability.md)
- [ ] **8.3** [Robust scripts](bash-scripting-and-automation/robust-scripts.md)
- [ ] **8.4** [Ansible starter](bash-scripting-and-automation/ansible-starter.md)
- [ ] **8.5** [auditd](firewall-and-selinux/auditd.md)
- [ ] **8.5** [SELinux confined users](firewall-and-selinux/selinux-confined-users-and-domains.md)
- [ ] **8.5** [SELinux MLS/MCS](firewall-and-selinux/selinux-mls-and-mcs.md)
- [ ] **8.6** [Thin provisioning & striping](storage-and-filesystems/lvm-thin-provisioning-and-striping.md)
- [ ] **8.6** [VG merge/split & pvmove](storage-and-filesystems/lvm-vg-merge-split-and-migration.md)
- [ ] **8.6** [Moving VGs](storage-and-filesystems/lvm-moving-vgs-between-systems.md)
- [ ] **8.6** [RAID](storage-and-filesystems/raid-mdadm.md)
- [ ] **8.6** [LUKS](storage-and-filesystems/luks-encryption.md)
- [ ] **8.6** [XFS quotas](storage-and-filesystems/xfs-quotas.md)
- [ ] **8.6** [VDO](storage-and-filesystems/lvm-vdo.md)
- [ ] **8.6** [Stratis](storage-and-filesystems/stratis.md)
- [ ] **8.7** [Bonding](networking-and-ssh/network-bonding.md)
- [ ] **8.7** [Packet capture](networking-and-ssh/packet-capture.md)
- [ ] **8.7** [SSH tunneling](networking-and-ssh/ssh-port-forwarding.md)
- [ ] **8.8** [DNS (BIND)](system-services-and-shared-storage/dns-bind.md)
- [ ] **8.8** [Samba](system-services-and-shared-storage/samba.md)
- [ ] **8.8** [vsftpd](system-services-and-shared-storage/vsftpd-ftp.md)
- [ ] **8.8** [iSCSI](system-services-and-shared-storage/iscsi.md)
- [ ] **8.8** [Multipath](system-services-and-shared-storage/multipath.md)
- [ ] **8.9** [VMs vs containers](containers-and-virtualization/virtualization-vs-containers.md)
- [ ] **8.9** [Podman](containers-and-virtualization/podman-containers.md)
- [ ] **8.9** [KVM](containers-and-virtualization/kvm-virtualization.md)
- [ ] **8.9** [Cockpit](containers-and-virtualization/cockpit-web-console.md)
- [ ] **8.9** [Image Builder](containers-and-virtualization/image-builder.md)
- [ ] **8.10** [Building RPMs](logs-scheduling-and-packages/rpm-package-building.md)
- [ ] **8.10** [Kernel compilation](boot-systemd-and-kernel/kernel-compilation.md)
- [ ] **8.11** [RHEL Lightspeed](advanced-rhel-and-career-notes/rhel-lightspeed-command-line-assistant.md)
- [ ] **8.12** [Production scenarios 1–24](troubleshooting-and-interviews/production-scenarios.md)

## Phase 9: Career Bridge (Interviews, Kubernetes, Next Certifications)

- [ ] **9.1** [Linux foundations of Kubernetes](advanced-rhel-and-career-notes/linux-foundations-of-kubernetes.md)
- [ ] **9.2** [Interview question bank](troubleshooting-and-interviews/interview-question-bank.md)
- [ ] **9.3** [GAPS §3](GAPS.md)

## Every note is scheduled

116 notes in the library; 116 appear in this roadmap.
