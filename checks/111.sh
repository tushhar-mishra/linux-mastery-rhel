TITLE="Linux foundations of Kubernetes"
STEP_1="A Podman pod"
step_1() {
  check "a pod named p exists" "podman pod create --name p -p 8080:80" bash -c "runuser -l '$LEARNER' -c 'podman pod exists p' 2>/dev/null || podman pod exists p 2>/dev/null"
  check "it has at least two containers besides the infra container" "podman run -d --pod p … (twice)" bash -c "n=\$(runuser -l '$LEARNER' -c 'podman pod inspect p --format \"{{.NumContainers}}\"' 2>/dev/null || podman pod inspect p --format '{{.NumContainers}}' 2>/dev/null); [ \"\${n:-0}\" -ge 3 ]"
  quiz "Which podman command turned the pod into Kubernetes YAML?" "kube generate" "podman kube generate p > p.yaml (podman kube play replays it)."
}
