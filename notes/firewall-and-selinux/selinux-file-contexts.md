# SELinux File Contexts: chcon, semanage fcontext & restorecon

> **Objectives:** *Restore default file contexts* · *List and identify SELinux file and process context* · supports *Diagnose and correct file permission problems* **[RHCSA Core]**
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

You need this after re-enabling SELinux, after editing files from rescue mode, and after a policy type change.

## 8. Common File Types

| Type | Used for |
|---|---|
| `httpd_sys_content_t` | Web content (read-only for httpd) |
| `httpd_sys_rw_content_t` | Web content httpd may write (uploads) |
| `public_content_t` / `public_content_rw_t` | Shared by FTP/HTTP/Samba (read / write) |
| `samba_share_t` | Samba shares |
| `nfs_t` | NFS-mounted files |
| `user_home_t` / `user_home_dir_t` | Home content / home directory |
| `ssh_home_t` | `~/.ssh` |
| `etc_t`, `var_log_t`, `tmp_t`, `user_tmp_t` | /etc, logs, temp files |
| `container_file_t` | Volumes used by containers |

Find the right type: `semanage fcontext -l | grep <standard path>` (e.g., `/var/www`), then copy that type to your custom path.

## 9. RHCSA Exam Focus **[RHCSA Core]**

- Custom web, FTP or Samba directory → `semanage fcontext -a -t TYPE 'DIR(/.*)?'` + `restorecon -Rv DIR`.
- Files moved into a service directory → `restorecon -Rv DIR`.
- Verify with `ls -Z`, then test the service (`curl`), and check `ausearch -m avc -ts recent` if it still fails.
- Don't use `chcon` as the final answer; it won't survive a relabel.

## 10. Production Practices **[Production Practice]**

- Prefer standard locations (`/var/www`, `/srv/<service>` with rules).
- Document local rules (`semanage fcontext -l -C`) and keep them in configuration management (e.g., Ansible `selinux` system role).
- Back up and restore with tools that keep xattrs (`tar --selinux --xattrs`, `rsync -aX`), or relabel after restoring.

## 11. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| httpd 403 on a file with correct rwx | Wrong type (e.g., `user_home_t` after `mv`, `samba_share_t`) | `restorecon -Rv /var/www/html` |
| Label "fixed" with chcon reverted later | `restorecon`/autorelabel | Add a `semanage fcontext` rule |
| `restorecon` changes nothing | No matching rule, or rule added for the wrong path | `semanage fcontext -l -C`; check the regex covers the path |
| `ValueError: File context for … already defined` | Rule exists | `semanage fcontext -m …` |
| New dir shows `default_t` | No rule for that path | Add a rule; `restorecon` |
| Files show `unlabeled_t`/`file_t` | Created with SELinux disabled | `touch /.autorelabel; reboot` |

## 12. Interview Questions

| Question | Answer |
|---|---|
| `chcon` vs `semanage fcontext`? | chcon changes a file's label now; semanage fcontext changes the policy rule so `restorecon`/relabels keep the label. |
| Why do files moved into `/var/www/html` fail? | `mv` keeps the original label (`user_home_t`); httpd isn't allowed to read it. `restorecon` fixes it. |
| What does `'(/.*)?'` mean? | The directory itself plus everything beneath it. |
| How do you see only your custom rules? | `semanage fcontext -l -C`. |
| `default_t` vs `file_t`? | default_t = no matching rule; file_t = no label at all. |

## 13. Quick Revision

```bash
ls -Z · ls -dZ · matchpathcon -V PATH · restorecon -Rnv DIR (dry run) · semanage fcontext -l [-C]
semanage fcontext -a|-m -t TYPE 'DIR(/.*)?' → restorecon -Rv DIR · semanage fcontext -d 'REGEX' · -e (equivalence)
chcon -t TYPE [-R] (testing; undone by restorecon) · cp = dest default · mv / cp -a = keep source · tar --selinux · rsync -X
mount -o context="…" · touch /.autorelabel · fixfiles -F onboot
```

## 14. Cross-References

- [SELinux fundamentals](selinux-fundamentals.md)
- [Booleans, ports & troubleshooting](selinux-booleans-ports-troubleshooting.md)
- [Files & directories (cp vs mv)](../shell-and-command-line/files-and-directories.md)
- [Archiving (tar --selinux)](../files-and-text-processing/archiving-and-compression.md)
- [Mounting & fstab](../storage-and-filesystems/mounting-and-fstab.md)
