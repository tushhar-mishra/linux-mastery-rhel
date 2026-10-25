# Job Scheduling: at, batch, cron, anacron & systemd Timers

> **Objective:** *Schedule tasks using at, cron, and systemd timer units* **[RHCSA Core]**
> **Related:** [System logging](system-logging.md) · [systemd targets & services](../boot-systemd-and-kernel/systemd-targets-and-services.md) · [Shell variables (cron environment)](../shell-and-command-line/shell-variables-and-environment.md) · [systemd unit files](../boot-systemd-and-kernel/systemd-unit-files.md) · [Robust scripts](../bash-scripting-and-automation/robust-scripts.md)

## 1. Overview

| Need | Tool |
|---|---|
| Run once at a specific time | **`at`** |
| Run once when the system is idle | **`batch`** |
| Recurring, per user or system | **cron** (`crontab`, `/etc/cron.d/`) |
| Daily/weekly/monthly jobs that must run even if the machine was off | **anacron** |
| Recurring jobs with systemd features (logging, dependencies, catch-up, randomized delay) | **systemd timers** |

## 2. `at` (one-time jobs)

````bash
dnf install -y at ; systemctl enable --now atd
at 21:40 Aug 5 2026            # interactive: type commands, finish with Ctrl+D
at now + 5 minutes             # also: now + 2 hours, tomorrow, midnight, noon, teatime
echo 'df -hT > /tmp/fs.txt' | at 22:00
atq          # (= at -l) list jobs: number, time, queue, owner
at -c 4      # show the full job script (environment + commands)
atrm 4       # remove job 4
````

- Jobs are stored in `/var/spool/at/` (current RHEL location, not legacy) and run with the submitting user's environment and working directory.
- Output that isn't redirected is mailed to the user (if local mail is configured).

### `batch`

`echo 'updatedb' | batch` runs once when the load average falls below atd's threshold (see `man atd`, option `-l`).

## 3. cron (recurring jobs)

`cronie` provides `crond`, installed and enabled by default (`systemctl status crond`).

### 3.1 Where jobs live

| Location | Who | User field? | Edit with |
|---|---|---|---|
| User crontab (`/var/spool/cron/<user>`) | Each user | No | `crontab -e` |
| `/etc/crontab` | System | **Yes** | vi (prefer `/etc/cron.d/`) |
| `/etc/cron.d/<file>` | Packages, admins | **Yes** | vi |
| `/etc/cron.{hourly,daily,weekly,monthly}/` | Scripts (executable) | — | Drop an executable script |

### 3.2 Format

