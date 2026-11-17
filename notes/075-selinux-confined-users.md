# 075 · SELinux Confined Domains and Confined Users

> **You need first:** [074 · SELinux booleans, ports and troubleshooting](074-selinux-booleans-ports-troubleshooting.md)
> **Next:** [076 · SELinux MLS and MCS](076-selinux-mls-mcs.md)

---

## What it is

In RHEL's **targeted** policy, two kinds of processes exist:
- **Confined** processes run in a **specific domain** with a tight rulebook: `httpd_t`, `sshd_t`, `chronyd_t`, `named_t`.
- **Unconfined** processes run in broad domains that SELinux barely restricts (only DAC applies): your login shell (`unconfined_t`), or a service started from a generically-labelled program (`unconfined_service_t`).

You can go further and **confine users** by mapping Linux accounts to restricted **SELinux users**:

| SELinux user | Role | GUI | Network | `su` / `sudo` | Typical use |
|---|---|---|---|---|---|
| `unconfined_u` | `unconfined_r` | ✔ | ✔ | ✔ / ✔ | **Default for everyone** (including root) |
| `guest_u` | `guest_r` | ✘ | ✘ | ✘ / ✘ | Terminal-only restricted accounts |
| `xguest_u` | `xguest_r` | ✔ | Web browser only | ✘ / ✘ | Kiosks, guest desktops |
| `user_u` | `user_r` | ✔ | ✔ | ✘ / ✘ | Ordinary unprivileged users |
| `staff_u` | `staff_r` (+ `sysadm_r` through sudo) | ✔ | ✔ | ✘ / ✔ | Operators who sometimes administer |
| `sysadm_u` | `sysadm_r` | — | ✔ | ✔ | Dedicated admins (SSH login off by default) |
| `system_u` | `system_r` | — | — | — | System processes and files, not people |

## Why it exists

- Knowing which services are **confined** tells you which ones SELinux actually protects. Third-party software installed into `/opt` often ends up **unconfined**, so SELinux isn't protecting you from it.
- **Confined users** limit what a compromised or careless account can do. For example, a `user_u` account **can't** use `su` or `sudo`, even if someone adds it to `wheel` by mistake. They're used in high-security, kiosk and multi-user environments, and required by some government baselines.

## Analogy

Confined services are **staff with a specific job badge** (kitchen, cleaning): they can only enter their own work areas. Unconfined processes are **visitors with an "all areas" pass**; only the normal door locks (DAC) stop them. Confined users are **employees with restricted badges**: an intern badge (`user_u`) opens office doors but never the server room, no matter whose keys the intern borrows.

## How it works inside

- **How a service gets its domain:** systemd runs as `init_t`. When it executes `/usr/sbin/httpd`, labelled `httpd_exec_t`, the policy's transition rule puts the new process in `httpd_t`. If a program is labelled with a generic type like `bin_t` (typical for software installed by hand), there's no specific rule, and it lands in **`unconfined_service_t`**: almost unrestricted.
- **How a user gets an SELinux user:** at login, PAM's `pam_selinux` (topic 029) looks up `semanage login` mappings (Linux login → SELinux user + level range) and starts the session in that user's role and domain (`staff_u:staff_r:staff_t`). **`su` doesn't do this**: it keeps the caller's context. Mappings only apply to **real logins** (SSH, console).
- **Roles limit, they don't grant.** A confined admin still needs root (via sudo) for DAC. SELinux roles only **narrow** what that root can do.
- **Running programs from home and `/tmp`** is controlled by booleans: `user_exec_content`, `staff_exec_content`, `guest_exec_content`, `xguest_exec_content`.

## Commands

### Which processes are confined?

```bash
ps -eZ | awk '{print $1}' | cut -d: -f3 | sort | uniq -c | sort -rn | head
```
```
     98 kernel_t
     12 unconfined_t
      6 init_t
      3 sshd_t
      2 httpd_t
      2 chronyd_t
      1 unconfined_service_t
```
- Extracts the **type** field (domain) of every process and counts them.

