# 028 · sudo, su and Privileged Access

> **You need first:** [027 · Special permissions, ACLs and attributes](027-special-permissions-acls-and-attributes.md)
> **Next:** [029 · PAM and authselect](029-pam-and-authselect.md)

---

## What it is

Three ways to act with more rights than your normal account:

| Tool | What it does | Whose password | Typical use |
|---|---|---|---|
| **`sudo`** ("substitute user do") | Runs **one command** (or a shell) as another user, usually root, following rules in `/etc/sudoers` | **Your own** (or none if the rule says `NOPASSWD`) | Daily admin work; fine-grained permission per command |
| **`su`** ("substitute user") | Starts a whole **shell** as another user | **The target user's** | Rare on RHEL 10, where root has no password by default |
| **polkit** | Lets normal programs ask a privileged background service to do something (`systemctl`, `nmcli`, Cockpit) | An admin's (members of `wheel`) | Desktop and D-Bus actions |

**D-Bus** is the message system programs use to talk to system services on the same machine.

On RHEL 10, the installer disables the root password. Ticking "Make this user administrator" adds you to the **`wheel`** group, and `/etc/sudoers` already contains the rule `%wheel ALL=(ALL) ALL`. That's why admins can use `sudo` right after install. **Ubuntu** works the same way, but the group is called **`sudo`**.

## Why it exists

Sharing one root password is dangerous: everyone knows it, you can't tell who did what, and removing one person means changing it for everybody. sudo fixes all of that:
- Each admin uses **their own** password.
- Rights can be **limited per command** ("the web team may only restart nginx").
- **Every command is logged** with the real person's name.
- Removing someone from a group removes their access instantly.

## Analogy

Root is the **master key** to the building. Instead of copying it for everyone, there's a **security desk** (sudo) with a **rulebook** (`/etc/sudoers`). You show your own ID, the guard checks the rulebook ("Alice may open the server room, Bob may only open the storage cupboard"), opens that one door for you, and writes it in the logbook. `su` is borrowing someone else's ID card entirely, and you have to know their PIN.

## How it works inside

### What happens when you type `sudo systemctl restart nginx`

1. `/usr/bin/sudo` is a **SUID-root** program (topic 027), so it starts running with root's rights whoever you are.
2. It reads the **policy**: `/etc/sudoers` plus every file pulled in by `#includedir /etc/sudoers.d`. (That leading `#` is part of the directive, **not** a comment.)
3. It looks for rules matching **(you, this host, the target user, this exact command line)**. If several rules match, **the last match wins**.
4. If the rule needs a password, it asks PAM (topic 029) to check **your** password. Success is cached for this terminal for 5 minutes by default.
5. It **logs** the request, allowed or denied, to `/var/log/secure` (Ubuntu: `/var/log/auth.log`) and the journal.
6. It cleans the environment (`env_reset`), sets a safe PATH (`secure_path`), switches to the target user and runs the command (execve).

### The sudoers grammar

```
WHO      WHERE = (AS_USER:AS_GROUP)  [TAGS:]  WHAT
alice    ALL   = (ALL:ALL)                    ALL
%wheel   ALL   = (ALL)                        ALL                    ← RHEL default
%ops     ALL   = (root)              NOPASSWD: /usr/bin/systemctl restart nginx, /usr/bin/journalctl
```

| Field | Meaning | Examples |
|---|---|---|
| **WHO** | A user, `%group`, `#UID`, or a `User_Alias` | `alice`, `%wheel`, `ADMINS` |
| **WHERE** | Which host the rule applies to (lets one file be shared by many servers) | `ALL`, `web01` |
| **AS** | Who you may become | `(ALL)`, `(root)`, `(postgres)` |
| **TAGS** | Modifiers | `NOPASSWD:`, `NOEXEC:`, `SETENV:` |
| **WHAT** | Commands with **full paths**, comma-separated, or `ALL` | `/usr/bin/systemctl restart nginx` |

| You write | Allows |
|---|---|
| `/usr/bin/systemctl` | systemctl with **any** arguments |
| `/usr/bin/systemctl restart nginx` | Only that exact command line |
| `/usr/bin/passwd ""` | passwd with **no** arguments only |
| `!/usr/bin/passwd root` | Negation: weak as security (copy the binary, start a shell) |

**Aliases** (names must be UPPERCASE):
```
User_Alias  WEBADMINS = alice, bob, %webteam
Cmnd_Alias  WEBCMDS   = /usr/bin/systemctl restart nginx, /usr/bin/systemctl reload nginx, /usr/sbin/nginx -t
WEBADMINS   ALL = (root) NOPASSWD: WEBCMDS
```

**Defaults:**
```
Defaults    env_reset                                   # clean environment
Defaults    secure_path = /sbin:/bin:/usr/sbin:/usr/bin # PATH for sudo'd commands
Defaults    timestamp_timeout=10                        # minutes the password is remembered
Defaults    use_pty                                     # run in a pseudo-terminal (hardening)
Defaults    logfile=/var/log/sudo.log                   # an extra log file
```

