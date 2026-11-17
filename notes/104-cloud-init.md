# 104 · cloud-init: How Cloud VMs Configure Themselves

> **You need first:** [103 · Performance and observability](103-performance-and-observability.md) (and topics 100 KVM, 065 SSH keys, 098 units)
> **Next:** [105 · Ansible](105-ansible.md)

---

## What it is

**cloud-init** is the standard program that **configures a VM on its first boot** from a generic image. It's installed in practically every cloud image (RHEL, Ubuntu, Fedora, Debian…) and runs on AWS, Azure, Google Cloud, OpenStack, Proxmox, KVM/libvirt and more. On first boot it sets:
- the hostname;
- users and SSH keys;
- packages;
- files;
- network settings;
- commands to run.

Words:
- **Image**: a generic, pre-installed disk (for RHEL: the "KVM Guest Image" qcow2). Thousands of VMs start from the same image.
- **Datasource**: where cloud-init finds its instructions. On a cloud, a **metadata service** at `http://169.254.169.254` (a special link-local address); on a lab KVM host, a small ISO labelled `cidata` (the **NoCloud** datasource).
- **Metadata**: facts from the platform: instance ID, hostname, region, network config.
- **User data**: **your** instructions, most often a YAML file starting with `#cloud-config` (or a shell script starting with `#!`).
- **Instance ID**: a unique ID per VM. cloud-init runs its first-boot work once per instance ID.

## Why it exists

Images must be **generic** (no hostname, no keys, no passwords baked in), but every VM needs to become **specific**. Before cloud-init, people built a custom image per role or logged in to configure each VM by hand. cloud-init turns "launch a VM" into "launch a VM **and** have it ready", which is what Terraform, autoscaling groups and Kubernetes node pools rely on. It's usually the **first step**; configuration management (Ansible, topic 105) or Kubernetes takes over after.

## Analogy

A generic image is a **new phone straight from the factory**. cloud-init is the **setup wizard** on first power-on: it reads your account details (user data) and the carrier's settings (metadata), then sets the name, adds your accounts, installs your apps and connects to the network. It doesn't run the wizard again on the next reboot, unless you "factory reset" it (`cloud-init clean`).

## How it works inside

1. At boot, systemd's `cloud-init-generator` checks whether cloud-init should run, and **ds-identify** detects the platform (DMI/SMBIOS strings, attached disks).
2. cloud-init runs in **stages**, as systemd units at different points in the boot:

| Stage | systemd unit | What happens |
|---|---|---|
| Local | `cloud-init-local.service` | Before networking: find a local datasource, write the **network configuration** (NetworkManager keyfiles on RHEL, netplan on Ubuntu) |
| Network | `cloud-init.service` (`cloud-init-network.service` in newer versions) | Network up: fetch metadata/user data, set hostname, users, SSH keys, disks, mounts |
| Config | `cloud-config.service` | Many `#cloud-config` modules: repositories, timezone, NTP; `runcmd` is written out as a script here (it runs in the final stage) |
| Final | `cloud-final.service` | Late work: install packages, run `runcmd` and user scripts, `phone_home`, print the "finished" message |

