# 013 · Shell Expansion and Globbing (Wildcards)

> **You need first:** [012 · Variables and environment](012-variables-and-environment.md)
> **Next:** [014 · Command substitution, subshells and shell options](014-command-substitution-subshells-and-options.md)

---

## What it is

**Expansion** is bash rewriting your command line **before** running it. It replaces shortcuts with real text:

| Expansion | You type | bash turns it into |
|---|---|---|
| **Brace** | `file{1,2,3}.txt` | `file1.txt file2.txt file3.txt` |
| **Tilde** | `~/notes` | `/home/alice/notes` |
| **Variable** | `$HOME` | `/home/alice` |
| **Arithmetic** | `$((4*5))` | `20` |
| **Command substitution** | `$(date +%F)` | `2026-11-16` (topic 014) |
| **Globbing** (filename expansion) | `*.log` | the names of all matching files in this directory |

A **glob** (or **wildcard**) is a pattern that matches **file names**: `*`, `?`, `[abc]`.

A **locale** is your language and region setting (for example `en_US.UTF-8`). It affects sort order, date formats and messages.

## Why it exists

Expansion saves typing (`mkdir {src,docs,tests}`) and lets one command work on many files (`rm *.tmp`). But because **the shell** does it, not the command, it causes some of the most common mistakes: a `find` that searches the wrong thing, or an `rm` that deletes more than you meant.

## Analogy

Expansion is a **personal assistant who rewrites your instructions** before passing them on. You write "send this to everyone in sales (`sales*`)". The assistant looks up the list, writes out every name, and hands the worker a full list. The worker (`ls`, `rm`) never sees "everyone in sales"; it only sees the names. If nobody matches, this assistant passes your note on unchanged, which can confuse the worker.

## How it works inside

### The order bash applies expansions

| Step | Expansion | Example |
|---|---|---|
| 1 | Brace | `{a,b}` |
| 2 | Tilde | `~`, `~alice` |
| 3 | Variable, arithmetic and command substitution (left to right) | `$HOME`, `$((2*3))`, `$(date)` |
| 4 | **Word splitting** of *unquoted* results (on spaces/tabs/newlines) | `f="a b"; touch $f` makes 2 files |
| 5 | **Globbing** of *unquoted* patterns | `*.conf` |
| 6 | Quote removal | `"x"` becomes `x` |

What the order means in practice:
- Braces come **first**, before variables. So `{1..$n}` does **not** work. Use `seq 1 "$n"` instead.
- `~` is **not** expanded inside quotes. `"~/file"` stays literally `~/file`. Write `"$HOME/file"`.
- **Quotes stop steps 4 and 5.** That's why `"$var"` is safe: no splitting, no wildcard surprises.

### Globbing: the shell asks the filesystem

When bash sees an unquoted `*.log`, it reads the directory, keeps the names that match, **sorts them** (by locale), and puts them on the command line in place of the pattern. So `rm *.log` becomes `rm a.log b.log c.log` before `rm` even starts.

Rules:
- `*` and `?` do **not** match a leading dot, so **hidden files are skipped**. Use `.*` explicitly or `shopt -s dotglob`.
- **If nothing matches, the pattern stays as-is.** In an empty folder, `ls *.txt` gets the literal argument `*.txt` and says `cannot access '*.txt'`. (`shopt -s nullglob` makes a no-match expand to nothing.)
- `/` is never matched by a wildcard. `*/` matches directories one level down.
- To stop globbing: quote it (`'*'`), escape it (`\*`), or `set -f`.

### Glob vs regular expression: don't mix them up

**Regular expressions** (regex, topic 017) are patterns for matching **text inside files** (`grep`, `sed`, `awk`). Globs match **file names**. They look similar but mean different things:

| | Glob (shell, `find -name`, `case`) | Regex (`grep`, `sed`, `awk`) |
|---|---|---|
| Any text | `*` | `.*` |
| One character | `?` | `.` |
| A set of characters | `[abc]` | `[abc]` |
| Not in a set | `[!abc]` | `[^abc]` |
| `*` means | "anything" | "zero or more of the **previous** thing" |
| Must match the whole name? | Yes, automatically | No; use `^` and `$` to anchor |

## Commands

### Brace expansion