### Escape hatches: a narrow rule can still give full root

If the allowed program can **start a shell** or **write any file**, the user can become root regardless of how narrow the rule looks:

| "Harmless-looking" rule | Why it's really root | Safer option |
|---|---|---|
| `/usr/bin/vi /etc/hosts` | Type `:!sh` inside vi | `sudoedit /etc/hosts` |
| `/usr/bin/less /var/log/messages` | Type `!sh` inside less | A log-reading group (`systemd-journal`, `adm`) |
| `/usr/bin/find` | `find / -exec /bin/sh \;` | A specific script |
| `/usr/bin/tar`, `awk`, `python3`, `bash` | They can run commands | A root-owned wrapper script |
| `/usr/bin/systemctl` (any args) | `systemctl edit` → write any unit → root | List exact subcommands and units |
| `/usr/bin/cp` (any args) | Overwrite `/etc/sudoers.d/x` | Specific paths or a script |

**`sudoedit`** is special: sudo copies the file to a temporary file **owned by you**, runs your editor **as you**, then copies the result back as root. The editor never has root rights.

## Commands

### Using sudo

| Command | Effect |
|---|---|
| `sudo CMD` | Run CMD as root |
| `sudo -u postgres psql` | Run as another user |
| `sudo -i` | Root **login** shell (root's environment and home) |
| `sudo -s` | Root shell keeping more of your environment |
| `sudo -e FILE` / `sudoedit FILE` | Safely edit a root-owned file |
| `sudo -l` | What am I allowed to run? |
| `sudo -v` / `sudo -k` | Refresh / forget the cached password |
| `sudo !!` | Re-run the last command with sudo |

```bash
sudo -l
```
```
Matching Defaults entries for alice on server1:
    !visiblepw, always_set_home, match_group_by_gid, env_reset, ...
    secure_path=/sbin\:/bin\:/usr/sbin\:/usr/bin

User alice may run the following commands on server1:
    (ALL) ALL
```
- alice may run anything as anyone, via the `%wheel` rule.

### Editing the policy safely: always `visudo`

`visudo` locks the file, edits a copy, and **refuses to save a syntax error**. A broken `/etc/sudoers` breaks sudo for **everyone**, which on RHEL 10 (no root password) can lock you out of your own server.

```bash
sudo visudo                                 # edit /etc/sudoers
sudo visudo -f /etc/sudoers.d/webteam       # create/edit a drop-in file (preferred)
sudo visudo -c                              # check everything
```
```
/etc/sudoers: parsed OK
/etc/sudoers.d/webteam: parsed OK
```
- If visudo finds an error: `e` to edit again, `x` to quit without saving. **Never** `Q` (save anyway).

**Drop-in file rules for `/etc/sudoers.d/`:**

| Rule | Why |
|---|---|
| File names **containing a `.`** or **ending in `~`** are **silently ignored** | So editor backups and `.rpmnew` files aren't loaded. `webteam` works; `webteam.conf` is ignored |
| Owner root, mode **0440** | sudo refuses files that are writable by others or not owned by root |
| Read in alphabetical order | Later files can override earlier rules (last match wins) |

Writing a drop-in from a script, validated **before** it goes live:
```bash
echo '%webteam ALL=(root) NOPASSWD: /usr/bin/systemctl restart nginx' > /tmp/webteam
sudo visudo -cf /tmp/webteam && sudo install -m 0440 -o root -g root /tmp/webteam /etc/sudoers.d/webteam
```

### Common rules

```bash
# Make alice an admin (the normal way)
sudo usermod -aG wheel alice            # Ubuntu: sudo usermod -aG sudo alice  (then re-login)

# Group sysadmin may do anything, no password
echo '%sysadmin ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/sysadmin
sudo chmod 0440 /etc/sudoers.d/sysadmin ; sudo visudo -c

# harry may only create users and set passwords
echo 'harry ALL=(root) /usr/sbin/useradd, /usr/bin/passwd' | sudo tee /etc/sudoers.d/harry
sudo chmod 0440 /etc/sudoers.d/harry ; sudo visudo -c   # tee creates files 0644; visudo -c would warn "bad permissions"
```
- Find full paths with `command -v useradd`. sudoers needs absolute paths.

```bash
sudo -l -U harry
```
```
Matching Defaults entries for harry on server1:
    ...

User harry may run the following commands on server1:
    (root) /usr/sbin/useradd, /usr/bin/passwd
```
- As root, check what another user may do.

### Delegating a task safely with a wrapper script

```bash
sudo install -m 0755 -o root -g root restart-web.sh /usr/local/sbin/restart-web.sh
echo '%webteam ALL=(root) NOPASSWD: /usr/local/sbin/restart-web.sh' | sudo tee /etc/sudoers.d/webteam
sudo chmod 0440 /etc/sudoers.d/webteam ; sudo visudo -c
```
- The script and **every directory above it** must be writable only by root. Otherwise the user can replace the script and become root.

### su

```bash
su - alice          # become alice with a full login environment (needs alice's password)
su alice            # become alice but keep your environment (non-login)
sudo -u alice -i    # become alice using YOUR password (if sudo allows it)
exit                # back to yourself
```

| | `su -` (to root) | `sudo -i` |
|---|---|---|
| Password | Root's | Yours |
| Works when root has no password (RHEL 10 default) | **No** | Yes |
| Logging | "session opened for root by alice" | Each command logged under alice's name |

Restrict who may use `su` with `pam_wheel` (topic 029).

### Logs

```bash
sudo grep 'sudo' /var/log/secure | tail -3
```
```
Nov 16 13:02:11 server1 sudo[4120]:   alice : TTY=pts/0 ; PWD=/home/alice ; USER=root ; COMMAND=/usr/bin/dnf update
Nov 16 13:03:40 server1 sudo[4188]:     bob : user NOT in sudoers ; TTY=pts/1 ; PWD=/home/bob ; USER=root ; COMMAND=/usr/bin/cat /etc/shadow
```
- Who, from which terminal and directory, as whom, which command. Denied attempts are logged too.

```bash
journalctl _COMM=sudo --since today
```

### The redirection trap (again)

`sudo echo x > /etc/file` fails, because **your** shell opens the file before sudo runs (topic 016). Use `echo x | sudo tee /etc/file`.

### polkit in one minute

`systemctl`, `nmcli`, `timedatectl` and Cockpit send requests over D-Bus to privileged services. Those services ask **polkit** whether you may do it. RHEL's default rules treat `wheel` members as admins. That's why a wheel user running `systemctl restart nginx` **without** sudo gets a password prompt instead of "Access denied". Rules live in `/usr/share/polkit-1/rules.d/` and `/etc/polkit-1/rules.d/`.

### Try it
1. Create group `ops` and users `ann` (in ops) and `ben` (not). Allow `%ops` to run `systemctl restart chronyd` and `systemctl status chronyd` with no password, and nothing else.
2. Test as ann: `sudo -n systemctl restart chronyd; echo $?` → 0. Then `sudo -n dnf install zsh` → refused (`-n` = never prompt).
3. Rename the file to `ops.conf` and test again (the rule is now ignored). Rename it back.
4. Find the denied attempts in `/var/log/secure`.

## Where you'll use it

- **Every admin task** on RHEL and Ubuntu servers.
- **Least-privilege delegation:** on-call engineers may restart services and read logs, but not install packages.
- **Automation:** Ansible connects as a normal user and uses `become` (which uses sudo). CI deploy users get narrow `NOPASSWD` rules for exactly the commands they need.
- **Audits:** "who ran what as root last night?" → the sudo log.
- **Containers:** most images have no sudo at all; you choose the user with `USER` or `runAsUser`. Kubernetes nodes are administered through sudo like any server.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `alice is not in the sudoers file. This incident will be reported.` | No matching rule | Add a rule or `usermod -aG wheel alice`, then **re-login** |
| Added to wheel but still refused | The group list is fixed at login (topic 024) | Log out and back in, or `su - alice` |
| `Sorry, user alice is not allowed to execute '…' as root` | Command or arguments don't match the rule | `sudo -l`; check paths and arguments |
| A rule in `/etc/sudoers.d/ops.conf` does nothing | The file name contains a dot | Rename it to `ops` |
| `… is world writable` / `… is owned by uid 1000, should be 0` | Wrong mode or owner on the drop-in | `chown root:root`, `chmod 0440` |
| A NOPASSWD rule still asks for a password | A **later** rule (like `%wheel ALL=(ALL) ALL`) also matches and wins | Put your rule in a file that sorts later, or adjust the order |
| `sudo: mycmd: command not found` for `/usr/local/bin/mycmd` | Not in `secure_path` | Use the full path |
| `syntax error near line N` and **nobody** can sudo | sudoers edited without visudo | Fix via `pkexec visudo`, or rescue boot (topic 057) |
| `sudo: a terminal is required to read the password` | No terminal (script, `ssh host sudo …`) | `ssh -t`, or a narrow NOPASSWD rule |

## Quick recap

- sudo = run one command as root using **your** password, checked against `/etc/sudoers` (+ `/etc/sudoers.d/`), logged per user. Last matching rule wins.
- Grammar: `WHO WHERE=(AS) [NOPASSWD:] /full/path args`. `%wheel ALL=(ALL) ALL` is the RHEL default (`%sudo` on Ubuntu).
- Always `visudo` / `visudo -c`. Drop-in names have no dot; mode 0440, owned by root.
- Programs that can spawn shells (vi, less, find, tar, systemctl) give full root. Use `sudoedit` or wrapper scripts.

**Interview questions**

1. *How does sudo get root privileges?* It's a SUID-root binary. It checks the sudoers policy and authenticates the caller via PAM, logs the request, then runs the command as the target user.
2. *sudo vs su?* sudo uses **your** password, applies per-command rules and logs each command under your name. su needs the **target's** password and gives a full shell.
3. *How can a rule allowing only `vi /etc/hosts` give full root?* vi can run shell commands (`:!sh`), and they run as root. Use `sudoedit`, which runs the editor as the user.
