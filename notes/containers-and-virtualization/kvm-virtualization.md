# KVM Virtualization on RHEL 10 (libvirt, virsh, virt-install, Cockpit)

> **[Advanced/Optional]** (not in the RHEL 10 objectives)
> **Related:** [Cockpit](cockpit-web-console.md) · [Virtualization vs containers](virtualization-vs-containers.md) · [Image Builder](image-builder.md) · [Lab setup](../linux-fundamentals/virtualization-and-lab-setup.md) · [SELinux MCS (sVirt)](../firewall-and-selinux/selinux-mls-and-mcs.md)

## 1. Overview

| Component | Role |
|---|---|
| **KVM** | Kernel module (`kvm`, `kvm_intel`/`kvm_amd`) that turns Linux into a hypervisor using VT-x/AMD-V |
| **QEMU** | User-space process per VM that emulates devices (virtio disks/NICs for performance) |
| **libvirt** | Management API and daemons; tools: `virsh`, `virt-install`, Cockpit |
| **sVirt** | SELinux MCS labels isolate VMs from each other |

Each VM is a normal Linux process (`qemu-kvm`), scheduled by the host kernel. KVM was developed by **Qumranet** (acquired by Red Hat in 2008) and merged into Linux 2.6.20 (2007).

## 2. Host Preparation

```bash
grep -Ec '(vmx|svm)' /proc/cpuinfo     # > 0 = hardware virtualization available (enable VT-x/AMD-V in firmware)
lsmod | grep kvm
# in a VM-based lab, enable NESTED virtualization on the outer hypervisor

dnf install -y qemu-kvm libvirt virt-install virt-viewer
for drv in qemu network nodedev nwfilter secret storage interface; do
    systemctl start virt${drv}d{,-ro,-admin}.socket      # modular daemons (libvirtd is deprecated)
done
virt-host-validate qemu                # all PASS (WARN acceptable for optional features)
```

### Web console

```bash
dnf install -y cockpit cockpit-machines ; systemctl enable --now cockpit.socket
```

`https://host:9090` → **Virtual machines** → *Create VM*: name, installation source (ISO/URL/PXE/cloud image), OS, storage, memory → Create. Tabs: Overview, Usage, Disks (add/remove), Network interfaces, Snapshots, Consoles (VNC/serial). **virt-manager is deprecated in RHEL 10** in favor of the web console.

## 3. Networking & Storage Defaults

| Item | Default |
|---|---|
| Network `default` | NAT via `virbr0`, 192.168.122.0/24, DHCP by libvirt's dnsmasq |
| Bridged | Host bridge (`nmcli con add type bridge …`) so VMs get LAN addresses |
| `direct` (macvtap) | VM on the host NIC; host ↔ VM traffic not possible by default |
| Storage pool `default` | `/var/lib/libvirt/images/` (correct SELinux labels) |
| Machine type | q35 (i440fx is deprecated in RHEL 10) |

## 4. Creating VMs (CLI)

```bash
osinfo-query os | grep -i rhel                      # valid --osinfo names
qemu-img create -f qcow2 /var/lib/libvirt/images/rhel10-vm.qcow2 40G

virt-install \
  --name rhel10-vm --memory 4096 --vcpus 2 \
  --osinfo rhel10.0 \
  --cdrom /var/lib/libvirt/images/rhel-10.0-x86_64-dvd.iso \
  --disk path=/var/lib/libvirt/images/rhel10-vm.qcow2,format=qcow2 \
  --network network=default \
  --graphics vnc,listen=127.0.0.1 --noautoconsole     # VNC only on localhost (use SSH tunnel/Cockpit)
```

**Unattended (Kickstart):**

```bash
virt-install --name rhel10-auto --memory 4096 --vcpus 2 --osinfo rhel10.0 \
  --location /var/lib/libvirt/images/rhel-10.0-x86_64-dvd.iso \
  --initrd-inject /root/ks.cfg --extra-args "inst.ks=file:/ks.cfg console=ttyS0" \
  --disk size=40 --network network=default --graphics none
```

Recent virt-install **requires** `--osinfo` (or `--osinfo detect=on,require=off`). `--ram` is the deprecated spelling of `--memory`.

