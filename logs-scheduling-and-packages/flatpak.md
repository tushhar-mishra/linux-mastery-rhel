# Flatpak on RHEL 10

> **Sessions:** S58 · **Objectives:** *Configure access to Flatpak repositories* · *Install and remove Flatpak software packages* **[RHCSA Core]**
> **Related:** [RPM & DNF](rpm-and-dnf-package-management.md) · [RHEL 9 vs 10 (desktop apps moved to Flatpak)](../linux-fundamentals/rhel-9-vs-rhel-10.md)

## 1. Overview

**Flatpak** distributes **sandboxed desktop applications** that run the same way across distributions. On RHEL 10, desktop apps such as Firefox and Thunderbird are delivered as Flatpaks, which is why Flatpak is now an exam objective.

| | RPM/DNF | Flatpak |
|---|---|---|
| Scope | OS, libraries, services, server software | Mostly desktop applications |
| Dependencies | System libraries | Shared **runtimes** (e.g., GNOME, KDE, Freedesktop) |
| Isolation | None | Sandbox (bubblewrap) + portals |
| Install scope | System only | **System** or **per-user** (`--user`) |
| Sources | Repositories (`.repo`) | **Remotes** (`flatpak remote-add`) |

## 2. Key Concepts

| Term | Meaning |
|---|---|
| **Remote** | A Flatpak repository (OSTree or OCI registry), e.g. `flathub`, `rhel` |
| **Application ID** | Reverse-DNS name: `org.gimp.GIMP`, `org.mozilla.firefox` |
| **Runtime** | Shared platform the app runs on, installed automatically |
| **Ref / branch** | `app/org.gimp.GIMP/x86_64/stable`; select with `org.gimp.GIMP//stable` |
| **System installation** | `/var/lib/flatpak/` (root, for all users), the default |
| **User installation** | `~/.local/share/flatpak/` (`--user`, no root) |
| Sandbox / portals | `bwrap` isolates apps; `xdg-desktop-portal` brokers file/print access |

There's no `flatpak.service` daemon. The CLI starts a D-Bus–activated helper (`flatpak-system-helper`) on demand.

### Remotes on RHEL

| Remote | Source |
|---|---|
| **`rhel`** | Provided by the `redhat-flatpak-repo` package: `oci+https://flatpaks.redhat.io/rhel/`. Needs Red Hat registry credentials (`podman login registry.redhat.io`, saved to `~/.config/flatpak/oci-auth.json` or `/etc/flatpak/oci-auth.json`) |
| **Flathub** | Community catalog: `https://dl.flathub.org/repo/flathub.flatpakrepo` |
| Flathub Beta | `https://flathub.org/beta-repo/flathub-beta.flatpakrepo` |

GNOME and KDE nightly remotes exist for testing; their URLs change, so check the projects' docs.

## 3. Commands **[RHCSA Core]**

````bash
dnf install -y flatpak ; flatpak --version
````

### Remotes

````bash
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo     # system
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo  # per user
flatpak remotes -d                       # list with details (system + user)
flatpak remote-ls flathub --app | head   # what a remote offers
flatpak remote-modify --disable flathub-beta ; flatpak remote-modify --enable flathub-beta
flatpak remote-delete flathub-beta       # (--user for a user remote)
````

### Apps

````bash
flatpak search gimp                              # find the Application ID
flatpak install -y flathub org.gimp.GIMP         # system-wide (root/sudo)
flatpak install --user -y flathub org.gimp.GIMP  # current user only
flatpak install -y https://dl.flathub.org/repo/appstream/org.gimp.GIMP.flatpakref   # from a .flatpakref
flatpak run org.gimp.GIMP                        # needs a graphical session for GUI apps
flatpak list --app                               # installed apps (--runtime for runtimes)
flatpak info org.gimp.GIMP                       # version, origin remote, size
flatpak update -y                                # update apps and runtimes
flatpak uninstall -y org.gimp.GIMP               # remove the app
flatpak uninstall -y --unused                    # then remove runtimes nothing uses
flatpak uninstall --delete-data org.gimp.GIMP    # also delete ~/.var/app/<id> data [Advanced]
````

