# 026 · File Permissions, Ownership and umask

> **You need first:** [025 · Shell startup files](025-shell-startup-files.md)
> **Next:** [027 · Special permissions, ACLs and attributes](027-special-permissions-acls-and-attributes.md)

---

## What it is

Every file and directory has:
- an **owner** (a user, shown as **u**),
- a **group owner** (shown as **g**),
- and three sets of **permission bits**: for the owner (**u**), for the group (**g**), and for everyone else, "others" (**o**).

Each set has three bits: **r** (read), **w** (write) and **x** (execute). This model is called **DAC** (Discretionary Access Control): "discretionary" because the file's owner decides who gets access.

- **`chmod`** (change mode) sets the permission bits.
- **`chown`** / **`chgrp`** change the owner / group.
- **`umask`** (user file-creation mask) decides the **default** permissions of new files.

## Why it exists

Many users and services share one machine. Permissions stop Alice from reading Bob's mail, stop a hacked web server from changing system files, and keep SSH private keys secret. Get them too loose and you leak data; too tight and services break with "Permission denied".

## Analogy

Each file is a **room with three doors**: one for the **owner**, one for **members of the group**, and one for **everybody else**. Each door has three switches: may **look in** (r), may **change things** (w), may **use the machine inside** (x).

A **directory is a corridor**: `x` lets you **walk through** it, `r` lets you **read the name plates** on the doors, and `w` lets you **add or remove doors** (create, delete or rename files).

## How it works inside

### Reading the mode

```
-rwxr-x---.  1 alice devs  4096 May  6 13:56 report.sh
│└┬┘└┬┘└┬┘│
│ u   g  o └─ "." = SELinux label (topic 072) · "+" = extra ACL entries (topic 027)
└─ type: - file, d directory, l link …
```
Here: the owner `alice` has `rwx`, group `devs` has `r-x`, others have `---`.

### What r, w, x mean

| Bit | Value | On a file | On a directory |
|---|---|---|---|
| `r` | 4 | Read the contents | **List** the names inside (`ls`) |
| `w` | 2 | Change the contents | **Create, delete, rename** entries (needs `x` too) |
| `x` | 1 | Run it as a program | **Enter/pass through** it (`cd`), reach entries by name |

What follows:
- **Deleting a file needs `w` + `x` on its directory**, and no permission at all on the file itself (unless the sticky bit is set, topic 027).
- To reach `/a/b/c/file` you need **`x` on every directory along the path**. A missing `x` on `/a` blocks everything below it.
- `r` without `x` on a directory: you can list names but can't open anything. `x` without `r`: you can open a file if you know its exact name, but can't list.

### How the kernel decides (on every open)

1. **root** (more precisely, a process with the "override file permissions" **capability**, `CAP_DAC_OVERRIDE`; topic 092): read and write are always allowed. Execute needs at least one `x` bit set somewhere.
2. Else, if your UID is the file's **owner** → only the **owner** bits are used.
3. Else, if the file's **group** is one of your groups → only the **group** bits are used. (ACL entries, topic 027, plug in here.)
4. Otherwise → the **others** bits are used.

**The first matching class wins, and the classes don't add up.** If the owner has `---` and others have `rwx`, the owner is **denied**.

After this check passes, **SELinux** (topic 072) can still deny access. It's a second, separate gate.

### Octal numbers

Add the bits: r=4, w=2, x=1. One digit per class.

| Octal | Bits | Octal | Bits |
|---|---|---|---|
| 0 | `---` | 4 | `r--` |
| 1 | `--x` | 5 | `r-x` |
| 2 | `-w-` | 6 | `rw-` |
| 3 | `-wx` | 7 | `rwx` |

Common modes: `644` normal files, `755` directories and scripts, `600` private files (SSH keys), `700` private directories, `640`/`750` readable by the group, `664`/`775` writable by the group.

### umask: default permissions

A new **file** starts from `666` (`rw-rw-rw-`; never executable by default). A new **directory** starts from `777`. The umask **removes** bits:

**final = base AND NOT umask** (a bit mask, **not** subtraction).

