# 039 · Job Scheduling: at, cron, anacron and systemd Timers

> **You need first:** [038 · Logging](038-logging-journald-rsyslog-logrotate.md)
> **Next:** [040 · Script basics](040-script-basics.md)

---

## What it is

Tools that run commands **automatically at a set time**:

| Need | Tool |
|---|---|
| Run **once**, at a specific time | **`at`** |
| Run once, when the system isn't busy | **`batch`** |
| Run **repeatedly** on a schedule (per user or system-wide) | **cron** |
| Daily/weekly/monthly jobs that must still run if the machine was **off** at the scheduled time | **anacron** |
| Repeating jobs with logging, catch-up and resource controls | **systemd timers** |

The background programs that do the scheduling are **`atd`** (for at) and **`crond`** (for cron). On RHEL cron comes from the `cronie` package; on Ubuntu it's the `cron` package.

## Why it exists

Servers need routine work done without a human: backups at 02:00, log cleanup, certificate renewal, reports, health checks, package-cache refresh. Doing it by hand is unreliable; scheduling makes it automatic and repeatable.

## Analogy

- `at` is a **one-time alarm**: "remind me tomorrow at 10:00".
- cron is a **recurring alarm clock**: "every weekday at 07:00". If you're away when it rings, you miss it.
- anacron is a **to-do list that checks "was this done today?"** when you get back home, and does it if not.
- systemd timers are a **smart assistant**: recurring alarms that also keep a diary of every run (the journal), catch up on missed ones, and can be given resource limits.

## How it works inside

### cron

- `crond` wakes up **every minute**, reads all crontabs (it notices changed files automatically), and runs each job whose schedule matches the current minute.
- Each job runs in a **very minimal environment**: `PATH=/usr/bin:/bin`, `SHELL=/bin/sh`, no `.bashrc` or `.bash_profile` (topic 025). This is the **#1 reason** a script "works by hand but not from cron".
- Anything the job prints is **mailed** to the user (if local mail is set up); otherwise it's lost. So redirect output to a log (`>> /var/log/job.log 2>&1`).
- Execution is recorded in `/var/log/cron` (RHEL), in `syslog` (Ubuntu), and in the journal.

### systemd timers

A **timer** unit (`backup.timer`) activates a **service** unit with the same name (`backup.service`). The service does the work; the timer only says **when**. systemd keeps the timer's schedule, runs the service exactly like any other service (cgroup, journal, user, limits), and with `Persistent=true` records the last run on disk so a missed run happens at the next boot.

### anacron

On RHEL, `/etc/cron.hourly/0anacron` runs anacron every hour. anacron checks timestamp files in `/var/spool/anacron/` ("when was cron.daily last run?") and runs anything overdue, after a random delay. That's how `/etc/cron.daily/*` scripts still run on a laptop or VM that's often powered off.

## Commands

### at (one-time)

```bash
sudo dnf install -y at ; sudo systemctl enable --now atd
echo 'df -hT > /tmp/fs.txt' | at 22:00
at now + 5 minutes            # interactive: type commands, then Ctrl+D
```
```
warning: commands will be executed using /bin/sh
job 4 at Mon Nov 16 22:00:00 2026
```

```bash
atq            # list jobs
at -c 4        # show what job 4 will run (including its saved environment)
atrm 4         # cancel it
```
- Time formats: `now + 2 hours`, `tomorrow`, `10:00 tomorrow`, `midnight`, `noon`, `21:40 Aug 5 2026`.
- `batch` runs a job once the load average falls low enough.

### cron: where jobs live

| Location | Who | Has a user field? | Edit with |
|---|---|---|---|
| Per-user crontab (`/var/spool/cron/<user>`) | Each user | No | `crontab -e` |
| `/etc/crontab` | System | **Yes** | An editor (prefer `/etc/cron.d/`) |
| `/etc/cron.d/<file>` | Packages, admins | **Yes** | An editor |
| `/etc/cron.hourly`, `.daily`, `.weekly`, `.monthly` | Executable scripts dropped in | — | Copy a script there |

### cron schedule format

```
┌──────── minute (0-59)
│ ┌────── hour (0-23)
│ │ ┌──── day of month (1-31)
│ │ │ ┌── month (1-12 or jan-dec)
│ │ │ │ ┌ day of week (0-7: 0 and 7 = Sunday, or sun-sat)
│ │ │ │ │
* * * * *  command                 ← user crontab
* * * * *  user  command           ← /etc/crontab and /etc/cron.d/*
```

