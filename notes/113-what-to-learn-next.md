# 113 · What to Learn Next

> **You need first:** [112 · Interview question bank](112-interview-question-bank.md)
> **Next:** — this is the last topic. Go back to [INDEX](../INDEX.md) to review.

---

## What it is

A map of what comes **after** this Linux path, toward DevOps, SRE and platform engineering, plus the gaps inside this path worth filling later, and the details you should confirm on a real RHEL host.

## Why it exists

Linux is the foundation, but production work also needs:
- orchestration;
- cloud;
- infrastructure as code;
- CI/CD;
- observability;
- programming;
- SRE practice.

Knowing the next steps (and what this path deliberately left out) stops you from either stalling or jumping ahead without the basics.

## Analogy

You've finished building the **foundation and ground floor** of a house. This page is the **architect's plan for the upper floors**: what to build next, in what order, and which rooms on the ground floor still need finishing touches.

## How it works inside

### The suggested order

```
Linux (this path) ──► Git + a scripting language (Python)
                  ──► Containers in depth ──► Kubernetes / OpenShift
                  ──► One cloud provider ──► Terraform (infrastructure as code)
                  ──► Ansible in depth ──► CI/CD pipelines
                  ──► Observability stack ──► SRE practice (SLOs, incidents, capacity)
```
These overlap; learn them through **projects** rather than strictly one after another.

### Areas to study next

| Area | Why | A good next step |
|---|---|---|
| **Git** and branching workflows | Everything (code, configs, playbooks, manifests) lives in Git | Keep this notes folder and your lab playbooks in Git; learn branches, rebase and pull requests |
| **Python** (and later Go) | SRE automation and tooling beyond bash | Rewrite two of your scripts in Python with tests |
| **Kubernetes / OpenShift** | The platform you'll operate | CKA/CKAD, or Red Hat EX280. Start from topic 111 and practise on kind/minikube/k3s or OpenShift Local |
| **Containers in depth** | Image engineering and supply-chain security | OCI spec, multi-stage builds, signing (cosign), scanning, SBOMs |
| **A cloud platform** (AWS, Azure or GCP) | Most production Linux runs there | One associate-level certification; networking (VPC), IAM, compute, storage |
| **Terraform / OpenTofu** | Provisioning infrastructure as code | Build a VPC + VMs with cloud-init (topic 104), then configure them with Ansible |
| **Ansible in depth** | Roles, collections, Vault, Jinja2, Automation Platform | RHCE (EX294) |
| **CI/CD** (GitHub Actions, GitLab CI, Tekton, Jenkins) | Delivery pipelines | A pipeline that lints and tests your playbook, builds an image, and deploys it |
| **Observability** (Prometheus, Grafana, Alertmanager, Loki/ELK, OpenTelemetry) | Fleet-level metrics, logs, traces, alerting | Instrument a lab service end to end with dashboards and alerts |
| **Networking at scale** | Load balancers, BGP, VPNs, service meshes, DNS operations | A vendor-neutral networking course; build a keepalived + HAProxy lab |
| **SRE practice** | SLIs/SLOs, error budgets, incident command, postmortems, capacity planning | The Google SRE books (free online) |
| **Security engineering** | PKI/certmonger, IdM, HashiCorp Vault, OpenSCAP compliance, threat detection | The RHEL Security Hardening guide; build an IdM lab |
| **High availability and backup** | Pacemaker/Corosync, keepalived, backup systems | The RHEL High Availability add-on documentation; restore drills |
| **RHEL lifecycle tooling** | Image mode (bootc), Leapp in-place upgrades, Satellite, Insights | Red Hat documentation for each |

### Gaps inside this path (good future additions to your notes)

| Gap | Current coverage |
|---|---|
| IPv6 in depth (Neighbour Discovery, SLAAC, privacy addresses, DHCPv6) | Basics in topics 059–060 |
| Writing complete nftables rule sets | Reading level and labs in topics 071, 095 |
| Kerberos fundamentals | Mentioned in topic 030 |
| eBPF beyond ready-made tools; flame graphs | Tool level in topic 103 |
| RHEL image mode (bootc), hands-on | Mentioned in topic 108 |
| Writing custom SELinux policy modules (`.te` files) | `audit2allow` as a last resort only (topic 074) |
| systemd-resolved, remote journal upload, systemd-oomd tuning | Mentions only |
| LVM RAID details and repair | Preview in topic 085 |

