# Building RPM Packages

> **Sessions:** S59 · **[Advanced/Optional]** (not an RHCSA objective) · useful for DevOps, internal software distribution and interviews
> **Related:** [RPM & DNF](rpm-and-dnf-package-management.md) · [Shell startup files (profile.d)](../users-groups-and-permissions/shell-startup-files.md) · [Archiving (tarballs)](../files-and-text-processing/archiving-and-compression.md)

## 1. Overview

An RPM bundles files, metadata (name, version, dependencies) and install scripts. Building one turns software into something you can install, upgrade, verify and remove with `dnf`/`rpm` across many servers.

**Workflow:** prepare build tree → source tarball in `SOURCES/` → SPEC file in `SPECS/` → `rpmbuild` → test → lint → (sign) → publish to a repo.

> ⚠️ Build as a **regular user**, never root. A broken spec could write into the live system.

## 2. Build Environment

```bash
sudo dnf install -y rpm-build rpmdevtools rpmlint
rpmdev-setuptree            # creates ~/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
rpmdev-newspec ~/rpmbuild/SPECS/hello.spec   # spec skeleton (optional)
```

| Directory | Purpose |
|---|---|
| `SOURCES/` | Tarballs, patches, extra files |
| `SPECS/` | `.spec` recipes |
| `BUILD/` | Sources unpacked and compiled here (`%prep`, `%build`) |
| `BUILDROOT/` | Fake root where `%install` places files (`%{buildroot}`) |
| `RPMS/<arch>/` | Built binary RPMs (`noarch/`, `x86_64/`) |
| `SRPMS/` | Source RPMs (spec + sources) |

## 3. SPEC File Anatomy

| Section / tag | Purpose |
|---|---|
| `Name`, `Version`, `Release: 1%{?dist}` | Identity; `%{?dist}` adds `.el10` |
| `Summary`, `License`, `URL` | Metadata (`License` uses SPDX IDs, e.g. `GPL-3.0-or-later`) |
| `Source0`, `Patch0` | Files from `SOURCES/` |
| `BuildArch: noarch` | For scripts and data (no compiled code) |
| `BuildRequires` / `Requires` | Needed to build / to run |
| `%description` | Long description |
| `%prep` | Unpack (`%setup -q` or `%autosetup`) |
| `%build` | Compile (`%configure`, `%make_build`), empty for scripts |
| `%install` | Copy into `%{buildroot}` (`install -D -m …`) |
| `%check` | Run tests (optional) |
| `%files` | Every packaged file: `%license`, `%doc`, `%config(noreplace)`, `%attr(mode,user,group)`, `%dir` |
| `%post`, `%preun`, `%postun` | Scriptlets (e.g., `systemctl daemon-reload`) |
| `%changelog` | `* Mon Aug 18 2025 Name <email> - 1.0-1` + entries |

Path macros (use instead of hard-coded paths): `%{_bindir}` = `/usr/bin`, `%{_sbindir}`, `%{_sysconfdir}` = `/etc`, `%{_datadir}` = `/usr/share`, `%{_unitdir}` = systemd units. Check any macro with `rpm --eval '%{_bindir}'`.

## 4. Example: Packaging a Shell Command

```bash
mkdir -p ~/work/snake-game-1.0
cp snake-game.sh ~/work/snake-game-1.0/
tar -czf ~/rpmbuild/SOURCES/snake-game-1.0.tar.gz -C ~/work snake-game-1.0
```

```spec
Name:           snake-game
Version:        1.0
Release:        1%{?dist}
Summary:        Snake game for the terminal
License:        GPL-3.0-or-later
URL:            https://example.com/snake-game
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch
Requires:       bash, ncurses

%description
An ASCII snake game for the Linux terminal (W A S D to move, Q to quit).

%prep
%setup -q

%build
# nothing to build for a shell script

%install
install -D -m 0755 snake-game.sh %{buildroot}%{_bindir}/snake-game

%files
%{_bindir}/snake-game

%changelog
* Mon Aug 18 2025 Jane Admin <jane@example.com> - 1.0-1
- First release
```

### Example 2: login message in `/etc/profile.d` (corrected)

Files in `/etc/profile.d/*.sh` are **sourced** by login shells, so they need mode `0644`, not executable. They must also stay quiet for non-interactive sessions (scp, sftp, automation):

