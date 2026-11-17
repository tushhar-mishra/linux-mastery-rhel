TITLE="Containers: Podman and Docker"
STEP_1="Rootless httpd with :Z"
step_1() {
  check "a rootless container of yours publishes port 8080" "podman run -d --name web -p 8080:80 -v ~/site:/usr/local/apache2/htdocs:Z docker.io/library/httpd" bash -c "runuser -l '$LEARNER' -c 'podman ps --format \"{{.Ports}}\"' 2>/dev/null | grep -q ':8080->'"
  check "it answers on http://localhost:8080" "podman logs web; check the :Z volume" curl -s --max-time 5 -o /dev/null http://localhost:8080/
}
STEP_2="Your own image"
step_2() {
  check "you have built an image (localhost/…)" "podman build -t myhttpd -f Containerfile ." bash -c "runuser -l '$LEARNER' -c 'podman images --format \"{{.Repository}}\"' 2>/dev/null | grep -q '^localhost/'"
}
STEP_3="A user network"
step_3() {
  check "you have a podman network besides the default" "podman network create appnet" bash -c "runuser -l '$LEARNER' -c 'podman network ls --format \"{{.Name}}\"' 2>/dev/null | grep -vxq podman"
}
STEP_4="Quadlet + linger"
step_4() {
  check "a Quadlet .container file exists in ~/.config/containers/systemd/" "Write ~/.config/containers/systemd/web.container (topic 101)" bash -c "ls '$LHOME'/.config/containers/systemd/*.container >/dev/null 2>&1"
  check "lingering is enabled for $LEARNER" "sudo loginctl enable-linger $LEARNER" bash -c "loginctl show-user '$LEARNER' -p Linger 2>/dev/null | grep -q yes"
}
STEP_5="Host PID and namespaces"
step_5() {
  quiz "Which podman inspect format prints a container's host PID?" "\.State\.Pid" "podman inspect -f '{{.State.Pid}}' NAME"
}
