# 031 · Installing Software: rpm, dnf, Repositories (and apt on Ubuntu)

> **You need first:** [030 · Central identity](030-central-identity-nss-and-sssd.md)
> **Next:** [032 · Flatpak and snap](032-flatpak-and-snap.md)

---

## What it is

- A **package** is a single file containing a program (or library, or config), plus **metadata**: its name, version, what it needs (its **dependencies**), and scripts to run on install/remove. On RHEL these are **RPM** files (originally "Red Hat Package Manager"); on Debian/Ubuntu they're **DEB** files.
- A **repository** (repo) is a server or folder full of packages plus an index of them.
- **Dependencies** are other packages a package needs. `httpd` needs `apr`, `apr-util` and others.

Two layers of tools:

| Layer | RHEL | Ubuntu/Debian | Resolves dependencies? | Uses repos? |
|---|---|---|---|---|
| Low-level | `rpm` | `dpkg` | No | No |
| High-level | **`dnf`** (`yum` is now just a link to it) | **`apt`** | Yes | Yes |

RHEL 10 content comes from two main repos: **BaseOS** (the core operating system) and **AppStream** (applications, languages, databases). RHEL 10 has **no "modularity"** (the old `dnf module` streams are gone).

## Why it exists

Installing software by hand ("download, compile, copy files around") doesn't scale and can't be tracked. Package managers:
- **Resolve dependencies** automatically.
- **Track every file**, so you can verify, update or cleanly remove software.
- **Verify signatures**, so you know a package really came from Red Hat or Canonical and wasn't tampered with.
- **Patch** the whole system with one command, which is the core of keeping servers secure.

## Analogy

A repository is a **supermarket**, and `dnf`/`apt` is a **personal shopper**. You say "I want to bake a cake (install httpd)". The shopper knows the recipe needs flour, eggs and sugar (dependencies), fetches all of them, checks every seal is unbroken (signature check), and keeps a receipt (the package database), so it can later return exactly those items. `rpm`/`dpkg` is buying one item yourself: fine, but you have to know the rest of the recipe.

## How it works inside

### Package names

```
openssh-server-9.9p1-7.el10_0.x86_64.rpm
│              │     │         └─ architecture (x86_64, aarch64, noarch = any)
│              │     └─ release (Red Hat's build number + el10 = Enterprise Linux 10)
│              └─ upstream version
└─ name
```
An optional **epoch** (`1:`) can appear before the version to force ordering.

### What `dnf install httpd` does

1. Reads the `.repo` files in `/etc/yum.repos.d/`.
2. Downloads each repo's **metadata** (`repodata/repomd.xml` and friends: the index of all packages and their dependencies) into the cache `/var/cache/dnf/`, if it's older than `metadata_expire`.
3. Runs a **solver**: works out every package needed to satisfy `httpd` and its dependencies at compatible versions.
4. Shows you the **transaction** (what will be installed, upgraded or removed) and asks for confirmation.
5. Downloads the RPMs and **checks each GPG signature** against the trusted keys.
   - **GPG** (GNU Privacy Guard) signing works like this: the vendor signs each package with a secret key, and your system checks it with the vendor's public key. Topic 064 explains the cryptography.
6. Hands them to the **rpm** library, which, for each package: runs pre-install scripts → writes the files → updates the **RPM database** (`/usr/lib/sysimage/rpm/rpmdb.sqlite`) → runs post-install scripts.
7. Records the transaction in `dnf history` and `/var/log/dnf.log`.

`apt` does the same with `/etc/apt/sources.list.d/`, `/var/lib/apt/lists/`, and the dpkg database in `/var/lib/dpkg/`. The big habit difference: **apt does not refresh metadata automatically; you must run `apt update` first.**

### Getting RHEL content

A RHEL machine must be **registered** to download from Red Hat's CDN (Content Delivery Network). AlmaLinux and Rocky come with public mirrors already configured. Ubuntu uses public mirrors.

## Commands

### Registering RHEL

```bash
sudo subscription-manager register              # Red Hat login (or --org / --activationkey)
sudo subscription-manager repos --list-enabled
```
```
+----------------------------------------------------------+
    Available Repositories in /etc/yum.repos.d/redhat.repo
+----------------------------------------------------------+
Repo ID:   rhel-10-for-x86_64-baseos-rpms
Repo Name: Red Hat Enterprise Linux 10 for x86_64 - BaseOS (RPMs)
...
Repo ID:   rhel-10-for-x86_64-appstream-rpms
```

