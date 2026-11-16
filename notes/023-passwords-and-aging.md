# 023 · Passwords, Password Aging and Account Locking

> **You need first:** [022 · Users and accounts](022-users-and-accounts.md)
> **Next:** [024 · Groups](024-groups.md)

---

## What it is

- **`/etc/shadow`** stores each local user's **password hash** and **aging** rules. Only root can read it.
- A **hash** is a one-way scramble of the password. Linux never stores your real password. At login it hashes what you type and compares the two results. You can't turn a hash back into the password; you can only guess and compare.
- A **salt** is random text mixed into the password before hashing, so two users with the same password still get different hashes.
- **Password aging** controls **when** a password must be changed (maximum age, warning period, and so on).
- **Locking** and **expiring** control **whether** an account can be used at all.
- **PAM** (Pluggable Authentication Modules) is the framework that actually checks passwords and enforces password-quality rules (topic 029).

Tools: `passwd`, `chage` (**ch**ange **age**), `usermod -L/-U`, `chpasswd`, `vipw`, `pwck`.

## Why it exists

- Storing only hashes means that if `/etc/shadow` leaks, attackers still have to crack each password.
- Aging and expiry let you force new users to set their own password, disable contractors on their end date, and meet company policy.
- Locking lets you block an account immediately (someone left, a key leaked) without deleting their files.

## Analogy

The hash is a **fingerprint of the password**. The door scanner compares fingerprints; it never stores the finger. The salt is like **wearing a unique glove** before printing: the same finger gives different prints for different people, so an attacker can't use one printed "fingerprint dictionary" for everybody.

Aging is the **expiry date on a badge**. Locking is **putting tape over the badge reader for one person**: the badge still exists, it just doesn't work at that reader.

## How it works inside

### `/etc/shadow`, field by field

```
alice:$y$j9T$Fq...$Zx...:20408:0:99999:7:::
  1        2               3   4   5   6 7 8 9
```

| # | Field | Meaning |
|---|---|---|
| 1 | User name | Matches `/etc/passwd` |
| 2 | Password hash | See the states below |
| 3 | lastchg | Day of the last change, counted in days since 1 Jan 1970. **`0` = must change at next login** |
| 4 | min | Days before the user may change it again (`0` = any time) |
| 5 | max | Days the password stays valid (`99999` = effectively never expires) |
| 6 | warn | Days of warning before it expires |
| 7 | inactive | Days **after** expiry during which login is still allowed **but forces a password change**. After that, the account is disabled |
| 8 | expire | The date the **whole account** stops working (days since 1970). Empty = never |
| 9 | reserved | Unused |

Convert a day number to a date: `date -d @$((20408*86400)) +%F`.

### What the password field can contain

| Value | Meaning |
|---|---|
| `$y$…` | **yescrypt** hash (RHEL 10 and recent Ubuntu default; designed to be slow to crack) |
| `$6$…` / `$5$…` | SHA-512 / SHA-256 based hash (older default) |
| `$1$…` | MD5: weak, should not be used |
| `!` alone | Password **never set** (state after `useradd` on RHEL 10; RHEL 9 used `!!`) |
| `!` + hash | **Locked** (the hash is kept so it can be unlocked) |
| `*` | No password is possible (typical for system accounts) |
| *(empty)* | **No password at all**: login may succeed with nothing ⚠️ |

The format is `$id$salt$hash`. The salt is stored in the string, which is how the system can re-hash your typed password for comparison.

### What happens at login

1. The login program (sshd, `login`, `su`) asks PAM to authenticate the user.
2. PAM's `pam_unix` module reads the user's line in `/etc/shadow`, takes the salt and algorithm from the hash, hashes the password you typed with them, and compares the two.
3. The **account** check then looks at the aging and expiry fields: is the account expired? Is a password change required?
4. Only if both pass does the session start.

