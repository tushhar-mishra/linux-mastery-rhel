# Linux Foundations of Kubernetes (Bridge Note)

> **Track:** **[Interview Knowledge]** · **[Production Practice]** · **Verification status:** the Linux mechanisms referenced were verified in the linked notes. Kubernetes behavior below follows upstream Kubernetes documentation (kubelet, CRI-O/containerd, kube-proxy); it was **not** run in this knowledge base's lab, and defaults can change between Kubernetes/OpenShift versions. Confirm against your cluster version.
> **Prerequisites:** [Namespaces & cgroups](../containers-and-virtualization/namespaces-and-cgroups.md) · [Podman](../containers-and-virtualization/podman-containers.md) · [TCP/IP for operators](../networking-and-ssh/tcp-ip-for-operators.md) · [Memory management](../processes-and-resource-management/memory-management.md) · [Processes & system calls](../processes-and-resource-management/processes-and-system-calls.md) · [systemd unit files](../boot-systemd-and-kernel/systemd-unit-files.md)

## 1. The Point of This Note

Kubernetes doesn't replace Linux; it **schedules and configures Linux features** across many machines. Almost every "Kubernetes problem" that reaches an SRE is a Linux problem on a node: a cgroup limit, a namespace, a netfilter rule, a DNS setting, a filesystem filling up. If you understand the notes linked above, this table is your translation guide.

## 2. Concept Map