```bash
sudo subscription-manager repos --enable codeready-builder-for-rhel-10-x86_64-rpms   # extra developer repo
```

### Repositories

```bash
dnf repolist
```
```
repo id                                 repo name
rhel-10-for-x86_64-appstream-rpms       Red Hat Enterprise Linux 10 for x86_64 - AppStream (RPMs)
rhel-10-for-x86_64-baseos-rpms          Red Hat Enterprise Linux 10 for x86_64 - BaseOS (RPMs)
```
- `dnf repolist all` also shows disabled repos; `-v` shows URLs and package counts.

A `.repo` file (`/etc/yum.repos.d/internal.repo`):
```ini
[internal-appstream]
name=Internal AppStream mirror
baseurl=http://repo.example.com/rhel10/AppStream
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
```

| Key | Meaning |
|---|---|
| `[id]` | Unique repo ID, no spaces |
| `baseurl=` | `http(s)://`, `ftp://` or `file:///` path to the folder that **contains `repodata/`** |
| `enabled=` | 1 on / 0 off |
| `gpgcheck=` / `gpgkey=` | Verify signatures / where the public key is |
| `metadata_expire=` | How often to refresh the index (`-1` = never, good for a DVD) |

```bash
sudo dnf config-manager --add-repo http://repo.example.com/rhel10/BaseOS   # generate a .repo file
sudo rpm --import http://repo.example.com/RPM-GPG-KEY-example              # trust a key
sudo dnf config-manager --set-disabled internal-appstream
sudo dnf install htop --enablerepo=epel                                     # enable a repo for one command
```

**EPEL** (Extra Packages for Enterprise Linux) is a popular community repo of extra packages for RHEL (`dnf install epel-release` on Alma/Rocky).

### An offline repo from the install DVD/ISO

The DVD ISO contains the BaseOS and AppStream repos. **Mounting** (topic 048) makes the ISO's contents appear under a directory:

```bash
sudo mkdir -p /mnt/iso
sudo mount -o ro /dev/sr0 /mnt/iso                 # the VM's DVD drive; for an ISO file: mount -o loop,ro file.iso /mnt/iso
sudo tee /etc/yum.repos.d/dvd.repo <<'EOF'
[dvd-baseos]
name=DVD BaseOS
baseurl=file:///mnt/iso/BaseOS
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
metadata_expire=-1

[dvd-appstream]
name=DVD AppStream
baseurl=file:///mnt/iso/AppStream
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
metadata_expire=-1
EOF
sudo dnf clean all ; dnf repolist
```
To keep it after a reboot, add `/dev/sr0  /mnt/iso  iso9660  ro,nofail  0 0` to `/etc/fstab` (topic 048).

### dnf

| Task | Command |
|---|---|
| Search names and summaries | `dnf search nginx` |
| Details | `dnf info nginx` |
| Which package provides a file or command | `dnf provides semanage` (or a full path) |
| List | `dnf list --installed` · `dnf list --available` · `dnf list 'openssh*'` |
| Install | `sudo dnf install -y nginx` |
| Install a local RPM file (dependencies from repos) | `sudo dnf install ./app-1.0.rpm` |
| Remove | `sudo dnf remove nginx` · `sudo dnf autoremove` (unused dependencies) |
| Updates | `dnf check-update` · `sudo dnf upgrade` · `sudo dnf upgrade openssh` |
| Security updates only | `dnf updateinfo list --security` · `sudo dnf upgrade --security` |
| Groups of packages | `dnf group list` · `sudo dnf group install "Development Tools"` |
| History and undo | `dnf history` · `dnf history info 7` · `sudo dnf history undo 7` |
| Files in a package (before installing) | `dnf repoquery -l nginx` |
| Cache | `sudo dnf clean all` · `sudo dnf makecache` |

```bash
dnf provides semanage
```
```
policycoreutils-python-utils-3.11-1.el10.noarch : SELinux policy core python utilities
Repo        : appstream
Matched from:
Filename    : /usr/sbin/semanage
```
- The fix for "command not found" when you don't know the package name. A bare command name is searched in the usual bin directories.
- For a full path, give it exactly (`dnf provides /usr/sbin/semanage`). Careful with wildcards: `'*/bin/semanage'` finds **nothing**, because the file is in `/usr/sbin` and `/bin/` doesn't appear in that path; `'*/semanage'` matches too much (headers, man pages).

