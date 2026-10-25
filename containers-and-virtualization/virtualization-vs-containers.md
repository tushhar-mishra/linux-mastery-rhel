# Hardware Virtualization vs Containers (OS Virtualization)

> **Sessions:** S81 · **[Interview Knowledge]**
> **Related:** [KVM](kvm-virtualization.md) · [Podman](podman-containers.md) · [SELinux MCS (sVirt/container isolation)](../firewall-and-selinux/selinux-mls-and-mcs.md)

## 1. Why Virtualize?

Dedicated physical servers suffer from low utilization, long procurement and deployment times, high power/space/cooling costs, hardware lock-in, and complex recovery. Virtualization and containers address these problems in different ways.

## 2. Hardware Virtualization (VMs)

A **hypervisor** presents virtual hardware; each **VM** runs a complete guest OS with its own kernel.

| Hypervisor type | Runs on | Examples |
|---|---|---|
| **Type 1** (bare-metal) | Directly on hardware | VMware ESXi, Microsoft Hyper-V, Xen; KVM (the Linux kernel itself acts as the hypervisor) |
| **Type 2** (hosted) | As an application on a host OS | Oracle VirtualBox, VMware Workstation/Fusion |

**Drawbacks:** per-VM OS overhead (RAM, disk, patching), slower startup, hypervisor maintenance and licensing, resource contention, a host failure taking down all its VMs (unless clustered), and VM-escape vulnerabilities as a (rare) risk.

## 3. Containers (OS-level Virtualization)

Containers are isolated **processes** sharing the **host kernel**. Isolation comes from kernel features: **namespaces** (PID, network, mount, user, UTS, IPC), **cgroups** (resource limits), **SELinux** (`container_t` + MCS categories), **seccomp** and **capabilities**. Images follow **OCI** standards.

| Role | Examples |
|---|---|
| Container engines | Podman (RHEL), Docker, containerd, CRI-O |
| Orchestrators (not engines) | Kubernetes, Red Hat OpenShift |
| Image tools | Buildah, Skopeo |

## 4. Comparison

| Feature | VMs | Containers |
|---|---|---|
| Virtualizes | Hardware | OS user space |
| Kernel | One per VM | Shared host kernel |
| Guest OS | Any (Windows, Linux, BSD) | Same kernel family as the host (Linux containers on Linux) |
| Size / startup | GBs / seconds–minutes | MBs / milliseconds–seconds |
| Isolation | Strong (hardware boundary) | Good, but kernel shared: a kernel exploit affects all |
| Density | Lower | Higher |
| Typical use | Mixed OSes, legacy apps, strong multi-tenant isolation | Microservices, CI/CD, scalable stateless apps |
| Management | Hypervisor tools (libvirt, vSphere) | Engines + orchestration (Podman, Kubernetes) |

## 5. In Practice

- Most production containers run **inside VMs** (cloud instances): VMs give the isolation boundary, containers give density and deployment speed.
- Choose VMs for different kernels/OSes, kernel-level customization or hard tenant isolation; choose containers for packaging and scaling applications.
- Podman pods mirror Kubernetes pods, and `podman kube generate` / `kube play` bridge local and cluster workflows.

## 6. Interview Questions

| Question | Answer |
|---|---|
| Main difference between a VM and a container? | A VM virtualizes hardware and runs its own kernel; a container is an isolated process sharing the host kernel. |
| Which kernel features make containers possible? | Namespaces, cgroups, plus SELinux/seccomp/capabilities for security. |
| Can you run a Windows container on Linux? | No; containers use the host kernel (a VM is needed). |
| Is Kubernetes a container engine? | No; it orchestrates containers run by an engine/runtime (CRI-O, containerd). |
| Type 1 vs Type 2 hypervisor? | Type 1 runs on hardware (ESXi, Hyper-V, Xen, KVM); Type 2 runs as an app on a host OS (VirtualBox). |

## 7. Course Corrections

| Course | Correction |
|---|---|
| "Kubernetes" listed among container engines | It's an orchestrator |
| Type 1 diagram with a host OS beneath the hypervisor | That layout describes Type 2 (or KVM, where Linux *is* the hypervisor) |
| Containers "medium isolation" without explanation | Shared kernel is the key limitation; SELinux/seccomp/user namespaces mitigate it |

## 8. Quick Revision

````
VM = hypervisor + guest kernel (strong isolation, heavier) · container = process + namespaces/cgroups/SELinux (light, shared kernel)
Type 1: ESXi Hyper-V Xen KVM · Type 2: VirtualBox Workstation · engines: Podman Docker CRI-O · orchestrators: Kubernetes OpenShift
