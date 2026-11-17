# 045 · Writing Robust, Production-Safe Bash Scripts

> **You need first:** [044 · Arithmetic](044-arithmetic.md)
> **Next:** [046 · Disks and partitions](046-disks-and-partitions.md)

---

## What it is

A **robust** script is one you can trust to run **unattended**, at 3 AM, on servers you've never seen, with input nobody expected. It must:

1. **Fail loudly and early**: a non-zero exit code and a clear message on stderr.
2. **Be safe with bad input**: validate everything; never `rm -rf "$empty"/`.
3. **Clean up** temporary files and locks, even if interrupted (Ctrl+C, `kill`).
4. **Be idempotent**: running it twice leaves the same end result as running it once.
5. **Not overlap** with itself (a cron run that takes longer than the interval).
6. **Leave evidence**: timestamped logs, and exit codes a scheduler can alert on.

New tools in this topic: **`trap`** (run code when the script exits or gets a signal), **`mktemp`** (safe temporary files), **`flock`** (a lock so only one copy runs), **`timeout`**, **arrays**, and **ShellCheck**.

## Why it exists

A one-off script that works on your test input is easy. Production scripts face empty variables, file names with spaces, full disks, network timeouts and being killed halfway through. Classic outages caused by fragile scripts: deleting `/` because a variable was empty, filling the disk with half-written temp files, two backup runs corrupting each other, a "successful" job that silently did nothing.

## Analogy

A quick script is a **paper airplane**: fine across the room. A production script is a **real aircraft**: it needs pre-flight checks (validation), a checklist that's safe to rerun (idempotency), only one pilot at a time (locking), a plan for engine failure (traps and retries), and a black-box recorder (logs and exit codes).

## How it works inside

### `set -Eeuo pipefail` and its limits

| Option | Effect |
|---|---|
| `-e` (errexit) | Exit when a command fails, **with many exceptions** |
| `-u` (nounset) | Using an unset variable is an error; write `${var:-}` for optional ones |
| `-o pipefail` | A pipeline fails if **any** part fails (otherwise only the last part counts) |
| `-E` (errtrace) | `ERR` traps also fire inside functions and subshells |

**Where `-e` silently does nothing:**

```bash
# 1. Inside anything used as a condition, including a whole function called from if:
set -e; f(){ false; echo "after false"; }; if f; then echo ok; fi
#   after false     ← the failure inside f was ignored
#   ok

# 2. A plain assignment from $(...) DOES stop the script…
set -e; x=$(false); echo "not reached"

# 3. …but "local", "export", "declare", "readonly" hide the failure (their own status is 0):
set -e; g(){ local v=$(false); echo "local hid the error"; }; g
#   fix: local v; v=$(false)

# 4. Without pipefail, only the last stage of a pipeline counts:
set -e; false | true; echo "reached without pipefail"
```

So treat `set -e` as a **safety net**, not error handling. Check critical commands explicitly: `cmd || die "cmd failed"`.

### trap: always clean up

`trap 'commands' EXIT` runs the commands **whenever the script ends**: a normal end, `exit N`, or an error stop from `set -e`. Signals are separate: add `trap '…; exit 130' INT TERM`, so Ctrl+C or `kill` also ends through the EXIT trap. (130 = 128 + 2, the standard "killed by SIGINT" code, topic 004.) SIGKILL can't be trapped (topic 033).

### Temporary files

Predictable names like `/tmp/myscript.tmp` are dangerous: another user can create that file or a **symlink** first, and your script (perhaps running as root) then writes to their target. **`mktemp`** creates a unique, private file (mode 600) or directory (`-d`, mode 700).

### Atomic writes

Write output to a temp file **in the same directory (filesystem)** as the target, then `mv` it into place. On the same filesystem, `mv` is a **rename**, which is atomic (topic 007): readers see either the old file or the complete new one, never half a file.

### Locking

**`flock`** takes a lock on a file. While one copy of the script holds it, a second copy either waits (`-w 30`) or gives up at once (`-n`). The kernel releases the lock automatically when the process ends, even if it crashes.

## Commands

### A reusable template

