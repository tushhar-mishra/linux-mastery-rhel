# File Permissions, Ownership & umask

> **Objectives:** *List, set, and change standard ugo/rwx permissions* · *Manage default file permissions* · *Diagnose and correct file permission problems* **[RHCSA Core]**
> **Related:** [Special permissions & ACLs](special-permissions-and-acls.md) · [Files & directories (`ls -l` anatomy)](../shell-and-command-line/files-and-directories.md) · [Groups](groups.md) · [Shell startup files](shell-startup-files.md) · [SELinux fundamentals](../firewall-and-selinux/selinux-fundamentals.md)

## 1. Overview

Every file has an **owner (u)**, a **group owner (g)**, and permission bits for **user, group and others**. The kernel checks them on every access. Permissions mean different things on **files** and **directories**. Most real "Permission denied" problems come from the directory rules, missing `x` on a parent directory, ACLs or SELinux, not from the file's own bits.

## 2. Key Concepts

### 2.1 Reading the mode

```
-rwxr-x---.  1 alice devs  4096 May  6 13:56 report.sh
│└┬┘└┬┘└┬┘│
│ u   g  o └ "." SELinux context · "+" ACL present
└ type: - file, d dir, l link, c char dev, b block dev, p pipe, s socket
```

### 2.2 What r, w, x mean

| Bit | On a file | On a directory |
|---|---|---|
| `r` (4) | Read contents | **List names** (`ls`) |
| `w` (2) | Modify contents | **Create, delete, rename entries** (needs `x` too) |
| `x` (1) | Execute as a program | **Enter/traverse** (`cd`), access entries by name |

Consequences:

- **Deleting a file needs `w`+`x` on its directory**, not any permission on the file itself. The sticky bit adds an exception (see [special permissions](special-permissions-and-acls.md)).
- To reach `/a/b/c/file` you need **`x` on every parent directory**.
- `r` without `x` on a directory: you can list names but can't open anything inside. `x` without `r`: you can open files whose names you know, but can't list them.

### 2.3 How the kernel decides

1. If you're **root** (strictly: the process holds `CAP_DAC_OVERRIDE`): read/write are allowed regardless of bits. Execute needs at least one `x` bit set somewhere.
2. Else if your UID is the **owner**, only the **user** (owner) bits apply.
3. Else if your UID matches a **named-user ACL entry** (`user:alice:r--`), that entry applies, limited by the ACL mask.
4. Else if the **owning group** or any **named-group ACL entry** matches one of your groups, access is granted if **any** matching group entry allows the request (each limited by the mask); if groups matched but none allows it, access is **denied** and "other" is never consulted.
5. Otherwise the **other** bits apply.

