# Linux: From Zero to Production

One self-contained learning path for Linux, from the first command to the kernel mechanisms behind containers and Kubernetes, aimed at DevOps/SRE interviews and real production work.

**Start here → [INDEX.md](INDEX.md)**: 113 topics in strict reading order, one line each.

- **Main system:** RHEL 10 (also AlmaLinux and Rocky Linux). Ubuntu/Debian differences are noted where they matter.
- **Verified on a real system:** command output in the notes was captured on **AlmaLinux 10.2** (a RHEL 10.2 rebuild, kernel 6.12, systemd 257) in a VirtualBox VM. Your values (UUIDs, sizes, versions, timestamps) will differ. A few things couldn't run in that lab (KVM guests, multi-host setups, Red Hat subscription services); those topics say so.
- **Every topic has the same shape:** What it is · Why it exists · Analogy · How it works inside · Commands (with real output and a "Try it" lab) · Where you'll use it · When it breaks · Quick recap + interview questions.
- **Every topic links** to the one before ("You need first") and the one after ("Next").
- **Practice safely:** build the lab in [topic 002](notes/002-build-your-practice-lab.md), and take a VM snapshot before any lab that breaks things.
