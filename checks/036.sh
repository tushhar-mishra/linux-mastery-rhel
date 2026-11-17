TITLE="Resource monitoring"
STEP_1="Reading the load generator"
step_1() {
  if is_rhel; then check "stress-ng is installed" "sudo dnf install -y stress-ng" rpm -q stress-ng
  else check "stress-ng is installed" "sudo apt install -y stress-ng" dpkg -s stress-ng; fi
  quiz "Which vmstat column rose most with 'stress-ng --cpu'?" "^\s*(r|us)\b" "r (runnable tasks) and us (user CPU)."
  quiz "Which columns appeared with '--vm --vm-bytes 75%'?" "si|so|free|cache|avail" "free/available dropped; with too little RAM, si/so (swap in/out) appear."
  quiz "Which column rose with '--hdd'?" "^\s*(wa|b|bi|bo)\b" "wa (I/O wait), b (blocked tasks), and bo (blocks written out)."
}