The first matching class wins; the classes are **not** cumulative. If an owner has `---` and others have `rwx`, the owner is denied. Steps 3–4 only exist when the file has an ACL (`+` in `ls -l`); see [ACLs](special-permissions-and-acls.md#4-acls-posix-access-control-lists). Mandatory checks (SELinux) run **after** this algorithm allows access.

### 2.4 Octal

| Octal | Bits | Octal | Bits |
|---|---|---|---|
| 0 | `---` | 4 | `r--` |
| 1 | `--x` | 5 | `r-x` |
| 2 | `-w-` | 6 | `rw-` |
| 3 | `-wx` | 7 | `rwx` |

Common modes: `644` files, `755` directories/scripts, `600` private files (SSH keys), `700` private dirs, `640`/`750` group-readable, `664`/`775` group-writable.

## 3. Commands & Syntax

### 3.1 `chmod`

```bash
chmod 750 script.sh                  # octal: u=rwx g=r-x o=---
chmod u+x,g-w,o= file                # symbolic: add / remove / set exactly
chmod u=rw,g=rw,o=r file             # 664
chmod a+r file                       # all three classes
chmod -R u+rwX,go-rwx dir            # X = execute only on directories (and already-executable files)
chmod --reference=ref.txt target     # copy another file's mode
```

> ⚠️ **`chmod +w` (no u/g/o) is not `a+w`.** Without a class, bits that are set in your umask are left untouched. With umask 022, `chmod +w f` adds write for the **owner only**. Always name the class.

### 3.2 `chown` / `chgrp`

```bash
chown alice file                     # change owner (root only)
chown alice:devs file                # owner and group
chown :devs file    ≡  chgrp devs file
chown -R alice:devs /srv/project     # recursive
chown -h alice link                  # change a symlink itself, not its target
```

- Only **root** can change a file's owner.
- A file's owner can `chgrp` it, but only to a group they belong to.

### 3.3 umask (default permissions) **[RHCSA Core]**

New files start from `666`, directories from `777`. The umask **removes** bits: **`final = base AND NOT umask`**. It is a bit mask, not subtraction.

| umask | Files | Directories | Typical use |
|---|---|---|---|
| `0022` | `644` rw-r--r-- | `755` rwxr-xr-x | **RHEL 9/10 default for root and regular users** |
| `0002` | `664` rw-rw-r-- | `775` rwxrwxr-x | Group collaboration (RHEL 8 and earlier defaulted regular users to this) |
| `0027` | `640` rw-r----- | `750` rwxr-x--- | Hardened |
| `0077` | `600` rw------- | `700` rwx------ | Private |

```bash
umask            # 0022 (octal; RHEL 10 default for root and regular users)
umask -S         # u=rwx,g=rwx,o=rx (permissions that REMAIN allowed)
umask 027        # this shell only
```

- **RHEL 10 default: `0022` for root and regular users** (verified on RHEL 10.2: `pam_umask` in the `postlogin` PAM stack reads `UMASK 022` from `/etc/login.defs`, and `/etc/profile` no longer contains the old "UID > 199 → `umask 002`" logic). RHEL 8 and earlier gave private-group users `0002`, which is why older material says so. Always check with `umask` as the user (`su - user -c umask`).
- **Persist it:** one user → `~/.bashrc`; all users → `/etc/profile.d/umask.sh` (see [shell startup files](shell-startup-files.md)). Test with `su - user`.
- The leading digit is just octal notation; umask never masks SUID/SGID/sticky.

> ⚠️ **Common misconceptions:**
> - umask is **not** subtraction: "666 − 027 = 639" is wrong (639 isn't valid octal); the correct result is **640**.
> - Subtraction also fails for umask `033` (files are `644`, not `633`).
> - The umask's first digit doesn't mask special bits.

### 3.4 Creating with a mode; preserving modes

```bash
mkdir -m 750 /srv/secure      # mode set exactly, umask ignored
install -m 640 -o root -g devs src /etc/app.conf   # copy + set mode/owner in one step
cp -p src dst                 # keep mode, ownership (as root), timestamps (and ACLs)
cp -a src dst                 # archive: also keep SELinux context, links, xattrs
```

## 4. Diagnosing Permission Problems **[RHCSA Core]**

Work through these in order:

```bash
id alice                                   # 1. who is she? which groups (current session!)
namei -l /srv/project/data/report.txt      # 2. owner/mode of EVERY path component (missing x?)
ls -ld /srv/project/data; ls -l report.txt # 3. directory and file bits, owner, group
getfacl report.txt                         # 4. ACL entries and mask (look for "+")
ls -Z report.txt                           # 5. SELinux context (permission OK but still denied?)
lsattr report.txt                          # 6. immutable (i) / append-only (a) attributes
findmnt -T report.txt -o TARGET,OPTIONS    # 7. ro, noexec, nosuid mounts
sudo -u alice cat /srv/project/data/report.txt   # 8. reproduce as the user
```

| Symptom | Likely cause |
|---|---|
| Can't `cd` into a directory | Missing `x` on it or a parent |
| Can `ls` but can't open files | Directory has `r`, missing `x` |
| Can't delete own file | No `w`/`x` on the directory, sticky bit, or `chattr +i` |
| Group member denied | Hasn't re-logged in since being added; or the ACL mask limits the group |
| Correct bits but still denied | SELinux label (check `ls -Z` and `ausearch -m avc`) |
| `./script: Permission denied` | No `x`, or the filesystem is mounted `noexec` |

## 5. RHCSA Exam Focus **[RHCSA Core]**

```bash
chown harry:sysadmin /common/admin && chmod 2770 /common/admin   # typical collaboration task
chmod 640 /etc/app.conf
echo 'umask 027' >> /home/natasha/.bashrc      # "natasha's new files: 640"
su - natasha -c 'umask; touch t; ls -l t'      # verify
```

- Verify ownership **and** mode with `ls -ld` on directories (plain `ls -l dir` lists the contents).
- Test access as the target user (`su - user`), not as root; root bypasses most checks.

## 6. Production Practices **[Production Practice]**

- Never fix access problems with `chmod 777`. Find the real requirement (group, ACL, SELinux).
- Shared data goes in `/srv` or a dedicated mount, not in home directories (RHEL homes are `700`).
- Keep secrets `600`/`640` and owned by the service account; check with `find / -xdev -perm -o+w -type f`.
- Use `install -m` or configuration management to set modes deterministically.

## 7. Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `chown: changing ownership …: Operation not permitted` | Non-root changing the owner | `sudo chown` |
| `chgrp: … Operation not permitted` | Owner not in the target group | Add them to the group, or use root |
| New files have unexpected modes | umask (and default ACLs) | `umask`; `getfacl -d dir` |
| `chmod` seems to do nothing on a file with `+` | Group bits map to the ACL **mask** | `getfacl`; adjust the entries or mask |
| Permissions correct, service still denied | SELinux | `ls -Z`; `restorecon` ([file contexts](../firewall-and-selinux/selinux-file-contexts.md)) |

## 8. Interview Questions

| Question | Answer |
|---|---|
| What does `x` mean on a directory? | Permission to traverse it and access entries by name. |
| Why can a user delete a root-owned file? | Deletion needs `w`+`x` on the **directory**; without the sticky bit, file ownership doesn't matter. |
| Are permission classes cumulative? | No. The first matching class (owner → group → other) decides. |
| How is the umask applied? | `base AND NOT umask` (files from 666, directories from 777). |
| `chmod -R 755` vs `chmod -R u+rwX,go+rX`? | The first makes every file executable; `X` adds execute only to directories and already-executable files. |
| Can root read a `000` file? | Yes (DAC override), but SELinux can still deny it. |

## 9. Practice Exercises (with Solutions)

| # | Task | Command | Note |
|---|---|---|---|
| 1–3 | Create, chown to root, chown back | `mkdir ~/mydocs; touch ~/mydocs/readme.txt; sudo chown root:root …; sudo chown $USER:$USER …` | ✔ |
| 4 | u=rwx, g=rx, o=r | `chmod 754 ~/mydocs/readme.txt` | ✔ |
| 5 | `~/projects` for group developers | `chmod 770 ~/projects; sudo chown $USER:developers ~/projects` | ⚠️ Group members still can't reach it: RHEL home dirs are `700`. Use `/srv/projects` for shared data |
| 6–7 | Root's `admin.txt`; user edits it | Edit fails (root-owned `644`) | Use `vi`; `nano` may not be installed |
| 8 | Chown all files to yourself | `sudo chown $USER:$USER ~/projects/*` | |
| 9 | "Can't delete admin.txt unless root" | ✘ **Wrong** | The user owns `~/projects` (rwx), so they **can** delete any file in it; only the sticky bit prevents that |
| 10 | Files rw for user+group, none for others | `umask 007` | ✔ (files 660, dirs 770) |
| 11 | Show umask | `umask` · `umask -S` | ✔ |
| 12 | `/tmp/confidential.txt` mode 400 (root) | `sudo chmod 400 …` | Normal users can't read it ✔ |
| 13 | Group-owned writable file | `sudo chown $USER:admins f; chmod 664 f` | ✔ |
| 14 | SGID on `~/projects` | `chmod g+s ~/projects` | Affects **new** files only |
| 15 | Default perms of a new file | Depends on umask | RHEL 10 default umask `0022` → `rw-r--r--` (or `rw-rw----` if `umask 007` from task 10 is still active in that shell) |
| 16 | 750 | `chmod 750 devfile.txt` | ✔ |
| 17 | Can users delete others' files? | Yes, with `w`+`x` on the directory | ✘ Course says no; only the sticky bit restricts it |

## 10. Quick Revision

```bash
r=4 w=2 x=1 | dir: r=list w=create/delete(+x) x=traverse | owner→group→other, first match wins
chmod 750 f | chmod u+x,g-w,o= f | chmod -R u+rwX,go-rwx d | chown u:g f | chgrp g f
umask 0022→644/755 (RHEL 10 default) · 0002→664/775 · 0027→640/750 | base AND NOT umask | ~/.bashrc, /etc/profile.d/
namei -l path | getfacl | ls -Z | lsattr | findmnt -T  (diagnosis order)
```

## 11. Cross-References

- [Special permissions & ACLs](special-permissions-and-acls.md)
- [Links](links.md)
- [Files & directories](../shell-and-command-line/files-and-directories.md)
- [Groups](groups.md) · [Shell startup files (persisting umask)](shell-startup-files.md)
- [SELinux file contexts](../firewall-and-selinux/selinux-file-contexts.md)