```bash
echo file{1,2,3}.txt
echo {1..5} {01..05} {a..e} {0..10..5}
```
```
file1.txt file2.txt file3.txt
1 2 3 4 5 01 02 03 04 05 a b c d e 0 5 10
```
- `{1..5}` is a range, `{01..05}` is zero-padded, `{0..10..5}` counts in steps of 5.
- Braces **generate** text whether files exist or not. Globs only **match** files that exist.

```bash
mkdir -p app/{bin,conf,logs}
cp -a nginx.conf{,.bak}     # becomes: cp -a nginx.conf nginx.conf.bak
```

### Tilde

```bash
echo ~ ~root ~+ ~-
```
```
/home/alice /root /home/alice/app /home/alice
```
- `~+` = current directory, `~-` = previous directory.

### Arithmetic (whole numbers only)

```bash
echo $((3 + 5)) $((7 / 2)) $((7 % 2)) $((2 ** 10))
```
```
8 3 1 1024
```
- `/` divides and drops the remainder. `%` gives the remainder. `**` is power. For decimals use `bc` or `awk` (topic 044).

### Globbing

Set up test files:
```bash
mkdir /tmp/g && cd /tmp/g
touch app.log app2.log db.log notes.txt Doc1 Doc2 DocA .hidden
```

| Pattern | Matches | Example result |
|---|---|---|
| `*` | Any text, including none | `ls *.log` → `app.log app2.log db.log` |
| `?` | Exactly one character | `ls Doc?` → `Doc1 Doc2 DocA` |
| `[abc]` | One character from the set | `ls Doc[1A]` → `Doc1 DocA` |
| `[0-9]`, `[a-z]` | One character from a range | `ls Doc[0-9]` → `Doc1 Doc2` |
| `[!abc]` or `[^abc]` | One character **not** in the set | `ls Doc[!1]` → `Doc2 DocA` |
| `[[:digit:]]` `[[:alpha:]]` `[[:upper:]]` `[[:lower:]]` `[[:alnum:]]` `[[:space:]]` | Named character classes (safe in every locale) | `ls *[[:digit:]]*` |

```bash
echo *
```
```
app2.log app.log db.log Doc1 Doc2 DocA notes.txt
```
- `.hidden` is missing: `*` skips dot files. `echo *` is also a way to list files when `ls` is broken.
- The order follows your **locale** (`en_US.UTF-8`): it ignores case and punctuation at first, so `app2.log` sorts before `app.log` and `Doc1` sits among the lowercase names. With `LC_ALL=C` you get strict byte order: `Doc1 Doc2 DocA app.log app2.log db.log notes.txt` (see "locale" below).

```bash
echo .*
```
```
.hidden
```
- Since bash 5.2, `.*` no longer matches `.` and `..` (the `globskipdots` option, on by default). Older shells printed `. .. .hidden`, which is why old scripts warn that `rm -rf .*` could climb into the parent directory. Don't rely on either behaviour in scripts: use `shopt -s dotglob` or an explicit pattern such as `.[!.]*`.

```bash
ls *.pdf
```
```
ls: cannot access '*.pdf': No such file or directory
```
- No match, so `ls` received the literal text `*.pdf`.

```bash
echo rm *.log
```
```
rm app2.log app.log db.log
```
- **Preview trick:** put `echo` in front of a destructive command to see exactly what it would run. Then remove the `echo`.

```bash
cp -a src/. dest/
```
- Copies a directory's contents **including hidden files**. `src/*` would skip them.

### The classic `find` mistake

```bash
cd /etc
find /etc -name *.conf
```
```
find: paths must precede expression: `dhcpcd.conf'
find: possible unquoted pattern after predicate `-name'?
```
- Bash expanded `*.conf` using the files in your **current** directory *before* `find` ran, so `find` received several names and got confused.

```bash
find /etc -name '*.conf'
```
- Quoted: `find` receives the pattern itself and does its own matching in every directory. **Always quote patterns that are meant for the command, not the shell**: `find -name`, `grep`, `tar --wildcards`, `semanage fcontext`.

### Extra bash options

```bash
shopt -s globstar ; ls **/*.conf     # ** = any depth of subdirectories
shopt -s extglob  ; ls !(*.log)      # everything EXCEPT *.log
shopt -s nullglob                    # no match → expands to nothing (good in scripts)
shopt -s dotglob                     # * also matches hidden files
```

### Locale and sorting

