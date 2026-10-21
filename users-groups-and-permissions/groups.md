# Groups & Group Membership

> **Sessions:** S24 · **Objective:** *Create, delete, and modify local groups and group memberships* **[RHCSA Core]**
> **Related:** [Local users](local-users.md) · [Passwords (gshadow)](passwords-and-aging.md) · [Special permissions (SGID directories)](special-permissions-and-acls.md) · [File permissions](file-permissions.md) · [sudo & the wheel group](sudo-and-privileged-access.md)

## 1. Overview

Groups let you grant access to many users at once. Each user has exactly **one primary group** (the GID in `/etc/passwd`, used as the group of newly created files) and any number of **supplementary groups** (listed in `/etc/group`). Group definitions live in `/etc/group`; group passwords and group administrators live in `/etc/gshadow`.

## 2. Key Concepts

### 2.1 `/etc/group` and `/etc/gshadow`

```
/etc/group:    devs:x:612:nina,leo,julian        name : password-placeholder : GID : members
/etc/gshadow:  devs:!:nina:leo,julian            name : password : ADMINS : members
```

- The member list in `/etc/group` shows **supplementary** members only. A user whose *primary* group is `devs` isn't listed there.
- Group GID ranges follow user ranges: system < 1000, regular ≥ 1000.

### 2.2 Primary vs supplementary

| | Primary group | Supplementary groups |
|---|---|---|
| Stored in | `/etc/passwd` field 4 | `/etc/group` member list |
| Count | Exactly one | Zero or more |
| Used for | Group owner of new files | Access checks |
| Change with | `usermod -g grp user` / `newgrp` (temporary) | `usermod -aG`, `gpasswd -a/-d` |

## 3. Commands & Syntax

| Task | Command |
|---|---|
| Create group | `groupadd devs` · `groupadd -g 5000 devs` · `groupadd -r appgrp` (system) |
| Rename group | `groupmod -n newname oldname` |
| Change GID | `groupmod -g 5001 devs` (files keep the old GID ⚠️) |
| Delete group | `groupdel devs` (fails if it's any user's primary group) |
| Add user to groups (keep others) | `usermod -aG devs,ops alice` |
| Replace all supplementary groups | `usermod -G devs alice` ⚠️ |
| Change primary group | `usermod -g devs alice` |
| Add / remove one member | `gpasswd -a alice devs` · `gpasswd -d alice devs` |
| Set the full member list | `gpasswd -M alice,bob devs` |
| Delegate group admin | `gpasswd -A nina devs` · clear: `gpasswd -A "" devs` |
| Show groups | `groups` · `groups alice` · `id alice` · `id -Gn alice` · `getent group devs` |
| Temporarily switch primary group | `newgrp devs` (starts a new shell; `exit` to return) |
| Edit files safely | `vigr` · `vigr -s` (gshadow) · then `grpck -r` |

```bash
groupadd -g 3001 sysadmin
usermod -aG sysadmin natasha
getent group sysadmin            # sysadmin:x:3001:natasha
id natasha                       # …groups=1002(natasha),3001(sysadmin)
```

### 3.1 Membership takes effect at login **[RHCSA Core]**

`id alice` reads the database, so it shows a new group immediately. But processes that are **already running**, including alice's current shell, keep their old group list. Alice must log in again (or `su - alice`, or `newgrp devs`) before the new group grants access.

### 3.2 Group administrators (`gpasswd -A`)

```bash
gpasswd -A nina devs          # root delegates
su - nina
gpasswd -a julian devs        # nina can now add/remove members without being root
gpasswd -d julian devs
```

Admins are stored in field 3 of `/etc/gshadow`. An admin doesn't need to be a member.

### 3.3 `newgrp`

```bash
id -gn             # alice
newgrp devs        # new shell; primary group is now devs (must be a member, or know the group password)
touch shared.txt   # group owner: devs
exit               # back to the original shell
```

For permanent shared directories, use a **set-GID directory** instead, so new files inherit the directory's group automatically (see the [collaboration directory recipe](special-permissions-and-acls.md#3-shared-collaboration-directory-recipe-rhcsa-core)).

