# 088 · LUKS Disk Encryption

> **You need first:** [087 · RAID with mdadm](087-raid-mdadm.md)
> **Next:** [089 · XFS quotas](089-xfs-quotas.md)

---

## What it is

**LUKS** (Linux Unified Key Setup) is the standard way to **encrypt a whole block device** (a disk, partition or LV) on Linux. The kernel's **dm-crypt** device-mapper target does the encryption; the **`cryptsetup`** tool manages it.

- Opening (unlocking) the device creates a **decrypted view**, `/dev/mapper/<name>`, that you format and mount normally. Everything written to it is encrypted on the real disk.
- RHEL uses **LUKS2** by default.
- **It protects data at rest**: a stolen laptop, a pulled disk, a decommissioned drive, a snapshot copied out of a cloud account. It does **not** protect a running, unlocked system; once mounted, files are readable as normal.

Words:
- **Master key** (volume key): the random key that actually encrypts the data (AES-XTS by default, topic 064).
- **Keyslot**: one of up to 32 slots in the **LUKS header**, each holding the master key **wrapped** (encrypted) by a passphrase or a key file.
- **LUKS header**: the metadata at the start of the device: cipher settings and keyslots.
- **`/etc/crypttab`**: tells the system which encrypted devices to unlock at boot.
- **NBDE** (Network-Bound Disk Encryption): automatic unlocking when the server can reach a trusted key server (**Tang**), using the **Clevis** client. Unlocking can also be bound to the local **TPM** (Trusted Platform Module, a security chip on the motherboard).

## Why it exists

Disks leave your control all the time: laptops get stolen, failed drives go back to vendors, servers are decommissioned, cloud volumes get snapshotted. Without encryption, anyone can read the data by attaching the disk elsewhere. Many regulations (GDPR, PCI-DSS, HIPAA) expect encryption at rest.

## Analogy

The data is a **safe's contents**, locked with **one master combination** (the master key). Instead of telling everyone the master combination, you keep it inside a **small lockbox with several keyholes** (the header with keyslots): the admin's key opens one keyhole, the automation key file opens another, and each reveals the same master combination. Changing someone's key only changes their keyhole; the safe never needs re-locking. **Lose the lockbox (header), and nobody can ever open the safe again**, which is why you keep a spare.

## How it works inside

1. `cryptsetup luksFormat` writes a header, generates a random **master key**, and stores it in **keyslot 0**, encrypted with a key derived from your passphrase. The derivation uses **Argon2**, a deliberately slow, memory-hungry function that makes guessing passphrases expensive.
2. `cryptsetup open` asks for a passphrase or key file, tries the keyslots, recovers the master key, and creates a **dm-crypt** device-mapper device (topic 049) that encrypts and decrypts every block on the fly.
3. **Changing or adding a passphrase** only changes keyslots; the data is never re-encrypted.
4. At boot, `systemd-cryptsetup` reads `/etc/crypttab` and unlocks each device (prompting on the console if needed); then fstab mounts the `/dev/mapper/…` device.
5. **If the header is damaged**, the master key is gone and the data is unrecoverable, even with the right passphrase. Back up the header.

**Layering choices:**

| Layout | Use |
|---|---|
| **LVM on LUKS** (encrypt the PV) | One unlock for many LVs: the RHEL installer's "Encrypt my data" |
| **LUKS on LVM** (encrypt individual LVs) | Different keys per volume |
| disk → LUKS → **VDO** → filesystem (topic 090) | Encrypted data looks random and can't be deduplicated, so VDO must sit on top of LUKS, where it still sees plaintext |

## Commands

```bash
sudo dnf install -y cryptsetup          # usually already installed
lsblk -f                                # confirm the target is EMPTY
sudo cryptsetup luksFormat /dev/vdb
```
```
WARNING!
========
This will overwrite data on /dev/vdb irrevocably.

Are you sure? (Type 'yes' in capital letters): YES
Enter passphrase for /dev/vdb:
Verify passphrase:
```

```bash
sudo cryptsetup open /dev/vdb secure
sudo mkfs.xfs /dev/mapper/secure
sudo mkdir -p /secure ; sudo mount /dev/mapper/secure /secure
lsblk -f /dev/vdb
```
```
NAME       FSTYPE      FSVER LABEL UUID                                 MOUNTPOINTS
vdb        crypto_LUKS 2           5b0e…-…-…
└─secure   xfs                     9c1d…-…-…                            /secure
```
- `vdb` is the encrypted device (`crypto_LUKS`); `secure` is the decrypted view holding XFS.

```bash
sudo cryptsetup luksDump /dev/vdb | sed -n '1,12p;/Keyslots/,/^Tokens/p'
```
```
LUKS header information
Version:       	2
UUID:          	5b0e…
Data segments:
  0: crypt
	cipher: aes-xts-plain64
...
Keyslots:
  0: luks2
	Key:        512 bits
	PBKDF:      argon2id
...
```
- The cipher (`aes-xts-plain64`), the key size, and how each keyslot derives its key (`argon2id`).

### Back up the header (do this immediately)

```bash
sudo cryptsetup luksHeaderBackup /dev/vdb --header-backup-file /root/vdb-luks.hdr
```
Store it **off** this disk (a vault, another system). Restore with `luksHeaderRestore`.

### Keys

