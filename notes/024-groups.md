# 024 · Groups and Group Membership

> **You need first:** [023 · Passwords and aging](023-passwords-and-aging.md)
> **Next:** [025 · Shell startup files](025-shell-startup-files.md)

---

## What it is

A **group** is a named set of users. You give access to the group once, and every member gets it.

- **Primary group**: the **one** group stored in the user's `/etc/passwd` line (field 4). New files the user creates belong to this group.
- **Supplementary groups** (secondary groups): any number of extra groups listed in `/etc/group`. They add access rights.
- **`wheel`**: the RHEL group whose members may use `sudo` to become admin. Ubuntu uses the group **`sudo`** instead.
- **Group administrator**: a user allowed to add or remove members of one group without being root.

Files:
```
/etc/group:    devs:x:612:nina,leo,julian       name : x : GID : supplementary members
/etc/gshadow:  devs:!:nina:leo,julian           name : password : ADMINS : members
```

## Why it exists

Giving access user by user doesn't scale. "The dev team can write to `/srv/app`" should be **one rule** (for the group `devs`), not 30. When someone joins or leaves the team, you change their group membership once, and all their access follows. Groups also map nicely onto roles: `wheel`/`sudo` (admins), `docker` (may use Docker), `systemd-journal` (may read all logs).

## Analogy

Groups are **team key cards**. Instead of programming every door for every person, you program the door "Engineering may enter" and hand each engineer an Engineering card. Your **primary group** is the team name printed on everything you create. **Supplementary groups** are extra cards on your lanyard.

The catch: your lanyard is filled **when you arrive in the morning (log in)**. If you're added to a new team at noon, your lanyard doesn't change until you come back in.

## How it works inside

### Group lists are fixed when a process starts

When you log in, the login program asks NSS for **all** your groups and attaches the list to your shell process. The kernel stores it as part of the process's **credentials**: UID, GID and the list of supplementary GIDs. Every program you start **inherits a copy**.

When you access a file, the kernel compares the file's group with your process's GID **and supplementary GID list**. It does **not** re-read `/etc/group`.

That's why:
- `usermod -aG devs alice` updates the **database** immediately, so `id alice` shows the new group.
- But alice's **already-running** shell still carries the old list. She gets "Permission denied" until she logs out and back in, or runs `su - alice` or `newgrp devs`.
- The same applies to **services**: a daemon added to a group must be **restarted** before the new group takes effect.

### Primary vs supplementary

| | Primary group | Supplementary groups |
|---|---|---|
| Stored in | `/etc/passwd` field 4 | Member list in `/etc/group` |
| How many | Exactly one | Zero or more |
| Used for | The group owner of **new files** | Access checks |
| Change with | `usermod -g grp user`; `newgrp` (temporary) | `usermod -aG`, `gpasswd -a/-d` |

A user whose **primary** group is `devs` is **not** listed in `devs`'s member list in `/etc/group`. That list shows only supplementary members. So don't trust `grep devs /etc/group` alone; use `getent group` plus `id`.

## Commands

| Task | Command |
|---|---|
| Create a group | `groupadd devs` · `groupadd -g 5000 devs` · `groupadd -r appgrp` (system group) |
| Rename a group | `groupmod -n newname oldname` |
| Change a GID | `groupmod -g 5001 devs` (files keep the old number ⚠️) |
| Delete a group | `groupdel devs` (fails if it's anyone's primary group) |
| Add a user to groups (keep the others) | `usermod -aG devs,ops alice` |
| **Replace** all supplementary groups | `usermod -G devs alice` ⚠️ |
| Change the primary group | `usermod -g devs alice` |
| Add / remove one member | `gpasswd -a alice devs` · `gpasswd -d alice devs` |
| Set the full member list | `gpasswd -M alice,bob devs` |
| Make someone group admin | `gpasswd -A nina devs` (clear with `gpasswd -A "" devs`) |
| Show groups | `groups alice` · `id alice` · `id -Gn` · `getent group devs` |
| Temporarily use another primary group | `newgrp devs` (starts a new shell; `exit` to return) |
| Edit by hand safely | `vigr` and `vigr -s`, then `grpck -r` |

```bash
sudo groupadd -g 3001 devs
sudo usermod -aG devs alice
getent group devs
id alice
```
```
devs:x:3001:alice
uid=1000(alice) gid=1000(alice) groups=1000(alice),10(wheel),3001(devs)
```

### Proving the "re-login" rule

```bash
# as alice, in an existing session:
id -Gn
```
```
alice wheel
```
- The current shell still has the old list, even though the database says `devs`.

