TITLE="Namespaces and cgroups"
STEP_1="unshare"
step_1() {
  quiz "Inside 'unshare --pid --fork --mount-proc', what PID did your shell have?" "^\s*1\s*$" "The first process in a new PID namespace is PID 1."
}
STEP_2="The red network namespace"
step_2() {
  check "the netns 'red' exists" "sudo ip netns add red (and the veth pair from the topic)" bash -c 'ip netns list | grep -qw red'
  check "red has an interface besides lo" "ip link add veth-host type veth peer name veth-red; ip link set veth-red netns red" bash -c 'ip -n red -br link | grep -v "^lo" | grep -q .'
  check "red can reach the internet (ping 8.8.8.8)" "Default route in red via veth-host, ip_forward=1, and masquerade on the host" ip netns exec red ping -c1 -W2 8.8.8.8
}
STEP_3="Limits in action"
step_3() {
  quiz "Which cpu.stat field counts the periods in which the group was throttled?" "nr_throttled" "nr_throttled (and throttled_usec for the total time)."
  quiz "Which memory.events counter rose when the process was killed?" "oom_kill" "oom_kill: the cgroup OOM killer ran (oom counts the events)."
}
STEP_4="A container's namespaces"
step_4() {
  quiz "Which /proc/PID/ns entry differed between the container and your shell? (name one)" "net|mnt|pid|uts|ipc|cgroup|user" "Compare the inode numbers in the ls -l /proc/PID/ns output: different number = different namespace."
}
