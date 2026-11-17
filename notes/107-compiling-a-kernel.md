# 107 · Compiling a Kernel

> **You need first:** [106 · Building RPM packages](106-building-rpm-packages.md) (and topics 053–055 boot, GRUB, modules)
> **Next:** [108 · Image Builder](108-image-builder.md)

---

## What it is

Building the Linux kernel **from source** (kernel.org, or a patched tree) instead of installing Red Hat's packaged kernel.

| | Packaged kernel (`dnf`) | Self-compiled kernel |
|---|---|---|
| Source | Red Hat, built and **signed** | kernel.org or your patches |
| Support | Fully supported; security updates | **Unsupported**: you maintain it |
| Secure Boot | Signed: boots normally | **Unsigned: won't boot** until signed with an enrolled key |
| Use | Production | Learning, testing new features or drivers, kernel development |

Words:
- **`.config`**: the kernel build configuration: thousands of `CONFIG_…` options, each `y` (built in), `m` (built as a loadable module, topic 055) or `n` (left out).
- **kABI** (kernel Application Binary Interface): RHEL's promise that the kernel's interface for third-party modules stays stable for a whole major release. A custom kernel loses it.
- **MOK** (Machine Owner Key): your own key, enrolled in shim's database, so Secure Boot trusts what you sign (topic 053).

## Why it exists

You'll rarely do this in production, but it is the best way to really understand:
- what the kernel and its modules are;
- how `/boot`, the initramfs and the boot entries fit together;
- what "built in vs module" means;
- why Secure Boot matters.

It's also required for kernel development, for testing a fix from upstream before your distribution ships it, and for unusual hardware or embedded systems.

## Analogy

Installing the packaged kernel is **buying a certified car from the dealer**: warranty, recalls handled, approved for the road. Compiling your own is **building a kit car in your garage**: educational, customisable, sometimes faster, but no warranty, no recall service, and the road authority (Secure Boot) won't let it out until you get it inspected and stamped (signed with an enrolled key).

## How it works inside

1. **Configure:** start from RHEL's own config (`/boot/config-$(uname -r)`). `make olddefconfig` answers new options with their defaults.
2. **Build:** `make -j$(nproc)` compiles the core kernel image (`arch/x86/boot/bzImage`) and every `=m` option as a `.ko` module. This needs a C compiler, `flex`/`bison` (parsers), `bc`, OpenSSL headers (module signing), libelf and `pahole` (from `dwarves`, for BTF debug info used by eBPF, topic 103).
3. **`make modules_install`**: copies the modules to `/lib/modules/VERSION/` and runs `depmod` to build the dependency map.
4. **`make install`**: copies `vmlinuz-VERSION`, `System.map` and `config` to `/boot`. On RHEL it calls **`kernel-install`**, which builds the **initramfs** (dracut) and creates a **BLS** (Boot Loader Specification) entry in `/boot/loader/entries/`, so GRUB shows the new kernel without running `grub2-mkconfig` (topic 054).
5. **Boot:** with Secure Boot on, shim checks the signature of `vmlinuz`. Unsigned → "invalid signature" / "bad shim signature". Sign it with `pesign`/`sbsign` and enrol your key with `mokutil`, or test in a VM with Secure Boot off.

**Always keep the RHEL kernel installed and as the default** until the new one has proven itself.

## Commands

### Prepare (take a VM snapshot first)

```bash
uname -r ; rpm -q kernel
sudo dnf group install -y "Development Tools"
sudo dnf install -y ncurses-devel bc flex bison openssl-devel elfutils-libelf-devel dwarves perl
df -h /home /boot            # the build needs ~20+ GB; /boot needs room for the new kernel + initramfs
```

### Get, configure, build

```bash
cd ~ && curl -LO https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.12.10.tar.xz
tar -xf linux-6.12.10.tar.xz && cd linux-6.12.10
cp /boot/config-$(uname -r) .config
make olddefconfig
scripts/config --set-str CONFIG_SYSTEM_TRUSTED_KEYS "" --set-str CONFIG_LOCALVERSION "-lab"    # drop RHEL's key paths; tag our build
make menuconfig              # optional: browse/change options in a text UI
make localmodconfig          # optional, small labs: keep only the modules loaded right now (much faster build)
time make -j"$(nproc)"
```
```
  CC      kernel/sched/core.o
  ...
  LD      vmlinux
  BUILD   arch/x86/boot/bzImage
Kernel: arch/x86/boot/bzImage is ready  (#1)

real	38m12.554s
```
- A build from the full distribution config takes from tens of minutes to over an hour, depending on CPUs, and needs 20+ GB of disk. On a 1-vCPU lab VM, even a `localmodconfig` build compiled only about 10% of the files in an hour, so give the VM several CPUs (`nproc`) before you start.
- `localmodconfig` builds a kernel that only supports the hardware and features in use **now**: plug in a new device or load a new filesystem later and its module won't exist. Fine for a lab, not for a fleet kernel.

### Install and boot

```bash
sudo make INSTALL_MOD_STRIP=1 modules_install      # strip debug info: much smaller modules and initramfs
sudo make install
ls /boot | grep 6.12.10 ; sudo grubby --info=ALL | grep -E '^(index|kernel)'
```
```
config-6.12.10-lab
initramfs-6.12.10-lab.img
System.map-6.12.10-lab
vmlinuz-6.12.10-lab
index=0
kernel="/boot/vmlinuz-6.12.10-lab"
index=1
kernel="/boot/vmlinuz-6.12.0-55.el10.x86_64"
```
- The new kernel, its initramfs and a boot entry. Keep the RHEL kernel as the default (`sudo grubby --set-default /boot/vmlinuz-6.12.0-55.el10.x86_64`), and choose the custom one from the GRUB menu for the first test.

