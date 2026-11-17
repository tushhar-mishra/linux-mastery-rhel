# 073 · SELinux File Contexts: semanage fcontext, restorecon and chcon

> **You need first:** [072 · SELinux fundamentals](072-selinux-fundamentals.md)
> **Next:** [074 · SELinux booleans, ports and troubleshooting](074-selinux-booleans-ports-troubleshooting.md)

---

## What it is

Every file's SELinux label lives in its inode, in the **extended attribute** `security.selinux`. Separately, the policy contains **file-context rules**: a list of **regular expressions** (topic 017) for paths and the label each path **should** have.

| Tool | What it changes | Survives `restorecon` / a full relabel? |
|---|---|---|
| **`chcon`** | The file's label, right now | **No**: undone by the next restorecon |
| **`semanage fcontext`** | The **rule** (the expected label for a path) | **Yes**, but you must run `restorecon` to apply it to existing files |
| **`restorecon`** | Resets file labels to what the rules say | — |

**The permanent recipe is always: `semanage fcontext` (rule) + `restorecon` (apply).**

## Why it exists

Services only access files with the "right" type: the web server reads `httpd_sys_content_t`, Samba shares `samba_share_t`, and so on. When you put data in a **non-standard** place (`/srv/web`, `/data/www`), or **move** files from somewhere else, the labels are wrong and the service gets "Permission denied" or "403 Forbidden", even though rwx looks perfect. This topic is how you fix that properly, so it survives relabels and audits.

## Analogy

Labels are **colour-coded stickers** on boxes. Rules are the **warehouse map** that says "everything on aisle /var/www gets a green sticker". `chcon` is **slapping a sticker on one box by hand**; the next stock-take (`restorecon`) replaces it with whatever the map says. `semanage fcontext` **updates the map**, so every stock-take puts green stickers on aisle `/srv/web` too.

## How it works inside

