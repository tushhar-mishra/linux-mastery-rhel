# Command Line Assistant (RHEL Lightspeed)

> **[Advanced/Optional]** · not available in the exam (requires internet and a registered system)
> **Related:** [Getting help (offline docs for the exam)](../shell-and-command-line/getting-help-and-documentation.md) · [System logging](../logs-scheduling-and-packages/system-logging.md) · [SELinux troubleshooting](../firewall-and-selinux/selinux-booleans-ports-troubleshooting.md)

## 1. Overview

The **Command Line Assistant**, powered by **RHEL Lightspeed**, answers natural-language questions in the terminal using Red Hat documentation and knowledge-base content. It can explain errors and logs that you pass to it. It does **not** inspect the system on its own and doesn't run commands for you.

**Requirements:** RHEL 9.6+ or RHEL 10, the system registered with Red Hat, and network access (proxies supported) to the Lightspeed service.

## 2. Install & Basic Use

```bash
sudo dnf install -y command-line-assistant
c --help                                     # options vary by version; check here first
c "How do I set the timezone to America/Vancouver on RHEL 10?"
#   → suggests: timedatectl set-timezone America/Vancouver
```

## 3. Giving It Context

```bash
journalctl -u httpd -b --no-pager | c "Why is httpd failing to start?"     # pipe output
ausearch -m avc -ts recent | c "Explain these SELinux denials and fixes"
df -h | c "Which filesystem is nearly full?"
c -a /etc/httpd/conf/httpd.conf "Is there an error in this config?"        # attach a file (see c --help)
```

Interactive multi-step sessions and history viewing (`c history …`) are available too; see `c --help` for your version's exact syntax.

## 4. Good Practice **[Production Practice]**

- **Verify** every suggested command (read it, understand it, test on non-production first). AI answers can be wrong or incomplete.
- Data you pipe or attach is sent to Red Hat's service: **remove secrets**, keys, passwords and personal data first.
- Combine it with authoritative sources: `man` pages, `/usr/share/doc`, Red Hat documentation.
- For the exam, train the **offline** workflow instead: `man -k`, `man 5 …`, `/usr/share/doc`, `--help` (see [getting help](../shell-and-command-line/getting-help-and-documentation.md)).

## 5. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Authentication/registration errors | System not registered | `subscription-manager register`; check status |
| Connection errors | No internet / proxy not configured | Configure proxy settings for the assistant |
| `c: command not found` | Package missing / older RHEL | Install `command-line-assistant` (RHEL 9.6+ / 10) |
