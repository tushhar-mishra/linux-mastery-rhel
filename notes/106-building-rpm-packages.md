# 106 · Building RPM Packages

> **You need first:** [105 · Ansible](105-ansible.md) (and topics 031 rpm/dnf, 021 archives, 025 startup files)
> **Next:** [107 · Compiling a kernel](107-compiling-a-kernel.md)

---

## What it is

An **RPM package** bundles three things:
- **files** (binaries, configs, docs);
- **metadata** (name, version, dependencies);
- **scripts** (to run at install or removal).

Building one turns your software into something you can install, upgrade, verify and remove with `dnf`/`rpm` on every server, just like Red Hat's own packages (topic 031).

| Term | Meaning |
|---|---|
| **SPEC file** | The recipe: metadata plus the build and install steps |
| **`rpmbuild`** | The tool that follows the recipe |
| **Binary RPM** | The installable package (`name-version-release.arch.rpm`) |
| **SRPM** (source RPM) | The spec + sources, used to rebuild the binary RPM |
| **`%{buildroot}`** | A temporary **fake root** where `%install` places files, so the build never touches the real system |
| **Macro** | A `%{name}` placeholder that rpmbuild expands (`%{_bindir}` = `/usr/bin`) |
| **Scriptlet** | A shell snippet run at install/upgrade/removal (`%post`, `%preun`, `%postun`) |

Ubuntu/Debian use **.deb** packages built with `dpkg-buildpackage` / `debuild` (a `debian/` directory instead of a spec). The ideas are the same.

## Why it exists

Copying files with `scp` or a script leaves no record of what was installed, no clean removal, no dependency handling and no integrity checks. A package gives you:
- versioning and clean upgrades;
- dependency resolution (`Requires`);
- `rpm -V` verification;
- ownership (`rpm -qf FILE` tells you which package a file came from);
- signed distribution via your own repository.

That's how organisations ship internal tools, agents and configs to fleets.

## Analogy

A spec file is a **flat-pack furniture instruction sheet**. It lists the parts (sources), the tools needed (BuildRequires), how to assemble (`%build`), and where each piece goes (`%install`, `%files`). `rpmbuild` assembles it in a **workshop** (the buildroot), not in your living room, then shrink-wraps the result with a label (metadata) and a seal (a GPG signature).

## How it works inside

**Workflow:** prepare the build tree → put the source tarball in `SOURCES/` → write the spec in `SPECS/` → `rpmbuild` → test → lint → sign → publish to a repo.

| Directory (`~/rpmbuild/`) | Purpose |
|---|---|
| `SOURCES/` | Tarballs, patches, extra files |
| `SPECS/` | `.spec` files |
| `BUILD/` | Sources unpacked and compiled (`%prep`, `%build`) |
| `BUILDROOT/` | The fake root for `%install` (`%{buildroot}`) |
| `RPMS/<arch>/` | Built binary RPMs (`noarch/`, `x86_64/`) |
| `SRPMS/` | Source RPMs |

`rpmbuild` runs the spec's sections in order:
1. **`%prep`**: unpack the sources and apply patches.
2. **`%build`**: compile.
3. **`%install`**: copy into `%{buildroot}`.
4. **`%check`**: run tests.

Then it collects exactly the files listed in **`%files`**, computes automatic dependencies (for example, the shared libraries a binary links to), and writes the RPM with its header (metadata, file list with checksums and permissions, scriptlets).

| Section / tag | Purpose |
|---|---|
| `Name`, `Version`, `Release: 1%{?dist}` | Identity. `%{?dist}` adds `.el10` |
| `Summary`, `License` (SPDX IDs, e.g. `GPL-3.0-or-later`), `URL` | Metadata |
| `Source0`, `Patch0` | Files from `SOURCES/` |
| `BuildArch: noarch` | Scripts/data with no compiled code |
| `BuildRequires` / `Requires` | Needed to build / needed to run |
| `%description` | Long description |
| `%prep` | `%setup -q` or `%autosetup` |
| `%build` | `%configure`, `%make_build`… (empty for scripts) |
| `%install` | `install -D -m MODE SRC %{buildroot}PATH` |
| `%files` | Every packaged file: `%license`, `%doc`, `%config(noreplace)`, `%attr(mode,user,group)`, `%dir` |
| `%post`, `%preun`, `%postun` | Scriptlets (for example `systemctl daemon-reload`) |
| `%changelog` | `* Tue Nov 17 2026 Name <email> - 1.0-1` + entries |