```bash
newgrp devs
id -Gn
```
```
devs alice wheel
```
- `newgrp` started a new shell with a fresh group list, and `devs` is now the primary group for new files. `exit` returns to the old shell. A full re-login (or `su - alice`) also works.

```bash
cat /proc/$$/status | grep -E '^(Uid|Gid|Groups)'
```
```
Uid:	1000	1000	1000	1000
Gid:	1000	1000	1000	1000
Groups:	10 1000
```
- The **kernel's** view of your current shell's credentials. This is what's actually checked. The four columns are the real, effective, saved and filesystem IDs (topic 092).

### Delegating membership management

```bash
sudo gpasswd -A nina devs
su - nina
gpasswd -a julian devs
```
```
Adding user julian to group devs
```
- nina (a team lead) can now manage `devs` without sudo.

### Try it
1. Create groups `music` and `media`. Add a test user to both with **one** `usermod -aG` command.
2. Log in as that user in one terminal. As root, add them to a third group. Check `id -Gn` in their old session, then after `su - user`.
3. Try `groupdel` on a user's primary group and read the error.
4. Make a user the admin of `music` and have them add someone.

**Check your work:** on your lab VM, from the notes folder, run `sudo ./checks/check 024` for every step, or `sudo ./checks/check 024 STEP` for one (topic 002 shows how to get the notes there).

## Where you'll use it

- **Admin rights:** `usermod -aG wheel alice` (RHEL) or `usermod -aG sudo alice` (Ubuntu) (topic 028).
- **Docker:** `usermod -aG docker alice` lets alice use Docker without sudo. Note that this is effectively **root-equivalent** access.
- **Logs:** members of `systemd-journal` (RHEL) or `adm` (Ubuntu) can read all system logs.
- **Shared project directories:** a group plus an SGID directory (topic 027).
- **Services:** add the `nginx` user to a group so it can read app files, then **restart nginx** so it picks up the new group.
- **Kubernetes/containers:** `fsGroup` and `supplementalGroups` in a pod's security settings are these same supplementary GIDs, applied to the container's processes.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| Added to a group but still "Permission denied" | The session (or service) started before the change | Log out and in, `su - user`, `newgrp grp`; restart services |
| The user lost all other groups | `usermod -G` without `-a` | Re-add with `usermod -aG` |
| `groupdel: cannot remove the primary group of user 'x'` | It's someone's primary group | Change their primary first (`usermod -g`) |
| Files show a number instead of a group name | The group was deleted or its GID changed | `find / -xdev -nogroup`; `chgrp` |
| `grpck` reports mismatches | `/etc/group` was edited by hand without `/etc/gshadow` | Fix with `vigr` **and** `vigr -s` |
| `newgrp` asks for a password | You're not a member | Add the user to the group |

After changing a GID with `groupmod -g`, fix old files: `find / -xdev -gid OLD -exec chgrp -h NEW {} +`.

## Quick recap

- One **primary** group (owns new files) plus any number of **supplementary** groups (extra access).
- `groupadd`, `groupmod`, `groupdel`; `usermod -aG` (always with `-a`); `gpasswd -a/-d/-A`.
- Group lists are attached to a process **at login**. New membership needs a new login, `newgrp`, or a service restart.
- Check with `id`, `getent group`, and `/proc/<pid>/status` for the kernel's real view.

**Interview questions**

1. *Primary vs supplementary group?* The primary group (exactly one, from `/etc/passwd`) becomes the group owner of new files. Supplementary groups (zero or more, from `/etc/group`) give extra access.
2. *A user was added to a group but still gets "Permission denied". Why?* Their running shell got its group list at login. They need to log in again (or use `newgrp`/`su -`); services need a restart.
3. *Why might `groupdel` fail?* The group is some user's primary group.

**Scenario question** (answer out loud first, then compare)

> *"You added a user to the `docker` (or `wheel`) group, but they still get 'permission denied'. What's going on?"*

**Model answer:**
1. Group membership is attached to a process **at login**. Their current shell still has the old group list: `id` in their session doesn't show the new group, while `id username` (which reads the database) does.
2. They need to **log out and in** again (or `newgrp group` / `su - user` to test).
3. Services running as that user need a **restart** for the same reason.
4. Also check the change itself: `getent group docker`, and that it was `usermod -aG` (with `-a`), not `-G`, which would have removed their other groups.

**Likely follow-ups:**
- *Primary vs supplementary group?* The primary group owns new files; supplementary groups grant extra access.
- *How can you see a running process's real groups?* `grep Groups /proc/PID/status`.
