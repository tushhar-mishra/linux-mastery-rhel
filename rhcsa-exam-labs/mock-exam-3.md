# RHCSA 10 Mock Exam 3: Break-Fix (with Break Script & Grader)

> **Track:** **[RHCSA Core]** · trains *Interrupt the boot process*, *Diagnose and correct file permission problems*, SELinux, firewalld, services, journals, users and sudo under pressure · **Verified:** the break script and grader were run on a RHEL 10.2 `ubi-init` container (boot loader and SELinux steps need a real VM; everything else was exercised).
> **Time:** 60 minutes. **Rules:** no internet, no notes; man pages allowed; leave SELinux enforcing and firewalld running.
> **Prerequisites:** [Troubleshooting methodology](../troubleshooting-and-interviews/troubleshooting-methodology.md) · [boot recovery](../boot-systemd-and-kernel/boot-recovery.md) · [SELinux](../firewall-and-selinux/selinux-booleans-ports-troubleshooting.md)

## Setup (on a disposable lab VM, after taking a snapshot)

```bash
sudo -i
touch /etc/rhcsa-lab-ok                 # safety marker: the script refuses to run without it
bash graders/mock3-break.sh             # type BREAK when asked
reboot
```

The script installs httpd/chrony/tuned/firewalld, then introduces faults in **seven areas** and sets root's password to a random value. You don't get a list of faults; you get the end state you must restore.

## The Task

A colleague left `server3` in a bad state before going on leave. Restore it so that, **after a reboot**:

1. The system boots without manual intervention into the **multi-user** target, and you know the root password (set it to `Root@2026`).
2. Apache serves `/var/www/html/index.html` (content `mock3`) on **TCP 8085** to other hosts, and starts at boot. SELinux stays **enforcing**.
3. Members of group `ops` (for example `opsuser`) can run any command with `sudo` (password required).
4. User `deploy` can log in interactively with password `Deploy@2026`.
5. The system journal is preserved across reboots.
6. Time synchronization is active and enabled; the recommended tuned profile is active and enabled.
7. Members of `analysts` (for example `ana`) can read files in `/srv/reports`; other non-root users can't.

Then reboot once more and run: `bash graders/mock3-grade.sh`.

## Hints (open only if stuck for > 5 minutes)

<details><summary>Hint 1: getting in</summary>

The machine probably doesn't reach a login prompt, and you don't know root's password. Which boot-time method gives you a shell without any password?

</details>

<details><summary>Hint 2: where to look for everything else</summary>

`systemctl --failed`, `journalctl -b -p err`, `ausearch -m avc -ts boot`, `firewall-cmd --list-all`, `visudo -c`, `getent passwd deploy`, `passwd -S deploy`, `namei -l /srv/reports/q3.txt`, `systemd-analyze cat-config systemd/journald.conf`.

</details>

## Solution

<details><summary>Full solution with reasoning</summary>

**Fault G: boot (fstab, default target, root password).** The machine stops in emergency/rescue mode: a bogus fstab entry for `/archive` times out, and the default target is `rescue.target`, both asking for root's unknown password.

```text
GRUB → e → append rd.break to the linux line → Ctrl+X
```
```bash
mount -o remount,rw /sysroot ; chroot /sysroot
passwd root                                    # Root@2026
vi /etc/fstab                                  # delete the UUID=00000000-1111-… /archive line
systemctl set-default multi-user.target        # works in the chroot (it only relinks default.target);
                                               # alternative: ln -sf /usr/lib/systemd/system/multi-user.target /etc/systemd/system/default.target
touch /.autorelabel ; exit ; exit
```

**Fault A: web server.** `systemctl status httpd` → `could not bind to address …:8085` (SELinux port label missing). After that, the page returns 403 (`index.html` labeled `user_home_t`), and remote clients time out (firewall).

```bash
semanage port -a -t http_port_t -p tcp 8085
restorecon -v /var/www/html/index.html
firewall-cmd --permanent --add-port=8085/tcp ; firewall-cmd --reload
systemctl enable --now httpd ; curl http://localhost:8085/
```

**Fault B: sudo.** `/etc/sudoers.d/ops.conf` is ignored because the name contains a dot.

```bash
mv /etc/sudoers.d/ops.conf /etc/sudoers.d/ops ; visudo -c ; sudo -l -U opsuser
```

**Fault C: deploy.** Shell is `/sbin/nologin` and the password is locked.

```bash
usermod -s /bin/bash -U deploy ; passwd -S deploy       # P = usable password (RHEL 10)
```

**Fault D: journal.** A drop-in forces `Storage=volatile` and `/var/log/journal` was removed.

```bash
systemd-analyze cat-config systemd/journald.conf | grep -i storage
rm /etc/systemd/journald.conf.d/50-lab.conf
mkdir -p /var/log/journal ; systemd-tmpfiles --create --prefix /var/log/journal
systemctl restart systemd-journald ; journalctl --flush      # verified: --flush moves the active journal to /var/log/journal
```

**Fault E: time & tuning.**

```bash
systemctl enable --now chronyd tuned ; tuned-adm profile "$(tuned-adm recommend)" ; tuned-adm active
```

**Fault F: reports.** `/srv/reports` is `0700` and the file `0600`, both group `analysts`: the group has no `x` on the directory and no `r` on the file.

```bash
namei -l /srv/reports/q3.txt
chmod 0750 /srv/reports ; chmod 0640 /srv/reports/q3.txt
su - ana -c 'cat /srv/reports/q3.txt' ; su - opsuser -c 'cat /srv/reports/q3.txt'   # works / Permission denied
```

Reboot, then `bash graders/mock3-grade.sh` → all PASS.

</details>

## Debrief Questions

1. Why did the system ask for a root password at boot, and why didn't that help you?
2. Which three independent mechanisms blocked the website, and in which order did they reveal themselves?
3. Why was `ops.conf` ignored, and how would you have noticed without knowing the rule?
4. What's the difference between a locked password and a `nologin` shell? Which one stops SSH key logins?
5. Why does `/srv/reports` need `x` for the group even though the task only says "read"?

## Cross-References

- [Mock exam 2](mock-exam-2.md) · [Production scenarios](../troubleshooting-and-interviews/production-scenarios.md) · [Coverage checklist](../COVERAGE.md)
