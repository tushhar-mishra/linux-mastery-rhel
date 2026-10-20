# Virtualization & RHEL 10 Lab Setup

> **Sessions:** S2 (virtualization; installation supplemented, see note) · **Verified:** Oct 2026
> **Related:** [RHEL 9 vs 10](rhel-9-vs-rhel-10.md) · [SSH](../networking-and-ssh/ssh-remote-access.md) · KVM in depth: `containers-and-virtualization/` (S80)

> 📝 **Coverage note:** The course notes for S2 covered physical servers and hypervisors but contained **no RHEL 10 installation material**. Sections 6–7 are supplemented and should be revisited if installation notes are added later.

## 1. Overview

Exam systems and practice labs run as **virtual machines**. A hypervisor abstracts CPU, memory, storage and network so several isolated operating systems share one physical host.

## 2. Physical Servers: Limitations **[Interview Knowledge]**

| Category | Problems |
|---|---|
| Utilization | Resource wastage (one app per server), one OS per box |
| Cost | Hardware, power, cooling, space, maintenance |
| Agility | Slow provisioning, limited scalability, inflexible |
| Resilience | Hardware-bound disaster recovery, complex backup/restore |
| Lifecycle | Hardware obsolescence, vendor lock-in |

## 3. Hypervisors **[Interview Knowledge]**

| | Type 1 (bare-metal) | Type 2 (hosted) |
|---|---|---|
| Runs on | Hardware directly | A host OS |
| Performance | Near-native | Extra layer of overhead |
| Use | Data centers, cloud | Desktops, labs |
| Examples | VMware ESXi, Microsoft Hyper-V, Xen, **KVM** | VirtualBox, VMware Workstation/Fusion, Parallels, UTM |

**KVM (Kernel-based Virtual Machine)**, RHEL's hypervisor:

- Kernel modules (`kvm` + `kvm_intel`/`kvm_amd`) turn the Linux kernel itself into the hypervisor. That's why KVM is classed as **Type 1**, even though a full OS runs alongside it.
- **QEMU** emulates devices. **libvirt** manages VMs (`virsh`, `virt-install`, Cockpit).
- Each VM is a normal Linux process, scheduled by the kernel and confined by SELinux (sVirt).

> ⚠️ **Course correction:** The hypervisor slide omits KVM, the hypervisor RHEL actually uses. Its diagram, with a host OS under the hypervisor, depicts Type 2.

**Hardware support:** Intel VT-x (`vmx` CPU flag) and AMD-V (`svm`).

```bash
grep -Ec '(vmx|svm)' /proc/cpuinfo    # >0 → hardware virtualization available
lscpu | grep -i virtualization
systemd-detect-virt                   # inside a guest: kvm, oracle, vmware, microsoft, none
ls -l /dev/kvm                        # present when KVM is usable
```

## 4. VMs vs Containers **[Interview Knowledge]**

| | VM | Container |
|---|---|---|
| Isolation | Full guest OS and kernel | Shared host kernel (namespaces + cgroups) |
| Boot | Seconds to minutes | Milliseconds to seconds |
| Size | GBs | MBs |
| Best for | Different OSes/kernels, strong isolation | App packaging, density |

Containers (Podman) are **no longer an EX200 objective** on RHEL 10 but matter for interviews.

## 5. Lab Design **[RHCSA Core preparation]**

| Item | Recommendation |
|---|---|
| Subscription | No-cost **Red Hat Developer** subscription (genuine RHEL 10; use RHEL for final practice) |
| ISO | **DVD ISO** (contains BaseOS and AppStream repos; doubles as a local repository) |
| VMs | 2 VMs: `servera` (RHEL 10, optional GUI) and `serverb` (minimal) |
| Sizing | 2 vCPU, 2–4 GB RAM (4 GB with GUI), 20+ GB OS disk |
| Extra disks | 2–3 additional 5–10 GB virtual disks per VM for partitioning, LVM and swap |
| Network | Guest↔guest **and** host↔guest: VirtualBox "NAT Network" or NAT + Host-only; KVM default NAT network |
| Snapshots | Take a clean snapshot after install; snapshot before boot or password-recovery labs |
| CPU | Must expose **AVX2** (x86-64-v3). On KVM use `host-passthrough` |

