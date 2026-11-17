# 005 · Getting Help: man, --help, info and /usr/share/doc

> **You need first:** [004 · Your first commands](004-your-first-commands.md)
> **Next:** [006 · The filesystem tree](006-the-filesystem-tree.md)

---

## What it is

Every Linux system carries its own manuals. You don't need the internet to find out how a command or config file works.

| Help source | What you get |
|---|---|
| `cmd --help` | A quick list of options, printed by the program itself |
| `man cmd` | The **manual page**: the full official reference for a command or file |
| `man -k word` | A search through all manual page titles |
| `help cmd` | Help for bash **builtins** (like `cd`, `read`, `export`) |
| `info cmd` | Longer, book-style GNU manuals |
| `/usr/share/doc/<package>/` | READMEs, change logs, **sample config files** |
| `type`, `which`, `whereis` | Where a command lives and what kind it is |

## Why it exists

Nobody remembers every option of every command. Experts are fast because they know **where to look**. Manual pages on the machine also match the **exact version installed**. A random web page may describe a newer or older version with different options. During an outage you may not have internet access, but the man pages are always there.

## Analogy

`--help` is the **sticky note** on the machine. `man` is the **official user manual** in the drawer. `/usr/share/doc` is the **box the machine came in**, with example setups inside. `man -k` is the **index at the back of the manual**.

## How it works inside

### Where man pages live

Man pages are compressed text files under `/usr/share/man/manN/` (for example `/usr/share/man/man1/ls.1.gz`). When you run `man ls`:

1. `man` searches its **sections** in a fixed order and finds the first match.
2. It decompresses the file and formats it for your screen width.
3. It hands the text to a **pager**: a program that shows text one screen at a time. On Linux this is `less`.

A search index (built by the command `mandb`, stored under `/var/cache/man`) makes `man -k` fast.

### Sections

The same name can exist in several sections. For example, `passwd` is both a command and a file.

| Section | Contents | Examples |
|---|---|---|
| 1 | User commands | `ls`, `passwd`, `journalctl` |
| 2 | System calls (kernel functions) | `open`, `fork` |
| 3 | Library functions (for C programmers) | `printf`, `malloc` |
| 4 | Special device files | `null`, `random` |
| **5** | **File formats and config files** | `fstab`, `passwd`, `crontab`, `sshd_config`, `sudoers` |
| 6 | Games | — |
| **7** | **Overviews and conventions** | `regex`, `signal`, `hier`, `systemd.time` |
| **8** | **System administration commands** | `useradd`, `fdisk`, `lvcreate`, `semanage-fcontext` |

Sections 5, 7 and 8 are the admin's best friends.

### Reading a man page

Every page has the same layout: `NAME` · `SYNOPSIS` · `DESCRIPTION` · `OPTIONS` · `EXAMPLES` · `FILES` · `SEE ALSO`.

How to read the **SYNOPSIS** line:

| Symbol | Meaning |
|---|---|
| `[ ]` | Optional |
| `…` | Can repeat |
| `a\|b` | Choose one |
| **bold** | Type exactly as shown |
| *underlined/italic* | Replace with your own value |

### Moving around inside `less` (used by man)

| Key | Action | Key | Action |
|---|---|---|---|
| Space / `f` | Next page | `/text` | Search forward |
| `b` | Previous page | `?text` | Search backward |
| Enter / `j` / ↓ | Next line | `n` | Next match |
| `k` / ↑ | Previous line | `N` | Previous match |
| `g` / `G` | Top / bottom | `h` | Help |
| `q` | Quit | | |

Speed trick: open the page and type **`/EXAMPLES`** to jump to the examples.

## Commands

```bash
ls --help
```
```
Usage: ls [OPTION]... [FILE]...
List information about the FILEs (the current directory by default).
Sort entries alphabetically if none of -cftuvSUX nor --sort is specified.

Mandatory arguments to long options are mandatory for short options too.
  -a, --all                  do not ignore entries starting with .
  -A, --almost-all           do not list implied . and ..
...
  -h, --human-readable       with -l and -s, print sizes like 1K 234M 2G etc.
```
- The usage line follows SYNOPSIS rules: options are optional (`[OPTION]...`), and so are files.
- Each option is shown in its short form (`-a`) and long form (`--all`).

