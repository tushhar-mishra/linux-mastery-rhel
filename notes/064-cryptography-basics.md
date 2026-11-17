# 064 · Cryptography Basics for Operators

> **You need first:** [063 · Name resolution and DNS](063-name-resolution-and-dns-client.md)
> **Next:** [065 · SSH](065-ssh.md)

---

## What it is

**Cryptography** is the maths that keeps data secret and trustworthy. You don't need to do the maths, but you do need the vocabulary, because SSH, HTTPS, package signing, disk encryption and Kubernetes certificates all rely on it.

| Term | Plain meaning |
|---|---|
| **Plaintext / ciphertext** | Readable data / scrambled data |
| **Key** | The secret value that controls the scrambling |
| **Encryption / decryption** | Plaintext → ciphertext / back again (needs the right key) |
| **Symmetric encryption** | **One shared key** both encrypts and decrypts (AES, ChaCha20) |
| **Asymmetric (public-key) encryption** | A **key pair**: a **public key** you can share with anyone and a **private key** you never share (RSA, Ed25519) |
| **Hash** | A fixed-size "fingerprint" of any data. One-way: you can't get the data back (SHA-256) |
| **Digital signature** | Proof that a specific private-key holder produced or approved some data, and that it hasn't changed since |
| **Certificate** (X.509) | A document binding a public key to a name (like `www.example.com`), **signed by a CA** |
| **CA** (Certificate Authority) | An organisation (or internal service) whose signature makes certificates trusted |
| **PKI** (Public Key Infrastructure) | The whole system of CAs, certificates and trust stores |
| **TLS** (Transport Layer Security) | The protocol that encrypts HTTPS and many other connections (topic 070). "SSL" is its old, broken predecessor; people still say "SSL certificate" |
| **Key exchange** | How two sides agree on a secret key over an open network without sending it (Diffie–Hellman, X25519) |

## Why it exists

Networks are untrusted: anyone in the path could read or change traffic. Cryptography gives:

| Goal | Provided by |
|---|---|
| **Confidentiality**: only the intended reader can read it | Encryption |
| **Integrity**: nobody changed it | Hashes, MACs (message authentication codes), signatures |
| **Authentication**: it really is the server/person/vendor you think | Signatures, certificates, keys |
| **Non-repudiation**: the signer can't deny signing | Digital signatures |

## Analogy

- **Symmetric key** = a **house key**: the same key locks and unlocks. Fast, but you must somehow get a copy to your friend safely.
- **Public/private key pair** = a **post box with a slot**. Anyone can drop a letter in (encrypt with the **public** key); only the owner with the box key (the **private** key) can open it.
- **Signature** = a **wax seal from a signet ring**. Only the ring owner (private key) can make it; anyone who knows the seal's design (public key) can check it's genuine and unbroken.
- **Certificate** = a **passport**: your photo (public key) + your name, stamped by a government (CA) that everyone trusts.
- **Hash** = a **fingerprint**: tiny, unique to the person, and you can't rebuild the person from it.

## How it works inside

### Symmetric vs asymmetric

| | Symmetric | Asymmetric |
|---|---|---|
| Keys | One shared secret | Public + private pair |
| Speed | **Very fast**: bulk data | Slow: small amounts only |
| Problem | How do both sides get the key safely? | Solves that problem |
| Algorithms | **AES** (e.g. AES-256-GCM), **ChaCha20-Poly1305**. DES/3DES are broken | **RSA** (3072+ bits), **Ed25519**/ECDSA (elliptic-curve signatures), **X25519** (key exchange). DSA is obsolete |

### Real protocols are hybrid (SSH, TLS)

1. **Key exchange** (asymmetric maths, X25519/ECDH): both sides create a **shared session key** without ever sending it over the wire. Each session gets fresh keys ("forward secrecy": stealing the server's key later can't decrypt old recordings).
2. **Authentication** (signatures): the server proves its identity by signing with its **private** key. The client checks it with the server's **public** key, which the client trusts either directly (SSH `known_hosts`) or through a **CA-signed certificate** (TLS).
3. **Bulk encryption** (symmetric, AES-GCM or ChaCha20) with the session key: fast, with built-in integrity checks.

Modern OpenSSH (RHEL 10) even includes **post-quantum hybrid** key exchange, to protect against future quantum computers.

### Hashes

