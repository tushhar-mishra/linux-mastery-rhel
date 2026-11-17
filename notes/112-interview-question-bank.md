# 112 · Interview Question Bank (with Model Answers)

> **You need first:** [111 · Linux foundations of Kubernetes](111-linux-foundations-of-kubernetes.md) (this bank draws on the whole path)
> **Next:** [113 · What to learn next](113-what-to-learn-next.md)

---

## What it is

Integrative and scenario questions of the kind asked in Linux admin, DevOps, SRE and platform interviews, each with a **model answer** and the topics to review. Every topic in this path also ends with 2–3 short questions; this bank covers the bigger "explain" and "what would you do" questions.

Levels:
- **L1**: junior admin.
- **L2**: mid-level admin / DevOps.
- **L3**: senior SRE / platform engineer, including design questions.

## Why it exists

Knowing a fact and **explaining it under pressure** are different skills. Interviewers want to hear:
- a structure;
- the mechanism underneath;
- what you'd check and why;
- the trade-offs.

Practising out loud, with a model answer to compare against, is the fastest way to build that skill.

## Analogy

This is a **sparring partner**. Reading the answers is like watching boxing videos: useful, but you only improve by getting in the ring. Answer each question out loud **before** opening the model answer.

## How it works inside

**How interviewers grade:**

| They look for | Not |
|---|---|
| A structured approach (scope → evidence → hypotheses → test) | Jumping straight to a fix |
| Mechanisms ("the shell forks, the child execs…") | Reciting commands |
| What you'd check, and why | False certainty |
| Trade-offs and failure modes | One "right" answer |
| "I don't know, but here's how I'd find out" | Bluffing |

**How to practise:**
1. Pick a question.
2. Answer out loud for 2–4 minutes (L2/L3), or write bullet points.
3. Open the model answer and compare: did you mention the mechanism? The evidence commands? The trade-offs?
4. Re-read the linked topics for anything you missed, and repeat a week later.

## Commands

The "commands" here are the questions themselves.

### A. Fundamentals

#### A1. What happens when you type `ls -l /etc` and press Enter? **[L1→L2]**

<details><summary>Model answer</summary>

1. The terminal sends characters to the shell through the PTY.
2. Bash reads the line, splits it into words, performs expansions (brace, tilde, parameters, command substitution, arithmetic, word splitting, globbing), and removes quotes.
3. It resolves `ls`: alias → function → builtin → hash/`$PATH`. Here it's an alias for `ls --color=auto`, which resolves to `/usr/bin/ls`.
4. It `fork()`s (copy-on-write), and the child `execve()`s `/usr/bin/ls`; the dynamic loader maps glibc.
5. `ls` calls `openat`/`getdents64` on `/etc` and `statx` per entry. Each access passes permission checks: DAC, then SELinux.
6. It formats the output and `write()`s it to fd 1 (the PTY), then exits.
7. Bash `wait4()`s, stores the status in `$?`, and prints the prompt.

Follow-ups: why `cd` must be a builtin; what `strace -f` shows. → Topics 011–014, 092.
</details>

#### A2. Walk me through the RHEL boot process. Where can it fail, and how do you fix each stage? **[L1→L2]**

<details><summary>Model answer</summary>

UEFI firmware → shim (Secure Boot) → GRUB2 reading BLS entries → kernel + initramfs (dracut) → systemd inside the initramfs finds and mounts the real root at `/sysroot` (LVM, LUKS, RAID drivers) → switch-root → systemd as PID 1 starts `default.target`.

| Failure | Where | Fix |
|---|---|---|
| No boot device | Firmware / ESP | Boot order, ESP |
| A `grub>` prompt | GRUB config or ESP | Rescue media |
| Panic "unable to mount root", or a dracut timeout | initramfs, `root=`, `rd.lvm.lv=` | Older kernel; `dracut -f --kver` |
| Emergency mode | fstab or mounts | `journalctl -xb` |
| Boot loop | Default target | `systemd.unit=` |
| Can't log in | Password, PAM, shell | `rd.break` + `/.autorelabel` |

→ Topics 053–057.
</details>

#### A3. A user can't open a file. List everything that could cause "Permission denied". **[L1→L2]**

<details><summary>Model answer</summary>