```bash
sudo dnf install -y nginx
```
```
Dependencies resolved.
================================================================================
 Package             Arch     Version              Repository              Size
================================================================================
Installing:
 nginx               x86_64   2:1.26.3-1.el10      rhel-10-...-appstream   33 k
Installing dependencies:
 nginx-core          x86_64   2:1.26.3-1.el10      rhel-10-...-appstream  670 k
 nginx-filesystem    noarch   2:1.26.3-1.el10      rhel-10-...-appstream   12 k
...
Transaction Summary
================================================================================
Install  4 Packages
...
Complete!
```
- The "Installing dependencies" section is the solver at work. `2:` is the epoch.

```bash
dnf history
```
```
ID | Command line            | Date and time    | Action(s)      | Altered
---------------------------------------------------------------------------
 8 | install -y nginx        | 2026-11-16 14:02 | Install        |    4
 7 | upgrade                 | 2026-11-15 22:10 | Upgrade        |   37
```
- `dnf history undo 8` removes exactly what transaction 8 installed.

**`/etc/dnf/dnf.conf`** important settings: `gpgcheck=1`; `installonly_limit=3` (how many kernels to keep); `clean_requirements_on_remove=True`; `best=True`; `skip_if_unavailable=False`. Log: `/var/log/dnf.log`.

### rpm (querying and verifying)

| Task | Command |
|---|---|
| All installed packages | `rpm -qa` (`rpm -qa \| grep ssh`) |
| Is it installed? / info | `rpm -q openssh-server` · `rpm -qi openssh-server` |
| Files / config files / docs | `rpm -ql pkg` · `rpm -qc pkg` · `rpm -qd pkg` |
| Which package owns this file | `rpm -qf /usr/sbin/sshd` |
| Look inside a `.rpm` file before installing | `rpm -qpi file.rpm` · `rpm -qpl file.rpm` |
| Dependencies | `rpm -qR pkg` |
| Install scripts | `rpm -q --scripts pkg` |
| Recent changes | `rpm -q --changelog pkg \| head` |
| Verify files against the database | `rpm -V pkg` · `rpm -Va` |
| Check a file's signature | `rpm -K file.rpm` |
| Remove by name | `rpm -e pkg` |

```bash
rpm -qc openssh-server
```
```
/etc/pam.d/sshd
/etc/ssh/sshd_config
/etc/ssh/sshd_config.d/40-redhat-crypto-policies.conf
/etc/ssh/sshd_config.d/50-redhat.conf
/etc/sysconfig/sshd
```

```bash
sudo rpm -V openssh-server
```
```
S.5....T.  c /etc/ssh/sshd_config
```
- `rpm -V` lists files that differ from what was installed. Each letter means a change: `S` size, `5` content checksum, `T` modification time, `M` mode (permissions), `U` user, `G` group, `L` link. `c` = a config file, so this edit is expected. An unexpected `5` on `/usr/bin/ls` would be **very** suspicious (tampering).

`rpm -i`/`-U` install files **without** resolving dependencies. Prefer `dnf install ./file.rpm`.

### Ubuntu/Debian equivalents

| Task | RHEL | Ubuntu/Debian |
|---|---|---|
| Refresh repo metadata | automatic (`dnf makecache`) | **`sudo apt update`** (required first) |
| Install / remove | `dnf install` / `dnf remove` | `apt install` / `apt remove` (`purge` also removes configs) |
| Upgrade everything | `dnf upgrade` | `apt upgrade` (`full-upgrade` allows removals) |
| Search / info | `dnf search` / `dnf info` | `apt search` / `apt show` |
| File owner | `rpm -qf FILE` | `dpkg -S FILE` |
| Files in a package | `rpm -ql PKG` | `dpkg -L PKG` |
| Install a local file | `dnf install ./x.rpm` | `apt install ./x.deb` |
| List installed | `rpm -qa` | `dpkg -l` / `apt list --installed` |
| Repo config | `/etc/yum.repos.d/*.repo` | `/etc/apt/sources.list.d/*.list` or `*.sources` |
| Hold a version | `dnf versionlock add PKG` (plugin) | `apt-mark hold PKG` |
| Logs | `/var/log/dnf.log`, `dnf history` | `/var/log/apt/history.log`, `/var/log/dpkg.log` |

### Try it
1. `dnf provides htop` (or enable EPEL), install it, then find its files with `rpm -ql`.
2. Edit `/etc/ssh/sshd_config` (add a comment), then run `rpm -V openssh-server` and read the codes.
3. Install a package, then undo it with `dnf history undo`.
4. Build the offline DVD repo, disable the network repos with `--disablerepo='*' --enablerepo='dvd-*'`, and install `zsh`.

