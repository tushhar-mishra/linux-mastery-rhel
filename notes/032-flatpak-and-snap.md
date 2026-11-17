# 032 · Flatpak (and snap): Sandboxed App Packages

> **You need first:** [031 · Packages: rpm, dnf and apt](031-packages-rpm-dnf-and-apt.md)
> **Next:** [033 · Processes and signals](033-processes-and-signals.md)

---

## What it is

**Flatpak** is a second packaging system, mainly for **desktop applications**. Each app carries its own libraries (through shared **runtimes**) and runs in a **sandbox**: a restricted environment that limits which of your files and devices it can touch. The same Flatpak runs on RHEL, Fedora, Ubuntu and others.

On **RHEL 10**, desktop apps such as Firefox and Thunderbird are no longer RPMs; they are delivered as Flatpaks.

**snap** is Canonical's (Ubuntu's) similar format. Ubuntu delivers Firefox and some server tools (like `lxd`) as snaps.

| | RPM/DNF (or DEB/apt) | Flatpak | snap |
|---|---|---|---|
| Used for | The OS, libraries, services, servers | Desktop apps | Desktop apps and some server tools (Ubuntu) |
| Dependencies | Shared system libraries | Shared **runtimes** (GNOME, KDE, Freedesktop) | Bundled "base" snaps |
| Isolation | None | Sandbox (bubblewrap) | Sandbox (AppArmor + confinement) |
| Install scope | System only | **System** or **per user** | System |
| Sources | Repositories | **Remotes** | The Snap Store |
| Auto-updates | No (you run `dnf upgrade`) | No (you run `flatpak update`) | Yes, by the `snapd` service |

## Why it exists

Desktop apps (browsers, editors) change fast and need new libraries that an enterprise distro, which keeps libraries stable for 10 years, doesn't want to upgrade. Shipping the app with its own runtime solves that, and the sandbox limits the damage a compromised app can do.

**For servers**, this rarely matters: server software comes from RPM/DEB packages or **containers** (topic 101). It's worth knowing because it's on every RHEL 10 workstation, and "why isn't Firefox in `dnf`?" is a real question.

## Analogy

An RPM app **moves into your house** and uses your kitchen and furniture (system libraries). A Flatpak app **arrives in its own camper van** (runtime), parks in your driveway, and only gets the keys to the rooms you allow (sandbox permissions).

## How it works inside

| Term | Meaning |
|---|---|
| **Remote** | A Flatpak source (like a repository): `flathub`, or `rhel` on RHEL |
| **Application ID** | A reverse-domain name: `org.mozilla.firefox`, `org.gimp.GIMP` |
| **Runtime** | The shared base the app runs on; installed automatically and shared between apps |
| **Ref** | Full name: `app/org.gimp.GIMP/x86_64/stable` |
| **System install** | In `/var/lib/flatpak/`, for all users (needs root) |
| **User install** | In `~/.local/share/flatpak/` (`--user`, no root) |
| **Sandbox** | Built with `bwrap` (bubblewrap), which uses kernel **namespaces** (topic 097) to give the app its own private view of the filesystem |
| **Portals** | Helper services (`xdg-desktop-portal`) that let a sandboxed app ask for a file, printer or screen share through a dialog the user controls |

Flatpak stores apps using **OSTree** (a Git-like store for files that de-duplicates identical files) or pulls them as **OCI** container images. OCI (Open Container Initiative) is the standard container image format. There's no always-running Flatpak daemon; a helper starts when needed.

**Remotes on RHEL:**

| Remote | Source |
|---|---|
| `rhel` | From the `redhat-flatpak-repo` package: `oci+https://flatpaks.redhat.io/rhel/`. Needs Red Hat registry credentials (`podman login registry.redhat.io`) |
| `flathub` | The big community catalog: `https://dl.flathub.org/repo/flathub.flatpakrepo` |

## Commands

```bash
sudo dnf install -y flatpak ; flatpak --version
```

### Remotes

```bash
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak remotes -d
```
```
Name    Title   URL                             Collection ID Subset Filter Priority Options
flathub Flathub https://dl.flathub.org/repo/    -             -      -      1        system
rhel    RHEL    oci+https://flatpaks.redhat.io… -             -      -      1        system,oci
```
- `-d` = details. The `Options` column shows whether each remote is **system** or **user** scope.

```bash
flatpak remote-ls flathub --app | head -3
flatpak remote-modify --disable flathub
flatpak remote-delete flathub
```

### Apps

```bash
flatpak search gimp
```
```
Name                           Description                               Application ID     Version Branch Remotes
GIMP User Manual               GIMP User Manual                          org.gimp.GIMP.Manual 2.10  2.10   flathub
GNU Image Manipulation Program High-end image creation and manipulation  org.gimp.GIMP      3.2.8   stable flathub
...
```
- Search uses each remote's app catalogue ("appstream" data). Right after `remote-add` it may not be downloaded yet, and search says **`No matches found`**. Fetch it with `sudo flatpak update --appstream`, then search again.