```bash
ps -eZ | grep unconfined_service_t
ls -Z /opt/vendor/bin/agent
```
```
system_u:system_r:unconfined_service_t:s0 3120 ? 00:00:12 agent
unconfined_u:object_r:usr_t:s0 /opt/vendor/bin/agent
```
- A third-party agent running **unconfined**, because its binary has a generic label.

### Lab: see confinement work

```bash
sudo dnf install -y httpd ; sudo systemctl enable --now httpd
echo 'Hello' | sudo tee /var/www/html/testfile
curl -s -o /dev/null -w '%{http_code}\n' http://localhost/testfile      # 200
sudo chcon -t samba_share_t /var/www/html/testfile
curl -s -o /dev/null -w '%{http_code}\n' http://localhost/testfile      # 403: DAC allows, SELinux denies
sudo restorecon -v /var/www/html/testfile                                # back to 200
```
- In a throwaway lab only: relabelling `/usr/sbin/httpd` to `bin_t` makes it start as `unconfined_service_t`, and then the `samba_share_t` file **is** readable. That shows exactly what confinement buys you. Restore immediately with `restorecon -v /usr/sbin/httpd; systemctl restart httpd`.

### SELinux users and mappings

```bash
sudo semanage login -l
sudo semanage user -l
```
```
Login Name           SELinux User         MLS/MCS Range        Service
__default__          unconfined_u         s0-s0:c0.c1023       *
root                 unconfined_u         s0-s0:c0.c1023       *

                Labeling   MLS/       MLS/
SELinux User    Prefix     MCS Level  MCS Range                      SELinux Roles
guest_u         user       s0         s0                             guest_r
root            user       s0         s0-s0:c0.c1023                 system_r staff_r sysadm_r unconfined_r
staff_u         user       s0         s0-s0:c0.c1023                 system_r staff_r sysadm_r unconfined_r
sysadm_u        user       s0         s0-s0:c0.c1023                 sysadm_r
system_u        user       s0         s0-s0:c0.c1023                 system_r unconfined_r
unconfined_u    user       s0         s0-s0:c0.c1023                 system_r unconfined_r
user_u          user       s0         s0                             user_r
xguest_u        user       s0         s0                             xguest_r
```

```bash
sudo useradd -Z staff_u alice                      # create with a mapping
sudo semanage login -a -s user_u bob               # map an existing user (-m to change, -d to remove)
ssh alice@localhost 'id -Z'
```
```
staff_u:staff_r:staff_t:s0-s0:c0.c1023
```
- Test with a **real login** (SSH); `su - alice` would still show your own context.

```bash
ssh bob@localhost 'sudo -l'
```
```
sudo: setresuid() [0, 0, 0] -> [2008, -1, -1]: Operation not permitted
sudo: error initializing audit plugin sudoers_audit
```
- `user_u` can't escalate, even if sudoers would allow it.

### Confined administrators

```bash
# staff_u + sudo, switching role to sysadm_r for admin work
sudo useradd -G wheel -Z staff_u admin3
echo 'admin3 ALL=(ALL) TYPE=sysadm_t ROLE=sysadm_r ALL' | sudo tee /etc/sudoers.d/admin3
sudo chmod 0440 /etc/sudoers.d/admin3                  # tee creates it 0644; visudo -c then warns "bad permissions"
sudo visudo -c
ssh admin3@localhost
sudo -i ; id -Z
```
```
staff_u:sysadm_r:sysadm_t:s0-s0:c0.c1023
```
- Or use a direct `sysadm_u` account: `sudo setsebool -P ssh_sysadm_login on; sudo useradd -G wheel -Z sysadm_u admin2`.

### Confine everyone by default (carefully)

```bash
sudo semanage login -a -s staff_u admin1              # 1. map ALL admins explicitly FIRST
sudo semanage login -m -s user_u -r s0 __default__    # 2. everyone else becomes user_u at next login
```
- If you skip step 1, every admin becomes `user_u` and loses sudo at their next login. Keep a root console open while testing.

