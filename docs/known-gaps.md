# Gaps, Uncertainties & Topics for Separate Study

> What this knowledge base does **not** cover, what was **not** verified, and what you should confirm on a real RHEL 10 host. Kept honest on purpose: a note that looks complete but isn't is worse than a known gap.
> Last full review: 26 Oct 2026 (see `git log`).

## 1. How Content Was Verified

| Method | Used for |
|---|---|
| Red Hat's EX200 page (fetched 26 Oct 2026) | The 62 objectives (verbatim in [COVERAGE](coverage.md)), "based on RHEL 10", persistence rule, no internet/notes |
| **RHEL 10.2 UBI containers** (`ubi10/ubi`, `ubi10/ubi-init` with systemd 257) on Docker Desktop | Commands and outputs in the new internals/production notes, sudo/grep/regex behavior, systemd unit behavior, cgroups, namespaces, overlayfs, TCP states, nftables, PSI, `passwd`/umask defaults, graders and mock-exam solutions |
| CentOS Stream 10 packages inside the lab container (parted, dosfstools, xfsprogs, e2fsprogs, httpd, firewalld, tuned, chrony, grubby) | Storage solution of mock exam 2 on loop devices; break-fix script and grader of mock exam 3 |
| ansible-core 2.21 from PyPI in the lab container | Ansible starter playbook and idempotency |

**Limits of that lab, and what they mean for you:**

- **Kernel:** containers share Docker Desktop's kernel (`6.12.x-linuxkit`), not RHEL's build. Kernel *mechanisms* (cgroups, namespaces, page cache, TCP) behave the same, but **sysctl defaults printed in a container are the host VM's** (e.g., `vm.overcommit_memory=1`, `vm.dirty_writeback_centisecs=1500` there). The notes state upstream/RHEL defaults separately; confirm with `sysctl` on your RHEL host.
- **Not executable in containers:** SELinux enforcement and labels, GRUB/boot/`rd.break`, NetworkManager/`nmcli`, real disks/udev, firewalld runtime filtering, auditd, kdump, `perf`/eBPF tools, PCP, NFS/autofs between hosts, SSSD/IdM. Notes covering these follow Red Hat documentation and the original course labs; practise them on VMs.
- **UBI vs a full install:** UBI images use the same RHEL 10.2 packages (shadow-utils, pam, authselect, setup), so defaults like `passwd -S` codes and umask `0022` should match a minimal install, but a security profile, tuned profile or local policy can change them.
- **Original course-derived notes** (about 90 files): reviewed line by line in the audit; specific claims were re-tested and corrected (see `git log`). Their full command sequences were **not** all re-executed in this pass.

## 2. Details to Confirm on a Real RHEL 10 Host

