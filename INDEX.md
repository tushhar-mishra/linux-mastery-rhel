# Linux: From Zero to Production

One learning path, in reading order. Each topic only uses ideas from topics before it. When a later idea has to appear early, it is explained right there in a line or two.

**Main system:** RHEL 10 (and its free rebuilds, AlmaLinux and Rocky Linux). Ubuntu/Debian differences are noted wherever they matter.
**Every topic has the same shape:** What it is · Why it exists · Analogy · How it works inside · Commands (with sample output and a "Try it" lab) · Where you'll use it · When it breaks · Quick recap with interview questions.

---

## Part 1 · The very beginning

| # | Topic | What you'll learn |
|---|---|---|
| 001 | [What is Linux](notes/001-what-is-linux.md) | Hardware basics, kernel vs user space, system calls, distributions (RHEL, Ubuntu…), RHEL 10 facts |
| 002 | [Build your practice lab](notes/002-build-your-practice-lab.md) | VMs, hypervisors, a two-VM Vagrant lab with extra disks, snapshots |
| 003 | [Terminals, consoles and shells](notes/003-terminals-consoles-and-shells.md) | /dev, TTY, PTS, pseudo-terminals, Ctrl+C/Z/D, `who`, `w`, `tty` |
| 004 | [Your first commands](notes/004-your-first-commands.md) | The prompt, command syntax, how bash runs a line, exit codes, time-saving keys |
| 005 | [Getting help](notes/005-getting-help.md) | `man` sections, `man -k`, `--help`, `help`, `/usr/share/doc`, `type` vs `which` |
| 006 | [The filesystem tree](notes/006-the-filesystem-tree.md) | `/`, mounting, FHS directories, /proc /sys /dev /run, `df`, `du` |
| 007 | [Files and directories](notes/007-files-and-directories.md) | Paths, reading `ls -l`, timestamps, `cp` / `mv` / `rm` and what they do on disk |
| 008 | [Inodes and links](notes/008-inodes-and-links.md) | What a file really is, hard vs symbolic links, deleted-but-open files, `lsof +L1` |
| 009 | [Viewing files](notes/009-viewing-files.md) | `cat`, `less`, `head`, `tail -F`, `wc`, `file`, Windows line endings |
| 010 | [vi and vim](notes/010-vi-and-vim.md) | Modes, survival kit, search and replace, swap-file recovery |

## Part 2 · Shell power

| # | Topic | What you'll learn |
|---|---|---|
| 011 | [Quoting and control operators](notes/011-quoting-and-control-operators.md) | Word splitting, single vs double quotes, aliases, `&&` `\|\|` `;` `&` `( )` `{ }` |
| 012 | [Variables and environment](notes/012-variables-and-environment.md) | Local vs exported, PATH, prompts, parameter expansion, `${var:?}` safety |
| 013 | [Expansion and globbing](notes/013-expansion-and-globbing.md) | Expansion order, braces, wildcards, globs vs regex, locale |
| 014 | [Command substitution, subshells and shell options](notes/014-command-substitution-subshells-and-options.md) | `$(…)`, subshells, `set -x`, `set -euo pipefail`, `shopt` |
| 015 | [Command history](notes/015-command-history.md) | Ctrl+R, `!!`, `!$`, `^old^new`, history settings, secrets in history |
| 016 | [Redirection and pipes](notes/016-redirection-and-pipes.md) | stdin/stdout/stderr, `>` `2>&1`, pipes, `tee`, heredocs, `sudo tee` |
| 017 | [grep and regular expressions](notes/017-grep-and-regular-expressions.md) | BRE/ERE/PCRE, anchors, quantifiers, grep options, regex in other tools |
| 018 | [Text filters and sed](notes/018-text-filters-and-sed.md) | `cut`, `tr`, `sort`, `uniq -c`, `sed`, `diff -u`, frequency-count pipelines |
| 019 | [awk](notes/019-awk.md) | Fields, patterns, sums and counts, admin one-liners |
| 020 | [Finding files](notes/020-finding-files.md) | `find` tests and actions, safe deletes, `xargs -0`, `locate`, `lsof` |
| 021 | [Archiving and compression](notes/021-archiving-and-compression.md) | `tar`, gzip/bzip2/xz/zstd, backups with metadata, tar over SSH |

## Part 3 · Users, permissions and privilege

