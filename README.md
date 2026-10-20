# Linux & RHCSA Knowledge Base (RHEL 10)

Topic-organized notes for **RHCSA (EX200, RHEL 10)**, Linux administration interviews, and production troubleshooting. Organized by **technical topic**, not by lecture.

- **Baseline:** RHEL 10.x · EX200 objectives as published by Red Hat (verified Oct 2026)
- **Source course:** 104-session RHCSA course (RHEL 10), consolidated, corrected and supplemented

## Label Legend

| Label | Meaning |
|---|---|
| **[RHCSA Core]** | Maps to a current official EX200 objective |
| **[Production Practice]** | Real-world administration and troubleshooting |
| **[Interview Knowledge]** | Conceptual depth and scenario reasoning |
| **[Advanced/Optional]** | Useful, but outside current EX200 scope |

## Topic Index

### Exam
- [EX200 objectives map (RHEL 10)](rhcsa-exam-labs/exam-objectives-map.md)

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

### Files & text processing
- [Viewing & creating file contents](files-and-text-processing/viewing-and-creating-file-contents.md)
- [Archiving & compression](files-and-text-processing/archiving-and-compression.md)

### Networking & SSH
- [SSH remote access, login & switching users](networking-and-ssh/ssh-remote-access.md) *(basics; extended in S64–68)*

## Repository Layout

```
linux-rhcsa-notes/
├── README.md
├── linux-fundamentals/
├── shell-and-command-line/
├── files-and-text-processing/
├── users-groups-and-permissions/
├── processes-and-resource-management/
├── storage-and-filesystems/
├── boot-systemd-and-kernel/
├── logs-scheduling-and-packages/
├── networking-and-ssh/
├── firewall-and-selinux/
├── bash-scripting-and-automation/
├── containers-and-virtualization/
├── system-services-and-shared-storage/
├── rhcsa-exam-labs/
└── advanced-rhel-and-career-notes/
```

## Session → Topic Map

| Sessions | Topic | Notes | Status |
|---|---|---|---|
| 1 | Exam objectives, careers, RHEL 9 vs 10 | `linux-fundamentals/rhcsa-exam-and-certification.md`, `rhel-9-vs-rhel-10.md` | Done |
| 2 | UNIX/Linux history, virtualization, installation | `unix-linux-history-and-architecture.md`, `virtualization-and-lab-setup.md` | Done (installation supplemented) |
| 3 | Remote access, filesystem hierarchy | `networking-and-ssh/ssh-remote-access.md`, `linux-fundamentals/filesystem-hierarchy.md` | Done |
| 4–6 | Shells, man pages, directories, files | `shell-and-command-line/shell-basics-and-command-syntax.md`, `getting-help-and-documentation.md`, `files-and-directories.md` | Done (S6 theory supplemented) |
| 7–8 | File contents, compression, archives | `files-and-text-processing/viewing-and-creating-file-contents.md`, `archiving-and-compression.md` | Done (S7 theory supplemented) || 9–15 | Expansion, variables, history, globbing | `shell-and-command-line/` | Pending |
| 16–20 | Redirection, filters, find, awk, regex, vi | `files-and-text-processing/` | Pending |
| 21–28 | Users, groups, permissions, sudo, links | `users-groups-and-permissions/` | Pending |
| 29–30 | Processes, priorities | `processes-and-resource-management/` | Pending |
| 31–48 | Storage, LVM, swap, RAID, VDO, Stratis, LUKS | `storage-and-filesystems/` | Pending |
| 49–53 | Boot, systemd, kernel, modules | `boot-systemd-and-kernel/` | Pending |
| 54–59 | Scheduling, logs, monitoring, packages | `logs-scheduling-and-packages/` | Pending |
| 60–68 | Networking, SSH, recovery, backups | `networking-and-ssh/` | Pending |
| 69–77 | firewalld, SELinux | `firewall-and-selinux/` | Pending |
| 78–84 | Cockpit, Image Builder, KVM, Podman, tuned | `containers-and-virtualization/` | Pending |
| 85–93 | Bash scripting, PAM | `bash-scripting-and-automation/` | Pending |
| 94–101 | NTP, Apache, FTP, NFS, Samba, iSCSI, DNS | `system-services-and-shared-storage/` | Pending |
| 102–104 | Exam lab, Lightspeed, exam practice | `rhcsa-exam-labs/` | Pending |