```bash
sudo reboot
uname -r                     # 6.12.10-lab
```

### Remove it

```bash
sudo kernel-install remove 6.12.10-lab      # removes its BLS entry and /boot files
sudo rm -rf /lib/modules/6.12.10-lab
sudo grubby --default-kernel                # confirm a RHEL kernel is the default
```

### Secure Boot (overview)

```bash
mokutil --sb-state                          # SecureBoot enabled?
sudo mokutil --import my-signing-key.der    # enrol your key; confirm in MOK Manager at the next boot
# then sign vmlinuz (pesign / sbsign) and the modules (scripts/sign-file) with that key
```

### Try it
1. In a lab VM (snapshot first), build the current stable kernel from RHEL's config with `-lab` as the local version.
2. Boot it once from the GRUB menu, check `uname -r` and `lsmod`, then reboot into the RHEL kernel.
3. Remove the custom kernel cleanly.
4. With Secure Boot enabled in a UEFI VM, observe the refusal; then disable Secure Boot (lab) or sign and enrol.

**Check your work:** on your lab VM, from the notes folder, run `sudo ./checks/check 107` for every step, or `sudo ./checks/check 107 STEP` for one (topic 002 shows how to get the notes there).

## Where you'll use it

- **Kernel development and bug hunting:** testing an upstream fix, bisecting a regression (`git bisect` on the kernel tree).
- **Understanding:** the same pieces (modules, initramfs, BLS entries, Secure Boot) appear when you troubleshoot boots or third-party drivers (NVIDIA, storage HBAs, kernel modules built by **DKMS**).
- **Containers and Kubernetes:** containers share the host kernel (topic 099), so kernel version and config decide which features (cgroup v2, eBPF, overlayfs options) your nodes have. You'll check `CONFIG_…` options in `/boot/config-*` more often than you compile.
- **Production RHEL: don't.** Use the supported kernel; get features via newer minor releases or Red Hat support.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| Build stops with `pahole` / BTF errors | `dwarves` not installed | `dnf install dwarves` |
| `No rule to make target 'certs/rhel.pem'` | RHEL's signing-key paths are in the config | `scripts/config --set-str CONFIG_SYSTEM_TRUSTED_KEYS ""` |
| The new kernel won't boot: "invalid signature" | Secure Boot | Sign and enrol a key, or disable Secure Boot (lab) |
| Kernel panic: can't mount root | Storage/LVM/filesystem drivers missing, or a bad initramfs | Boot the RHEL kernel; fix the config; `dracut -f --kver VERSION` |
| `/boot` is full | Unstripped modules make a huge initramfs; too many kernels | `INSTALL_MOD_STRIP=1`; remove old kernels |
| Third-party module won't load on the custom kernel | Built for a different kernel/kABI | Rebuild the module against the new kernel headers (DKMS) |

## Quick recap

- Self-compiled kernels are **unsupported** on RHEL and **unsigned** (Secure Boot refuses them). Use them in labs.
- Steps: install build tools → get source → `cp /boot/config-$(uname -r) .config` → `make olddefconfig` → `make -j$(nproc)` → `make modules_install` → `make install` (kernel-install builds the initramfs and BLS entry).
- Keep the RHEL kernel as the default; remove with `kernel-install remove` + `rm -rf /lib/modules/VER`.

**Interview questions**

1. *Why shouldn't you run a self-compiled kernel on production RHEL?* You lose Red Hat support, security updates, the kABI guarantee for third-party modules, and Secure Boot signing.
2. *What does `make modules_install` do?* It installs the compiled `.ko` modules into `/lib/modules/VERSION/` and runs `depmod` to generate module dependency data.
3. *How do you base a custom kernel on your distribution's configuration?* Copy `/boot/config-$(uname -r)` to `.config` and run `make olddefconfig` to fill in defaults for options that are new in this kernel version.

**Scenario question** (answer out loud first, then compare)

> *"A colleague wants to compile a newer upstream kernel on production RHEL servers to get a driver fix. What do you say?"*

**Model answer:**
1. Don't run self-built kernels in production on RHEL:
   - Red Hat support for that system ends;
   - you lose Red Hat's security errata stream and the kABI guarantee for third-party modules;
   - the kernel isn't signed, so **Secure Boot** refuses it.
2. Alternatives, in order:
   - check whether the fix is already backported in a newer RHEL kernel (`rpm -q --changelog kernel | grep -i driver`);
   - ask the vendor or Red Hat for a supported driver (kmod, DUP);
   - use a newer minor release of the distribution.
3. If a custom kernel is unavoidable (a lab, a special appliance):
   - build it from RHEL's config;
   - sign it and its modules with an enrolled MOK;
   - keep the RHEL kernel installed as the fallback;
   - own its updates from then on.

**Likely follow-ups:**
- *What does `make olddefconfig` do?* Takes the existing `.config` and fills new options with defaults.
- *What does `make modules_install` do?* Installs the modules into `/lib/modules/VERSION/` and runs `depmod`.
