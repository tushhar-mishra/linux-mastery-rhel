# 111 · Linux Foundations of Kubernetes

> **You need first:** [110 · Production scenarios](110-production-scenarios.md) (and especially topics 092–098 internals and 101 containers)
> **Next:** [112 · Interview question bank](112-interview-question-bank.md)

---

## What it is

A translation guide: **every core Kubernetes concept is a Linux mechanism you already know**, configured automatically across many machines.

Words (just enough Kubernetes to read this topic):
- **Kubernetes** (K8s): an orchestrator that runs containers across a **cluster** of machines and keeps them in the state you declared.
- **Node**: one machine (usually a VM) in the cluster. It runs **kubelet** (the node agent) and a **container runtime** (CRI-O or containerd).
- **Pod**: the smallest unit Kubernetes runs: one or more containers that share a network identity.
- **Control plane**: the cluster's brain: the API server, **etcd** (its database), the scheduler and controllers.
- **Service**: a stable virtual IP and DNS name in front of a set of pods.
- **CNI** (Container Network Interface) plugin: the component that wires pod networking (Cilium, Calico, OVN-Kubernetes, Flannel).
- **CSI** (Container Storage Interface) driver: the component that attaches storage volumes to nodes.
- **kubectl**: the command-line client. **OpenShift**: Red Hat's Kubernetes distribution (CLI `oc`).

## Why it exists

Kubernetes doesn't replace Linux; it **schedules and configures Linux features** on many machines. Almost every "Kubernetes problem" that reaches an SRE is really a Linux problem on a node:
- a cgroup limit;
- a namespace;
- a netfilter rule;
- a DNS setting;
- a filesystem filling up.

If you understand topics 092–101, you can debug Kubernetes at the level most people can't.

## Analogy

Kubernetes is an **airline's operations centre** deciding which plane flies which route. But each flight is still flown by a **pilot in a cockpit** (Linux on a node), with real engines (CPU), fuel limits (cgroups), separate cabins (namespaces) and air-traffic rules (netfilter). When a flight has a problem, the operations centre's dashboard tells you **which** plane; you still need to understand the cockpit to fix it.

## How it works inside

### Concept map

| Kubernetes concept | Linux mechanism on the node | Topics |
|---|---|---|
| **Container** | A process tree with its own mnt/pid/uts/ipc namespaces, a cgroup, an overlay root filesystem, reduced capabilities, seccomp and an SELinux label | 097 |
| **Pod** | Containers that **share one network namespace** (same IP, same `localhost`), held open by a tiny "pause"/infra container | 097, 095 |
| **Image** | Read-only overlayfs layers + a writable upper layer | 097, 101 |
| **Container runtime** (CRI-O, containerd) + OCI runtime (crun/runc) | A systemd service that creates namespaces and cgroups | 098, 101 |
| **kubelet** | A systemd service; manages pod cgroups (systemd cgroup driver, cgroups v2) under `kubepods.slice` | 098, 097 |
| `resources.requests.cpu` | `cpu.weight`: a share under contention; never throttles | 097 |
| `resources.limits.cpu` | `cpu.max` quota → **throttling** (`nr_throttled`) | 097 |
| `resources.limits.memory` | `memory.max` → cgroup OOM kill → **`OOMKilled`, exit 137** | 093, 097 |
| **QoS class** (Guaranteed / Burstable / BestEffort) | `oom_score_adj` set by kubelet: Guaranteed −997, BestEffort 1000, Burstable in between | 093 |
| **Node-pressure eviction** | kubelet watches memory available, disk/inode free, and PIDs, and evicts pods **before** the kernel OOM-kills | 093, 006 |
| **Pod termination** | SIGTERM to PID 1 of each container → `terminationGracePeriodSeconds` (default 30 s) → SIGKILL | 092 |
| **Probes** (liveness, readiness, startup) | kubelet runs a command inside the container's namespaces, a TCP connect, or an HTTP GET | 095, 070 |
| **CNI networking** | A veth pair per pod into its network namespace, plus a bridge, routing or overlay (VXLAN/Geneve) on the node; the MTU must allow for overlay headers | 095, 097 |
| **Service (ClusterIP)** | kube-proxy writes **DNAT** rules (nftables/iptables) or IPVS entries; conntrack keeps each flow's mapping (some CNIs use eBPF instead) | 095 |
| **NodePort / LoadBalancer** | DNAT on node ports; SNAT/masquerade depending on `externalTrafficPolicy` | 095 |
| **NetworkPolicy** | Firewall rules (nftables or eBPF) installed by the CNI plugin | 071, 095 |
| **Cluster DNS** (CoreDNS) | Each pod's `/etc/resolv.conf` points at cluster DNS, with search domains and **`ndots:5`** | 063 |
| **Volumes** | **Bind mounts** into the container's mount namespace. `emptyDir` with `medium: Memory` = tmpfs (counts as memory). The runtime relabels for SELinux (like `:Z`). PersistentVolumes are often iSCSI/NFS/cloud disks attached by CSI drivers | 048, 073, 079, 083 |
| **Secrets / ConfigMaps** | Files on tmpfs or bind mounts inside the container | 093 |
| **securityContext** | `runAsUser`/`runAsNonRoot` (UIDs), `capabilities.add/drop`, `allowPrivilegeEscalation: false` (= no_new_privs), `seccompProfile`, `seLinuxOptions`, `readOnlyRootFilesystem` | 092, 097 |
| **Pod sysctls** | Namespaced sysctls (e.g. `net.ipv4.ip_local_port_range`) set inside the pod's network namespace | 055 |
| **Container logs** | The runtime writes stdout/stderr to files under `/var/log/pods/` on the node; kubelet rotates them | 038 |
| **OpenShift SCCs** (Security Context Constraints) | Admission rules pinning UID ranges, SELinux MCS categories and capabilities per namespace | 076 |

