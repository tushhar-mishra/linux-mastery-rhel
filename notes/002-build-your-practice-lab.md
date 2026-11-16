# 002 · Build Your Practice Lab

> **You need first:** [001 · What is Linux](001-what-is-linux.md)
> **Next:** [003 · Terminals, consoles and shells](003-terminals-consoles-and-shells.md)

---

## What it is

A **lab** is a set of Linux machines you are allowed to break. You build it from **virtual machines (VMs)**: fake computers that run as programs on your real computer.

Words you need:

- **Host** is your real computer (your laptop or desktop).
- **Guest** is the operating system running inside a VM.
- **Hypervisor** is the software that creates VMs and shares the host's CPU, RAM, disk and network between them.
- **Snapshot** is a saved "photo" of a VM at one moment. You can roll back to it in seconds.
- **ISO** is a single file that holds an exact copy of an installation DVD. You "insert" it into a VM to install the OS.

The lab in these notes is **two RHEL-family VMs** (`server1` and `server2`) on a private network, each with extra empty virtual disks for storage practice. An optional third VM runs Ubuntu so you can compare.

## Why it exists

Linux is learned with your hands, not by reading. Many important skills are dangerous: resetting a lost root password, fixing a machine that won't boot, wiping and partitioning disks, changing firewall rules. You must practise them somewhere where a mistake costs nothing. With snapshots, a broken VM is fixed in 10 seconds.

Two VMs let you practise everything that involves *another* machine: SSH, file copying, NFS shares, firewalls, routing, time sync.

## Analogy

A VM is a **flight simulator**. Pilots practise engine failures in a simulator because crashing a real plane is expensive. A snapshot is the simulator's "reset" button: crash, press reset, and you're back on the runway.

## How it works inside

### Why we have VMs at all

Before virtualization, each application got its own physical server. Most servers sat 90% idle. They were expensive to buy, power and cool, slow to order (weeks), and tied to one piece of hardware. Virtualization lets one physical server run many isolated VMs. This is how every cloud provider works.

### Hypervisor types

| | Type 1 ("bare-metal") | Type 2 ("hosted") |
|---|---|---|
| Runs on | The hardware directly | Top of a normal OS (Windows, macOS, Linux) |
| Speed | Near-native | A little extra overhead |
| Used for | Data centres, cloud | Laptops, labs |
| Examples | VMware ESXi, Microsoft Hyper-V, Xen, **KVM** | VirtualBox, VMware Workstation/Fusion, Parallels, UTM |

**KVM** (Kernel-based Virtual Machine) is Linux's own hypervisor. It is a set of kernel modules (`kvm`, `kvm_intel` or `kvm_amd`) that turn the Linux kernel itself into a hypervisor, so it counts as Type 1. **QEMU** (Quick EMUlator) pretends to be the VM's hardware (disk controller, network card). **libvirt** is the management layer you talk to. Each running VM is just a normal Linux process on the host. AWS and Google Cloud run on KVM-based hypervisors. Topic 100 goes deeper.

### Hardware help

Modern CPUs have built-in virtualization support: **Intel VT-x** (CPU flag `vmx`) and **AMD-V** (CPU flag `svm`). It is often switched off in the firmware settings (UEFI/BIOS). Without it, VMs either won't start or are very slow.

### What happens when a VM boots

1. The hypervisor reserves RAM and creates virtual CPUs.
2. It presents virtual hardware: a disk (really a file on your host, like `server1.vdi` or `server1.qcow2`), a network card and a DVD drive holding your ISO.
3. The VM's virtual firmware starts, finds the ISO and boots the installer, exactly like real hardware.
4. When the guest runs ordinary instructions, the real CPU runs them directly (that's why it's fast). When the guest touches hardware, the hypervisor steps in and fakes the response.

### VM network modes (VirtualBox names)

| Mode | Guest → internet | Host → guest | Guest ↔ guest |
|---|---|---|---|
| **NAT** (Network Address Translation) | Yes | Only with port forwarding | No |
| **NAT Network** | Yes | Only with port forwarding | Yes |
| **Host-only** | No | Yes | Yes |
| **Bridged** | Yes (the guest sits on your real network) | Yes | Yes |

The usual lab setup is **NAT** (for internet) **plus Host-only** (a private network where the VMs and your host can talk). Vagrant sets this up for you.

### Choosing the OS image

| Option | Notes |
|---|---|
| **RHEL 10** with the free **Red Hat Developer Subscription** | Genuine RHEL. Download the **DVD ISO** (it also holds the BaseOS and AppStream software repositories, useful offline) |
| **AlmaLinux 10 / Rocky Linux 10** | Free rebuilds that behave like RHEL 10. No registration needed. Easiest for Vagrant |
| **Ubuntu Server LTS** (Long Term Support) | Optional third VM to compare Debian-family tools |
| Apple Silicon Mac | Use the **aarch64** (64-bit ARM) ISO in UTM, Parallels or VMware Fusion. The commands are the same |

