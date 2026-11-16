# 010 · vi and vim: Editing Files in the Terminal

> **You need first:** [009 · Viewing files](009-viewing-files.md)
> **Next:** [011 · Quoting and control operators](011-quoting-and-control-operators.md)

---

## What it is

**vi** (from "visual") is a text editor that runs inside the terminal. **vim** ("vi improved") is the modern version, with colours, multi-level undo and more. On RHEL, plain `vi` comes from the small package `vim-minimal`. The full `vim` comes from `vim-enhanced`, which also gives you `vimtutor`, a 30-minute built-in lesson.

vi is **modal**: the same key does different things depending on the **mode** you are in. This is the one idea that confuses everyone at first.

**nano** is a simpler editor that may or may not be installed. Ubuntu installs it by default, and makes it the default editor for some tools.

## Why it exists

vi is on **every** Linux and UNIX system: minimal servers, rescue environments, containers with an emergency shell, network devices. When a server is broken and you need to fix one line in `/etc/fstab`, vi is what you'll have. Many admin tools also open it automatically: `visudo`, `crontab -e`, `systemctl edit`, `git commit` and `kubectl edit`.

Modes make it fast once learned: your hands never leave the keyboard, and short key combinations do big edits.

## Analogy

vi is a **pen with a cap**.
- **Normal mode** = cap on. You can point at, move, cut and copy words, but you can't write.
- **Insert mode** = cap off. Now every key writes text.
- **Esc** = put the cap back on.

Most beginner problems come from typing text with the cap on (the letters run as commands) or trying to move around with the cap off.

## How it works inside

### Modes

| Mode | What it's for | Enter with | Leave with |
|---|---|---|---|
| **Normal** (the default) | Move, delete, copy, paste | `Esc` | — |
| **Insert** | Type text | `i` `a` `o` `I` `A` `O` | `Esc` |
| **Command-line** | Save, quit, search, replace | `:` `/` `?` | Enter or `Esc` |
| **Visual** | Select text | `v` (characters), `V` (lines), `Ctrl+v` (a block) | `Esc` |
| **Replace** | Type over existing text | `R` | `Esc` |

vim shows `-- INSERT --` or `-- VISUAL --` at the bottom so you know where you are.

### Where your edits live

When you open a file, vim copies it into memory (a **buffer**). Your changes touch only that copy. **Nothing is written to disk until you save** (`:w`). That's why `:q!` (quit without saving) is a perfect "undo everything" escape.

While you edit, vim also writes your unsaved changes to a hidden **swap file** (`.filename.swp`) next to the file. If your SSH connection drops or the machine crashes, the swap file lets you recover. Opening a file that already has a swap file shows the warning **`E325: ATTENTION`**.

### Command grammar: operator + motion

Normal-mode commands combine like words: **operator** + **motion**, with an optional **count**.

- `d` (delete) + `w` (word) = `dw`, delete a word.
- `3dd` = delete 3 lines.
- `y` (yank = copy) + `$` (to end of line) = `y$`.
- `c` (change) + `w` = delete a word and start typing.
- `.` repeats the last change.

## Commands

```bash
vi /etc/hosts            # open (or create) a file
vim +25 app.conf         # open at line 25
sudo vi /etc/fstab       # system files need root
vimtutor                 # the built-in lesson (needs vim-enhanced)
```

### Survival kit (learn these first)

| Task | Keys |
|---|---|
| Start typing | `i` (before cursor), `a` (after), `o` (new line below), `O` (new line above), `A` (end of line), `I` (start of line) |
| Stop typing | `Esc` |
| Save | `:w` |
| Quit | `:q` |
| Save and quit | `:wq`, or `:x` / `ZZ` (write only if something changed) |
| Quit **without saving** | `:q!` |
| Throw away changes, reload the file | `:e!` |
| Undo / redo | `u` / `Ctrl+r` |
| Go to line N / first line / last line | `:N` (or `NG`) / `gg` / `G` |
| Search | `/text` then `n` (next) / `N` (previous) |
| Replace everywhere | `:%s/old/new/g` |
| Show line numbers | `:set nu` (hide: `:set nonu`) |