### Permissions **[Advanced]**

````bash
flatpak info --show-permissions org.videolan.VLC
flatpak override --user --filesystem=/home/user/Music org.videolan.VLC
flatpak override --user --reset org.videolan.VLC
````

## 4. RHCSA Exam Focus **[RHCSA Core]**

````bash
# "Configure access to the Flatpak repository at URL X named NAME"
flatpak remote-add --if-not-exists NAME URL      # (.flatpakrepo URL or as given)
flatpak remotes
# "Install application Y (system-wide)"
flatpak install -y NAME Y
flatpak list --app
# "Remove application Y"
flatpak uninstall -y Y
````

- Use **system** scope (no `--user`) unless the task says "for user X". Per-user installs must be done **as that user**.
- Verify with `flatpak remotes` and `flatpak list`. Desktop launchers appear under `/var/lib/flatpak/exports/share/applications/` (system) or `~/.local/share/flatpak/exports/share/applications/` (user).

## 5. Production Practices **[Production Practice]**

- Use the `rhel` remote for supported desktop apps on RHEL Workstation; add Flathub only if policy allows community software.
- Run `flatpak update` regularly; Flatpak updates aren't part of `dnf upgrade`.
- Watch disk usage in `/var/lib/flatpak` (runtimes are large); clean up with `uninstall --unused`.

## 6. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `No remote refs found similar to 'flathub'` | Remote missing in that scope (system vs user) | `flatpak remotes -d`; add it in the right scope |
| `rhel` remote: 401/unauthorized | Missing registry credentials | `podman login registry.redhat.io` → save `oci-auth.json` |
| `flatpak run` fails over SSH | No graphical session | Run from the desktop session |
| App can't see files | Sandbox | `flatpak override --filesystem=…` |
| Permission denied installing system-wide | Not root | `sudo`, or `--user` |
| Errors after an interrupted install | Repo inconsistency | `flatpak repair` (system) / `flatpak repair --user` |

## 7. Interview Questions

| Question | Answer |
|---|---|
| Why Flatpak on an enterprise distro? | Sandboxed, distro-independent desktop apps with their own runtimes; RHEL 10 ships Firefox/Thunderbird this way. |
| Remote vs repository? | Same idea: a remote is Flatpak's source of apps and runtimes. |
| System vs user install? | System: `/var/lib/flatpak`, root, for all users. User: `~/.local/share/flatpak`, no root. |
| How do you remove leftover runtimes? | `flatpak uninstall --unused`. |

## 8. Course Corrections

| Course | Correction |
|---|---|
| "RHEL Workstation may have the Fedora remote" | RHEL provides the `rhel` remote (`redhat-flatpak-repo`) |
| `flatpak export …` / install from the exported path | No such command; offline transfer: `flatpak create-usb` or `flatpak build-bundle` [Advanced] |
| `flatpak --default-system=true` / `--default-user=true` | Not real options; system scope is the default, `--user` selects user scope |
| Q14: `flatpak uninstall --unused` removes VLC and its deps | Uninstall VLC first, then `--unused` |
| Flathub URL `https://flathub.org/repo/flathub.flatpakrepo` | Canonical: `https://dl.flathub.org/repo/flathub.flatpakrepo` |

## 9. Quick Revision

````bash
flatpak remote-add [--user] --if-not-exists NAME URL · remotes -d · remote-ls NAME · remote-modify --disable · remote-delete
flatpak search X · install [--user] -y REMOTE APPID · run APPID · list --app|--runtime · info · update -y
flatpak uninstall -y APPID ; flatpak uninstall -y --unused · override [--reset] · repair
system: /var/lib/flatpak · user: ~/.local/share/flatpak · rhel remote: oci+https://flatpaks.redhat.io/rhel/
