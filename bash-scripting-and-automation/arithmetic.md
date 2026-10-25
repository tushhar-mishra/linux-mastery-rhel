# Arithmetic in Bash: $(( )), let, expr & bc

> **Sessions:** S92 · supports *Create simple shell scripts* **[RHCSA Core]**
> **Related:** [Script basics (quoting)](script-basics-and-variables.md) · [Conditionals (`(( ))`)](conditionals-and-tests.md) · [Loops](loops.md) · [awk](../files-and-text-processing/awk.md)

## 1. Quoting & Arithmetic

| Command | Output | Why |
|---|---|---|
| `echo 'The sum is 2 + 3'` | `The sum is 2 + 3` | Literal text |
| `echo "The sum is 2 + 3"` | `The sum is 2 + 3` | No arithmetic expansion requested |
| ``echo `The sum is 2 + 3` `` | error (`The: command not found`) | Backticks run a command |
| `echo "The sum is $(2 + 3)"` | error | `$( )` is command substitution |
| `echo 'The sum is $((2 + 3))'` | `The sum is $((2 + 3))` | Single quotes prevent expansion |
| `echo "The sum is $((2 + 3))"` | `The sum is 5` | Arithmetic expansion |

## 2. Integer Arithmetic (built-in)

```bash
a=17 ; b=5
echo $((a + b)) $((a - b)) $((a * b)) $((a / b)) $((a % b)) $((a ** 2))   # 22 12 85 3 2 289
((a++)) ; ((b += 10)) ; echo "$a $b"           # 18 15 (no $ needed inside (( )))
let "c = a * 2" ; echo "$c"                     # let: older equivalent
declare -i n ; n=5*4 ; echo "$n"                # integer attribute evaluates assignments
echo $((16#ff)) $((2#1010)) $((8#17))           # bases: 255 10 15
echo $((RANDOM % 100))                          # random 0–99
```

| Operators | |
|---|---|
| `+ - * / % **` | Arithmetic (`/` truncates toward zero) |
| `++ -- += -= *= /= %=` | Increment/assign |
| `< <= > >= == !=` | Comparison (in `(( ))`) |
| `&& \|\| !` | Logic |
| `& \| ^ ~ << >>` | Bitwise |
| `a ? b : c` | Ternary |

Integers only: `$((7/2))` = 3. Division by zero is an error (`division by 0`).

## 3. Calculator Script (with validation)

```bash
#!/bin/bash
read -rp "First number: " n1
read -rp "Second number: " n2
for v in "$n1" "$n2"; do
    [[ $v =~ ^-?[0-9]+$ ]] || { echo "Integers only: '$v'" >&2; exit 1; }
done
echo "Sum: $((n1 + n2))"
echo "Difference: $((n1 - n2))"
echo "Product: $((n1 * n2))"
if (( n2 == 0 )); then echo "Division by zero not possible" >&2
else echo "Quotient: $((n1 / n2))  Remainder: $((n1 % n2))"; fi
```

## 4. `expr` (legacy)

```bash
expr 5 + 3            # spaces required between every token
expr 5 \* 3           # * must be escaped (glob)
sum=$(expr "$n1" + "$n2")
```

`expr` exits with status **1** when the result is `0`, which surprises `set -e` scripts. Prefer `$(( ))`.

## 5. Decimals: `bc`

```bash
dnf install -y bc                       # if missing on minimal installs
echo "12.5 + 3.7" | bc                  # 16.2
echo "22.5 / 8.5" | bc                  # 2   (scale defaults to 0)
echo "scale=3; 22.5 / 8.5" | bc         # 2.647
echo "22.5 % 8.5" | bc                  # 5.5 (remainder with scale=0)
echo "scale=4; sqrt(2)" | bc -l         # 1.4142
echo "2 ^ 10" | bc                      # 1024 (exponent must be an integer)
echo "scale=4; e(1.5*l(2))" | bc -l     # 2^1.5 via exp/ln = 2.8284
pi=$(echo "scale=10; 4*a(1)" | bc -l)   # 3.1415926532 (a = arctan)
res=$(echo "scale=2; $n1 / $n2" | bc)   # into a variable
```

`bc -l` loads the math library and sets `scale=20`: `s()` sin, `c()` cos, `a()` arctan, `l()` ln, `e()` exp, `sqrt()`.

**Alternatives:** `awk "BEGIN{printf \"%.3f\n\", 22.5/8.5}"` or `printf '%.2f\n' "$(echo '10/3' | bc -l)"`.

## 6. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `syntax error: invalid arithmetic operator (error token is ".5")` | Decimal in `$(( ))` | Use `bc` / `awk` |
| `value too great for base (error token is "08")` | Leading zero = octal | `$((10#$n))` |
| `expr: syntax error` | Missing spaces / unescaped `*` | `expr 5 \* 3` |
| bc division gives an integer | `scale` not set | `scale=3;` or `bc -l` |
| `Runtime error … non-zero scale in exponent` | Decimal exponent with `^` | `e(y*l(x))` with `bc -l` |

## 7. Interview Questions

| Question | Answer |
|---|---|
| How do you do arithmetic in bash? | `$(( expr ))` for values, `(( expr ))` for tests/assignments. |
| Can bash handle decimals? | No; use `bc`, `awk` or another language. |
| Why prefer `$(( ))` over `expr`? | Built-in (faster), no escaping, no surprising exit codes. |

## 8. Course Corrections

| Course | Correction |
|---|---|
| "Modulus doesn't work with decimals in bc" | Works with `scale=0` (`22.5 % 8.5` → 5.5); with `bc -l` the result is ~0 |
| `pi=$(echo "h=10;4*a(1)" \| bc -l)` | `scale=10` was intended; `h=10` just sets an unused variable |
| ``x=`echo "12+5" \| bc` `` | `x=$(echo "12+5" \| bc)` |
| `($num2)^($num1)` with decimals | bc `^` needs an integer exponent |
| Calculator without input validation / divide-by-zero check | Validate input; guard against 0 |

## 9. Quick Revision

```bash
$(( a+b )) $(( a/b )) $(( a%b )) $(( a**b )) · ((i++)) ((x+=2)) · let · declare -i · $((16#ff)) · $((10#08))
expr 5 \* 3 · echo "scale=3; 22.5/8.5" | bc · bc -l: sqrt s c a l e · awk 'BEGIN{print 22.5/8.5}'