## 4. RHCSA Exam Focus **[RHCSA Core]**

```bash
groupadd sysadmin                         # "create group sysadmin"
useradd -G sysadmin harry                 # "user harry, member of sysadmin"
usermod -aG sysadmin sarah                # "existing user sarah also a member"
groupadd -g 4000 project ; getent group project   # specific GID
```

- **Never** drop `-a` from `usermod -aG`.
- Verify with `id user` and `getent group grp`. Test access with `su - user`.
- If a task says "secondary/supplementary group", use `-G`/`-aG`; "primary group" means `-g`.

## 5. Production Practices **[Production Practice]**

- Grant access to groups, not individual users: easier audits and on/offboarding.
- Use `gpasswd -A` to delegate membership management to team leads without sudo.
- Manage groups centrally (IdM/LDAP) on fleets; local groups for service accounts.
- After `groupmod -g`, fix file ownership: `find / -xdev -gid OLD -exec chgrp -h NEW {} +`.

## 6. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| User added to a group but still "Permission denied" | Old session | Log out/in, `su - user`, or `newgrp grp` |
| User lost other groups | `usermod -G` without `-a` | Re-add with `usermod -aG` |
| `groupdel: cannot remove the primary group of user 'x'` | Group is someone's primary | Change their primary group first (`usermod -g`) |
| Files show a number as group | Group deleted or GID changed | `find / -nogroup`; `chgrp` |
| `grpck` reports mismatches | Hand edits to `/etc/group` only | Fix with `vigr` **and** `vigr -s` |
| `newgrp` asks for a password | Not a member and group has a password | Add the user to the group instead |

## 7. Interview Questions

| Question | Answer |
|---|---|
| Primary vs supplementary group? | Primary (one, from `/etc/passwd`) owns new files; supplementary groups add access rights. |
| Why doesn't a new group work for a logged-in user? | Group lists are fixed when the session starts; re-login or `newgrp`. |
| What's in `/etc/gshadow`? | Group password hash, group administrators, members. |
| `usermod -aG` vs `gpasswd -a`? | Same result for one group; `gpasswd` can be run by a delegated group admin. |
| Why might `groupdel` fail? | The group is a user's primary group. |

## 8. Course Practice (S24, corrected where needed)

| # | Task | Command | Note |
|---|---|---|---|
| 1 | Create groups | `groupadd music; groupadd photography; groupadd media` | |
| 2 | oliver into music + media | `usermod -aG music,media oliver` | ✔ |
| 3 | Rename photography | `groupmod -n photos photography` | ✔ |
| 4 | Add luna to music "with vi" | `vigr` (edit `/etc/group`), then `vigr -s` (edit `/etc/gshadow`), then `grpck -r` | Course uses plain `vi` on one file only. Normally: `usermod -aG music luna` |
| 5 | Verify | `id luna` | Running sessions need re-login |
| 6 | Delegate admin to nina | `gpasswd -A nina photos; gpasswd -A nina media` then `su - nina; gpasswd -a oliver photos` | ✔ |

## 9. Quick Revision

```bash
groupadd [-g GID] [-r] g | groupmod -n new old | groupmod -g GID g | groupdel g
usermod -aG g1,g2 u | usermod -G (replaces!) | usermod -g pri u
gpasswd -a u g | -d u g | -M u1,u2 g | -A admin g
groups u | id u | getent group g | newgrp g | vigr [-s] | grpck
/etc/group  name:x:GID:members   /etc/gshadow  name:pw:admins:members
```

## 10. Cross-References

- [Local users](local-users.md)
- [Passwords & aging](passwords-and-aging.md)
- [Shell startup files](shell-startup-files.md)
- [File permissions & umask](file-permissions.md)
- [Special permissions & ACLs (SGID collaboration directories)](special-permissions-and-acls.md)
- [sudo & privileged access (wheel)](sudo-and-privileged-access.md)
- [Finding files (`-nogroup`)](../files-and-text-processing/finding-files.md)