| Task | Command |
|---|---|
| Add a passphrase or key file | `cryptsetup luksAddKey /dev/vdb [KEYFILE]` |
| Change a passphrase | `cryptsetup luksChangeKey /dev/vdb` |
| Remove a key | `cryptsetup luksRemoveKey /dev/vdb` or `luksKillSlot /dev/vdb N` |
| Status of an open device | `cryptsetup status secure` |
| Lock it | `umount /secure; cryptsetup close secure` |

Always keep **at least two** working keys, and check with `luksDump` before removing one. Removing the last key = losing the data.

### Unlock automatically at boot with a key file

```bash
( umask 077 ; sudo dd if=/dev/urandom of=/etc/luks-vdb.key bs=4096 count=1 )
sudo chmod 0400 /etc/luks-vdb.key
sudo cryptsetup luksAddKey /dev/vdb /etc/luks-vdb.key
echo "secure UUID=$(sudo cryptsetup luksUUID /dev/vdb) /etc/luks-vdb.key luks,nofail" | sudo tee -a /etc/crypttab
echo "/dev/mapper/secure /secure xfs defaults,nofail 0 0" | sudo tee -a /etc/fstab
sudo systemctl daemon-reload
```
- `/etc/crypttab` fields: `<name> <device> <keyfile|none> <options>`. `none` = ask for the passphrase at boot (needs someone at the console).
- **A key file on an unencrypted root disk** only protects this volume if the data disk is stolen **alone**. For real protection, encrypt root too, or use NBDE/TPM2.

### NBDE and TPM2 (servers that unlock themselves)

```bash
sudo dnf install -y clevis clevis-luks clevis-dracut
sudo clevis luks bind -d /dev/vdb tang '{"url":"http://tang.example.com"}'
sudo clevis luks bind -d /dev/vdb tpm2 '{}'
sudo dracut -f                         # needed for root volumes (unlock inside the initramfs)
```
- With Tang: the disk unlocks automatically **only while the server can reach the Tang server** on your network. A stolen disk or server, away from that network, stays locked.

### Decommission

```bash
sudo umount /secure ; sudo cryptsetup close secure
# remove its lines from /etc/crypttab and /etc/fstab; systemctl daemon-reload
sudo cryptsetup erase /dev/vdb      # ⚠️ wipes all keyslots → data unrecoverable instantly
sudo wipefs -a /dev/vdb
```
- `erase` is a **fast cryptographic wipe**: destroying the keyslots makes the encrypted data permanently unreadable, without overwriting the whole disk.

### Try it
1. Encrypt a lab disk, put XFS on it, write files, back up the header.
2. Add a key file and configure crypttab + fstab; reboot and confirm it auto-unlocks.
3. Change the passphrase with `luksChangeKey`; confirm the files are untouched.
4. Corrupt the header in a **throwaway** lab (`dd if=/dev/zero of=/dev/vdb bs=1M count=16`), see that it won't open, then restore it from the header backup.

## Where you'll use it

- **Laptops and workstations:** full-disk encryption at install time.
- **Servers with sensitive data:** LUKS + NBDE (Tang) or TPM2, so reboots don't need a human.
- **Cloud:** providers encrypt volumes at rest by default (with KMS keys). LUKS inside the VM adds a layer the cloud admin can't open.
- **Kubernetes:** some CSI drivers can create LUKS-encrypted volumes per PVC; etcd's own encryption-at-rest covers Secrets.
- **Disk disposal:** `cryptsetup erase` makes "wipe before returning the drive" instant.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `No key available with this passphrase` | Wrong passphrase or key, or a damaged header | Try other keys; restore the header backup |
| The boot waits for a passphrase, or hangs | crypttab says `none`, or a wrong key file path | Unlock at the console; fix crypttab; `nofail` for non-critical volumes |
| `Device secure already exists` | It's already open | `cryptsetup status secure`; close it first |
| Emergency mode after reboot | A crypttab or fstab typo | Fix it from the emergency shell (topic 057) |
| Clevis doesn't unlock at boot | Tang unreachable, network not up in the initramfs, or `dracut -f` missing | Check network/Tang; rebuild the initramfs |
| Data unreadable after "reformatting" | `luksFormat` on the wrong disk | Restore from backups (always check `lsblk` first) |

## Quick recap

- LUKS + dm-crypt encrypt a block device; `cryptsetup open DEV NAME` → `/dev/mapper/NAME` (format and mount it).
- A random master key lives in the **header**, wrapped by up to 32 **keyslots**. Change keys without re-encrypting. **Back up the header.**
- Boot unlock: `/etc/crypttab` (`name UUID=… keyfile|none luks`) + fstab on `/dev/mapper/NAME`; servers use Clevis + Tang or TPM2.
- Protects data **at rest** only. `cryptsetup erase` = instant secure wipe.

**Interview questions**

1. *Where is the LUKS encryption key stored?* The random master key is stored in the on-disk LUKS header, encrypted separately in each keyslot by a passphrase- or key-file-derived key.
2. *How do you change a LUKS passphrase without re-encrypting the disk?* `cryptsetup luksChangeKey` (or add a new key and remove the old one). Only the keyslot changes; the master key and data stay the same.
3. *How can an encrypted server reboot without someone typing a passphrase?* Network-Bound Disk Encryption (Clevis + Tang), which unlocks only while the trusted Tang server is reachable, or binding the key to the machine's TPM2 chip.
