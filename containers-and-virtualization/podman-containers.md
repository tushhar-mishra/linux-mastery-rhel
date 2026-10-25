# Podman Containers on RHEL 10

> **Sessions:** S82 · **[Advanced/Optional]** (containers were removed from the RHEL 10 objectives; still essential for RHEL admins)
> **Related:** [Virtualization vs containers](virtualization-vs-containers.md) · [SELinux file contexts (:Z)](../firewall-and-selinux/selinux-file-contexts.md) · [SELinux MCS](../firewall-and-selinux/selinux-mls-and-mcs.md) · [systemd services](../boot-systemd-and-kernel/systemd-targets-and-services.md) · [firewalld](../firewall-and-selinux/firewalld.md)

## 1. Overview

**Podman** is RHEL's daemonless, OCI-compliant container engine. RHEL 10 ships **Podman 5.x**. It's part of the container tools with **Buildah** (build images) and **Skopeo** (copy/inspect images).

| Layer | RHEL 10 component |
|---|---|
| CLI / API | `podman` (Docker-compatible CLI); optional REST API socket (`podman.socket`) |
| Engine | libpod: containers, pods, images, volumes, networks |
| OCI runtime | **crun** (default), runc available |
| Networking | **netavark** + aardvark-dns (CNI support removed in Podman 5); rootless uses **pasta** |
| Storage | containers/storage with overlay: root `/var/lib/containers/storage`, rootless `~/.local/share/containers/storage` |
| Security | SELinux (`container_t`, MCS categories), user namespaces, seccomp, capabilities |
| Boot integration | **Quadlet** (`.container` files → systemd units) |

**Rootful vs rootless:** Podman is rootless when a regular user runs it and rootful when root does. There's no global mode switch.

| | Rootful (root) | Rootless (user) |
|---|---|---|
| Container root | Real root (confined by SELinux) | Mapped to the user's UID via `/etc/subuid`, `/etc/subgid` |
| Ports < 1024 | Yes | No by default (`net.ipv4.ip_unprivileged_port_start`) |
| Storage | `/var/lib/containers` | `~/.local/share/containers` |
| Quadlet path | `/etc/containers/systemd/` | `~/.config/containers/systemd/` |

## 2. Install & Check

```bash
dnf install -y container-tools        # podman, buildah, skopeo … (or just: dnf install -y podman)
podman --version ; podman info | grep -E 'rootless|graphDriverName|networkBackend'
grep "^$USER:" /etc/subuid /etc/subgid   # rootless needs subordinate ID ranges (useradd creates them)
```

Rootless podman needs a **real login session** (SSH or console; or `machinectl shell user@`). After `su - user`, `XDG_RUNTIME_DIR` (`/run/user/<UID>`) may be missing or wrong. Don't `chown` that directory or hard-code the variable. If storage gets confused, `podman system migrate`.

## 3. Images

```bash
cat /etc/containers/registries.conf | grep -A3 unqualified   # search registries; short names are "enforcing"
podman search httpd
podman pull registry.access.redhat.com/ubi10/ubi             # fully qualified names avoid prompts
podman pull docker.io/library/httpd:latest
podman images ; podman inspect docker.io/library/httpd --format '{{.Config.Cmd}}'
podman tag docker.io/library/httpd:latest myhttpd:1.0
podman login docker.io ; podman push myhttpd:1.0 docker.io/USER/myhttpd:1.0
podman save -o httpd.tar docker.io/library/httpd ; podman load -i httpd.tar   # move images with metadata
podman rmi IMAGE ; podman image prune -a
skopeo inspect docker://registry.access.redhat.com/ubi10/ubi  # inspect without pulling
```

## 4. Containers

```bash
podman run --rm registry.access.redhat.com/ubi10/ubi cat /etc/os-release   # one-shot
podman run -it --name myubi registry.access.redhat.com/ubi10/ubi /bin/bash   # interactive (dnf/microdnf inside)
podman run -d --name myhttpd -p 8080:80 docker.io/library/httpd               # detached, host 8080 → container 80
curl http://localhost:8080

podman ps ; podman ps -a                 # running / all
podman logs -f myhttpd ; podman top myhttpd ; podman stats --no-stream ; podman port myhttpd
podman exec -it myhttpd /bin/bash        # shell in a running container
podman cp ./index.html myhttpd:/usr/local/apache2/htdocs/
podman stop myhttpd ; podman start myhttpd ; podman restart myhttpd
podman rm myhttpd ; podman rm -a ; podman rm -af     # remove (all stopped / force all)
podman inspect myhttpd --format '{{.NetworkSettings.IPAddress}}'
podman export -o c.tar myubi ; podman import c.tar localhost/myubi-flat   # flat filesystem snapshot (no CMD/ENV/layers)
podman unshare podman mount myubi        # rootless: mount a container's filesystem (root: podman mount)
```