**Check your work:** on your lab VM, from the notes folder, run `sudo ./checks/check 031` for every step, or `sudo ./checks/check 031 STEP` for one (topic 002 shows how to get the notes there).

## Where you'll use it

- **Patching:** `dnf upgrade --security` on a schedule, tested in staging first. In large fleets this is driven by Ansible (topic 105) or Red Hat Satellite.
- **Golden images and Dockerfiles:** `RUN dnf -y install nginx && dnf clean all` (clean the cache to keep images small). Ubuntu images: `apt-get update && apt-get install -y … && rm -rf /var/lib/apt/lists/*`.
- **Security investigations:** `rpm -Va` shows modified system binaries.
- **"command not found":** `dnf provides`.
- **Air-gapped (offline) environments:** local or internal mirror repos (`baseurl=file:///` or an internal HTTP server).
- **Pinning versions:** `dnf versionlock` for things like database or Kubernetes packages that must not auto-upgrade.

## When it breaks

| Message / symptom | Cause | Fix |
|---|---|---|
| `There are no enabled repositories` | Not registered, or no `.repo` files | Register, or add `.repo` files |
| `Cannot download repomd.xml` / `Curl error` | Wrong `baseurl` (must contain `repodata/`), network, DNS or proxy | `curl -I <baseurl>/repodata/repomd.xml`; fix the URL or proxy |
| `GPG check FAILED` / `public key … is not installed` | The signing key isn't trusted | `rpm --import KEY`; set the right `gpgkey=` |
| `error: Failed dependencies` | You used `rpm -i` | `dnf install ./file.rpm` |
| `No match for argument: X` | Wrong name, or the repo is disabled | `dnf search`, `dnf provides`, `dnf repolist all` |
| Old results after changing repos | Cached metadata | `dnf clean all; dnf makecache` |
| `/boot` full during a kernel update | Too many kernels | Lower `installonly_limit`; remove old kernels (topic 054) |
| Ubuntu: `Unable to locate package` | You didn't run `apt update`, or the repo component isn't enabled | `sudo apt update` |
| Ubuntu: `Could not get lock /var/lib/dpkg/lock-frontend` | Another apt (often automatic updates) is running | Wait for it; don't delete the lock while apt is running |

## Quick recap

- Packages = files + metadata + dependencies + signatures. Repos = servers of packages with an index.
- `rpm`/`dpkg` handle single files (no dependency resolution); `dnf`/`apt` use repos and resolve dependencies.
- `.repo` files: `[id] name baseurl enabled gpgcheck gpgkey`. Verify with `dnf repolist`.
- Key commands: `dnf search/info/provides/install/remove/upgrade/history`, `rpm -qa/-qf/-ql/-qc/-V`. On Ubuntu: `apt update` first.

**Interview questions**

1. *rpm vs dnf?* rpm installs, queries and verifies single package files but doesn't resolve dependencies. dnf works with repositories, resolves dependencies, verifies signatures and keeps a transaction history.
2. *How do you find which package provides a command?* `dnf provides cmd` (or the full path, e.g. `dnf provides /usr/sbin/semanage`) (or `rpm -qf $(command -v cmd)` if it's already installed; `dpkg -S` on Ubuntu).
3. *How do you undo a bad update?* `dnf history` to find the transaction, then `dnf history undo <id>`. For big changes, prefer a VM or LVM snapshot taken beforehand.

**Scenario question** (answer out loud first, then compare)

> *"`dnf update` on a production server fails with a dependency conflict halfway through your maintenance window. What do you do?"*

**Model answer:**
1. Read the message: which package needs what, and from which repo. Often a third-party repo (EPEL, a vendor repo) has a newer or conflicting package.
2. `dnf repolist` and `dnf list --showduplicates pkg` show where versions come from.
3. Options, safest first:
   - update everything else and exclude the problem package (`--exclude=pkg`);
   - temporarily disable the offending repo (`--disablerepo=epel`);
   - wait for the vendor's fix.
4. **Never** force it with `rpm -Uvh --nodeps`; that leaves an inconsistent system.
5. If something already broke, `dnf history` shows the transaction and `dnf history undo N` reverses it (or roll back to the snapshot you took first).
6. Afterwards: check services, `needs-restarting -r` for a reboot, and note the issue for the next window.

**Likely follow-ups:**
- *How do you find which package owns a file?* `rpm -qf /path` (Ubuntu: `dpkg -S`).
- *How do you check whether someone changed packaged files?* `rpm -V pkg` (or `rpm -Va`): codes like `S.5....T. c` show size, checksum and time changes on config files.
