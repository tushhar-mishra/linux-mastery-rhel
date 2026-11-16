# 076 · SELinux MLS and MCS: Levels and Categories

> **You need first:** [075 · SELinux confined users](075-selinux-confined-users.md)
> **Next:** [077 · auditd](077-auditd.md)

---

## What it is

The **fourth field** of an SELinux label is the **level**: a **sensitivity** plus optional **categories**.

```
user:role:type:sensitivity[:categories]
system_u:object_r:etc_t:s0
unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023     ← a RANGE: low-high
system_u:system_r:container_t:s0:c123,c456                ← a container with two categories
```

| Element | Syntax | Meaning |
|---|---|---|
| **Sensitivity** | `s0` … `s15` | **Ordered** levels: s0 lowest (like Unclassified < Confidential < Secret < Top Secret) |
| **Categories** | `c0` … `c1023`; a list `c1,c5`; a range `c0.c3` | **Unordered** compartments (projects, departments, tenants) |
| **Range** | `low-high` | Processes and users have a range; files usually have one level |

Two policies use these fields:
- **MLS** (Multi-Level Security): the full military-style model with ordered sensitivity levels. A separate, specialised policy (`selinux-policy-mls`).
- **MCS** (Multi-Category Security): only one sensitivity (`s0`) plus categories. **Part of the normal targeted policy, and used automatically for containers and VMs.**

## Why it exists

- **MLS** enforces "need to know" for classified data: someone cleared for Confidential must never read Secret, and Secret data must never leak into an Unclassified file, **no matter what file permissions say**.
- **MCS** solves a modern problem: on one host, many **containers** (or VMs) run as the **same** SELinux type (`container_t`), maybe even the same UID. Giving each a **unique category pair** means container A can't read container B's files even if it breaks out of its filesystem view. This is SELinux's "sVirt" protection.

## Analogy

**Sensitivity** is the **floor of a secure building**: you may go to your floor or below to read, but you mustn't carry papers down to a lower floor. **Categories** are **coloured project rooms on the same floor**: you need the matching colour stickers on your badge to enter. MCS gives every container a **unique pair of colours**, so neighbours can't walk into each other's rooms.

## How it works inside

### MLS rules (Bell–LaPadula model)

| Rule | Meaning |
|---|---|
| **No read up** | You can't read data above your level (Confidential can't read Secret) |
| **No write down** | You can't write to data below your level, which prevents leaks (Secret can't write an Unclassified file) |
| **Categories must dominate** | Your categories must include **all** of the object's categories |

In Red Hat's MLS policy: processes may **read** the same or lower levels and **write** to their own (or higher) levels. **DAC still applies too**; both must allow access.

**Example:**

| Who / what | Level |
|---|---|
| Alice: Secret, projects A + Engineering | `s2:c100,c101` |
| Bob: Confidential, Engineering | `s1:c101` |
| `plan.txt`: Secret, project A | `s2:c100` |
| `public.txt`: Unclassified | `s0` |

- Alice reads `plan.txt` ✔ (s2 ≥ s2, and she has c100).
- Bob can't read `plan.txt` ✘ (s1 < s2, and he lacks c100).
- Alice can't write `public.txt` ✘ (write down). Both may read it (if DAC allows).

A higher clearance is **not** admin privilege; it only controls which data you may touch.

### MCS in the targeted policy

- Everything is `s0`. Users get the range `s0-s0:c0.c1023` (all categories), so MCS never gets in their way.
- When Podman or libvirt starts a container or VM, it picks a **random, unused category pair** (for example `c123,c456`), runs the process as `container_t:s0:c123,c456` (or `svirt_t` for VMs), and labels that instance's files with the **same** pair.
- Another container gets `c77,c901`. Both are `container_t`, so type enforcement alone would let them access each other's `container_file_t` files. **The category mismatch blocks it.**

Human-readable names for levels and categories can be defined in `/etc/selinux/targeted/setrans.conf` (the mcstrans service).

## Commands

### See levels on your system

```bash
id -Z ; ls -Z /etc/hosts
```
```
unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023
system_u:object_r:net_conf_t:s0 /etc/hosts
```

### MCS isolation with containers

