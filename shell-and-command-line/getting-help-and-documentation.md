# Getting Help & System Documentation

> **Sessions:** S4–S5 · **Objective:** *Locate, read, and use system documentation including man, info, and files in /usr/share/doc* **[RHCSA Core]**
> **Related:** [Shell basics](shell-basics-and-command-syntax.md) · [Exam strategy](../linux-fundamentals/rhcsa-exam-and-certification.md)

## 1. Overview

The exam has **no internet**, so the documentation installed on the system is your only reference. Fast, targeted use of `man`, `--help` and `/usr/share/doc` can rescue tasks with unfamiliar syntax (systemd timers, nmcli, `semanage`, autofs maps).

| Need | Tool |
|---|---|
| Quick option reminder | `cmd --help` |
| Full reference for a command or config file | `man cmd`, `man 5 file` |
| Don't know the command name | `man -k keyword` (= `apropos`) |
| One-line description | `whatis cmd` (= `man -f`) |
| Help on a bash builtin (`cd`, `export`, `read`) | `help cd` |
| Long-form GNU manuals (coreutils) | `info coreutils` |
| Examples, sample configs, READMEs | `/usr/share/doc/<package>/`, `rpm -qd pkg` |
| Where is a command and what is it? | `type -a`, `which`, `whereis`, `command -v` |

## 2. Man Pages

### 2.1 Sections

| Section | Contents | RHEL examples |
|---|---|---|
| 1 | User commands | `ls`, `passwd`, `journalctl` |
| 2 | System calls | `open`, `fork` |
| 3 | Library functions | `printf`, `malloc` |
| 4 | Special files (devices) | `null`, `random` |
| 5 | **File formats & configuration** | `fstab`, `passwd`, `crontab`, `sshd_config`, `sudoers`, `systemd.timer` |
| 6 | Games | — |
| 7 | **Overviews, conventions** | `regex`, `signal`, `hier`, `systemd.time`, `nmcli-examples` |
| 8 | **System administration** | `useradd`, `fdisk`, `lvcreate`, `semanage-fcontext`, `grubby` |

Without a section number, `man` searches sections in a predefined order and opens the **first match**. When a name exists in several sections, specify it:

```bash
man passwd          # → passwd(1), the command
man 5 passwd        # → /etc/passwd file format
man -a passwd       # show all matching pages in turn (q moves to the next)
man -f passwd       # list them: passwd (1), passwd (5), …
```

> ⚠️ **Course corrections:**
> - `man 2 ls` doesn't open anything ("No manual entry for ls in section 2"), because `ls` isn't a system call.
> - `iptables` is a poor section 8 example for RHEL 10, which uses nftables/firewalld. Use `useradd` or `fdisk`.

### 2.2 Page structure

`NAME` · `SYNOPSIS` · `DESCRIPTION` · `OPTIONS` · `EXAMPLES` · `FILES` · `SEE ALSO`

**Reading SYNOPSIS:** `[ ]` optional · `…` repeatable · `a|b` choose one · **bold** type literally · *underlined/italic* replace with your value.

> **Exam tip:** Jump straight to examples with `/EXAMPLES` (or `/^EXAMPLE`).

### 2.3 Navigation (the pager is `less`)

| Key | Action | Key | Action |
|---|---|---|---|
| `Space` / `f` | Next page | `/text` | Search forward |
| `b` | Previous page | `?text` | Search backward |
| `Enter` / `j` / `↓` | Next line | `n` | Next match |
| `k` / `↑` | Previous line | `N` | **Previous match** |
| `g` / `G` | Top / bottom | `h` | Pager help |
| `q` | Quit | | |

Searches are case-insensitive when the pattern is all lowercase; an uppercase letter makes them case-sensitive.

> ⚠️ **Course corrections:** RHEL's `man` uses `less`, not `more`. `p` does not jump to the previous match; use `N`.

### 2.4 Searching

```bash
man -k partition            # search NAME lines (= apropos partition); regex allowed
man -k '^user'              # names starting with "user"
apropos -s 8 user           # restrict to section 8
man -k timer | grep -E '\((5|7|8)\)'   # filter results to config/overview/admin sections
man -K SIGHUP               # full-text search of ALL pages (slow)
man -wK -s 1 SIGHUP         # same, section 1 only, print paths
man -w bash                 # path of the man page file
```

If `man -k` returns *"nothing appropriate"*, the index is missing or stale:

```bash
sudo mandb                  # rebuild the man index (normally refreshed automatically)
```

### 2.5 Man pages worth knowing for the exam

| Task | Page |
|---|---|
| nmcli syntax and ready-made examples | `man nmcli-examples` (7), `man nmcli` |
| fstab fields and options | `man 5 fstab`, `man 8 mount` |
| cron syntax | `man 5 crontab` |
| systemd timer units / `OnCalendar` format | `man 5 systemd.timer`, `man 7 systemd.time` |
| SELinux file contexts (has EXAMPLES) | `man 8 semanage-fcontext`, `man 8 semanage-port`, `man 8 restorecon` |
| sudo rules | `man 5 sudoers` |
| SSH server options | `man 5 sshd_config` |
| autofs maps | `man 5 auto.master`, `man 5 autofs` |
| firewalld rich rules | `man 5 firewalld.richlanguage` |
| Time client | `man 5 chrony.conf` |
| Journal persistence | `man 5 journald.conf` |
| LVM | `man 8 lvm`, `man 8 lvcreate`, `man 8 lvextend` |
| Bootloader | `man 8 grubby` |
| Flatpak | `man flatpak`, `man flatpak-remote-add` |

