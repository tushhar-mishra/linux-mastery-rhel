# 105 · Ansible: Admin Tasks as Code

> **You need first:** [104 · cloud-init](104-cloud-init.md) (and everything you do by hand: users 022–028, packages 031, services 037, firewall 071, SELinux 072–074, storage 046–049, SSH keys 065)
> **Next:** [106 · Building RPM packages](106-building-rpm-packages.md)

---

## What it is

**Ansible** is a configuration-management and automation tool. You describe the **desired state** of servers in YAML ("this user exists", "nginx is installed and running", "port 80 is open"). Ansible connects over **SSH**, compares that with the current state, and changes only what's different.

| Term | Meaning |
|---|---|
| **Control node** | The machine where you run `ansible` / `ansible-playbook` |
| **Managed node** | A target host, reached over SSH (key-based login + sudo). It needs only Python: **agentless** |
| **Inventory** | The list of hosts and groups (`inventory.ini` or YAML) |
| **Module** | A unit of work (`ansible.builtin.user`, `dnf`, `copy`, `systemd_service`…), idempotent by design |
| **Task / Play / Playbook** | One module call / a set of tasks for a host group / a YAML file of plays |
| **Handler** | A task that runs only when **notified** by a change (e.g. restart after a config change) |
| **Facts** | Data gathered from hosts (`ansible_distribution`, IPs, disks) |
| **Variables**, **templates** | Data per host/group; Jinja2 templates turn variables into config files |
| **Role** | A reusable package of tasks, templates and defaults. Red Hat ships **RHEL System Roles** (network, storage, selinux, firewall, timesync…) |
| **Collection** | A bundle of modules and roles: `ansible.builtin` (always present), `ansible.posix`, `community.general` |
| **Idempotency** | Running the same thing twice gives the same result; the second run changes nothing |
| **Vault** | Encrypted variables files for secrets |

## Why it exists

Every task you've learned by hand (users, sudo, repos, services, firewall, SELinux, storage, mounts) must be done on **hundreds** of hosts and kept correct over time. Shell scripts become fragile at that scale: they aren't idempotent, can't preview changes, and are hard to read. Ansible gives you:
- declarative state, with only the differences applied;
- a dry run (`--check --diff`);
- **drift correction** (someone changed something by hand? the next run puts it back);
- version-controlled infrastructure in Git.

It's a staple of DevOps/SRE work (and the subject of Red Hat's RHCE certification, if you want one later).

## Analogy

A shell script is a **list of instructions**: "paint the wall blue". Run it twice, and you paint twice. Ansible is a **specification**: "the wall is blue". The worker looks first: if the wall is already blue, they do nothing; if someone painted it red, they repaint it. You can also ask "**what would you do?**" (`--check --diff`) before they lift a brush.

## How it works inside

1. `ansible-playbook` reads the inventory and playbook, then for each host opens an **SSH** connection (reusing it via SSH multiplexing).
2. It usually **gathers facts** first (the `setup` module).
3. For each task, it copies a small Python module to the host, runs it with the arguments (with `sudo` if `become: true`), and gets back JSON: `ok` (already correct), `changed`, `failed` or `skipped`.
4. Modules are idempotent because they **check before changing**. The `user` module reads `/etc/passwd` first; `copy` compares checksums; `dnf` asks whether the package is installed.
5. Tasks that report `changed` can **notify handlers**, which run once at the end of the play (so a config changed twice restarts the service once).
6. `--check` asks modules to report what they *would* do; `--diff` shows file differences.
7. The `command`/`shell` modules can't know if they changed anything. They always report `changed` unless you add `creates:`, `removes:` or `changed_when:`.

## Commands

### Setup