### Sizing

| | Minimum | Better |
|---|---|---|
| Host CPU | 4 cores with VT-x/AMD-V **and AVX2** (needed by RHEL 10) | 6–8 cores |
| Host RAM | 12 GB | 16–32 GB |
| Host free disk | 50 GB | 100+ GB on an SSD |
| Each VM | 2 vCPUs (virtual CPUs), 2–4 GB RAM, 20 GB system disk | Plus 2–3 extra 5–10 GB disks |

## Commands

### Option A: build with Vagrant (fast and repeatable)

**Vagrant** is a tool that builds VMs from a text file called a `Vagrantfile`. It downloads a ready-made disk image (a "box"), creates the VMs and sets up the network. You can destroy and rebuild the whole lab with two commands.

Install **VirtualBox** and **Vagrant** on your host. Then create a folder `linux-lab` with this `Vagrantfile`:

```ruby
# linux-lab/Vagrantfile
BOX_NAME = "almalinux/10"          # any RHEL-10-compatible box that exists in the Vagrant catalog

Vagrant.configure("2") do |config|
  config.vm.synced_folder ".", "/vagrant", disabled: true   # no shared folder: behave like a real server

  config.vm.define "server1" do |s|
    s.vm.box = BOX_NAME
    s.vm.hostname = "server1.example.com"
    s.vm.network "private_network", ip: "192.168.56.10"
    s.vm.provider "virtualbox" do |vb|
      vb.name = "server1" ; vb.memory = 4096 ; vb.cpus = 2
    end
  end

  config.vm.define "server2" do |s|
    s.vm.box = BOX_NAME
    s.vm.hostname = "server2.example.com"
    s.vm.network "private_network", ip: "192.168.56.11"
    s.vm.provider "virtualbox" do |vb|
      vb.name = "server2" ; vb.memory = 2048 ; vb.cpus = 1
    end
  end
end
```

- `private_network` creates the Host-only network. `192.168.56.10` is server1's address on it (IP addresses are explained in topic 059).
- `vb.memory` is RAM in MB. `vb.cpus` is the number of virtual CPUs.

```bash
cd linux-lab
vagrant up
```
```
Bringing machine 'server1' up with 'virtualbox' provider...
Bringing machine 'server2' up with 'virtualbox' provider...
==> server1: Importing base box 'almalinux/10'...
...
==> server2: Machine booted and ready!
```
- `vagrant up` downloads the box the first time, then creates and boots both VMs.

```bash
vagrant status
```
```
Current machine states:

server1                   running (virtualbox)
server2                   running (virtualbox)
```

```bash
vagrant ssh server1
```
```
[vagrant@server1 ~]$
```
- You are now inside server1, logged in as user `vagrant`. The text `[vagrant@server1 ~]$` is the **prompt** (explained in topic 004). The `vagrant` user can become the administrator with `sudo -i` (topic 028).

```bash
ping -c 3 192.168.56.11
```
```
PING 192.168.56.11 (192.168.56.11) 56(84) bytes of data.
64 bytes from 192.168.56.11: icmp_seq=1 ttl=64 time=0.612 ms
64 bytes from 192.168.56.11: icmp_seq=2 ttl=64 time=0.540 ms
64 bytes from 192.168.56.11: icmp_seq=3 ttl=64 time=0.498 ms

--- 192.168.56.11 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2003ms
```
- `ping` sends small test packets to another machine and waits for replies. `-c 3` means send 3.
- `time=0.6 ms` is the round-trip time. `0% packet loss` means server1 can reach server2. The lab network works.

Everyday lab control (run on the host, in the `linux-lab` folder):

```bash
vagrant snapshot save server1 clean      # take a snapshot named "clean"
vagrant snapshot restore server1 clean   # roll back to it
vagrant halt                              # shut down both VMs
vagrant destroy -f                        # delete both VMs completely (-f = don't ask)
```

### Option B: install from the ISO by hand (learn the installer)

Create a VM in VirtualBox, VMware or virt-manager, attach the DVD ISO and boot. The RHEL installer is called **Anaconda**. On its main screen:

| Setting | What to choose | Why |
|---|---|---|
| Software Selection | *Minimal Install* (like real servers) or *Server with GUI* | Servers rarely have a desktop |
| Installation Destination | The first disk only, "Automatic" partitioning. **Leave the extra disks unselected** | You'll partition them yourself in Part 6 |
| Network & Hostname | Switch the network card **ON**; set a hostname like `server1.example.com` | Otherwise the VM boots with no network |
| Time & Date | Your time zone; network time ON | Correct time matters for logs and security (topic 069) |
| Root Account | Disabled by default on RHEL 10. You may enable it for the lab | Root login over SSH with a password stays blocked anyway |
| User Creation | Create your user and tick **"Make this user administrator"** | This adds you to the `wheel` group, which may use `sudo` |

