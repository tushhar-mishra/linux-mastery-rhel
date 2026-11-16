# 044 · Arithmetic in Bash: $(( )), let and bc

> **You need first:** [043 · Loops](043-loops.md)
> **Next:** [045 · Robust production scripts](045-robust-scripts.md)

---

## What it is

| Tool | Does | Decimals? |
|---|---|---|
| `$(( expr ))` | **Arithmetic expansion**: calculates and puts the result in its place | No (whole numbers only) |
| `(( expr ))` | Calculates, for tests and assignments (`((i++))`, `if (( a > b ))`) | No |
| `let "expr"` | Older form of `(( ))` | No |
| `declare -i var` | Makes a variable an integer, so assignments are calculated | No |
| `expr` | A very old external program | No |
| **`bc`** | An arbitrary-precision calculator ("basic calculator") | **Yes** |
| `awk` | Also does decimal maths (topic 019) | **Yes** |

## Why it exists

Scripts count things, compute percentages, compare thresholds, increment loop counters and convert units. bash can do integer maths itself (fast, no extra programs). For decimals (money, averages, ratios) you hand the work to `bc` or `awk`.

## Analogy

`$(( ))` is the **calculator built into your phone's lock screen**: instant, but whole numbers only. `bc` is the **scientific calculator** you open when you need decimals and functions.

## How it works inside

- bash evaluates `$(( … ))` itself, using 64-bit signed integers (range about ±9.2 × 10¹⁸). No new process is started, so it's fast in loops.
- Inside `(( ))`, variable names don't need `$`, and spaces are free.
- **Division truncates** toward zero: `$((7/2))` is `3`. A decimal anywhere is a syntax error.
- **Leading zeros mean octal (base 8)**: `$((08))` fails with "value too great for base". This bites when doing maths on dates (`$(date +%m)` gives `08` in August). Fix it with `$((10#$m))`, which forces base 10.
- `bc` reads an expression on stdin and prints the result. Its `scale` variable sets how many decimal places to keep (default **0**, which is why `bc` division looks like integers until you set it).

## Commands

### Quoting and arithmetic

| Command | Output | Why |
|---|---|---|
| `echo "2 + 3"` | `2 + 3` | Just text |
| `echo "$((2 + 3))"` | `5` | Arithmetic expansion |
| `echo '$((2 + 3))'` | `$((2 + 3))` | Single quotes stop expansion |
| `echo "$(2 + 3)"` | error | `$( )` runs a **command** named `2` |

### Integer maths

```bash
a=17 ; b=5
echo $((a + b)) $((a - b)) $((a * b)) $((a / b)) $((a % b)) $((a ** 2))
```
```
22 12 85 3 2 289
```
- `+ - * /` as usual, `%` remainder, `**` power.

```bash
((a++)) ; ((b += 10)) ; echo "$a $b"
let "c = a * 2" ; echo "$c"
declare -i n ; n=5*4 ; echo "$n"
```
```
18 15
36
20
```

```bash
echo $((16#ff)) $((2#1010)) $((8#17)) $((10#08))
echo $((RANDOM % 100))
```
```
255 10 15 8
42
```
- `base#number` reads other number bases. `$RANDOM` gives 0–32767.

| Operators | Meaning |
|---|---|
| `+ - * / % **` | Maths |
| `++ -- += -= *= /= %=` | Change a variable |
| `< <= > >= == !=` | Compare (true = 1) |
| `&& \|\| !` | Logic |
| `& \| ^ ~ << >>` | Bit operations |
| `cond ? a : b` | Pick a or b |

```bash
used=870 ; total=1000
pct=$(( used * 100 / total ))
(( pct >= 80 )) && echo "warning: ${pct}%"
```
```
warning: 87%
```
- Multiply **before** dividing to keep precision with integers.

### A safe calculator script