### Classic incidents, explained in Linux terms

| Kubernetes symptom | Linux explanation | Node-level evidence |
|---|---|---|
| Pod `OOMKilled`, restarts, exit 137 | The container's cgroup reached `memory.max` | `memory.events` `oom_kill`; kernel log "Memory cgroup out of memory" |
| Latency spikes; CPU usage far below the node's capacity | The CPU **limit** quota is used up early in each period → throttling | `cpu.stat` `nr_throttled` / `throttled_usec` rising |
| Pod evicted: "The node was low on resource: memory / ephemeral-storage" | kubelet node-pressure eviction | `kubectl describe node` conditions; `df -h`/`df -i` on `/var/lib/containers` or `/var/lib/kubelet` |
| A pod takes exactly 30 s to terminate | PID 1 ignores SIGTERM | Add a handler or an init; check `STOPSIGNAL` |
| DNS slow, especially for external names | `ndots:5` + search domains = several failed queries first | Pod `resolv.conf`; use FQDNs with a trailing dot; NodeLocal DNSCache |
| Intermittent timeouts between pods | Conntrack table full, overlay MTU mismatch, NetworkPolicy drop | `nf_conntrack_count/max`, `dmesg`, `ping -M do`, CNI logs |
| `CrashLoopBackOff` | The process keeps exiting; kubelet restarts it with growing back-off (like systemd `Restart=`) | Container logs (`--previous`), exit code (128+N) |
| Node `NotReady` | kubelet or runtime down, disk/PID pressure, network | `systemctl status kubelet crio`, `journalctl -u kubelet` |
| `ImagePullBackOff` | Registry auth, TLS, DNS, or image storage full | Runtime logs, `crictl pull`, `df` on image storage |
| `Permission denied` writing to a volume | UID mismatch (`runAsUser`), SELinux label, read-only mount | `ls -lnZ` on the host path, `ausearch -m avc` |

## Commands

### On a node (SSH, or `oc debug node/NAME` then `chroot /host` on OpenShift)

```bash
systemctl status kubelet crio --no-pager | grep -E '●|Active'
journalctl -u kubelet --since -30min | tail
sudo crictl pods | head -3 ; sudo crictl ps | head -3          # the CRI-level view (cri-tools)
```
```
● kubelet.service - Kubernetes Kubelet
     Active: active (running) since Tue 2026-11-17 08:01:12 UTC; 7h ago
● crio.service - Container Runtime Interface for OCI (CRI-O)
     Active: active (running) since Tue 2026-11-17 08:01:05 UTC; 7h ago
POD ID          CREATED       STATE   NAME                       NAMESPACE   ATTEMPT
4b1d2c3e5f6a7   2 hours ago   Ready   web-7c9d8f6b5-x2kqp        shop        0
CONTAINER       IMAGE         CREATED       STATE     NAME   ATTEMPT   POD ID
9e8f7a6b5c4d3   quay.io/…     2 hours ago   Running   web    0         4b1d2c3e5f6a7
```

### From a container to its Linux objects

```bash
CID=9e8f7a6b5c4d3
PID=$(sudo crictl inspect --output go-template --template '{{.info.pid}}' $CID)
sudo cat /proc/$PID/cgroup
sudo ls -l /proc/$PID/ns/net
```
```
0::/kubepods.slice/kubepods-burstable.slice/kubepods-burstable-pod5f1c….slice/crio-9e8f7a6b….scope
lrwxrwxrwx. 1 root root 0 Nov 17 15:30 /proc/41237/ns/net -> 'net:[4026533012]'
```
- The container is a **Burstable** pod's scope under `kubepods.slice`. Its network namespace inode is shared by every container in the same pod.