**Important:** SSH **key** logins skip step 2 (no password involved), but step 3 still runs. That's why **locking the password does not stop SSH key logins, but expiring the account does.**

### Aging timeline

```
lastchg ──min──► may change ─────────────── max ──► EXPIRED ──inactive──► DISABLED
                                      ◄─warn─┘
expire (field 8): a fixed date when the whole ACCOUNT stops working, separate from all of the above
```

## Commands

### Setting passwords

```bash
passwd                     # change your own (asks for the current one; quality rules apply)
sudo passwd alice          # root sets alice's (no old password needed)
echo 'alice:N3w-Secure#Pass' | sudo chpasswd     # non-interactive; many users at once; works everywhere
echo 'N3w-Secure#Pass' | sudo passwd --stdin alice   # RHEL-only shortcut
```

Passwords typed on the command line end up in shell history (topic 015) and can briefly appear in process lists. In real automation, read them from a protected file or a secrets manager.

```bash
sudo passwd -S alice
```
```
alice P 2026-11-16 0 99999 7 -1
```
- Status: user, state, last change date, min, max, warn, inactive.
- RHEL 10 states: **`P`** = usable password, **`L`** = locked or never set, **`NP`** = no password. (RHEL 9 printed `PS`/`LK`/`NP`; Ubuntu prints `P`/`L`/`NP`.)

**Password quality** is checked by `pam_pwquality` using `/etc/security/pwquality.conf` (`minlen`, `minclass`, `dictcheck`, …). Normal users are **rejected** for weak passwords. Root only gets a `BAD PASSWORD` **warning** and can continue (unless `enforce_for_root` is set).

```bash
passwd
```
```
Changing password for user alice.
Current password:
New password:
BAD PASSWORD: The password is shorter than 8 characters
```

### Aging with `chage`

```bash
sudo chage -l alice
```
```
Last password change					: Nov 16, 2026
Password expires					: never
Password inactive					: never
Account expires						: never
Minimum number of days between password change		: 0
Maximum number of days between password change		: 99999
Number of days of warning before password expires	: 7
```

| Command | Effect |
|---|---|
| `chage -M 90 alice` | Password must change every 90 days |
| `chage -m 7 alice` | At least 7 days between changes |
| `chage -W 14 alice` | Warn 14 days before expiry |
| `chage -I 10 alice` | 10 days of grace after expiry, then disabled |
| `chage -d 0 alice` | **Force a change at next login** (same as `passwd -e alice`) |
| `chage -E 2026-12-31 alice` | The account stops working on that date |
| `chage -E -1 alice` | Remove the account expiry |
| `chage alice` | Ask for every value interactively |

```bash
sudo chage -d 0 alice ; su - alice
```
```
Password:
You are required to change your password immediately (administrator enforced).
Current password:
New password:
```

**Defaults for new users** live in `/etc/login.defs` (`PASS_MAX_DAYS`, `PASS_MIN_DAYS`, `PASS_WARN_AGE`). Changing them affects **only accounts created afterwards**; existing users need `chage`.

### Locking, disabling, expiring

| Goal | Command | Effect | Stops SSH key logins? |
|---|---|---|---|
| Lock the password | `usermod -L u` or `passwd -l u` | Puts `!` before the hash | **No** |
| Unlock | `usermod -U u` or `passwd -u u` | Removes the `!` | — |
| Remove the password | `passwd -d u` | Empty hash: **no password needed** ⚠️ | No |
| Expire the whole account | `chage -E 0 u` (or `usermod -e 1 u`) | Account unusable | **Yes** |
| Block shell login | `usermod -s /sbin/nologin u` | No interactive shell | Yes, for shells |

**To fully disable someone who left:** expire the account (`chage -E 0`), lock the password, remove their SSH keys and sudo rights, and review their files before deleting.

`passwd -d` is a trap: it doesn't mean "keys only". It means **no password**, which can allow login with an empty password on the console.

### Safe manual editing