```bash
# login-banner.sh — first lines
[[ $- == *i* && -t 1 ]] || return 0
```

```spec
%install
install -D -m 0644 login-banner.sh %{buildroot}%{_sysconfdir}/profile.d/login-banner.sh

%files
%{_sysconfdir}/profile.d/login-banner.sh
```

## 5. Build, Inspect, Test

```bash
rpmbuild -ba ~/rpmbuild/SPECS/snake-game.spec   # -bb binary only, -bs SRPM only, -bp prep only
ls ~/rpmbuild/RPMS/noarch/ ~/rpmbuild/SRPMS/
rpm -qpi ~/rpmbuild/RPMS/noarch/snake-game-1.0-1.el10.noarch.rpm   # metadata
rpm -qpl ~/rpmbuild/RPMS/noarch/snake-game-1.0-1.el10.noarch.rpm   # files
rpmlint ~/rpmbuild/SPECS/snake-game.spec ~/rpmbuild/RPMS/noarch/*.rpm   # quality checks
sudo dnf install ./snake-game-1.0-1.el10.noarch.rpm   # resolves Requires (better than rpm -ivh)
snake-game
sudo dnf remove snake-game
rpmbuild --rebuild package.src.rpm                               # rebuild someone else's SRPM
```

## 6. Signing & Publishing **[Production Practice]**

```bash
sudo dnf install -y rpm-sign createrepo_c
gpg --gen-key                                     # signing key
echo '%_gpg_name Your Name <you@example.com>' >> ~/.rpmmacros
rpm --addsign ~/rpmbuild/RPMS/noarch/*.rpm
gpg --export -a 'Your Name' > RPM-GPG-KEY-internal   # distribute; clients: rpm --import
mkdir -p /srv/repo ; cp ~/rpmbuild/RPMS/noarch/*.rpm /srv/repo/
createrepo_c /srv/repo                             # builds repodata/
# clients: .repo with baseurl=http://server/repo, gpgcheck=1, gpgkey=…
```

## 7. Troubleshooting

| Message | Cause | Fix |
|---|---|---|
| `error: File /…/SOURCES/x.tar.gz: No such file` | Tarball name/location | Match `Source0` and place it in `SOURCES/` |
| `cd: …/BUILD/name-version: No such file` | Tarball top directory ≠ `%{name}-%{version}` | Rename, or `%setup -q -n dirname` |
| `Installed (but unpackaged) file(s) found` | `%install` created files not in `%files` | List them in `%files` (or don't install them) |
| `File not found: …/BUILDROOT/…` | `%files` lists a file `%install` didn't create | Fix paths (use macros) |
| `error: Failed dependencies` on install | `Requires` not installable | Install via `dnf install ./file.rpm` with repos enabled |
| scp/sftp break after installing a profile.d script | Output in non-interactive shells | Guard: `[[ $- == *i* && -t 1 ]] \|\| return 0` |

## 8. Interview Questions

| Question | Answer |
|---|---|
| What are the main spec sections? | Preamble, `%description`, `%prep`, `%build`, `%install`, `%files`, `%changelog` (+ scriptlets). |
| What's `%{buildroot}`? | A temporary fake root where `%install` stages files, so the build never touches the real system. |
| Binary RPM vs SRPM? | Installable files vs sources + spec used to rebuild. |
| Why `Release: 1%{?dist}`? | Adds the distribution tag (`.el10`) so builds for different releases don't collide. |
| How do clients get your RPMs? | `createrepo_c` repo over HTTP + `.repo` file + signed packages. |

## 9. Quick Revision

```bash
dnf install rpm-build rpmdevtools rpmlint ; rpmdev-setuptree ; SOURCES/ SPECS/ BUILD/ BUILDROOT/ RPMS/ SRPMS/
spec: Name Version Release:1%{?dist} Summary License(SPDX) Source0 BuildArch Requires | %prep %setup -q | %build | %install %{buildroot} | %files | %changelog
rpmbuild -ba|-bb|-bs SPEC · rpm -qpi/-qpl F.rpm · rpmlint · dnf install ./F.rpm · rpm --addsign · createrepo_c DIR
```

## 10. Cross-References

- [RPM & DNF](rpm-and-dnf-package-management.md)
- [Shell startup files (profile.d)](../users-groups-and-permissions/shell-startup-files.md)
- [Archiving (tarballs)](../files-and-text-processing/archiving-and-compression.md)