| # | Topic | What you'll learn |
|---|---|---|
| 022 | [Users and accounts](notes/022-users-and-accounts.md) | UIDs, `/etc/passwd`, `useradd`/`usermod`/`userdel`, service accounts |
| 023 | [Passwords and aging](notes/023-passwords-and-aging.md) | `/etc/shadow`, hashes and salts, `chage`, lock vs expire |
| 024 | [Groups](notes/024-groups.md) | Primary vs supplementary, why new groups need a re-login |
| 025 | [Shell startup files](notes/025-shell-startup-files.md) | Login vs non-login shells, `.bashrc`, `/etc/profile.d` |
| 026 | [File permissions and umask](notes/026-file-permissions-and-umask.md) | rwx on files vs directories, the kernel's check, `chmod`, `chown`, umask math, diagnosis checklist |
| 027 | [Special permissions, ACLs and attributes](notes/027-special-permissions-acls-and-attributes.md) | SUID, SGID, sticky bit, shared team directories, ACL mask, `chattr +i` |
| 028 | [sudo and su](notes/028-sudo-and-su.md) | How sudo decides, sudoers grammar, `visudo`, drop-ins, shell-escape risks, polkit |
| 029 | [PAM and authselect](notes/029-pam-and-authselect.md) | Module stacks, lockout, password quality, limits, `pam-auth-update` on Ubuntu |
| 030 | [Central identity: NSS and SSSD](notes/030-central-identity-nss-and-sssd.md) | LDAP, Active Directory, IdM, Kerberos, `getent`, joining a domain |

## Part 4 · Software, processes and services

| # | Topic | What you'll learn |
|---|---|---|
| 031 | [Packages: rpm, dnf and apt](notes/031-packages-rpm-dnf-and-apt.md) | Repositories, GPG signing, dnf/rpm queries, offline repos, apt equivalents |
| 032 | [Flatpak and snap](notes/032-flatpak-and-snap.md) | Sandboxed app formats, remotes, system vs user installs |
| 033 | [Processes and signals](notes/033-processes-and-signals.md) | PIDs, process states, `ps`, `kill`, signals, job control |
| 034 | [top and load average](notes/034-top-and-load-average.md) | CPU states, load average meaning, memory columns, top keys |
| 035 | [Process priority: nice and renice](notes/035-process-priority-nice.md) | The scheduler, nice values, when priority helps |
| 036 | [Resource monitoring](notes/036-resource-monitoring.md) | `free`, `vmstat`, `iostat`, `mpstat`, `pidstat`, `sar`, the USE method |
| 037 | [systemd: services and targets](notes/037-systemd-services-and-targets.md) | Units, `systemctl`, enable vs start, targets, masking, a first unit file |
| 038 | [Logging: journald, rsyslog and logrotate](notes/038-logging-journald-rsyslog-logrotate.md) | `journalctl` filters, persistent journal, log files, rotation |
| 039 | [Job scheduling: cron and timers](notes/039-job-scheduling-cron-and-timers.md) | `at`, cron syntax and traps, anacron, systemd timers |

## Part 5 · Bash scripting

| # | Topic | What you'll learn |
|---|---|---|
| 040 | [Script basics](notes/040-script-basics.md) | Shebang, running scripts, `echo`/`printf`, variables, debugging |
| 041 | [Script input and arguments](notes/041-script-input-and-arguments.md) | `$1…`, `"$@"`, `shift`, `read`, `getopts`, usage messages |
| 042 | [Conditionals](notes/042-conditionals.md) | `if`, `test`, `[ ]` vs `[[ ]]`, file tests, `case` |
| 043 | [Loops](notes/043-loops.md) | `for`, `while read`, `until`, `break`/`continue`, the pipe-subshell trap |
| 044 | [Arithmetic](notes/044-arithmetic.md) | `$(( ))`, `let`, `bc` for decimals |
| 045 | [Robust production scripts](notes/045-robust-scripts.md) | `set -euo pipefail` limits, traps, locking, retries, logging, ShellCheck |

## Part 6 · Storage

| # | Topic | What you'll learn |
|---|---|---|
| 046 | [Disks and partitions](notes/046-disks-and-partitions.md) | Block devices, device names, udev, MBR vs GPT, `fdisk`/`parted`, `lsblk` |
| 047 | [Filesystems](notes/047-filesystems.md) | XFS vs ext4 vs VFAT, journaling, `mkfs`, labels, UUIDs |
| 048 | [Mounting and fstab](notes/048-mounting-and-fstab.md) | `mount`, options, `/etc/fstab`, `findmnt --verify`, busy unmounts |
| 049 | [LVM](notes/049-lvm.md) | PVs, VGs, LVs, extents, growing online with `lvextend -r` |
| 050 | [Swap](notes/050-swap.md) | Swap partitions, LVs and files, priorities, swappiness |
| 051 | [Filesystem check and repair](notes/051-filesystem-check-and-repair.md) | `xfs_repair`, `e2fsck`, backup superblocks |
| 052 | [LVM snapshots and metadata recovery](notes/052-lvm-snapshots-and-recovery.md) | Copy-on-write snapshots, merge rollback, `vgcfgrestore` |

