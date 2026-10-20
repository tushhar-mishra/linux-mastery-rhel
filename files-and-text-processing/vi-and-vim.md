# vi & vim

> **Sessions:** S20 · **Objective:** *Create and edit text files* **[RHCSA Core]**
> **Related:** [Viewing & creating files (heredoc/tee)](viewing-and-creating-file-contents.md) · [grep & regex (patterns in `:s`)](grep-and-regular-expressions.md) · [Variables (`EDITOR`)](../shell-and-command-line/shell-variables-and-environment.md)

## 1. Overview

`vi` is the editor guaranteed on every RHEL system, including minimal installs and rescue environments. On RHEL, `vi` comes from **vim-minimal**; **vim-enhanced** (`vim`) adds syntax highlighting and more, and includes `vimtutor`. Many admin tools open `$EDITOR`, which is usually vi/vim: `visudo`, `crontab -e`, `systemctl edit`, `vipw`, `vigr`, `git commit`.

```bash
vi file          # open or create
vim +25 file     # open at line 25
vimtutor         # 30-minute built-in tutorial (vim-enhanced) — highly recommended
sudo dnf install -y vim-enhanced
```

## 2. Modes

| Mode | Purpose | Enter with | Leave with |
|---|---|---|---|
| **Normal** | Navigate, delete, copy, paste | `Esc` | — |
| **Insert** | Type text | `i a I A o O` | `Esc` |
| **Command-line** | Save, quit, search/replace, ex commands | `:` `/` `?` | `Enter` / `Esc` |
| **Visual** | Select characters / lines / block | `v` / `V` / `Ctrl+v` | `Esc` |
| **Replace** | Overtype | `R` | `Esc` |

> ⚠️ **Course correction:** vi has more than three modes; Visual and Replace are used constantly.

## 3. Survival Kit **[RHCSA Core]**

| Task | Keys |
|---|---|
| Start typing | `i` (before cursor), `a` (after), `o` (new line below), `A` (end of line) |
| Stop typing | `Esc` |
| Save / quit / both | `:w` / `:q` / `:wq` |
| Save only if changed and quit | `:x` or `ZZ` |
| Quit **discarding** changes | `:q!` (or `ZQ`) |
| Revert to the saved version | `:e!` |
| Undo / redo | `u` / `Ctrl+r` |
| Go to line N / first / last | `:N` or `NG` / `gg` / `G` |
| Search | `/text` then `n` / `N` |
| Replace everywhere | `:%s/old/new/g` |
| Line numbers | `:set nu` / `:set nonu` |

> ⚠️ **Course correction:** `:x` isn't exactly `:wq`. `:x` writes **only if the buffer changed**, so it preserves the file's timestamp when nothing changed.

## 4. Navigation

| Keys | Move |
|---|---|
| `h j k l` | Left, down, up, right |
| `w` / `b` / `e` | Next word / previous word / end of word |
| `0` / `^` / `$` | Line start / first non-blank / line end |
| `gg` / `G` / `:N` | File start / end / line N |
| `Ctrl+f` / `Ctrl+b` | Page down / up |
| `%` | Jump to matching bracket |
| `*` / `#` | Search the word under the cursor forward / backward |

Counts multiply most commands: `5j`, `3w`, `10G`.

## 5. Editing

| Keys | Action |
|---|---|
| `x` / `r<c>` | Delete character / replace one character |
| `dd` / `3dd` / `dw` / `D` | Delete line / 3 lines / word / to end of line |
| `cw` / `cc` / `C` | Change word / line / to end of line (enters Insert) |
| `yy` / `5yy` / `yw` | Yank (copy) line / 5 lines / word |
| `p` / `P` | Paste after / before |
| `J` | Join the next line onto this one |
| `.` | Repeat the last change |
| `>>` / `<<` | Indent / unindent the line |
| `~` | Toggle case |

**Visual block editing** (comment out several lines): `Ctrl+v`, move down to select, `I#`, then `Esc`.

## 6. Search & Replace

```
/pattern          search forward  (n next, N previous)
?pattern          search backward
:s/old/new/       first match on the current line
:s/old/new/g      all matches on the current line
:%s/old/new/g     whole file
:%s/old/new/gc    whole file, confirm each
:%s/old/new/gi    whole file, ignore case
:10,20s/a/b/g     lines 10–20
:%s/\<hello\>/Hi/g        whole word only
:%s#/old/path#/new/path#g # another delimiter avoids escaping slashes
:set ic / :set noic       ignore case in searches
:set hlsearch / :noh      highlight / clear highlight
```

## 7. Ex (`:`) Commands

