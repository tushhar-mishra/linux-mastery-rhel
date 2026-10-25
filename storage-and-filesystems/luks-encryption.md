# LUKS Disk Encryption

> **Sessions:** S47 · **[Advanced/Optional]** (not in the RHEL 10 objectives) · common in production and compliance work
> **Related:** [Disks & partitioning](disks-and-partitioning.md) · [Mounting & fstab](mounting-and-fstab.md) · [LVM fundamentals](lvm-fundamentals.md) · [Stratis](stratis.md)

## 1. Overview

**LUKS** (Linux Unified Key Setup) encrypts a block device with **dm-crypt**. Data is encrypted with a random **master (volume) key**. That key is stored in the on-disk **LUKS header**, wrapped by up to 32 **keyslots** (passphrases or key files). Opening the device maps a decrypted view at `/dev/mapper/<name>`, which you format and mount normally. RHEL uses **LUKS2** by default.

`````
/dev/vdb (LUKS header + encrypted data) --cryptsetup open--> /dev/mapper/secure (plaintext view) --> mkfs/mount
`````

**It protects data at rest** (stolen disk, decommissioned drive), not a running, unlocked system.

## 2. Key Commands

| Task | Command |
|---|---|
| Initialize (⚠️ destroys data) | `cryptsetup luksFormat /dev/vdb` (type `YES`, set passphrase) |
| Is it LUKS? | `cryptsetup isLuks /dev/vdb && echo yes` |
| Open (unlock) | `cryptsetup open /dev/vdb secure` (old: `luksOpen`) |
| Status | `cryptsetup status secure` |
| Close (lock) | `cryptsetup close secure` (old: `luksClose`) |
| Header and keyslots | `cryptsetup luksDump /dev/vdb` |
| Add a key | `cryptsetup luksAddKey /dev/vdb [keyfile]` |
| Change a passphrase | `cryptsetup luksChangeKey /dev/vdb` |
| Remove a key | `cryptsetup luksRemoveKey /dev/vdb` / `luksKillSlot /dev/vdb N` |
| Back up the header | `cryptsetup luksHeaderBackup /dev/vdb --header-backup-file /root/vdb-luks.hdr` |
| Restore the header | `cryptsetup luksHeaderRestore /dev/vdb --header-backup-file /root/vdb-luks.hdr` |

## 3. Procedure

````bash
dnf install -y cryptsetup                       # usually preinstalled
lsblk -f                                        # confirm the target is empty/unused
cryptsetup luksFormat /dev/vdb                  # ⚠️ irreversible for existing data
cryptsetup open /dev/vdb secure
mkfs.xfs /dev/mapper/secure
mkdir -p /secure ; mount /dev/mapper/secure /secure
cryptsetup luksHeaderBackup /dev/vdb --header-backup-file /root/vdb-luks.hdr   # store OFF the disk
````

### Unlock automatically at boot (key file)

````bash
( umask 077 ; dd if=/dev/urandom of=/etc/luks-vdb.key bs=4096 count=1 )
chmod 0400 /etc/luks-vdb.key
cryptsetup luksAddKey /dev/vdb /etc/luks-vdb.key          # asks for an existing passphrase
cryptsetup luksDump /dev/vdb | grep -i keyslot            # two keyslots in use now

LUKS_UUID=$(cryptsetup luksUUID /dev/vdb)
echo "secure UUID=$LUKS_UUID /etc/luks-vdb.key luks" >> /etc/crypttab
echo "/dev/mapper/secure /secure xfs defaults 0 0" >> /etc/fstab
systemctl daemon-reload
reboot                                                    # verify: lsblk -f ; df -hT /secure
````

**`/etc/crypttab` fields:** `<name> <device> <keyfile|none> <options>`. Use `none` to be prompted for the passphrase at boot (console required). Add `nofail` to the crypttab and fstab options for non-essential volumes.

> ⚠️ A key file stored on an **unencrypted** root disk only protects this volume if the disk is stolen *alone*. For full protection, encrypt root too, or use NBDE (Clevis + Tang) or TPM2.

## 4. Removing Encryption Setup

````bash
umount /secure ; cryptsetup close secure
# delete the lines from /etc/crypttab and /etc/fstab, then: systemctl daemon-reload
cryptsetup erase /dev/vdb      # ⚠️ wipes all keyslots → data permanently unrecoverable
wipefs -a /dev/vdb             # remove the LUKS signature to reuse the disk
````

## 5. Layering **[Advanced]**

| Layout | When |
|---|---|
| **LVM on LUKS** (encrypt the PV) | One passphrase for many LVs (RHEL installer's "Encrypt my data") |
| **LUKS on LVM** (encrypt individual LVs) | Different keys per volume |
| LUKS under VDO | ✘ Encrypted data doesn't dedupe; put encryption **above** VDO |

**NBDE:** `clevis luks bind -d /dev/vdb tang '{"url":"http://tang.example.com"}'` unlocks automatically while the server can reach a Tang server. `clevis luks bind … tpm2 '{}'` binds to the local TPM. Enable `clevis-luks-askpass` / regenerate initramfs (`dracut -f`) for root volumes.

## 6. Production Practices **[Production Practice]**

- **Back up the LUKS header**: a corrupted header without a backup means permanent data loss.
- Keep at least **two** keyslots (e.g., an admin passphrase in a vault plus an automation key).
- Never delete the last working key; check with `luksDump` first.
- Use `cryptsetup luksUUID` and `UUID=` in crypttab; device names can change.
- Test reboot behavior in a maintenance window; a missing key can stop the boot.

## 7. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `No key available with this passphrase` | Wrong key/passphrase | Try other keyslots; restore header backup if corrupted |
| Boot waits for a passphrase / hangs | crypttab `none` or bad keyfile path | Console unlock; fix crypttab; `nofail` for non-critical volumes |
| `Device secure already exists` | Already opened | `cryptsetup status secure`; `close` first |
| Emergency mode after reboot | crypttab/fstab typo | Fix entries from the emergency shell; `systemctl daemon-reload` |
| Data unreadable after "reformat" | `luksFormat` on the wrong disk | Restore from backups (and header backup, if the header alone was damaged) |

## 8. Interview Questions

| Question | Answer |
|---|---|
| Where is the encryption key stored? | The master key is in the on-disk LUKS header, wrapped by keyslots (passphrases/key files). |
| How do you change a passphrase without re-encrypting? | `luksChangeKey` (or `luksAddKey` + `luksRemoveKey`); only the keyslot changes. |
| What does `/etc/crypttab` do? | Tells systemd which LUKS devices to open at boot, with which key. |
| Why back up the header? | Header damage makes the data unrecoverable even with the right passphrase. |
| How do servers unlock without a person at the console? | NBDE (Clevis + Tang) or TPM2 binding. |

## 9. Quick Revision

````bash
cryptsetup luksFormat DEV | open DEV NAME | status NAME | close NAME | luksDump DEV | isLuks DEV
luksAddKey DEV KEYFILE | luksChangeKey DEV | luksRemoveKey DEV | luksHeaderBackup DEV --header-backup-file F
crypttab: NAME UUID=<luksUUID> /etc/key luks ; fstab: /dev/mapper/NAME MNT xfs defaults 0 0 ; daemon-reload
key file: umask 077 ; dd if=/dev/urandom … ; chmod 0400 · erase + wipefs to decommission
````

## 10. Cross-References

- [Disks & partitioning](disks-and-partitioning.md)
- [Mounting & fstab](mounting-and-fstab.md)
- [LVM fundamentals](lvm-fundamentals.md)
- [Stratis](stratis.md)