| Syntax | Meaning | Example |
|---|---|---|
| `*` | Every value | `* * * * *` = every minute |
| `,` | List | `0 5,17 * * *` = 05:00 and 17:00 |
| `-` | Range | `30 23 * * 1-5` = weekdays at 23:30 |
| `/` | Step | `*/10 * * * *` = every 10 minutes; `0 */4 * * *` = every 4 hours |
| `@reboot` `@hourly` `@daily` `@weekly` `@monthly` | Shortcuts | `@weekly` = Sunday 00:00 |

**Minute comes first.** `30 2 * * *` is 02:30, not 30:02.

```bash
crontab -e
```
Add:
```
PATH=/usr/local/bin:/usr/bin:/bin
MAILTO=""
0 2 * * *   /usr/local/bin/backup.sh >> /var/log/backup.log 2>&1
*/15 * * * * /usr/local/bin/healthcheck.sh >> /var/log/health.log 2>&1
```
- Set `PATH` at the top; `MAILTO=""` turns off mail. Redirect output with `>> log 2>&1` (topic 016).

```bash
crontab -l                  # list your jobs
sudo crontab -u alice -l    # root: list alice's
crontab -r                  # ⚠️ deletes ALL your jobs without asking (crontab -ri asks first)
crontab -l > ~/cron.bak     # back up
```

**Traps:**
- `%` means "newline" in a crontab. Escape it: `date +\%F`.
- If you restrict **both** day-of-month **and** day-of-week, the job runs when **either** matches. For "the first Sunday of the month": `0 2 1-7 * * [ "$(date +\%u)" = 7 ] && /usr/local/bin/job.sh`.
- `crontab -r` is right next to `crontab -e` on the keyboard.

### Who may use cron and at

| Files | Rule |
|---|---|
| `/etc/cron.allow` exists | **Only** listed users may use cron (`cron.deny` is ignored) |
| Only `/etc/cron.deny` exists | Everyone **except** listed users |
| `/etc/at.allow`, `/etc/at.deny` | Same logic for at |

root is always allowed.

### anacron

```
# /etc/anacrontab
START_HOURS_RANGE=3-22
RANDOM_DELAY=45
#period(days) delay(min)  job-id        command
1             5           cron.daily    nice run-parts /etc/cron.daily
7             25          cron.weekly   nice run-parts /etc/cron.weekly
@monthly      45          cron.monthly  nice run-parts /etc/cron.monthly
```

### systemd timers

```ini
# /etc/systemd/system/backup.service
[Unit]
Description=Nightly backup

[Service]
Type=oneshot
ExecStart=/usr/local/bin/backup.sh
```
```ini
# /etc/systemd/system/backup.timer
[Unit]
Description=Run backup daily at 02:30

[Timer]
OnCalendar=*-*-* 02:30:00
Persistent=true
RandomizedDelaySec=5min

[Install]
WantedBy=timers.target
```
- `Type=oneshot` = a task that runs and finishes (not a long-running daemon).
- `Persistent=true` = if the machine was off at 02:30, run it at the next boot.
- `RandomizedDelaySec` spreads the start, so 500 servers don't all hit the backup server at the same second.

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now backup.timer     # enable the TIMER, not the service
systemctl list-timers
```
```
NEXT                        LEFT       LAST                        PASSED  UNIT                 ACTIVATES
Tue 2026-11-17 02:32:41 UTC 10h left   Mon 2026-11-16 02:31:10 UTC 13h ago backup.timer         backup.service
Tue 2026-11-17 00:00:00 UTC 8h left    Mon 2026-11-16 00:00:00 UTC 15h ago logrotate.timer      logrotate.service
```
- When it next runs, when it last ran, and which service it starts. The built-in timers (`logrotate`, `dnf-makecache`, `systemd-tmpfiles-clean`, `sysstat-collect`) are listed here too.

```bash
sudo systemctl start backup.service      # run the job right now to test it
journalctl -u backup.service -n 20       # its output and errors
systemd-analyze calendar 'Mon..Fri *-*-* 02:30:00'
```
```
  Original form: Mon..Fri *-*-* 02:30:00
Normalized form: Mon..Fri *-*-* 02:30:00
    Next elapse: Tue 2026-11-17 02:30:00 UTC
       From now: 10h left