```bash
sudo dnf install -y ansible-core              # control node (Ubuntu: apt install ansible / pipx install ansible-core)
ansible-galaxy collection install ansible.posix community.general
ssh-copy-id admin@server1 ; ssh admin@server1 sudo -n true && echo ready   # key login + passwordless sudo
```
```ini
# inventory.ini
[web]
server1.example.com
server2.example.com

[lab]
localhost ansible_connection=local
```
```bash
ansible -i inventory.ini all -m ansible.builtin.ping
ansible -i inventory.ini web -b -m ansible.builtin.dnf -a "name=httpd state=present"    # an ad-hoc task; -b = become (sudo)
```
```
server1.example.com | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

### A baseline playbook

```yaml
---
- name: Baseline configuration as code
  hosts: lab
  become: true
  vars:
    admins: [natasha, harry]
  tasks:
    - name: Group sysadmin exists
      ansible.builtin.group:
        name: sysadmin
        state: present

    - name: Admin users exist and are in sysadmin
      ansible.builtin.user:
        name: "{{ item }}"
        groups: sysadmin
        append: true                  # like usermod -aG: keep other groups
        shell: /bin/bash
      loop: "{{ admins }}"

    - name: sysadmin may use sudo (validated before install)
      ansible.builtin.copy:
        dest: /etc/sudoers.d/sysadmin
        content: "%sysadmin ALL=(ALL) NOPASSWD: ALL\n"
        owner: root
        group: root
        mode: "0440"
        validate: /usr/sbin/visudo -cf %s   # a syntax error never reaches /etc/sudoers.d

    - name: Shared directory with set-GID
      ansible.builtin.file:
        path: /srv/shared
        state: directory
        group: sysadmin
        mode: "2770"

    - name: Login banner line present exactly once
      ansible.builtin.lineinfile:
        path: /etc/motd
        line: "Authorized use only."
        create: true
        mode: "0644"

    - name: Unit file for a demo service
      ansible.builtin.copy:
        dest: /etc/systemd/system/demo.service
        content: |
          [Unit]
          Description=Demo
          [Service]
          Type=exec
          ExecStart=/usr/bin/sleep infinity
          [Install]
          WantedBy=multi-user.target
        mode: "0644"
      notify: Restart demo

    - name: Demo service enabled and running
      ansible.builtin.systemd_service:
        name: demo.service
        enabled: true
        state: started
        daemon_reload: true

  handlers:
    - name: Restart demo
      ansible.builtin.systemd_service:
        name: demo.service
        state: restarted
        daemon_reload: true
```

### Run it, run it again, detect drift

```bash
ansible-playbook -i inventory.ini site.yml --syntax-check
ansible-playbook -i inventory.ini site.yml
ansible-playbook -i inventory.ini site.yml
```
```
PLAY RECAP *********************************************************************
localhost                  : ok=9    changed=8    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
...
PLAY RECAP *********************************************************************
localhost                  : ok=8    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```
- First run: all seven tasks changed something and the handler ran (`changed=8`; `ok=9` also counts fact gathering). Second run: **`changed=0`**. That is idempotency.

```bash
sudo chmod 0755 /srv/shared                                       # someone changes it by hand
ansible-playbook -i inventory.ini site.yml --check --diff
```
```
TASK [Shared directory with set-GID] ***************************************
--- before
+++ after
@@ -1,4 +1,4 @@
 {
-    "mode": "02755",
+    "mode": "02770",
     "path": "/srv/shared"
 }