```bash
#!/usr/bin/env bash
# backup-dir.sh - archive a directory into DEST, keep the newest N copies.
# Usage: backup-dir.sh [-n KEEP] [-v] SOURCE_DIR DEST_DIR
set -Eeuo pipefail
readonly PROG=${0##*/}                  # script name without the path
KEEP=7 VERBOSE=0

log()   { printf '%s %s: %s\n' "$(date +%FT%T)" "$PROG" "$*" >&2; }
die()   { log "ERROR: $*"; exit 1; }
usage() { echo "Usage: $PROG [-n KEEP] [-v] SOURCE_DIR DEST_DIR" >&2; exit 2; }

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
[[ -d $src ]] || die "source is not a directory: $src"
mkdir -p -- "$dest"

exec 9>"${XDG_RUNTIME_DIR:-/run/lock}/$PROG.lock"   # lock file on fd 9: /run/user/UID for users, /run/lock for root
flock -n 9 || die "another instance is running"

tmp=$(mktemp -d)
# shellcheck disable=SC2317   # cleanup is called by the trap, which ShellCheck can't see
cleanup() { local rc=$?; rm -rf -- "$tmp"; (( rc == 0 )) || log "failed (rc=$rc)"; }
trap cleanup EXIT
trap 'log "interrupted"; exit 130' INT TERM

name="$(basename -- "$src")-$(date +%Y%m%d-%H%M%S).tar.gz"
tar -czf "$tmp/$name" -C "$(dirname -- "$src")" "$(basename -- "$src")"
mv -- "$tmp/$name" "$dest/$name"
(( VERBOSE )) && log "wrote $dest/$name"

# shellcheck disable=SC2012   # ls -t is fine here: the file names are generated by this script
mapfile -t old < <(ls -1t -- "$dest"/*.tar.gz | tail -n +$((KEEP + 1)))
for f in "${old[@]}"; do rm -f -- "$f"; (( VERBOSE )) && log "pruned $f"; done
exit 0
```
(`/run/lock` is writable only by root on RHEL. The lock line therefore uses `$XDG_RUNTIME_DIR` (your private `/run/user/UID` directory, set at login) when it exists, and falls back to `/run/lock` under `sudo` or systemd, where that variable is not set.)

Expected behaviour:
```
$ ./backup-dir.sh                         → Usage: …                         rc=2
$ ./backup-dir.sh -n x /etc /tmp/bk       → ERROR: -n needs a number          rc=1
$ ./backup-dir.sh /nope /tmp/bk           → ERROR: source is not a directory  rc=1
$ (3 runs with -v -n 2)                   → wrote … ×3, pruned the oldest; 2 archives remain
$ (while another run holds the lock)      → ERROR: another instance is running rc=1
```
- `mapfile -t old < <(…)` reads lines into an **array** (`old`). `"${old[@]}"` expands each element as a separate, safely quoted word.

### Quoting, arrays and safe paths

```bash
arr=("a b" c)
for x in ${arr[@]};   do echo "[$x]"; done     # [a] [b] [c]  ← unquoted: "a b" was split
for x in "${arr[@]}"; do echo "{$x}"; done     # {a b} {c}    ← correct
```

| Rule | Why |
|---|---|
| Quote every expansion: `"$var"`, `"$(cmd)"`, `"${arr[@]}"` | No word splitting or glob surprises |
| `--` before path arguments: `rm -f -- "$f"` | Names starting with `-` aren't read as options |
| `"${dir:?}"/*` in destructive commands | Aborts if `dir` is empty instead of hitting `/*` |
| Build argument lists as arrays: `opts=(-a --delete); rsync "${opts[@]}" …` | No quoting hacks inside strings |
| Loop files with globs or `find -print0 \| while IFS= read -r -d '' f` | Never parse `ls` output |
| `printf '%s\n' "$x"` instead of `echo "$x"` | `echo` misreads values like `-n` or `-e` |

### Idempotent patterns

| Instead of | Write |
|---|---|
| `useradd bob` | `id bob &>/dev/null \|\| useradd bob` |
| `echo 'line' >> /etc/file` | `grep -qxF 'line' /etc/file \|\| echo 'line' >> /etc/file` |
| `mkdir /data` | `mkdir -p /data` |
| `ln -s target link` | `ln -sfn target link` |

When a script fills up with these checks, the job probably belongs in configuration management (Ansible, topic 105).

### Timeouts and retries

```bash
timeout 10 curl -fsS https://api.example.com/health || die "health check failed"

retry() {                               # retry N times, doubling the wait each time
  local n=$1; shift; local i delay=1
  for ((i=1; i<=n; i++)); do
    "$@" && return 0
    log "attempt $i/$n failed: $*"; sleep "$delay"; delay=$((delay * 2))
  done
  return 1
}
retry 5 curl -fsS -o /tmp/file https://repo.example.com/file
```
- `timeout 10 cmd` kills `cmd` after 10 seconds (exit code 124). Never let a network call hang forever.
- `curl -f` makes HTTP errors (4xx/5xx) return non-zero. Without `-f`, curl "succeeds" on a 500 error page (topic 070).

### Logging and exit codes

- Log to **stderr**; keep stdout for real output that other tools consume.
- `logger -t myjob "message"` writes to the journal/syslog from any script (topic 038).
- Exit codes: `0` success, `1` failure, `2` usage error. Leave `126`, `127` and `128+N` for their standard meanings.
- Run scheduled scripts as **systemd services and timers** (topics 037, 039, 098): logs, overlap protection, `OnFailure=` alerts and resource limits come for free.

### Static analysis and testing

