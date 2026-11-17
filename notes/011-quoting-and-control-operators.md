# 011 · Quoting, Aliases and Control Operators

> **You need first:** [010 · vi and vim](010-vi-and-vim.md)
> **Next:** [012 · Variables and environment](012-variables-and-environment.md)

---

## What it is

Before bash runs anything, it cuts your line into **words** (the command and its arguments). Three things control how it does that, and what runs when:

- **Quoting**: tells bash "keep this text together" or "don't touch special characters here". The tools are `'single quotes'`, `"double quotes"` and the backslash `\`.
- **Aliases**: short nicknames for longer commands (`ll` = `ls -l`).
- **Control operators**: symbols between commands that decide **whether** and **when** the next command runs: `;` `&&` `||` `&` `|` `( )` `{ }`.

One word you need now: a **variable** is a named value the shell stores, like `name=alice`. You read it back with `$name`. Topic 012 covers variables fully.

## Why it exists

Spaces separate arguments, and characters like `$ * ! # & |` have special meanings. Without quoting, you couldn't pass a file called `my report.txt` or the text `$5`. Control operators let you say "only continue if the previous step worked", which is how safe automation is built.

Most "mysterious" shell errors (files not found, wrong arguments, scripts acting strangely) are quoting problems.

## Analogy

Quoting is like **packaging for shipping**:
- **No quotes**: loose items. The shell may split them up, unpack shortcuts (`*`, `$var`) and rearrange them.
- **Double quotes**: a box with a **window**. Items stay together as one piece, but the shell can still read the `$labels` through the window and fill them in.
- **Single quotes**: a **sealed box**. Nothing inside is touched or read, exactly as written.
- **Backslash**: a single item with a "fragile, don't touch" sticker.

Control operators are **traffic rules**: `;` = "drive on regardless", `&&` = "go only if green", `||` = "go only if red".

## How it works inside

### Word splitting

Unquoted spaces, tabs and newlines separate arguments, and several spaces in a row count as one. You can **see** how bash split a line with `printf '[%s]\n'`. It prints each argument inside brackets on its own line:

```bash
printf '[%s]\n' document 55.txt "notes 21.txt"
```
```
[document]
[55.txt]
[notes 21.txt]
```
Three arguments. The unquoted `document 55.txt` became two; the quoted one stayed whole.

### Quoting rules

| Form | `$var` and `$(cmd)` replaced? | `*` wildcards expanded? | Notes |
|---|---|---|---|
| Unquoted | Yes, then **split on spaces** | Yes | Spaces separate arguments |
| `"double"` | Yes, but **no splitting** | No | Inside, `\` only escapes `$`, a backquote, `"`, `\`. `!` still triggers history in interactive shells |
| `'single'` | No | No | Completely literal. Can't contain a `'` |
| `\c` | — | — | Makes one character literal |
| `$'text'` | No variables, but `\n` `\t` `\'` work | No | `echo $'a\tb'` prints a tab |

**Rule of thumb:** always write `"$var"` (double-quoted) unless you have a reason not to.

### The `!` trap

In an interactive shell, `!` triggers **history expansion** (topic 015): `!!` means "the previous command". This happens **even inside double quotes**. Use single quotes or `\!`. Scripts are not affected.

### How bash finds what to run (recap from topic 004)

alias → keyword → function → builtin → program in PATH. So the builtin `printf` wins over `/usr/bin/printf`. To skip an alias, write `\ls` or `command ls`.

### Aliases

An alias is a **text replacement for the first word** of a command. It works only in **interactive** shells; scripts ignore aliases. It can't take arguments in the middle. For anything with arguments or logic, use a **function** instead (a named group of commands, shown below and in topic 040).

### Control operators