## 5. Storage: Volumes & Bind Mounts

```bash
podman volume create webdata
podman run -d --name web -p 8080:80 -v webdata:/usr/local/apache2/htdocs docker.io/library/httpd
podman volume inspect webdata --format '{{.Mountpoint}}'

mkdir -p ~/html ; echo 'Hello' > ~/html/index.html
podman run -d --name web2 -p 8081:80 -v ~/html:/usr/local/apache2/htdocs:Z docker.io/library/httpd
```

> **SELinux:** host directories need **`:Z`** (private label for this container) or **`:z`** (shared between containers). Without it, access is denied under enforcing mode. Named volumes are labeled automatically. Avoid `--security-opt label=disable`.

## 6. Networks

```bash
podman network ls ; podman network inspect podman
podman network create appnet
podman run -d --name db  --network appnet -e MYSQL_ROOT_PASSWORD=Secr3t -v dbdata:/var/lib/mysql docker.io/library/mysql
podman run -d --name app --network appnet docker.io/library/httpd   # 'db' resolvable by name (aardvark-dns)
podman run -d --network appnet --ip 10.89.0.44 docker.io/library/httpd   # static IP: user-defined network
```

For access from other hosts, check the firewall for the published port, especially for rootless containers.

## 7. Pods

```bash
podman pod create --name webpod -p 8080:80          # ports are published on the POD
podman run -d --pod webpod --name web docker.io/library/httpd
podman run -d --pod new:test_server -p 8081:80 docker.io/library/nginx   # create pod + container in one step
podman pod ps ; podman pod inspect webpod
podman pod stop webpod ; podman pod rm webpod        # all pods: podman pod stop -a ; podman pod rm -a
podman kube generate webpod > webpod.yaml ; podman kube play webpod.yaml   # Kubernetes YAML
```

## 8. Building Images

**Containerfile:**

```dockerfile
FROM registry.access.redhat.com/ubi10/ubi
RUN dnf -y install httpd && dnf clean all
RUN echo 'Nehra Classes Are Awesome' > /var/www/html/index.html
EXPOSE 80
CMD ["/usr/sbin/httpd", "-DFOREGROUND"]
```

```bash
podman build -t myweb:1.0 .
podman run -d --name web -p 8080:80 localhost/myweb:1.0     # rootful: -p 80:80 also possible
```

**Buildah (scripted):**

```bash
ctr=$(buildah from registry.access.redhat.com/ubi10/ubi)
buildah run "$ctr" -- dnf -y install httpd
buildah copy "$ctr" index.html /var/www/html/index.html
buildah config --cmd '/usr/sbin/httpd -DFOREGROUND' --port 80 "$ctr"
buildah commit "$ctr" localhost/ubi-httpd
buildah build -t fedora-httpd .            # Containerfile build (was: buildah bud)
```

## 9. Start Containers at Boot: Quadlet

**Rootless example** (`~/.config/containers/systemd/myweb.container`):

```ini
[Unit]
Description=My web container

[Container]
Image=docker.io/library/httpd:latest
ContainerName=myweb
PublishPort=8080:80
Volume=%h/html:/usr/local/apache2/htdocs:Z

[Service]
Restart=always

[Install]
WantedBy=default.target
```

```bash
podman rm -f myweb 2>/dev/null                 # remove any manually created container with the same name
systemctl --user daemon-reload                 # Quadlet generates myweb.service
systemctl --user start myweb.service ; systemctl --user status myweb.service
sudo loginctl enable-linger "$USER"            # start user services at boot without a login
journalctl --user -u myweb.service             # as THIS user
/usr/libexec/podman/quadlet -user -dryrun      # debug generation
```

Rootful Quadlets go in `/etc/containers/systemd/` and use plain `systemctl daemon-reload` / `systemctl start`, with `WantedBy=multi-user.target`. Generated units can't be `enable`d; the `[Install]` section handles boot start. `podman generate systemd` still exists but is **deprecated**.