In order:
1. A missing `x` on a parent directory (`namei -l`).
2. Permission classes: owner → named ACL user → groups (with the mask) → other; the first match wins.
3. Stale session groups (re-login needed).
4. The ACL mask.
5. The SELinux type (`ls -Z`, `ausearch -m avc`).
6. Immutable or append-only attributes (`lsattr`).
7. Mount options (`ro`, `noexec`, `nosuid`).
8. For root in a container or sandboxed service: missing capabilities, `ProtectSystem=`, user-namespace mapping.
9. NFS `root_squash` or ID mapping.

→ Topics 026, 027, 072, 092, 097, 098.
</details>

#### A4. Hard link vs symbolic link. What happens to disk space when you delete a file? **[L1]**

<details><summary>Model answer</summary>

- A directory entry maps a name to an inode.
- A **hard link** is another name for the same inode: same filesystem only, and not for directories.
- A **symlink** is its own inode whose data is a path. It can cross filesystems and can dangle.
- Data is freed only when the link count reaches 0 **and** no process still holds the file open. That's why deleting a log a running process is writing doesn't free space (`lsof +L1`).

→ Topic 008.
</details>

#### A5. `sudo` vs `su`, and how would you let a team restart one service only? **[L1→L2]**

<details><summary>Model answer</summary>

- **sudo** is set-UID root. It checks sudoers rules per command (the last match wins), authenticates **you** via PAM, and logs every command.
- **su** starts a shell as the target user and needs the target's password, so it fails for root on RHEL 10, where root is locked.

The rule, in `/etc/sudoers.d/web` (no dot in the name, mode 0440, then `visudo -c`):
```
%web ALL=(root) NOPASSWD: /usr/bin/systemctl restart httpd, /usr/bin/systemctl status httpd
```

Never allow `systemctl` with any arguments (`systemctl edit` = root), editors or pagers; use `sudoedit` or wrapper scripts. → Topic 028.
</details>

### B. Processes and memory

#### B1. `kill -9` doesn't kill a process. Why, and what do you do? **[L2]**

<details><summary>Model answer</summary>

Two possibilities:
- It's a **zombie**: already dead, and the parent hasn't `wait()`ed. Fix or kill the parent.
- It's in **uninterruptible sleep (D)**: blocked in the kernel, usually on I/O (NFS, a failing disk). The signal is only acted on when the wait ends. Investigate with `ps -o stat,wchan`, `/proc/PID/stack` and `dmesg` (hung tasks, I/O errors, "NFS not responding"), and fix the storage or network path.

Also: PID 1 of a namespace ignores signals it has no handler for, when they're sent from inside. → Topic 092.
</details>

#### B2. Load average is 40 on a 16-core box. Is that bad? **[L2]**

<details><summary>Model answer</summary>

It depends. Linux load counts threads that are runnable **or** in D state, averaged over 1/5/15 minutes.
- **CPU problem:** `vmstat` `r` > 16, high us/sy, `mpstat`, PSI cpu (RHEL: boot with `psi=1` first).
- **I/O problem:** `b`, `wa`, D-state processes, `iostat` await, PSI io.

The trend matters (1-minute vs 15-minute). A load of 40 with idle CPUs and D-state tasks means a storage or NFS problem, not a CPU one. → Topics 034, 103.
</details>

#### B3. `free` shows 200 MB free on a 64 GB server. The team wants more RAM. What do you say? **[L2]**

<details><summary>Model answer</summary>

"Free" is meant to be small: the page cache uses idle RAM. Look at:
- `MemAvailable`;
- swap activity (`si`/`so`);
- major faults;
- PSI memory;
- OOM events.

If available memory is high and there's no pressure, nothing's wrong. If there is pressure, find the consumers by RSS/PSS (`smaps_rollup`), and check for leaks (AnonPages growth), tmpfs (Shmem) and slab growth. → Topic 093.
</details>

#### B4. A container was OOMKilled but the node had 30 GB free. Explain. **[L2→L3]**

<details><summary>Model answer</summary>

- Container limits are the cgroup's `memory.max`. When the cgroup's charged memory (anonymous + page cache + kernel memory) reaches it and reclaim fails, the **cgroup** OOM killer kills a task inside it (SIGKILL, exit 137), whatever the node's free memory.
- **Evidence:** `memory.events` `oom_kill`, kernel log "Memory cgroup out of memory", Kubernetes status `OOMKilled`.
- **Fix:** size the limit from the real peak, fix leaks, consider `memory.high`. Page cache counts towards the limit, but it's reclaimable.

→ Topics 093, 097, 111.
</details>

