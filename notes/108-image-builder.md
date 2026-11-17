# 108 · Image Builder: Golden Images from Blueprints

> **You need first:** [107 · Compiling a kernel](107-compiling-a-kernel.md) (and topics 100 KVM, 104 cloud-init, 031 packages)
> **Next:** [109 · Cockpit and Lightspeed](109-cockpit-and-lightspeed.md)

---

## What it is

**RHEL Image Builder** creates customised, repeatable OS images (**golden images**) from a declarative **blueprint**: which packages, users, services, timezone, firewall settings and so on. One blueprint can produce many output formats:
- qcow2 (KVM/OpenStack);
- AMI (AWS);
- VHD (Azure);
- VMDK (VMware);
- GCE;
- raw disks;
- installer ISOs.

| Component | Role |
|---|---|
| `osbuild-composer` | The backend service (socket-activated) that builds images using **osbuild** |
| `composer-cli` | The command-line client |
| `cockpit-image-builder` | The web UI inside Cockpit (topic 109) |
| **Blueprint** | A TOML file describing the image |
| **Compose** | One build of a blueprint into one image type |

Words:
- **Golden image**: a pre-built, tested base image that every new server starts from.
- **TOML**: a simple config file format (`key = "value"`, `[sections]`, `[[repeated sections]]`).
- **Image mode / bootc**: RHEL 10's newer approach, where the OS itself is built and shipped as a **container image** and updated atomically. It's worth knowing it exists.

Red Hat also offers a hosted Image Builder service in the Hybrid Cloud Console, and newer releases add a standalone `image-builder` CLI. The concepts are the same.

## Why it exists

Installing each server by hand (or from an old, drifting VM template) produces snowflakes: no two servers are quite the same. Golden images give:
- **consistency** (every server starts identical);
- **speed** (boot ready-made instead of installing for 20 minutes);
- **auditability** (the blueprint in Git *is* the documentation);
- **security** (rebuild regularly to include the latest updates).

Combined with cloud-init (per-instance details, topic 104) and Ansible (ongoing configuration, topic 105), this is the standard provisioning pipeline.

## Analogy

A blueprint is a **cake recipe card**; Image Builder is a **bakery machine** that bakes perfectly identical cakes from the card, in any tin size you ask for (qcow2, AMI, ISO…). cloud-init then **adds the name in icing** to each cake (hostname, keys) when it's served.

## How it works inside