## 10. Production Practices **[Production Practice]**

- Prefer **rootless** containers and Red Hat **UBI** base images; use fully qualified image names and pin tags/digests.
- Persist data in volumes; never keep state only in the container layer.
- Run services through Quadlet (systemd: restarts, logs, dependencies); enable `AutoUpdate=registry` with `podman-auto-update.timer` where appropriate **[Advanced]**.
- Don't store secrets in images or command lines; use `podman secret create` / `Secret=` in Quadlet.
- Scan and update images regularly.

## 11. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `RunRoot … /run/user/1000 … not writable` / `cannot evaluate symlinks` | No proper login session (`su`) | Log in via SSH/console or `machinectl shell user@`; `podman system migrate` |
| `potentially insufficient UIDs or GIDs available` | Missing `/etc/subuid`/`subgid` entries | `usermod --add-subuids … --add-subgids … USER`; `podman system migrate` |
| Short-name prompt / "short-name resolution enforced" | Unqualified image name | Use `registry/namespace/image:tag` |
| `Permission denied` inside a bind mount | SELinux label | Add `:Z` / `:z` |
| `rootlessport cannot expose privileged port 80` | Rootless + port < 1024 | Use ≥ 1024 or adjust the sysctl |
| Service doesn't start at boot (rootless) | Linger off | `loginctl enable-linger USER` |
| Quadlet unit not found | Wrong path or no daemon-reload | Correct directory; `systemctl --user daemon-reload`; `quadlet -dryrun` |
| `Error: … name "myweb" is already in use` | Leftover manual container | `podman rm -f myweb` |

## 12. Interview Questions

| Question | Answer |
|---|---|
| Podman vs Docker? | Podman is daemonless, rootless-capable and integrates with systemd (Quadlet); CLI-compatible with Docker. |
| How does rootless isolation work? | User namespaces map container root to an unprivileged host UID range (`/etc/subuid`). |
| What do `:Z` and `:z` do? | Relabel a bind-mounted directory for one container (private) or several (shared). |
| `podman save` vs `podman export`? | save = image with layers and metadata; export = flattened container filesystem. |
| How do you run a container as a service on RHEL 10? | A Quadlet `.container` file + daemon-reload (+ linger for rootless). |
| What's a pod? | Containers sharing network (and other) namespaces, managed as one unit. |

## 13. Course Corrections

| Course | Correction |
|---|---|
| "Podman version 3+ / Podman2" | RHEL 10 ships Podman 5.x |
| CNI "still supported"; rootless via slirp4netns | Podman 5: netavark only; rootless default networking is pasta |
| "Rootless is the default mode on RHEL 10" | Depends on who runs podman |
| `/run/user/1000` fix by `chown` + exporting `XDG_RUNTIME_DIR` | Use a real login session |
| `yum module install container-tools` (RHEL 8 & 9) | No module on RHEL 9/10: `dnf install container-tools` |
| `subscription-manager attach --auto` | Not needed (Simple Content Access) |
| `-v /html/:/usr/local/apache2/htdocs/` | Add `:Z` |
| `podman stop -a` / `rm -a` "for pods" | `podman pod stop -a` / `podman pod rm -a` |
| `podman generate systemd … --new` while the container still exists | Deprecated; use Quadlet; remove the manual container first |
| `journalctl --user` run as root | Run as the user |
| `podman generate kube` | `podman kube generate` |
| `buildah bud`; `yum` inside images; UBI 8 images; short names | `buildah build`; `dnf`/`microdnf`; UBI 10; fully qualified names |
| Rootless "cannot mount container filesystems" | `podman unshare podman mount` |
| Third-party rsyslog images | Prefer trusted images (UBI, official) |

## 14. Quick Revision

```bash
podman pull|images|rmi|tag|push|save|load · podman run -d|-it|--rm --name N -p H:C -v vol:/p | -v /dir:/p:Z
podman ps -a|logs -f|exec -it|top|stats|port|inspect|stop|start|rm -f · podman volume|network create
podman pod create -p H:C · run --pod · pod stop|rm -a · kube generate|play
podman build -t img . · buildah from|run|copy|config|commit|build
Quadlet: ~/.config/containers/systemd/X.container → systemctl --user daemon-reload → start X ; loginctl enable-linger USER
