# 101 · Containers with Podman (and Docker)

> **You need first:** [100 · KVM virtualization](100-kvm-virtualization.md) (and topics 097 namespaces/cgroups, 098 unit files, 073/076 SELinux)
> **Next:** [102 · A troubleshooting method](102-troubleshooting-method.md)

---

## What it is

**Podman** is RHEL's container engine. It's **daemonless** (no always-running background service), **rootless-capable**, uses **OCI** images (topic 099), and has a CLI that matches Docker's command for command. It comes with **Buildah** (build images) and **Skopeo** (copy and inspect images in registries).

| Layer | RHEL 10 component |
|---|---|
| CLI / API | `podman` (optional Docker-compatible REST socket: `podman.socket`) |
| Engine | libpod: containers, pods, images, volumes, networks |
| OCI runtime | **crun** (default); runc also available |
| Networking | **netavark** + **aardvark-dns** (name resolution between containers); rootless uses **pasta** |
| Storage | overlay: rootful `/var/lib/containers/storage`, rootless `~/.local/share/containers/storage` |
| Security | SELinux (`container_t` + MCS), user namespaces, seccomp, capabilities (topic 097) |
| Boot integration | **Quadlet**: `.container` files become systemd units |

Words:
- **Image**: a read-only template (layers + config).
- **Container**: a running (or stopped) instance of an image.
- **Registry**: a server that stores images (quay.io, registry.redhat.io, docker.io).
- **Tag**: an image version label (`:1.0`, `:latest`).
- **Digest**: an immutable `sha256:` ID for an exact image.
- **Volume**: persistent storage managed by the engine.
- **Bind mount**: a host directory mapped into the container.
- **Pod**: containers sharing a network namespace, like a Kubernetes pod.
- **Containerfile** (= Dockerfile): the build recipe.

**Rootful vs rootless:** Podman is rootless when a normal user runs it and rootful when root does.

| | Rootful (root) | Rootless (user) |
|---|---|---|
| Container root | Real root (confined by SELinux) | Mapped to the user's UID via `/etc/subuid`, `/etc/subgid` |
| Ports < 1024 | Yes | No by default |
| Storage | `/var/lib/containers` | `~/.local/share/containers` |
| Quadlet path | `/etc/containers/systemd/` | `~/.config/containers/systemd/` |