| umask | New files | New directories | Use |
|---|---|---|---|
| `0022` | `644` | `755` | **RHEL 10 and Ubuntu default** |
| `0002` | `664` | `775` | Group collaboration (older RHEL gave this to normal users) |
| `0027` | `640` | `750` | Hardened |
| `0077` | `600` | `700` | Private |

Subtraction gives wrong answers: with umask `027`, files are `640` (not "666−027=639"). With umask `033`, files are `644` (not 633). Think "which bits does the mask switch off?"

The umask is a property of each **process**, inherited from its parent.
- **Login sessions** (console, SSH): PAM sets it. `pam_umask` sits in `/etc/pam.d/postlogin` (a symlink managed by authselect, topic 029) and reads `UMASK 022` from `/etc/login.defs`. Change that line to `027` and the next login gets `0027`.
- **Services**: they get theirs from systemd (`UMask=` in the unit, default `0022`, topic 098).
- `/etc/bashrc` only steps in if the umask is `0`.

## Commands

### chmod

```bash
chmod 750 script.sh
ls -l script.sh
```
```
-rwxr-x---. 1 alice alice 120 Nov 16 12:30 script.sh
```

```bash
chmod u+x,g-w,o= file        # symbolic: add (+), remove (-), set exactly (=)
chmod u=rw,g=rw,o=r file     # = 664
chmod a+r file               # a = all three classes
chmod -R u+rwX,go-rwx dir    # X = execute ONLY on directories (and files already executable)
chmod --reference=a.txt b.txt   # copy a's mode to b
```

**`chmod +w file` (no class) is not `a+w`.** Without u/g/o, bits blocked by your umask are left alone, so with umask 022 it only adds write for the owner. Always name the class.

**`chmod -R 755 dir` makes every file executable.** Usually you want directories `755` and files `644`:
```bash
find dir -type d -exec chmod 755 {} +
find dir -type f -exec chmod 644 {} +
```
or `chmod -R u=rwX,go=rX dir`.

### chown and chgrp

```bash
sudo chown alice file                 # change the owner (root only)
sudo chown alice:devs file            # owner and group
sudo chown :devs file                 # group only (same as chgrp devs file)
sudo chown -R nginx:nginx /srv/www    # recursive
sudo chown -h alice link              # change the symlink itself, not its target
```
- Only **root** can change the owner (otherwise users could dodge disk quotas or frame others).
- The owner can `chgrp` a file, but only to a group they belong to.

### umask

```bash
umask ; umask -S
```
```
0022
u=rwx,g=rx,o=rx
```
- `-S` shows the permissions that **stay allowed** for directories.

```bash
umask 027 ; touch f ; mkdir d ; ls -ld f d
```
```
drwxr-x---. 2 alice alice 6 Nov 16 12:31 d
-rw-r-----. 1 alice alice 0 Nov 16 12:31 f
```
- This only lasts for the current shell. Make it permanent in `~/.bashrc` (one user) or `/etc/profile.d/umask.sh` (everyone), then test with `su - user -c umask`.

### Setting modes exactly when creating

```bash
mkdir -m 750 /srv/secure                          # ignores the umask
install -m 640 -o root -g devs app.conf /etc/app.conf   # copy + owner + mode in one step
cp -p src dst                                     # keep mode, owner (as root), timestamps
cp -a src dst                                     # also keep SELinux label, links, xattrs
```

### Diagnosing "Permission denied": a checklist

Work down this list in order:

```bash
id alice                                    # 1. her UID and groups (current session!)
namei -l /srv/project/data/report.txt       # 2. owner and mode of EVERY part of the path
ls -ld /srv/project/data ; ls -l report.txt # 3. directory and file bits
getfacl report.txt                          # 4. ACL entries and mask (look for "+", topic 027)
ls -Z report.txt                            # 5. SELinux label (topic 072)
lsattr report.txt                           # 6. immutable / append-only attributes (topic 027)
findmnt -T report.txt -o TARGET,OPTIONS     # 7. read-only (ro) or noexec mounts (topic 048)
sudo -u alice cat /srv/project/data/report.txt   # 8. reproduce it as the user
```