```bash
#!/bin/bash
read -rp "First number: " n1
read -rp "Second number: " n2
for v in "$n1" "$n2"; do
    [[ $v =~ ^-?[0-9]+$ ]] || { echo "Integers only: '$v'" >&2; exit 1; }
done
echo "Sum: $((n1 + n2))  Difference: $((n1 - n2))  Product: $((n1 * n2))"
if (( n2 == 0 )); then
    echo "Cannot divide by zero" >&2
else
    echo "Quotient: $((n1 / n2))  Remainder: $((n1 % n2))"
fi
```

### Decimals with bc

```bash
sudo dnf install -y bc        # often missing on minimal installs
echo "12.5 + 3.7" | bc
echo "22.5 / 8.5" | bc
echo "scale=3; 22.5 / 8.5" | bc
echo "scale=4; sqrt(2)" | bc -l
ratio=$(echo "scale=2; 870 / 1000 * 100" | bc) ; echo "$ratio%"
```
```
16.2
2
2.647
1.4142
87.00%
```
- `scale=N` = number of decimal places. `bc -l` loads the maths library (`sqrt`, `s` sin, `c` cos, `a` arctan, `l` natural log, `e` exponent) and sets `scale=20`.

### Decimals with awk (often simpler)

```bash
awk 'BEGIN { printf "%.2f\n", 22.5 / 8.5 }'
awk -v u=870 -v t=1000 'BEGIN { printf "%.1f%%\n", u/t*100 }'
```
```
2.65
87.0%
```

### expr (you'll see it in old scripts)

```bash
expr 5 + 3       # spaces between every part
expr 5 \* 3      # * must be escaped
```
`expr` exits with status **1** when the result is 0, which breaks `set -e` scripts. Use `$(( ))`.

### Try it
1. Compute the percentage of used inodes on `/` from `df -i` numbers, with `$(( ))`.
2. Average a column of numbers with awk: `seq 1 10 | awk '{s+=$1} END {print s/NR}'`.
3. Try `m=08; echo $((m+1))`, read the error, and fix it with `10#`.
4. Convert bytes to GiB with 2 decimals using `bc`.

## Where you'll use it

- **Thresholds in monitoring scripts:** usage percentages, free-space checks, error rates.
- **Loop counters and retry back-off:** `delay=$((delay * 2))`.
- **Time maths:** elapsed seconds with `start=$(date +%s)` … `$(( $(date +%s) - start ))`.
- **Unit conversion** (bytes → MiB) for reports.
- For heavy number crunching, use awk or Python instead.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `syntax error: invalid arithmetic operator (error token is ".5")` | A decimal in `$(( ))` | Use `bc` or `awk` |
| `value too great for base (error token is "08")` | A leading zero means octal | `$((10#$n))` |
| `division by 0` | Dividing by zero | Check the divisor first |
| `expr: syntax error` | Missing spaces or unescaped `*` | `expr 5 \* 3`, or use `$(( ))` |
| `bc` division gives a whole number | `scale` not set | `scale=3;` or `bc -l` |
| `bc: command not found` | Not installed | `dnf install bc`, or use awk |

## Quick recap

- `$(( ))` for integer results, `(( ))` for tests/increments; no `$` needed on names inside. Whole numbers only; `/` truncates.
- Leading zeros = octal → `10#$n`. Multiply before dividing.
- Decimals: `echo "scale=2; a/b" | bc` or `awk 'BEGIN{printf "%.2f\n", a/b}'`.
- Avoid `expr` in new scripts.

**Interview questions**

1. *How do you do arithmetic in bash?* `$(( expression ))` to get a value, `(( expression ))` for tests and in-place changes like `((i++))`.
2. *Can bash do decimal maths?* No, bash arithmetic is integer-only. Use `bc`, `awk` or another language.
3. *Why does `$((08 + 1))` fail?* A leading zero makes bash read the number as octal, where 8 is invalid. Use `$((10#08 + 1))`.