| Item | Where it matters | How to confirm |
|---|---|---|
| Exam duration and scoring (not on the official page; 3 h / 210 of 300 are widely reported) | [Exam note](../notes/linux-fundamentals/rhcsa-exam-and-certification.md) | Red Hat booking page |
| Whether port 8888 (or your chosen port) already has an SELinux type | [Mock 2 A11](../notes/rhcsa-exam-labs/mock-exam-2.md) | `semanage port -l \| grep -w PORT` (use `-m` if defined) |
| Kernel sysctl defaults (`vm.*`, `net.*`, `kernel.hung_task_timeout_secs`) | Internals notes | `sysctl -a \| grep KEY` |
| Transparent Huge Pages default | [Memory §9](../notes/processes-and-resource-management/memory-management.md#9-huge-pages--numa-awareness-advanced) | `cat /sys/kernel/mm/transparent_hugepage/enabled` |
| `kernel.core_pattern` → systemd-coredump | [Performance §7](../notes/advanced-rhel-and-career-notes/performance-and-observability.md#71-application-crashes-core-dumps) | `sysctl kernel.core_pattern` |
| Package names/paths: `bcc-tools` (`/usr/share/bcc/tools`), `bpftrace`, `perf`, `pcp`, `iotop`, `fio`, `conntrack-tools` | [Performance](../notes/advanced-rhel-and-career-notes/performance-and-observability.md) | `dnf info PKG` on a subscribed host |
| audit 4.x sample rules location | [auditd](../notes/firewall-and-selinux/auditd.md) | `rpm -ql audit \| grep -i rules` |
| `ansible-core` version in RHEL 10 AppStream; `ansible.posix`/`community.general` as RPMs vs Galaxy | [Ansible starter](../notes/bash-scripting-and-automation/ansible-starter.md) | `dnf info ansible-core rhel-system-roles` |
| Default umask in **graphical** sessions | [File permissions §3.3](../notes/users-groups-and-permissions/file-permissions.md#33-umask-default-permissions-rhcsa-core) | `umask` in a GNOME terminal |
| SELinux denial when systemd executes files labeled `user_home_t` (stated as "typically") | [systemd unit files](../notes/boot-systemd-and-kernel/systemd-unit-files.md#13-rhcsa--production-patterns) | Reproduce scenario 12 and `ausearch -m avc` |
| Certification-track names after the May 2026 restructure (e.g., EX342 naming) | [Exam note §5](../notes/linux-fundamentals/rhcsa-exam-and-certification.md#5-red-hat-certification-framework-2026-interview-knowledge) | Red Hat certification pages |
| RHEL 10 deprecations quoted from the course (virt-manager, Cockpit host switcher, i440fx) | KVM, Cockpit notes | RHEL 10 release notes |

## 3. Topics Requiring Separate Study

Beyond the scope of a Linux knowledge base, but on the path you described (DevOps, SRE, platform engineering):

| Area | Why | Suggested next step |
|---|---|---|
| **Ansible in depth** (roles, collections, Vault, Jinja2, AAP) | Configuration management at scale; RHCE | RHCE **EX294** (RH294) |
| **Kubernetes / OpenShift administration** | The platform you'll operate | CKA/CKAD or Red Hat **EX280**; start from the [bridge note](../notes/advanced-rhel-and-career-notes/linux-foundations-of-kubernetes.md) |
| **Containers in depth** (OCI spec, image builds, registries, supply-chain security) | Image engineering and security | Podman/Buildah docs; container hardening guides |
| **Cloud platforms** (AWS/Azure/GCP networking, IAM, compute, storage) | Most production Linux runs there | One provider's associate-level certification |
| **Infrastructure as Code** (Terraform/OpenTofu) | Provisioning, not just configuration | Terraform tutorials with a cloud provider |
| **CI/CD** (GitHub Actions/GitLab CI/Tekton/Jenkins) and **Git** workflows | Delivery pipelines | Build a pipeline that tests and deploys one of your playbooks |
| **Observability stacks** (Prometheus, Grafana, Alertmanager, Loki/ELK, OpenTelemetry) | Fleet-level metrics, logs, traces, alerting | Instrument a lab service end to end |
| **Programming** (Python, Go) | SRE automation and tooling beyond bash | Rewrite two of your scripts in Python with tests |
| **Networking at scale** (BGP, load balancers, VPNs, service meshes, DNS operations) | Platform and SRE roles | Vendor-neutral networking course |
| **SRE practice** (SLIs/SLOs, error budgets, incident command, postmortems, capacity planning) | How SRE teams work | The Google SRE books (free online) |
| **Security engineering** (PKI and certmonger, IdM administration, Vault, OpenSCAP compliance, threat detection) | Hardening and compliance work | RHEL Security Hardening guide; IdM course |
| **High availability** (Pacemaker/Corosync, keepalived), **backup systems** | Stateful services | RHEL HA add-on docs |
| **RHEL lifecycle tooling** (image mode/bootc, Leapp upgrades, Satellite, Insights) | Enterprise fleet operations | Red Hat documentation for each |

## 4. Known Gaps Inside This Knowledge Base (candidates for future notes)

| Gap | Priority | Current coverage |
|---|---|---|
| IPv6 in depth (Neighbor Discovery, SLAAC/privacy addresses, DHCPv6 operations) | Medium | Basics in [IP addressing](../notes/networking-and-ssh/ip-addressing-fundamentals.md), config in [nmcli](../notes/networking-and-ssh/networkmanager-nmcli.md) |
| Writing your own nftables rule sets | Medium | Reading/lab level in [TCP/IP §11](../notes/networking-and-ssh/tcp-ip-for-operators.md#11-netfilter-nftables--conntrack) |
| Kerberos fundamentals | Medium | Mentioned in [central identity](../notes/users-groups-and-permissions/central-identity-nss-sssd.md) |
| eBPF beyond ready-made tools; flame-graph walkthrough | Medium | Tool level in [performance](../notes/advanced-rhel-and-career-notes/performance-and-observability.md) |
| RHEL image mode (bootc) hands-on | Medium | One paragraph in [boot process](../notes/boot-systemd-and-kernel/boot-process.md) |
| Custom SELinux policy modules (writing `.te` files) | Low | `audit2allow` as last resort only |
| systemd-resolved, journald remote upload, `systemd-oomd` configuration | Low | Mentions only |
| LVM RAID details and repair | Low | Preview in [thin provisioning & striping §3.5](../notes/storage-and-filesystems/lvm-thin-provisioning-and-striping.md#35-lvm-raid-preview) |

## 5. Structural Decisions (for future maintenance)

- **Two structures, one source:** topic folders = reference library; [CURRICULUM](curriculum.md) = learning order; [ROADMAP](roadmap.md) is **generated** from the curriculum (`python3 tools/build_roadmap.py`), which also fails if any note is unscheduled.
- **Integrity checks:** `python3 tools/check_notes.py` must report 0 problems (broken links, missing anchors, unclosed code fences, stale "planned" markers).
- **Verification lines:** new notes state how they were verified in their header; keep doing that for every new note.