```bash
locale
```
```
LANG=en_US.UTF-8
LC_CTYPE="en_US.UTF-8"
LC_NUMERIC="en_US.UTF-8"
...
LC_ALL=
```
- `LANG` is the default. `LC_*` variables override single categories (`LC_COLLATE` = sort order, `LC_TIME` = date format). `LC_ALL` overrides everything.

```bash
ls ; LC_ALL=C ls
```
```
app2.log  app.log  db.log  Doc1  Doc2  DocA  notes.txt
Doc1  Doc2  DocA  app.log  app2.log  db.log  notes.txt
```
- With `en_US`, sorting ignores case and punctuation. With `C`, it uses raw byte order, so uppercase comes before lowercase. **Scripts that sort or compare text should set `LC_ALL=C`** for predictable results.
- Bash 5 (RHEL 10, current Ubuntu) makes `[a-z]` match only lowercase ASCII in every locale. Older material that says `[a-z]` also matches capitals is out of date.

```bash
localectl                                   # system-wide default (/etc/locale.conf)
sudo localectl set-locale LANG=en_US.UTF-8  # change it permanently
```

### Directory stack

```bash
pushd /etc ; pushd /var/log ; dirs -v ; popd
```
```
/etc ~
/var/log /etc ~
 0  /var/log
 1  /etc
 2  ~
/etc ~
```
- `pushd` changes directory and remembers where you were; `popd` goes back. For just two places, `cd -` is simpler.

### Try it
1. In `/tmp/g`, predict then run: `ls ?o*`, `ls *[0-9].log`, `ls [!a]*`.
2. Run `n=3; echo {1..$n}` then `seq 1 $n`. Why are they different?
3. In an empty directory, run `for f in *.txt; do echo "got: $f"; done`, then with `shopt -s nullglob`.
4. `cd /etc; find /etc -name *.conf | head` vs `find /etc -name '*.conf' | head`.

## Where you'll use it

- **Bulk file operations:** `mv *.log archive/`, `chmod 640 *.conf`. Preview with `echo` first.
- **Backups before edits:** `cp -a file{,.bak}`.
- **Kubernetes and Docker:** `kubectl apply -f manifests/` vs `kubectl apply -f 'manifests/*.yaml'`. Shell globbing vs the tool's own pattern handling causes surprises.
- **Scripts:** `for f in /var/log/app/*.log; do …; done` with `nullglob`, so an empty directory doesn't run the loop once with a literal `*.log`.
- **Predictable output in automation:** `LC_ALL=C sort`, `LC_ALL=C` before parsing command output.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `find: paths must precede expression` | Unquoted glob expanded by the shell | Quote the pattern |
| `ls: cannot access '*.txt'` | Nothing matched; the pattern was passed literally | Expected. In scripts use `nullglob` |
| `Argument list too long` | The glob expanded to more names than the kernel allows on one command line | `find … -exec cmd {} +` or `xargs` (topic 020) |
| Hidden files weren't copied with `cp dir/* dest` | `*` skips dot files | `cp -a dir/. dest/` |
| `touch {1..$n}` created a file literally named `{1..5}` | Braces expand before variables | `touch $(seq 1 "$n")` |
| A file called `-rf` gets treated as an option by `rm *` | Glob produced a name starting with `-` | `rm -- *` or `rm ./*` |
| Sorting differs between servers | Different locales | `LC_ALL=C` in scripts |

## Quick recap

- **The shell expands, not the command.** Order: brace → tilde → variables/arithmetic/`$( )` → word split → glob → quote removal.
- Globs: `*` `?` `[abc]` `[!a]` `[[:digit:]]`. They skip hidden files, and a no-match stays literal.
- Glob ≠ regex. Quote patterns meant for `find`, `grep`, `tar` and the like.
- `echo` before a destructive glob to preview it. `LC_ALL=C` for predictable sorting.

**Interview questions**

1. *Who expands `*.txt` in `ls *.txt`: the shell or `ls`?* The shell. `ls` receives the list of matching file names.
2. *Why quote the pattern in `find . -name '*.log'`?* So the shell doesn't expand it against the current directory first; `find` needs the raw pattern to match in every directory.
3. *Glob vs regex?* Globs match file names, and `*` means "anything". Regular expressions match text, and `*` means "zero or more of the previous item"; "anything" is `.*`.
