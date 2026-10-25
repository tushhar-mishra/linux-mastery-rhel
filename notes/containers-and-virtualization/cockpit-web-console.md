# Cockpit: The RHEL Web Console

> **[Advanced/Optional]** (convenient for any objective; not required by the exam)
> **Related:** [Image Builder](image-builder.md) · [KVM](kvm-virtualization.md) · [Podman](podman-containers.md) · [firewalld](../firewall-and-selinux/firewalld.md)

## 1. Overview

**Cockpit** is a browser-based admin interface on **HTTPS port 9090**. It uses the system's own APIs and tools (systemd, NetworkManager, storaged/udisks, journald, firewalld), so anything changed in Cockpit is visible in the CLI and vice versa. It's a convenience layer, not a replacement for the CLI.

## 2. Install & Access

`````bash
dnf install -y cockpit                   # usually preinstalled on Server installs
systemctl enable --now cockpit.socket    # socket-activated (the login banner reminds you)
firewall-cmd --list-services             # 'cockpit' is allowed in the public zone by default
# otherwise: firewall-cmd --permanent --add-service=cockpit ; firewall-cmd --reload
`````

Open `https://<server>:9090`, accept the self-signed certificate (lab), and log in as a **regular user**. Then click **Administrative access** (sudo) to get root privileges.

`root` is listed in `/etc/cockpit/disallowed-users` by default, so direct root logins are refused.

## 3. Main Pages & Add-ons

| Page | Use |
|---|---|
| Overview | Health, CPU/memory, uptime, hostname, performance profile (tuned), crypto policy |
| Logs | Journal with filters (priority, time, unit) |
| Storage | Disks, partitions, LVM, RAID, NFS mounts, LUKS, Stratis |
| Networking | Interfaces, bonds, bridges, VLANs, firewall zones |
| Accounts | Users, groups, passwords, admin rights, SSH keys |
| Services | systemd units: start/stop/enable, timers |
| SELinux, Software updates, Kernel dump, Diagnostic reports | As named |
| Terminal | Shell in the browser |

| Add-on package | Adds |
|---|---|
| `cockpit-machines` | Virtual machines (KVM) |
| `cockpit-podman` | Podman containers |
| `cockpit-image-builder` | Image Builder (replaces deprecated `cockpit-composer`) |
| `cockpit-storaged` | Storage page (often installed already) |

## 4. Multiple Hosts (RHEL 10)

The **host switcher** (several machines in one Cockpit session via SSH) is **deprecated and disabled by default** in RHEL 10. Alternatives:

- Use each host's own login page (`https://host2:9090`), one host per browser session.
- Use the **Cockpit Client** Flatpak on your workstation.
- Short term only, after a risk assessment: in `/etc/cockpit/cockpit.conf`, set `[WebService]` → `AllowMultiHost=yes`.

## 5. Security & Configuration **[Production Practice]**

- Install a trusted certificate: put `name.crt` and `name.key` in `/etc/cockpit/ws-certs.d/`, then restart `cockpit`. Check with `/usr/libexec/cockpit-certificate-ensure --check`.
- Restrict port 9090 to admin networks: a source-based firewalld zone or a rich rule (see [firewalld](../firewall-and-selinux/firewalld.md)).
- Use regular accounts + sudo, ideally with central identity/SSO (IdM).
- Settings such as `IdleTimeout` and `LoginTitle` go in `/etc/cockpit/cockpit.conf`.
- Back up configurations before large storage or network changes made through the GUI.

## 6. Example: Add a Data Partition (GUI)

Storage → select the disk with free space → **Create partition** → size, type (XFS/ext4), mount point `/data` → Cockpit writes the fstab entry (by UUID) when "mount at boot" is selected. Then verify in a terminal: `lsblk -f; findmnt /data; cat /etc/fstab`.

## 7. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Browser can't connect to :9090 | Socket not enabled / firewall | `systemctl enable --now cockpit.socket`; firewall service `cockpit` |
| "Permission denied" logging in as root | `disallowed-users` | Log in as a regular user + Administrative access |
| Can't change system settings | Limited access mode | Click **Administrative access** (user must be in wheel/sudoers) |
| No "Virtual Machines"/"Podman" page | Add-on missing | `dnf install cockpit-machines` / `cockpit-podman` |
| "Add new host" missing | Host switcher disabled in RHEL 10 | Use per-host login or Cockpit Client |

## 8. Interview Questions

| Question | Answer |
|---|---|
| What port does Cockpit use? | 9090/tcp (HTTPS), via `cockpit.socket`. |
| Does Cockpit keep its own configuration database? | No; it uses system APIs, so changes are the same as CLI changes. |
| How do you manage several servers securely on RHEL 10? | One host per browser session, or the Cockpit Client; the host switcher is deprecated. |

## 9. Quick Revision

`````bash
systemctl enable --now cockpit.socket · https://HOST:9090 · non-root + Administrative access
cockpit-machines · cockpit-podman · cockpit-image-builder · /etc/cockpit/{cockpit.conf,ws-certs.d,disallowed-users}
RHEL 10: host switcher deprecated (AllowMultiHost=yes to re-enable, not recommended)
`````

## 10. Cross-References

- [Image Builder](image-builder.md)
- [KVM](kvm-virtualization.md)
- [Podman](podman-containers.md)
- [firewalld](../firewall-and-selinux/firewalld.md)