```
- Checks a schedule expression and shows when it will next fire.

| Timer setting | Meaning |
|---|---|
| `OnCalendar=` | Wall-clock schedule: `daily`, `weekly`, `Mon..Fri 09:00`, `*:0/15` (every 15 min), `*-*-01 00:00` (monthly) |
| `OnBootSec=10min` | 10 minutes after boot |
| `OnUnitActiveSec=1h` | 1 hour after the service last started (an interval) |
| `Persistent=true` | Catch up missed `OnCalendar` runs |
| `AccuracySec=` | How much slack systemd may use (default 1 min) |

systemd's `weekly` = **Monday** 00:00; cron's `@weekly` = **Sunday** 00:00.

**Quick one-off timer without files:** `sudo systemd-run --on-calendar='*-*-* 03:00' /usr/bin/touch /tmp/ran`.

### cron vs systemd timers

| | cron | systemd timer |
|---|---|---|
| Setup | One line | Two small files |
| Logs | Mail, or your own redirect | Automatically in the journal |
| Missed runs | Only through anacron | `Persistent=true` |
| Prevent overlapping runs | You must add locking | A service can't start twice while running |
| Resource limits, security sandboxing | No | Yes (topic 098) |

### Preventing overlapping cron runs

```bash
*/5 * * * * flock -n /run/sync.lock /usr/local/bin/sync.sh
```
- `flock -n` takes a lock file. If the previous run still holds it, this run exits immediately instead of piling up.

### Try it
1. `echo 'date > /tmp/at-test' | at now + 1 minute`, wait, `cat /tmp/at-test`.
2. Add a cron job every minute that runs `date >> /tmp/cron-test 2>&1`. Check it after 2 minutes, then remove it.
3. Write a job that uses a command from `/usr/local/bin` without a full path. See it fail in cron, read `/var/log/cron`, and fix it.
4. Convert that job into a systemd timer running every 2 minutes (`OnCalendar=*:0/2`) and watch it in `list-timers` and `journalctl -u`.

## Where you'll use it

- **Backups, cleanups, reports, certificate renewals** (Let's Encrypt's certbot installs a timer), cache refreshes.
- **Prefer systemd timers** for new system jobs: logging, catch-up and safety come for free.
- **Kubernetes `CronJob`** uses the same 5-field cron syntax to start pods on a schedule. Everything here about cron expressions applies directly.
- **CI/CD** scheduled pipelines (`schedule:` triggers in GitHub Actions or GitLab) also use cron syntax.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| Works by hand, not from cron | cron's minimal environment (PATH, no profile), or an unescaped `%` | Full paths or `PATH=` at the top; `\%`; set variables inside the script |
| Nothing happens at all | `crond`/`atd` not running, or the user is denied | `systemctl status crond atd`; check the allow/deny files |
| "Did it run?" | — | `grep CROND /var/log/cron` (Ubuntu: `grep CRON /var/log/syslog`); timers: `list-timers`, `journalctl -u X.service` |
| A timer never fires | The timer isn't enabled, or you forgot `daemon-reload` | `systemctl enable --now X.timer`; `daemon-reload` |
| Runs on the wrong days | Day-of-month + day-of-week "OR" rule | Restrict only one, and test the other inside the command |
| Runs pile up and overload the box | A run takes longer than the interval | `flock -n`, or use a timer |
| An `at` job didn't survive a reboot | `atd` wasn't enabled | `systemctl enable --now atd` |
| A job ran at the "wrong" hour | Server time zone differs from what you assumed | `timedatectl` (topic 069) |

## Quick recap

- `at` = once; cron = repeating; anacron = catch up missed daily/weekly jobs; timers = repeating with logs and catch-up.
- cron: `min hour dom month dow command`. Use full paths, escape `%`, redirect output. `crontab -e/-l`; `/etc/cron.d/` files have a user field.
- Timers: a `.timer` + a `.service`; `OnCalendar=`, `Persistent=true`; enable the **timer**; check `systemctl list-timers` and `journalctl -u`.
- Check: `/var/log/cron`, `journalctl`, `systemd-analyze calendar`.

**Interview questions**

1. *Why does a script work in your shell but not from cron?* cron runs it with a minimal environment: a short PATH, no profile files, `/bin/sh`, and `%` meaning newline. Use full paths, set variables in the script, and escape `%`.
2. *cron vs anacron?* cron runs jobs at exact times only if the machine is up. anacron runs daily/weekly/monthly jobs that were missed while it was off.
3. *What advantages do systemd timers have over cron?* Output goes to the journal automatically, missed runs can be caught up (`Persistent=true`), a job can't overlap with itself, and the job gets all of systemd's dependency, resource-limit and security options.
