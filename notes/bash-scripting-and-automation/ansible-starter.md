# Ansible Starter: Your RHCSA Tasks as Code

> **Track:** **[Production Practice]** · bridge to **RHCE (EX294)** and DevOps work · **Verified:** playbook below run twice on a RHEL 10.2 `ubi-init` container with ansible-core 2.21 (installed from PyPI for the lab; RHEL ships its own `ansible-core` build, so confirm the version with `dnf info ansible-core`). Modules needing SELinux, firewalld or real block devices (`sefcontext`, `firewalld`, `mount`, `lvol`) couldn't be exercised in a container: test them on a RHEL VM.
> **Prerequisites:** All RHCSA notes (you automate what you already know how to do by hand) · [Robust scripts (idempotency)](robust-scripts.md#6-locking--idempotency) · [SSH keys](../networking-and-ssh/ssh-remote-access.md#33-key-based-authentication-rhcsa-core) · [sudo](../users-groups-and-permissions/sudo-and-privileged-access.md)
> **Next:** RHCE EX294 objectives (separate study; see [GAPS](../../docs/known-gaps.md))

## 1. Why Learn This Right After RHCSA

Every RHCSA task (users, sudo, repos, services, firewall, SELinux, storage, mounts) is something a production team does on **hundreds** of hosts and must keep correct over time. Shell scripts grow fragile at that point; **Ansible** describes the desired **state** declaratively, applies only what's different (idempotency), shows what would change (`--check --diff`), and needs nothing on the managed hosts except SSH and Python. It's also the RHCE (EX294) exam and a staple of DevOps/SRE roles.

## 2. Core Concepts

| Term | Meaning |
|---|---|
| **Control node** | Where you run `ansible`/`ansible-playbook` |
| **Managed node** | Target host reached over SSH (key-based auth + sudo) |
| **Inventory** | List of hosts and groups (`inventory.ini`/YAML) |
| **Module** | Unit of work (`ansible.builtin.user`, `dnf`, `copy`, `systemd_service`…); idempotent by design |
| **Task / Play / Playbook** | One module call / tasks for a host group / a YAML file of plays |
| **Handler** | Task run only when notified by a change (e.g., restart after a config change) |
| **Collection** | Packaged modules: `ansible.builtin` (always present), `ansible.posix` (firewalld, mount, seboolean), `community.general` (sefcontext and many more) |
| **Facts** | Data gathered from hosts (`ansible_distribution`, IPs, disks) |
| **Role** | Reusable structure of tasks/templates/defaults; Red Hat ships **RHEL System Roles** (`rhel-system-roles`) for networking, storage, selinux, firewall, timesync… |

## 3. Setup

```bash
# Control node (RHEL): ansible-core from the RHEL AppStream repository
sudo dnf install -y ansible-core            # (rhel-system-roles for supported roles)
ansible-galaxy collection install ansible.posix community.general   # if not provided as RPMs
ansible --version

# Managed nodes: key-based SSH as a user with sudo (exactly the RHCSA skills)
ssh-copy-id admin@server1 ; ssh admin@server1 sudo -n true && echo "ready"
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
ansible -i inventory.ini all -m ansible.builtin.ping          # connectivity + Python check
ansible -i inventory.ini web -b -m ansible.builtin.dnf -a "name=httpd state=present"   # ad-hoc task (-b = become/sudo)
```

## 4. A Playbook of RHCSA Tasks (verified)

```yaml
---
- name: RHCSA-style baseline as code
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
        append: true                  # like usermod -aG: don't drop other groups
        shell: /bin/bash
      loop: "{{ admins }}"

    - name: sysadmin may use sudo without a password (validated before install)
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

    - name: Nightly cron job for harry
      ansible.builtin.cron:
        name: report
        user: harry
        minute: "30"
        hour: "2"
        job: /usr/bin/echo report >> /tmp/report.log

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

```bash
ansible-playbook -i inventory.ini site.yml --syntax-check
ansible-playbook -i inventory.ini site.yml            # run 1: changed>0 for everything created, failed=0
ansible-playbook -i inventory.ini site.yml            # run 2: ok=9 changed=0   ← idempotent
chmod 0755 /srv/shared                                # simulate drift by hand
ansible-playbook -i inventory.ini site.yml --check --diff   # shows: -"mode": "02755"  +"mode": "02770"
ansible-playbook -i inventory.ini site.yml            # changed=1: drift corrected
```

Note from the drift test: `chmod 0755` on the directory **kept** the set-GID bit (`02755`), exactly the GNU `chmod` behavior described in [special permissions](../users-groups-and-permissions/special-permissions-and-acls.md).

## 5. Mapping the Rest of the RHCSA (test on a RHEL VM)

| RHCSA task | Module |
|---|---|
| Repositories | `ansible.builtin.yum_repository` |
| Packages | `ansible.builtin.dnf` |
| Services, targets | `ansible.builtin.systemd_service` (`enabled`, `state`); `ansible.builtin.command: systemctl set-default …` with `changed_when` |
| Firewall | `ansible.posix.firewalld` (`service`, `port`, `permanent: true`, `immediate: true`, `state: enabled`) |
| SELinux mode / booleans / file contexts / ports | `ansible.posix.selinux`, `ansible.posix.seboolean` (`persistent: true`), `community.general.sefcontext` + a `restorecon` command, `community.general.seport` |
| Partitions, LVM, filesystems | `community.general.parted`, `community.general.lvg`, `community.general.lvol`, `community.general.filesystem` |
| Mounts / fstab | `ansible.posix.mount` (`state: mounted` writes fstab **and** mounts) |
| Time sync, networking, storage, SELinux, firewall at scale | **RHEL System Roles** (`redhat.rhel_system_roles.timesync`, `.network`, `.storage`, `.selinux`, `.firewall`) |
| Files from templates | `ansible.builtin.template` (Jinja2) |

## 6. Good Practices

- Use fully qualified module names (`ansible.builtin.copy`), and `validate:` for configs with a checker (`visudo -cf`, `sshd -t -f`, `nginx -t -c`).
- Prefer modules over `command`/`shell`; if you must use them, add `creates:`/`removes:` or `changed_when:` so runs stay idempotent and honest.
- Keep playbooks in Git; review changes with `--check --diff` before applying to production.
- Keep secrets in **Ansible Vault** (`ansible-vault create`), never in plain YAML.
- Start small: one role per responsibility, variables in `group_vars/`.

## 7. Exercises

1. Extend the playbook with `ansible.builtin.yum_repository` for the RHEL DVD repos from the [RPM note](../logs-scheduling-and-packages/rpm-and-dnf-package-management.md#23-local-dvdiso-repository-offline), then `dnf: name=httpd`.
2. Add `ansible.posix.firewalld` (http, permanent + immediate) and `community.general.seport` (tcp 8082 → http_port_t). Verify with the RHCSA commands.
3. Convert mock exam 2 node 1 ([mock exam 2](../rhcsa-exam-labs/mock-exam-2.md)) into a playbook; run it against a fresh VM and then against the same VM again (changed=0).

## 8. Interview Questions

| Question | Answer |
|---|---|
| What makes Ansible idempotent? | Modules compare desired vs current state and change only the difference; a second run reports `changed=0`. |
| Agent vs agentless? | Ansible is agentless: SSH + Python on the target, no daemon. |
| How do you preview changes? | `--check --diff`. |
| How do you protect a config change from breaking a service? | `validate:` on the file task + handlers that reload only on change. |
| When would you still write a shell script? | One-off local tasks, glue inside a pipeline, or where Ansible isn't available. |

## 9. Quick Revision

```
control node + inventory + SSH keys + sudo · ansible -m ping · ansible-playbook site.yml [--check --diff] [--syntax-check]
modules: group user copy(validate) file template lineinfile cron dnf yum_repository systemd_service
         ansible.posix: firewalld mount selinux seboolean · community.general: sefcontext seport parted lvg lvol filesystem
handlers (notify) · loops · vars · facts · roles · RHEL System Roles · Vault · idempotency = changed=0 on rerun
```

## 10. Cross-References

- [Robust scripts](robust-scripts.md) · [sudo](../users-groups-and-permissions/sudo-and-privileged-access.md) · [SSH keys](../networking-and-ssh/ssh-remote-access.md)
- [firewalld](../firewall-and-selinux/firewalld.md) · [SELinux file contexts](../firewall-and-selinux/selinux-file-contexts.md) · [LVM](../storage-and-filesystems/lvm-fundamentals.md) · [Mounting & fstab](../storage-and-filesystems/mounting-and-fstab.md)
