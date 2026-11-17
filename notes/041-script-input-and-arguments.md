# 041 · Script Input: Arguments, read and getopts

> **You need first:** [040 · Script basics](040-script-basics.md)
> **Next:** [042 · Conditionals](042-conditionals.md)

---

## What it is

A script gets input in three ways:

1. **Command-line arguments**: `./backup.sh /etc /backup` → inside the script, `$1` = `/etc`, `$2` = `/backup`. These are the **positional parameters**.
2. **Interactive input** with **`read`**: the script asks a question and waits for typing.
3. **stdin** (piped or redirected input), read line by line (topic 043), plus **environment variables** (topic 012).

**Options** like `-v` or `-f file` are parsed with the builtin **`getopts`**.

## Why it exists

A script with hard-coded values does one job. With arguments, the same script works for any user, file or server: `mkusers alice bob carol`. Arguments are also what automation uses (cron, CI, Ansible, Kubernetes `args:`), since automation can't type answers to prompts.

## Analogy

Arguments are **the order written on a form** when you hand in a job ("copy *this* to *there*"). `read` is the worker **phoning you to ask** a question halfway through. Good automation uses the form, because nobody answers the phone at 3 AM.

## How it works inside

When bash starts a script, it takes the words after the script name (after all quoting and expansion, topics 011–013) and stores them as `$1`, `$2`, …. `$#` is how many there are. They're a simple list that `shift` can drop from the front.

| Parameter | Meaning |
|---|---|
| `$0` | The script's name as it was called |
| `$1` … `$9`, `${10}` | Arguments. **Braces are needed from 10 up** (`$10` is `$1` followed by `0`) |
| `$#` | Number of arguments |
| `"$@"` | All arguments, **each kept separate**: use this almost always |
| `"$*"` | All arguments joined into **one** string |
| `shift [n]` | Drop the first n arguments; `$2` becomes `$1`, and so on |

`"$@"` vs `"$*"` only differ when quoted, and `"$@"` is the one that keeps `"big banana"` as one argument.

**`read`** reads one line from stdin, splits it on `IFS` (spaces/tabs, topic 012), and assigns the words to the variable names you give. The last variable gets everything left over.

## Commands

### Arguments

```bash
cat > args.sh <<'EOF'
#!/bin/bash
echo "Script: $0   Count: $#"
echo "First: ${1:-<none>}   Second: ${2:-<none>}"
for arg in "$@"; do
    echo " - [$arg]"
done
EOF
chmod +x args.sh
./args.sh apple "big banana" cherry
```
```
Script: ./args.sh   Count: 3
First: apple   Second: big banana
 - [apple]
 - [big banana]
 - [cherry]
```
- `${1:-<none>}` shows a default if `$1` is empty (topic 012).
- `"big banana"` stayed one argument thanks to quotes on the command line **and** `"$@"` in the script.

### Validating arguments (always do this)

`[ … ]` is the test command: it checks a condition and returns 0 (true) or 1 (false). Topic 042 explains it fully. Here, `-ne` means "not equal" for numbers, `-f` "is a regular file", `-d` "is a directory".

```bash
#!/bin/bash
# backup.sh SOURCE_FILE BACKUP_DIR - copy a file into a backup directory
usage() { echo "Usage: $0 <source_file> <backup_dir>" >&2; exit 1; }

[ "$#" -eq 2 ] || usage
src=$1
dest=$2
[ -f "$src" ]  || { echo "Error: '$src' is not a regular file" >&2; exit 2; }
[ -d "$dest" ] || { echo "Error: '$dest' is not a directory" >&2;  exit 3; }

cp -a -- "$src" "$dest"/ && echo "Copied '$src' to '$dest'"
```
```bash
./backup.sh ; echo "rc=$?"
./backup.sh /etc/hosts /nope ; echo "rc=$?"
```
```
Usage: ./backup.sh <source_file> <backup_dir>
rc=1
Error: '/nope' is not a directory
rc=3
```
- Error messages go to **stderr** (`>&2`) with a **non-zero** exit code, so callers (cron, CI, other scripts) can detect the failure.
- `--` before the file names protects against names starting with `-` (topic 004).

### Processing arguments one by one with shift

```bash
while [ "$#" -gt 0 ]; do
    echo "Processing $1"
    shift
done
```

### A real example: create users from arguments

```bash
#!/bin/bash
# mkusers - create every user named on the command line
[ "$#" -ge 1 ] || { echo "Usage: $0 user..." >&2; exit 1; }
for u in "$@"; do
    if id "$u" &>/dev/null; then
        echo "$u already exists"
    else
        useradd "$u" && echo "created $u"
    fi
done
```
- `id user &>/dev/null` = check whether the user exists, silently, using only the exit code. `&>` sends both stdout and stderr (topic 016).

### read: interactive input

```bash
read -rp "Enter your name: " name
read -rsp "Password: " pass ; echo      # -s = don't show typing; echo moves to a new line
read -r first last rest <<< "Ada Lovelace Countess of Lovelace"
echo "$first | $last | $rest"
```
```
Ada | Lovelace | Countess of Lovelace
```
- Extra words all go into the last variable.