(Podman is covered in topic 101. Install it with `dnf install podman` to try this now.)
```bash
podman run -d --name a registry.access.redhat.com/ubi10/ubi sleep 1000
podman run -d --name b registry.access.redhat.com/ubi10/ubi sleep 1000
ps -eZ | grep 'container_t'
```
```
system_u:system_r:container_t:s0:c214,c812  5301 ?  00:00:00 sleep
system_u:system_r:container_t:s0:c77,c901   5355 ?  00:00:00 sleep
```
- Same type, **different categories**: the kernel won't let one touch the other's files.

```bash
podman inspect -f '{{.ProcessLabel}} {{.MountLabel}}' a
```
```
system_u:system_r:container_t:s0:c214,c812 system_u:object_r:container_file_t:s0:c214,c812
```
- The process label and the label given to its files share the pair.

### Categories by hand (targeted MCS)

```bash
chcat -L                                       # list category translations
sudo chcat -- +c10 /srv/projectA/plan.txt      # add category c10 to a file
ls -Z /srv/projectA/plan.txt
```
- Mostly used by tools rather than by hand on targeted systems.

### Trying the full MLS policy (throwaway lab only)

```bash
sudo dnf install -y selinux-policy-mls
sudo sed -i 's/^SELINUX=.*/SELINUX=permissive/; s/^SELINUXTYPE=.*/SELINUXTYPE=mls/' /etc/selinux/config
sudo fixfiles -F onboot && sudo reboot        # full relabel for the new policy
sudo ausearch -m AVC -ts boot                 # review denials while permissive
sudo semanage login -a -s staff_u -r s0-s2:c0.c100 alice
```
- Switching policy relabels everything and can lock users out. Graphical desktops and most third-party apps aren't designed for MLS. This is for specialised high-assurance systems.

### Try it
1. Run two containers and compare their `ps -eZ` labels.
2. Start a container with a volume using `:Z` (topic 101) and look at the volume directory's label on the host: it carries the container's categories.
3. Read `/etc/selinux/targeted/setrans.conf`.

## Where you'll use it

- **Every container on RHEL, Fedora and OpenShift** relies on MCS categories, which is why a misbehaving container can't read its neighbours' data.
- **Kubernetes on SELinux hosts:** pods can be given a fixed level (`securityContext.seLinuxOptions.level: "s0:c123,c456"`) so pods sharing a volume use the same categories. OpenShift assigns one category pair **per namespace**.
- **VMs with libvirt (sVirt):** each VM's disk images carry its categories.
- **Government/defence systems:** full MLS.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| A container can't read a volume another container wrote | Different MCS categories on the files | Use `:z` (shared label) instead of `:Z` (private); or set the same level |
| A pod can't read a volume after being rescheduled | A new random category pair | Set a fixed `seLinuxOptions.level`, or let the runtime relabel |
| AVC denial mentions only the level (`s0:c1,c2` vs `s0:c3,c4`) | An MCS mismatch, not a type problem | Fix the labels/levels, not the type |
| Users locked out after switching to MLS | Their mappings or ranges don't fit the new policy | Permissive, fix the mappings, relabel, then enforce |

## Quick recap

- Level = sensitivity (`s0`–`s15`, ordered) + categories (`c0`–`c1023`, compartments). Processes have ranges (`low-high`).
- **MLS:** no read up, no write down, categories must dominate. DAC still applies. A specialised policy.
- **MCS:** `s0` + categories inside the targeted policy. Each container/VM gets a unique pair (`container_t:s0:cX,cY`), isolating same-type processes.
- Volume labels: `:Z` private, `:z` shared.

**Interview questions**

1. *MLS vs MCS?* MLS uses ordered sensitivity levels with "no read up, no write down" rules for classified data. MCS uses categories at a single level (s0) to keep separate instances, such as containers, apart.
2. *Why do two containers on RHEL show different `:s0:cX,cY` suffixes?* Each gets a unique MCS category pair. Both run as `container_t`, but the category mismatch stops either reading the other's files.
3. *What does `s0-s0:c0.c1023` mean?* A range from s0 with no categories up to s0 with all 1024 categories: the normal range for unconfined users, so MCS never restricts them.
