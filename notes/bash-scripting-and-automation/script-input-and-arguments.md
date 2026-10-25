# Script Input: read, Positional Parameters & Argument Handling

> **Objective:** *Process script inputs ($1, $2, etc.)* **[RHCSA Core]**
> **Related:** [Script basics](script-basics-and-variables.md) · [Conditionals & tests](conditionals-and-tests.md) · [Loops](loops.md) · [Positional parameters (shell note)](../shell-and-command-line/shell-variables-and-environment.md#6-positional-parameters-rhcsa-core)

## 1. Interactive Input: `read`

````bash
read -r name                          # wait for a line; -r keeps backslashes literal
read -rp "Enter your name: " name     # prompt on the same line
read -rsp "Password: " pass ; echo    # silent (no echo); echo moves to a new line
read -r first last rest               # split into words; extra words go to the LAST variable
read -ra colors                       # into an array: ${colors[0]} ${colors[1]} …
read -r ; echo "$REPLY"               # no variable → $REPLY
read -rt 10 -p "Answer within 10s: " ans || echo "timeout"   # -t timeout
read -rn 1 -p "Continue? [y/n] " yn ; echo                    # -n N characters
````

| Option | Meaning |
|---|---|
| `-p "text"` | Prompt |
| `-s` | Silent (passwords) |
| `-a array` | Store words in an array |
| `-r` | Raw: don't treat `\` as escape (**use almost always**) |
| `-t N` | Timeout (non-zero exit status if it expires) |
| `-n N` | Return after N characters |
| `IFS=` | Keep leading/trailing whitespace: `IFS= read -r line` |

## 2. Command-Line Arguments **[RHCSA Core]**

| Parameter | Meaning |
|---|---|
| `$0` | Script name as invoked |
| `$1` … `$9`, `${10}` | Arguments (braces from 10 on) |
| `$#` | Number of arguments |
| `"$@"` | All arguments, **each kept separate** (use this) |
| `"$*"` | All arguments joined into one string |
| `shift [n]` | Discard the first n arguments; `$2` becomes `$1` |

`$@` and `$*` only differ when **quoted**.

````bash
#!/bin/bash
# args.sh
echo "Script: $0  Count: $#"
echo "First: ${1:-<none>}  Second: ${2:-<none>}"
for arg in "$@"; do echo "- $arg"; done
args=("$@") ; echo "Third via array: ${args[2]:-<none>}"
````

````bash
./args.sh apple "big banana" cherry
````

### Validate arguments

````bash
#!/bin/bash
# backup.sh SOURCE_FILE BACKUP_DIR
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <source_file> <backup_directory>" >&2
    exit 1
fi
src=$1 ; dest=$2
[ -f "$src" ]  || { echo "Error: '$src' is not a regular file" >&2; exit 2; }
[ -d "$dest" ] || { echo "Error: '$dest' is not a directory" >&2; exit 3; }
cp -a -- "$src" "$dest"/ && echo "Copied '$src' to '$dest'"
````

### Process all arguments one by one

````bash
while [ "$#" -gt 0 ]; do
    echo "Processing $1"
    shift
done
````

### Combine arguments and prompts

````bash
name=${1:-}                                  # optional argument
[ -n "$name" ] || read -rp "Name: " name     # ask if not given
read -rp "Country: " country
echo "Hello $name from $country!"
````

### Options with `getopts` **[Advanced]**

````bash
while getopts ":v f:" opt; do
  case $opt in
    v) verbose=1 ;;
    f) file=$OPTARG ;;
    *) echo "Usage: $0 [-v] [-f file]" >&2; exit 1 ;;
  esac
done
shift $((OPTIND - 1))        # remaining non-option arguments in "$@"
````

## 3. RHCSA Exam Patterns **[RHCSA Core]**

````bash
#!/bin/bash
# /usr/local/bin/mkusers  — create a user for every argument
[ "$#" -ge 1 ] || { echo "Usage: $0 user…" >&2; exit 1; }
for u in "$@"; do
    if id "$u" &>/dev/null; then echo "$u exists"; else useradd "$u" && echo "created $u"; fi
done
````

- Check the argument count and print a usage message to **stderr**, with a non-zero exit.
- Use the exact output text and exit codes the task specifies.

## 4. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Arguments with spaces split up | Unquoted `$@` / `$1` | `"$@"`, `"$1"` |
| `$10` shows `$1` followed by `0` | Missing braces | `${10}` |
| Backslashes vanish from input | `read` without `-r` | `read -r` |
| Password visible / prompt on the same line as output | Missing `-s` / missing `echo` after | `read -rsp …; echo` |
| Script hangs in cron | `read` waits for input that never comes | Use arguments, not prompts, in automation |

## 5. Interview Questions

| Question | Answer |
|---|---|
| `"$@"` vs `"$*"`? | `"$@"` keeps each argument separate; `"$*"` joins them into one string. |
| How do you check the number of arguments? | `$#` (e.g., `[ "$#" -ne 2 ]`). |
| What does `shift` do? | Drops `$1` and moves the remaining arguments down. |
| How do you read a password without echoing it? | `read -rsp "Password: " pw`. |

## 6. Quick Revision

````bash
read -rp "Prompt: " v · read -rsp "Pass: " p ; echo · read -ra arr · $REPLY · -t N · -n N
$0 $1..$9 ${10} $# "$@" "$*" shift · [ "$#" -ne N ] && { echo "Usage: $0 …" >&2; exit 1; }
for a in "$@" · while [ "$#" -gt 0 ]; do …; shift; done · getopts
````

## 7. Cross-References

- [Script basics](script-basics-and-variables.md)
- [Conditionals & tests](conditionals-and-tests.md)
- [Loops](loops.md)
- [Positional parameters (shell note)](../shell-and-command-line/shell-variables-and-environment.md#6-positional-parameters-rhcsa-core)
