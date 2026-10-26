# Shell Expansion & File Globbing

> **Related:** [Quoting](quoting-and-control-operators.md) · [Variables](shell-variables-and-environment.md) · [Command substitution](command-substitution-and-shell-options.md) · [Files & directories](files-and-directories.md) · [grep & regex](../files-and-text-processing/grep-and-regular-expressions.md) · [Finding files](../files-and-text-processing/finding-files.md)

## 1. Overview

**The shell, not the command, expands** wildcards, braces, variables and `~` before running anything. `ls *.txt` never sees `*.txt`; it receives a list of filenames. Knowing the expansion order and the difference between **globs** (filenames) and **regular expressions** (text) prevents a whole class of exam and production mistakes.

## 2. Expansion Order **[Interview Knowledge]**

| # | Expansion | Example | Result |
|---|---|---|---|
| 1 | **Brace** | `file{1,2}.txt` | `file1.txt file2.txt` |
| 2 | **Tilde** | `~`, `~alice`, `~+` (PWD), `~-` (OLDPWD) | `/home/you` |
| 3 | **Parameter/variable**, **arithmetic**, **command substitution** (left to right) | `$HOME`, `$((2*3))`, `$(date +%F)` | values |
| 4 | **Word splitting** of *unquoted* results (on `IFS`) | `f="a b"; touch $f` | 2 files |
| 5 | **Filename expansion (globbing)** of unquoted patterns | `*.conf` | matching names |
| 6 | **Quote removal** | `"x"` | `x` |

Consequences:

- Brace expansion runs **first**, so `{1..$n}` doesn't work. Use `seq 1 "$n"` or a C-style `for` loop.
- `~` isn't expanded inside quotes: `"~/file"` is literal. Use `"$HOME/file"`.
- Quoting stops steps 4 and 5. That's why `"$var"` is safe.

## 3. Brace Expansion

```bash
echo file{1,2,3}.txt        # file1.txt file2.txt file3.txt
echo {1..10}                # 1 2 … 10
echo {01..10}               # 01 02 … 10 (zero-padded)
echo {a..e} {1..10..2}      # a b c d e   1 3 5 7 9
mkdir -p proj/{src,docs,tests}
cp -a nginx.conf{,.bak}     # cp -a nginx.conf nginx.conf.bak
touch my_directory/file{1..10}
```

Braces **generate** text whether or not the files exist; globs **match** only existing files.

## 4. Arithmetic Expansion

```bash
echo $((3 + 5)) $((7 / 2)) $((7 % 2)) $((2 ** 10))   # 8 3 1 1024 (integers only)
n=5; ((n++)); echo $n                                # 6
```

Bash arithmetic is **integer-only**. Use `bc` or `awk` for decimals ([arithmetic](../bash-scripting-and-automation/arithmetic.md)).

## 5. Globbing (Filename Expansion) **[RHCSA Core]**

| Pattern | Matches | Example |
|---|---|---|
| `*` | Any string, including empty | `ls Doc*`, `ls *.log` |
| `?` | Exactly one character | `ls Doc?` → `Doc4 DocA` |
| `[abc]` | One character from the set | `ls Doc[5A]*` |
| `[a-z]`, `[0-9]` | One character in the range | `ls doc[0-9]` |
| `[!abc]` or `[^abc]` | One character **not** in the set (`!` is POSIX) | `ls doc[!5]*` |
| `[[:digit:]]`, `[[:upper:]]`, `[[:lower:]]`, `[[:alpha:]]`, `[[:alnum:]]`, `[[:space:]]` | POSIX character classes (locale-safe; preferred in scripts) | `ls *[[:digit:]]` |

**Rules:**

- **Hidden files** (leading `.`) aren't matched by `*` or `?`. Use `.*` explicitly or `shopt -s dotglob`.
- **No match:** the pattern stays **literal**. In an empty directory `echo *` prints `*`, and `ls *.txt` errors with `cannot access '*.txt'`. `shopt -s nullglob` expands it to nothing; `failglob` makes it an error.
- Results are **sorted** according to the locale (`LC_COLLATE`).
- `/` is never matched by a wildcard. `*/` matches directories one level down: `ls -d */`.
- Prevent globbing by quoting or escaping: `echo '*'`, `echo "*"`, `echo \*`, or `set -f`.

