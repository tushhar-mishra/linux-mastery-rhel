# awk

> **Sessions:** S19 · **[Advanced/Optional]**, but very useful for scripts, log analysis and interviews
> **Related:** [Text filters](text-filters.md) · [grep & regex](grep-and-regular-expressions.md) · [Redirection](io-redirection-and-pipes.md)

## 1. Overview

`awk` is a pattern-scanning language named after Aho, Weinberger and Kernighan (Bell Labs, 1977). It reads input as **records** (lines) split into **fields**, and runs `pattern { action }` rules on each record. On RHEL, `awk` is **GNU awk (gawk)**.

```bash
awk 'pattern { action }' file
command | awk -F: '$3 >= 1000 { print $1 }'
```

Always use **single quotes**, so the shell doesn't expand awk's `$1`.

## 2. Key Concepts

| Variable | Meaning |
|---|---|
| `$0` | Whole record (line) |
| `$1` … `$NF` | Fields; `$NF` is the last field |
| `NF` | Number of fields in this record |
| `NR` / `FNR` | Record number overall / within the current file |
| `FS` (`-F`) | Input field separator. Default: runs of whitespace |
| `OFS` | Output field separator (default space), used between comma-separated `print` items |
| `RS` / `ORS` | Input / output record separators |
| `FILENAME` | Current file name |

- **Patterns:** `NR>1`, `$3=="Delhi"`, `/regex/`, `$1 ~ /^ab/`, `$1 !~ /x/`, `cond1 && cond2`, `BEGIN`, `END`.
- **Comma vs concatenation:** `print $1, $2` inserts OFS; `print $1 $2` joins them directly.

## 3. Examples

Sample `data.txt` (with a header line):

```
Name Age City
Tarun 24 Jaipur
Ravi 30 Delhi
Priya 27 Mumbai
Neha 25 Pune
```

```bash
awk '{print $1, $3}' data.txt                         # columns 1 and 3
awk 'NR>1 {print $1}' data.txt                        # skip header
awk 'NR>1 && $2 > 25' data.txt                        # condition (default action: print)
awk '$3 == "Delhi"' data.txt
awk 'NR>1 {s+=$2; n++} END {if (n) print "Avg:", s/n}' data.txt
awk '{print NR": "$0}' data.txt                       # number lines
awk 'NR>1 {printf "%-10s %3d %s\n", $1, $2, $3}' data.txt
awk -F, 'BEGIN{OFS="\t"} {print $1, $2, $3}' users.csv # CSV → TSV
awk -v min=26 'NR>1 && $2 >= min {print $1}' data.txt  # pass a shell value safely
awk 'NR>1 {c[$3]++} END {for (k in c) print k, c[k]}' data.txt   # count per city (arrays)
awk 'BEGIN {for (i=1; i<=5; i++) print "Number:", i}'
```

**System administration one-liners:**

```bash
awk -F: '$3>=1000 && $3<65534 {print $1}' /etc/passwd        # regular users (65534 = nobody)
awk -F: '{print $1, $3, $7}' /etc/passwd                      # user, UID, shell
df -hP | awk 'NR>1 && $5+0 > 80 {print $6, $5}'               # filesystems over 80% full
ps -eo pid,%mem,comm --sort=-%mem | awk 'NR<=6'               # top memory consumers
sudo awk '/Failed password/ {print $(NF-3)}' /var/log/secure | sort | uniq -c | sort -rn
ip -4 -o addr show scope global | awk '{print $2, $4}'        # interface + address/prefix
```

## 4. awk vs cut vs grep vs sed

| Need | Best tool |
|---|---|
| Select lines by pattern | `grep` |
| Simple single-character delimiter column | `cut` |
| Columns separated by variable whitespace, conditions, sums, reports | `awk` |
| Substitutions and in-place edits | `sed` |

## 5. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Header line appears in numeric filters | `"Age" > 25` is a **string** comparison and true | Add `NR>1` |
| `$1` empty or odd in output | Double quotes let the shell expand `$1` | Single-quote the program |
| Wrong columns on CSV | Default FS is whitespace | `-F,` (quoted commas need a real CSV parser) |
| `$5 > 80` misbehaves on `85%` | `85%` is a string | Force numeric: `$5+0` |
| Division by zero in END | No matching lines | Guard: `if (n)` |

## 6. Interview Questions

| Question | Answer |
|---|---|
| What is `NF` and `$NF`? | Field count, and the last field. |
| `NR` vs `FNR`? | Overall record number vs per-file record number. |
| How do you pass a shell variable into awk? | `awk -v name="$var" '…'`. |
| Print the 2nd column of lines containing "error"? | `awk '/error/ {print $2}' file`. |

## 7. Course Corrections

- `awk '$2 > 25' data.txt` also prints the **header** (string comparison). Use `NR>1 && $2 > 25`.
- `awk '$9 == 404 …' access.log` assumes the Apache/Nginx combined log format.
- `dmesg` may require root, depending on `kernel.dmesg_restrict`.

## 8. Quick Revision

```bash
awk -F: -v x=1 'BEGIN{OFS=","} NR>1 && $3>=1000 {print $1,$NF; n++} END{print n}' /etc/passwd
$0 $1 $NF NF NR FNR FS OFS   ~ !~ /re/   printf "%-10s %5d\n"   arrays: c[$1]++
```

## 9. Cross-References

- [Text filters & pipelines](text-filters.md)
- [grep & regular expressions](grep-and-regular-expressions.md)
- [Command substitution (awk in scripts)](../shell-and-command-line/command-substitution-and-shell-options.md)