```bash
ls --help | grep -i sort
```
```
Sort entries alphabetically if none of -cftuvSUX nor --sort is specified.
  -c                         with -lt: sort by, and show, ctime (time of last
  -r, --reverse              reverse order while sorting
  -S                         sort by file size, largest first
      --sort=WORD            sort by WORD instead of name: none (-U), size (-S),
  -t                         sort by time, newest first; see --time
...
```
- (The real output has a few more lines; only the most useful ones are shown.)
- The `|` symbol (a **pipe**, topic 016) sends `ls --help`'s output into `grep`. `grep` keeps only the lines containing a word (topic 017). `-i` ignores upper/lower case. This is the fastest way to find one option.

```bash
man 5 fstab
```
- Opens the manual for the **file** `/etc/fstab` (section 5), not a command.

```bash
man -f passwd
```
```
passwd (1)           - change user password
passwd (1ossl)       - OpenSSL application commands
passwd (5)           - password file
```
- `-f` (same as `whatis`) lists every section that has a page with this exact name. Then you pick: `man 5 passwd`.
- `passwd (5)` (the file format) comes from the `man-pages` package. Minimal installs and cloud images often lack it, and then only `passwd (1)` appears: `sudo dnf install man-pages`, then `sudo mandb`. `1ossl` is OpenSSL's own `passwd` command.

```bash
man -k partition
```
```
addpart (8)          - tell the kernel about the existence of a partition
cfdisk (8)           - display or manipulate a disk partition table
delpart (8)          - tell the kernel to forget about a partition
fdisk (8)            - manipulate disk partition table
growpart (1)         - extend a partition in a partition table to fill availa...
...
parted (8)           - a partition manipulation program
partprobe (8)        - inform the OS of partition table changes
sfdisk (8)           - display or manipulate a disk partition table
...
```
- `-k` (same as `apropos`) searches the NAME line of **all** pages for a word. Use it when you don't know the command's name.
- Each line shows the name, the section number in brackets, and a one-line description.

```bash
apropos -s 8 user
```
```
...
useradd (8)          - create a new user or update default new user information
userdel (8)          - delete a user account and related files
usermod (8)          - modify a user account
...
```
- `-s 8` limits the search to admin commands.

```bash
sudo mandb
```
```
Purging old database entries in /usr/share/man...
Processing manual pages under /usr/share/man...
...
11890 manual pages were added.
0 stray cats were added.
0 old database entries were purged.
```
- Rebuilds the search index. Use it if `man -k` prints `nothing appropriate`. `sudo` runs a command as the administrator (topic 028).

```bash
help cd
```
```
cd: cd [-L|[-P [-e]] [-@]] [dir]
    Change the shell working directory.

    Change the current directory to DIR.  The default DIR is the value of the
    HOME shell variable. If DIR is "-", it is converted to $OLDPWD.
...
```
- Builtins have no man page of their own (`man cd` opens the giant bash manual). Use `help`.

```bash
info coreutils 'ls invocation'
```
- Opens the GNU manual section for `ls`. Keys: Enter follows a link, `n`/`p` = next/previous section, `u` = up, `q` = quit. Install the `info` package if it's missing.

```bash
ls /usr/share/doc/ | head -5
```
```
annobin-plugin
attr
audit
authselect
authselect-libs
```
- One folder per package. `head -5` shows only the first 5 lines (topic 009).

```bash
rpm -qd openssh-server
```
```
/usr/share/man/man5/moduli.5.gz
/usr/share/man/man5/sshd_config.5.gz
/usr/share/man/man8/sftp-server.8.gz
/usr/share/man/man8/sshd.8.gz
```
- Lists the **documentation files** a package installed (`-q` query, `-d` docs). On Ubuntu: `dpkg -L openssh-server | grep doc`.

### Finding out what a command really is