**Apple Silicon hosts:** use the **aarch64** RHEL 10 ISO (UTM, Parallels or VMware Fusion). The exam itself is x86_64, but the commands are the same.

**VirtualBox NAT + SSH from host:** add a port-forward rule, host `2222` → guest `22`, then run `ssh -p 2222 user@127.0.0.1`.

## 6. RHEL 10 Installation (Anaconda) **[Supplement]**

| Hub item | What to do | Notes |
|---|---|---|
| Language/Keyboard | Set as needed | |
| Installation Source | Local media (auto) | |
| Software Selection | *Server with GUI* (learning) or *Minimal Install* (closer to servers) | GUI needs more RAM |
| Installation Destination | **Automatic** for the OS disk; leave extra disks **unselected** | Default layout: `/boot` (XFS, ~1 GiB), LVM `/` (XFS), swap; UEFI adds `/boot/efi` (**VFAT**) |
| Network & Hostname | Turn the NIC **ON**; set hostname (e.g., `servera.lab.example.com`) | Otherwise the system may boot without network |
| Time & Date | Time zone; NTP on | |
| **Root Account** | **Disabled by default in RHEL 10.** Enable and set a password if you want root console login | Password-based SSH root login stays disabled by default |
| User Creation | Create a user and tick **"Make this user administrator"** (adds to `wheel` → sudo) | |
| Connect to Red Hat | Register now or later | |

**Post-install checks:**

```bash
cat /etc/redhat-release
sudo subscription-manager register        # if not registered during install
sudo subscription-manager status
sudo dnf repolist                         # BaseOS + AppStream enabled?
ip -br addr; hostnamectl
lsblk -f; df -hT
sudo dnf -y update && sudo reboot
```

## 7. Local DVD Repository (preview of S57) **[RHCSA Core]**

Relevant objective: *install/update packages from … the local file system.*

```bash
sudo mkdir -p /mnt/iso
sudo mount -o ro /dev/sr0 /mnt/iso                 # or: mount -o loop,ro /path/rhel-10.x-x86_64-dvd.iso /mnt/iso

sudo tee /etc/yum.repos.d/local-dvd.repo >/dev/null <<'EOF'
[local-baseos]
name=Local DVD BaseOS
baseurl=file:///mnt/iso/BaseOS
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release

[local-appstream]
name=Local DVD AppStream
baseurl=file:///mnt/iso/AppStream
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
EOF

sudo dnf clean all && sudo dnf repolist
```

Persistence requires an `/etc/fstab` entry for the ISO mount (covered in storage notes).

## 8. Troubleshooting

| Symptom | Check | Fix |
|---|---|---|
| RHEL 10 installer or guest won't boot early | `grep avx2 /proc/cpuinfo` inside a Linux live environment on the host | Expose AVX2 (host-passthrough) or use newer hardware |
| VM creation fails: "VT-x/AMD-V not available" | BIOS/UEFI settings; Hyper-V conflicts on Windows | Enable virtualization in firmware; resolve hypervisor conflicts |
| No network after install | `nmcli device status` | `nmcli con up <name>`; `nmcli con mod <name> connection.autoconnect yes` |
| `dnf` says "no repositories available" | `subscription-manager status` | Register, or configure the local DVD repo |
| Can't log in as root | Root disabled by default | Use the admin user + `sudo -i` |

## 9. Interview Questions

| Question | Answer |
|---|---|
| Type 1 vs Type 2? | Type 1 runs on hardware (ESXi, Hyper-V, KVM). Type 2 runs as an application on a host OS (VirtualBox). |
| Why is KVM considered Type 1? | Its modules turn the Linux kernel into the hypervisor; VMs are scheduled directly by that kernel. |
| VM vs container? | A VM virtualizes hardware and runs its own kernel. A container isolates processes on the shared host kernel. |
| How would you check whether a server can host VMs? | CPU flags `vmx`/`svm`, `/dev/kvm`, firmware settings, `virt-host-validate` [Advanced]. |

## 10. Quick Revision

KVM = kernel hypervisor + QEMU + libvirt. Check virtualization with `vmx|svm` and `systemd-detect-virt`. RHEL 10 needs AVX2. Root is disabled by default, so make your user an administrator. The DVD ISO provides BaseOS + AppStream local repos.