## 3. Other Help Sources

### `--help`

```bash
ls --help | less            # option summary from the program itself
ls --help | grep -i sort    # find one option fast
```

### `help` (bash builtins)

```bash
help                        # list builtins
help cd                     # builtins have no separate man page; `man cd` opens the bash builtins page
help -d read                # one-line description
```

### `info`

GNU projects keep their full manuals in Texinfo. Requires the `info` package.

```bash
info coreutils              # whole coreutils manual
info coreutils 'ls invocation'   # jump to a node
```

Keys: `Enter` follow link · `n`/`p` next/previous node · `u` up · `l` back · `/` search · `q` quit.

### `whatis` / `apropos`

```bash
whatis chmod                # chmod (1) - change file mode bits
                            # chmod (2) - change permissions of a file  (if dev man pages installed)
apropos network             # every page whose NAME line matches "network"
```

### `/usr/share/doc`

```bash
ls /usr/share/doc/                       # one directory per package
rpm -qd openssh-server                   # docs shipped by a package
rpm -qf "$(command -v sshd)"             # which package owns a command
dnf provides '*/semanage'                # which package would provide it
```

- Holds READMEs, changelogs, licenses and sometimes **sample configuration files**.
- Some packages ship docs in a separate `-doc` subpackage.
- Container and minimal images may be built with `tsflags=nodocs`, which leaves no man pages or docs.

## 4. Locating Commands: `type` vs `which` vs `whereis`

| Command | Searches | Knows aliases/builtins/functions? | Typical output |
|---|---|---|---|
| `type -a ls` | Shell's own lookup (builtin) | **Yes**, authoritative for "what will run" | `ls is aliased to 'ls --color=auto'` / `ls is /usr/bin/ls` |
| `command -v ls` | Same lookup; POSIX | Yes | `alias ls='ls --color=auto'`; use in scripts |
| `which ls` | `$PATH` executables | Not inherently | `/usr/bin/ls` |
| `whereis ls` | Standard binary, source and man directories | No | `ls: /usr/bin/ls /usr/share/man/man1/ls.1.gz` |

## 5. RHCSA Exam Focus **[RHCSA Core]**

**Offline lookup workflow** (practice until it's reflex):

1. Don't know the command → `man -k <keyword>` (add `-s 5`/`-s 8` or `grep` to narrow).
2. Know the command → `cmd --help`, then `man cmd`, then `/EXAMPLES`.
3. Config file syntax → `man 5 <file>`.
4. Still stuck → `/usr/share/doc/<pkg>/` and `rpm -qd <pkg>`.

**Practice drills:**

- Find the `OnCalendar` syntax for "every day at 02:30" using only man pages.
- Find an nmcli example for a static IPv4 address.
- Find the `semanage fcontext` example for a custom web directory.
- Find which section documents `/etc/fstab` and what its 5th and 6th fields mean.

## 6. Production Practices **[Production Practice]**

- Read the man page for **your installed version**. Online pages (man7.org, upstream docs) can describe newer or different options than RHEL ships.
- `rpm -qd` and `/usr/share/doc` often contain vendor examples that are safer starting points than random snippets.
- When docs are missing on a minimal host, check `tsflags=nodocs` in `/etc/dnf/dnf.conf`, then reinstall the package after removing it.

## 7. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `No manual entry for X` | Wrong section; the package has no man page; docs excluded (`nodocs`); man pages in a separate package | `man -k X`; `rpm -qd pkg`; `dnf provides '*/X.*.gz'`; reinstall without `nodocs` |
| `man -k`: *nothing appropriate* | Missing or stale index | `sudo mandb` |
| `info: command not found` | `info` package not installed | `dnf install info` (or use man) |
| `man cd` shows a huge bash page | `cd` is a builtin | `help cd` |
| `which` finds nothing for `cd` | Builtins aren't files on disk | `type cd` |

## 8. Interview Questions

| Question | Answer |
|---|---|
| How do you find a command when you don't know its name? | `man -k keyword` / `apropos`, narrowed by section. |
| Why do `passwd(1)` and `passwd(5)` both exist? | One documents the command, the other the `/etc/passwd` file format. Sections separate them. |
| `which` vs `type`? | `which` searches PATH for executables. `type` is the shell's own resolution, including aliases, functions and builtins, so it shows what will actually run. |
| Where are man pages stored? | Mostly `/usr/share/man/manN/*.gz`; the index lives under `/var/cache/man`. |
| `--help` vs `man`? | `--help` is a quick summary built into the program. `man` is the full maintained reference with examples and related pages. |

## 9. Quick Revision

```bash
man -k kw | apropos -s 8 kw | man 5 file | /EXAMPLES  n  N  q
whatis cmd | help builtin | info coreutils | rpm -qd pkg | ls /usr/share/doc
type -a cmd | command -v cmd | which cmd | whereis cmd | sudo mandb
```

## 10. Cross-References

- [Shell basics](shell-basics-and-command-syntax.md)
- [Exam strategy: docs during the exam](../linux-fundamentals/rhcsa-exam-and-certification.md#4-exam-strategy-rhcsa-core)
- Package queries (`rpm -q*`, `dnf provides`): S57 (planned)
