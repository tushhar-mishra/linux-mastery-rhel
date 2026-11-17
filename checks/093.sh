TITLE="Memory management"
STEP_1="Page cache"
step_1() {
  quiz "After writing 1 GiB, which free -h column grew?" "buff|cache" "buff/cache grew; 'available' barely changed, because clean cache is reclaimable."
  check "/var/tmp/big was deleted" "rm /var/tmp/big" not test -e /var/tmp/big
}
STEP_2="A cgroup OOM kill"
step_2() {
  check "the kernel log has a memory-cgroup OOM from this boot" "sudo systemd-run --scope -p MemoryMax=64M python3 -c 'b=bytearray(200*1024*1024)'" bash -c 'journalctl -k -b --no-pager -q | grep -qi "memory cgroup out of memory"'
}
STEP_3="RSS vs PSS"
step_3() {
  quiz "Which total was larger: the httpd workers' summed RSS or summed PSS?" "rss" "RSS counts shared pages in every process; PSS splits them, so its sum is the honest total."
}
STEP_4="oom_score_adj"
step_4() {
  quiz "What was the oom_score of the sleep with oom_score_adj -1000?" "^\s*0\s*$" "-1000 makes it unkillable: its score is 0. The +1000 one scored highest (above 1000)."
}
