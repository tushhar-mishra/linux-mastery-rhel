# SELinux MLS & MCS (Security Levels and Categories)

> **[Advanced/Optional]** · **[Interview Knowledge]**
> **Related:** [SELinux fundamentals](selinux-fundamentals.md) · [Confined users](selinux-confined-users-and-domains.md) · [File contexts](selinux-file-contexts.md)

## 1. Overview

The fourth field of an SELinux context is the **level**: a **sensitivity** plus optional **categories**:

````
user:role:type:sensitivity[:categories]
system_u:object_r:etc_t:s0
unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023      ← a RANGE: low-high
system_u:system_r:container_t:s0:c123,c456                 ← container with two categories
````

| Element | Syntax | Meaning |
|---|---|---|
| Sensitivity | `s0` … `s15` | Ordered levels (s0 lowest), e.g., Unclassified < Confidential < Secret < Top Secret |
| Categories | `c0` … `c1023`; lists `c1,c5`; ranges `c0.c3` | Unordered compartments (projects, tenants) |
| Range | `low-high` | Subjects (processes/users) have a range; objects usually a single level |

## 2. MLS: Multi-Level Security (Bell–LaPadula)

| Rule | Meaning | Example |
|---|---|---|
| **No read up** | A subject can't read objects with a higher sensitivity | Confidential (s1) can't read Secret (s2) |
| **No write down** | A subject can't write to lower-sensitivity objects (prevents leaks) | Secret process can't write an Unclassified file |
| **Category dominance** | The subject's categories must include all of the object's categories | Needs `c100` to read a `c100` file |

Red Hat's MLS policy summarizes data flow as: processes can **read** the same or lower levels, and **write** to their own or higher levels. DAC still applies on top: both must allow access.

**Example (corrected):**

| Subject / object | Level |
|---|---|
| Alice: Secret, categories ProjectA + Engineering | `s2:c100,c101` |
| Bob: Confidential, Engineering | `s1:c101` |
| `/srv/projectA/plan.txt`: Secret, ProjectA | `s2:c100` |
| `/srv/notes/public.txt`: Unclassified | `s0` |

- Alice reads `plan.txt` ✔ (s2 ≥ s2 and she has c100).
- Bob can't read `plan.txt` ✘ (s1 < s2, and he lacks c100).
- Alice can't write `public.txt` ✘ (write down). Both can read it (if DAC allows).

## 3. MCS: Multi-Category Security (used by default)

RHEL's **targeted** policy uses **MCS**: one sensitivity (`s0`) plus categories. Its main use is isolating instances of the same domain from each other:

- **Containers (Podman) and VMs (sVirt/libvirt)** each get a unique random category pair, so two `container_t` processes can't access each other's files.
- Users' ranges `s0-s0:c0.c1023` give access to all categories.

```bash
podman run -d --name web1 registry.access.redhat.com/ubi10/ubi sleep 1000   # (if Podman is available)
ps -eZ | grep container_t            # …:container_t:s0:c123,c456 (differs per container)
ls -Z ~/.local/share/containers/storage/overlay* 2>/dev/null | head   # matching categories on files
chcat -L                             # category translations (mcstrans) [Advanced]
cat /etc/selinux/targeted/setrans.conf   # human-readable names for levels/categories
```

## 4. Enabling the MLS Policy (lab only)

```bash
dnf install -y selinux-policy-mls
vi /etc/selinux/config        # SELINUX=permissive , SELINUXTYPE=mls
fixfiles -F onboot            # (or: touch /.autorelabel) — full relabel for the new policy
reboot
ausearch -m AVC -ts boot      # review denials in permissive mode
semanage login -l             # map users with suitable ranges, e.g. semanage login -a -s staff_u -r s0-s2:c0.c100 alice
vi /etc/selinux/config        # SELINUX=enforcing when clean → reboot
```

> ⚠️ Switching policy type relabels the whole filesystem and can lock users out. Graphical desktops and many third-party applications aren't designed for MLS. Use it in a test environment first; it's meant for specialized high-assurance systems.

## 5. Production Context **[Production Practice]**

| Scenario | Mechanism |
|---|---|
| Government/defense classified systems | Full **MLS** policy |
| Multi-tenant hosting, containers, VMs | **MCS** categories in targeted policy (automatic) |
| Project separation on one server | Categories (`chcat`) with targeted MCS **[Advanced]** |

A higher clearance **isn't** administrative privilege; it only controls data access.

## 6. Interview Questions

| Question | Answer |
|---|---|
| MLS vs MCS? | MLS uses ordered sensitivity levels with no-read-up/no-write-down; MCS uses categories at one level (s0) to separate instances. |
| Why do two containers have different `:s0:cX,cY`? | MCS isolation (sVirt): each gets unique categories so they can't access each other's data. |
| What does `s0-s0:c0.c1023` mean? | A range from s0 (no categories) up to s0 with all categories. |
| Does SELinux MLS replace DAC? | No; both must allow access. |

## 7. Quick Revision

````
level = sN[:cX,cY | :cA.cB] · range = low-high · MLS: no read up, no write down (+ categories) · DAC still applies
targeted = MCS (s0 + categories) → containers/VMs: container_t:s0:cX,cY
MLS policy: selinux-policy-mls → SELINUXTYPE=mls + permissive → fixfiles -F onboot → reboot → review → enforcing
````

## 8. Cross-References

- [SELinux fundamentals](selinux-fundamentals.md)
- [Confined users](selinux-confined-users-and-domains.md)
- [File contexts](selinux-file-contexts.md)