```bash
sudo flatpak install -y flathub org.gimp.GIMP        # system-wide
flatpak install --user -y flathub org.gimp.GIMP      # just for you
flatpak run org.gimp.GIMP                            # needs a graphical session
flatpak list --app
```
```
Name   Application ID   Version  Branch Installation
GIMP   org.gimp.GIMP    3.2.8    stable system
```

```bash
flatpak info org.gimp.GIMP              # version, origin, size, runtime
flatpak update -y                       # update apps and runtimes (not done by dnf upgrade!)
sudo flatpak uninstall -y org.gimp.GIMP
sudo flatpak uninstall -y --unused      # remove runtimes nothing uses any more
flatpak uninstall --delete-data org.gimp.GIMP   # also delete ~/.var/app/<id> (the app's saved data)
```

### Permissions

```bash
flatpak info --show-permissions org.videolan.VLC
flatpak override --user --filesystem=$HOME/Music org.videolan.VLC   # allow access to a folder
flatpak override --user --reset org.videolan.VLC
```

### snap on Ubuntu

```bash
snap list
sudo snap install htop
sudo snap refresh            # update (also happens automatically)
sudo snap remove htop
snap info htop
```
Snaps are mounted as compressed **squashfs** images under `/snap/`, which is why `df` on Ubuntu shows many `/dev/loopN` entries.

### Try it
1. On a RHEL 10 desktop VM, run `flatpak list` and find Firefox.
2. Add Flathub as a **user** remote and install a small app with `--user`. See where it landed (`~/.local/share/flatpak`).
3. Uninstall it, then run `flatpak uninstall --unused`.
4. On Ubuntu, run `snap list` and `df -h | grep loop`.

**Check your work:** on your lab VM, from the notes folder, run `sudo ./checks/check 032` for every step, or `sudo ./checks/check 032 STEP` for one (topic 002 shows how to get the notes there).

## Where you'll use it

- **RHEL workstations** for developers and admins (browser, editors).
- **Disk cleanup:** runtimes in `/var/lib/flatpak` are large; `flatpak uninstall --unused`.
- **Ubuntu servers:** knowing that some tools (like `lxd`, `microk8s`) are snaps, and that snaps auto-refresh, which can surprise you during change freezes.
- **Concept link:** the sandbox uses the same kernel namespaces as containers (topic 097).

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `flatpak search` finds nothing right after adding a remote | The app catalogue (appstream data) hasn't been downloaded yet | `sudo flatpak update --appstream` |
| `No remote refs found similar to 'flathub'` | The remote exists in the other scope (system vs user) | `flatpak remotes -d`; add it in the right scope |
| `rhel` remote: 401 unauthorized | Missing Red Hat registry credentials | `podman login registry.redhat.io` |
| `flatpak run` fails over SSH | No graphical session | Run it from the desktop |
| The app can't see your files | Sandbox | `flatpak override --filesystem=…`, or use the file-picker portal |
| Permission denied installing system-wide | Not root | `sudo`, or `--user` |
| Errors after an interrupted install | Store inconsistency | `flatpak repair` (or `flatpak repair --user`) |
| Ubuntu: lots of `/dev/loop` mounts | Each snap is a mounted image | Normal |

## Quick recap

- Flatpak = sandboxed desktop apps with shared runtimes, from **remotes** (Flathub, `rhel`). RHEL 10 ships Firefox this way. snap is Ubuntu's equivalent.
- System (`/var/lib/flatpak`, root) vs user (`~/.local/share/flatpak`, `--user`) installs.
- `remote-add`, `search`, `install`, `run`, `list`, `update`, `uninstall`, `uninstall --unused`.
- `dnf upgrade` doesn't update Flatpaks; run `flatpak update`.

**Interview questions**

1. *Why would an enterprise distro ship apps as Flatpaks?* Fast-moving desktop apps can bring their own runtimes without changing the stable system libraries, and they run sandboxed.
2. *System vs user Flatpak install?* System installs go to `/var/lib/flatpak` for all users and need root. User installs go to `~/.local/share/flatpak` and need no root.
3. *How does Flatpak sandbox apps?* bubblewrap uses kernel namespaces to give the app a private view of the system; portals give controlled access to files and devices.

**Scenario question** (answer out loud first, then compare)

> *"A user on a RHEL 10 desktop says Firefox didn't update after you ran `dnf upgrade`. Explain why, and how you manage it."*

**Model answer:**
1. On RHEL 10, Firefox ships as a **Flatpak**, not an RPM, so `dnf` doesn't manage it.
2. `flatpak list` shows it, with its origin (the `rhel` remote).
3. Update with `flatpak update` (system installs need root; `--user` installs are updated by the user).
4. Patch processes and compliance reports must include Flatpak (and snap on Ubuntu), not just the package manager.

**Likely follow-ups:**
- *Where are system and user Flatpaks stored?* `/var/lib/flatpak` and `~/.local/share/flatpak`.
- *What does `flatpak uninstall --unused` do?* Removes runtimes no remaining app needs.