#### B5. What does `fork()` do, and why can a big process fork quickly but then run out of memory? **[L3]**

<details><summary>Model answer</summary>

- `fork()` duplicates lazily: page tables are copied, pages are shared read-only, and a page is copied only when written (**copy-on-write**). So forking a 20 GB process is fast.
- But if parent and child both write a lot (e.g. Redis snapshots under write load), memory use can approach double.
- With heuristic overcommit, the fork succeeds and the OOM killer may act later; with strict overcommit, the fork itself fails.

→ Topics 092, 093.
</details>

### C. Storage

#### C1. `df` says the filesystem is full; `du` says it's half empty. **[L1→L2]**

<details><summary>Model answer</summary>

Possible causes:
- **Deleted-but-open files** (`lsof +L1`): restart the holder, or truncate via `/proc/PID/fd/N`.
- Files **hidden under a mount point**: bind-mount the parent elsewhere and look.
- Reserved blocks on ext4.
- Snapshot or thin-provisioning semantics.

Also check inodes with `df -i`. → Topics 006, 008, 110 (scenario 9).
</details>

#### C2. An app says "saved", the power fails, and the data is gone. How? **[L2→L3]**

<details><summary>Model answer</summary>

- `write()` only puts data in the page cache as dirty pages. Writeback happens later (dirty thresholds, about 30 s expiry).
- Without `fsync()`/`fdatasync()` (and a device that honours cache flushes), data can be lost.
- Journaling keeps filesystem **metadata** consistent, not unsynced data.
- The safe pattern: write a temp file → fsync → rename → fsync the directory.

→ Topic 094.
</details>

#### C3. Replace a failing disk in an LVM volume group with no downtime. **[L2]**

<details><summary>Model answer</summary>

1. `pvcreate NEW`.
2. `vgextend VG NEW`.
3. `pvmove OLD NEW`: it runs online, mirroring the extents and then switching.
4. `vgreduce VG OLD`.
5. `pvremove OLD`, then remove the disk.

Mention the I/O impact (run it off-peak), that `pvmove` can resume after interruption, and that RAID or multipath may be the better layer, depending on the architecture. → Topics 086, 087.
</details>

#### C4. `iostat` shows `%util` 100% on an NVMe drive. Is it saturated? **[L2]**

<details><summary>Model answer</summary>

Not necessarily. `%util` means "time with at least one request in flight", which is meaningful for single-queue HDDs. NVMe serves many requests in parallel, so judge by:
- `await` (latency);
- `aqu-sz` (queue depth);
- IOPS and throughput vs the device's specs;
- application latency (`biolatency`).

→ Topics 094, 103.
</details>

### D. Networking

#### D1. Explain everything that happens when you run `curl https://api.example.com`. **[L2→L3]**

<details><summary>Model answer</summary>

1. nsswitch → `/etc/hosts` → DNS queries to the `resolv.conf` servers (search domains, ndots).
2. Route lookup (`ip route get`), then ARP/ND for the gateway.
3. `connect()` from an ephemeral port: SYN → SYN-ACK → ACK, passing netfilter OUTPUT/POSTROUTING.
4. TLS handshake with SNI; the certificate chain is checked against the trust store, plus a hostname check.
5. The HTTP request and response.
6. Close; the side that closed first enters TIME_WAIT.

Mention timing each phase with `curl -w` and which tool debugs each layer. → Topics 063, 064, 070, 095.
</details>

#### D2. A service is unreachable from clients. Go. **[L1→L2]**

<details><summary>Model answer</summary>

1. Is it running, and listening on the right address? (`ss -tlnp`: 0.0.0.0 vs 127.0.0.1)
2. Does a local `curl` work?
3. Firewall (`firewall-cmd --list-all`) and SELinux port label.
4. Route and ARP from the client.
5. Does the SYN arrive? (`tcpdump`)
6. Refused (RST) vs timeout (drop) vs no route (ICMP).
7. Does DNS resolve to the right IP?
8. TLS.

→ Topics 095, 096, 102.
</details>

#### D3. Thousands of sockets in CLOSE_WAIT vs TIME_WAIT. Which is the problem? **[L2]**

<details><summary>Model answer</summary>

- **CLOSE_WAIT:** the peer closed and our application never called `close()`. It's a bug that leaks fds until "Too many open files".
- **TIME_WAIT:** we closed first. It's normal, lasts about 60 s, and is harmless on servers. On clients making many short connections to one destination, it can exhaust ephemeral ports (`EADDRNOTAVAIL`): reuse connections.