```bash
namei -l /srv/project/data/report.txt
```
```
f: /srv/project/data/report.txt
dr-xr-xr-x root  root  /
drwxr-xr-x root  root  srv
drwxr-x--- root  devs  project
drwxr-xr-x alice devs  data
-rw-r--r-- alice devs  report.txt
```
- `project` is `750` with group `devs`. A user **not** in `devs` gets no `x` on it and is stopped there, whatever `report.txt` allows.

| Symptom | Likely cause |
|---|---|
| Can't `cd` into a directory | Missing `x` on it or on a parent |
| Can `ls` but can't open files | The directory has `r` but not `x` |
| Can't delete your own file | No `w`+`x` on the directory, sticky bit, or the immutable attribute |
| A group member is denied | They haven't logged in again since being added (topic 024), or the ACL mask limits the group |
| Bits look right, still denied | SELinux (`ls -Z`, `ausearch -m avc`) |
| `./script: Permission denied` | No `x` bit, or the filesystem is mounted `noexec` |

### Try it
1. Make `/tmp/perm` with a file inside. Set the directory to `700` as user A and try to read the file as user B. Then give the directory `711` and try again with the exact file name.
2. Set a file to `---rwxrwx` (`077`) that you own, and try to read it. (Owner class wins: denied.)
3. Compute the result of umask `0027` and `0033` by hand, then check with `touch`.
4. Run `namei -l` on `/etc/ssh/sshd_config` and on your SSH key `~/.ssh/id_ed25519`.

## Where you'll use it

- **"Permission denied" incidents:** the checklist above, every time. Never "fix" with `chmod 777`: it opens the file to every user and every hacked service, and often doesn't even fix the real cause (SELinux, a parent directory).
- **SSH keys:** `~/.ssh` must be `700`, private keys `600`, `authorized_keys` `600`. sshd **refuses** keys with loose permissions (topic 065).
- **Web content:** files `644`, directories `755`, owned by a deploy user, readable by the `nginx`/`apache` user.
- **Secrets and configs:** `600` or `640`, owned by the service account.
- **Containers and Kubernetes:** a container running as UID 1001 can't write to a volume owned by root with mode `755`. That's why Kubernetes has `fsGroup`, and why images `chown` their data directories. "Permission denied" on a mounted volume is one of the most common container errors.

## When it breaks

| Error | Cause | Fix |
|---|---|---|
| `chown: … Operation not permitted` | A non-root user tried to change the owner | `sudo chown` |
| `chgrp: … Operation not permitted` | The owner isn't in the target group | Add them to the group, or use root |
| New files get unexpected permissions | The umask (or a default ACL) | `umask`; `getfacl -d dir` |
| `chmod` seems to do nothing on a file showing `+` | With ACLs, the group bits show the ACL **mask** | `getfacl` (topic 027) |
| Bits are right but the service is still denied | SELinux label | `ls -Z`; `restorecon` (topic 073) |
| sshd ignores your key | Key or directory permissions too open | `chmod 700 ~/.ssh; chmod 600 ~/.ssh/authorized_keys` |

## Quick recap

- r=4, w=2, x=1 for user, group, others. On directories: r = list, w = create/delete (needs x), x = pass through.
- The kernel checks owner → group → others; **the first match wins**. You need `x` on every parent directory. Deleting depends on the **directory**.
- `chmod 750` / `chmod u+x,g-w,o=` / `chmod -R u=rwX,go=rX`; `chown user:group`.
- umask: `final = base AND NOT umask`; RHEL 10 default `0022` → files 644, directories 755.

**Interview questions**

1. *What does `x` mean on a directory?* Permission to pass through it and reach entries inside by name (for example, with `cd` or by opening a file in it).
2. *How can a user delete a file owned by root?* Deleting changes the directory, so it only needs `w` and `x` on the directory. Only the sticky bit prevents this.
3. *How is the umask applied?* New files start at 666 and directories at 777, and the umask's bits are switched off: `base AND NOT umask`. It is not subtraction.