1. You **push** a blueprint to osbuild-composer, which stores it (with a version).
2. **Depsolve:** composer resolves the requested packages and all dependencies against the configured repositories (by default, the host's own RHEL repos, so the build host must be registered or have mirrors).
3. A **compose** creates an osbuild **manifest**: an exact, ordered list of stages (install these RPMs into a fresh tree, set the locale, create users, enable services, partition a disk image, install the bootloader, convert the format).
4. **osbuild** runs those stages in an isolated build root (not on your live system), producing the image file under `/var/lib/osbuild-composer/`.
5. Cloud image types include **cloud-init** and the right drivers and agents for that platform.

## Commands

### Install

```bash
sudo dnf install -y osbuild-composer composer-cli cockpit-image-builder
sudo systemctl enable --now osbuild-composer.socket
sudo usermod -aG weldr alice          # optional: allow a non-root user to use composer-cli (re-login)
composer-cli status show
```
Requirements: a registered RHEL host (or local repo mirrors), about 4 GiB RAM and 20+ GiB free in `/var`. The **first** request after the service starts is slow: osbuild-composer preloads the definition of every distribution release it supports (minutes on a small VM), so a `depsolve` can look hung. Watch `journalctl -u osbuild-composer -f` for the `Finished preload` lines.

### A blueprint

`golden.toml`:
```toml
name = "golden"
description = "RHEL 10 base image with tools and a deploy user"
version = "0.0.1"

[[packages]]
name = "vim-enhanced"
version = "*"

[[packages]]
name = "tmux"
version = "*"

[[packages]]
name = "cloud-init"
version = "*"

[customizations]
hostname = "golden"

[customizations.timezone]
timezone = "UTC"

[customizations.locale]
languages = ["en_US.UTF-8"]
keyboard = "us"

[[customizations.user]]
name = "deploy"
description = "Deployment user"
groups = ["wheel"]
key = "ssh-ed25519 AAAA… deploy@admin"       # an SSH key; never a plain-text password

[customizations.services]
enabled = ["sshd", "chronyd"]

[customizations.firewall.services]
enabled = ["ssh"]
```

```bash
composer-cli blueprints push golden.toml
composer-cli blueprints depsolve golden | head -5
composer-cli blueprints list
```
```
blueprint: golden v0.0.1
    almalinux-gpg-keys-10.2-22.el10.x86_64      (on RHEL: redhat-release and friends)
    almalinux-release-10.2-22.el10.x86_64
...
golden
```
- `depsolve` succeeding means every package and dependency is available. Fix errors here, not after a 15-minute build.

### Build and download

```bash
composer-cli compose types | tr '\n' ' '
composer-cli compose start golden qcow2
composer-cli compose status
```
```
ami azure container container-minimal ec2 gce image-installer network-installer oci ova pxe-tar-xz qcow2 tar vagrant-libvirt vagrant-virtualbox vhd vmdk wsl
Compose 5f1c2b3a-8d9e-4f10-a2b3-c4d5e6f7a8b9 added to the queue
5f1c2b3a-8d9e-4f10-a2b3-c4d5e6f7a8b9 RUNNING  Tue Nov 17 15:02:11 2026 golden 0.0.1 qcow2
```
- The available types depend on the release and architecture. Status goes WAITING → RUNNING → FINISHED (or FAILED).

```bash
composer-cli compose log 5f1c2b3a-…            # tail of the build log
composer-cli compose image 5f1c2b3a-…          # download into the current directory
sudo cp 5f1c2b3a-…-disk.qcow2 /var/lib/libvirt/images/golden.qcow2
sudo virt-install --name golden-test --memory 2048 --vcpus 2 --osinfo rhel10.0 --import \
  --disk /var/lib/libvirt/images/golden.qcow2 --network network=default --noautoconsole
```

### Web UI

Open `https://HOST:9090` → **Image Builder** → create a blueprint (packages, users, services) → create an image (pick the type) → download when it's finished.

### Try it
1. Write the blueprint above with your own SSH key, depsolve it, build a qcow2, and boot it on KVM (topic 100). Log in as `deploy` with your key.
2. Add a package, bump `version` to 0.0.2, push, rebuild, and confirm the change.
3. Build the same blueprint as a `vhd` or `ami` to see that one recipe serves many platforms.

**Check your work:** on your lab VM, from the notes folder, run `sudo ./checks/check 108` for every step, or `sudo ./checks/check 108 STEP` for one (topic 002 shows how to get the notes there).

## Where you'll use it

- **Golden image pipelines:** blueprints in Git → a CI job builds images → images are uploaded to the cloud or a VM platform → **Terraform** launches instances → cloud-init personalises → Ansible configures.
- **Kubernetes node images:** a consistent, hardened base OS for every node in a pool.
- **Edge and image mode** (RHEL for Edge, bootc): atomic, image-based OS updates.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `composer-cli` hangs for minutes right after install or restart | osbuild-composer is preloading its distribution definitions | Wait; follow `journalctl -u osbuild-composer -f`. Give the host more CPU/RAM |
| `composer-cli: … connection refused` | The socket isn't started | `systemctl enable --now osbuild-composer.socket` |
| `permission denied` on the API socket | Not root and not in `weldr` | `usermod -aG weldr USER`; re-login |
| Depsolve errors | A package name or version isn't in the repos | `dnf info PKG`; fix the blueprint |
| Compose FAILED | Repos unreachable, not registered, disk full | `compose log UUID`; `subscription-manager status`; `df -h /var` |
| An image type is missing | Not supported on this release or architecture | `composer-cli compose types` |
| Can't log in to the built image | No user/key in the blueprint, and no cloud-init data | Add a `[[customizations.user]]` with `key`, or provide cloud-init user data |

## Quick recap

- Image Builder turns a TOML **blueprint** into images: qcow2, AMI, VHD, VMDK, ISO and more.
- `dnf install osbuild-composer composer-cli cockpit-image-builder`; enable `osbuild-composer.socket`.
- `composer-cli blueprints push | depsolve | list`; `compose start BP TYPE | status | log | image UUID`.
- Keep blueprints in Git, use SSH keys (never plain passwords), rebuild regularly for updates; cloud-init personalises each instance.

**Interview questions**

1. *What is a golden image, and why use one?* A tested, pre-built base OS image that all servers start from. It gives consistency, fast provisioning, auditability and a regular way to roll in security updates.
2. *What is a blueprint in RHEL Image Builder?* A versioned TOML definition of an image's packages and customisations (users, services, timezone, firewall), from which composer builds images in any supported format.
3. *How do golden images, cloud-init and Ansible fit together?* The golden image provides the common base; cloud-init applies per-instance settings at first boot (hostname, keys); Ansible manages ongoing configuration and drift.

**Scenario question** (answer out loud first, then compare)

> *"Every new server in your company is installed by hand and they all end up slightly different. Propose a better process."*

**Model answer:**
1. **Golden image:** an Image Builder blueprint (TOML, in Git) with the base packages, users with SSH keys, services, firewall and timezone. Build it for each platform you use (qcow2 for KVM, VMDK, AMI…).
2. **Rebuild regularly** (for example monthly) so new servers start patched, and version the blueprint.
3. **Per-instance settings at first boot** with cloud-init: hostname, keys, network, registration.
4. **Ongoing configuration** with Ansible, so drift is detected and corrected.
5. Test each new image (boot it, run checks) before releasing it.
6. Result: identical, auditable servers in minutes instead of hours.

**Likely follow-ups:**
- *Why not put passwords in the blueprint?* It's stored in Git and the image; use SSH keys, and inject secrets at deploy time.
- *What's `composer-cli blueprints depsolve` for?* Checking the package set resolves before a long compose.