3. Results are cached in `/var/lib/cloud/` (`instance/` → a symlink to the current instance's directory). Each module records that it ran, with a **frequency**: `once-per-instance` (most), `always` (every boot, e.g. `bootcmd`) or `once`.
4. **New instance ID** (a new VM from the same image) → per-instance modules run again. Same instance ID (a reboot) → they're skipped.
5. Logs: `/var/log/cloud-init.log` (detailed) and `/var/log/cloud-init-output.log` (output of your commands and scripts).

## Commands

### A user-data file

```yaml
#cloud-config
hostname: web01
fqdn: web01.lab.example
users:
  - name: alice
    groups: wheel
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    shell: /bin/bash
    ssh_authorized_keys:
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA… alice@laptop
ssh_pwauth: false
timezone: Europe/London
package_update: true
packages: [nginx, chrony]
write_files:
  - path: /usr/share/nginx/html/index.html
    content: "Hello from cloud-init\n"
    permissions: "0644"
runcmd:
  - [systemctl, enable, --now, nginx]
  - [firewall-cmd, --permanent, --add-service=http]
  - [firewall-cmd, --reload]
```
- The first line **must** be exactly `#cloud-config`.
- `runcmd` runs once, late in the final stage; `bootcmd` runs early on **every** boot.

### Lab: boot a RHEL or Ubuntu cloud image on KVM with NoCloud

```bash
cat > meta-data <<'EOF'
instance-id: web01-001
local-hostname: web01
EOF
# user-data = the YAML above
sudo dnf install -y genisoimage
genisoimage -output seed.iso -volid cidata -joliet -rock user-data meta-data     # the volume label MUST be "cidata"
sudo cp rhel-10.0-x86_64-kvm.qcow2 /var/lib/libvirt/images/web01.qcow2
sudo cp seed.iso /var/lib/libvirt/images/web01-seed.iso
sudo virt-install --name web01 --memory 2048 --vcpus 2 --osinfo rhel10.0 --import \
  --disk /var/lib/libvirt/images/web01.qcow2 \
  --disk /var/lib/libvirt/images/web01-seed.iso,device=cdrom \
  --network network=default --graphics none --noautoconsole
```
- Newer `virt-install` can do this in one step: `--cloud-init user-data=user-data,meta-data=meta-data`. On Ubuntu, `cloud-localds seed.iso user-data meta-data` builds the ISO.
- In the cloud, you paste the same YAML into the "user data" field (AWS EC2, Azure "custom data", GCP `user-data` metadata key) or pass it from Terraform.

### Check what happened (inside the VM)

```bash
sudo cloud-init status --long
```
```
status: done
extended_status: done
boot_status_code: enabled-by-generator
last_update: Tue, 17 Nov 2026 14:41:09 +0000
detail: DataSourceNoCloud [seed=/dev/sr0]
errors: []
recoverable_errors: {}
```
- `done` with no errors; the datasource was the NoCloud seed on the CD-ROM. `status: error` or `running` for a long time means look at the logs.
- **Use sudo for every `cloud-init` command on RHEL 10.** `/run/cloud-init` is mode 0700, so as a normal user even `cloud-init status` or `schema` crashes with `PermissionError: [Errno 13] Permission denied: '/run/cloud-init/cloud.cfg'`.

```bash
sudo cloud-init status --wait                  # block until finished. Exit code: 0 = done, 1 = error, 2 = done with recoverable errors (degraded)
sudo cloud-init analyze show | tail -5         # time per stage and module
sudo tail -20 /var/log/cloud-init-output.log   # output of packages / runcmd
sudo grep -iE 'warn|error|traceback' /var/log/cloud-init.log | head
sudo cloud-init query userdata                 # the user data it received
sudo cloud-init query ds | head                # datasource metadata
sudo cloud-init schema --system --annotate     # validate the user data it used
```
```
Finished at Tue, 17 Nov 2026 14:41:09 +0000. Datasource DataSourceNoCloud [seed=/dev/sr0].  Up 38.52 seconds
```
- That line at the end of `cloud-init-output.log` means everything ran.

### Validate before you boot

```bash
sudo cloud-init schema --config-file user-data --annotate
```
```
Valid schema user-data
```

### Re-run (lab) and prepare an image

```bash
sudo cloud-init clean --logs            # forget this instance: next boot = "first boot" again
sudo cloud-init clean --logs --seed --machine-id   # before turning a configured VM into a template image
```
- Images made from a VM **without** cleaning keep the old instance state, the SSH host keys and the machine-id, so every clone looks identical. That's a classic duplicate-identity bug.

### Try it
1. Boot a RHEL (or Ubuntu) cloud image on KVM with a NoCloud seed that creates your user with an SSH key and installs nginx. SSH in with your key.
2. Read `cloud-init status --long`, `analyze show`, and the output log.
3. Put a YAML error in user-data, validate it with `cloud-init schema`, then boot anyway and find the error in the logs.
4. Reboot and confirm `runcmd` did **not** run again; then `cloud-init clean --logs`, reboot, and watch it run again.

**Check your work:** on your lab VM, from the notes folder, run `sudo ./checks/check 104` for every step, or `sudo ./checks/check 104 STEP` for one (topic 002 shows how to get the notes there).

## Where you'll use it

- **Every cloud VM**: EC2/Azure/GCP instance bootstrapping, often templated by **Terraform** (`user_data = file("cloud-init.yaml")`).
- **Kubernetes node provisioning:** many installers and node pools (Cluster API, kubeadm-based images, managed node groups) use cloud-init to join nodes to the cluster.
- **Proxmox, OpenStack and libvirt** templates for home and work labs.
- **Golden images:** clean cloud-init state before sealing an image (topic 108 builds images with cloud-init included).

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `extended_status: degraded done`, `detail: DataSourceNone`, warning `Used fallback datasource` | No datasource was found (no seed ISO, no metadata service), so your user data never ran | Check the seed volume label is `cidata`, or the cloud metadata endpoint; `sudo cloud-init status --wait` returns 2 here |
| `PermissionError … /run/cloud-init/cloud.cfg` | Ran `cloud-init` as a normal user | Use `sudo` |
| Nothing was applied; no user created | The first line isn't `#cloud-config`, invalid YAML, or the datasource wasn't found | `cloud-init schema --annotate`; `cloud-init status --long` (datasource); check that the seed ISO label is `cidata` |
| Can't SSH in with the key | Wrong user name, key typo, or `ssh_pwauth` expectations | Console login, or read `cloud-init.log`; RHEL's default image user is `cloud-user`, Ubuntu's is `ubuntu` |
| The boot hangs for minutes | Looking for a metadata service that doesn't exist (wrong datasource) | Set `datasource_list` in `/etc/cloud/cloud.cfg.d/`; provide a NoCloud seed |
| `runcmd` didn't run again after a reboot | It's once-per-instance by design | `bootcmd` for every-boot work, or a systemd unit |
| Package install failed | No network or repos at that stage, or no subscription on RHEL | Check `cloud-init-output.log`; register first (`rh_subscription` module) |
| Clones share SSH host keys / machine-id | The template wasn't cleaned | `cloud-init clean --logs --seed --machine-id` before sealing |
| Network config written by cloud-init overrides yours | cloud-init manages networking on every boot | Disable it: `network: {config: disabled}` in `/etc/cloud/cloud.cfg.d/99-custom.cfg` |

## Quick recap

- cloud-init turns a generic image into a specific VM on **first boot**, from a **datasource** (cloud metadata service or a NoCloud `cidata` ISO).
- User data = `#cloud-config` YAML: `hostname`, `users` + `ssh_authorized_keys`, `packages`, `write_files`, `runcmd`, `bootcmd`.
- Stages: local → network → config → final; per-instance work runs once per **instance ID**.
- Debug: `cloud-init status --long`, `analyze show`, `/var/log/cloud-init.log`, `cloud-init-output.log`, `schema --annotate`. `cloud-init clean` before making templates.

**Interview questions**

1. *What is cloud-init and where does it get its configuration?* The first-boot configuration agent in cloud images. It reads platform metadata and user data from a datasource: the cloud's metadata service (169.254.169.254) or, in labs, a NoCloud seed disk labelled `cidata`.
2. *Why didn't my `runcmd` run after a reboot?* `runcmd` runs once per instance; cloud-init records that it ran in `/var/lib/cloud`. Use `bootcmd` or a systemd unit for every-boot tasks.
3. *What must you do before turning a configured VM into a reusable image?* Run `cloud-init clean` (with `--logs`, and `--machine-id`/`--seed` as appropriate), so clones get fresh instance state, SSH host keys and machine IDs.

**Scenario question** (answer out loud first, then compare)

> *"New VMs from your template come up without the SSH key and with the wrong hostname, and some have the same SSH host key as each other. What's wrong with the template?"*

**Model answer:**
1. Identical host keys and missing per-VM settings mean the template was made from a VM that **already ran cloud-init**, and wasn't cleaned.
2. cloud-init remembers the instance it configured (in `/var/lib/cloud`). The clones look like the same instance, so the per-instance modules (users, keys, hostname, host-key regeneration) don't run again.
3. Fix the template:
   - run `cloud-init clean --logs --seed --machine-id`;
   - remove the SSH host keys;
   - then shut down and capture the image.
4. On the broken clones: fix the hostname and keys by hand, regenerate the host keys (`rm /etc/ssh/ssh_host_*`, `ssh-keygen -A`, restart sshd), or `cloud-init clean` and reboot.
5. Check what each instance received: `cloud-init query -a`, `cloud-init status --long`, `/var/log/cloud-init.log`.

**Likely follow-ups:**
- *`runcmd` vs `bootcmd`?* `runcmd` runs once per instance late in boot; `bootcmd` runs early on every boot.
- *Where does cloud-init get its data in a lab?* A NoCloud seed (an ISO labelled `cidata` with `user-data` and `meta-data`).
