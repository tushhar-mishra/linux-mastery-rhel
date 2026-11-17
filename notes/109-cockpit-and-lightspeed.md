# 109 · Cockpit Web Console and RHEL Lightspeed

> **You need first:** [108 · Image Builder](108-image-builder.md)
> **Next:** [110 · Production scenarios](110-production-scenarios.md)

---

## What it is

Two convenience tools that sit on top of everything you've learned:

| Tool | What it is |
|---|---|
| **Cockpit** | A browser-based admin interface on **HTTPS port 9090**. It uses the system's own APIs (systemd, NetworkManager, udisks/storaged, journald, firewalld), so a change made in Cockpit is visible in the CLI, and vice versa |
| **Command Line Assistant** (powered by **RHEL Lightspeed**) | An AI helper in the terminal (`c "question"`). It answers natural-language questions using Red Hat documentation and knowledge-base content, and explains errors and logs you pipe into it |

Cockpit also runs on Ubuntu/Debian (`apt install cockpit`). Lightspeed is RHEL-only (RHEL 9.6+ and 10, with a registered system). Rebuilds such as AlmaLinux don't ship `command-line-assistant` at all (`dnf` says "No matching Packages").

## Why it exists

- **Cockpit:**
  - gives a quick visual overview: health, logs, storage, networking, services, SELinux, updates;
  - a browser terminal;
  - add-ons for VMs (topic 100), Podman containers (topic 101) and Image Builder (topic 108).

  Useful for occasional admins, for teaching, and for tasks where a picture helps (storage layouts, performance graphs). It is a convenience layer, **not** a replacement for the CLI.
- **Lightspeed:** speeds up "how do I…?" and "what does this error mean?" without leaving the terminal.

## Analogy

Cockpit is the **car's dashboard and touchscreen**: it shows you the same engine (the system APIs) that the mechanic's tools (CLI) work on, so both always agree. Lightspeed is a **knowledgeable passenger with the manual**: helpful, but you're still the driver, so check what it tells you before acting.

## How it works inside

- **Cockpit:**
  - `cockpit.socket` listens on 9090 and starts `cockpit-ws` (the web server) on demand.
  - You log in with a **normal Linux account** (PAM, topic 029). A `cockpit-bridge` process runs **as that user** and talks to the system over D-Bus and commands.
  - Clicking **Administrative access** uses **sudo** (topic 028) to run the bridge with privileges.
  - `root` is in `/etc/cockpit/disallowed-users` by default.
  - Cockpit keeps no database of its own, so nothing gets out of sync.
- **Lightspeed:** the `c` client sends your question, plus anything you pipe or attach, to Red Hat's service over HTTPS. The system must be registered. It does **not** inspect the system by itself and doesn't run commands for you.

## Commands

### Cockpit

```bash
sudo dnf install -y cockpit                 # often preinstalled on Server installs
sudo systemctl enable --now cockpit.socket
sudo firewall-cmd --list-services           # 'cockpit' is allowed in the public zone by default
```
```
cockpit dhcpv6-client ssh
```
Browse to `https://server1:9090`, accept the self-signed certificate (lab), log in as a **regular user**, then click **Administrative access**.

| Page | Use |
|---|---|
| Overview | Health, CPU/memory graphs, uptime, hostname, tuned profile, crypto policy |
| Logs | The journal with priority, time and unit filters |
| Storage | Disks, partitions, LVM, RAID, LUKS, NFS mounts, Stratis |
| Networking | Interfaces, bonds, bridges, VLANs, firewall zones |
| Accounts | Users, groups, passwords, admin rights, SSH keys |
| Services | systemd units and timers |
| SELinux, Software updates, Kernel dump, Diagnostic reports | As named |
| Terminal | A shell in the browser |

| Add-on | Adds |
|---|---|
| `cockpit-machines` | Virtual machines (KVM) |
| `cockpit-podman` | Podman containers |
| `cockpit-image-builder` | Image Builder |