`%config(noreplace)` matters: on upgrade, a config file the admin changed is **kept**, and the new one is saved as `.rpmnew` (topic 031).

**Build as a normal user, never root.** A broken spec run as root could write into the live system.

## Commands

### Prepare

```bash
sudo dnf install -y rpm-build rpmdevtools rpmlint
rpmdev-setuptree                         # creates ~/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
rpm --eval '%{_bindir} %{_sysconfdir} %{_unitdir} %{?dist}'
```
```
/usr/bin /etc /usr/lib/systemd/system .el10
```

### Package a script

```bash
mkdir -p ~/work/hello-tool-1.0
cat > ~/work/hello-tool-1.0/hello-tool <<'EOF'
#!/usr/bin/bash
echo "Hello from $(hostname) at $(date +%T)"
EOF
tar -czf ~/rpmbuild/SOURCES/hello-tool-1.0.tar.gz -C ~/work hello-tool-1.0
```
`~/rpmbuild/SPECS/hello-tool.spec`:
```spec
Name:           hello-tool
Version:        1.0
Release:        1%{?dist}
Summary:        Prints a friendly greeting
License:        MIT
URL:            https://example.com/hello-tool
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch
Requires:       bash

%description
A tiny demo command packaged as an RPM.

%prep
%setup -q

%build
# nothing to compile

%install
install -D -m 0755 hello-tool %{buildroot}%{_bindir}/hello-tool

%files
%{_bindir}/hello-tool

%changelog
* Tue Nov 17 2026 Alice Admin <alice@example.com> - 1.0-1
- First release
```

### Build, inspect, test

