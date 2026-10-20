# UNIX/Linux History & Architecture

> **Sessions:** S2 (history portion) · **Scope:** [Interview Knowledge], not tested on EX200
> **Related:** [Filesystem hierarchy](filesystem-hierarchy.md) · [Virtualization](virtualization-and-lab-setup.md)

## 1. Overview

Linux is a **UNIX-like** kernel written from scratch, not derived from UNIX source code. Combined with GNU and other userland software, it forms a complete OS. This history explains Linux's design philosophy (small tools, text streams, everything-is-a-file) and comes up in interviews as conceptual grounding.

## 2. Timeline (corrected)

| Year | Event |
|---|---|
| 1969 | Bell Labs leaves the Multics project. Ken Thompson and Dennis Ritchie (with McIlroy, Ossanna and others) start UNIX on a DEC **PDP-7**, written in **assembly** |
| ~1970 | Name "Unics" (pun on Multics). Thompson creates **B**, derived from **BCPL** |
| 1971 | **First Edition** UNIX on the PDP-11, still assembly (not portable) |
| 1971–73 | Ritchie develops **C** from B |
| 1973 | **Fourth Edition**: kernel rewritten in C, the key to portability |
| 1977–78 | **BSD** at UC Berkeley |
| 1982–83 | AT&T **System III**, then **System V** (1983) |
| 1983 | Richard Stallman announces the **GNU Project** (27 Sep) |
| 1985 | **Free Software Foundation (FSF)** founded |
| 1987 | **MINIX** (Andrew Tanenbaum), a teaching UNIX-like OS |
| 1988 | **POSIX** (IEEE 1003.1) standardizes UNIX-like APIs |
| 1989 / 1991 | GPLv1 / **GPLv2** |
| 1991 | Linus Torvalds announces Linux (25 Aug) for the Intel 386. Version 0.01 in Sept |
| 1992 | Linux relicensed under GPLv2. **SLS**, one of the first distributions |
| 1993 | **Slackware** (Patrick Volkerding), **Debian** |
| 1994 | **Linux 1.0** (14 Mar). First Red Hat Linux release. S.u.S.E. distribution |
| 1998 | "Open source" term coined. **OSI** founded |
| 2002–03 | **RHEL** emerges (from Red Hat Linux Advanced Server). **Fedora** launched |
| 2008 | **Android** (Linux kernel) ships |
| 2013–14 | Docker, Kubernetes (built on Linux namespaces and cgroups) |
| 2019 | IBM completes its Red Hat acquisition (announced 2018). **CentOS Stream** launched |
| 2021 | CentOS Linux 8 EOL → **Rocky Linux**, **AlmaLinux** |
| 2025 | **RHEL 10** GA |

> ⚠️ **Course corrections:**
> - There was no "A language"; that section describes **assembly**.
> - UNIX was rewritten in C in the **Fourth** Edition (1973), not the Second.
> - First Edition was not portable; it was assembly.
> - B was used for some utilities, but the kernel moved from assembly to C.
> - SLS was 1992 (the notes give both 1992 and 1993).
> - The FSF was founded in 1985, not 1983.

## 3. GNU, Free Software and Licensing

| Term | Meaning |
|---|---|
| **GNU** | "GNU's Not Unix": a free UNIX-like OS project. It produced the compiler (GCC), C library (glibc), shell (bash) and core utilities (coreutils) |
| **FSF** | Founded by Stallman to promote free software |
| **Free software** | "Free as in freedom, not as in beer." The four freedoms: **run**, **study/modify**, **redistribute**, **distribute modified versions** |
| **GPL** | GNU **General** Public License (not "GNU Public License"). Copyleft: derivatives must stay under the GPL |
| **Linux kernel license** | **GPLv2 only** |
| **Open source** | 1998 term (OSI) emphasizing a practical development model. Overlaps heavily with free software, with a different philosophy |

> ⚠️ **Course correction:** The FSF did not "create the Linux OS." GNU provided most of the userland; Torvalds wrote the kernel. A distribution bundles components under many licenses (GPL, LGPL, MIT, BSD, Apache), not only the GPL.

**Linux vs. GNU/Linux:** Strictly, "Linux" is the kernel. A usable OS = kernel + GNU userland + other software. "GNU/Linux" is the FSF's preferred name; most people just say "Linux."

## 4. Is Linux UNIX?

| | UNIX | Linux |
|---|---|---|
| Origin | AT&T Bell Labs code lineage | Independent reimplementation, no UNIX code |
| "UNIX" name | Trademark of The Open Group, granted to systems certified against the Single UNIX Specification (e.g., AIX, HP-UX, Solaris, **macOS**) | Mainstream distributions are not UNIX-certified |
| Compatibility | — | Largely POSIX-compliant; runs most UNIX software after recompiling |

**Answer:** Linux is **UNIX-like**, not UNIX.

