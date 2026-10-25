# Interview Question Bank (with Model Answers)

> **Track:** **[Interview Knowledge]** · Levels: **L1** junior/RHCSA · **L2** mid-level admin/DevOps · **L3** senior SRE/platform
> **How to use:** answer out loud (2–4 minutes for L2/L3) **before** opening the model answer. Good answers explain the mechanism, give the commands you'd run, and mention trade-offs. Each note also ends with short-answer questions; this bank covers the integrative and scenario questions demanding interviews actually ask.
> **Prerequisites:** the notes linked in each answer.

## How Interviewers Grade

| They look for | Not |
|---|---|
| A structured approach (scope → evidence → hypotheses → test) | Jumping to a fix |
| Mechanisms ("the shell forks, the child execs…") | Command recitation |
| Knowing what you'd check and why | Claiming certainty you don't have |
| Trade-offs and failure modes | One "right" answer |
| Saying "I don't know, here's how I'd find out" | Bluffing |

---

## A. Fundamentals

### A1. What happens when you type `ls -l /etc` and press Enter? **[L1→L2]**

<details><summary>Model answer</summary>

The terminal sends characters to the shell via the TTY/PTY. Bash reads the line, tokenizes it, performs expansions (brace, tilde, parameters, command substitution, arithmetic, word splitting, globbing), and removes quotes. It resolves `ls` (alias → function → builtin → hash/`$PATH`), here an alias to `ls --color=auto`, then `/usr/bin/ls`. It `fork()`s (copy-on-write), the child `execve()`s `/usr/bin/ls` with the arguments; the dynamic loader maps glibc. `ls` calls `openat`/`getdents64` on `/etc` and `statx` per entry (permission checks: DAC then SELinux), formats output and `write()`s to fd 1 (the PTY). It exits; the parent `wait4()`s, stores the status in `$?`, and prints the prompt. Follow-ups: why `cd` must be a builtin; what `strace -f` would show. → [Shell basics §2.3](../shell-and-command-line/shell-basics-and-command-syntax.md#23-how-bash-processes-a-command-line-interview-knowledge), [processes & syscalls §4](../processes-and-resource-management/processes-and-system-calls.md#4-process-lifecycle-fork-exec-wait-exit)

</details>

### A2. Walk me through the RHEL boot process. Where can it fail and how do you fix each stage? **[L1→L2]**

<details><summary>Model answer</summary>

UEFI firmware → shim (Microsoft-signed, Secure Boot) → GRUB2 reading BLS entries → kernel + initramfs (dracut) → systemd in the initramfs finds and mounts the real root at `/sysroot` (LVM, LUKS, RAID drivers) → switch-root → systemd PID 1 starts `default.target`. Failures: no boot device (firmware/ESP), `grub>` prompt (config/ESP; rescue media), panic "unable to mount root" or dracut timeout (initramfs/`root=`/`rd.lvm.lv=`; boot older kernel, `dracut -f --kver`), emergency mode (fstab/mounts; `journalctl -xb`), boot loop (default target; `systemd.unit=`), login problems (`rd.break` + `/.autorelabel`). → [boot process](../boot-systemd-and-kernel/boot-process.md), [boot recovery](../boot-systemd-and-kernel/boot-recovery.md)

</details>

### A3. A user can't open a file. List everything that could cause "Permission denied". **[L1→L2]**

<details><summary>Model answer</summary>

In order: missing `x` on a parent directory (`namei -l`); DAC class bits (owner → named ACL user → groups with mask → other; first match wins); stale session groups (re-login); ACL mask; SELinux type (`ls -Z`, `ausearch -m avc`); immutable/append-only attributes (`lsattr`); mount options (`ro`, `noexec`, `nosuid`); for root inside a container or sandboxed service: missing capabilities (`CAP_DAC_OVERRIDE`), `ProtectSystem=`, user namespace mappings; NFS root_squash/ID mapping. → [file permissions §4](../users-groups-and-permissions/file-permissions.md#4-diagnosing-permission-problems-rhcsa-core)

</details>

### A4. Hard link vs symbolic link; what happens to disk space when you delete a file? **[L1]**

<details><summary>Model answer</summary>

A directory entry maps a name to an inode. A hard link is another name for the same inode (same filesystem, no directories). A symlink is its own inode whose data is a path (can cross filesystems, can dangle). Data is freed only when the link count reaches 0 **and** no process holds it open; that's why deleting a log written by a running process doesn't free space (`lsof +L1`). → [links](../users-groups-and-permissions/links.md)

</details>

### A5. Explain `sudo` vs `su`, and how you'd give a team the ability to restart one service only. **[L1→L2]**

<details><summary>Model answer</summary>

sudo is set-UID root, evaluates sudoers rules per command (last match wins), authenticates **you** via PAM and logs each command; su starts a shell as the target and needs the target's password (fails on RHEL 10 with root locked). Rule: `%web ALL=(root) NOPASSWD: /usr/bin/systemctl restart httpd, /usr/bin/systemctl status httpd` in `/etc/sudoers.d/web` (no dot in the name, 0440, `visudo -c`). Mention escapes: don't allow `systemctl` with any arguments (`systemctl edit` → root) or editors/pagers; use sudoedit or wrapper scripts. → [sudo](../users-groups-and-permissions/sudo-and-privileged-access.md)

</details>

## B. Processes & Memory

### B1. `kill -9` doesn't kill a process. Why, and what do you do? **[L2]**

<details><summary>Model answer</summary>

Either it's a **zombie** (already dead; the parent hasn't `wait()`ed; fix or kill the parent), or it's in **uninterruptible sleep (D)**, blocked in the kernel, usually on I/O (NFS, failing disk); signals are acted on only when the wait ends (killable waits are the exception). Investigate with `ps -o stat,wchan`, `/proc/PID/stack`, `dmesg` (hung task, I/O errors, NFS not responding) and fix the storage/network path. Also: PID 1 in a namespace ignores signals it has no handler for (from inside). → [processes & syscalls §4.3–4.4](../processes-and-resource-management/processes-and-system-calls.md#43-exit-zombies-wait-and-orphans)

</details>

### B2. Load average is 40 on a 16-core box. Is that bad? **[L2]**

<details><summary>Model answer</summary>

Depends. Linux load counts tasks (threads) runnable **or** in D state, damped over 1/5/15 min. Check whether it's CPU (`vmstat` `r` > 16, high `us/sy`, `mpstat`, PSI cpu) or I/O (`b`, `wa`, D-state processes, `iostat` await, PSI io). Trend matters (1-min vs 15-min). A load of 40 with idle CPUs and D-state tasks = storage/NFS problem, not CPU. → [top §2](../processes-and-resource-management/top-and-process-monitoring.md#2-the-summary-area)

</details>

### B3. `free` shows 200 MB free on a 64 GB server. The team wants to add RAM. What do you say? **[L2]**

<details><summary>Model answer</summary>

Free is meant to be small: the page cache uses idle RAM. Look at `MemAvailable`, swap activity (`si/so`), major faults, PSI memory, and OOM events. If available is high and there's no pressure, nothing's wrong. If there is pressure, identify consumers by RSS/PSS (`smaps_rollup`), check for leaks (AnonPages growth), tmpfs (Shmem), slab growth. → [memory management](../processes-and-resource-management/memory-management.md)

</details>

### B4. A container was OOMKilled but the node had 30 GB free. Explain. **[L2→L3]**

<details><summary>Model answer</summary>

Container limits are cgroup `memory.max`. When the cgroup's charged memory (anon + page cache + kernel memory) reaches the limit and reclaim fails, the **cgroup** OOM killer kills a task inside it (SIGKILL, exit 137) regardless of node memory. Evidence: `memory.events oom_kill`, kernel log "Memory cgroup out of memory", Kubernetes status OOMKilled. Fix: right-size the limit from real peak usage, fix leaks, consider `memory.high`; note that page cache counts toward the limit but is reclaimable. → [cgroups §3.2](../containers-and-virtualization/namespaces-and-cgroups.md#32-memory-limit-by-hand-verified)

</details>

### B5. What does `fork()` do, and why can a big process fork quickly but then run out of memory? **[L3]**

<details><summary>Model answer</summary>

`fork()` duplicates the process lazily: page tables are copied, pages are shared read-only, and a page is copied only on write (COW). Forking a 20 GB process is quick, but if parent and child both write (e.g., Redis snapshotting under write load), memory use can approach double. With overcommit heuristics the fork succeeds and the OOM killer may act later; with strict overcommit the fork itself fails. → [processes §4.1](../processes-and-resource-management/processes-and-system-calls.md#41-fork-and-copy-on-write), [memory §7](../processes-and-resource-management/memory-management.md#7-overcommit)

</details>

## C. Storage

### C1. `df` says the filesystem is full, `du` says it's half empty. **[L1→L2]**

<details><summary>Model answer</summary>

Deleted-but-open files (`lsof +L1`, fix by restarting/truncating via `/proc/PID/fd/N`), files hidden under a mount point (mount the device elsewhere and look), reserved blocks on ext4, or snapshots/thin provisioning semantics. Also check inodes (`df -i`). → [scenario 9](production-scenarios.md#9-disk-full-du-disagrees--production)

</details>

### C2. An app says "saved", the power fails, the data is gone. How? **[L2→L3]**

<details><summary>Model answer</summary>

`write()` only puts data in the page cache (dirty pages); writeback happens later (dirty thresholds, ~30 s expiry). Without `fsync()`/`fdatasync()` (and the device honoring cache flushes), data can be lost. Journaling keeps filesystem **metadata** consistent, not unsynced data. Safe pattern: write temp → fsync → rename → fsync the directory. → [storage I/O path §5](../storage-and-filesystems/storage-io-path.md#5-writes-dirty-pages--durability)

</details>

### C3. Replace a failing disk in an LVM volume group with no downtime. **[L2]**

<details><summary>Model answer</summary>

Add the new disk as a PV (`pvcreate`), `vgextend VG NEWPV`, `pvmove OLDPV` (online, mirrors extents then switches), `vgreduce VG OLDPV`, `pvremove OLDPV`, then remove the disk. Mention I/O impact (run off-peak), resumability of `pvmove`, and that RAID/multipath may be the better layer depending on the architecture. → [VG migration §5](../storage-and-filesystems/lvm-vg-merge-split-and-migration.md#5-migrating-data-to-a-new-disk-pvmove)

</details>

### C4. `iostat` shows `%util` 100% on an NVMe drive. Is it saturated? **[L2]**

<details><summary>Model answer</summary>

Not necessarily: `%util` is "time with at least one request in flight", meaningful for single-queue HDDs. NVMe serves many requests in parallel, so judge by `await` (latency), `aqu-sz` (queue depth), IOPS/throughput vs device specs, and application latency (`biolatency`). → [storage I/O path §8](../storage-and-filesystems/storage-io-path.md#8-measuring-io)

</details>

## D. Networking

### D1. Explain everything that happens when you run `curl https://api.example.com`. **[L2→L3]**

<details><summary>Model answer</summary>

nsswitch → `/etc/hosts` → DNS queries to `resolv.conf` servers (search/ndots), route lookup (`ip route get`), ARP/ND for the gateway, `connect()` from an ephemeral port: SYN, SYN-ACK, ACK (passing netfilter OUTPUT/POSTROUTING), TLS handshake with SNI, certificate chain validation against the trust store and hostname check, HTTP request/response, connection close (TIME_WAIT on the closer). Mention how to time each phase with `curl -w` and which tool debugs each layer. → [TCP/IP §3](../networking-and-ssh/tcp-ip-for-operators.md#3-end-to-end-what-happens-on-curl-httpsapiexamplecomhealth)

</details>

### D2. A service is unreachable from clients. Go. **[L1→L2]**

<details><summary>Model answer</summary>

Is it running and listening on the right address (`ss -tlnp`: 0.0.0.0 vs 127.0.0.1)? Local curl? Firewall (`firewall-cmd --list-all`), SELinux port label, route/ARP from the client, does the SYN arrive (`tcpdump`), refused (RST) vs timeout (drop) vs no route (ICMP), DNS name resolves to the right IP, TLS. → [TCP/IP §16](../networking-and-ssh/tcp-ip-for-operators.md#16-troubleshooting-flow-service-x-is-unreachable)

</details>

### D3. Thousands of sockets in CLOSE_WAIT vs TIME_WAIT: which is the problem? **[L2]**

<details><summary>Model answer</summary>

CLOSE_WAIT: the peer closed, our application never called `close()`: a bug that leaks fds until "Too many open files". TIME_WAIT: we closed first; normal, ~60 s, harmless on servers, but on clients making many short connections to one destination it can exhaust ephemeral ports (`EADDRNOTAVAIL`): use connection reuse. → [TCP/IP §4, §6](../networking-and-ssh/tcp-ip-for-operators.md#4-tcp-connection-lifecycle)

</details>

### D4. Small HTTP requests work, large responses hang. **[L3]**

<details><summary>Model answer</summary>

Classic PMTUD black hole: a smaller MTU on the path (VPN, overlay, tunnel) and ICMP "fragmentation needed" blocked, so large DF packets vanish. Test with `ping -M do -s 1472`, `tracepath`, `ss -ti` (mss); fix by allowing the ICMP, setting the correct MTU, or MSS clamping. → [TCP/IP §9](../networking-and-ssh/tcp-ip-for-operators.md#9-mtu-and-path-mtu-discovery)

</details>

### D5. How does `podman run -p 8080:80` (or a Kubernetes Service) deliver packets to the container? **[L3]**

<details><summary>Model answer</summary>

The container has its own network namespace, connected by a veth pair to a host bridge. The runtime installs a DNAT rule (netfilter PREROUTING/OUTPUT, or an equivalent proxy for rootless) from host:8080 to container-IP:80, with IP forwarding on and masquerade (SNAT) in POSTROUTING for outbound traffic; conntrack maps replies back. Kubernetes Services do the same with kube-proxy-managed DNAT (iptables/nftables/IPVS) to pod IPs. → [TCP/IP §11–12](../networking-and-ssh/tcp-ip-for-operators.md#11-netfilter-nftables--conntrack), [K8s bridge](../advanced-rhel-and-career-notes/linux-foundations-of-kubernetes.md)

</details>

## E. systemd, Security & Operations

### E1. Your service starts before the database is ready and crashes at boot. **[L2]**

<details><summary>Model answer</summary>

`Requires=`/`Wants=` only pull units in; ordering needs `After=`. Add `Requires=postgresql.service` + `After=postgresql.service` (and `After=network-online.target` + `Wants=` if it connects remotely). Even then "started" ≠ "accepting connections" unless the DB uses `Type=notify`, so the app should retry with backoff; add `Restart=on-failure`. → [systemd unit files §5](../boot-systemd-and-kernel/systemd-unit-files.md#5-dependencies-vs-ordering-the-most-misunderstood-part)

</details>

### E2. How would you harden a new internet-facing RHEL server? **[L2→L3]**

<details><summary>Model answer</summary>

Minimal install and patching (`dnf upgrade --security`, automation); SSH keys only, no root login, `AllowGroups`; sudo with least privilege; firewalld default-deny with only needed services (source-restricted admin access); SELinux enforcing; services with systemd sandboxing and dedicated users; crypto policy DEFAULT or FUTURE; auditd rules for identity/privilege changes and central log forwarding; time sync; disable unused services; compliance scanning (OpenSCAP `scap-security-guide`); backups and tested restores. → [SSH hardening](../networking-and-ssh/ssh-server-hardening.md), [auditd](../firewall-and-selinux/auditd.md), [systemd §10](../boot-systemd-and-kernel/systemd-unit-files.md#10-sandboxing-hardening)

</details>

### E3. SELinux is blocking an application. What's your process? **[L1→L2]**

<details><summary>Model answer</summary>

Never disable it. Reproduce, then `ausearch -m AVC -ts recent` / `sealert`. Read scontext, tcontext, tclass and the permission. Fix in order: wrong file label (`semanage fcontext` + `restorecon`), boolean (`setsebool -P`), port label (`semanage port`), and only as a last resort a reviewed custom module (`audit2allow -M`). Per-domain permissive mode for development. → [SELinux troubleshooting](../firewall-and-selinux/selinux-booleans-ports-troubleshooting.md)

</details>

### E4. How would you patch 1,000 RHEL servers safely? **[L3 design]**

<details><summary>Model answer</summary>

Inventory and grouping (canary → batches by role/AZ), a controlled content source (Satellite/mirrored repos, frozen snapshots), automation (Ansible: drain from load balancer, `dnf upgrade`, reboot when needed via `needs-restarting -r`, health checks, re-add), concurrency limits and automatic stop on failures, rollback plans (dnf history, LVM/VM snapshots, image-based immutable hosts), monitoring of error rates during rollout, and reporting/compliance. → [Ansible starter](../bash-scripting-and-automation/ansible-starter.md)

</details>

### E5. Design central logging for a fleet. **[L3 design]**

<details><summary>Model answer</summary>

Local: persistent journald with size caps; forward via rsyslog (RELP/TCP+TLS) or an agent (Vector/Fluent Bit/OTel collector) to a central pipeline with buffering; structured fields (host, unit, severity); retention tiers; access control; audit logs shipped separately and immutably; alerting on patterns; clock sync everywhere (timestamps). Mention back-pressure and what happens when the central store is down. → [system logging](../logs-scheduling-and-packages/system-logging.md)

</details>

## F. Live Exercises (do them in a terminal)

### F1. Top 5 client IPs with HTTP 5xx in an Apache access log. **[L1→L2]**

<details><summary>Model answer</summary>

```bash
awk '$9 ~ /^5[0-9][0-9]$/ {print $1}' /var/log/httpd/access_log | sort | uniq -c | sort -rn | head -5
```

Explain the fields of the combined log format ($1 client, $9 status), why `sort` before `uniq -c`, and `LC_ALL=C` for speed on big files. → [awk](../files-and-text-processing/awk.md), [grep & regex](../files-and-text-processing/grep-and-regular-expressions.md)

</details>

### F2. Write a script that takes usernames and reports which exist, exiting non-zero if any don't. **[L1]**

<details><summary>Model answer</summary>

```bash
#!/bin/bash
(( $# )) || { echo "Usage: $0 USER..." >&2; exit 2; }
rc=0
for u in "$@"; do
  if entry=$(getent passwd "$u"); then
    IFS=: read -r _ _ uid _ _ home shell <<< "$entry"
    echo "$u: exists UID=$uid HOME=$home SHELL=$shell"
  else
    echo "$u: missing" >&2; rc=1
  fi
done
exit "$rc"
```

Discussion points: `getent` (directory users) vs grep, quoting `"$@"`, exit codes, stderr. → [robust scripts](../bash-scripting-and-automation/robust-scripts.md)

</details>

### F3. Find which process is listening on port 8080, its user, its open files count and its limits. **[L2]**

<details><summary>Model answer</summary>

```bash
ss -tlnpH 'sport = :8080'                     # users:(("python3",pid=1234,fd=3))
ps -o pid,user,cmd -p 1234 ; ls /proc/1234/fd | wc -l ; grep 'open files' /proc/1234/limits
systemctl status 1234                         # which unit (cgroup) it belongs to
```

→ [processes & syscalls §8](../processes-and-resource-management/processes-and-system-calls.md#8-procpid-a-processs-dashboard)

</details>

## Cross-References

- [Troubleshooting methodology](troubleshooting-methodology.md) · [Production scenarios](production-scenarios.md)
- [Curriculum (what to study before each question level)](../../docs/curriculum.md)