```bash
type -a ls ; which ls ; whereis ls
```
```
ls is aliased to `ls --color=auto'
ls is /usr/bin/ls
/usr/bin/ls
ls: /usr/bin/ls /usr/share/man/man1/ls.1.gz
```

| Command | What it searches | Notes |
|---|---|---|
| `type -a` | bash's own lookup (aliases, functions, builtins, PATH) | Tells you what **will actually run** |
| `command -v` | Same lookup, short output | Use this inside scripts |
| `which` | Only program files in PATH | Knows nothing about aliases or builtins |
| `whereis` | Standard binary and manual folders | Also shows the man page location |

### Man pages worth bookmarking

| Task | Page |
|---|---|
| Network config examples | `man nmcli-examples` |
| Disk mounts at boot | `man 5 fstab` |
| Scheduled jobs | `man 5 crontab`, `man 5 systemd.timer`, `man 7 systemd.time` |
| sudo rules | `man 5 sudoers` |
| SSH server options | `man 5 sshd_config` |
| SELinux file labels (with examples) | `man 8 semanage-fcontext` |
| Signals list | `man 7 signal` |
| Regular expressions | `man 7 regex` |
| Directory layout | `man 7 hier`, `man 7 file-hierarchy` |

### Try it
1. Using only man pages, find what the 5th and 6th fields of `/etc/fstab` mean.
2. Find a command that changes a user's password **expiry** settings using `man -k password`.
3. Run `man -f crontab`, then open the section-5 page and jump to `/EXAMPLE`.
4. Run `help` alone to see every bash builtin.

**Check your work:** on your lab VM, from the notes folder, run `sudo ./checks/check 005` for every step, or `sudo ./checks/check 005 STEP` for one (topic 002 shows how to get the notes there).

## Where you'll use it

- **Writing a config file you've never written before** (a systemd timer, an sudoers rule): `man 5 …` plus `/EXAMPLES` is quicker and safer than guessing.
- **Unfamiliar server, old version:** the installed man page tells you which options this version supports.
- **Incident without internet** (isolated networks, broken DNS): local docs are all you have.
- **Interviews:** "How would you find a command if you didn't know its name?" → `man -k`.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `No manual entry for X` | Wrong section, no page shipped, or docs were stripped (containers and minimal installs often set `tsflags=nodocs` in `/etc/dnf/dnf.conf`) | `man -k X`; `rpm -qd pkg`; remove `nodocs` and reinstall the package; check for a `-doc` package |
| `man -k` says `nothing appropriate` | Index missing or stale | `sudo mandb` |
| `info: command not found` | Package not installed | `sudo dnf install info` (or use man) |
| `man cd` opens a huge bash page | `cd` is a builtin | `help cd` |
| `which cd` prints nothing | Builtins aren't files | `type cd` |
| Container image has no man pages | Built small on purpose | Read the docs on your workstation or on a full VM |

## Quick recap

- `--help` = quick summary. `man` = full reference. `man -k` = search. `help` = builtins. `/usr/share/doc` = examples.
- Sections: 1 commands, 5 file formats, 7 overviews, 8 admin commands. `man 5 passwd` ≠ `man passwd`.
- In man: `/text` to search, `n`/`N` for next/previous, `/EXAMPLES` to jump to examples, `q` to quit.
- `type -a` shows what will actually run. `which` only searches PATH.

**Interview questions**

1. *How do you find a command if you don't know its name?* `man -k keyword` (or `apropos`), narrowed by section with `-s 8`.
2. *Why are there two `passwd` man pages?* Section 1 documents the `passwd` command; section 5 documents the `/etc/passwd` file format.
3. *`which` vs `type`?* `which` only searches PATH for program files. `type` follows the shell's own lookup (aliases, functions, builtins), so it shows what will really run.

**Scenario question** (answer out loud first, then compare)

> *"You need to change a setting in a config file you've never seen, on a server with no internet access. How do you find out what's valid?"*

**Model answer:**
1. `man -k name` to find the right page, especially **section 5** (file formats): `man 5 sshd_config`, `man 5 crontab`.
2. Inside the page, search with `/keyword` and jump to `/EXAMPLES`.
3. Check `/usr/share/doc/<package>/` for sample configs and READMEs.
4. Many tools can **test** their config before you apply it: `sshd -t`, `nginx -t`, `named-checkconf`, `visudo -c`.
5. Use `rpm -qc package` (or `dpkg -L`) to list the package's config files.

**Likely follow-ups:**
- *What if `man -k` finds nothing?* The index may be stale: run `mandb` as root. Or the man pages aren't installed (minimal images often strip them).
- *How do you get help for `cd`?* It's a builtin, so `help cd`, not `man cd`.
