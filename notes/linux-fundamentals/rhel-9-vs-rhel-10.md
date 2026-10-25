# RHEL 9 vs RHEL 10

> **Verified:** Oct 2026 (current minor: RHEL 10.2)
> **Related:** [Exam & certification](rhcsa-exam-and-certification.md) · [Lab setup](virtualization-and-lab-setup.md)

## 1. Overview

RHEL 10 (codename **Coughlan**) became generally available on **20 May 2025**. The exam is based on RHEL 10, so these differences affect both exam technique and lab setup.

## 2. Comparison **[Interview Knowledge]**

| Area | RHEL 9 | RHEL 10 | Why it matters |
|---|---|---|---|
| GA | May 2022 | 20 May 2025 | Lifecycle planning |
| Lifecycle | Ends 2032 | Ends 2035 | Migration timelines |
| Kernel | 5.14 | 6.12 | Hardware support, scheduler |
| x86_64 CPU baseline | x86-64-v2 (~2008+) | **x86-64-v3** (AVX2; ~2013+, Intel Haswell+) | Old hosts/VMs can't boot RHEL 10 |
| 32-bit | i686 compat packages | Removed | Legacy apps break |
| Toolchain | GCC 11, glibc 2.34, Python 3.9 | GCC 14, glibc 2.39, Python 3.12 | Rebuilds needed |
| OpenSSH | 8.7 | 9.9; `ssh-keygen` defaults to **Ed25519** (RSA in FIPS mode) | Key generation defaults |
| Network config | Keyfiles default; legacy ifcfg still read | **ifcfg support removed**; keyfiles only | `nmcli` is the way |
| Teaming | teamd deprecated | **teamd/libteam removed** → use bonding | Migrate before upgrading |
| DHCP client | dhclient available | **dhclient removed** (NetworkManager internal DHCP) | Scripts calling dhclient fail |
| Display server | Wayland default; Xorg available | **Xorg server removed**; Wayland + Xwayland | X11-only tools |
| Remote desktop | TigerVNC | TigerVNC removed | Use RDP-based remote desktop |
| Desktop apps | Firefox, Thunderbird as RPMs | Removed as RPMs → **Flatpak** | Flatpak is now an exam objective |
| Application Streams | Modularity (`dnf module`) | No modularity; traditional RPMs | `dnf module` workflows irrelevant |
| cgroups | v2 default; v1 possible | **v1 removed** | Old agents and container tools |
| Installer root account | Root password set by default | **Root disabled by default**; admin user (wheel); password SSH root login disabled | Lab and `su` behavior |
| `passwd` command | `passwd` package (libuser); `passwd -S` codes `PS`/`LK`/`NP`; new accounts `!!` in shadow | Provided by **shadow-utils** (verified 4.15 on 10.2); `passwd -S` codes `P`/`L`/`NP`; new accounts `!` in shadow; `--stdin` still works | Scripts parsing `passwd -S` output |
| Default filesystem | XFS | XFS | No change |
| `/usr/sbin` | Separate | **Still separate** (Fedora merged it into `/usr/bin`; RHEL 10 did not) | FHS accuracy |
| New features | — | Lightspeed command-line assistant, image mode (bootc), post-quantum cryptography | [Lightspeed note](../advanced-rhel-and-career-notes/rhel-lightspeed-command-line-assistant.md) |
| In-place upgrade | — | 9.6 → 10.0, 9.7 → 10.1 (Leapp) | Upgrade planning |

## 3. Exam and Lab Impact **[RHCSA Core]**

- Configure networking with **`nmcli`/`nmtui`** only. `/etc/sysconfig/network-scripts/` is not used.
- **Root may be locked.** Use `sudo -i`, or set a root password if your lab needs one.
- **Flatpak** objectives exist partly because desktop apps moved to Flatpak.
- There's no browser in a minimal or server install. Rely on `man`, `info` and `/usr/share/doc`.
- Lab VMs must expose **AVX2** to the guest (see troubleshooting).

## 4. Commands

```bash
cat /etc/redhat-release              # Red Hat Enterprise Linux release 10.x (Coughlan)
cat /etc/os-release                  # ID, VERSION_ID, PLATFORM_ID
uname -r                             # 6.12.0-…el10…x86_64
hostnamectl                          # OS, kernel, architecture, virtualization type
rpm -q kernel                        # installed kernels

# Does this CPU support x86-64-v3? (run on any Linux with glibc ≥ 2.33)
/usr/lib64/ld-linux-x86-64.so.2 --help | grep x86-64-v
#   x86-64-v3 (supported, searched)  ← required for RHEL 10
grep -o -m1 avx2 /proc/cpuinfo       # quick check: prints "avx2" if present
```

## 5. Troubleshooting **[Production Practice]**

| Symptom | Likely cause | Fix |
|---|---|---|
| RHEL 10 VM fails very early in boot or the installer; error mentions x86-64-v3 or CPU support | Host CPU lacks AVX2, or the hypervisor hides it | Use a Haswell-or-newer host. On KVM use CPU mode `host-passthrough`. Some VirtualBox-on-Windows setups with Hyper-V active don't expose AVX2. |
| Old team interface missing after upgrade | teamd removed | Recreate as a bond: `nmcli con add type bond …` |
| ifcfg file changes ignored | ifcfg unsupported | Migrate: `nmcli connection migrate` (do it on RHEL 9 before upgrading) |

## 6. Interview Questions

| Question | Answer |
|---|---|
| What is x86-64-v3 and why did RHEL raise the baseline? | A microarchitecture level that includes AVX2, BMI and FMA. Compiling for it gives performance gains, at the cost of dropping pre-2013 CPUs. |
| What replaced network teaming? | Kernel bonding via NetworkManager. |
| How do you upgrade RHEL 9 → 10? | Leapp in-place upgrade from a supported minor release (e.g., 9.6 → 10.0) after reviewing the pre-upgrade report. Or rebuild fresh. |
| Where does NetworkManager store connections on RHEL 10? | Keyfiles in `/etc/NetworkManager/system-connections/` (`.nmconnection`, mode 0600). |

## 7. Quick Revision

Kernel 6.12 · x86-64-v3 · ifcfg/teamd/dhclient/Xorg/TigerVNC removed · Firefox → Flatpak · no modularity · root disabled by default · Ed25519 default keys · `/usr/sbin` still separate.

**Sources:** Red Hat docs *Considerations in adopting RHEL 10*, Networking chapter (docs.redhat.com); RHEL 10 release notes; RHEL Jira RHEL-60564 (OpenSSH 9.9).