## 5. Managing VMs with `virsh`

| Task | Command |
|---|---|
| List | `virsh list --all` |
| Start / graceful stop / force off / reboot | `virsh start VM` · `shutdown VM` · `destroy VM` · `reboot VM` |
| Autostart with host | `virsh autostart VM` (`--disable`) |
| Info / IP addresses | `virsh dominfo VM` · `virsh domifaddr VM` |
| Serial console (needs `console=ttyS0` in guest) | `virsh console VM` (exit with `Ctrl+]`) |
| Graphical console | `virt-viewer --connect qemu:///system VM` |
| Edit XML | `virsh edit VM` |
| Add disk | `qemu-img create -f qcow2 …/extra.qcow2 20G` ; `virsh attach-disk VM …/extra.qcow2 vdb --persistent` |
| Add NIC | `virsh attach-interface VM network default --model virtio --config` |
| Snapshots | `virsh snapshot-create-as VM snap1` · `snapshot-list VM` · `snapshot-revert VM snap1` · `snapshot-delete VM snap1` |
| Networks / pools / volumes | `virsh net-list --all` · `pool-list` · `vol-list default` |
| Delete VM and disks ⚠️ | `virsh undefine VM --nvram --remove-all-storage` (`--nvram` for UEFI VMs) |
| Image tools | `qemu-img info/resize/convert` |
| Monitoring | `virt-top` (if installed), `virsh domstats VM`, `top` (qemu-kvm processes) |

## 6. KVM vs Xen **[Interview Knowledge]**

| | KVM | Xen |
|---|---|---|
| Design | Linux kernel is the hypervisor; VMs are processes | Microkernel hypervisor + privileged Dom0 |
| Virtualization | Hardware-assisted (HVM) + virtio paravirtual drivers | PV and HVM |
| RHEL support | Supported hypervisor | Not supported as a host since RHEL 6 |
| Typical users | RHEL, OpenStack, Google Cloud, **AWS Nitro** (KVM-based), Oracle Cloud | Citrix Hypervisor, Qubes OS, older AWS instances |

## 7. Production Practices **[Production Practice]**

- Don't over-commit RAM for production guests; monitor host CPU steal and memory.
- Keep VM images in labeled locations (`/var/lib/libvirt/images`) or relabel custom pools.
- Never expose VNC on 0.0.0.0 without authentication; use Cockpit or SSH tunnels.
- Back up disk images **and** domain XML (`virsh dumpxml VM`); snapshots aren't backups.

## 8. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `virt-host-validate`: hardware virtualization FAIL | VT-x/AMD-V disabled or nested virt off | Enable in firmware / outer hypervisor |
| `error: --os-variant/--osinfo OS name is required` | Newer virt-install | Add `--osinfo NAME` |
| `virsh console` shows nothing | No serial console in guest | Add `console=ttyS0` to the guest kernel cmdline |
| Permission denied on disk image | SELinux label / location | Use `/var/lib/libvirt/images` or `restorecon` |
| VM has no network | `default` network inactive | `virsh net-start default; virsh net-autostart default` |
| Cockpit lacks "Virtual machines" | `cockpit-machines` missing | Install it |

## 9. Quick Revision

```bash
grep -Ec '(vmx|svm)' /proc/cpuinfo · dnf install qemu-kvm libvirt virt-install virt-viewer · virt${drv}d sockets · virt-host-validate qemu
virt-install --name N --memory M --vcpus C --osinfo OS --cdrom ISO|--location ISO --disk … --network network=default
virsh list --all|start|shutdown|destroy|autostart|dominfo|domifaddr|console|edit|snapshot-*|undefine --nvram --remove-all-storage
cockpit-machines · default NAT virbr0 192.168.122.0/24 · /var/lib/libvirt/images
```

## 10. Cross-References

- [Cockpit](cockpit-web-console.md)
- [Virtualization vs containers](virtualization-vs-containers.md)
- [Image Builder](image-builder.md)
- [Lab setup](../linux-fundamentals/virtualization-and-lab-setup.md)
- [SELinux MCS (sVirt)](../firewall-and-selinux/selinux-mls-and-mcs.md)
