TITLE="Script input and arguments"
STEP_1="args.sh"
step_1() {
  local f; f=$(find "$LHOME" -maxdepth 2 -name args.sh -type f 2>/dev/null | head -1)
  check "args.sh exists" "Write it from the topic" test -n "$f"
  [ -n "$f" ] && check_match "it counts 'a \"b c\" d' as 3 arguments" "Use \"\$@\" and \$# (quoted)" "3" timeout 10 runuser -u "$LEARNER" -- bash "$f" a "b c" d
}
STEP_2="backup.sh validation"
step_2() {
  local f; f=$(find "$LHOME" -maxdepth 2 -name backup.sh -type f 2>/dev/null | head -1)
  check "backup.sh exists" "Write it from the topic" test -n "$f"
  [ -n "$f" ] || return 0
  check "with no arguments it exits non-zero" "Check \$# first and exit 1 or 2 with a usage message" not timeout 10 runuser -u "$LEARNER" -- bash "$f"
  check_match "with no arguments it prints a usage message" "echo \"Usage: …\" >&2" "[Uu]sage" timeout 10 runuser -u "$LEARNER" -- bash "$f"
  check "with a missing directory it exits non-zero" "Check [ -d \"\$2\" ] and exit 1" not timeout 10 runuser -u "$LEARNER" -- bash "$f" /etc/hosts /nope-dir
}
STEP_3="getopts"
step_3() {
  local f; f=$(find "$LHOME" -maxdepth 2 -name backup.sh -type f 2>/dev/null | head -1)
  check "backup.sh parses options with getopts" "while getopts ':nd:' opt; do case …" bash -c "grep -q getopts '$f'"
}
STEP_4="Argument or prompt"
step_4() { manual "Your script used \$1 when given and asked with 'read -rp' when not."; }