→ Topic 095.
</details>

#### D4. Small HTTP requests work, large responses hang. **[L3]**

<details><summary>Model answer</summary>

A classic PMTUD black hole: a smaller MTU somewhere on the path (VPN, overlay, tunnel), and ICMP "fragmentation needed" is blocked, so large Don't-Fragment packets vanish.
- **Test:** `ping -M do -s 1472`, `tracepath`, `ss -ti` (mss).
- **Fix:** allow the ICMP, set the correct MTU, or clamp the MSS.

→ Topic 095.
</details>

#### D5. How does `podman run -p 8080:80` (or a Kubernetes Service) deliver packets to the container? **[L3]**

<details><summary>Model answer</summary>

- The container has its own network namespace, joined to a host bridge by a veth pair.
- The runtime adds a DNAT rule (PREROUTING/OUTPUT) from host:8080 to container-IP:80; rootless Podman uses a user-space forwarder instead.
- IP forwarding is on, and masquerade (SNAT) in POSTROUTING handles outbound traffic.
- Conntrack maps replies back.
- Kubernetes Services do the same with kube-proxy-managed DNAT (nftables/iptables/IPVS) to pod IPs, or with eBPF in some CNIs.

→ Topics 095, 097, 101, 111.
</details>

### E. systemd, security and operations

#### E1. Your service starts before the database is ready and crashes at boot. **[L2]**

<details><summary>Model answer</summary>

- `Requires=`/`Wants=` only pull units in; ordering needs `After=`. Add `Requires=postgresql.service` + `After=postgresql.service`, plus `Wants=`/`After=network-online.target` if it connects remotely.
- Even then, "started" ≠ "accepting connections" unless the DB uses `Type=notify`, so the app should retry with back-off.
- Add `Restart=on-failure`.

→ Topic 098.
</details>

#### E2. How would you harden a new internet-facing RHEL server? **[L2→L3]**

<details><summary>Model answer</summary>

- **Install and patching:** a minimal install, automated patching (`dnf upgrade --security`).
- **Access:** SSH keys only, no root login, `AllowGroups`; least-privilege sudo.
- **Firewall:** firewalld with only the needed services; admin access restricted by source.
- **Confinement:** SELinux enforcing; services with systemd sandboxing and dedicated users.
- **Crypto:** policy DEFAULT or FUTURE.
- **Auditing:** auditd rules for identity and privilege changes, logs forwarded centrally.
- **Housekeeping:** time sync, unused services disabled, OpenSCAP compliance scans.
- **Recovery:** backups with tested restores.

→ Topics 066, 071, 072, 077, 098, 064.
</details>

#### E3. SELinux is blocking an application. What's your process? **[L1→L2]**

<details><summary>Model answer</summary>

Never disable it. Reproduce the problem, then run `ausearch -m AVC -ts recent` (or `sealert`) and read the scontext, tcontext, tclass and permission. Fix in this order:
1. A wrong file label (`semanage fcontext` + `restorecon`).
2. A boolean (`setsebool -P`).
3. A port label (`semanage port`).
4. Only as a last resort, a reviewed custom module (`audit2allow -M`).

Per-domain permissive mode is fine for development. → Topics 073, 074.
</details>

#### E4. How would you patch 1,000 RHEL servers safely? **[L3 design]**

<details><summary>Model answer</summary>

- **Inventory and grouping:** canary first, then batches by role or availability zone.
- **A controlled content source:** Satellite or mirrored, frozen repo snapshots.
- **Automation** with Ansible, per host:
  1. drain it from the load balancer;
  2. `dnf upgrade`;
  3. reboot if `needs-restarting -r` says so;
  4. run health checks;
  5. re-add it.
- **Safety:** concurrency limits (`serial:`), stop automatically on failures, and rollback plans (dnf history, snapshots, image-based hosts).
- **Watching and reporting:** monitor error rates during the rollout, and report for compliance.

→ Topics 031, 105, 108.
</details>

#### E5. Design central logging for a fleet. **[L3 design]**

<details><summary>Model answer</summary>

