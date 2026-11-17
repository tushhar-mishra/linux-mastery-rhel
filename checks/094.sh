TITLE="The storage I/O path"
STEP_1="Dirty pages"
step_1() {
  quiz "What happened to Dirty in /proc/meminfo when you ran sync?" "drop|fell|zero|0|decreas|went down" "sync forced writeback, so the dirty pages were written and became clean."
}
STEP_2="The device-mapper stack"
step_2() {
  quiz "Which dm target does a plain linear LV use in 'dmsetup table'?" "^\s*linear\s*$" "linear: one or more ranges of a PV mapped end to end."
}
STEP_3="Cold vs warm cache"
step_3() {
  quiz "Why was the second 'cat bigfile' faster?" "cache|ram|memory" "The first read filled the page cache; the second was served from RAM."
}
STEP_4="fio and iostat"
step_4() {
  quiz "Which iostat column shows the average time per request (ms)?" "await|r_await|w_await" "r_await / w_await: queue + service time. On SSDs and NVMe, latency matters more than %util."
}