A good hash (SHA-256, SHA-512) has three properties: the same input gives the same output; a one-bit change gives a completely different output; and you can't find two inputs with the same hash or reverse it. **MD5 and SHA-1 are broken** for security use.
- **File integrity:** compare a download's `sha256sum` with the published value.
- **Passwords:** stored as **salted, deliberately slow** hashes (yescrypt in `/etc/shadow`, topic 023), so guessing is expensive.

### Signatures

To sign: hash the data, then encrypt the hash with the **private** key. To verify: decrypt the signature with the **public** key and compare it with your own hash of the data. A match means the right key signed it **and** the data is unchanged. This is how **RPM packages** (`gpgcheck=1`, topic 031), **Secure Boot** (topic 053), **container images** (cosign/sigstore) and **Git commits** are verified.

### Certificates and the chain of trust

A server certificate contains the server's **public key**, its **names** (in the SAN, Subject Alternative Name, field), a **validity period**, and the **issuer's signature**. Your system trusts a set of **root CAs** (on RHEL in `/etc/pki/ca-trust/`; on Ubuntu `/etc/ssl/certs/`). Usually: root CA → **intermediate CA** → server certificate. The client checks that:
1. every signature in the chain is valid and leads to a trusted root;
2. the certificate hasn't expired;
3. the **name you connected to** matches a name in the certificate.

Failure of any one → "certificate verify failed".

### System-wide crypto policy (RHEL)

RHEL sets which algorithms every library (OpenSSL, GnuTLS, NSS, OpenSSH, libssh) may use, through one policy: `DEFAULT`, `FUTURE` (stricter), `LEGACY` (allows old algorithms) or `FIPS` (US government-approved algorithms only). That's why an ancient client may suddenly be refused after an upgrade.

## Commands

```bash
sha256sum rhel-10.1-x86_64-dvd.iso
sha256sum -c SHA256SUMS
```
```
c1d4f8e0a7…9b2e  rhel-10.1-x86_64-dvd.iso
rhel-10.1-x86_64-dvd.iso: OK
```
- Compare with the vendor's published checksum. `-c` checks a whole file of checksums.

```bash
echo -n "hello" | sha256sum ; echo -n "hellp" | sha256sum
```
```
2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824  -
fdd7585e08c4e2afd71dcabdb4636c89d557a3f42db9e2040c8bbd1708aa4ce7  -
```
- One letter changed → a completely different hash.

```bash
openssl rand -base64 32
```
```
q3Jb5Vh0hB4lFv2sYw9cE7Ff1m5x0Gq3oTzJr8pWm6A=
```
- A strong random secret (API tokens, passwords for services).

```bash
update-crypto-policies --show
```
```
DEFAULT
```

```bash
gpg -c secret.txt          # symmetric: encrypt a file with a passphrase → secret.txt.gpg
gpg -d secret.txt.gpg      # decrypt
```

### Look at a certificate

```bash
openssl s_client -connect www.redhat.com:443 -servername www.redhat.com </dev/null 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates -ext subjectAltName
```
```
subject=jurisdictionC=US, jurisdictionST=Delaware, businessCategory=Private Organization, serialNumber=2945436, C=US, ST=North Carolina, L=Raleigh, O=Red Hat, LLC, CN=www.redhat.com
issuer=C=US, O=DigiCert Inc, CN=DigiCert EV RSA CA G2
notBefore=Aug 24 00:00:00 2026 GMT
notAfter=Mar 10 23:59:59 2027 GMT
X509v3 Subject Alternative Name:
    DNS:www.redhat.com
```
- **Subject/SAN** = which names it's valid for. **Issuer** = the CA that signed it. **notBefore/notAfter** = the validity window. Expired certificates are one of the most common production outages.
- This is an **EV** (Extended Validation) certificate, so its subject also lists the company's legal details. Browsers and clients only check the names in the SAN; the `CN` is legacy.

### Make a self-signed certificate (labs)

```bash
openssl req -x509 -newkey rsa:3072 -nodes -days 365 \
  -keyout /tmp/lab.key -out /tmp/lab.crt -subj "/CN=server1.example.com" \
  -addext "subjectAltName=DNS:server1.example.com"
openssl x509 -in /tmp/lab.crt -noout -subject -enddate
```
- `-x509` = self-signed; `-nodes` = don't encrypt the private key with a passphrase. Clients won't trust it unless you add it to their trust store.

### Trust an internal CA

```bash
sudo cp corp-root-ca.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust
```
- Ubuntu: copy to `/usr/local/share/ca-certificates/` (the file must end in `.crt`) and run `sudo update-ca-certificates`.

