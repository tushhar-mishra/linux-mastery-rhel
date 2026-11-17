# Helpers shared by every checks/NNN.sh file. Sourced by checks/check; not run directly.
# A topic file sets TITLE and defines functions step_1, step_2, ... (one per "Try it" step it can check).
# Inside a step, use:
#   check  "what is checked" "hint shown if it fails" command args...     → passes if the command succeeds
#   check_match "what" "hint" REGEX command args...                       → passes if the output matches REGEX (grep -E)
#   quiz   "question" REGEX "explanation"                                 → asks you; passes if your answer matches REGEX (case-insensitive)
#   manual "something only you can confirm"                               → printed as a reminder, not scored
#   note   "extra information"

PASS=0; FAIL=0; SKIP=0
if [ -t 1 ]; then G=$'\e[32m'; R=$'\e[31m'; Y=$'\e[33m'; B=$'\e[1m'; N=$'\e[0m'; else G=; R=; Y=; B=; N=; fi

# The person doing the lab (checks run under sudo, but files like ~/lab belong to you)
LEARNER=${SUDO_USER:-$(id -un)}
LHOME=$(getent passwd "$LEARNER" | cut -d: -f6)
as_learner() { runuser -u "$LEARNER" -- "$@"; }

# Distribution family: "rhel" (RHEL, AlmaLinux, Rocky, Fedora) or "debian" (Debian, Ubuntu)
. /etc/os-release
case " ${ID:-} ${ID_LIKE:-} " in
  *" rhel "*|*" fedora "*|*" centos "*) FAMILY=rhel ;;
  *" debian "*|*" ubuntu "*) FAMILY=debian ;;
  *) FAMILY=other ;;
esac
is_rhel()   { [ "$FAMILY" = rhel ]; }
is_debian() { [ "$FAMILY" = debian ]; }

_pass() { PASS=$((PASS+1)); printf '  %s✔%s %s\n' "$G" "$N" "$1"; }
_fail() { FAIL=$((FAIL+1)); printf '  %s✘%s %s\n' "$R" "$N" "$1"; [ -n "$2" ] && printf '      %shint:%s %s\n' "$Y" "$N" "$2"; return 0; }

check() {
  local what=$1 hint=$2; shift 2
  if "$@" </dev/null >/dev/null 2>&1; then _pass "$what"; else _fail "$what" "$hint"; fi
}

check_match() {
  local what=$1 hint=$2 re=$3 out; shift 3
  out=$("$@" </dev/null 2>&1)
  if printf '%s\n' "$out" | grep -Eq -- "$re"; then _pass "$what"; else _fail "$what" "$hint"; fi
}

quiz() {
  local q=$1 re=$2 why=$3 ans
  printf '  %s?%s %s\n    > ' "$B" "$N" "$q"
  if ! IFS= read -r ans; then ans=""; echo; fi
  [ -t 0 ] || echo "$ans"
  if [ -z "${ans//[[:space:]]/}" ]; then SKIP=$((SKIP+1)); printf '      (skipped)\n'; return 0; fi
  if printf '%s\n' "$ans" | grep -Eiq -- "$re"; then _pass "correct"; else _fail "not quite" ""; fi
  [ -n "$why" ] && printf '      %s\n' "$why"
}

manual() { printf '  %s☐%s %s\n' "$Y" "$N" "$1"; }
note()   { printf '    %s\n' "$1"; }

# Small reusable tests
user_exists()  { getent passwd "$1" >/dev/null; }
group_exists() { getent group "$1" >/dev/null; }
in_group()     { id -nG "$1" 2>/dev/null | tr ' ' '\n' | grep -qx "$2"; }
unit_active()  { systemctl is-active --quiet "$1"; }
unit_enabled() { systemctl is-enabled --quiet "$1"; }
fs_type()      { findmnt -no FSTYPE --mountpoint "$1" 2>/dev/null; }
is_mountpoint(){ findmnt -n --mountpoint "$1" >/dev/null 2>&1; }
fstab_has()    { grep -Ev '^\s*(#|$)' /etc/fstab | awk '{print $2}' | grep -qx "$1"; }
fstab_spec()   { grep -Ev '^\s*(#|$)' /etc/fstab | awk -v m="$1" '$2==m {print $1}'; }
file_mode()    { stat -c %a "$1" 2>/dev/null; }
port_listening(){ ss -Htln "sport = :$1" | grep -q .; }
fw_has()       { firewall-cmd "$@" >/dev/null 2>&1; }
not()          { ! "$@"; }

run_steps() {
  local want=$1 fn n found=0
  printf '%sTopic %s · %s%s\n' "$B" "$TOPIC" "$TITLE" "$N"
  for fn in $(declare -F | awk '{print $3}' | grep -E '^step_[0-9]+$' | sort -t_ -k2 -n); do
    n=${fn#step_}
    [ -n "$want" ] && [ "$want" != "$n" ] && continue
    found=1
    printf '\n%sStep %s%s %s\n' "$B" "$n" "$N" "$(eval "printf '%s' \"\${STEP_$n:-}\"")"
    "$fn"
  done
  if [ "$found" = 0 ]; then
    echo "No automatic check for step $want of this lab."; return 2
  fi
  printf '\n%sResult:%s %d passed, %d failed' "$B" "$N" "$PASS" "$FAIL"
  [ "$SKIP" -gt 0 ] && printf ', %d skipped' "$SKIP"
  printf '\n'
  [ "$FAIL" -eq 0 ]
}
