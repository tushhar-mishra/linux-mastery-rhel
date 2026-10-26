# Passwords, Aging & Account Locking

> **Objective:** *Change passwords and adjust password aging for local user accounts* **[RHCSA Core]**
> **Related:** [Local users](local-users.md) · [Groups](groups.md) · [SSH (key logins bypass passwords)](../networking-and-ssh/ssh-remote-access.md) · [PAM & authselect](pam-and-authselect.md)

## 1. Overview

Password hashes and aging data live in `/etc/shadow` (mode `000`, root only). `passwd` and `chage` manage them; PAM enforces quality rules (`pam_pwquality`) and decides how hashes are generated. Aging controls *when* a password must change; locking and expiry control *whether* an account can be used at all.

## 2. `/etc/shadow` Fields

```
alice:$y$j9T$…:20202:0:99999:7:::
  1      2      3   4   5   6 7 8 9
```

| # | Field | Meaning |
|---|---|---|
| 1 | Username | Matches `/etc/passwd` |
| 2 | Password hash | See states below |
| 3 | lastchg | Days since 1970-01-01 of the last change. `0` = **must change at next login** |
| 4 | min | Days before the password may be changed again (`0` = any time) |
| 5 | max | Days the password stays valid (`99999` = effectively never expires) |
| 6 | warn | Days of warning before expiry |
| 7 | inactive | Days **after** expiry during which login is still allowed **but a password change is forced**; after that the account is disabled |
| 8 | expire | Absolute **account** expiry date (days since 1970); empty = never |
| 9 | reserved | Unused |

Convert day numbers: `date -d @$((20202*86400)) +%F` → `2025-04-24`.

> ⚠️ **Common misconceptions:**
> - A hash starting with `$y$` is **yescrypt**, not SHA-512 (`$6$`).
> - The *inactive* period doesn't block login; it forces a password change. The account is disabled only when the period ends.

### 2.1 Password field states

| Value | Meaning |
|---|---|
| `$y$…` / `$6$…` / `$5$…` / `$1$…` | yescrypt / SHA-512 / SHA-256 / MD5 (weak) hash |
| `!` (alone) | **Never set**: state right after `useradd` on **RHEL 10** (verified, shadow-utils 4.15); no password login. RHEL 9 and earlier wrote `!!` |
| `!` + hash | **Locked** (`usermod -L` / `passwd -l`); hash preserved for unlocking |
| `*` | No valid password possible (typical for system accounts) |
| *(empty)* | **No password**. Console login may succeed with no password ⚠️ |

### 2.2 Hash algorithm

Which algorithm `passwd` uses is set in the PAM stack (authselect), while `ENCRYPT_METHOD` in `/etc/login.defs` affects shadow-utils tools such as `chpasswd`, `useradd -p` workflows and `newusers`. RHEL 10 uses yescrypt (`$y$`) by default (`ENCRYPT_METHOD YESCRYPT`, verified on 10.2). Check your own system:

```bash
sudo awk -F: '$2 ~ /^\$/ {print $1, substr($2,1,3)}' /etc/shadow   # algorithm per user
grep -E '^ENCRYPT_METHOD' /etc/login.defs
```

## 3. Setting Passwords

```bash
passwd                              # change your own (asks current password; quality enforced)
sudo passwd alice                   # root sets alice's (no old password; quality warnings only)
echo 'N3w-Secure#Pass' | sudo passwd --stdin alice     # non-interactive (RHEL-specific option)
echo 'alice:N3w-Secure#Pass' | sudo chpasswd           # non-interactive, several users at once
sudo passwd -S alice                # status: alice P 2026-10-25 0 99999 7 -1   (RHEL 10, verified)
```

- `passwd -S` codes on **RHEL 10** (`passwd` now comes from **shadow-utils**): **`P`** (usable password), **`L`** (locked, *or* never set), **`NP`** (no password). RHEL 9's libuser-based `passwd` printed `PS`/`LK`/`NP`. `--stdin` is still supported on RHEL 10 (verified).
- Commands with passwords on the command line land in shell history and process lists. Use `--stdin`/`chpasswd` from a file or prompt in production.

### Password quality (`pam_pwquality`)

- Configured in `/etc/security/pwquality.conf` (`minlen`, `dcredit`, `ucredit`, `minclass`, `dictcheck`, …).
- Normal users are **rejected** for weak passwords; root gets a `BAD PASSWORD` **warning** but can proceed (unless `enforce_for_root`).
- `PASS_MIN_LEN` in `login.defs` is not what enforces length on RHEL; `minlen` in pwquality is.