changed: [localhost]
```
- The dry run shows exactly what it would fix. Note `chmod 0755` kept the set-GID bit (`02755`), GNU chmod's behaviour on directories (topic 027). Run it for real and the drift is corrected.

### Modules for the tasks you know

| Task | Module |
|---|---|
| Repositories / packages | `ansible.builtin.yum_repository`, `ansible.builtin.dnf` (Ubuntu: `apt`) |
| Services and targets | `ansible.builtin.systemd_service` |
| Files, templates, lines | `copy` (with `validate:`), `template` (Jinja2), `lineinfile`, `blockinfile`, `file` |
| Users, groups, keys | `user`, `group`, `ansible.posix.authorized_key` |
| Cron | `ansible.builtin.cron` |
| Firewall | `ansible.posix.firewalld` (`permanent: true`, `immediate: true`) |
| SELinux | `ansible.posix.selinux`, `ansible.posix.seboolean`, `community.general.sefcontext` (+ restorecon), `community.general.seport` |
| Storage | `community.general.parted`, `lvg`, `lvol`, `filesystem`; `ansible.posix.mount` (`state: mounted` = fstab **and** mount) |
| Whole areas at scale | **RHEL System Roles**: `redhat.rhel_system_roles.network`, `.storage`, `.selinux`, `.firewall`, `.timesync` |

### Secrets

```bash
ansible-vault create group_vars/web/vault.yml          # encrypted file for passwords and tokens
ansible-playbook -i inventory.ini site.yml --ask-vault-pass
```

### Try it
1. Run the baseline playbook twice against a lab VM and confirm `changed=0` on the second run.
2. Add `ansible.posix.firewalld` (http, permanent + immediate) and `community.general.seport` (tcp 8082 → `http_port_t`); verify by hand with `firewall-cmd` and `semanage port -l`.
3. Template an nginx config with `ansible.builtin.template` and a `validate: nginx -t -c %s`, plus a handler that reloads nginx.
4. Change something by hand, then catch it with `--check --diff`.

**Check your work:** on your lab VM, from the notes folder, run `sudo ./checks/check 105` for every step, or `sudo ./checks/check 105 STEP` for one (topic 002 shows how to get the notes there).

## Where you'll use it

- **Server fleets:** baselines, patching, user management, compliance (CIS hardening roles).
- **After cloud-init:** cloud-init bootstraps (user, key, Python); Ansible configures. Terraform creates infrastructure; Ansible configures what's inside.
- **Kubernetes:** Kubespray installs clusters with Ansible; node preparation (sysctl, kernel modules, container runtime) is typical Ansible work.
- **Day-2 operations:** rolling restarts (`serial:`), certificate renewal, configuration rollouts with review in Git.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `UNREACHABLE! … Permission denied (publickey)` | SSH key not set up, wrong user | `ssh-copy-id`; `ansible_user=` in the inventory; test `ssh` by hand |
| `Missing sudo password` | `become` needs a password | `--ask-become-pass`, or configure NOPASSWD sudo for the automation user |
| `couldn't resolve module/action 'ansible.posix.firewalld'` | Collection not installed | `ansible-galaxy collection install ansible.posix` |
| Always `changed` on every run | `command`/`shell` tasks | Use a real module, or `creates:` / `changed_when:` |
| A config change broke the service | No validation | `validate:` on the file task; reload via handlers only |
| YAML errors | Indentation, tabs, unquoted `{{ }}` at the start of a value | `--syntax-check`; quote values starting with `{{` |
| Slow runs on many hosts | Fact gathering and serial SSH | `gather_facts: false` where possible; raise `forks`; SSH pipelining |

## Quick recap

- Agentless: control node + inventory + SSH keys + sudo. Modules are idempotent; the second run reports `changed=0`.
- Playbook = plays → tasks (modules) + handlers (run on change) + variables/templates; roles and collections for reuse.
- `ansible-playbook site.yml [--syntax-check] [--check --diff]`; `validate:` for config files; Vault for secrets.
- Prefer modules over `command`/`shell`; keep playbooks in Git.

**Interview questions**

1. *What makes Ansible idempotent?* Its modules check the current state and change only what differs from the desired state, so re-running a playbook on a correct system reports `changed=0`.
2. *Agent-based vs agentless?* Ansible is agentless: it connects over SSH and runs short-lived Python modules, so nothing needs to run permanently on managed hosts (unlike Puppet or Chef agents).
3. *How do you safely change a service's config file with Ansible?* Template or copy it with `validate:` (e.g. `nginx -t -c %s`) so an invalid file is never installed, and notify a handler that reloads the service only if the file changed. Preview first with `--check --diff`.

**Scenario question** (answer out loud first, then compare)

> *"Someone changed an nginx setting by hand on 3 of your 40 Ansible-managed servers. How do you find them and put them back, safely?"*

**Model answer:**
1. Run the playbook in **check mode with diff**: `ansible-playbook site.yml --check --diff --limit webservers`. The drifted servers show `changed` with the exact diff; the rest show `ok`.
2. Review the diffs. Maybe the hand change was a real fix that belongs in the playbook instead.
3. Apply for real. The template task uses `validate: nginx -t -c %s` so a bad file is never installed, and notifies a handler that **reloads** nginx only on the changed hosts.
4. Roll out with `serial:` batches, so a mistake doesn't hit all 40 at once.
5. Prevent: run the playbook on a schedule (or check mode with alerts), and reduce manual access.

**Likely follow-ups:**
- *What makes a task idempotent?* The module checks the current state and only changes what differs; the second run reports `changed=0`.
- *Why avoid `shell:` tasks?* They usually aren't idempotent and report `changed` every run, unless you add `creates:` or `changed_when:`.
