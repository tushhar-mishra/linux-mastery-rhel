# 100 · KVM Virtualization: libvirt, virsh, virt-install and Cockpit

> **You need first:** [099 · VMs vs containers](099-vms-vs-containers.md)
> **Next:** [101 · Containers with Podman (and Docker)](101-containers-podman-and-docker.md)

---

## What it is

**KVM** (Kernel-based Virtual Machine) turns the Linux kernel itself into a **Type 1 hypervisor**. It's the virtualisation built into RHEL (and Ubuntu), and the base of OpenStack, Google Cloud and AWS Nitro.

| Component | Role |
|---|---|
| **KVM** | Kernel modules (`kvm`, `kvm_intel` / `kvm_amd`) that use the CPU's VT-x/AMD-V extensions |
| **QEMU** | One user-space process per VM (`qemu-kvm`) that emulates devices. **virtio** paravirtual disks and NICs give near-native speed |
| **libvirt** | The management layer: an API and daemons that define VMs as XML, plus networks and storage pools |
| `virsh` | The libvirt command-line tool |
| `virt-install` | Creates new VMs |
| **Cockpit** + `cockpit-machines` | The web UI for VMs (`virt-manager` is deprecated in RHEL 10) |
| **sVirt** | SELinux MCS labels that isolate each VM's process and disk files from the others (topic 076) |

Words:
- **Domain**: libvirt's name for a VM.
- **qcow2** (QEMU Copy-On-Write v2): the usual disk image format. It's thin (grows as used) and supports snapshots.
- **Storage pool**: a place libvirt keeps disk images (default `/var/lib/libvirt/images`).

## Why it exists

To run several isolated OSes on one physical server: lab environments, mixed OS versions, legacy applications, test clusters, and private clouds. Because each VM is just a Linux process, everything you know (scheduling, cgroups, SELinux, `top`) applies to VMs too.

## Analogy

KVM is a **landlord who turns one big building (the server) into furnished flats (VMs)**. QEMU builds the fake fixtures in each flat (virtual disks and NICs). libvirt is the **letting agency** keeping the paperwork (XML definitions), and `virsh`/Cockpit are the agency's front desk.

## How it works inside

1. When a VM starts, libvirt launches a `qemu-kvm` **process** and asks KVM (via `/dev/kvm`) to create virtual CPUs. Each vCPU is a **thread** of that process, scheduled by the normal Linux scheduler.
2. Guest code runs **directly on the real CPU** in guest mode. Privileged operations exit to KVM, which handles them or passes them to QEMU (for example, device I/O).
3. Guest RAM is ordinary memory of the qemu process (so `top` shows a big RSS), placed in libvirt's `machine.slice` cgroup (topic 097).
4. Disks are image files (qcow2) or block devices (LVs, iSCSI LUNs); NICs connect to a virtual **bridge**:
   - The **`default`** network is NAT through `virbr0`, on 192.168.122.0/24, with DHCP from libvirt's dnsmasq.
   - A **bridged** network (a host bridge made with nmcli) puts VMs directly on your LAN.
5. **sVirt:** every VM's qemu process gets a unique label like `svirt_t:s0:c12,c540`, and its disk files get the matching category. A compromised VM can't open another VM's disk, even as the same Unix user.
6. RHEL 10 uses **modular libvirt daemons** (`virtqemud`, `virtnetworkd`, `virtstoraged`…), socket-activated, instead of the old monolithic `libvirtd`. The default machine type is `q35`.

## Commands

### Prepare the host