```bash
sudo vipw          # edit /etc/passwd with locking (vipw -s for /etc/shadow)
sudo vigr          # edit /etc/group (vigr -s for /etc/gshadow)
sudo pwck -r       # check passwd/shadow are consistent (read-only)
sudo grpck -r      # check group/gshadow
```
- These lock the files so two edits can't collide, and they edit a copy safely.

### Checking which hash algorithm is used

```bash
sudo awk -F: '$2 ~ /^\$/ {print $1, substr($2,1,3)}' /etc/shadow
grep ^ENCRYPT_METHOD /etc/login.defs
```
```
alice $y$
bob $y$
ENCRYPT_METHOD YESCRYPT
```

```bash
openssl passwd -6 'Secret'
```
```
$6$Kq3h9bZr8s$2mJ...
```
- Generates a SHA-512 hash (for example, for automation tools that want a pre-hashed password). Plain `openssl passwd` without `-6` uses weak MD5.

### Try it
1. Create `temp1`, check `passwd -S` (never set), set a password, check again.
2. `chage -d 0 temp1`, then `su - temp1` and change the password when asked.
3. Lock `temp1`, look at its shadow line (the `!`), then unlock it.
4. `chage -E 2026-01-01 temp1` (a date in the past), then try `su - temp1` and read the message.

## Where you'll use it

- **Onboarding:** create the account, set a temporary password, `chage -d 0` so the user picks their own.
- **Offboarding:** `chage -E 0` plus lock plus remove keys, the same day.
- **Contractors:** `chage -E <end date>` at creation.
- **Audits:** find empty password fields (`sudo awk -F: '$2==""' /etc/shadow`), MD5 hashes, accounts that never expire when policy requires it.
- **Modern practice:** prefer SSH keys, central identity and MFA (multi-factor authentication). Current NIST guidance (NIST = US National Institute of Standards and Technology) **discourages forced periodic password rotation**, because it pushes people towards weaker passwords. Use aging when your policy demands it.
- **Cloud images and containers** usually have no passwords at all: key-only login, and locked root.

## When it breaks

| Symptom | Check | Fix |
|---|---|---|
| "Your account has expired; please contact your system administrator" | `chage -l u` → Account expires | `chage -E -1 u` or a new date |
| "You are required to change your password immediately" | lastchg = 0, or max reached | Expected. Change it, or set `chage -d $(date +%F) u` |
| Correct password, still can't log in | `passwd -S u` shows `L`; the shadow hash starts with `!` | `usermod -U u` |
| `BAD PASSWORD: …` | pwquality rules | Use a stronger password; change `pwquality.conf` only if policy allows |
| A "locked" user still gets in via SSH | Key login skips the password | Expire the account (`chage -E 0`) or set `nologin` |
| `pwck` complains after hand edits | Files are out of sync | Fix with `vipw`/`vipw -s`; restore the backup |

## Quick recap

- `/etc/shadow`: `user:hash:lastchg:min:max:warn:inactive:expire:`. `$y$` = yescrypt. `!` = never set or locked. Empty = no password (dangerous).
- `passwd`, `chpasswd`, `passwd -S`; `chage -l -M -m -W -I -d 0 -E`.
- Lock (`usermod -L`) stops passwords only; expire (`chage -E 0`) stops the whole account, including SSH keys.
- New-user defaults are in `/etc/login.defs`; quality rules in `/etc/security/pwquality.conf`. Edit account files with `vipw`.

**Interview questions**

1. *Lock vs expire vs delete password?* Lock puts `!` before the hash, so passwords fail but SSH keys still work. Expire disables the whole account, keys included. Deleting the password leaves it empty, which may allow login with no password at all.
2. *What does `chage -d 0 user` do?* It sets the last-change day to 0, which forces the user to change their password at the next login.
3. *What is a salt?* Random data stored with the hash and mixed into the password before hashing. Identical passwords get different hashes, and precomputed crack tables become useless.
