# RHCSA Practice Lab Setup (VirtualBox/KVM + Vagrant)

> Supports all objectives (practice environment)
> **Related:** [Virtualization & lab setup](../linux-fundamentals/virtualization-and-lab-setup.md) · [Sample exam with solutions](sample-exam-with-solutions.md) · [Objectives map](exam-objectives-map.md) · [KVM](../containers-and-virtualization/kvm-virtualization.md) · [Mock exam 2](mock-exam-2.md) · [Mock exam 3](mock-exam-3.md)

## 1. Goal

A **repeatable, disposable** two-VM lab that mirrors the exam: two systems, extra disks, a private network, no reliance on GUI tools. Vagrant builds it from a text file; snapshots or `vagrant destroy` + `vagrant up` reset it.

| Component | Minimum | Recommended |
|---|---|---|
| CPU | 4 cores, VT-x/AMD-V enabled (x86-64-v3 for RHEL 10) | 6–8 cores |
| RAM | 12 GB | 16–32 GB |
| Disk | 50 GB free | 100+ GB SSD |

## 2. Choosing the OS Image

| Option | Pros | Notes |
|---|---|---|
| **RHEL 10** via the free Red Hat Developer Subscription | Identical to the exam | Register with `subscription-manager`; build VMs from the ISO (or a Vagrant box you create) |
| AlmaLinux 10 / Rocky Linux 10 boxes | Binary-compatible, no registration | Check the box name and availability on the Vagrant box catalog |
| Rocky/Alma **9** boxes | Easy to find | RHEL 9 differs (no Flatpak objective, modularity, ifcfg etc.); use only if 10 isn't available |

## 3. Install Tools

- VirtualBox (or libvirt/KVM on Linux hosts with the `vagrant-libvirt` plugin)
- Vagrant: `vagrant --version`

## 4. Vagrantfile (two servers + private network)

```ruby
# rhcsa10-lab/Vagrantfile
BOX_NAME = "almalinux/10"          # adjust to an available 10.x box (or your RHEL 10 box)

Vagrant.configure("2") do |config|
  config.vm.synced_folder ".", "/vagrant", disabled: true   # exam-like: no shared folders

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

```bash
mkdir rhcsa10-lab && cd rhcsa10-lab      # place the Vagrantfile here
vagrant up ; vagrant status
vagrant ssh server1 ; sudo -i            # Vagrant boxes use user "vagrant" with passwordless sudo
ping -c 3 192.168.56.11                  # server1 → server2
vagrant halt ; vagrant destroy -f        # stop / delete
vagrant snapshot save server1 clean ; vagrant snapshot restore server1 clean   # quick resets
```

## 5. Extra Disks for Storage Tasks

Halt the VMs, then add two virtual disks to `server1` (VirtualBox: Settings → Storage → Add Hard Disk, e.g., 5 GB each). Then `vagrant up` and `lsblk` should show `sdb` and `sdc` (or `vdb`/`vdc` on KVM).

| Disk | Practice |
|---|---|
| disk1 | GPT partitions, LVM (PV/VG/LV, extents, extend), swap |
| disk2 | VFAT/ext4/XFS filesystems, fstab by UUID; optionally LUKS/RAID **[Advanced]** |

## 6. Make the Lab Exam-Like

- Keep **SELinux enforcing** and **firewalld enabled**.
- Practice as root on the console as well as via SSH; practice `rd.break` from the VirtualBox console.
- Create a local repository from the RHEL 10 ISO (`/mnt/iso/BaseOS`, `/AppStream`) and practice without internet.
- Put an NFS server, chrony server and Flatpak remote on `server2` to practice client tasks on `server1`.
- After each practice run: **reboot** and verify everything persisted.

## 7. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| VM won't start: "VT-x is not available" | Virtualization disabled / Hyper-V conflict (Windows) | Enable VT-x/AMD-V; disable conflicting hypervisor features |
| RHEL 10 kernel panic / "CPU not supported" | CPU lacks x86-64-v3 | Newer host CPU, or a distribution build for older CPUs |
| `vagrant up` can't find the box | Wrong box name | `vagrant box list`; check the catalog |
| Private network unreachable | Host-only adapter issue | Recreate the host-only network; `ip a` in guests |