```bash
grep -Ec '(vmx|svm)' /proc/cpuinfo       # > 0 needed (in a lab VM: enable NESTED virtualisation outside)
sudo dnf install -y qemu-kvm libvirt virt-install virt-viewer
for drv in qemu network nodedev nwfilter secret storage interface; do
  sudo systemctl enable --now virt${drv}d.socket virt${drv}d-ro.socket virt${drv}d-admin.socket
done
sudo virt-host-validate qemu
```
```
  QEMU: Checking for hardware virtualization                                 : PASS
  QEMU: Checking if device '/dev/kvm' exists                                 : PASS
  QEMU: Checking if device '/dev/kvm' is accessible                          : PASS
  QEMU: Checking for cgroup 'cpu' controller support                         : PASS
  QEMU: Checking for secure guest support                                    : WARN (Unknown if this platform has Secure Guest support)
```
- `PASS` for hardware virtualisation and `/dev/kvm` is what matters; `WARN` for optional features is fine.

Ubuntu: `sudo apt install qemu-kvm libvirt-daemon-system virtinst` and add yourself to the `libvirt` group.

### Web console

```bash
sudo dnf install -y cockpit cockpit-machines ; sudo systemctl enable --now cockpit.socket
```
Browse to `https://HOST:9090` → **Virtual machines** → *Create VM* (ISO, URL, cloud image), plus consoles, disks, NICs and snapshots (topic 109).

### Create a VM

```bash
osinfo-query os | grep -i rhel                       # valid --osinfo names
sudo virt-install \
  --name rhel10-vm --memory 4096 --vcpus 2 \
  --osinfo rhel10.0 \
  --cdrom /var/lib/libvirt/images/rhel-10.0-x86_64-dvd.iso \
  --disk size=40,format=qcow2 \
  --network network=default \
  --graphics vnc,listen=127.0.0.1 --noautoconsole
```
- `--osinfo` is **required** by recent virt-install; it tunes defaults for the guest OS.
- VNC listens on localhost only. Reach it through Cockpit or an SSH tunnel (topic 067), never openly on 0.0.0.0.

**Unattended install with Kickstart** (an answer file for the RHEL installer):
```bash
sudo virt-install --name rhel10-auto --memory 4096 --vcpus 2 --osinfo rhel10.0 \
  --location /var/lib/libvirt/images/rhel-10.0-x86_64-dvd.iso \
  --initrd-inject /root/ks.cfg --extra-args "inst.ks=file:/ks.cfg console=ttyS0" \
  --disk size=40 --network network=default --graphics none
```

### Manage VMs

```bash
sudo virsh list --all
sudo virsh domifaddr rhel10-vm
```
```
 Id   Name         State
-----------------------------
 3    rhel10-vm    running
 -    rhel10-auto  shut off

 Name       MAC address          Protocol     Address
-------------------------------------------------------------------
 vnet2      52:54:00:4b:1a:9c    ipv4         192.168.122.57/24
```

| Task | Command |
|---|---|
| Start / graceful shutdown / power off / reboot | `virsh start VM` · `shutdown VM` · `destroy VM` (= pull the plug, not delete) · `reboot VM` |
| Start with the host | `virsh autostart VM` |
| Info | `virsh dominfo VM`, `virsh domstats VM` |
| Serial console (guest needs `console=ttyS0`) | `virsh console VM` (exit with `Ctrl+]`) |
| Graphical console | `virt-viewer --connect qemu:///system VM` |
| Edit the definition | `virsh edit VM`; `virsh dumpxml VM > vm.xml` (back it up) |
| Add a disk | `qemu-img create -f qcow2 /var/lib/libvirt/images/extra.qcow2 20G` ; `virsh attach-disk VM /var/lib/libvirt/images/extra.qcow2 vdb --persistent` |
| Add a NIC | `virsh attach-interface VM network default --model virtio --config` |
| Snapshots | `virsh snapshot-create-as VM snap1` · `snapshot-list` · `snapshot-revert VM snap1` · `snapshot-delete VM snap1` |
| Networks / pools / volumes | `virsh net-list --all` · `pool-list` · `vol-list default` |
| Delete a VM **and its disks** ⚠️ | `virsh undefine VM --nvram --remove-all-storage` |
| Disk images | `qemu-img info / resize / convert` |