### Try it
1. Count confined vs unconfined processes on your VM.
2. Do the httpd confinement lab.
3. Create `guest1` mapped to `guest_u` and `staff1` mapped to `staff_u`. SSH in as each, run `id -Z`, try `sudo -l`, and try running a script in the home directory.
4. Set up the `staff_u` + `TYPE=sysadm_t ROLE=sysadm_r` sudo rule and confirm the role switch.

**Check your work:** on your lab VM, from the notes folder, run `sudo ./checks/check 075` for every step, or `sudo ./checks/check 075 STEP` for one (topic 002 shows how to get the notes there).

## Where you'll use it

- **Security reviews:** "which services run unconfined?" (`ps -eZ | grep unconfined_service_t`). Third-party agents (monitoring, backup, security tools) are the usual suspects. Vendors sometimes ship SELinux policy modules for them.
- **Hardened environments** (government, finance, shared academic systems, kiosks): confined user mappings.
- **Containers:** container processes run in the confined `container_t` domain (topics 076, 101), which is why a container breakout on RHEL is much harder.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `id -Z` doesn't change after mapping | You tested with `su -` | Log in over SSH or the console |
| A confined user can't use sudo | They're `user_u`/`guest_u` | Map to `staff_u` (+ a sudo role rule) |
| `sudo -i` still shows `staff_t` | The `TYPE=sysadm_t ROLE=sysadm_r` sudoers rule is missing or wrong | Fix it; `visudo -c` |
| A `sysadm_u` user can't SSH in | `ssh_sysadm_login` is off | `setsebool -P ssh_sysadm_login on` |
| Users can't run scripts in their home | A `*_exec_content` boolean is off | Enable it, if your policy allows |
| A third-party daemon runs as `unconfined_service_t` | Generic executable label | Accept the risk, or install vendor policy and labels |
| All admins lost sudo after changing `__default__` | Admins weren't mapped first | Root console → map admins → test |

## Quick recap

- Targeted policy: services are **confined** (`httpd_t`…); users and generically-labelled services are **unconfined** (`unconfined_t`, `unconfined_service_t`).
- SELinux users: `unconfined_u` (default), `user_u` (no su/sudo), `staff_u` (sudo, can switch to `sysadm_r`), `sysadm_u`, `guest_u`, `xguest_u`.
- `semanage login -l/-a/-m/-d`, `useradd -Z`. Mappings apply at **real logins**, not `su`.
- SELinux roles **restrict** root; they never grant privileges. Map admins before confining `__default__`.

**Interview questions**

1. *What does "targeted" policy mean?* Selected system services run in their own confined domains; users and everything else run unconfined, restricted mainly by normal permissions.
2. *Why would a service run as `unconfined_service_t`?* Its executable has a generic label (such as `bin_t` or `usr_t`), so no transition rule puts it into a specific confined domain.
3. *How do you stop a user from ever using sudo, at the SELinux level?* Map them to `user_u` (or `guest_u`) with `semanage login -a -s user_u USER`; those SELinux users can't transition to root even if sudoers allows it.

**Scenario question** (answer out loud first, then compare)

> *"Contractors need SSH access to run a few scripts, but must never become root, even if a sudo rule is added by mistake later. How can SELinux help?"*

**Model answer:**
1. Map their Linux accounts to a restricted SELinux user: `semanage login -a -s user_u contractor1` (or for a group: `semanage login -a -s user_u %contractors`).
2. `user_u` can't use `su` or `sudo` to reach root domains, even if sudoers would allow it. SELinux checks happen after DAC and sudo.
3. Admins who need root get `staff_u` with a sudo rule that switches to `sysadm_r`/`sysadm_t`.
4. Mappings apply at **login**; test with a fresh SSH login and `id -Z`, then try `sudo -l`.
5. Keep admins mapped (and tested) **before** confining the `__default__` login, or you can lock yourself out.

**Likely follow-ups:**
- *What does "targeted" mean?* Only selected services are confined; users and everything else run unconfined by default.
- *Why does a service show `unconfined_service_t`?* Its binary has a generic label, so no domain transition applies.
