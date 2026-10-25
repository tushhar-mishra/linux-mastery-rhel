# Cryptography Basics for Linux Admins

> **[Interview Knowledge]** · background for SSH, TLS, LUKS, RPM signatures, password hashing
> **Related:** [SSH remote access](ssh-remote-access.md) · [SSH hardening (crypto policies)](ssh-server-hardening.md) · [LUKS](../storage-and-filesystems/luks-encryption.md) · [Passwords & hashing](../users-groups-and-permissions/passwords-and-aging.md) · [RPM signatures](../logs-scheduling-and-packages/rpm-and-dnf-package-management.md)

## 1. Goals

| Goal | Provided by |
|---|---|
| **Confidentiality** (only intended parties can read) | Encryption |
| **Integrity** (data wasn't changed) | Hashes, MACs, signatures |
| **Authentication** (who sent it / who is this server) | Signatures, certificates, keys |
| **Non-repudiation** | Digital signatures |

**Encryption** turns plaintext into ciphertext with an algorithm and a key; **decryption** reverses it with the right key.

## 2. Symmetric Encryption

One **shared secret key** encrypts and decrypts.

| Pros | Cons |
|---|---|
| Very fast, good for bulk data | Both sides must share the key securely (key distribution problem) |

| Algorithm | Status |
|---|---|
| **AES** (128/256, e.g., AES-GCM) | Standard choice (LUKS, TLS, SSH, VPNs) |
| **ChaCha20-Poly1305** | Modern, fast in software (SSH, TLS) |
| DES / 3DES | **Broken / deprecated** |
| Blowfish, Twofish | Legacy / niche |

## 3. Asymmetric (Public-Key) Encryption

A **key pair**: the public key can be shared, the private key stays secret.

- **Encryption:** encrypt with the recipient's **public** key → only their **private** key decrypts.
- **Signatures:** sign with your **private** key → anyone verifies with your **public** key.

| Algorithm | Use |
|---|---|
| **RSA** (≥ 3072/4096 bits recommended) | Encryption, signatures (legacy-compatible) |
| **ECC**: **Ed25519**, ECDSA | Signatures (SSH keys default: Ed25519) |
| (EC)DH / X25519 | Key exchange (agree on a shared secret over an insecure channel) |
| DSA | **Obsolete**; removed from modern OpenSSH |

Asymmetric operations are slow, so real protocols are **hybrid**: asymmetric key exchange and authentication, then symmetric encryption for the data. SSH and TLS both work this way. Modern OpenSSH also supports post-quantum hybrid key exchange.

## 4. Hashing (not encryption)

A **hash** maps any data to a fixed-size digest. It's one-way, and any change produces a different digest.

| Use | Example |
|---|---|
| File integrity | `sha256sum file` / `sha256sum -c SHA256SUMS` |
| Password storage | Salted, slow hashes: yescrypt / SHA-512 crypt in `/etc/shadow` |
| Signatures | Sign the hash of a message |

MD5 and SHA-1 are broken for security; use SHA-256 or better.

## 5. Signatures, Certificates & PKI

- A **digital signature** proves who signed and that the content is unchanged (RPM package GPG signatures, signed kernels and Secure Boot).
- An **X.509 certificate** binds a public key to an identity, signed by a **Certificate Authority** (TLS for HTTPS). RHEL's trusted CAs: `/etc/pki/ca-trust/` (`update-ca-trust`).

## 6. Where RHEL Uses It

| Area | Crypto |
|---|---|
| SSH | Host/user keys (Ed25519/ECDSA/RSA), ECDH/post-quantum hybrid key exchange, AES/ChaCha20 |
| HTTPS / TLS | Certificates + key exchange + AES-GCM |
| LUKS | AES-XTS with keys protected by passphrase-derived keyslots |
| dnf / rpm | GPG signatures (`gpgcheck=1`, `rpm -K`) |
| `/etc/shadow` | Salted slow password hashes |
| System-wide policy | `update-crypto-policies --show` / `--set DEFAULT\|FUTURE\|FIPS` |

````bash
sha256sum rhel-10.iso                          # integrity check
openssl rand -base64 32                        # random secret
gpg -c secret.txt ; gpg -d secret.txt.gpg      # symmetric file encryption [Advanced]
openssl s_client -connect www.redhat.com:443 </dev/null | head   # inspect a TLS handshake [Advanced]
````

## 7. Interview Questions

| Question | Answer |
|---|---|
| Symmetric vs asymmetric? | One shared key (fast) vs a public/private pair (solves key distribution, slower). |
| Why do SSH and TLS use both? | Asymmetric crypto to authenticate and agree on a session key; symmetric crypto for fast bulk encryption. |
| Hashing vs encryption? | Hashing is one-way (integrity, passwords); encryption is reversible with a key. |
| What's a digital signature? | A hash encrypted (signed) with a private key, verifiable with the public key. |
| Why salt password hashes? | Identical passwords produce different hashes; precomputed tables become useless. |

## 8. Quick Revision

````
CIA: confidentiality (encryption) · integrity (hash/MAC/signature) · authentication (keys/certs)
symmetric: AES, ChaCha20 (fast; shared key) · asymmetric: RSA, Ed25519/ECDSA, X25519 (key pair) · hybrid = both
hash: SHA-256 (MD5/SHA-1 broken) · passwords: salted yescrypt/SHA-512 · update-crypto-policies --show
````

## 9. Cross-References

- [SSH remote access](ssh-remote-access.md)
- [SSH hardening (crypto policies)](ssh-server-hardening.md)
- [LUKS](../storage-and-filesystems/luks-encryption.md)
- [Passwords & hashing](../users-groups-and-permissions/passwords-and-aging.md)
- [RPM signatures](../logs-scheduling-and-packages/rpm-and-dnf-package-management.md)