````
┌──────── minute (0-59)
│ ┌────── hour (0-23)
│ │ ┌──── day of month (1-31)
│ │ │ ┌── month (1-12 or jan-dec)
│ │ │ │ ┌ day of week (0-7, 0 and 7 = Sunday, or sun-sat)
│ │ │ │ │
* * * * *  command                      (user crontab)
* * * * *  user  command                (/etc/crontab, /etc/cron.d/*)
````

| Syntax | Meaning | Example |
|---|---|---|
| `*` | Every value | `* * * * *` every minute |
| `,` | List | `0 5,17 * * *` 05:00 and 17:00 |
| `-` | Range | `30 23 * * 1-5` weekdays 23:30 |
| `/` | Step | `*/10 * * * *` every 10 min; `0 */4 * * *` every 4 h |
| `@reboot` `@hourly` `@daily` `@weekly` `@monthly` `@yearly` | Shortcuts | `@weekly` = `0 0 * * 0` (**Sunday**) |

### 3.3 Commands

````bash
crontab -e                 # edit your crontab (validates syntax on save)
crontab -l                 # list
crontab -r                 # ⚠️ delete ALL your jobs without asking (crontab -ri asks)
crontab -u natasha -e      # root: edit another user's crontab
crontab -u natasha -l
crontab -l > cron.bak ; crontab cron.bak    # backup / restore
````

### 3.4 Rules that cause most cron bugs

- **Minimal environment:** `PATH=/usr/bin:/bin`, no profile files → use **full paths** or set `PATH=` at the top of the crontab.
- `%` is special (newline) → escape it as `\%` (`date +\%F`).
- If **both** day-of-month and day-of-week are restricted, the job runs when **either** matches. For "first Sunday" use a test: `0 2 1-7 * * [ "$(date +\%u)" = 7 ] && /usr/local/bin/job.sh`.
- Redirect output, or it's mailed to the user: `… >> /var/log/job.log 2>&1`.

### 3.5 Examples

````
0 2 * * *        /usr/local/bin/backup.sh                    # daily 02:00
30 23 * * 1-5    /usr/bin/echo "weekday" >> /tmp/weekday.log # Mon–Fri 23:30
0 17 * * sun,fri /script/report.sh                           # Sun and Fri 17:00
* * * * jan,may,aug /script/check.sh                          # every minute in those months
* * * * *        /tmp/a.sh ; * * * * * sleep 30; /tmp/a.sh    # "every 30 s" (two lines)
````

## 4. Access Control (at and cron)

| Files | Rule |
|---|---|
| `/etc/cron.allow` exists | **Only** listed users may use cron (`cron.deny` ignored) |
| Only `/etc/cron.deny` exists | Everyone **except** listed users |
| `/etc/at.allow` / `/etc/at.deny` | Same logic for at |

Root is always allowed. A denied user sees `You (user) are not allowed to use this program` or `You do not have permission to use at`.

## 5. anacron

Runs daily/weekly/monthly jobs that were **missed** while the machine was off. On RHEL it's started hourly by `/etc/cron.hourly/0anacron` and configured in `/etc/anacrontab`:

````
START_HOURS_RANGE=3-22
RANDOM_DELAY=45
#period(days)  delay(min)  job-id        command
1              5           cron.daily    nice run-parts /etc/cron.daily
7              25          cron.weekly   nice run-parts /etc/cron.weekly
@monthly       45          cron.monthly  nice run-parts /etc/cron.monthly
2              15          mybackup      /usr/local/bin/myscript.sh
````

Last-run timestamps are kept in `/var/spool/anacron/<job-id>`. Jobs run as root.

## 6. systemd Timers (supplemented) **[RHCSA Core]**

A timer unit (`*.timer`) activates a service unit (`*.service`, same name by default).

````ini
# /etc/systemd/system/backup.service
[Unit]
Description=Nightly backup

[Service]
Type=oneshot
ExecStart=/usr/local/bin/backup.sh
````

````ini
# /etc/systemd/system/backup.timer
[Unit]
Description=Run backup daily at 02:30

[Timer]
OnCalendar=*-*-* 02:30:00
Persistent=true            # run at next boot if the scheduled time was missed
RandomizedDelaySec=5min    # optional: spread load

[Install]
WantedBy=timers.target
````

````bash
systemctl daemon-reload
systemctl enable --now backup.timer      # enable the TIMER, not the service
systemctl list-timers --all              # NEXT/LEFT/LAST/PASSED/UNIT/ACTIVATES
systemctl start backup.service           # test the job immediately
journalctl -u backup.service             # job output and errors
````

| Timer setting | Meaning |
|---|---|
| `OnCalendar=` | Wall-clock schedule (`daily`, `weekly`, `Mon..Fri 09:00`, `*:0/15`, `*-*-01 00:00`) |
| `OnBootSec=10min` | 10 minutes after boot |
| `OnUnitActiveSec=1h` | 1 hour after the service last ran (monotonic interval) |
| `Persistent=true` | Catch up missed runs (OnCalendar only) |
| `AccuracySec=` | Allowed scheduling slack (default 1 min) |

````bash
systemd-analyze calendar 'Mon..Fri *-*-* 02:30:00'   # validate and show next run
man systemd.timer ; man systemd.time                    # syntax references (available offline)
systemd-run --on-calendar='*-*-* 03:00' /usr/bin/touch /tmp/ran   # transient timer (no files) [Advanced]
````

> systemd's `weekly` means **Monday** 00:00; cron's `@weekly` means **Sunday** 00:00.

Built-in examples: `systemctl list-timers` shows `logrotate.timer`, `dnf-makecache.timer`, `systemd-tmpfiles-clean.timer` and others.

### cron vs systemd timers

| | cron | systemd timer |
|---|---|---|
| Setup | One line | Two unit files |
| Logs | Mail / own redirection | Journal (`journalctl -u`) |
| Missed runs | anacron only | `Persistent=true` |
| Dependencies, resource limits | No | Yes (unit options, cgroups) |

## 7. RHCSA Exam Focus **[RHCSA Core]**

````bash
# "User natasha: run /bin/echo hello every day at 14:23"
crontab -e -u natasha  →  23 14 * * * /bin/echo hello
crontab -l -u natasha                                   # verify

# "Run a job once tomorrow at 10:00"
echo '/usr/local/bin/task.sh' | at 10:00 tomorrow ; atq

# "Create a systemd timer that runs X every 15 minutes"
OnCalendar=*:0/15  → daemon-reload → enable --now x.timer → list-timers
````

- Use **absolute paths** in jobs.
- Exact times matter: double-check minute and hour order (minute first!).

## 8. Production Practices **[Production Practice]**

- Prefer systemd timers for new system jobs: logging, catch-up and resource controls come for free.
- Make jobs idempotent and lock against overlapping runs (`flock -n /run/job.lock /usr/local/bin/job.sh`).
- Log output; alert on failures (`OnFailure=` in systemd, or checks on exit codes).
- Spread heavy jobs (`RandomizedDelaySec`, anacron `RANDOM_DELAY`) to avoid load spikes.

## 9. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Cron job runs manually but not from cron | PATH/environment, `%` unescaped | Full paths; `\%`; set variables in the script |
| Nothing happens | crond/atd stopped, user denied | `systemctl status crond atd`; check allow/deny files |
| Did it run? | — | `grep CROND /var/log/cron`; `journalctl -u crond`; timer: `systemctl list-timers`, `journalctl -u x.service` |
| Timer never fires | Timer not enabled, or no `daemon-reload` | `systemctl enable --now x.timer`; `daemon-reload` |
| Job runs on unexpected days | DOM+DOW OR rule | Restrict one field, test in the command |
| `at` job missing after reboot | atd not enabled | `systemctl enable --now atd` |

## 10. Interview Questions

| Question | Answer |
|---|---|
| cron vs anacron? | cron runs at exact times if the system is up; anacron runs periodic jobs that were missed while it was down. |
| Why does a script work in a shell but not in cron? | cron's minimal environment: PATH, variables, no profile; also unescaped `%`. |
| How do you allow only certain users to use cron? | List them in `/etc/cron.allow`. |
| Advantages of systemd timers? | Journal logging, `Persistent=` catch-up, dependencies, resource control, `list-timers` visibility. |
| What does `*/15` mean? | Every 15 units of that field (e.g., every 15 minutes). |

## 11. Quick Revision

````bash
at TIME / at now +5 minutes · atq · at -c N · atrm N · batch · systemctl enable --now atd
crontab -e|-l|-r|-u U · m h dom mon dow cmd · */N , - · @reboot @daily · \% · full paths
/etc/crontab & /etc/cron.d/ (user field) · /etc/cron.{allow,deny} · /etc/at.{allow,deny} · /var/log/cron
/etc/anacrontab · /var/spool/anacron
timer: OnCalendar= Persistent=true WantedBy=timers.target · daemon-reload · enable --now X.timer · list-timers · systemd-analyze calendar
````

## 12. Cross-References

- [System logging](system-logging.md)
- [systemd targets & services](../boot-systemd-and-kernel/systemd-targets-and-services.md)
- [Shell variables (cron environment)](../shell-and-command-line/shell-variables-and-environment.md)