**Production practice:**
- Put a trusted certificate in `/etc/cockpit/ws-certs.d/` (`name.crt` + `name.key`), then `systemctl restart cockpit`.
- Restrict port 9090 to admin networks with a source-based firewalld zone or a rich rule (topic 071).
- Settings such as `IdleTimeout` and `LoginTitle` go in `/etc/cockpit/cockpit.conf`.
- RHEL 10 deprecates and disables the multi-host **host switcher**. Use one browser session per host, or the Cockpit Client Flatpak.

**Example: add a data partition in the GUI.** Storage → the disk → Create partition → size, XFS, mount point `/data`, "mount at boot". Then verify in a terminal: `lsblk -f; findmnt /data; grep /data /etc/fstab`. Cockpit wrote a normal UUID-based fstab line.

### Command Line Assistant (Lightspeed)

```bash
sudo dnf install -y command-line-assistant
c "How do I set the timezone to Europe/London on RHEL 10?"
```
```
To set the timezone, run:
    sudo timedatectl set-timezone Europe/London
Verify with:
    timedatectl
```
```bash
journalctl -u httpd -b --no-pager | c "Why is httpd failing to start?"
sudo ausearch -m avc -ts recent | c "Explain these SELinux denials"
c --help                                     # options (attachments, history) vary by version
```
- **Verify** every suggestion (read it, understand it, test on non-production). AI answers can be wrong or incomplete.
- Whatever you pipe or attach is **sent to Red Hat**: strip secrets, keys, passwords and personal data first.
- Keep your offline skills sharp: `man -k`, `man 5 FILE`, `/usr/share/doc`, `--help` (topic 005).

### Try it
1. Enable Cockpit on a lab VM, log in as your user, and get administrative access.
2. Create an LV and filesystem through the Storage page, then confirm it with `lvs`, `findmnt` and `/etc/fstab`.
3. Stop a service in Cockpit and watch `systemctl status` in a terminal at the same time.
4. Restrict 9090 to your lab subnet with a firewalld rich rule, and test from another address.

## Where you'll use it

- **Cockpit:**
  - small teams and single servers;
  - quick visual checks during incidents (logs, graphs);
  - managing KVM VMs on a lab host;
  - teaching juniors (who can see the equivalent CLI state).

  Fleets and Kubernetes are managed with automation and dedicated consoles instead.
- **Lightspeed:** drafting commands and explaining errors on registered RHEL hosts. Like any AI assistant, treat it as a starting point, not an authority.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| Browser can't reach :9090 | Socket not enabled, or firewall | `systemctl enable --now cockpit.socket`; allow the `cockpit` service |
| "Permission denied" logging in as root | `disallowed-users` | Log in as a normal user + Administrative access |
| Can't change system settings | Limited access mode, or user not in sudoers | Click Administrative access; add the user to `wheel` |
| No "Virtual machines" / "Podman" page | Add-on missing | `dnf install cockpit-machines` / `cockpit-podman` |
| "Add new host" is missing | The host switcher is disabled in RHEL 10 | Per-host login or Cockpit Client |
| `c: command not found` | Package missing or older RHEL | Install `command-line-assistant` (RHEL 9.6+/10) |
| Lightspeed auth or connection errors | System not registered, or proxy | `subscription-manager register`; configure the proxy |

## Quick recap

- Cockpit: `systemctl enable --now cockpit.socket` → `https://HOST:9090`; normal user + Administrative access (sudo); add-ons for VMs, Podman, Image Builder. It uses system APIs, so the GUI and CLI always agree.
- Secure it: a real certificate in `/etc/cockpit/ws-certs.d/`, restrict 9090, central accounts. The RHEL 10 host switcher is deprecated.
- Lightspeed: `c "question"`, pipe logs into it. Verify answers and never send secrets.

**Interview questions**

1. *What port does Cockpit use, and how is it started?* HTTPS on 9090/tcp, socket-activated by `cockpit.socket`.
2. *Does Cockpit keep its own configuration?* No. It drives the system's own APIs and tools (systemd, NetworkManager, storaged, firewalld), so changes are identical to CLI changes and visible both ways.
3. *What are the risks of using an AI command assistant on servers?* Suggestions can be wrong or unsafe, so verify and test them, and anything you send leaves the machine, so remove secrets and personal data first.