## 4. Password Aging (`chage`) **[RHCSA Core]**

```
lastchg ──min──►  can change  ──────────────── max ──► EXPIRED ──inactive──► DISABLED
                                     ◄─warn─┘
expire (field 8): absolute date the whole ACCOUNT stops working, independent of the above
```

| Command | Effect |
|---|---|
| `chage -l alice` | Show all aging info (any user can view their own) |
| `chage -M 90 alice` | Max days (password must change every 90 days) |
| `chage -m 7 alice` | Min days between changes |
| `chage -W 14 alice` | Warning days |
| `chage -I 10 alice` | Inactive days after expiry |
| `chage -d 0 alice` | **Force a password change at next login** (same as `passwd -e alice`) |
| `chage -E 2026-12-31 alice` | Account expires on that date |
| `chage -E -1 alice` | Remove account expiry |
| `chage alice` | Interactive prompts for every field |

Equivalent `passwd` options on RHEL: `-n` (min), `-x` (max), `-w` (warn), `-i` (inactive), `-e` (expire password now).

### Defaults for new users: `/etc/login.defs`

```
PASS_MAX_DAYS   99999
PASS_MIN_DAYS   0
PASS_WARN_AGE   7
```

Changes apply **only to accounts created afterwards**. Existing users need `chage`.

## 5. Locking, Disabling, Expiring

| Goal | Command | Effect | Blocks SSH keys? |
|---|---|---|---|
| Lock password | `usermod -L u` or `passwd -l u` | Prefixes `!` to the hash | **No** |
| Unlock | `usermod -U u` or `passwd -u u` | Removes `!` | — |
| Delete password | `passwd -d u` | Empty hash: **no password needed** ⚠️ | No |
| Expire the account | `chage -E 0 u` or `usermod -e 1 u` | Account unusable | **Yes** (PAM account check) |
| Deny interactive shell | `usermod -s /sbin/nologin u` | No shell sessions | Yes, for shells |
| Force change at next login | `chage -d 0 u` | Must set a new password | — |

> ⚠️ **Common misconceptions:**
> - `passwd -d` does **not** mean "SSH keys only." It removes the password, so console login may need no password at all. That's the opposite of locking.
> - Locking the password doesn't stop key-based SSH or `su` from root. To fully disable an account, expire it and/or set `/sbin/nologin`.
> - Don't "lock" by typing `!!x` into `/etc/passwd`. It breaks the link to `/etc/shadow`; use `usermod -L`/`chage -E`.

### Safe manual editing

```bash
sudo vipw        # /etc/passwd with locking      sudo vipw -s   # /etc/shadow
sudo vigr        # /etc/group                    sudo vigr -s   # /etc/gshadow
sudo pwck -r     # check passwd/shadow consistency (read-only)
sudo grpck -r    # check group/gshadow consistency
```

## 6. Generating Hashes **[Advanced/Optional]**

```bash
openssl passwd -6 'Secret'          # SHA-512 ($6$). Plain `openssl passwd` defaults to weak MD5 ($1$)
openssl passwd -6 -salt XyZ 'Secret'
sudo useradd -p "$(openssl passwd -6 'Secret')" tarun   # works, but the password hits history and ps
```

- The salt is stored between the second and third `$`, so identical passwords produce different hashes.
- Copying a hash from one user to another gives them the same password (the salt travels with it).
- Old examples that call `crypt()` with a 2-character DES salt are legacy. DES is crackable in minutes and may not be supported by RHEL's libxcrypt; use it only to understand hash formats.

## 7. RHCSA Exam Focus **[RHCSA Core]**

```bash
passwd alice                      # set a password interactively (as root)
echo 'pass' | passwd --stdin bob  # non-interactive
chage -M 90 alice                 # "password must change every 90 days"
chage -d 0 alice                  # "must change password at first login"
chage -E 2026-12-31 alice         # "account expires on …"
vi /etc/login.defs  →  PASS_MAX_DAYS 90   # "all NEW users …" (existing users unaffected)
chage -l alice                    # always verify
```

## 8. Production Practices **[Production Practice]**