**Panic button:** press `Esc` twice, type `:q!`, press Enter. You're out, and nothing was changed.

### Moving

| Keys | Move |
|---|---|
| `h` `j` `k` `l` | Left, down, up, right (arrow keys also work) |
| `w` / `b` / `e` | Next word / previous word / end of word |
| `0` / `^` / `$` | Start of line / first non-blank / end of line |
| `gg` / `G` / `:N` | Top / bottom / line N |
| `Ctrl+f` / `Ctrl+b` | Page down / page up |
| `%` | Jump to the matching bracket |
| `*` / `#` | Search for the word under the cursor, forward / backward |

Numbers multiply commands: `5j` goes down 5 lines; `10G` goes to line 10.

### Editing

| Keys | Action |
|---|---|
| `x` | Delete one character |
| `r<c>` | Replace one character with `<c>` |
| `dd` / `3dd` / `dw` / `D` | Delete a line / 3 lines / a word / to end of line |
| `cw` / `cc` / `C` | Change a word / line / to end of line (enters Insert mode) |
| `yy` / `5yy` / `yw` | Copy ("yank") a line / 5 lines / a word |
| `p` / `P` | Paste after / before the cursor |
| `J` | Join the next line onto this one |
| `.` | Repeat the last change |
| `>>` / `<<` | Indent / un-indent the line |
| `~` | Swap upper/lower case |

**Comment out several lines:** `Ctrl+v`, move down to select a column, type `I#`, then press `Esc`. The `#` appears on every selected line.

### Search and replace

```
/pattern            search forward  (n = next, N = previous)
?pattern            search backward
:s/old/new/         first match on this line
:s/old/new/g        every match on this line  (g = global)
:%s/old/new/g       every match in the whole file  (% = all lines)
:%s/old/new/gc      same, but ask to confirm each one  (c = confirm)
:%s/old/new/gi      ignore upper/lower case
:10,20s/a/b/g       only on lines 10 to 20
:%s/\<cat\>/dog/g   whole word "cat" only (not "category")
:%s#/old/path#/new/path#g   use # as the separator, so you don't need to escape the slashes
:noh                clear search highlighting
```

Patterns here are **regular expressions** (topic 017). For simple words, they work as you'd expect.

### Command-line (`:`) power tools

| Command | Action |
|---|---|
| `:5d` / `:5,10d` | Delete line 5 / lines 5–10 |
| `:3t7` | Copy line 3 to after line 7 |
| `:3m7` | Move line 3 to after line 7 |
| `:g/^$/d` | Delete all blank lines |
| `:g/pattern/d` / `:v/pattern/d` | Delete matching / non-matching lines |
| `:r file` / `:r !cmd` | Insert another file / the output of a command |
| `:w newname` | Save a copy under another name |
| `:w!` | Force a write (a read-only file you own, or as root) |
| `:!cmd` | Run a shell command without leaving vim |
| `:set list` | Show tabs (`^I`) and line ends (`$`) |
| `:set paste` | Paste from your clipboard without auto-indent "staircasing" (`:set nopaste` afterwards) |

### Registers (named clipboards)

`"ayy` copies a line into register **a**; `"ap` pastes it. `:reg` lists all registers. `"0` holds the last copy, and `"1`–`"9` hold recent deletes. (In vim, "buffer" means an open file; the clipboards are called **registers**.)

### Settings file

```vim
" ~/.vimrc   (lines starting with " are comments)
set number
syntax on
set tabstop=2 shiftwidth=2 expandtab   " spaces instead of tabs: essential for YAML
set hlsearch incsearch ignorecase smartcase
```