```bash
sudo dnf install -y epel-release ; sudo dnf install -y ShellCheck   # ShellCheck comes from EPEL (Ubuntu: apt install shellcheck)
shellcheck backup-dir.sh
```
```
In backup-dir.sh line 43:
for f in ${old[@]}; do rm -f -- "$f"; (( VERBOSE )) && log "pruned $f"; done
         ^-------^ SC2068 (error): Double quote array expansions to avoid re-splitting elements.
```
- That is what ShellCheck says if you drop the quotes from `"${old[@]}"`. The script as printed above passes with no warnings. Its two `# shellcheck disable=…` comments silence false alarms on purpose: one for `ls -t` on names the script made itself, one for a function only a `trap` calls.
- ShellCheck catches unquoted variables, the `local` masking problem, useless `cat`, `#!/bin/sh` portability issues and dozens more. Treat its warnings as bugs.
- Test the **unhappy** paths on purpose: no arguments, bad arguments, missing directories, a full disk (write to `/dev/full`), Ctrl+C in the middle, two runs at once.

### When to stop using bash

Move to Python (or Go, or Ansible) when you need real data structures, JSON/YAML handling beyond `jq`, complex error handling, unit tests, or more than a few hundred lines. Bash is excellent **glue**, not an application platform.

### Try it
1. Run the template three times with `-v -n 2` and confirm only 2 archives remain.
2. Start a run with a long `sleep` added before `tar`, then start a second run: it must refuse. Press Ctrl+C on the first and confirm the temp directory is gone.
3. Run ShellCheck on three scripts you wrote earlier and fix every finding.
4. Turn the script into a systemd service + timer with `Persistent=true` (topic 039).

**Check your work:** on your lab VM, from the notes folder, run `sudo ./checks/check 045` for every step, or `sudo ./checks/check 045 STEP` for one (topic 002 shows how to get the notes there).

## Where you'll use it

- **Backup, cleanup and maintenance jobs** that run from timers.
- **CI/CD steps and deployment scripts:** a failure must stop the pipeline, not silently continue.
- **Container entrypoints:** trap SIGTERM to shut down cleanly; `exec` the main process.
- **Code review:** reviewers look for unquoted variables, missing `--`, unchecked `cd`, `rm -rf $VAR`, missing locks.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| The script continued after a failure | The failure was in an `if`, `&&`/`\|\|`, `local x=$(…)`, or a pipeline without `pipefail` | Check explicitly with `\|\| die`; split `local`; add `pipefail` |
| `unbound variable` | `set -u` and an optional variable | `${var:-}` |
| Temp files pile up in `/tmp` | No cleanup trap | `mktemp` + `trap … EXIT` |
| Two runs corrupted each other | No lock | `flock -n` |
| A consumer read a half-written file | Wrote directly to the final path | Write a temp file in the same directory, then `mv` |
| The script hung forever | A network call without a timeout | `timeout`, `curl --max-time` |
| It deleted far too much | An empty variable in a path | `${dir:?}`, `--`, review with `echo` first |

## Quick recap

- `set -Eeuo pipefail` is a safety net with holes (conditions, `local x=$(…)`, `&&`/`||`). Check critical steps explicitly.
- Quote everything, use `--` before paths, `${dir:?}` before destructive globs, arrays for argument lists.
- `mktemp` + `trap … EXIT` for cleanup; temp file + `mv` for atomic writes; `flock -n` against overlap; `timeout` and retries for network calls.
- Log to stderr or the journal, use meaningful exit codes, run under systemd timers, and lint with ShellCheck.

**Interview questions**

1. *Is `set -e` enough to make a script safe?* No. It's ignored in conditions and `&&`/`||` lists, `local var=$(cmd)` hides failures, and without `pipefail` only the last pipeline stage counts. Check important commands explicitly.
2. *How do you make sure a script cleans up its temp files even when interrupted?* Create them with `mktemp`, delete them in `trap '…' EXIT`, and add `trap 'exit 130' INT TERM` so signals also go through the EXIT trap.
3. *How do you stop a cron job from overlapping with itself?* Take a lock with `flock -n` on a lock file at the start (or run it as a systemd timer, which won't start a second instance of a running service).

**Scenario question** (answer out loud first, then compare)

> *"Review this production cron job for me: it backs up a database to `/backup/db.sql`, then deletes backups older than 7 days. What would you check before trusting it?"*

**Model answer:**
1. **Failure handling:**
   - `set -Eeuo pipefail`, so `mysqldump | gzip` fails if the dump fails;
   - an explicit check before the "delete old backups" step, so a failed backup never deletes the good ones.
2. **Atomic writes:** dump to a temp file (`mktemp` in the same directory), then `mv` it into place. A half-written file is never mistaken for a backup.
3. **No overlap:** `flock -n /run/lock/dbbackup.lock` so a slow run and the next run don't collide.
4. **Cleanup:** `trap 'rm -f "$tmp"' EXIT`.
5. **Safe deletion:** `find /backup -name 'db-*.sql.gz' -mtime +7 -delete` with a quoted pattern and a fixed directory, never a variable that could be empty.
6. **Visibility:** log to the journal or a file, exit non-zero on failure, and alert on a **missing** recent backup.
7. **Restore test:** it isn't a backup until a restore has worked.

**Likely follow-ups:**
- *Why is `local out=$(cmd)` a trap?* `local` succeeds, hiding `cmd`'s failure from `set -e`. Declare first, assign separately.
- *What does ShellCheck add?* It catches quoting bugs, unused variables, wrong tests and portability problems before they run.