- Prefer SSH keys plus MFA/central identity over password aging; frequent forced rotation tends to produce weaker passwords (modern NIST guidance discourages arbitrary rotation).
- Disable departed users by expiring the account (`chage -E 0`) before deleting, so their files can be reviewed.
- Audit: empty password fields (`sudo awk -F: '$2==""' /etc/shadow`), MD5 hashes, `PermitEmptyPasswords no` in sshd.
- Never edit shadow files with plain `vi`; use `vipw -s` and validate with `pwck`.

## 9. Troubleshooting

| Symptom | Diagnose | Fix |
|---|---|---|
| "Your account has expired; please contact your system administrator" | `chage -l u` (Account expires) | `chage -E -1 u` or a new date |
| "You are required to change your password immediately" | lastchg = 0 or max reached | Expected; or `chage -d $(date +%F) u` |
| User can't log in, password correct | `passwd -S u` → `L` (RHEL 9: `LK`); shadow hash starts with `!` | `usermod -U u` |
| `BAD PASSWORD: …` for a user | pwquality rules | Choose a stronger password; adjust `pwquality.conf` only if policy allows |
| Locked user still logs in via SSH | Key auth bypasses the password | Expire the account or set `nologin` |
| `pwck` reports errors after hand edits | Inconsistent files | Fix with `vipw`/`vipw -s`; restore backups |

## 10. Interview Questions

| Question | Answer |
|---|---|
| Lock vs expire vs delete password? | Lock prefixes `!` (password unusable, keys still work); expire disables the whole account; deleting the password allows login with **no** password. |
| What does `chage -d 0` do? | Sets the last change to day 0, forcing a password change at next login. |
| What does `!` alone (RHEL 10) or `!!` (RHEL 9) mean in shadow? | The password has never been set. `!` in front of a hash means locked. |
| What's the salt for? | It makes identical passwords hash differently and defeats precomputed tables; it's stored in the hash string. |
| Who enforces password complexity on RHEL? | `pam_pwquality` (`/etc/security/pwquality.conf`). |
| Why `vipw` instead of `vi`? | It locks the files against concurrent edits and edits a copy safely. |

## 11. Practice Exercises (with Solutions)

| # | Task | Command | Note |
|---|---|---|---|
| 1 | Password for oliver | `sudo passwd oliver` | |
| 2 | Lock amelia; verify | `sudo usermod -L amelia; sudo grep '^amelia:' /etc/shadow` | Look for `!` before the hash |
| 3 | `passwd -d oliver` | `sudo passwd -d oliver` | ⚠️ Empty password: login may need no password. Not a safe "disable" |
| 4 | Lock vs disable | See §5 | `passwd -d` is not "SSH key only": it allows login with no password |
| 5 | oliver sets "oliver" | `su - oliver; passwd` | Rejected by pwquality (based on username) |
| 6 | Change every 10 days | `sudo chage -M 10 oliver; sudo chage -l oliver` | |
| 7 | Same for new users | `PASS_MAX_DAYS 10` in `/etc/login.defs` | New accounts only |
| 8 | Copy amelia's hash to oliver | `sudo cp -a /etc/shadow /etc/shadow.bak; sudo vipw -s` | Yes, oliver then uses amelia's password |
| 9 | Why `vipw` | File locking, safe edit | ✔ |
| 10 | List shells | `chsh -l` (needs util-linux-user) · `cat /etc/shells` | |
| 11 | Custom home | `useradd -m -d /custom/home/elena elena` | `-d` alone doesn't create it |
| 12 | Locked? | `sudo passwd -S oliver` → `L` | RHEL 10 codes: `P`/`L`/`NP` (RHEL 9: `PS`/`LK`/`NP`) |

## 12. Quick Revision

```bash
/etc/shadow: user:hash:lastchg:min:max:warn:inactive:expire:   $y$ $6$ !! ! * empty
passwd [-S|-l|-u|-d|-e|--stdin] u ; chpasswd ; chage -l|-M|-m|-W|-I|-d 0|-E date|-E -1 u
usermod -L/-U/-e ; /etc/login.defs PASS_* (new users) ; /etc/security/pwquality.conf
vipw [-s] ; vigr [-s] ; pwck ; grpck ; date -d @$((DAYS*86400))
```

## 13. Cross-References

- [Local users](local-users.md)
- [Groups (gshadow)](groups.md)
- [SSH key authentication](../networking-and-ssh/ssh-remote-access.md)
- [Command history (secrets in history)](../shell-and-command-line/command-history.md)
- [PAM & authselect](pam-and-authselect.md) · [sudo & privileged access](sudo-and-privileged-access.md)