### Details to confirm on your own RHEL 10 host

Defaults change between releases, tuned profiles and security policies. Check these yourself, rather than trusting any notes:

| Item | Topics | How to confirm |
|---|---|---|
| Kernel sysctl defaults (`vm.*`, `net.*`, `kernel.hung_task_timeout_secs`) | 055, 093–095 | `sysctl -a \| grep KEY` |
| Transparent Huge Pages default | 093 | `cat /sys/kernel/mm/transparent_hugepage/enabled` |
| `kernel.core_pattern` → systemd-coredump | 103 | `sysctl kernel.core_pattern` |
| Package names and paths: `bcc-tools`, `bpftrace`, `perf`, `pcp`, `fio`, `conntrack-tools` | 095, 103 | `dnf info PKG` on a subscribed host |
| audit sample rules location | 077 | `rpm -ql audit \| grep -i rules` |
| `ansible-core` version; collections as RPMs vs Galaxy | 105 | `dnf info ansible-core rhel-system-roles` |
| Default umask in graphical sessions | 026 | `umask` in a GNOME terminal |
| Whether a chosen port already has an SELinux type | 074 | `semanage port -l \| grep -w PORT` |
| RHEL 10 deprecations (virt-manager, Cockpit host switcher, i440fx) | 100, 109 | RHEL 10 release notes |

## Commands

Your own progress tracker. Keep it next to the notes:

```bash
cd ~/linux-mastery-rhel
git init 2>/dev/null ; git add -A ; git commit -m "Finished the Linux path"     # track your own edits from now on
ls notes/[0-9]*.md | wc -l                                                     # 113 topics
grep -l 'Try it' notes/[0-9]*.md | wc -l                                       # every topic has a lab
```

A simple study log:
```bash
echo "$(date +%F) finished 113, next: Kubernetes basics (kind cluster)" >> ~/study-log.txt
```

### Try it: three capstone projects

1. **Self-hosted web app, the production way.**
   - A RHEL VM built from an Image Builder blueprint (108), personalised by cloud-init (104).
   - Configured by Ansible (105): nginx reverse proxy (078) + an app in a Podman Quadlet container (101), with TLS (064), firewalld (071) and SELinux enforcing (072–074).
   - Logs to the journal, with metrics in PCP or Prometheus (103).
   - Break it with five scenarios from topic 110, and fix each one.
2. **Storage and recovery.** RAID 1 (087) → LUKS (088) → LVM (049) → XFS with project quotas (089), plus backups with rsync (068). Replace a disk with `pvmove` (086) and restore from backup.
3. **Kubernetes on Linux.** A three-node kind/k3s cluster. Reproduce OOMKilled, CPU throttling, a DNS `ndots` slowdown and a Service DNAT path, and explain each one at the node level (111).

## Where you'll use it

- **Planning your learning** for the next 6–12 months.
- **Interviews:** "What are you learning now?" A concrete plan and a capstone project are strong answers.
- **Career paths:** Linux admin → DevOps engineer → SRE / platform engineer. Each step reuses everything in this path.

## When it breaks

| Trap | Better |
|---|---|
| Jumping to Kubernetes without Linux basics | You'll debug pods by guessing. Keep topics 092–098 fresh |
| Collecting certificates without building anything | Build the capstones; employers ask what you did |
| Learning tools without fundamentals | Tools change; processes, networking, storage and security don't |
| Never revisiting old topics | Re-run the "Try it" labs every few months; redo topic 110 |

## Quick recap

- Next: Git + Python → containers in depth → Kubernetes/OpenShift → a cloud + Terraform → Ansible in depth + CI/CD → observability → SRE practice.
- Fill the known gaps (IPv6, nftables rule sets, Kerberos, eBPF, bootc) over time.
- Confirm defaults on your own RHEL hosts; learn by building the capstone projects.

**Interview questions**

1. *What's your plan to grow from Linux admin to SRE?* Strengthen automation (Python, Ansible, Git, CI/CD), learn a cloud and Terraform, run Kubernetes at the node level, and practise observability and incident response, with real projects to show for each.
2. *Why is Linux knowledge still important when everything runs on Kubernetes?* Kubernetes configures Linux features (namespaces, cgroups, netfilter, mounts) on every node; most hard incidents are Linux problems underneath.
3. *How do you keep your skills current?* Release notes and upstream docs, lab environments to reproduce changes, re-running break-fix drills, and building small projects with each new tool.
