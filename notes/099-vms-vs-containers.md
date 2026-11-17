# 099 · Virtual Machines vs Containers

> **You need first:** [098 · systemd unit files in depth](098-systemd-unit-files.md) (and topic 097 namespaces and cgroups)
> **Next:** [100 · KVM virtualization](100-kvm-virtualization.md)

---

## What it is

There are two ways to run many isolated workloads on one physical server:

| | **Hardware virtualization (VMs)** | **OS-level virtualization (containers)** |
|---|---|---|
| What's virtualised | **Hardware**: CPU, RAM, disks, NICs | The **operating system's view**: processes, network, filesystems |
| Kernel | **Each VM runs its own kernel** | **All containers share the host kernel** |
| Built from | A **hypervisor** + CPU virtualisation extensions (Intel VT-x, AMD-V) | Namespaces + cgroups + capabilities/seccomp/SELinux + overlayfs (topic 097) |

Words:
- **Hypervisor**: the software that creates and runs VMs.
  - **Type 1** (bare-metal) runs directly on the hardware: VMware ESXi, Microsoft Hyper-V, Xen, and **KVM**, where the Linux kernel itself becomes the hypervisor.
  - **Type 2** (hosted) runs as an application on a normal OS: VirtualBox, VMware Workstation.
- **Guest**: the OS inside a VM. **Host**: the machine running the hypervisor or containers.
- **Image**: a template. A VM disk image (qcow2, VMDK), or a container image (OCI format: layers + metadata).
- **OCI** (Open Container Initiative): the standards for container images and runtimes, so Podman, Docker, CRI-O and containerd are interchangeable.
- **Container engine**: Podman, Docker, CRI-O, containerd. **Orchestrator**: Kubernetes, OpenShift (it schedules containers across many machines; it isn't an engine).

## Why it exists

Dedicated physical servers per application waste money: typical utilisation is 10–20%, buying hardware takes weeks, and every box needs power, space, cooling and patching. **VMs** pack many OSes onto one server and made the cloud possible. **Containers** go further: they package just an application and its libraries, start in milliseconds, and run tens or hundreds per host, which is ideal for microservices, CI/CD and Kubernetes.

## Analogy

- **VMs are separate houses** built on one big plot of land. Each has its own foundation, plumbing and electricity (its own kernel). They're very private, but every house costs a lot to build and maintain.
- **Containers are apartments in one building.** They share the foundation and main plumbing (the kernel), with private, locked flats (namespaces) and metered utilities (cgroups). They're far cheaper and faster to move into, but if the building's foundation cracks (a kernel vulnerability), every flat is affected.

## How it works inside

**A VM:**
1. The CPU's virtualisation extensions let a guest kernel run directly on the processor in a special "guest mode". Sensitive operations **trap** to the hypervisor.
2. The hypervisor gives each VM virtual devices. For speed, these are **paravirtual** devices (virtio) that the guest knows are virtual.
3. The guest boots a full OS: firmware, bootloader, kernel, init (topic 053). It has its own memory management, its own drivers, its own everything.
4. Overhead: RAM for each guest kernel and OS, slower boots (seconds to minutes), patching every guest OS.

**A container:**
1. The engine pulls an image, stacks its layers with overlayfs, creates namespaces and a cgroup, drops privileges, and **execs your process**. There's no boot, no second kernel (topic 097).
2. The process makes syscalls straight into the **host kernel**. So a Linux container needs a Linux kernel; you can't run a Windows container on Linux without a VM.
3. Overhead: almost none beyond the process itself; startup in milliseconds.

| Feature | VMs | Containers |
|---|---|---|
| Kernel | One per VM | The shared host kernel |
| Guest OS | Anything (Windows, Linux, BSD) | Same kernel family as the host |
| Size / startup | GBs / seconds–minutes | MBs / milliseconds–seconds |
| Isolation | Strong: a hardware boundary | Good, but the kernel is shared: a kernel exploit affects all |
| Density | Lower | Much higher |
| Typical use | Mixed OSes, legacy apps, strong multi-tenant isolation, kernel customisation | Microservices, CI/CD, scalable stateless apps |
| Management | libvirt, vSphere, cloud consoles | Podman, Docker, Kubernetes |

**In practice they're combined:** most production containers run **inside VMs** (cloud instances, Kubernetes worker nodes). VMs give the hard isolation boundary between customers or teams; containers give density and fast deployment. "Sandboxed container" runtimes (Kata Containers, gVisor, Firecracker microVMs) blur the line: each container gets a tiny VM or a user-space kernel for extra isolation.

## Commands

```bash
systemd-detect-virt                  # what am I running in?
```
```
kvm
```
- Prints `none` on bare metal, `kvm`/`vmware`/`microsoft`/`oracle` in a VM, and `podman`/`docker`/`container-other` inside a container. `-c` checks only for containers, `-v` only for VMs.

```bash
grep -Ec '(vmx|svm)' /proc/cpuinfo   # > 0: the CPU offers VT-x (vmx) or AMD-V (svm) to this OS
uname -r ; podman run --rm registry.access.redhat.com/ubi10/ubi uname -r
```
```
8
6.12.0-264.16.1.el10_3.x86_64
6.12.0-264.16.1.el10_3.x86_64
```
- The container reports the **host's kernel version**, because there is no other kernel. A VM would report its own.

```bash
podman run -d --name sl registry.access.redhat.com/ubi10/ubi sleep 300
ps -ef | grep 'sleep 300'            # the container's process is visible on the host
```
```
alice      51234   51220  0 13:05 ?        00:00:00 sleep 300
```
- A container is just a host process (in other namespaces). A VM appears on its host as a single `qemu-kvm` process (topic 100).

### Try it
1. Run `systemd-detect-virt` on your laptop, in your lab VM, and inside a Podman container.
2. Compare `uname -r` on the host, inside a container, and inside a nested VM if you have one.
3. Start a container and find its process with `ps`, then compare `/proc/PID/ns/net` with your shell's (topic 097).

## Where you'll use it

- **Cloud:** EC2/Azure/GCE instances are VMs (AWS Nitro and Google Cloud are KVM-based). Your containers or Kubernetes nodes run inside them.
- **Kubernetes:** pods are containers on nodes, which are usually VMs. KubeVirt runs VMs **as** pods for workloads that need them.
- **Choosing:** a VM for a different OS or kernel, kernel modules, or hard tenant isolation; a container to package and scale applications.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| "exec format error" running a container | The image's CPU architecture doesn't match the host (arm64 vs x86-64) | Pull the right `--arch` / multi-arch image |
| A container app needs a newer kernel feature | Containers use the host kernel | Upgrade the host, or use a VM |
| Can't create VMs inside your lab VM | Nested virtualisation is off on the outer hypervisor | Enable nested virtualisation / VT-x passthrough |
| One noisy VM slows others | Over-committed host CPU or RAM | Check **steal** time (`%st` in `top`) inside the guests; rebalance |
| A kernel CVE affects all containers on a host | The shared kernel | Patch and reboot hosts; use VM isolation between untrusted tenants |

## Quick recap

- VM = hypervisor + its own guest kernel: strong isolation, heavier. Container = an isolated host process sharing the kernel: light and fast.
- Type 1 hypervisors (ESXi, Hyper-V, Xen, KVM) vs Type 2 (VirtualBox, Workstation).
- Engines (Podman, Docker, CRI-O, containerd) run containers; orchestrators (Kubernetes, OpenShift) schedule them.
- Production usually means **containers inside VMs**. `systemd-detect-virt` tells you where you are.

**Interview questions**

1. *What is the main difference between a VM and a container?* A VM virtualises hardware and runs its own kernel; a container is an isolated process (namespaces, cgroups) that shares the host's kernel.
2. *Can you run a Windows container on a Linux host?* No. Containers make syscalls to the host kernel, so a Windows container needs a Windows kernel, which means a VM.
3. *Is Kubernetes a container engine?* No. It's an orchestrator that schedules containers across nodes; a runtime such as CRI-O or containerd actually runs them.