- **On each host:** persistent journald with size caps.
- **Shipping:** rsyslog (RELP, or TCP+TLS) or an agent (Vector, Fluent Bit, OpenTelemetry collector) sends to a central pipeline with buffering.
- **Data:** structured fields (host, unit, severity), retention tiers, access control.
- **Audit logs:** shipped separately and immutably.
- **Use:** alerting on patterns.
- **Basics:** clock sync everywhere.
- **Failure planning:** discuss back-pressure, and what happens when the central store is down.

→ Topics 038, 069, 077, 103.
</details>

### F. Live exercises (do them in a terminal)

#### F1. Top 5 client IPs with HTTP 5xx in an access log. **[L1→L2]**

<details><summary>Model answer</summary>

```bash
awk '$9 ~ /^5[0-9][0-9]$/ {print $1}' /var/log/httpd/access_log | sort | uniq -c | sort -rn | head -5
```
Explain the combined log format fields ($1 = client, $9 = status), why `sort` comes before `uniq -c`, and `LC_ALL=C` for speed on big files. → Topics 017–019.
</details>

#### F2. A script that takes usernames, reports which exist, and exits non-zero if any don't. **[L1]**

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
Discuss `getent` (it includes directory users) vs grep, quoting `"$@"`, exit codes, and stderr. → Topics 030, 040–045.
</details>

#### F3. Find which process listens on port 8080, its user, its open-file count and its limits. **[L2]**

<details><summary>Model answer</summary>

```bash
sudo ss -tlnpH 'sport = :8080'          # users:(("python3",pid=1234,fd=3))
ps -o pid,user,cmd -p 1234 ; sudo ls /proc/1234/fd | wc -l ; grep 'open files' /proc/1234/limits
systemctl status 1234                    # which unit (cgroup) it belongs to
```
→ Topics 092, 095.
</details>

### Try it
Pick one question from each section (A–F). Record yourself answering out loud, then compare with the model answer. Repeat any you fumbled one week later.

## Where you'll use it

- **Technical interviews:** phone screens (L1/L2 facts), on-site troubleshooting rounds (D2, C1, B1), and SRE design rounds (E4, E5).
- **On the job:** the same explanations, given to colleagues during incidents and reviews.

## When it breaks

| Interview mistake | Fix |
|---|---|
| Listing commands without saying why | Say what each check rules in or out |
| Freezing on an unknown detail | "I'm not sure; here's how I'd find out" (man page, `strace`, logs) |
| Jumping to "restart it" | Start with scope and evidence (topic 102) |
| Too much theory in a hands-on round | Lead with the command, then explain the mechanism briefly |

## Quick recap

- Answer out loud first, then compare. Mechanism + evidence + trade-offs beats memorised flags.
- The six areas: fundamentals, processes and memory, storage, networking, systemd/security/operations, live exercises.
- Revisit the linked topics for weak answers, and repeat after a week.

**Interview questions**

1. *How would you prepare for a Linux troubleshooting interview?* Practise the method on real break-fix labs (topic 110), explaining out loud: scope, evidence, hypotheses, the test, the fix, prevention.
2. *What should you say when you don't know an answer?* Say so honestly, then explain how you'd find out (documentation, man pages, logs, a quick test in a lab), and reason from the mechanisms you do know.
3. *What do interviewers value more: commands or reasoning?* Reasoning: a structured approach and understanding of mechanisms, with the commands as supporting evidence.

**Scenario question** (answer out loud first, then compare)

> *"Mock interview: 'A user reports that a website hosted on one of your Linux servers is slow. Go.'"*

**Model answer:** (what a strong candidate says, in order)
1. **Clarify:** slow for everyone or some users? All pages or one? Since when? Did anything change?
2. **Measure from outside:** `curl -w` timings show whether DNS, the TCP connect, TLS or time-to-first-byte is slow. That picks the layer.
3. **On the server:**
   - load vs CPUs, `vmstat 1` (run queue, iowait, swapping, steal);
   - `iostat -xz 1`, `free -h` and PSI;
   - `ss -s` and the listen queue.
4. **The application:**
   - web server and app logs, slow upstreams (the database), worker pool saturation;
   - error rates (502/504).
5. **One hypothesis at a time**, with evidence, and say what you'd expect to see if it's true.
6. **Fix and verify** from the user's side; prevent it with monitoring on the signal that would have caught it.
7. Throughout: explain *why* each command, not just *what*. That's what interviewers score.

**Likely follow-ups:**
- *What if you don't know the answer?* Say so, then say how you'd find out, and reason from mechanisms you know.
- *Which matters more, commands or reasoning?* Reasoning, backed by commands as evidence.