### 5.1 Globs vs regular expressions

| | Glob (shell, `find -name`, `case`) | Regex (`grep`, `sed`, `awk`, `semanage fcontext`) |
|---|---|---|
| Any string | `*` | `.*` |
| One character | `?` | `.` |
| Set | `[abc]` | `[abc]` |
| Negated set | `[!abc]` | `[^abc]` |
| Anchors | Whole name matched implicitly | `^` … `$` |
| `*` means | "anything" | "zero or more of the **previous** item" |

### 5.2 Exam traps **[RHCSA Core]**

```bash
find /etc -name *.conf          # ✘ the shell expands *.conf in the current dir first
                                #   → wrong results or "paths must precede expression"
find /etc -name '*.conf'        # ✔ quote patterns meant for the command
grep 'error.*disk' /var/log/messages     # regex, quoted
semanage fcontext -a -t httpd_sys_content_t '/web(/.*)?'   # REGEX, not a glob
tar -xzf a.tgz --wildcards '*.conf'      # glob handled by tar, quoted
```

### 5.3 Useful patterns

```bash
echo *                     # list names without ls (shell builtin; useful if ls is broken)
printf '%s\n' *            # one per line, handles spaces
ls -d .[!.]* ..?*          # hidden files without . and .. [Advanced]
cp -a src/. dest/          # copy a directory's contents INCLUDING hidden files
echo rm *.log              # preview what a destructive glob would do, then rerun without echo
rm -- *                    # protect against files named "-rf" etc.
shopt -s globstar; ls **/*.conf      # recursive match [Advanced]
shopt -s extglob; ls !(*.log)        # everything except *.log [Advanced]
```

## 6. Locale (`LANG`) and Pattern Matching

| Variable | Role | Precedence |
|---|---|---|
| `LC_ALL` | Overrides everything (use for one-off commands or scripts) | Highest |
| `LC_COLLATE`, `LC_TIME`, `LC_MESSAGES`, … | Individual categories | Middle |
| `LANG` | Default for all categories | Lowest |

```bash
echo $LANG; locale               # current settings
localectl                        # system default (/etc/locale.conf)
localectl list-locales | head    # installed locales
LC_ALL=C ls                      # byte-order sort (uppercase first), predictable
LANG=fr_FR.UTF-8 date            # French output only if glibc-langpack-fr is installed
sudo localectl set-locale LANG=en_US.UTF-8   # persistent system default
```

- **Bash 5.x (RHEL 10) enables `globasciiranges` by default.** `[a-z]` matches only lowercase ASCII letters in any locale, so the classic "`[a-z]` also matches uppercase in `en_US`" behavior no longer applies.
- What `LANG` still visibly changes is **sort order** (`ls`, `sort`), messages, and date/number formats.
- In scripts, set `LC_ALL=C` when you need predictable sorting and ranges.

> ⚠️ **Common misconception:** older material shows `[a-z]` matching `FileA`/`FileB` under some locales; that was older bash behavior. Today `LANG` visibly changes **sort order**, not range matching. And `LANG=fr_FR.UTF-8` needs `glibc-langpack-fr` installed.

## 7. Directory Stack (`pushd`/`popd`)

```bash
pushd /etc        # go to /etc, remember the previous directory
pushd /var/log    # stack: /var/log /etc ~
dirs -v           # show the numbered stack
popd              # back to /etc
cd -              # toggle between the last two directories (simpler)
```

## 8. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `find: paths must precede expression` | Unquoted glob expanded by the shell | Quote the pattern |
| `ls: cannot access '*.txt'` | No match, so the pattern was passed literally | Expected; or `shopt -s nullglob` in scripts |
| `Argument list too long` | Glob expanded to too many names | `find … -exec … {} +` or `xargs` |
| Hidden files not copied by `cp dir/* dest` | `*` skips dotfiles | `cp -a dir/. dest/` |
| Range matches unexpected names | Locale/collation differences (older shells) | POSIX classes or `LC_ALL=C` |
| `touch {1..$n}` creates a file literally named `{1..5}` | Brace expansion precedes variable expansion | `touch $(seq 1 "$n")` |

