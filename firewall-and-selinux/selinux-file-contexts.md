# SELinux File Contexts: chcon, semanage fcontext & restorecon

> **Sessions:** S75–S76 · **Objectives:** *Restore default file contexts* · *List and identify SELinux file and process context* · supports *Diagnose and correct file permission problems* **[RHCSA Core]**
> **Related:** [SELinux fundamentals](selinux-fundamentals.md) · [Booleans, ports & troubleshooting](selinux-booleans-ports-troubleshooting.md) · [Files & directories (cp vs mv)](../shell-and-command-line/files-and-directories.md) · [Archiving (tar --selinux)](../files-and-text-processing/archiving-and-compression.md) · [Mounting & fstab](../storage-and-filesystems/mounting-and-fstab.md)

## 1. Overview

Every file's SELinux label is stored in its **extended attribute** `security.selinux`. The policy also contains **file-context rules** (regular expressions → default labels) that say what each path *should* be labeled. `restorecon` applies those rules; `semanage fcontext` adds your own rules; `chcon` changes a label directly without changing any rule.

| Tool | Changes | Survives `restorecon` / relabel? |
|---|---|---|
| `chcon` | The file's current label only | **No** (reverted) |
| `semanage fcontext` | The **rule** (default label for a path) | **Yes**, but you must run `restorecon` to apply it |
| `restorecon` | Resets labels to match the rules | — |

`chcon` labels survive a reboot (they're stored on disk), but any `restorecon` or full relabel undoes them. Persistent changes therefore use `semanage fcontext` + `restorecon`.

## 2. Viewing Labels & Rules

```bash
ls -Z /var/www/html/index.html        # current label of a file
ls -dZ /srv/web                       # label of the directory itself
matchpathcon -V /var/www/html/*       # current vs expected label ("verified" or "should be …")
restorecon -Rnv /srv/web              # dry run: what restorecon WOULD change
semanage fcontext -l | grep '/var/www'   # rules from policy + local
semanage fcontext -l -C               # only YOUR local customizations
cat /etc/selinux/targeted/contexts/files/file_contexts.local   # where local rules are stored (don't edit by hand)
```

### Special types

| Type | Meaning |
|---|---|
| `default_t` | Path matches no specific rule (e.g., a new top-level directory like `/testdir`) |
| `file_t` | File has **no label at all** (e.g., created while SELinux was disabled) |

Most confined services can't read either. Fix them with proper rules + `restorecon`.

## 3. Persistent Labeling: `semanage fcontext` + `restorecon` **[RHCSA Core]**

```bash
# Serve web content from /srv/web
mkdir -p /srv/web ; echo 'Hello' > /srv/web/index.html
semanage fcontext -a -t httpd_sys_content_t '/srv/web(/.*)?'   # rule for the dir AND everything below
restorecon -Rv /srv/web                                        # apply it
ls -dZ /srv/web ; ls -Z /srv/web                               # httpd_sys_content_t
```

| Command | Purpose |
|---|---|
| `semanage fcontext -a -t TYPE 'REGEX'` | Add a rule |
| `semanage fcontext -m -t TYPE 'REGEX'` | Modify an existing local rule |
| `semanage fcontext -d 'REGEX'` | Delete a local rule (then `restorecon` to revert files) |
| `semanage fcontext -a -e /var/www /srv/web` | **Equivalence**: label `/srv/web` like `/var/www` **[Advanced]** |
| `restorecon -v FILE` / `-Rv DIR` | Apply rules (verbose / recursive) |
| `restorecon -RFv DIR` | Also reset the user/role fields (normally only the type is changed) |

- `'(/.*)?'` means "this directory, optionally followed by anything below it". Always quote the regex.
- The regex must match the **full path**, from `/`.

## 4. Direct Changes: `chcon` (testing only)

```bash
chcon -t httpd_sys_content_t /testdir/file.txt
chcon -R -t httpd_sys_content_t /testdir/
chcon --reference=/var/www/html /srv/web/index.html   # copy another file's label
restorecon -Rv /testdir                               # undo: back to the rule's label
```

## 5. How Operations Affect Labels

| Operation | Resulting label |
|---|---|
| Create a new file | **Inherits** the parent directory's type (unless a type-transition rule says otherwise) |
| `cp src dst` (new file) | Destination directory's default (like a new file) |
| `cp` over an **existing** file | Keeps the **existing destination** file's label |
| `cp -a` / `cp --preserve=context` | Keeps the **source** label |
| `cp --context=CTX src dst` | Sets the label you specify |
| `mv src dst` (same filesystem) | **Keeps** the source label → classic web-server "403" problem |
| `tar` without `--selinux` | Extracted files get the default label for their location |
| `tar --selinux -cf/-xf`, `rsync -X` | Preserve labels |

**Classic fix after `mv`:** `restorecon -Rv /var/www/html/`.

## 6. Labels on Mounted Filesystems

Filesystems without SELinux xattrs (VFAT, NFS, ISO) get **one** label for everything, from policy (e.g., `nfs_t`, `dosfs_t`, `iso9660_t`) or from mount options:

```bash
mount -o context="system_u:object_r:httpd_sys_content_t:s0" /dev/sdb1 /mnt/web
# /etc/fstab
server:/export  /var/www/html/shared  nfs  context="system_u:object_r:httpd_sys_content_t:s0"  0 0
```

| Option | Effect |
|---|---|
| `context=` | Label for every file (overrides xattrs) |
| `fscontext=` | Label of the filesystem object itself |
| `defcontext=` | Label for files **without** a label (xattr-capable FS) |
| `rootcontext=` | Label of the mount's root inode |

Often a **boolean** is simpler, e.g. `setsebool -P httpd_use_nfs on` to let httpd read `nfs_t`.

## 7. Full System Relabel

```bash
touch /.autorelabel ; reboot          # relabel everything at next boot
fixfiles -F onboot ; reboot            # same, forcing full contexts
restorecon -RFv /                      # online full relabel (slow; large systems)
```

You need this after re-enabling SELinux, after editing files from rescue mode, and after a policy type