> ⚠️ **Course correction:** The "Flavours of UNIX" chart draws Linux as a UNIX descendant; it's a reimplementation. Kali is Debian-based. CentOS Linux has been replaced by CentOS Stream.

## 5. Architecture **[Interview Knowledge]**

```
 ┌─────────────────────────────────────────┐
 │ Applications (dnf, sshd, httpd, vim)    │  user space
 │ Shell (bash) + utilities (coreutils)    │
 │ System libraries (glibc)                │
 ├──────────── system calls ───────────────┤
 │ Kernel: process scheduler, memory mgmt, │  kernel space
 │ VFS/filesystems, networking, drivers,   │
 │ security (SELinux), cgroups/namespaces  │
 ├─────────────────────────────────────────┤
 │ Hardware: CPU, RAM, disk, NIC           │
 └─────────────────────────────────────────┘
```

| Component | Role |
|---|---|
| **Kernel** | Manages hardware and resources; enforces isolation between processes |
| **System call** | The only gateway from user space into the kernel (`open`, `read`, `fork`, `execve`) |
| **glibc** | Wraps system calls in the C API that programs use |
| **Shell** | Command interpreter. Parses input, expands, then runs programs via `fork`/`execve` |
| **Utilities** | Small single-purpose tools combined with pipes |

**Kernel design:** Linux is **monolithic** (drivers run in kernel space) and **modular** (loadable modules via `modprobe`). Compare **microkernels** like MINIX, where drivers run in user space. The 1992 Tanenbaum–Torvalds debate was about exactly this.

```bash
uname -r                 # kernel release
uname -m                 # architecture (x86_64, aarch64)
cat /proc/version        # kernel build info
echo $SHELL; cat /etc/shells
ps -p $$                 # which shell you're actually running
ldd /usr/bin/ls          # shows dependency on libc.so.6 (glibc)
lsmod | head             # loaded kernel modules
strace -c ls             # [Advanced] count system calls made by ls
```

## 6. Distributions

| Family | Examples | Package format |
|---|---|---|
| Red Hat | Fedora (upstream) → CentOS Stream (just ahead of RHEL) → **RHEL**; rebuilds: Rocky, AlmaLinux | RPM / DNF |
| Debian | Debian, Ubuntu, Kali | DEB / APT |
| SUSE | SLES, openSUSE | RPM / zypper |
| Independent | Arch | pacman |

## 7. Linux Features (accurate version)

| Course claim | Accurate statement |
|---|---|
| "High security (virus free)" | Strong security model (permissions, SELinux, fast patching), but malware for Linux exists |
| "Supports all file systems" | Supports many (XFS, ext4, Btrfs, VFAT, NFS…). Support varies by distribution; RHEL ships a curated set |
| "Distributed OS" | Not a distributed OS; well suited to networked and clustered systems |
| Multiuser, multitasking, open source, portable, customizable | Accurate |

## 8. Programming Language Levels (background)

| Level | Example | Key point |
|---|---|---|
| Machine code | Binary opcodes | What the CPU executes; architecture-specific |
| Assembly | x86-64, ARM assembly | Human-readable mnemonics, 1:1 with machine instructions; architecture-specific |
| High-level | C, Python, Java | Portable source; compiled or interpreted |

C is sometimes called "middle-level" because it gives low-level memory control with high-level structure. That's why kernels are written in it.

> ⚠️ **Course correction:** Assembly does not "require more memory than machine code." It *assembles into* machine code. Assembly is low-level, not "middle-level." The language table also repeats the Portability row.

## 9. Interview Questions

| Question | Answer |
|---|---|
| Is Linux an OS or a kernel? | Strictly a kernel. A full OS = kernel + userland (GNU and others) + applications, packaged as a distribution. |
| Why did rewriting UNIX in C matter? | It made the OS portable across hardware, which drove UNIX's spread and shaped Linux. |
| Linux vs UNIX? | UNIX is a code lineage and certified trademark. Linux is an independent POSIX-like reimplementation. |
| What's a system call? | The controlled interface from user space into the kernel, e.g., `read()`, `fork()`. |
| Monolithic vs microkernel? | Monolithic: services in kernel space (fast; a fault can crash the kernel). Microkernel: services in user space (isolated, more overhead). Linux is monolithic and modular. |
| What does the GPL require? | If you distribute GPL software or derivatives, you must provide source under the same license. |
| Free vs open source? | Same licenses in practice. "Free software" stresses user freedom (ethics); "open source" stresses the development model. |

## 10. Quick Revision

1969 UNIX (assembly) → 1973 C rewrite (portability) → 1983 GNU → 1985 FSF → 1988 POSIX → 1991 Linux → 1994 Linux 1.0. Linux is UNIX-like and licensed GPLv2. The kernel talks to hardware; user space talks to the kernel via system calls.

## 11. Cross-References

- [Filesystem hierarchy](filesystem-hierarchy.md)
- Kernel modules: `boot-systemd-and-kernel/` (S53)
