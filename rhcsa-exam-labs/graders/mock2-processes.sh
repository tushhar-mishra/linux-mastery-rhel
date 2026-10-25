#!/usr/bin/env bash
# Grader for RHCSA mock exam 2, task A19 (run on server1 BEFORE rebooting). Read-only.
set -u
pass=0 fail=0
ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); }
check() { local desc=$1; shift; if "$@" >/dev/null 2>&1; then ok "$desc"; else bad "$desc"; fi; }

printf '\n== A19 processes\n'
check "cpuhog is still running (not restarted)"   pgrep -x cpuhog
check "cpuhog nice value is 15"                    bash -c "test \"\$(ps -o ni= -p \$(pgrep -o -x cpuhog) | tr -d ' ')\" = 15"
check "memhog has been terminated"                 bash -c "! pgrep -x memhog"

printf '\nScore: %d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