| Option | Meaning |
|---|---|
| `-r` | Raw: don't treat `\` as an escape. **Use it almost always** |
| `-p "text"` | Show a prompt |
| `-s` | Silent (for passwords) |
| `-a arr` | Put the words into an array: `${arr[0]}`, `${arr[1]}` |
| `-t N` | Give up after N seconds (non-zero exit status) |
| `-n N` | Return after N characters (for y/n questions) |
| `IFS=` before `read` | Keep leading and trailing spaces |

With no variable name, the line goes into `$REPLY`.

```bash
read -rt 10 -n 1 -p "Continue? [y/N] " ans || ans=n ; echo
```

### Mixing: argument first, else ask

```bash
name=${1:-}
[ -n "$name" ] || read -rp "Name: " name     # -n = "is not empty"
```

### Options with getopts

```bash
#!/bin/bash
# deploy.sh [-v] [-e ENV] VERSION
verbose=0
env=staging
while getopts ":ve:" opt; do
    case $opt in
        v) verbose=1 ;;
        e) env=$OPTARG ;;
        :) echo "Option -$OPTARG needs a value" >&2; exit 1 ;;
        *) echo "Usage: $0 [-v] [-e env] version" >&2; exit 1 ;;
    esac
done
shift $((OPTIND - 1))          # remove the parsed options; the rest is in "$@"
version=${1:?version required}
echo "deploying $version to $env (verbose=$verbose)"
```
```bash
./deploy.sh -v -e prod 2.4.1
```
```
deploying 2.4.1 to prod (verbose=1)
```
- In the option string `":ve:"`: `v` is a flag; `e:` means `-e` takes a value (put into `$OPTARG`). The leading `:` lets you handle errors yourself.
- `case` is explained in topic 042. `$((…))` is arithmetic (topic 044).
- `getopts` only handles short options (`-v`). Long options (`--verbose`) need a manual `while`/`case` loop over `"$@"`.

### Try it
1. Write `args.sh` and call it with zero, one and three arguments, including one with spaces.
2. Write `backup.sh` with validation; test every error path and check `$?`.
3. Add `-n` (dry-run) and `-d DIR` options with getopts.
4. Write a script that takes a username as `$1`, or asks for one with `read` if it's missing.

**Check your work:** on your lab VM, from the notes folder, run `sudo ./checks/check 041` for every step, or `sudo ./checks/check 041 STEP` for one (topic 002 shows how to get the notes there).

## Where you'll use it

- **Every reusable script:** pass targets and options as arguments, never hard-code them.
- **Automation-safe design:** no `read` prompts in anything run by cron, CI or Ansible. Accept arguments or environment variables instead (a prompt makes the job hang forever).
- **Container entrypoints:** `ENTRYPOINT ["/entrypoint.sh"]` + `CMD ["serve"]` → the script receives `serve` as `$1`. Kubernetes `args:` arrive the same way.
- **Wrappers:** `exec /usr/bin/realtool "$@"` passes every argument through unchanged.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| An argument with spaces got split | `$@` or `$1` used without quotes | `"$@"`, `"$1"` |
| `$10` prints the first argument followed by `0` | No braces | `${10}` |
| Backslashes disappear from input | `read` without `-r` | `read -r` |
| A password shows on screen, or the prompt is glued to the next output | Missing `-s`, or no `echo` after it | `read -rsp …; echo` |
| The script hangs in cron or CI | `read` is waiting for input that never comes | Use arguments or environment variables in automation |
| `getopts` doesn't see options after a file name | It stops at the first non-option argument | Put options first: `script -v file` |

## Quick recap

- `$0` name, `$1…${10}` arguments, `$#` count, `"$@"` all (kept separate), `shift`.
- Validate first: wrong count or bad values → usage message on **stderr** + non-zero `exit`.
- `read -rp "Prompt: " var`; `-s` for secrets, `-t` timeout, `-a` array. Avoid prompts in automation.
- `getopts ":ve:"` + `case` + `shift $((OPTIND-1))` for options.

**Interview questions**

1. *`"$@"` vs `"$*"`?* `"$@"` expands to each argument as a separate word, preserving spaces inside arguments. `"$*"` joins all arguments into a single string.
2. *How do you check the number of arguments?* With `$#`, for example `[ "$#" -eq 2 ] || { echo "usage…" >&2; exit 1; }`.
3. *How do you read a password without showing it?* `read -rsp "Password: " pw; echo`.

**Scenario question** (answer out loud first, then compare)

> *"Your backup script takes a list of directories as arguments. It works until someone passes `/srv/My Files`. Then it backs up `/srv/My` and fails on `Files`. Fix it."*

**Model answer:**
1. Somewhere the arguments are expanded unquoted: `for d in $@` or `$*`, or `tar … $dirs`.
2. Always use **`"$@"`** (with the quotes): it expands to each original argument as one word, spaces included.
3. If you build a list, use a **bash array**: `dirs=("$@")`, then `tar -czf out.tgz "${dirs[@]}"`.
4. Validate at the start: `[ "$#" -ge 1 ] || { echo "usage: $0 DIR..." >&2; exit 2; }`, and check each one exists with `[ -d "$d" ]`.
5. Test with names that contain spaces, a leading `-` and glob characters.

**Likely follow-ups:**
- *How do you parse `-v -o FILE` style options?* `getopts ":vo:"` in a `while` loop with `case`, then `shift $((OPTIND-1))`.
- *How do you prompt for input without breaking automation?* Only prompt when the value is missing **and** stdin is a terminal (`[ -t 0 ]`); otherwise fail with a usage message.