### See a VM as a process

```bash
ps -eo pid,rss,%cpu,cmd | grep [q]emu-kvm | cut -c1-120
ps -eZ | grep [q]emu
```
```
 7812 4123456 12.5 /usr/libexec/qemu-kvm -name guest=rhel10-vm,debug-threads=on -S -object ...
system_u:system_r:svirt_t:s0:c12,c540  7812 ?   00:01:22 qemu-kvm
```
- The whole VM is **one process** using about 4 GB RSS (its RAM). Its SELinux label carries a unique MCS pair `c12,c540` (sVirt).

### Try it
1. Validate your host, create a small VM from an ISO (or a cloud image via Cockpit), and find its IP with `domifaddr`.
2. Snapshot it, break something inside, and revert.
3. Attach a second disk and partition it inside the guest (topics 046–049).
4. Compare the qemu process's SELinux label and its disk file's label (`ls -Z /var/lib/libvirt/images`).

## Where you'll use it

- **Home and work labs:** multi-VM setups (client/server, clusters) on one machine.
- **Private clouds:** OpenStack Nova and oVirt/RHV are built on KVM + libvirt; **OpenShift Virtualization / KubeVirt** run KVM VMs inside Kubernetes pods.
- **Public cloud:** AWS Nitro, Google Cloud and many others are KVM-based, so cloud "instance" troubleshooting (virtio drivers, serial console) is KVM knowledge.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `virt-host-validate`: hardware virtualisation FAIL | VT-x/AMD-V disabled, or nested virtualisation off | Enable it in firmware / on the outer hypervisor |
| `virt-install`: `ERROR    Host does not support any virtualization options` | No `/dev/kvm` (no VT-x/AMD-V, or a VM without nested virtualisation). RHEL's `qemu-kvm` has **no software emulation (TCG)**, so even `--virt-type qemu` fails | Run on bare metal or enable nested virtualisation on the outer hypervisor |
| `--osinfo OS name is required` | Newer virt-install | Add `--osinfo NAME` (or `--osinfo detect=on,require=off`) |
| `virsh console` shows nothing | The guest has no serial console | Add `console=ttyS0` to the guest kernel command line (topic 054) |
| Permission denied on a disk image | SELinux label or location | Use `/var/lib/libvirt/images`, or `restorecon`/proper fcontext |
| The VM has no network | The `default` network is inactive | `virsh net-start default; virsh net-autostart default` |
| Cockpit has no "Virtual machines" | `cockpit-machines` is missing | Install it |
| VMs are slow, guests show high `%st` | The host is over-committed | Fewer vCPUs/VMs; check the host's load (topic 034) |

## Quick recap

- KVM (kernel) + QEMU (device emulation, one process per VM) + libvirt (management) + sVirt (SELinux isolation).
- Setup: check `vmx|svm`, install `qemu-kvm libvirt virt-install`, enable the `virt*d` sockets, run `virt-host-validate qemu`.
- `virt-install --name --memory --vcpus --osinfo --cdrom|--location --disk --network`; manage with `virsh` (`list`, `start`, `shutdown`, `destroy`, `console`, `snapshot-*`, `undefine`).
- Default NAT network `virbr0` 192.168.122.0/24; images in `/var/lib/libvirt/images`; web UI = Cockpit.

**Interview questions**

1. *What are KVM, QEMU and libvirt?* KVM is the kernel hypervisor module using CPU virtualisation extensions; QEMU is the per-VM user-space process emulating devices; libvirt is the management API and tools (`virsh`, `virt-install`, Cockpit).
2. *How does a KVM VM appear on the host?* As one `qemu-kvm` process, with each vCPU as a thread and guest RAM as process memory, scheduled and limited like any process.
3. *What is sVirt?* SELinux protection for VMs: each VM's process and disk images get a unique MCS category pair, so one compromised VM can't access another's disks.