- The rules come from the installed policy (`/etc/selinux/targeted/contexts/files/file_contexts`) plus **your local rules** (`file_contexts.local`, written by `semanage`; don't edit it by hand).
- `restorecon PATH` looks up the best-matching rule for each file (the most specific regex wins) and rewrites the `security.selinux` attribute if it differs. By default it only fixes the **type** field (`-F` resets everything).
- **New files** get the label of their **parent directory**, unless a policy type-transition rule says otherwise. Labelling the **directory** correctly is enough for future files.
- **`mv` keeps the inode, so it keeps the old label.** `cp` creates a new inode, which gets the destination's label. (`cp -a` deliberately keeps the source label.)
- Filesystems **without** extended attributes (VFAT, NFS, ISO images) can't store per-file labels. The whole mount gets **one** label, either from policy (`dosfs_t`, `nfs_t`, `iso9660_t`) or from the `context=` mount option.
- Two special types to recognise: **`default_t`** = the path matches no specific rule (for example a new top-level directory like `/data`); **`file_t`** / `unlabeled_t` = the file has no label at all (created while SELinux was disabled). Most confined services can read neither.

### How common operations affect labels

| Operation | Resulting label |
|---|---|
| Create a new file | The parent directory's type (or a type-transition rule) |
| `cp src dst` (creates a new file) | The destination's default |
| `cp` over an **existing** file | Keeps the existing destination file's label |
| `cp -a` / `cp --preserve=context` | Keeps the **source's** label |
| **`mv`** (same filesystem) | **Keeps the source's label** → classic 403 |
| `tar` without `--selinux` | The default label for where the files land |
| `tar --selinux`, `rsync -X` | Keeps the labels |

## Commands

### See current vs expected labels

```bash
ls -Z /var/www/html/
matchpathcon -V /var/www/html/*
sudo restorecon -Rnv /var/www/html        # -n = dry run: what WOULD change
```
```
unconfined_u:object_r:user_home_t:s0 index.html
/var/www/html/index.html has context unconfined_u:object_r:user_home_t:s0, should be system_u:object_r:httpd_sys_content_t:s0
Would relabel /var/www/html/index.html from unconfined_u:object_r:user_home_t:s0 to unconfined_u:object_r:httpd_sys_content_t:s0
```

### Fix files that were moved into the right place

```bash
sudo restorecon -Rv /var/www/html
```
```
Relabeled /var/www/html/index.html from unconfined_u:object_r:user_home_t:s0 to unconfined_u:object_r:httpd_sys_content_t:s0
```
- This is the most common SELinux fix of all. The 403 from topic 072's lab is now gone.

### Serve content from a custom directory (permanent)

```bash
sudo mkdir -p /srv/web && echo 'Hello' | sudo tee /srv/web/index.html
ls -dZ /srv/web
sudo semanage fcontext -a -t httpd_sys_content_t '/srv/web(/.*)?'
sudo restorecon -Rv /srv/web
ls -dZ /srv/web ; ls -Z /srv/web
```
```
unconfined_u:object_r:var_t:s0 /srv/web
Relabeled /srv/web from unconfined_u:object_r:var_t:s0 to unconfined_u:object_r:httpd_sys_content_t:s0
Relabeled /srv/web/index.html from unconfined_u:object_r:var_t:s0 to unconfined_u:object_r:httpd_sys_content_t:s0
unconfined_u:object_r:httpd_sys_content_t:s0 /srv/web
unconfined_u:object_r:httpd_sys_content_t:s0 index.html
```
- `'/srv/web(/.*)?'` = "the directory `/srv/web` itself, **optionally** followed by `/` and anything below". It's a **regex** matched against the **full path**: always quote it.

| Command | Purpose |
|---|---|
| `semanage fcontext -a -t TYPE 'REGEX'` | Add a rule |
| `semanage fcontext -m -t TYPE 'REGEX'` | Modify an existing local rule |
| `semanage fcontext -d 'REGEX'` | Delete a local rule (then `restorecon` to revert the files) |
| `semanage fcontext -a -e /var/www /srv/web` | **Equivalence**: label `/srv/web` exactly like `/var/www`, sub-paths included |
| `semanage fcontext -l` | All rules (huge) |
| **`semanage fcontext -l -C`** | **Only your local customisations** |
| `restorecon -Rv DIR` | Apply the rules recursively, verbosely |
| `restorecon -RFv DIR` | Also reset the user and role fields |

### Find the right type for a custom path

Look at what the **standard** path uses, and copy it:
```bash
sudo semanage fcontext -l | grep -E '^/var/www(\(|/)' | head -5
```
```
/var/www(/.*)?                                     all files          system_u:object_r:httpd_sys_content_t:s0
/var/www(/.*)?/logs(/.*)?                          all files          system_u:object_r:httpd_log_t:s0
/var/www/[^/]*/cgi-bin(/.*)?                       all files          system_u:object_r:httpd_sys_script_exec_t:s0
/var/www/calamaris(/.*)?                           all files          system_u:object_r:calamaris_www_t:s0
/var/www/cgi-bin(/.*)?                             all files          system_u:object_r:httpd_sys_script_exec_t:s0
```

### Common file types

| Type | Used for |
|---|---|
| `httpd_sys_content_t` | Web content the web server may **read** |
| `httpd_sys_rw_content_t` | Web content it may **write** (uploads, caches) |
| `httpd_log_t` | Web server logs |
| `public_content_t` / `public_content_rw_t` | Shared read / write by FTP, HTTP and Samba |
| `samba_share_t` | Samba shares (topic 080) |
| `nfs_t` | Files on NFS mounts |
| `user_home_t` / `user_home_dir_t` | Home content / the home directory itself |
| `ssh_home_t` | `~/.ssh` (topic 065) |
| `etc_t`, `var_log_t`, `tmp_t` | /etc, logs, temp files |
| `container_file_t` | Files usable by containers (topic 101) |

### chcon: quick test only

```bash
sudo chcon -t httpd_sys_content_t /data/test.html       # change now (testing)
sudo chcon --reference=/var/www/html /data/test.html    # copy another file's label
sudo restorecon -v /data/test.html                       # back to what the rules say
```

### Labels on filesystems without xattrs

```bash
sudo mount -o context="system_u:object_r:httpd_sys_content_t:s0" /dev/vdb3 /srv/usb
```
```
# /etc/fstab
nfs1:/export/web  /var/www/html/shared  nfs  context="system_u:object_r:httpd_sys_content_t:s0"  0 0
```
- Often a **boolean** is simpler: `setsebool -P httpd_use_nfs on` lets the web server read `nfs_t` (topic 074).

### Full relabel

```bash
sudo touch /.autorelabel && sudo reboot      # relabel everything at the next boot
sudo restorecon -RFv /                       # online full relabel (slow)
```
You need this after re-enabling SELinux, after rescue-mode edits (topic 057), or when files show `file_t`/`unlabeled_t`.

### Try it
1. Put a file in your home, `mv` it into `/var/www/html`, `curl localhost/file` (403), fix it with `restorecon`, and `curl` again.
2. Serve `/srv/web` with a `semanage fcontext` rule; check `semanage fcontext -l -C`.
3. Label a test file with `chcon`, then run `restorecon` and watch it revert.
4. Run `restorecon -Rnv /etc` to see whether anything in `/etc` is mislabelled.

## Where you'll use it

- **Custom data paths** for web servers, databases (`/data/pgsql` needs `postgresql_db_t`), Samba, FTP and logs.
- **Deployments** that `mv` or untar artifacts into place: add `restorecon -R` as the final deployment step (Ansible has `sefcontext` and `selinux` modules for the rule).
- **Restores from backup** without `--selinux`/`-X`: relabel afterwards.
- **Containers:** Podman's `-v /data:/data:Z` relabels a host directory to `container_file_t` with the container's private categories; `:z` makes it shareable between containers (topic 101).

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| The web server returns 403 on a file with correct rwx | Wrong type (`user_home_t` after `mv`, `default_t` on a new path) | `restorecon -Rv`; add a rule for custom paths |
| A label "fixed" with chcon came back wrong later | restorecon or an autorelabel reverted it | Add a `semanage fcontext` rule |
| `restorecon` changes nothing | No rule matches, or the regex is wrong | `semanage fcontext -l -C`; check that the regex matches the full path |
| `File context for … already defined` | The rule already exists | `semanage fcontext -m …` |
| A new directory shows `default_t` | No rule for it | Add a rule, then `restorecon` |
| Files show `file_t` / `unlabeled_t` | Created while SELinux was disabled | `touch /.autorelabel; reboot` |
| A container can't read a bind-mounted directory | Host label not usable by `container_t` | Mount with `:Z` (private) or `:z` (shared) |

## Quick recap

- Labels live in xattrs; **rules** (regex → type) say what they should be. `restorecon` applies the rules.
- Permanent: `semanage fcontext -a -t TYPE 'DIR(/.*)?'` + `restorecon -Rv DIR`. `chcon` is for testing only.
- `mv` and `cp -a` keep labels; `cp` takes the destination's default. Fix moved files with `restorecon -Rv`.
- Tools: `ls -Z`, `matchpathcon -V`, `restorecon -Rnv` (dry run), `semanage fcontext -l -C`, `touch /.autorelabel`.

**Interview questions**

1. *`chcon` vs `semanage fcontext`?* `chcon` changes a file's label immediately but is undone by the next restorecon or relabel. `semanage fcontext` changes the rule, so the label is permanent once `restorecon` applies it.
2. *Why do files moved into `/var/www/html` often give 403?* `mv` keeps the file's original label (for example `user_home_t`), which httpd isn't allowed to read. `restorecon -Rv /var/www/html` fixes it.
3. *What does `'/srv/web(/.*)?'` mean in a file-context rule?* The directory `/srv/web` itself plus everything beneath it: it's a regex that must match the full path.
