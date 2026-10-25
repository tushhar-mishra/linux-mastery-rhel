# RHEL Image Builder (osbuild-composer)

> **[Advanced/Optional]**
> **Related:** [Cockpit](cockpit-web-console.md) · [KVM](kvm-virtualization.md) · [RPM & DNF](../logs-scheduling-and-packages/rpm-and-dnf-package-management.md) · [Passwords & hashing](../users-groups-and-permissions/passwords-and-aging.md)

## 1. Overview

**Image Builder** creates customized, repeatable RHEL images (golden images) from a declarative **blueprint**: packages, users, services, timezone and more. Output formats include qcow2 (KVM/OpenStack), AMI, VHD, VMDK and installer ISOs.

| Component | Role |
|---|---|
| `osbuild-composer` | Backend service (socket-activated) that builds images with `osbuild` |
| `composer-cli` | Command-line client |
| `cockpit-image-builder` | Web UI in Cockpit (replaces deprecated `cockpit-composer`) |
| Blueprint | TOML description of the image |
| Compose | One build of a blueprint into an image type |

**Requirements:** a registered RHEL 10 host with BaseOS/AppStream access (or local mirrors), root or `weldr` group membership, about 4 GiB RAM and 20+ GiB free in `/var`.

## 2. Install

````bash
dnf install -y osbuild-composer composer-cli cockpit-image-builder
systemctl enable --now osbuild-composer.socket
usermod -aG weldr alice              # optional: let a non-root user use composer-cli (re-login)
source /etc/bash_completion.d/composer-cli
composer-cli status show             # API/backend status
````

## 3. Blueprint

````bash
composer-cli blueprints list
vi my-golden-image.toml
````

````toml
name = "my-golden-image"
description = "RHEL 10 golden image with base tools and a deploy user"
version = "0.0.1"

[[packages]]
name = "vim-enhanced"
version = "*"

[[packages]]
name = "bash-completion"
version = "*"

[[packages]]
name = "tmux"
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
key = "ssh-ed25519 AAAA… deploy@admin"          # prefer an SSH key
# password = "$6$…"                                # or a hash (openssl passwd -6), never plain text

[customizations.services]
enabled = ["sshd"]
````

````bash
composer-cli blueprints push my-golden-image.toml
composer-cli blueprints depsolve my-golden-image   # check that all packages resolve
composer-cli blueprints show my-golden-image
composer-cli blueprints save my-golden-image       # writes my-golden-image.toml (export)
````

## 4. Build (Compose)

````bash
composer-cli compose types                          # available outputs on THIS system
composer-cli compose start my-golden-image qcow2    # prints a compose UUID
composer-cli compose status                         # WAITING → RUNNING → FINISHED/FAILED
composer-cli compose log <UUID>                     # tail of the build log
composer-cli compose logs <UUID>                    # full logs as a tarball
composer-cli compose image <UUID>                   # download the image to the current directory
composer-cli compose info <UUID>
composer-cli compose delete <UUID>
````

Build data lives under `/var/lib/osbuild-composer/` (and caches under `/var/cache/osbuild-composer/`).

## 5. Cockpit UI

`https://<host>:9090` → **Image Builder** → *Create blueprint* (packages, users, services…) → *Create image* (choose output type) → download when finished.

## 6. Production Practices **[Production Practice]**

- Keep blueprints in Git; bump `version` on each change.
- Never store plain-text passwords; prefer SSH keys, and remove build-time secrets.
- Pin or review package sets; rebuild images regularly to include security updates.
- For container-style OS deployment on RHEL 10, also consider **image mode** (bootc).

## 7. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `composer-cli: … connection refused` | Socket not started | `systemctl enable --now osbuild-composer.socket` |
| `permission denied` on the API socket | Not root / not in `weldr` | `usermod -aG weldr USER`; re-login |
| Depsolve errors | Package name/version not in repos | `dnf info PKG`; fix the blueprint |
| Compose FAILED | Repos unavailable, disk space | `compose log UUID`; `df -h /var` |
| Image type missing | Not supported on this release/arch | `composer-cli compose types` |

## 8. Interview Questions

| Question | Answer |
|---|---|
| What is a blueprint? | A TOML definition of an image's packages and customizations. |
| How do you download a finished image? | `composer-cli compose image <UUID>`. |
| Why golden images? | Consistent, fast, auditable deployments across VMs/clouds. |

## 9. Quick Revision

````bash
dnf install osbuild-composer composer-cli cockpit-image-builder ; systemctl enable --now osbuild-composer.socket
blueprints push|list|show|depsolve|save|delete · compose types|start BP TYPE|status|log|logs|image|info|delete UUID
````

## 10. Cross-References

- [Cockpit](cockpit-web-console.md)
- [KVM](kvm-virtualization.md)
- [RPM & DNF](../logs-scheduling-and-packages/rpm-and-dnf-package-management.md)
- [Passwords & hashing](../users-groups-and-permissions/passwords-and-aging.md)