## Part 7 · Boot and kernel

| # | Topic | What you'll learn |
|---|---|---|
| 053 | [The boot process](notes/053-boot-process.md) | UEFI → shim → GRUB → kernel + initramfs → systemd, Secure Boot |
| 054 | [GRUB and kernel packages](notes/054-grub-and-kernel-packages.md) | `grubby`, kernel arguments, default kernel, keeping old kernels |
| 055 | [Kernel modules and sysctl](notes/055-kernel-modules-and-sysctl.md) | `modprobe`, blacklisting, `/etc/sysctl.d`, shared libraries |
| 056 | [tuned profiles](notes/056-tuned-profiles.md) | `tuned-adm`, recommended profiles, custom profiles |
| 057 | [Boot recovery](notes/057-boot-recovery.md) | Root password reset with `rd.break`, broken fstab, boot loops, rescue media |

## Part 8 · Networking and remote access

| # | Topic | What you'll learn |
|---|---|---|
| 058 | [How networks work](notes/058-how-networks-work.md) | NIC, MAC, switch, router, packets, layers, ports, TCP vs UDP, ARP, DHCP |
| 059 | [IP addressing and subnetting](notes/059-ip-addressing-and-subnetting.md) | IPv4, CIDR, subnet math, private ranges, IPv6 basics |
| 060 | [NetworkManager and nmcli](notes/060-networkmanager-and-nmcli.md) | Connections, static IPv4/IPv6, keyfiles, hostname, netplan on Ubuntu |
| 061 | [Routing](notes/061-routing.md) | Route tables, gateways, `ip route get`, persistent routes |
| 062 | [Network bonding](notes/062-network-bonding.md) | Bonding modes, failover, nmcli bonds |
| 063 | [Name resolution and DNS client](notes/063-name-resolution-and-dns-client.md) | `/etc/hosts`, nsswitch, resolv.conf, systemd-resolved, `dig` |
| 064 | [Cryptography basics](notes/064-cryptography-basics.md) | Symmetric, asymmetric, hashing, signatures, certificates, crypto policies |
| 065 | [SSH](notes/065-ssh.md) | Host vs user keys, key login, agent, `scp`/`sftp`, client config |
| 066 | [SSH server hardening](notes/066-ssh-server-hardening.md) | sshd_config drop-ins, root login, ports + SELinux, AllowGroups |
| 067 | [SSH tunnels](notes/067-ssh-tunnels.md) | Local, remote and dynamic forwarding, jump hosts |
| 068 | [rsync and backups](notes/068-rsync-and-backups.md) | Trailing slash rule, `--delete`, automated backups over SSH |
| 069 | [Time sync with chrony](notes/069-time-sync-chrony.md) | NTP, `chronyc sources`, `timedatectl` |
| 070 | [HTTP and curl](notes/070-http-and-curl.md) | Requests, status codes, headers, TLS handshake, `curl -v` debugging |

## Part 9 · Security

| # | Topic | What you'll learn |
|---|---|---|
| 071 | [firewalld](notes/071-firewalld.md) | Zones, services, ports, rich rules, NAT; ufw and nftables equivalents |
| 072 | [SELinux fundamentals](notes/072-selinux-fundamentals.md) | Modes, contexts, type enforcement, domain transitions; AppArmor on Ubuntu |
| 073 | [SELinux file contexts](notes/073-selinux-file-contexts.md) | `semanage fcontext`, `restorecon`, cp vs mv, relabeling |
| 074 | [SELinux booleans, ports and troubleshooting](notes/074-selinux-booleans-ports-troubleshooting.md) | `setsebool -P`, `semanage port`, reading AVC denials |
| 075 | [SELinux confined users](notes/075-selinux-confined-users.md) | Confined domains and users, staff_u, sysadm_u |
| 076 | [SELinux MLS and MCS](notes/076-selinux-mls-mcs.md) | Levels and categories, how containers are kept apart |
| 077 | [auditd](notes/077-auditd.md) | Audit rules, the login UID, `ausearch`, `aureport` |

## Part 10 · Network services

