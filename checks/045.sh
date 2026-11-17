TITLE="Robust scripts"
STEP_1="Keeping 2 archives"
step_1() {
  local d; d=$(find /tmp "$LHOME" -maxdepth 3 -name '*-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9].tar.gz' -printf '%T@ %h\n' 2>/dev/null | sort -n | awk 'END{print $2}')
  check "found the template's archives" "Run ./backup-dir.sh -v -n 2 ~/lab /tmp/bk three times (a source directory you can read)" test -n "$d"
  [ -n "$d" ] && check "exactly 2 archives remain in $d" "-n 2 keeps the newest two" test "$(find "$d" -maxdepth 1 -name '*.tar.gz' | wc -l)" -eq 2
}
STEP_2="The lock and the trap"
step_2() {
  quiz "What did the second run say while the first was still running?" "another instance|already running|lock" "flock -n refused because the first run held the lock on fd 9."
  check "no leftover mktemp directories from the script remain in /tmp" "The EXIT trap should delete \$tmp; check your trap line" bash -c '[ -z "$(find /tmp -maxdepth 1 -name "tmp.*" -type d -mmin +1 -newer /proc/1 2>/dev/null | head -1)" ]'
}
STEP_3="ShellCheck"
step_3() {
  check "shellcheck is installed" "RHEL: sudo dnf install -y epel-release && sudo dnf install -y ShellCheck   Ubuntu: sudo apt install shellcheck" command -v shellcheck
  local f; f=$(find "$LHOME" -maxdepth 2 -name backup-dir.sh -type f 2>/dev/null | head -1)
  [ -n "$f" ] && check "backup-dir.sh is ShellCheck-clean" "shellcheck $f" shellcheck "$f"
}
STEP_4="A service + timer"
step_4() {
  local s; s=$(grep -ls 'backup-dir' /etc/systemd/system/*.service 2>/dev/null | head -1)
  check "a service in /etc/systemd/system runs backup-dir.sh" "Create backup-dir.service with ExecStart=/usr/local/bin/backup-dir.sh …" test -n "$s"
  [ -n "$s" ] || return 0
  local t=${s%.service}.timer
  check "$(basename "$t") exists with Persistent=true" "[Timer] OnCalendar=daily + Persistent=true" grep -qE '^\s*Persistent\s*=\s*(true|yes)' "$t"
  check "$(basename "$t") is enabled and active" "sudo systemctl enable --now $(basename "$t")" bash -c "systemctl is-enabled --quiet $(basename "$t") && systemctl is-active --quiet $(basename "$t")"
}