```bash
rpmbuild -ba ~/rpmbuild/SPECS/hello-tool.spec      # -bb binary only, -bs SRPM only, -bp prep only
ls ~/rpmbuild/RPMS/noarch/ ~/rpmbuild/SRPMS/
rpm -qpi ~/rpmbuild/RPMS/noarch/hello-tool-1.0-1.el10.noarch.rpm | head -6
rpm -qpl ~/rpmbuild/RPMS/noarch/hello-tool-1.0-1.el10.noarch.rpm
rpmlint ~/rpmbuild/SPECS/hello-tool.spec ~/rpmbuild/RPMS/noarch/*.rpm
```
```
Wrote: /home/alice/rpmbuild/SRPMS/hello-tool-1.0-1.el10.src.rpm
Wrote: /home/alice/rpmbuild/RPMS/noarch/hello-tool-1.0-1.el10.noarch.rpm
Name        : hello-tool
Version     : 1.0
Release     : 1.el10
Architecture: noarch
...
/usr/bin/hello-tool
hello-tool.noarch: W: no-documentation
hello-tool.spec: W: no-%check-section
hello-tool.spec: W: invalid-url Source0: hello-tool-1.0.tar.gz
 1 packages and 1 specfiles checked; 0 errors, 4 warnings, 4 filtered, 0 badness; has taken 0.9 s
```
- One binary RPM and one SRPM. `rpmlint` warnings are style advice (no documentation, no `%check`, a Source0 that isn't a full URL); errors must be fixed. The SRPM is in `SRPMS/`, not in `RPMS/noarch/`, so only one package was linted.

```bash
sudo dnf install ~/rpmbuild/RPMS/noarch/hello-tool-1.0-1.el10.noarch.rpm   # dnf resolves Requires (better than rpm -ivh)
hello-tool ; rpm -qf /usr/bin/hello-tool ; rpm -V hello-tool
sudo dnf remove hello-tool
rpmbuild --rebuild somepackage.src.rpm                     # rebuild someone else's SRPM
```

### Shipping a config file and a systemd unit

```spec
%install
install -D -m 0644 myagent.conf    %{buildroot}%{_sysconfdir}/myagent.conf
install -D -m 0644 myagent.service %{buildroot}%{_unitdir}/myagent.service
install -D -m 0755 myagent         %{buildroot}%{_bindir}/myagent

%post
systemctl daemon-reload >/dev/null 2>&1 || :

%files
%config(noreplace) %{_sysconfdir}/myagent.conf
%{_unitdir}/myagent.service
%{_bindir}/myagent
```
- Files in `/etc/profile.d/*.sh` are **sourced**, so give them mode `0644`, and make them silent in non-interactive shells (`[[ $- == *i* && -t 1 ]] || return 0`), or they break `scp`/`sftp` (topic 025).

### Sign and publish

```bash
sudo dnf install -y rpm-sign createrepo_c
gpg --quick-gen-key 'Build Bot <build@example.com>'   # asks for a passphrase (rpm --addsign asks again)
echo '%_gpg_name Build Bot <build@example.com>' >> ~/.rpmmacros
rpm --addsign ~/rpmbuild/RPMS/noarch/*.rpm
gpg --export -a 'Build Bot' > RPM-GPG-KEY-internal
sudo cp RPM-GPG-KEY-internal /var/www/html/      # clients download the key from here (gpgkey= below)
sudo mkdir -p /var/www/html/repo ; sudo cp ~/rpmbuild/RPMS/noarch/*.rpm /var/www/html/repo/
sudo createrepo_c /var/www/html/repo                 # builds repodata/
```
On clients (topic 031):
```ini
# /etc/yum.repos.d/internal.repo
[internal]
name=Internal tools
baseurl=http://repo.example.com/repo
gpgcheck=1
gpgkey=http://repo.example.com/RPM-GPG-KEY-internal
```
- On the first install dnf shows the key's fingerprint and imports it (`Importing GPG key 0x202A2FC8 … Key imported successfully`). Before the key is imported, `rpm -qpi` on a signed package warns `Signature, key ID 202a2fc8: NOKEY`; that is normal, not an error.

### Try it
1. Package a script as above, install it with `dnf`, check `rpm -qf` and `rpm -V`, then remove it.
2. Add a `%config(noreplace)` file. Install, edit the config, bump `Release` to 2, rebuild and upgrade. Find the `.rpmnew` file.
3. Publish a signed local repo with `createrepo_c`, add the `.repo` file, and install from it.

## Where you'll use it

- **Shipping internal tools, agents and configs** to RHEL fleets through a repo (often Pulp, Satellite, Artifactory or Nexus).
- **CI/CD pipelines** that build RPMs (`rpmbuild`, `mock` for clean chroot builds, Fedora's Copr).
- **Container images:** installing your RPMs in a Containerfile keeps images reproducible and auditable.
- **Rebuilding SRPMs** for patches or backports.

## When it breaks

| Message | Cause | Fix |
|---|---|---|
| `File /…/SOURCES/x.tar.gz: No such file` | The tarball's name or place | Match `Source0`; put it in `SOURCES/` |
| `cd: …/BUILD/name-version: No such file` | The tarball's top directory isn't `%{name}-%{version}` | Rename it, or `%setup -q -n DIRNAME` |
| `Installed (but unpackaged) file(s) found` | `%install` created files not listed in `%files` | List them (or don't install them) |
| `File not found: …/BUILDROOT/…` | `%files` lists a file `%install` didn't create | Fix the paths (use macros) |
| `Failed dependencies` on install | A `Requires` can't be satisfied | Install with `dnf install ./file.rpm` with repos enabled |
| `Package … is not signed` | `gpgcheck=1` but no signature or key | `rpm --addsign`; distribute the key; `rpm --import` |
| `scp`/`sftp` break after installing a profile.d script | It prints output in non-interactive shells | Add the interactive guard |

## Quick recap

- `dnf install rpm-build rpmdevtools rpmlint`; `rpmdev-setuptree`; sources in `SOURCES/`, spec in `SPECS/`.
- Spec: preamble (`Name`, `Version`, `Release: 1%{?dist}`, `License`, `Source0`, `Requires`) → `%prep` → `%build` → `%install` into `%{buildroot}` → `%files` → `%changelog`.
- `rpmbuild -ba`, `rpm -qpi/-qpl`, `rpmlint`, `dnf install ./pkg.rpm`. Build as a normal user.
- `%config(noreplace)` for configs; sign with `rpm --addsign`; publish with `createrepo_c` + a `.repo` file with `gpgcheck=1`.

**Interview questions**

1. *What is `%{buildroot}`?* A temporary fake root directory where the `%install` section places files, so building a package never writes into the real system.
2. *Binary RPM vs source RPM?* A binary RPM contains the installable files for an architecture; an SRPM contains the spec and sources needed to rebuild it.
3. *What does `%config(noreplace)` do?* On upgrade, if the admin changed that config file, RPM keeps their version and writes the packaged one as `.rpmnew` instead of overwriting it.