```bash
CG=/sys/fs/cgroup$(sudo cat /proc/$PID/cgroup | cut -d: -f3)
cat $CG/memory.max $CG/memory.current ; grep oom_kill $CG/memory.events
grep -E 'nr_periods|nr_throttled' $CG/cpu.stat
```
```
536870912
498212864
oom_kill 3
nr_periods 182044
nr_throttled 61233
```
- A 512 MiB limit, nearly reached, with three OOM kills so far, and throttled in a third of all periods. That's two problems explained in four lines (topics 093, 097).

### Use node tools inside the pod's network namespace

```bash
sudo nsenter -t $PID -n ss -tanp                    # the pod's sockets
sudo nsenter -t $PID -n cat /etc/resolv.conf 2>/dev/null || sudo cat /proc/$PID/root/etc/resolv.conf
sudo nsenter -t $PID -n tcpdump -nn -i eth0 port 53
```
```
search shop.svc.cluster.local svc.cluster.local cluster.local
nameserver 172.30.0.10
options ndots:5
```
- Cluster DNS, search domains and `ndots:5`: `api.example.com` (2 dots) is first tried as `api.example.com.shop.svc.cluster.local` and so on, before the real name.

### Services as netfilter rules

```bash
sudo nft list ruleset | grep -m5 -i 'kube-svc\|dnat'      # kube-proxy in nftables mode
sudo iptables-save | grep -m5 KUBE-SVC                    # or iptables mode
sudo conntrack -L -d 172.30.45.12 2>/dev/null | head -3   # flows to a ClusterIP, translated to pod IPs
```

### Try it
1. Without a cluster: run `podman pod create --name p -p 8080:80` and add two containers. Show that they share a network namespace (topic 101), and generate Kubernetes YAML with `podman kube generate p`.
2. With a small cluster (kind, minikube, k3s or OpenShift Local), deploy a pod with `limits.memory: 64Mi` that allocates 200 MiB. Find `OOMKilled` in `kubectl describe pod`, then the `oom_kill` counter in the cgroup on the node.
3. Deploy a pod with `limits.cpu: 100m` running a busy loop; read `nr_throttled` on the node.
4. Find a Service's DNAT rules and its conntrack entries on a node.

## Where you'll use it

- **Every Kubernetes/OpenShift job:** node debugging, capacity planning (requests/limits), performance (throttling), networking (DNS, conntrack, MTU), and security reviews (securityContext, SCCs, privileged pods).
- **Interviews:** "explain a pod / OOMKilled / CPU throttling / how a Service works at the Linux level" are favourite SRE questions.

## When it breaks

| Mistake | Consequence | Better |
|---|---|---|
| Treating Kubernetes as a black box | Stuck at `kubectl describe` | Follow the pod to its node, PID, cgroup and namespaces |
| CPU limits set "just in case" on latency-sensitive services | Throttling, while the nodes idle | Set requests; use limits deliberately; watch `nr_throttled` |
| Memory limit = request with no headroom | Frequent OOMKilled | Size from the observed peak plus a margin |
| Ignoring `ndots:5` | Extra DNS load and latency | Trailing-dot FQDNs, `dnsConfig`, NodeLocal DNSCache |
| Running privileged pods "to make it work" | Host-level compromise risk | Add the one capability or SELinux option actually needed |

## Quick recap

- Container = namespaces + cgroup + overlayfs + reduced privileges. Pod = containers sharing a network namespace.
- requests.cpu → `cpu.weight`; limits.cpu → `cpu.max` (throttling); limits.memory → `memory.max` (OOMKilled, 137). QoS → `oom_score_adj`.
- Service = DNAT + conntrack; DNS = CoreDNS + search domains + `ndots:5`; volumes = bind mounts; termination = SIGTERM → grace → SIGKILL.
- Node toolkit: `systemctl`/`journalctl -u kubelet`, `crictl`, `/proc/PID/cgroup`, cgroup files, `nsenter -n`, `nft list ruleset`, `conntrack`.

**Interview questions**

1. *What is a pod at the Linux level?* One or more processes that share a network namespace (and usually IPC/UTS), each with its own mount and PID namespaces and a cgroup under the pod's cgroup.
2. *CPU request vs CPU limit?* A request becomes `cpu.weight` (a share under contention, never throttles) and is used for scheduling; a limit becomes a `cpu.max` quota that throttles the container once it's used up in each period.
3. *How does a ClusterIP Service work?* kube-proxy (or an eBPF CNI) installs DNAT rules that rewrite the virtual Service IP to one of the backend pod IPs; conntrack remembers the translation for the rest of the flow.
