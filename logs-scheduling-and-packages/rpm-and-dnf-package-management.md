# RPM & DNF Package Management

> **Sessions:** S57 · **Objectives:** *Configure access to RPM repositories* · *Install and remove RPM software packages* · *Install and update software packages from Red Hat CDN, a remote repository, or from the local file system* **[RHCSA Core]**
> **Related:** [Flatpak](flatpak.md) · [RPM package building](rpm-package-building.md) · [Lab setup (local DVD repo)](../linux-fundamentals/virtualization-and-lab-setup.md) · [GRUB2 & kernel packages](../boot-systemd-and-kernel/grub2-and-kernel-management.md)

## 1. Overview

RHEL software ships as **RPM packages** from **repositories**. Two layers:

| Layer | Tool | Dependencies | Repos |
|---|---|---|---|
| Low-level | `rpm` | **Not** resolved | No |
| High-level | **`dnf`** (`yum` is a symlink to it) | Resolved automatically | Yes |

RHEL 10 content comes from two main repositories: **BaseOS** (core OS) and **AppStream** (applications, languages, databases). **There's no modularity on RHEL 10** (`dnf module` streams are gone).

**Package name anatomy:** `openssh-server-9.9p1-7.el10_0.x86_64.rpm` → name `openssh-server`, version `9.9p1`, release `7.el10_0`, arch `x86_64` (`noarch` = architecture-independent). An optional epoch appears as `1:zsh-…`.

## 2. Repositories **[RHCSA Core]**

### 2.1 Red Hat CDN (subscription)

```bash
subscription-manager register                 # Customer Portal credentials (or --org/--activationkey)
subscription-manager status
subscription-manager repos --list-enabled     # rhel-10-for-x86_64-baseos-rpms / …-appstream-rpms
subscription-manager repos --enable codeready-builder-for-rhel-10-x86_64-rpms   # extra repo
rhc connect                                   # newer alternative (register + Insights)
```

With **Simple Content Access** (standard now), there's no need to attach subscriptions (`attach --auto`/`--pool` are deprecated).

### 2.2 `.repo` files

Location: `/etc/yum.repos.d/*.repo`.

```ini
[appstream-remote]
name=Exam AppStream
baseurl=http://repo.example.com/rhel10/AppStream
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
```

| Key | Meaning |
|---|---|
| `[id]` | Unique repo ID (no spaces) |
| `baseurl=` | `http(s)://`, `ftp://` or `file:///` path containing `repodata/` |
| `enabled=` | 1/0 |
| `gpgcheck=` / `gpgkey=` | Verify signatures / where the public key is |
| `metadata_expire=` | When to refresh metadata (`-1` = never, good for static ISOs) |

```bash
# Option A: write the file by hand (above)
# Option B: generate it (dnf-plugins-core)
dnf config-manager --add-repo http://repo.example.com/rhel10/BaseOS
rpm --import http://repo.example.com/RPM-GPG-KEY-example      # trust a repo's key
dnf repolist ; dnf repolist all ; dnf repolist -v              # verify
dnf config-manager --set-disabled appstream-remote             # disable / --set-enabled
dnf install htop --enablerepo=epel                             # one-off enable
```

### 2.3 Local DVD/ISO repository (offline)

```bash
mkdir -p /mnt/iso
mount -o ro /dev/sr0 /mnt/iso                        # DVD device   (ISO file: mount -o loop,ro rhel-10.iso /mnt/iso)
cat > /etc/yum.repos.d/rhel10-dvd.repo <<'EOF'
[dvd-baseos]
name=RHEL 10 DVD BaseOS
baseurl=file:///mnt/iso/BaseOS
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
metadata_expire=-1

[dvd-appstream]
name=RHEL 10 DVD AppStream
baseurl=file:///mnt/iso/AppStream
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
metadata_expire=-1
EOF
dnf clean all ; dnf repolist
echo '/dev/sr0  /mnt/iso  iso9660  ro,nofail  0 0' >> /etc/fstab     # persistent (or the .iso path with loop,ro)
```

## 3. dnf Commands **[RHCSA Core]**

