# Writing Robust, Production-Safe Bash Scripts

> **Track:** **[Production Practice]** · builds on the RHCSA scripting objectives · **Verified:** template and pitfalls run with bash 5.2 on RHEL 10.2 (Oct 2026)
> **Prerequisites:** [Script basics](script-basics-and-variables.md) · [Script input](script-input-and-arguments.md) · [Conditionals](conditionals-and-tests.md) · [Loops](loops.md) · [Command substitution & `set` options](../shell-and-command-line/command-substitution-and-shell-options.md) · [Processes & signals](../processes-and-resource-management/processes-and-system-calls.md#7-signals-in-depth)
> **Next:** [Ansible starter](ansible-starter.md) · [systemd unit files (running scripts as services/timers)](../boot-systemd-and-kernel/systemd-unit-files.md)

## 1. What "Robust" Means

An RHCSA script has to work once, on the exam's input. A production script runs unattended, at 3 a.m., on hosts you haven't seen, with inputs nobody anticipated. It must:

1. **Fail loudly and early**: a non-zero exit code and a clear message on stderr.
2. **Be safe on bad input**: validate arguments; never `rm -rf "$empty_var"/`.
3. **Clean up** temporary files, locks and partial output, even when interrupted.
4. **Be idempotent**: running it twice leaves the same end state.
5. **Not overlap** with itself (cron/timer runs that take longer than the interval).
6. **Leave evidence**: logs with timestamps; exit codes the scheduler can alert on.

## 2. A Template You Can Reuse

Verified on RHEL 10.2: usage errors exit 2, validation errors exit 1, a second concurrent instance is refused, and only the newest `KEEP` archives remain.

```bash
#!/usr/bin/env bash
# backup-etc.sh: archive a directory to a destination, keep N copies.
# Usage: backup-etc.sh [-n KEEP] [-v] SOURCE_DIR DEST_DIR
set -Eeuo pipefail                       # see §3 for exactly what this does and doesn't catch
readonly PROG=${0##*/}
KEEP=7 VERBOSE=0

log()  { printf '%s %s: %s\n' "$(date +%FT%T)" "$PROG" "$*" >&2; }
die()  { log "ERROR: $*"; exit 1; }
usage(){ echo "Usage: $PROG [-n KEEP] [-v] SOURCE_DIR DEST_DIR" >&2; exit 2; }

while getopts ':n:vh' opt; do
  case $opt in
    n) [[ $OPTARG =~ ^[0-9]+$ ]] || die "-n needs a number"; KEEP=$OPTARG ;;
    v) VERBOSE=1 ;;
    h) usage ;;
    :) die "option -$OPTARG needs an argument" ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))
(( $# == 2 )) || usage
src=$1 dest=$2
[[ -d $src ]] || die "source not a directory: $src"
mkdir -p -- "$dest"

exec 9>"/tmp/$PROG.lock"                 # (production: /run/lock/ or a RuntimeDirectory=)
flock -n 9 || die "another instance is running"

tmp=$(mktemp -d)                          # private temp dir (mode 0700)
trap 'rc=$?; rm -rf -- "$tmp"; (( rc == 0 )) || log "failed (rc=$rc)"' EXIT
trap 'log "interrupted"; exit 130' INT TERM

name="$(basename -- "$src")-$(date +%Y%m%d-%H%M%S).tar.gz"
tar -czf "$tmp/$name" -C "$(dirname -- "$src")" "$(basename -- "$src")"
mv -- "$tmp/$name" "$dest/$name"          # appears atomically only when complete (same filesystem: rename)
(( VERBOSE )) && log "wrote $dest/$name"

mapfile -t old < <(ls -1t -- "$dest"/*.tar.gz | tail -n +$((KEEP + 1)))
for f in "${old[@]}"; do rm -f -- "$f"; (( VERBOSE )) && log "pruned $f"; done
exit 0
```

Verified runs:

```
$ ./backup-etc.sh                         → Usage: …            rc=2
$ ./backup-etc.sh -n x /etc /tmp/bk       → ERROR: -n needs a number   rc=1
$ ./backup-etc.sh /nope /tmp/bk           → ERROR: source not a directory: /nope   rc=1
$ (3 runs with -v -n 2)                   → wrote … ×3, pruned the oldest; 2 archives remain
$ (while another instance holds the lock) → ERROR: another instance is running   rc=1
```

## 3. `set -Eeuo pipefail`: Know the Limits

| Option | Effect |
|---|---|
| `-e` (errexit) | Exit when a command fails… with many exceptions (below) |
| `-u` (nounset) | Referencing an unset variable is an error; use `${var:-}` for optional ones |
| `-o pipefail` | A pipeline fails if **any** stage fails (otherwise only the last stage counts) |
| `-E` (errtrace) | `ERR` traps also fire inside functions and subshells |

**Pitfalls (each verified):**

```bash
# 1. errexit is OFF inside anything used as a condition, including whole functions
set -e; f(){ false; echo after-false-in-f; }; if f; then echo ok; fi
#   after-false-in-f      ← the failure inside f was ignored
#   ok

# 2. Command substitution in a plain assignment DOES propagate the failure…
set -e; x=$(false); echo "not reached"        # exits with 1

# 3. …but "local" (and "export", "declare", "readonly") masks it: their own exit status is 0
set -e; g(){ local v=$(false); echo local-masks-error; }; g
#   local-masks-error     → write:  local v; v=$(false)

# 4. Without pipefail, only the last stage of a pipeline counts
set -euo pipefail; false | true; echo "not reached"   # exits with 1 thanks to pipefail
```

Treat `set -e` as a safety net, not error handling: check critical commands explicitly (`cmd || die "cmd failed"`).

## 4. Quoting, Arrays & Safe Paths

```bash
arr=("a b" c)
for x in ${arr[@]};   do echo "[$x]"; done     # [a] [b] [c]   ← unquoted: word splitting broke "a b"
for x in "${arr[@]}"; do echo "{$x}"; done     # {a b} {c}     ← always quote array expansions
```

| Rule | Why |
|---|---|
| Quote every expansion: `"$var"`, `"$(cmd)"`, `"${arr[@]}"` | Prevent word splitting and globbing |
| Use `--` before path arguments: `rm -f -- "$f"` | Filenames starting with `-` aren't parsed as options |
| `"${dir:?}"/*` instead of `"$dir"/*` in destructive commands | Abort if `dir` is empty (would become `/*`) |
| Use arrays for argument lists: `opts=(-a --delete); rsync "${opts[@]}" …` | No quoting hacks with strings |
| Iterate files with globs or `find -print0 \| while IFS= read -r -d '' f` | Never parse `ls` (names with spaces/newlines) |
| `printf '%s\n' "$x"` instead of `echo "$x"` | `echo` mangles strings like `-n` or `-e` |

## 5. Cleanup, Signals & Temporary Files

- `mktemp` / `mktemp -d` create unique files/directories (mode 0600/0700). Never use predictable names like `/tmp/myscript.tmp`: another user can pre-create or symlink them.
- `trap '…' EXIT` runs on **any** exit (normal, `exit N`, errexit). Add `INT TERM` traps that `exit` with `128+N` so EXIT cleanup still runs.
- Write output to a temp file in the **same directory/filesystem** as the target, then `mv` it into place. Readers never see a half-written file, because rename is atomic ([storage I/O path](../storage-and-filesystems/storage-io-path.md#52-making-data-durable)).

## 6. Locking & Idempotency

```bash
exec 9>/run/lock/myjob.lock ; flock -n 9 || exit 0     # skip if already running (cron/timers)
flock -w 30 /run/lock/myjob.lock -c 'critical section'  # wait up to 30 s
```

Idempotent patterns:

| Instead of | Write |
|---|---|
| `useradd bob` | `id bob &>/dev/null \|\| useradd bob` |
| `echo 'line' >> /etc/file` | `grep -qxF 'line' /etc/file \|\| echo 'line' >> /etc/file` |
| `mkdir /data` | `mkdir -p /data` |
| `firewall-cmd --add-service=http` | It's already idempotent; check `--query-service` if you need the result |

When a script grows many such checks, it's a sign the task belongs in configuration management ([Ansible starter](ansible-starter.md)).

## 7. Timeouts, Retries & External Commands

```bash
timeout 10 curl -fsS https://api.example.com/health || die "health check failed"   # never hang forever
retry() {                         # retry N times with exponential backoff
  local n=$1; shift; local i delay=1
  for ((i=1; i<=n; i++)); do
    "$@" && return 0
    log "attempt $i/$n failed: $*"; sleep "$delay"; delay=$((delay * 2))
  done
  return 1
}
retry 5 curl -fsS -o /tmp/file https://repo.example.com/file
```

`curl -f` makes HTTP errors (4xx/5xx) return non-zero; without it, `curl` succeeds on a 500 page.

## 8. Logging & Exit Codes

- Log to **stderr** (`>&2`); keep stdout for real output that other tools may consume.
- Under systemd, stdout/stderr go to the journal automatically; `logger -t myjob "message"` writes to the journal from anywhere.
- Exit codes: `0` success, `1` general failure, `2` usage error; keep `126`/`127`/`128+N` for their standard meanings ([exit statuses](../shell-and-command-line/quoting-and-control-operators.md#41-exit-status-)).
- Run scheduled scripts as systemd services/timers to get logging, `OnFailure=` alerts and resource limits for free.

## 9. Static Analysis & Testing

- **ShellCheck** (`shellcheck script.sh`; EPEL, or the container image) catches unquoted variables, `local` masking, useless `cat`, and dozens of portability bugs. Treat its warnings as defects.
- `bash -n script.sh` for syntax; `bash -x` / `PS4='+ ${BASH_SOURCE}:${LINENO}: '` for tracing.
- Test unhappy paths deliberately: no arguments, bad arguments, missing directories, full disk (`/dev/full`), Ctrl+C in the middle, two concurrent runs.

## 10. When to Stop Using Bash

Move to Python (or another language) or Ansible when you need data structures beyond flat arrays, JSON/YAML parsing (beyond `jq`), complex error handling, unit tests, or more than a few hundred lines. Bash is excellent glue, not an application platform.

## 11. Exercises

1. Run the template with `/dev/full` as the destination file system. Which line fails, and does the EXIT trap clean up?
2. Add a `--dry-run` (`-n` is taken; use `-d`) mode that prints actions without executing them.
3. Convert the script into a systemd service + timer that runs nightly with `Persistent=true`, and alert with `OnFailure=` to a unit that logs `logger -p user.err`.
4. Run ShellCheck on three of your RHCSA practice scripts and fix every finding.

## 12. Quick Revision

```
set -Eeuo pipefail (safety net; off in conditions; local masks $(…) errors) · ${var:-} · ${dir:?}
quote "$x" "${arr[@]}" · -- before paths · printf over echo · find -print0 | while IFS= read -r -d ''
mktemp -d + trap 'cleanup' EXIT + trap 'exit 130' INT TERM · temp file + mv (atomic)
flock -n 9 · idempotent checks (id || useradd, grep -qxF || echo >>) · timeout · retry with backoff · curl -f
log to stderr / logger / journal · exit 0/1/2 · shellcheck · bash -n · systemd timers for scheduling
```

## 13. Cross-References

- [Script basics](script-basics-and-variables.md) · [Script input & getopts](script-input-and-arguments.md) · [Conditionals](conditionals-and-tests.md) · [Loops](loops.md) · [Arithmetic](arithmetic.md)
- [Shell options (`set -e` caveats)](../shell-and-command-line/command-substitution-and-shell-options.md#41-set--e-caveats-production-practice) · [I/O redirection](../files-and-text-processing/io-redirection-and-pipes.md)
- [Job scheduling (timers)](../logs-scheduling-and-packages/job-scheduling.md) · [systemd unit files](../boot-systemd-and-kernel/systemd-unit-files.md) · [Ansible starter](ansible-starter.md)
