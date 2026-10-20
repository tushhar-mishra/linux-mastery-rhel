# RHCSA Exam (EX200) & Red Hat Certification Path

> **Sessions:** S1 · **Baseline:** EX200 on RHEL 10 · **Verified:** Oct 2026
> **Related:** [Objectives map](../rhcsa-exam-labs/exam-objectives-map.md) · [RHEL 9 vs 10](rhel-9-vs-rhel-10.md) · [Lab setup](virtualization-and-lab-setup.md)

## 1. Overview

**RHCSA** (Red Hat Certified System Administrator) is earned by passing **EX200**, a performance-based exam. You perform real administration tasks on live RHEL 10 systems; there are no multiple-choice questions. It validates core RHEL administration and is the foundation for engineer-level Red Hat certifications in both the Enterprise Linux and Ansible tracks.

## 2. Exam Format **[RHCSA Core]**

| Item | Detail | Confidence |
|---|---|---|
| Platform | RHEL 10 | Official |
| Format | Hands-on tasks on live systems (VMs) | Official |
| Duration | 3 hours, single section | Partner listings; confirm when booking |
| Allowed resources | No internet, no notes; product docs (man, info, `/usr/share/doc`) available | Official |
| Persistence | All configuration must survive a reboot without intervention | Official |
| Scoring | Total score reported; 300 max and 210 to pass are widely reported but not on the public page | Unofficial |
| Delivery | Test center or remote exam | Official |
| Validity | 3 years | Official |
| Cost | Varies by region and taxes; check the Red Hat store (course figure: INR 20,000 + GST, may be outdated) | Volatile |

**Official training paths:** RH124 (System Administration I) + RH134 (System Administration II), or RH199 (RHCSA Rapid Track). None is mandatory.

## 3. Objective Categories

Ten categories (full list with session mapping in the [objectives map](../rhcsa-exam-labs/exam-objectives-map.md)):

| # | Category | Weight hint |
|---|---|---|
| 1 | Understand and use essential tools | Foundation for everything |
| 2 | Manage software (RPM + Flatpak) | New category in RHEL 10 version |
| 3 | Create simple shell scripts | |
| 4 | Operate running systems | Includes boot interruption, tuned, journals |
| 5 | Configure local storage | GPT, LVM, swap |
| 6 | Create and configure file systems | VFAT/ext4/XFS, NFS, autofs |
| 7 | Deploy, configure, and maintain systems | Includes systemd timers, bootloader |
| 8 | Manage basic networking | nmcli, IPv4/IPv6, firewalld |
| 9 | Manage users and groups | |
| 10 | Manage security | firewalld, umask, SSH keys, SELinux |

> ⚠️ **Course correction:** The course slides show the RHEL 9 objectives (MBR partitions, set-GID directories, containers category, "SELinux policy violations"). These are not in the current RHEL 10 list.

## 4. Exam Strategy **[RHCSA Core]**

1. **Read every task first** (about 5 minutes). Note dependencies: network, repositories, root access.
2. **Do access-critical tasks first.** If a task requires resetting the root password or fixing boot, do it before anything else.
3. **Configure repositories early.** Many later tasks need packages.
4. **Make every change persistent:**

   | Runtime only (lost on reboot) | Persistent equivalent |
   |---|---|
   | `ip addr add …` | `nmcli con mod …` then `nmcli con up …` |
   | `systemctl start svc` | `systemctl enable --now svc` |
   | `firewall-cmd --add-service=x` | `firewall-cmd --permanent --add-service=x` then `firewall-cmd --reload` |
   | `mount /dev/x /mnt` | `/etc/fstab` entry (UUID) then `mount -a` |
   | `chcon -t …` | `semanage fcontext -a …` then `restorecon -Rv …` |
   | `setsebool x on` | `setsebool -P x on` |
   | `swapon /dev/x` | `/etc/fstab` swap entry then `swapon -a` |
   | `setenforce 1` | `SELINUX=enforcing` in `/etc/selinux/config` |

5. **Verify like a user.** Log in as the created user, access the share, test the port, check the permissions.
6. **Reboot deliberately.** Once after boot/storage changes, and once near the end with at least 15 minutes of margin.
7. **Never disable SELinux or firewalld** to make a task "work." That breaks other tasks.

### Common Traps