The automatic layout creates: a `/boot` area (about 1 GiB), the main system area `/` on LVM (topic 049), and swap (topic 050). On UEFI machines it adds `/boot/efi`. You'll understand every one of these by Part 7.

After the first boot, log in and check:

```bash
cat /etc/os-release        # right distro and version?
ip -br addr                # has the network card got an address? (topic 060)
lsblk                      # do you see your extra disks?
```

`lsblk` sample output (explained fully in topic 046):
```
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda      8:0    0   20G  0 disk
├─sda1   8:1    0    1G  0 part /boot
└─sda2   8:2    0   19G  0 part
  ├─rhel-root 253:0 0 17G 0 lvm /
  └─rhel-swap 253:1 0  2G 0 lvm [SWAP]
sdb      8:16   0    5G  0 disk
sdc      8:32   0    5G  0 disk
```
- `sda` is the system disk. `sdb` and `sdc` are your empty practice disks (on KVM they're called `vda`, `vdb`, `vdc`).

### Add extra disks for storage practice

Shut the VM down. Then in VirtualBox go to Settings → Storage → Add Hard Disk (5 GB each). Boot it, and `lsblk` should show the new `sdb` and `sdc`.

### Check that your host can run VMs well

On a Linux host:

```bash
grep -Ec '(vmx|svm)' /proc/cpuinfo
```
```
8
```
- This counts the CPU lines that have the virtualization flag. Any number above 0 means VT-x/AMD-V is available. `0` means it's off in the firmware or unsupported.

Inside a guest:

```bash
systemd-detect-virt
```
```
oracle
```
- This shows what hypervisor you're running under: `oracle` (VirtualBox), `kvm`, `vmware`, `microsoft` (Hyper-V), or `none` (real hardware).

### Make the lab realistic

- Keep **SELinux enforcing** and the **firewall on**. Never switch them off to "make something work". Production servers keep them on, and you'll learn to work with them (Part 9).
- Take a snapshot called `clean` right after setup, and another before every risky lab (boot, disks, passwords).
- After each lab, **reboot** and check that your change survived. Many changes only live in memory until you make them permanent. Real servers reboot for patches.

### Try it
1. Build the two-VM lab and run `ping` from server1 to server2.
2. Take a snapshot. Then (inside server1) run `sudo touch /i-was-here`, restore the snapshot, and confirm the file is gone with `ls /`.
3. Add two 5 GB disks to server1 and find them with `lsblk`.

## Where you'll use it

- **Every topic in these notes** has commands to type in this lab.
- **Production practice:** real teams test changes on staging VMs first. "Snapshot, change, verify, roll back if bad" is the same habit you'll use with real change management.
- **Vagrant and similar "infrastructure from a text file" tools** (Terraform, cloud images) are everyday DevOps work. The Vagrantfile is your first taste of *infrastructure as code*.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| "VT-x is not available" / "AMD-V is disabled" | Virtualization is switched off in firmware, or Windows Hyper-V is holding it | Enable VT-x/AMD-V in UEFI/BIOS. On Windows, turn off conflicting features or use a Hyper-V-compatible setup |
| RHEL 10 installer stops or panics very early, mentioning the CPU | The CPU (as seen by the VM) lacks AVX2 / x86-64-v3 | Newer host CPU, or on KVM set CPU mode `host-passthrough` |
| `vagrant up` can't find the box | Wrong box name | `vagrant box list`; search the Vagrant box catalog for a 10.x box |
| VMs can't ping each other | Host-only network missing or broken | Recreate the host-only network in VirtualBox; inside the guests run `ip -br addr` |
| No network after a manual install | The network card was left OFF in the installer | `nmcli device status`, then `nmcli connection up <name>` (topic 060) |
| Can't log in as root | Root is disabled by default on RHEL 10 | Log in as your admin user and run `sudo -i` |
| VM very slow | Too little RAM, or hardware virtualization unavailable | Give it more RAM; check the `vmx`/`svm` flags |

## Quick recap

- A lab is 2+ disposable VMs on a private network, with extra disks and **snapshots**.
- A hypervisor runs VMs. KVM (Linux's own) is Type 1; VirtualBox is Type 2.
- RHEL 10 needs a CPU with AVX2 (x86-64-v3) and hardware virtualization (VT-x/AMD-V).
- Keep SELinux and the firewall on in the lab, and reboot to check your changes stick.

**Interview questions**

1. *Type 1 vs Type 2 hypervisor?* Type 1 runs directly on hardware (ESXi, Hyper-V, KVM). Type 2 runs as an app on a normal OS (VirtualBox, VMware Workstation).
2. *Why is KVM called Type 1 when a full Linux OS runs on the host?* Its kernel modules turn the Linux kernel itself into the hypervisor. VMs are processes scheduled directly by that kernel.
3. *How do you check if a server can host VMs?* Look for the `vmx` or `svm` CPU flags, check that `/dev/kvm` exists, check the firmware settings, and run `virt-host-validate`.