| Task | Command |
|---|---|
| Search names/summaries | `dnf search ftp` |
| Details | `dnf info zsh` |
| Which package provides a file/command | `dnf provides '*/bin/semanage'` |
| List | `dnf list --installed` · `dnf list --available` · `dnf list 'openssh*'` |
| Install | `dnf install -y httpd` |
| Install a local RPM (resolves deps from repos) | `dnf install ./package.rpm` |
| Reinstall / downgrade | `dnf reinstall pkg` · `dnf downgrade pkg` |
| Remove (+ unneeded deps) | `dnf remove pkg` · `dnf autoremove` |
| Check for updates / update | `dnf check-update` · `dnf upgrade` (`update` is an alias) |
| Update one package / exclude | `dnf upgrade openssh` · `dnf upgrade --exclude='kernel*'` |
| Security updates | `dnf updateinfo list --security` · `dnf upgrade --security` |
| Groups | `dnf group list` · `dnf group info "Development Tools"` · `dnf group install …` |
| History | `dnf history` · `dnf history info 7` · `dnf history undo 7` · `dnf history rollback 5` |
| Query repo metadata | `dnf repoquery -l pkg` (files) · `dnf repoquery --requires pkg` |
| Cache | `dnf clean all` · `dnf makecache` |

**`/etc/dnf/dnf.conf` (`/etc/yum.conf` links to it):** `gpgcheck=1`, `installonly_limit=3` (kernels kept), `clean_requirements_on_remove=True`, `best=True`, `skip_if_unavailable=False`. Cache: `/var/cache/dnf/`; log: `/var/log/dnf.log`.

## 4. rpm Commands

| Task | Command |
|---|---|
| All installed | `rpm -qa` (`rpm -qa \| grep ssh`) |
| Installed? / info | `rpm -q openssh` · `rpm -qi openssh` |
| Files / config files / docs | `rpm -ql pkg` · `rpm -qc pkg` · `rpm -qd pkg` |
| Package owning a file | `rpm -qf /usr/bin/zsh` |
| Query an **uninstalled .rpm file** | `rpm -qpi file.rpm` · `rpm -qpl file.rpm` |
| Dependencies / provides | `rpm -qR pkg` · `rpm -q --provides pkg` |
| Scripts / changelog | `rpm -q --scripts pkg` · `rpm -q --changelog pkg \| head` |
| Install / upgrade / freshen | `rpm -ivh f.rpm` · `rpm -Uvh f.rpm` · `rpm -Fvh f.rpm` (no dependency resolution) |
| Erase | `rpm -e zsh` (package **name**, not the file) |
| Verify installed files | `rpm -V openssh-server` · `rpm -Va` |
| Check a package signature | `rpm -K file.rpm` |
| Import a GPG key | `rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release` |

**`rpm -V` codes:** `S` size, `M` mode, `5` digest, `D` device, `L` link, `U` user, `G` group, `T` mtime, `P` capabilities; `c` marks a config file. Example: `S.5....T.  c /etc/ssh/sshd_config` means a config file was edited (expected).

**RPM database:** `/usr/lib/sysimage/rpm/rpmdb.sqlite` (`/var/lib/rpm` is a symlink to it).

## 5. RHCSA Exam Focus **[RHCSA Core]**

```bash
# "Configure the system to use http://content/rhel10/BaseOS and …/AppStream as repositories"
vi /etc/yum.repos.d/exam.repo    # two sections; gpgcheck=0 only if no key is provided
dnf repolist                     # both enabled?
dnf install -y <pkg>             # proves the repos work
```

- Repo IDs must be unique; `baseurl` must point at the directory that contains `repodata/`.
- If a GPG key URL is given, use `gpgcheck=1` + `gpgkey=`.
- Kernel updates install alongside old kernels; reboot and check `uname -r`.

## 6. Production Practices **[Production Practice]**

- Keep `gpgcheck=1`; only add trusted third-party repos (with their keys).
- Use `dnf history` for audit and rollback; snapshot before big upgrades.
- Patch with `dnf upgrade --security` on a schedule; test in staging first.
- Lock critical versions if required (`python3-dnf-plugin-versionlock` → `dnf versionlock add pkg`) **[Advanced]**.
- Prefer `dnf install ./local.rpm` over `rpm -i`, so dependencies are recorded and resolved.