### Try it
1. Download any file and its published SHA-256 and verify it.
2. Inspect the certificates of three websites; note their issuers and expiry dates.
3. Create a self-signed certificate and look at it with `openssl x509 -text -noout`.
4. Encrypt and decrypt a file with `gpg -c`.

**Check your work:** on your lab VM, from the notes folder, run `sudo ./checks/check 064` for every step, or `sudo ./checks/check 064 STEP` for one (topic 002 shows how to get the notes there).

## Where you'll use it

- **SSH keys** (topic 065): Ed25519 key pairs, host-key verification.
- **HTTPS everywhere** (topics 070, 078): certificates, renewals (Let's Encrypt with certbot or cert-manager), "certificate expired" incidents.
- **Kubernetes:** the API server, kubelets and etcd all talk over **mutual TLS** (both sides present certificates). `kubeadm certs check-expiration` exists because expired cluster certificates take clusters down. Secrets, service-mesh mTLS and image signing are the same basics.
- **Package and image trust:** GPG-signed RPMs, signed container images.
- **Secrets management:** Vault and cloud KMS (Key Management Service) store and use keys so they never sit in plain files.
- **Disk encryption:** LUKS (topic 088).

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `certificate verify failed: unable to get local issuer certificate` | An internal or private CA isn't trusted, or the server doesn't send its intermediate | Add the CA (`update-ca-trust`); fix the server's chain |
| `certificate has expired` | Past `notAfter` | Renew; automate renewals; monitor expiry |
| Hostname mismatch | The name you used isn't in the SAN | Use the right name, or reissue the certificate with it |
| Old clients can't connect after an upgrade | The crypto policy forbids old algorithms | Upgrade the clients; as a last resort `update-crypto-policies --set LEGACY` (weakens security) |
| A checksum doesn't match | Corrupted or tampered download | Download again from a trusted source |
| Time-related TLS failures | The system clock is wrong | Fix time sync (topic 069) |

## Quick recap

- Symmetric (AES/ChaCha20) = one key, fast. Asymmetric (RSA/Ed25519/X25519) = public + private keys, solves key distribution. Real protocols are **hybrid**.
- Hash (SHA-256) = one-way fingerprint for integrity and password storage. Signature = a hash signed with a private key, verified with the public key.
- Certificate = public key + names + validity + CA signature. Trust = a chain up to a root in `/etc/pki/ca-trust/`.
- Tools: `sha256sum`, `openssl s_client`/`x509`/`req`/`rand`, `gpg`, `update-ca-trust`, `update-crypto-policies`.

**Interview questions**

1. *Symmetric vs asymmetric encryption?* Symmetric uses one shared key and is fast; asymmetric uses a public/private pair, which solves key distribution but is slow. Protocols use asymmetric crypto to authenticate and agree a session key, then symmetric crypto for the data.
2. *Hashing vs encryption?* Hashing is one-way and fixed-size, used for integrity and password storage. Encryption is reversible with the right key, used for confidentiality.
3. *What does a client check when validating a TLS certificate?* That the signature chain leads to a trusted root CA, that the certificate is within its validity dates, and that the requested hostname matches the certificate's SAN.

**Scenario question** (answer out loud first, then compare)

> *"A TLS service's clients started failing this morning with certificate errors. How do you diagnose it from a Linux box?"*

**Model answer:**
1. `openssl s_client -connect host:443 -servername host -showcerts </dev/null` shows the chain the server sends and the verify result.
2. Check the leaf certificate: `openssl x509 -noout -dates -subject -issuer -ext subjectAltName`.
   - **Expired?** `notAfter` passed.
   - **Name mismatch?** The hostname isn't in the SAN.
3. **Incomplete chain:** the server sends the leaf but not the intermediate. Browsers may cope; `curl` and other tools fail with "unable to get local issuer certificate".
4. **Client trust:** a new private CA must be in the client's store (`/etc/pki/ca-trust/source/anchors/` + `update-ca-trust`).
5. **Policy:** `update-crypto-policies --show`. Older SHA-1 or small RSA keys are refused by the DEFAULT policy on RHEL.
6. **Clock** on the client: a wrong date makes valid certificates look expired or not yet valid.

**Likely follow-ups:**
- *What's a hash used for in a signature?* The hash of the data is signed with the private key; anyone verifies it with the public key.
- *Why do protocols use both asymmetric and symmetric crypto?* Asymmetric to authenticate and agree a key; symmetric because it's fast for bulk data.