| Command | Action |
|---|---|
| `:5d` / `:5,10d` | Delete line 5 / lines 5–10 |
| `:3t7` (or `:3co7`) | Copy line 3 to after line 7 |
| `:3m7` | Move line 3 to after line 7 |
| `:g/^$/d` | Delete blank lines |
| `:g/pattern/d` / `:v/pattern/d` | Delete matching / non-matching lines |
| `:r file` / `:r !cmd` | Insert a file / a command's output |
| `:w newfile` / `:10,20w part.txt` | Save as / save a line range |
| `:w!` / `:wq!` | Force a write (e.g. a read-only file you own, or as root) |
| `:!cmd` | Run a shell command |
| `:set list` | Show tabs (`^I`) and line ends (`$`) |
| `:set paste` | Paste without auto-indent "staircasing" (then `:set nopaste`) |

## 8. Registers ("buffers") **[Advanced]**

| Register | Content |
|---|---|
| `"a`–`"z` | Named. `"ayy` yank into a, `"ap` paste from a; **uppercase appends** (`"Ayy`) |
| `"0` | Last yank |
| `"1`–`"9` | Recent line-wise deletes (shifted on each delete) |
| `"-` | Last small (within-line) delete |
| `".` `":` `"/` | Last inserted text / last command / last search |
| `"+` `"*` | System clipboard. **Only in clipboard-enabled builds** (not typical on RHEL servers) |

```
:reg          list all registers
:reg ab       only registers a and b
```

> ⚠️ **Course correction:** vim calls these **registers**; in vim, a "buffer" is an open file.

## 9. Configuration (`~/.vimrc`)

```vim
set number
syntax on
set tabstop=4 shiftwidth=4 expandtab   " spaces instead of tabs (good for YAML)
set hlsearch incsearch ignorecase smartcase
```

## 10. Swap Files & Recovery

vim keeps unsaved changes in `.file.swp` next to the file. Opening a file that has a swap file shows **`E325: ATTENTION`**. Two causes:

1. **A previous session crashed:** press `R` to recover, then save, then delete the swap file.
2. **Someone (or another of your terminals) is editing it now:** press `Q`/`A` and don't edit concurrently.

```bash
vim -r file          # recover from swap
ls -a | grep swp     # find leftover swap files; delete only once recovered
```

## 11. RHCSA Exam Focus

- Fast config edits: `vi /etc/fstab` → `o` new line → type → `Esc` → `:wq` → **validate** (`findmnt --verify`, `mount -a`).
- Use `visudo` (not vi) for `/etc/sudoers`; it checks syntax before saving.
- If anything goes wrong mid-edit: `Esc`, then `:q!`, and start again. Nothing is written until you save.
- `nano` may not be installed on exam systems; be fluent in vi.

## 12. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Typed text runs as commands | Not in Insert mode | `Esc`, `u` to undo, then `i` |
| "Stuck", can't quit | Wrong mode or pending command | `Esc Esc` then `:q!` |
| `E45: 'readonly' option is set` | No write permission or read-only open | `:w!` if you own the file; otherwise reopen with `sudo` (or `:w !sudo tee %` **[Advanced]**) |
| `E212: Can't open file for writing` | Directory missing or no permission | Check the path; use `sudo` |
| `E325: ATTENTION` | Existing swap file | See §10 |
| Pasted text indents like stairs | Auto-indent during paste | `:set paste` before pasting |
| Screen froze | `Ctrl+s` (XOFF) | `Ctrl+q` |

## 13. Course Practical Challenge (solutions)

| Step | Keys |
|---|---|
| Create a 10-line file | `vi ten.txt` → `i` → type 10 lines → `Esc` |
| Delete line 5 | `:5d` |
| Copy line 3 to after line 7 | `:3t7` |
| Replace "hello" with "Hi" everywhere | `:%s/hello/Hi/g` |
| Save and exit | `:wq` |

## 14. Quick Revision

```
i a o A I O | Esc | :w :q :wq :x ZZ :q! :e! | u Ctrl+r | gg G :N | / ? n N
dd yy p P x r cw dw D J . >> | v V Ctrl+v | :%s/a/b/gc | :g/^$/d | :3t7 :3m7
:set nu list paste ic hlsearch | "ayy "ap :reg | vim -r (swap) | visudo for sudoers
```

## 15. Cross-References

- [Viewing & creating files](viewing-and-creating-file-contents.md)
- [grep & regular expressions](grep-and-regular-expressions.md)
- [Variables (`EDITOR`)](../shell-and-command-line/shell-variables-and-environment.md)
- sudo/`visudo` (S27), fstab (S33–34), cron (S54): planned