| Operator | Meaning | Example |
|---|---|---|
| `;` or newline | Run one after the other, whatever happens | `cd /tmp; ls` |
| `&&` | Run the next **only if** the previous succeeded (exit 0) | `mkdir d && cd d` |
| `\|\|` | Run the next **only if** the previous failed | `mkdir d \|\| echo "already exists"` |
| `&` | Start in the **background**; get the prompt back at once | `sleep 60 &` |
| `\|` | **Pipe**: the output of the left side becomes the input of the right side (topic 016) | `ls -l \| less` |
| `!` | Flip success and failure | `! grep -q root /etc/passwd` |
| `( … )` | Run inside a **subshell**, a copy of the shell, so changes (like `cd`) don't affect you | `(cd /etc; ls)` |
| `{ …; }` | Group in the **current** shell. Needs spaces and the final `;` | `{ date; uptime; } > report.txt` |
| `#` | Comment, but only at the **start of a word** | `echo a#b` → `a#b`; `echo a #b` → `a` |
| `\` at end of line | Continue on the next line. It must be the **very last** character | |

### `a && b || c` is NOT if/else

`c` runs if **a** fails **or if b fails**:

```bash
true && false || echo "this runs!"
```
For a real if/else, use `if a; then b; else c; fi` (topic 042).

## Commands

```bash
name=alice
echo "Hello $name"          # Hello alice      (double quotes: variable replaced)
echo 'Hello $name'          # Hello $name      (single quotes: literal)
echo "Price: \$5"           # Price: $5        (\ protects $)
echo "She said \"hi\""      # She said "hi"
echo 'It'\''s fine'         # It's fine        (close quote, escaped ', reopen)
echo a    b                 # a b              (unquoted spaces collapse)
echo "a    b"               # a    b           (quoted spaces kept)
```

```bash
echo "Done!!"
```
```
echo "Doneecho 'Hello $name'"
Doneecho 'Hello $name'
```
- `!!` was replaced by your previous command, even inside double quotes. Fix: `echo 'Done!!'`.

### echo vs printf

```bash
echo -e "a\tb\nc"
printf '%s\n' one two three
printf 'User: %s  UID: %d\n' alice 1000
```
```
a	b
c
one
two
three
User: alice  UID: 1000
```
- `echo` always adds a newline at the end (`-n` removes it) and only understands `\t` `\n` with `-e`.
- `printf` uses a **format string**: `%s` = a string, `%d` = a whole number, `\n` = newline. It reuses the format for extra arguments. It behaves the same on every system, so prefer it in scripts.

### Aliases

```bash
alias
```
```
alias egrep='grep -E --color=auto'
alias fgrep='grep -F --color=auto'
alias grep='grep --color=auto'
alias l.='ls -d .* --color=auto'
alias ll='ls -l --color=auto'
alias ls='ls --color=auto'
alias which='(alias; declare -f) | /usr/bin/which --tty-only --read-alias --read-functions --show-tilde --show-dot'
alias xzegrep='xzegrep --color=auto'
...
alias zgrep='zgrep --color=auto'
```
- The aliases RHEL sets up. As root you'd also see `rm='rm -i'`, `cp='cp -i'`, `mv='mv -i'`.

```bash
alias k='kubectl'          # define for this shell only
unalias k                  # remove it
\rm file                   # bypass the rm alias once
```
To keep an alias, add it to `~/.bashrc` (topic 025).

A function that takes an argument:
```bash
mkcd() { mkdir -p -- "$1" && cd -- "$1"; }
mkcd /tmp/newproject ; pwd
```
```
/tmp/newproject
```
- `$1` is the first argument given to the function (topic 041).

### Control operators in action

```bash
mkdir /tmp/demo && cd /tmp/demo && echo "ready in $(pwd)"
```
```
ready in /tmp/demo
```
- Each step runs only if the one before it worked. `$(pwd)` inserts the output of `pwd` (topic 014).

```bash
ls /nonexistent || echo "listing failed with code $?"
```
```
ls: cannot access '/nonexistent': No such file or directory
listing failed with code 2
```

```bash
(cd /etc && pwd) ; pwd
```
```
/etc
/tmp/demo
```
- The `cd` happened inside a subshell, so your own shell stayed where it was.

```bash
{ echo "== $(hostname) =="; uptime; df -h /; } > report.txt
```
- Three commands, one output file.

```bash
sleep 30 &
```
```
[1] 4821
```
- `[1]` is the **job number** and `4821` the **PID** (process ID). `jobs` lists background jobs, `fg %1` brings one back, and `$!` holds the last background PID. Topic 033 covers job control.

```bash
cmd || { echo "cmd failed" >&2; exit 1; }
```
- The standard "fail loudly" pattern in scripts. `>&2` sends the message to the error stream (topic 016).

### Try it
1. `touch "my file.txt"` then try `ls my file.txt` vs `ls "my file.txt"`. Explain the error.
2. `printf '[%s]\n' $HOME "$HOME" '$HOME'`. Why is the third one different?
3. Run `false && echo A || echo B` and `true && false || echo C`. Predict the output first.
4. Make an alias `ports='ss -tlnp'`, use it, then open a new terminal and see that it's gone.

**Check your work:** on your lab VM, from the notes folder, run `sudo ./checks/check 011` for every step, or `sudo ./checks/check 011 STEP` for one (topic 002 shows how to get the notes there).

## Where you'll use it

- **Every script:** `"$var"` everywhere. An unquoted variable with a space inside is a classic production bug (for example, deleting the wrong path).
- **One-liners in runbooks:** `systemctl restart app && curl -fsS localhost:8080/health || echo "health check failed"`.
- **CI pipelines and Dockerfiles** chain commands with `&&`, so the build stops at the first failure: `RUN dnf -y install x && dnf clean all`.
- **YAML and JSON in shell:** passing JSON to `curl -d '{"a":1}'` needs single quotes, so the `"` survive.
- **kubectl and SSH:** `ssh host 'echo $HOSTNAME'` (single quotes: expanded on the *remote* host) vs `ssh host "echo $HOSTNAME"` (double quotes: expanded *locally* first). A frequent surprise.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `bash: !…: event not found` | `!` triggered history expansion | Single quotes, `\!`, or `set +H` |
| `No such file or directory` for a name with spaces | Unquoted, so split into two words | Quote it |
| A `>` prompt appears and waits | Unclosed quote or brace, or a trailing `\` | Finish the command, or press Ctrl+C |
| Alias works by hand but not in a script | Scripts don't expand aliases | Use a function or the full command |
| Line continuation fails | A space after the `\` | Remove trailing whitespace |
| "else" part runs when it shouldn't | `a && b \|\| c` and `b` failed | Use `if … then … else … fi` |
| Remote command uses your local value | Double quotes expanded it locally | Use single quotes for remote commands |

## Quick recap

- Unquoted text is split on spaces and expanded. `"double"` keeps it as one word but expands `$var`. `'single'` is fully literal. `\` protects one character.
- Always quote variables: `"$var"`. Debug splitting with `printf '[%s]\n' …`.
- `;` always, `&&` on success, `||` on failure, `&` background, `( )` subshell, `{ ;}` current shell.
- `a && b || c` is not if/else. Aliases are interactive-only; use functions in scripts.

**Interview questions**

1. *Single vs double quotes?* Single quotes make everything literal. Double quotes keep the text as one argument but still expand `$variables`, `$(commands)` and backslash escapes.
2. *Is `a && b || c` the same as if/else?* No. `c` also runs if `b` fails. Use a real `if` statement.
3. *`( )` vs `{ }`?* `( )` runs the commands in a subshell, so changes like `cd` or variables don't persist. `{ }` runs them in the current shell.

**Scenario question** (answer out loud first, then compare)

> *"A cleanup script runs `rm -rf $DIR/*`. One night it wiped far more than intended. What are the likely causes, and how should the line be written?"*

**Model answer:**
1. If `DIR` was **empty or unset**, the line became `rm -rf /*`.
2. If `DIR` contained a **space** (`/data/old logs`), the unquoted value split into two arguments, `/data/old` and `logs/*`, and both were deleted.
3. Safe version: `rm -rf -- "${DIR:?DIR is not set}"/*`.
   - Quotes stop word splitting.
   - `${DIR:?}` makes the script stop with an error if DIR is empty.
   - `--` stops a name starting with `-` being read as an option.
4. Also `set -u` in the script, and an `echo` dry run of risky globs while testing.

**Likely follow-ups:**
- *Is `cd "$DIR" && rm -rf *` safer?* Better than the original, because `&&` skips the `rm` if `cd` fails. With `cd "$DIR"; rm -rf *` (a `;`), a failed `cd` deletes the current directory's contents instead.
- *Why are aliases not used in scripts?* Non-interactive shells don't expand aliases by default. Use functions.
