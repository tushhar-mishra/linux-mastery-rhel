# I/O Redirection & Pipes

> **Sessions:** S16 · **Objective:** *Use input-output redirection (>, >>, |, 2>, etc.)* **[RHCSA Core]**
> **Related:** [Viewing & creating files (heredoc, tee)](viewing-and-creating-file-contents.md) · [Text filters](text-filters.md) · [Quoting & control operators](../shell-and-command-line/quoting-and-control-operators.md) · [Shell options (noclobber, pipefail)](../shell-and-command-line/command-substitution-and-shell-options.md)

## 1. Overview

Every process starts with three open **file descriptors**:

| FD | Name | Default |
|---|---|---|
| 0 | stdin | Keyboard |
| 1 | stdout | Terminal |
| 2 | stderr | Terminal |

The **shell** sets up redirections *before* the command runs, so the command never sees `>` or `2>`. It just finds its FDs already pointing at files. Separating stdout from stderr is what makes clean logs, quiet `find` searches and reliable scripts possible.

## 2. Operators **[RHCSA Core]**

| Operator | Effect | Example |
|---|---|---|
| `> file` | stdout → file (**truncate** first) | `ls /etc > list.txt` |
| `>> file` | stdout → file (append) | `echo line >> notes.txt` |
| `2> file` / `2>> file` | stderr → file (truncate / append) | `find / -name x 2> err.log` |
| `> file 2>&1` | stdout **and** stderr → file (POSIX) | `cmd > all.log 2>&1` |
| `&> file` / `&>> file` | Same, bash shorthand | `ping -c1 host &> net.log` |
| `2>&1` | stderr → wherever stdout points **right now** | |
| `>&2` | stdout → stderr (script error messages) | `echo "error" >&2` |
| `2>/dev/null` | Discard errors | `find / -name passwd 2>/dev/null` |
| `>/dev/null 2>&1` | Discard everything | `cmd >/dev/null 2>&1` |
| `< file` | stdin ← file | `tr 'a-z' 'A-Z' < f` |
| `<< DELIM` | Heredoc (multi-line stdin) | see [heredocs](viewing-and-creating-file-contents.md#33-heredocs-rhcsa-core-technique) |
| `<<< "text"` | Here-string (one-line stdin) | `grep Linux <<< "I love Linux"` |
| `>\| file` | Overwrite even with `noclobber` set | `echo x >\| f` |
| `cmd1 \| cmd2` | stdout of cmd1 → stdin of cmd2 | `ls -l \| less` |
| `cmd1 \|& cmd2` | stdout **and** stderr into the pipe (= `2>&1 \|`) | `rm ghost 2>&1 \| grep ghost` |

### 2.1 Order matters

Redirections are processed **left to right**:

`````````bash
ls /etc /nope > out.txt 2>&1   # 1→out.txt, then 2→(where 1 points)=out.txt  ✔ both in file
ls /etc /nope 2>&1 > out.txt   # 2→terminal (where 1 pointed), then 1→out.txt ✘ errors on screen
`````````

### 2.2 Truncation happens before the command runs

`````````bash
echo "Welcome" > example.txt
fakecmd > example.txt     # bash: fakecmd: command not found … and example.txt is now EMPTY
sort data.txt > data.txt  # ✘ empty result: the shell truncated data.txt before sort read it
sort data.txt -o data.txt # ✔ sort can safely write to its input with -o
`````````

Protect interactive work with `set -o noclobber` (`set -C`); `>|` deliberately overrides it.

### 2.3 Placement is flexible (readability isn't)

`````````bash
cat file.txt > result.txt 2> error.txt     # conventional, preferred
2> error.txt cat file.txt > result.txt     # valid
< file.txt > result.txt 2> error.txt cat   # valid, but hard to read
`````````

## 3. Pipes **[RHCSA Core]**

- A pipe connects **stdout only**; stderr still goes to the terminal: `rm ghost.txt | grep ghost` shows nothing on the grep side. Use `2>&1 |` or `|&`.
- All commands in a pipeline run **concurrently**, and data streams through without temporary files.
- The pipeline's exit status is the **last** command's. Use `set -o pipefail` (scripts) to fail if any stage fails; `${PIPESTATUS[@]}` lists every stage's status **[Advanced]**.

### 3.1 `tee`: split the stream

`````````bash
ls -l /etc | tee listing.txt | wc -l          # save AND keep processing
dnf -y update 2>&1 | tee -a /root/update.log  # watch live and keep a log
echo "10.0.0.5 web1" | sudo tee -a /etc/hosts # write a root-owned file (sudo + > fails)
`````````

## 4. Input Redirection

`````````bash
wc -l < /etc/passwd          # 42  (number only: wc doesn't see a filename)
tr 'aeiou' 'AEIOU' < msg.txt # tr ONLY reads stdin, so redirection is required
mail -s "report" root < report.txt   # [if mailx installed]
grep "Linux" <<< "I love Linux"      # here-string
`````````

## 5. Clearing Files Safely

`````````bash
> app.log                 # truncate to 0 bytes (>| app.log under noclobber)
: > app.log               # same, more explicit
truncate -s 0 app.log     # same, via coreutils
`````````

> ⚠️ **Truncate, don't delete, logs that a running process holds open.** `rm` removes only the name; the process keeps writing to the deleted inode and **disk space isn't freed** until it restarts. Find these files with `lsof +L1` (see the [filesystem note](../linux-fundamentals/filesystem-hierarchy.md#7-troubleshooting-production-practice)).

## 6. RHCSA Exam Focus

- "Save the output to `/root/x.txt`": use `>` (or `>>` if the task says append), then **verify with `cat`**.
- Silence permission noise in searches: `find / -user alice 2>/dev/null`.
- To capture errors too, put `2>&1` **after** `> file`.
- Writing system files: use `sudo tee` or a root shell. `sudo echo … > /etc/x` fails.

## 7. Production Practices **[Production Practice]**

- Cron and script jobs: `/usr/local/bin/job.sh >> /var/log/job.log 2>&1`, or send output to the journal with `systemd-cat`/`logger`.
- Error messages in scripts go to stderr: `echo "ERROR: disk full" >&2`.
- Use `set -o pipefail` in scripts that pipe critical commands.
- `exec >>/var/log/script.log 2>&1` at the top of a script redirects everything after it **[Advanced]**.

## 8. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Errors still print after `> file` | They're stderr | Add `2>&1` (after `> file`) or `2> err` |
| `2>&1 > file` doesn't capture errors | Wrong order | `> file 2>&1` |
| Output file empty | Truncated by `>` before the command (same file as input, or the command failed) | Temp file + `mv`, or `sort -o` |
| `cannot overwrite existing file` | `noclobber` on | `>\|` or `set +C` |
| `Permission denied` with `sudo cmd > /etc/x` | Your shell does the redirection | `cmd \| sudo tee /etc/x` |
| `grep` after a pipe never sees errors | Pipe carries stdout only | `2>&1 \|` or `\|&` |
| Disk full persists after `rm` of a log | File still open | Restart the service, or truncate instead; `lsof +L1` |

## 9. Interview Questions

| Question | Answer |
|---|---|
| What are FDs 0, 1 and 2? | stdin, stdout, stderr. |
| `cmd > f 2>&1` vs `cmd 2>&1 > f`? | First: both to `f`. Second: stderr to the terminal (stdout's old target), stdout to `f`. |
| Why does `sort f > f` empty the file? | The shell truncates `f` before `sort` starts reading. |
| Does a pipe carry stderr? | No. Use `2>&1 \|` or `\|&`. |
| What is `/dev/null`? | A character device that discards writes and returns EOF on reads. |
| How do you write a root-owned file from a non-root shell? | `… \| sudo tee [-a] /path`. |
| Why didn't deleting a big log free space? | The process still holds it open. Truncate it or restart the process. |

## 10. Course Practice (corrected where needed)

| # | Task | Command / note |
|---|---|---|
| 1 | Enable noclobber | `set -o noclobber` |
| 2 | Verify | First `ls /etc > testfile.txt` works **only if the file doesn't exist yet**; repeating it fails |
| 3 | Check its state | `set -o \| grep noclobber` (and `C` appears in `echo $-`) |
| 4 | Disable | `set +o noclobber` |
| 5 | Watch a file grow | Shell 1: `touch /tmp/watch.log; tail -F /tmp/watch.log` · Shell 2: `echo "started $(date)" >> /tmp/watch.log` |
| 6 | Heredoc file | `cat << END > animals.txt` … `END` |

> ⚠️ **Course correction:** `cat < message.txt` is described as "same as `cat input.txt`"; it's the same as `cat message.txt`. Note too that with `<` the *shell* opens the file, so `cat` never sees its name.

## 11. Quick Revision

`````````bash
> >> 2> 2>> &> &>> 2>&1 >&2 < << <<< >| | |&    /dev/null
cmd > f 2>&1 (both)   cmd 2>/dev/null (quiet)   cmd | tee [-a] f   cmd | sudo tee f
set -C / >|   set -o pipefail   sort -o f f   : > log (truncate)   lsof +L1
`````````

---