## 7. Troubleshooting

| Message / symptom | Cause | Fix |
|---|---|---|
| `There are no enabled repositories` | Not registered / no `.repo` files | Register, or add `.repo` files |
| `Cannot download repomd.xml` / `Curl error` | Wrong `baseurl` (must contain `repodata/`), network, DNS | `curl -I <baseurl>/repodata/repomd.xml`; fix URL |
| `GPG check FAILED` / `public key … not installed` | Key missing | `rpm --import KEY`; correct `gpgkey=` |
| `error: Failed dependencies` (rpm) | rpm doesn't resolve dependencies | `dnf install ./file.rpm` |
| `No match for argument: X` | Wrong name or repo disabled | `dnf search`, `dnf provides`, `dnf repolist all` |
| Transaction conflicts | Mixed repos/versions | Inspect, `dnf history`, remove the conflicting repo |
| Old metadata after repo change | Cache | `dnf clean all ; dnf makecache` |

## 8. Debian Comparison **[Interview Knowledge]**

| Task | RHEL | Debian/Ubuntu |
|---|---|---|
| Low-level | `rpm -i/-e/-q` | `dpkg -i/-r/-l` |
| High-level | `dnf install/remove/upgrade` | `apt install/remove/upgrade` |
| Refresh metadata | `dnf makecache` (automatic) | `apt update` (required) |
| File owner | `rpm -qf` | `dpkg -S` |
| Repo config | `/etc/yum.repos.d/*.repo` | `/etc/apt/sources.list(.d)` |

## 9. Interview Questions

| Question | Answer |
|---|---|
| rpm vs dnf? | rpm installs single files without dependency resolution; dnf uses repos and resolves dependencies. |
| How do you find which package provides a command? | `dnf provides '*/bin/cmd'` (or `rpm -qf $(command -v cmd)` if installed). |
| How do you set up an offline repo? | Mount the DVD/ISO and create a `.repo` with `file:///…/BaseOS` and `…/AppStream`. |
| How do you undo a bad update? | `dnf history`, then `dnf history undo <id>` (or rollback). |
| What does `rpm -V` tell you? | Which files changed since installation (size, digest, mode, owner…). |

## 10. Course Corrections

| Course | Correction |
|---|---|
| `dnf module list/enable` as a feature | No modularity on RHEL 10 |
| `yum update all` | Not a command; `dnf upgrade` |
| `yum upgrade` "also removes obsoletes, update doesn't" | In dnf they're the same command |
| `yum upgrade –refresh` | `dnf upgrade --refresh` |
| `rpm -e package.rpm` | `rpm -e <name>` |
| `mount -o loop /dev/sr0 /mnt` | `-o loop` is for ISO files; `mount -o ro /dev/sr0 /mnt` |
| `yum grouplist` / `groupinstall` | `dnf group list` / `dnf group install` |
| `--exclude=openssh*` | Quote it: `--exclude='openssh*'` |
| `subscription-manager attach --auto` / `--pool` | Not needed with Simple Content Access |
| `rhel-9-for-x86_64-…-rpms` | RHEL 10: `rhel-10-for-x86_64-baseos-rpms` / `…-appstream-rpms` |
| Repo name "Red Hat Enterprise Linux 9" / expected `LocalRepo` | Inconsistent with the repo defined; names are free text, IDs must match your file |

## 11. Quick Revision

```bash
/etc/yum.repos.d/*.repo: [id] name baseurl enabled gpgcheck gpgkey · dnf repolist [all] · dnf config-manager --add-repo URL
dnf search|info|provides|list|install|install ./f.rpm|remove|autoremove|upgrade|check-update|history [undo N]|group install|clean all
rpm -qa|-q|-qi|-ql|-qc|-qd|-qf FILE|-qpl F.rpm|-qR|-V|-K|-e NAME|--import KEY
subscription-manager register ; repos --list-enabled · DVD: mount -o ro /dev/sr0 /mnt/iso + file:///mnt/iso/{BaseOS,AppStream}