| Kubernetes concept | Linux mechanism on the node | Where you learned it |
|---|---|---|
| **Container** | A process tree with its own mnt/pid/uts/ipc (and usually net, via the pod) namespaces, cgroup, overlay rootfs, reduced capabilities, seccomp, SELinux label | [Namespaces & cgroups](../containers-and-virtualization/namespaces-and-cgroups.md) |
| **Pod** | Containers that **share a network namespace** (same IP, same `localhost`) and usually IPC/UTS; an infra ("pause") container holds the namespaces | [TCP/IP §12](../networking-and-ssh/tcp-ip-for-operators.md#12-network-namespaces-veth--bridges-container-networking-in-6-commands) |
| **Image** | Read-only overlayfs layers + a writable upper layer | [Namespaces & cgroups §4](../containers-and-virtualization/namespaces-and-cgroups.md#4-overlay-filesystem-container-image-layers) |
| **Container runtime** (CRI-O on OpenShift/RHEL-based clusters, containerd elsewhere) + OCI runtime (crun/runc) | systemd service on the node that creates the namespaces/cgroups | [systemd unit files](../boot-systemd-and-kernel/systemd-unit-files.md) |
| **kubelet** | systemd service; manages pods' cgroups (cgroup driver `systemd` with cgroups v2) | [systemd](../boot-systemd-and-kernel/systemd-unit-files.md) |
| **resources.requests.cpu** | `cpu.weight`: relative share under contention, never throttles | [cgroups §3.3](../containers-and-virtualization/namespaces-and-cgroups.md#33-cpu-quota-and-throttling-verified) |
| **resources.limits.cpu** | `cpu.max` quota per period → **CFS throttling** (`nr_throttled`) | same |
| **resources.limits.memory** | `memory.max` → cgroup OOM kill → `OOMKilled`, exit code **137** | [Memory §8.1](../processes-and-resource-management/memory-management.md#81-global-oom-vs-cgroup-oom) |
| **QoS class** (Guaranteed / Burstable / BestEffort) | `oom_score_adj` set by kubelet: Guaranteed −997, BestEffort 1000, Burstable in between (by request size) | [Memory §8](../processes-and-resource-management/memory-management.md#8-the-oom-killer) |
| **Node-pressure eviction** | kubelet watches `memory.available`, disk/inode free on nodefs/imagefs, PID availability and evicts pods before the kernel OOM-kills | [Memory](../processes-and-resource-management/memory-management.md), [storage](../storage-and-filesystems/storage-io-path.md) |
| **Pod termination** | SIGTERM to PID 1 of each container → `terminationGracePeriodSeconds` (default 30 s) → SIGKILL | [Processes §4.4 (PID 1)](../processes-and-resource-management/processes-and-system-calls.md#44-pid-1-is-special) |
| **Probes** (liveness/readiness/startup) | kubelet runs a command (`nsenter`-style exec), TCP connect or HTTP GET into the pod's namespaces | [TCP/IP](../networking-and-ssh/tcp-ip-for-operators.md) |
| **CNI networking** | veth pair per pod into the pod's netns + bridge or routing/overlay (VXLAN/Geneve) on the node; MTU must account for overlay headers | [TCP/IP §9, §12](../networking-and-ssh/tcp-ip-for-operators.md#9-mtu-and-path-mtu-discovery) |
| **Service (ClusterIP)** | kube-proxy programs **DNAT** in netfilter (iptables or nftables mode) or IPVS; conntrack tracks flows | [TCP/IP §11](../networking-and-ssh/tcp-ip-for-operators.md#11-netfilter-nftables--conntrack) |
| **NodePort / LoadBalancer** | DNAT on node ports; SNAT/masquerade depending on `externalTrafficPolicy` | same |
| **NetworkPolicy** | Implemented by the CNI plugin (netfilter/nftables or eBPF rules) | same |
| **Cluster DNS** (CoreDNS) | Pod `/etc/resolv.conf` with the cluster DNS server, search domains and **`ndots:5`**: short and external names are tried with each search suffix first | [TCP/IP §13](../networking-and-ssh/tcp-ip-for-operators.md#13-dns-troubleshooting) |
| **Volumes** (hostPath, emptyDir, PVs) | Bind mounts into the container's mount namespace; emptyDir `medium: Memory` = tmpfs (counts toward memory); SELinux relabeling (`:Z`-like) by the runtime | [Mounting](../storage-and-filesystems/mounting-and-fstab.md), [SELinux contexts](../firewall-and-selinux/selinux-file-contexts.md) |
| **Secrets / ConfigMaps** | Files on tmpfs or bind mounts in the container | [Memory (tmpfs = Shmem)](../processes-and-resource-management/memory-management.md#3-two-kinds-of-memory-anonymous-and-file-backed) |
| **securityContext** | `runAsUser`/`runAsNonRoot` (UIDs), `capabilities.add/drop`, `allowPrivilegeEscalation: false` (= no_new_privs), `seccompProfile: RuntimeDefault`, `seLinuxOptions`, `readOnlyRootFilesystem` | [Processes §5](../processes-and-resource-management/processes-and-system-calls.md#5-credentials--privilege), [cgroups §5](../containers-and-virtualization/namespaces-and-cgroups.md#5-privilege-reduction) |
| **Pod sysctls** | Namespaced sysctls (e.g., `net.ipv4.ip_local_port_range`) set inside the pod's network namespace | [Kernel parameters](../boot-systemd-and-kernel/kernel-modules-and-parameters.md) |
| **Container logs** | Runtime captures stdout/stderr to files on the node (`/var/log/pods/`, `/var/log/containers/`); kubelet rotates them | [System logging](../logs-scheduling-and-packages/system-logging.md) |
| **OpenShift SCCs** | Admission rules that pin UID ranges, SELinux MCS categories (`container_t:s0:cX,cY`) and capabilities per namespace | [SELinux MCS](../firewall-and-selinux/selinux-mls-and-mcs.md) |

## 3. Classic Kubernetes Incidents, Explained in Linux Terms

| Symptom | Linux explanation | Node-level evidence |
|---|---|---|
| Pod `OOMKilled`, restarts, exit 137 | Container's cgroup reached `memory.max` | `memory.events` `oom_kill`, kernel log "Memory cgroup out of memory" |
| Latency spikes, CPU usage well below the node's capacity | CPU **limit** → quota exhausted per 100 ms period → throttling | `cpu.stat` `nr_throttled` / `throttled_usec` rising |
| Pod evicted (`The node was low on resource: memory/ephemeral-storage`) | kubelet node-pressure eviction | `kubectl describe node` conditions; `df -h`/`df -i` on `/var/lib/containers` or `/var/lib/kubelet` |
| Pod takes exactly 30 s to terminate | App (PID 1) ignores SIGTERM | Add a handler or an init; check `STOPSIGNAL` |
| DNS lookups slow, external names especially | `ndots:5` + search domains = several failed queries first; conntrack races on UDP | Pod `resolv.conf`; use FQDNs with a trailing dot; NodeLocal DNSCache |
| Intermittent connection timeouts between pods | conntrack table full, MTU mismatch on the overlay, NetworkPolicy drop | `nf_conntrack_count/max`, `dmesg`, `ping -M do`, CNI policy logs |
| `CrashLoopBackOff` | Process exits repeatedly; kubelet restarts with exponential backoff (like systemd `Restart=`) | Container logs (`--previous`), exit code (`128+N`) |
| Node `NotReady` | kubelet or runtime service down, disk/PID pressure, network | `systemctl status kubelet crio`, `journalctl -u kubelet` |
| `ImagePullBackOff` | Registry auth/TLS/DNS, disk full in image storage | Runtime logs, `crictl pull`, `df` on image storage |
| `Permission denied` writing to a volume | UID mismatch (`runAsUser`), SELinux label, read-only mount | `ls -lnZ` on the host path, `ausearch -m avc` |

## 4. Node Debugging Toolkit

```bash
systemctl status kubelet crio ; journalctl -u kubelet --since -30min
crictl ps ; crictl pods ; crictl inspect CONTAINER | grep -i pid      # CRI-level view (cri-tools)
crictl logs CONTAINER
PID=$(crictl inspect --output go-template --template '{{.info.pid}}' CONTAINER)
nsenter -t "$PID" -n ss -tanp          # the pod's sockets, with the node's tools
nsenter -t "$PID" -n tcpdump -nn -i eth0 port 53
cat /proc/$PID/cgroup                  # → path under /sys/fs/cgroup/kubepods.slice/…
cat /sys/fs/cgroup/kubepods.slice/…/memory.events /sys/fs/cgroup/kubepods.slice/…/cpu.stat
nft list ruleset | less                # or iptables-save, when kube-proxy uses iptables mode
```

On OpenShift, `oc debug node/NAME` then `chroot /host` gives you this shell.

## 5. What to Learn Next (outside this knowledge base)

Kubernetes objects and the control plane (API server, etcd, scheduler, controllers), kubectl, Helm/Kustomize, CNI plugins (OVN-Kubernetes, Cilium), storage (CSI), observability (Prometheus, OpenTelemetry), and OpenShift administration (EX280). See [GAPS](../GAPS.md) for the full list. Linux knowledge makes all of them faster to learn and much faster to debug.

## 6. Interview Questions

| Question | Answer |
|---|---|
| What is a pod at the Linux level? | One or more processes sharing a network namespace (and usually IPC/UTS), each with its own mount/PID namespaces and cgroup under the pod's cgroup. |
| CPU request vs limit? | Request → cgroup `cpu.weight` (scheduling share, no throttling); limit → `cpu.max` quota (throttling). |
| Why was my pod OOMKilled when the node has free memory? | Its container's `memory.max` (limit) was reached; the cgroup OOM killer acts independently of node free memory. |
| How does a ClusterIP Service work? | kube-proxy installs DNAT rules (iptables/nftables/IPVS) that rewrite the virtual IP to a backend pod IP; conntrack keeps the mapping for the flow. |
| Why does `kubectl delete pod` take 30 s? | SIGTERM is ignored by PID 1 in the container; after the grace period kubelet sends SIGKILL. |
| What does `ndots:5` cause? | Names with fewer than 5 dots are first tried with every search domain, multiplying DNS queries for external names. |

## 7. Cross-References

- [Namespaces & cgroups](../containers-and-virtualization/namespaces-and-cgroups.md) · [Podman (pods, `kube play`)](../containers-and-virtualization/podman-containers.md) · [SELinux MCS](../firewall-and-selinux/selinux-mls-and-mcs.md)
- [TCP/IP for operators](../networking-and-ssh/tcp-ip-for-operators.md) · [Memory management](../processes-and-resource-management/memory-management.md) · [Processes & system calls](../processes-and-resource-management/processes-and-system-calls.md)
- [Performance & observability](performance-and-observability.md) · [Production scenarios](../troubleshooting-and-interviews/production-scenarios.md)