YAML files (Kubernetes manifests, Ansible playbooks, CI configs) **break if they contain tabs**. `expandtab` makes the Tab key insert spaces.

### Recovering from a crash

```
E325: ATTENTION
Found a swap file by the name ".app.conf.swp"
...
[O]pen Read-Only, (E)dit anyway, (R)ecover, (D)elete it, (Q)uit, (A)bort:
```
- If your **previous session crashed**: press `R` to recover, save with `:w`, then delete the swap file (`D` next time, or `rm .app.conf.swp`).
- If **someone else is editing it right now** (check with `w`, topic 003): press `Q` and coordinate. Two people saving the same file means one person's changes are lost.

### Try it
1. `cp /etc/services ~/svc.txt` then `vi ~/svc.txt`. Go to the last line (`G`), then the first (`gg`), then line 100 (`:100`).
2. Search `/ssh`, press `n` a few times. Replace every `tcp` with `TCP` on lines 1–50: `:1,50s/tcp/TCP/g`.
3. Delete 3 lines (`3dd`), undo (`u`), redo (`Ctrl+r`).
4. Quit **without** saving (`:q!`) and confirm the file is unchanged.
5. Run `vimtutor` once all the way through.

## Where you'll use it

- **Emergency edits** on broken servers: a bad line in `/etc/fstab`, `/etc/hosts` or a service config.
- **Tools that open an editor for you:** `visudo` (always use it for sudo rules, topic 028), `crontab -e` (topic 039), `systemctl edit` (topic 037), `kubectl edit`, `git commit`. They use the `EDITOR` variable (topic 012). Set `export EDITOR=vim` (or `nano`).
- **Inside containers** with only `vi` available (often busybox `vi`, a minimal version).
- **After every config edit, validate before reloading:** `sshd -t`, `nginx -t`, `visudo -c`, `findmnt --verify`. A typo found by a validator is a non-event; a typo found by a restart is an outage.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| Your text runs as commands; things get deleted | You were in Normal mode | `Esc`, then `u` a few times, then `i` |
| "Can't get out" | Wrong mode or a half-typed command | `Esc Esc` then `:q!` |
| `E45: 'readonly' option is set` | No write permission, or opened read-only | `:w!` if you own it; otherwise quit and reopen with `sudo vi` |
| `E212: Can't open file for writing` | The directory doesn't exist or you lack permission | Check the path; use `sudo` |
| `E325: ATTENTION` | A swap file exists | Recover (`R`) if you crashed; quit (`Q`) if someone else is editing |
| Pasted text indents further on each line | Auto-indent during paste | `:set paste`, paste, then `:set nopaste` |
| Screen froze | Pressed Ctrl+S | Ctrl+Q |
| YAML error "found character that cannot start any token" | Tabs in a YAML file | `:set list` to see `^I`; `:set expandtab` then `:retab` |

## Quick recap

- vi has modes: **Normal** (commands), **Insert** (`i`/`a`/`o`, typing), **Command-line** (`:`), **Visual** (`v`/`V`/`Ctrl+v`). `Esc` always gets you back to Normal.
- `:w` save, `:q` quit, `:wq`/`:x` both, `:q!` quit without saving, `u` undo.
- `dd` `yy` `p` `/search` `n` `:%s/old/new/g` `gg` `G` `:N` cover most daily editing.
- Edits live in memory until `:w`. A swap file protects you from crashes.

**Interview questions**

1. *How do you replace every occurrence of a word in vi?* `:%s/old/new/g`. `%` means all lines, `g` means every match on each line; add `c` to confirm each one.
2. *What's the difference between `:wq` and `:x`?* Both save and quit, but `:x` writes only if the file changed, so the timestamp is untouched when nothing changed.
3. *You open a file and see E325 ATTENTION. What does it mean?* A swap file exists: either an earlier vim session crashed (recover with `R`), or someone else is editing the file right now (quit and coordinate).