| # | Topic | What you'll learn |
|---|---|---|
| 078 | [Web servers: Apache and nginx](notes/078-web-servers-apache-and-nginx.md) | Virtual hosts, HTTPS, reverse proxy, load balancing, SELinux + firewall |
| 079 | [NFS and autofs](notes/079-nfs-and-autofs.md) | Exports, NFS mounts, autofs maps |
| 080 | [Samba](notes/080-samba.md) | SMB shares, Windows and Linux clients |
| 081 | [DNS server with BIND](notes/081-dns-server-bind.md) | Zones, records, serials, caching resolvers |
| 082 | [FTP with vsftpd](notes/082-ftp-vsftpd.md) | Anonymous and local users, why FTP is legacy |
| 083 | [iSCSI](notes/083-iscsi.md) | Block storage over the network: targets and initiators |
| 084 | [Multipath](notes/084-multipath.md) | Redundant storage paths, failover |

## Part 11 · Advanced storage

| # | Topic | What you'll learn |
|---|---|---|
| 085 | [LVM thin provisioning and striping](notes/085-lvm-thin-and-striping.md) | Thin pools, overcommit risks, striped LVs |
| 086 | [LVM volume group operations](notes/086-lvm-vg-operations.md) | Merge, split, rename, `pvmove`, moving VGs between hosts |
| 087 | [RAID with mdadm](notes/087-raid-mdadm.md) | RAID levels, building arrays, replacing a failed disk |
| 088 | [LUKS encryption](notes/088-luks-encryption.md) | Encrypted volumes, crypttab, key files |
| 089 | [XFS quotas](notes/089-xfs-quotas.md) | User, group and project quotas |
| 090 | [VDO](notes/090-vdo.md) | Deduplication and compression on LVM |
| 091 | [Stratis](notes/091-stratis.md) | Pooled storage with snapshots |

## Part 12 · Linux internals

| # | Topic | What you'll learn |
|---|---|---|
| 092 | [Processes and system calls](notes/092-processes-and-system-calls.md) | `strace`, fork/exec/wait, zombies, PID 1, capabilities, file descriptors, signal delivery |
| 093 | [Memory management](notes/093-memory-management.md) | Virtual memory, page cache, RSS/PSS, reclaim, PSI, the OOM killer |
| 094 | [The storage I/O path](notes/094-storage-io-path.md) | VFS, dirty pages, fsync, block layer, device mapper |
| 095 | [TCP/IP deep dive](notes/095-tcp-ip-deep-dive.md) | Sockets, TCP states, listen queues, `ss`, MTU, netfilter, conntrack |
| 096 | [Packet capture](notes/096-packet-capture.md) | `tcpdump`, `tshark`, Wireshark, reading captures |
| 097 | [Namespaces and cgroups](notes/097-namespaces-and-cgroups.md) | How containers are built from kernel features, by hand |
| 098 | [systemd unit files in depth](notes/098-systemd-unit-files.md) | Service types, dependencies vs ordering, restarts, resource limits, sandboxing |

## Part 13 · Virtualization and containers

| # | Topic | What you'll learn |
|---|---|---|
| 099 | [VMs vs containers](notes/099-vms-vs-containers.md) | Two kinds of isolation and when to use each |
| 100 | [KVM virtualization](notes/100-kvm-virtualization.md) | libvirt, `virsh`, `virt-install` |
| 101 | [Containers: Podman and Docker](notes/101-containers-podman-and-docker.md) | Images, containers, volumes, networks, builds, Quadlet |

## Part 14 · Production engineering

| # | Topic | What you'll learn |
|---|---|---|
| 102 | [Troubleshooting method](notes/102-troubleshooting-method.md) | A repeatable loop, finding the failing layer, decision trees |
| 103 | [Performance and observability](notes/103-performance-and-observability.md) | The first 60 seconds, PSI, `perf`, eBPF, core dumps, kdump |
| 104 | [cloud-init](notes/104-cloud-init.md) | How cloud VMs configure themselves on first boot |
| 105 | [Ansible](notes/105-ansible.md) | Inventory, playbooks, idempotency, turning admin tasks into code |
| 106 | [Building RPM packages](notes/106-building-rpm-packages.md) | SPEC files, `rpmbuild`, signing |
| 107 | [Compiling a kernel](notes/107-compiling-a-kernel.md) | Building, installing and removing a custom kernel |
| 108 | [Image Builder](notes/108-image-builder.md) | Blueprints and custom OS images |
| 109 | [Cockpit and Lightspeed](notes/109-cockpit-and-lightspeed.md) | The web console and the command-line assistant |
| 110 | [Production scenarios](notes/110-production-scenarios.md) | Break-fix scenarios with full solutions |
| 111 | [Linux foundations of Kubernetes](notes/111-linux-foundations-of-kubernetes.md) | Kubernetes concepts mapped onto the Linux you now know |
| 112 | [Interview question bank](notes/112-interview-question-bank.md) | Deep questions with model answers, L1 to L3 |
| 113 | [What to learn next](notes/113-what-to-learn-next.md) | Kubernetes, cloud, IaC, observability, programming |