| Trap | Prevention |
|---|---|
| Typo in `/etc/fstab` → emergency mode at boot | `findmnt --verify` and `mount -a` before rebooting |
| LV extended but filesystem not grown | `lvextend -r …` (resizes the filesystem too) |
| Wrong host (tasks span two VMs) | Check `hostname` and the prompt before each task |
| Exact values ignored (UID, mode, owner, path, case) | Re-read the task; graders check exact state |
| Service running but not enabled | `systemctl is-enabled svc` |
| `su -` fails on RHEL 10 | Root may be disabled; use `sudo -i` (see [SSH note](../networking-and-ssh/ssh-remote-access.md)) |

### Using Docs Offline

```bash
man -k partition          # search man page descriptions (apropos)
mandb                     # rebuild the index if man -k returns nothing
man 5 fstab               # section 5 = file formats
rpm -qd openssh-server    # list a package's documentation files
ls /usr/share/doc/        # package docs and examples
<command> --help          # quick option reference
```

## 5. Red Hat Certification Framework (2026) **[Interview Knowledge]**

Red Hat restructured certifications on **11 May 2026** into **5 tracks** (Enterprise Linux, Ansible, OpenShift, Cloud-native applications, AI) and **5 levels**:

| Level | Credential | Notes |
|---|---|---|
| 1 | Red Hat Certified Technologist | Optional entry level |
| 2 | RHCSA / RHCD (Developer) | **EX200** is the Level 2 exam for Enterprise Linux |
| 3 | RHCE (per track) | Engineer level |
| 4 | Red Hat Certified Specialist | Electives |
| 5 | RHCA (per track) | 1 Admin/Dev exam + 1 Engineer exam + 3 Specialist exams |

- **Enterprise Linux track:** EX200 → engineer level. Third-party guides report this is **EX342**, renamed "Red Hat Certified Advanced System Administrator in Enterprise Linux" (previously Linux Diagnostics and Troubleshooting). *Verify on Red Hat's certification page.*
- **Ansible track:** EX200 → **EX294** (now titled "Advanced System Administrator in Ansible").
- **Recertification:** certs stay valid 3 years. Renew by retaking your highest-level exam, earning another cert at the same level, or earning a higher-level cert.

> ⚠️ **Course corrections:** RH134 is *System Administration **II*** (the slide says I). RH135, RH200 and RH255 are course-plus-exam bundles. RH254/EX300 are the retired RHEL 7-era RHCE. The RHCA list on the slide predates the 2026 restructure.

## 6. Career Relevance **[Interview Knowledge]**

| Role | Linux skills that matter most |
|---|---|
| System administrator | Users, storage, services, patching, troubleshooting |
| DevOps / SRE | Shell scripting, systemd, networking, automation (Ansible), observability |
| Cloud engineer | SSH, networking, storage, image builds, cloud-init |
| Security / pentest | Permissions, SELinux, firewalls, logs, auditing |
| Network admin | Routing, firewalling, packet capture |
| DBA / data engineer | Storage performance, memory, kernel tuning, process control |

Certification gets interviews; **troubleshooting depth** passes them. Practice explaining *why* a fix works.

## 7. Interview Questions

| Question | Concise answer |
|---|---|
| Why is RHCSA performance-based? | It tests working end-state configuration, not recall. Grading checks the systems, usually after reboot. |
| How do you ensure a change survives reboot? | Use the persistent mechanism: nmcli/keyfiles, `enable`, `--permanent`, fstab, `semanage`, `setsebool -P`. Then reboot-test. |
| What do you do if a task seems to require disabling SELinux? | Diagnose instead: check contexts (`ls -Z`), Booleans, port labels and audit logs. Disabling it is never the right fix. |
| What resources exist without internet? | `man`, `man -k`, `info`, `/usr/share/doc`, `--help`, `rpm -qd`. |
| RHCSA vs RHCE? | RHCSA validates core admin skills. RHCE validates engineer-level skills in a track (e.g., Ansible automation). |

## 8. Quick Revision

- EX200 = RHEL 10, hands-on, offline, persistence required.
- Persistent forms: `enable --now`, `--permanent` + `--reload`, fstab + `mount -a`, `semanage` + `restorecon`, `setsebool -P`, `nmcli con mod`.
- Reboot-test before the end. Never disable SELinux or firewalld.
- RHCA (2026) = 1 admin/dev + 1 engineer + 3 specialist exams within one track.

## 9. Cross-References

- [Objectives map](../rhcsa-exam-labs/exam-objectives-map.md)
- [RHEL 9 vs RHEL 10](rhel-9-vs-rhel-10.md)
- [Lab setup](virtualization-and-lab-setup.md)

**Sources:** redhat.com EX200 exam page; Red Hat blog "Validate targeted expertise: Major updates to Red Hat Certification" (11 May 2026).