## 9. Interview Questions

| Question | Answer |
|---|---|
| Who expands `*.txt`, the shell or `ls`? | The shell; `ls` receives the expanded filenames. |
| Glob vs regex? | Globs match **filenames** (`*` = anything); regex matches **text** (`*` = repeat the previous item). |
| Why quote the pattern in `find -name '*.log'`? | So the shell doesn't expand it before `find` sees it. |
| Brace expansion vs globbing? | Braces generate strings regardless of files; globs match existing files only. |
| What happens if a glob matches nothing? | Bash passes it literally (unless `nullglob`/`failglob`). |
| How do you list files if `ls` is compromised? | `echo *` or `printf '%s\n' *` (shell builtins). |

## 10. Practice Exercises (with Solutions)

Setup: `touch test1 test10 test11 test2 Test2 Test3 test99 testXY testa Testa TestXYZ test\( "test 2"`

| # | Task | Command | Correct output |
|---|---|---|---|
| 3 | Start with `test` | `ls test*` | test1 test10 test11 test2 test99 testXY testa test( "test 2" ✔ |
| 4 | Start with `Test` | `ls Test*` | Test2 Test3 Testa TestXYZ ✔ |
| 5 | `test…` ending in a digit | `ls test*[0-9]` | test1 test10 test11 test2 test99 **"test 2"** |
| 6 | `test…` ending in a letter | `ls test*[a-zA-Z]` | testXY testa ✔ |
| 7–8 | `Test` + digit (+ nothing else) | `ls Test[0-9]*` / `ls Test[0-9]` | Test2 Test3 ✔ |
| 9 | Letter … digit | `ls [a-zA-Z]*[0-9]` | test1 test10 test11 test2 test99 Test2 Test3 **"test 2"** |
| 10 | Exactly five characters | `ls ?????` | test1 test2 Test2 Test3 **testa Testa test(** |
| 11 | Start `t`/`T`, end `3`/`a` | `ls [tT]*[3a]` | Test3 testa Testa ✔ |
| 12 | `t`, then `e` or `R`, … digit | `ls t[eR]*[0-9]` | test1 test10 test11 test2 test99 **"test 2"** |
| 13 | Not starting with `T` | `ls [!T]*` (or `[^T]*`) | all lowercase `test…` names ✔ |
| 14 | Copy `LANG` | `MyLANG=$LANG` (export only if children need it) | |
| 15 | `LANG` influence | `ls` vs `LC_ALL=C ls` | Different **sort order** (see §6) |
| 16 | List without `ls` | `echo *` | ✔ |
| 17 | Alternative to `cd` | `pushd`/`popd` | ✔ |

## 11. Quick Revision

```bash
Order: brace → tilde → $var $((…)) $(…) → word split → glob → quote removal
{a,b} {1..10} {01..10} file{,.bak}     * ? [abc] [a-z] [!x] [[:digit:]]
.* / dotglob   nullglob failglob nocaseglob globstar extglob   set -f
find -name '*.x' (QUOTE)   glob ≠ regex   LC_ALL > LC_* > LANG   LC_ALL=C
pushd popd dirs -v   cd -
```

## 12. Cross-References

- [Quoting & control operators](quoting-and-control-operators.md)
- [Variables (LANG, IFS)](shell-variables-and-environment.md)
- [Shell options (`set -f`, `shopt`)](command-substitution-and-shell-options.md)
- [grep & regular expressions](../files-and-text-processing/grep-and-regular-expressions.md)
- [Finding files (`find -name`)](../files-and-text-processing/finding-files.md)
- [SELinux `semanage fcontext` regex](../firewall-and-selinux/selinux-file-contexts.md#3-persistent-labeling-semanage-fcontext--restorecon-rhcsa-core)