**Docker** differs mainly in architecture: a central root daemon (`dockerd`) does all the work, and the CLI talks to it over `/var/run/docker.sock`. Membership in the `docker` group = **root-equivalent** access to the host. Ubuntu/Debian typically use Docker (`apt install docker.io`, or Docker CE from Docker's repository). Commands are nearly identical (`alias docker=podman` works for most uses).

## Why it exists

Containers package an application with exactly the libraries it needs, so it runs the same on a laptop, in CI and in production, starting in milliseconds (topic 099). Podman brings that to RHEL **without** a root daemon (a smaller attack surface; a daemon crash doesn't take every container down), and with first-class **systemd** integration for running containers as services.

## Analogy

An **image** is a **frozen ready-meal** (recipe and ingredients sealed in layers); a **container** is that meal **heated up and served**: you can serve many from the same packet. The **registry** is the supermarket freezer. A **volume** is your own **lunchbox** that survives after the plate is thrown away. Docker is a **restaurant with one head chef** (the daemon) who cooks everything; Podman is a **kitchen where each cook works independently**, so no single chef can bring the whole kitchen down.

## How it works inside

`podman run -d -p 8080:80 IMAGE` does roughly this:
1. **Resolve and pull the image.** Short names are checked against `/etc/containers/registries.conf`; use fully qualified names (`registry/namespace/image:tag`) to avoid prompts and spoofing.
2. **Prepare storage:** stack the image's layers with overlayfs and add a writable upper layer (topic 097).
3. **Create namespaces and a cgroup**; with rootless Podman, a **user namespace** maps container UID 0 to your UID, and other UIDs to your `/etc/subuid` range.
4. **Networking:**
   - **Rootful:** a veth pair to the `podman0` bridge; netavark adds the NAT and port-forward (DNAT) rules (topics 095, 097).
   - **Rootless:** **pasta** forwards traffic in user space instead, so no root is needed.
5. **Security:** SELinux label `container_t:s0:cX,cY`, a seccomp filter, and a reduced capability set.
6. **crun** (the OCI runtime) does the final `clone`/`pivot_root`/`exec` of the image's command. **conmon** (a tiny monitor process) stays behind to hold logs and the exit code. There's no daemon.

**Bind mounts and SELinux:** a host directory has a host label (for example `user_home_t`) that `container_t` can't read. `:Z` relabels it privately for **this** container's categories; `:z` relabels it as shared between containers. Named volumes are labelled automatically.

## Commands

### Install and check

```bash
sudo dnf install -y container-tools          # podman, buildah, skopeo…
podman info --format '{{.Host.Security.Rootless}} {{.Store.GraphDriverName}} {{.Host.NetworkBackend}}'
grep "^$USER:" /etc/subuid /etc/subgid
```
```
true overlay netavark
/etc/subuid:alice:524288:65536
/etc/subgid:alice:524288:65536
```
- Rootless, overlay storage, netavark networking. alice owns 65,536 subordinate UIDs starting at 524288 for container users.

Rootless Podman needs a **real login session** (SSH or console). After `su - user`, `XDG_RUNTIME_DIR` may be wrong. Log in properly, or use `machinectl shell user@`.

### Images

```bash
podman pull registry.access.redhat.com/ubi10/ubi
podman images
skopeo inspect docker://registry.access.redhat.com/ubi10/ubi | head    # inspect without pulling
podman tag localhost/myweb:1.0 quay.io/USER/myweb:1.0
podman login quay.io ; podman push quay.io/USER/myweb:1.0
podman save -o myweb.tar localhost/myweb:1.0 ; podman load -i myweb.tar   # move images with layers + metadata
podman image prune -a
```
```
REPOSITORY                            TAG         IMAGE ID      CREATED      SIZE
registry.access.redhat.com/ubi10/ubi  latest      747428888698  4 days ago  220 MB
```

### Run and manage containers

```bash
podman run --rm registry.access.redhat.com/ubi10/ubi cat /etc/redhat-release     # one-shot
podman run -it --name myubi registry.access.redhat.com/ubi10/ubi /bin/bash      # interactive
podman run -d --name web -p 8080:80 docker.io/library/httpd                     # detached; host 8080 → container 80
curl -s http://localhost:8080 | head -1
podman ps
```
```
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
CONTAINER ID  IMAGE                           COMMAND           CREATED        STATUS        PORTS                 NAMES
3f2a9c1b7e44  docker.io/library/httpd:latest  httpd-foreground  5 seconds ago  Up 5 seconds  0.0.0.0:8080->80/tcp  web
```

| Task | Command |
|---|---|
| All containers (incl. stopped) | `podman ps -a` |
| Logs | `podman logs -f web` |
| Processes / resources | `podman top web` · `podman stats --no-stream` |
| A shell inside | `podman exec -it web /bin/bash` |
| Copy files | `podman cp ./index.html web:/usr/local/apache2/htdocs/` |
| Stop / start / remove | `podman stop web` · `start` · `rm web` · `rm -af` |
| Details | `podman inspect web` (`--format '{{.State.Pid}}'` for the host PID) |
| Exit code | `podman inspect web --format '{{.State.ExitCode}} {{.State.OOMKilled}}'` |

### Volumes and bind mounts

```bash
podman volume create webdata
podman run -d --name web1 -p 8081:80 -v webdata:/usr/local/apache2/htdocs docker.io/library/httpd

mkdir -p ~/html ; echo 'Hello from the host' > ~/html/index.html
podman run -d --name web2 -p 8082:80 -v ~/html:/usr/local/apache2/htdocs:Z docker.io/library/httpd
ls -dZ ~/html
```
```
system_u:object_r:container_file_t:s0:c418,c907 /home/alice/html
```
- `:Z` relabelled the directory to `container_file_t` with this container's private category pair. **Without `:Z`, you get `Permission denied` inside the container.** Avoid `--security-opt label=disable`.

### Networks and pods

```bash
podman network create appnet
podman run -d --name db  --network appnet -e MARIADB_ROOT_PASSWORD=Secr3t -v dbdata:/var/lib/mysql docker.io/library/mariadb
podman run -d --name app --network appnet docker.io/library/httpd
podman exec app getent hosts db                     # names resolve via aardvark-dns on user networks
```
```
10.89.0.3       db.dns.podman
```
- The name resolves to the container's address on `appnet`; aardvark-dns adds the `dns.podman` search domain.
```bash
podman pod create --name webpod -p 8090:80          # ports are published on the POD
podman run -d --pod webpod --name web3 docker.io/library/httpd
podman kube generate webpod > webpod.yaml           # Kubernetes YAML from a pod
podman kube play webpod.yaml                        # and back again
```

### Build images

```dockerfile
# Containerfile
FROM registry.access.redhat.com/ubi10/ubi
RUN dnf -y install httpd && dnf clean all
RUN echo 'Hello from RHEL' > /var/www/html/index.html
EXPOSE 80
CMD ["/usr/sbin/httpd", "-DFOREGROUND"]
```
```bash
podman build -t myweb:1.0 .
podman run -d --name myweb -p 8080:80 localhost/myweb:1.0
```
- Use the **exec form** `CMD ["…"]` so your program is PID 1 and receives SIGTERM directly (topic 092). Combine `RUN` steps and clean caches to keep layers small. Run as a non-root `USER` where possible.

### Run a container as a service: Quadlet

`~/.config/containers/systemd/myweb.container` (rootless):
```ini
[Unit]
Description=My web container

[Container]
Image=localhost/myweb:1.0
ContainerName=myweb
PublishPort=8080:80
Volume=%h/html:/var/www/html:Z

[Service]
Restart=always

[Install]
WantedBy=default.target
```
```bash
podman rm -f myweb 2>/dev/null
systemctl --user daemon-reload                      # Quadlet's generator creates myweb.service
systemctl --user start myweb.service
systemctl --user status myweb.service --no-pager | head -5
sudo loginctl enable-linger "$USER"                 # start user services at boot without a login
/usr/libexec/podman/quadlet -user -dryrun           # debug the generated unit
```
- Rootful Quadlets go in `/etc/containers/systemd/` with `WantedBy=multi-user.target`.
- Generated units can't be `enable`d; the `[Install]` section handles boot start.
- `podman generate systemd` is deprecated.

### Docker equivalents (Ubuntu and many CI systems)

```bash
sudo apt install docker.io                # or Docker CE; sudo systemctl enable --now docker
sudo usermod -aG docker alice             # ⚠️ docker group = root on the host
docker run -d --name web -p 8080:80 httpd
docker compose up -d                      # multi-container apps from compose.yaml (Podman: podman compose)
```

### Try it
1. Run httpd rootless on port 8080 with a `:Z` bind mount, then remove `:Z` and see the SELinux denial (`ausearch -m avc -ts recent`).
2. Build the UBI httpd image from a Containerfile and run it.
3. Create a user network with a DB and an app container and resolve `db` by name.
4. Turn your container into a Quadlet service, enable linger, reboot, and confirm it's running.
5. Find the container's host PID and compare its namespaces and capabilities with your shell (topic 097).

**Check your work:** on your lab VM, from the notes folder, run `sudo ./checks/check 101` for every step, or `sudo ./checks/check 101 STEP` for one (topic 002 shows how to get the notes there).

## Where you'll use it

- **Kubernetes:** pods, images, registries, volumes and probes are the same concepts. CRI-O (used by OpenShift) shares Podman's libraries, so `crictl` on a node feels similar. `podman kube play` lets you test Kubernetes YAML locally.
- **CI/CD:** building and pushing images (`podman build`/`buildah`, `skopeo copy` between registries).
- **Single-host services:** Quadlet gives you restart, logging and boot ordering via systemd.
- **Security:** rootless containers, UBI base images, pinned digests, image scanning, secrets via `podman secret` (never in images or environment lists in Git).

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `RunRoot … /run/user/1000 … not writable` | Not a real login session (`su`) | Log in via SSH/console, or `machinectl shell user@`; `podman system migrate` |
| `potentially insufficient UIDs or GIDs available` | Missing `/etc/subuid`/`subgid` entries | `usermod --add-subuids 524288-589823 --add-subgids 524288-589823 USER`; `podman system migrate` |
| A short-name prompt or "short-name resolution enforced" | An unqualified image name | Use `registry/namespace/image:tag` |
| `Permission denied` inside a bind mount | The SELinux label | Add `:Z` / `:z` |
| `rootlessport cannot expose privileged port 80` | Rootless + port < 1024 | Use a port ≥ 1024, or adjust `net.ipv4.ip_unprivileged_port_start` |
| Works locally, unreachable from other hosts | The firewall | `firewall-cmd --add-port=8080/tcp` (topic 071) |
| Exits immediately | The command finished, or the app crashed | `podman logs NAME`; `podman inspect` ExitCode |
| Exit 137 / `OOMKilled: true` | Memory limit | Raise `--memory`, or fix the app (topic 093) |
| A rootless service doesn't start at boot | Linger is off | `loginctl enable-linger USER` |
| `name "myweb" is already in use` | A leftover container | `podman rm -f myweb` |

## Quick recap

- Podman = daemonless, rootless-capable, Docker-compatible; crun runtime, netavark/pasta networking, overlay storage, SELinux + user namespaces.
- `podman pull | images | run -d -p H:C -v vol:/p | -v /dir:/p:Z | ps -a | logs -f | exec -it | inspect | rm -f`.
- Volumes for data; `:Z`/`:z` for bind mounts; user networks give name resolution; pods ≈ Kubernetes pods (`kube generate/play`).
- Build with a Containerfile (`podman build`); run as a service with **Quadlet** (+ linger for rootless).
- Docker = the same commands with a root daemon; the `docker` group is root-equivalent.

**Interview questions**

1. *Podman vs Docker?* Podman has no central daemon, runs rootless by default for normal users, and integrates with systemd (Quadlet). Docker uses a root daemon that all clients talk to. Their CLIs and images are compatible.
2. *How does rootless Podman isolate containers without root?* A user namespace maps the container's root to the user's own UID, and other container UIDs to the subordinate range in `/etc/subuid`, so "root" inside has no real privilege outside.
3. *What do `:Z` and `:z` do on a bind mount?* They relabel the host directory for SELinux: `:Z` privately for this container (its MCS categories), `:z` shared among containers. Without one, `container_t` is denied access.

**Scenario question** (answer out loud first, then compare)

> *"A rootless Podman container with a bind mount runs fine on your laptop but fails on a RHEL server with 'Permission denied' when it reads its data directory. Why?"*

**Model answer:**
1. Most likely **SELinux**: the host directory has a label like `user_home_t` or `var_t`, and `container_t` may not read it.
   - Check with `ls -Zd /data`;
   - and `ausearch -m avc -ts recent` (or `journalctl -t setroubleshoot`).
2. Fix by adding `:Z` (private) or `:z` (shared) to the volume: `-v /data:/data:Z`. Podman relabels the directory with the container's categories.
3. If SELinux is fine, it's the **user namespace**: inside, the app runs as, say, UID 1000. Outside that maps to a subordinate UID (from `/etc/subuid`), which doesn't own the files.
   - Fix ownership with `podman unshare chown 1000:1000 /data`;
   - or use `--userns=keep-id`.
4. Your laptop probably has SELinux off or permissive, or runs Docker as root, which hides both issues.

**Likely follow-ups:**
- *How do you make a container start at boot?* A Quadlet `.container` file; for rootless, also `loginctl enable-linger user`.
- *Why is the `docker` group dangerous?* Its members can start privileged containers that mount the host's `/`: that's root.
