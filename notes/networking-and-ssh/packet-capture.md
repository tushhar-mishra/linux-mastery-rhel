# Packet Capture & Network Sniffing: tcpdump, tshark, Wireshark

> **[Advanced/Optional]** · essential production troubleshooting and security awareness
> **Related:** [Routing](routing.md) · [Bonding](network-bonding.md) · [SSH (encrypted vs plaintext)](ssh-remote-access.md) · [firewalld](../firewall-and-selinux/firewalld.md) · [TCP/IP for operators](tcp-ip-for-operators.md)

## 1. Overview

**Packet capture** records the frames passing through a network interface so you can see exactly what's on the wire: DNS lookups, TCP handshakes, retransmissions, HTTP requests, and credentials in **plaintext protocols**.

> ⚖️ **Ethics and law:** capture only on systems and networks you own or are explicitly authorized to monitor. Unauthorized sniffing can be illegal. Captures can contain passwords and personal data; protect and delete `.pcap` files appropriately.

**Promiscuous mode** lets a NIC accept frames not addressed to it. On modern **switched** networks you still mostly see your own traffic plus broadcast/multicast. Seeing others' traffic needs a SPAN/mirror port, a hub, or a hypervisor that allows it.

## 2. Tools on RHEL 10

| Tool | Package | Notes |
|---|---|---|
| `tcpdump` | `tcpdump` (BaseOS) | CLI capture with BPF filters, the standard on servers |
| `tshark`, `dumpcap` | `wireshark-cli` (AppStream) | Terminal Wireshark with protocol dissectors |
| Wireshark GUI | `wireshark` (AppStream) | Graphical analysis (needs a desktop) |
| ngrep | EPEL | grep for packet payloads |
| ettercap | Not in RHEL repos | MITM/ARP spoofing tool, used in security training |

```bash
dnf install -y tcpdump wireshark-cli          # (+ wireshark for the GUI)
tcpdump -D                                    # list capture interfaces (also: ip -br link)
```

Capturing requires root (or membership in the `wireshark` group for `dumpcap`).

## 3. tcpdump

| Option | Meaning |
|---|---|
| `-i ens160` / `-i any` | Interface / all interfaces |
| `-n` / `-nn` | Don't resolve hosts / hosts and ports |
| `-c 50` | Stop after 50 packets |
| `-w file.pcap` / `-r file.pcap` | Write raw packets / read a capture |
| `-A` / `-X` | Print payload as ASCII / hex+ASCII |
| `-v`, `-vv` | More protocol detail |
| `-e` | Show MAC addresses (link-layer header) |
| `-s 0` | Full packet length (default on modern tcpdump) |
| `-G 3600 -w cap-%H.pcap` / `-C 100` | Rotate files by time / by size (MB) |

**Filters (BPF):** written as an expression **at the end** of the command:

```bash
tcpdump -i ens160 -nn host 192.168.1.20
tcpdump -i ens160 -nn tcp port 22
tcpdump -i ens160 -nn 'src net 10.0.0.0/24 and dst port 53'
tcpdump -i ens160 -nn icmp
tcpdump -i ens160 -nn 'tcp port 80 and not host 192.168.1.5'
tcpdump -i ens160 -nn not port 22            # exclude your own SSH session when capturing over SSH
tcpdump -i ens160 -nn -c 100 -w /tmp/web.pcap port 80
tcpdump -nn -r /tmp/web.pcap 'tcp[tcpflags] & tcp-syn != 0'   # SYNs only [Advanced]
```

## 4. tshark & Wireshark

| tshark option | Meaning |
|---|---|
| `-i ens160` | Interface (`-I` would enable monitor mode, not select an interface) |
| `-f "tcp port 22"` | **Capture** filter (BPF, same syntax as tcpdump) |
| `-Y http` / `-Y 'dns.qry.name contains "redhat"'` | **Display** filter (Wireshark syntax) |
| `-c 50`, `-w file.pcap`, `-r file.pcap` | Count / write / read |
| `-V` / `-x` | Full protocol tree / hex dump |

```bash
tshark -i ens160 -f "port 80" -c 20
tshark -r /tmp/web.pcap -Y http.request -T fields -e http.host -e http.request.uri
wireshark /tmp/web.pcap &        # GUI: apply display filters like http, dns, tcp.analysis.retransmission
```

Common workflow: capture on the server with `tcpdump -w`, copy the `.pcap` to a workstation (`scp`), and analyze in Wireshark.

## 5. Lab: Plaintext vs Encrypted Protocols

```bash
# Server: HTTP
dnf install -y httpd ; systemctl enable --now httpd
firewall-cmd --permanent --add-service=http ; firewall-cmd --reload
# Sniffer (server or monitoring VM)
tcpdump -i ens160 -nn -A port 80        # browse/curl http://SERVER → GET lines, headers, cookies visible
# FTP (if vsftpd is set up): tcpdump -i ens160 -nn -A port 21 → USER/PASS visible
# Encrypted comparison
tcpdump -i ens160 -nn -A port 22        # SSH → unreadable binary
tcpdump -i ens160 -nn -A port 443       # HTTPS → only the TLS handshake metadata (e.g., SNI) is readable
```

Telnet demonstrates the same point (`telnet-server`/`telnet` packages), but it may not be available in RHEL 10 repositories. HTTP and FTP show plaintext credentials just as well.

**Conclusion:** replace Telnet, FTP and HTTP with SSH, SFTP and HTTPS.

## 6. Troubleshooting with Captures **[Production Practice]**

| Question | Capture |
|---|---|
| Is the request reaching the server? | `tcpdump -nn -i any port 8080` on the server |
| Firewall dropping? | SYN arrives, no SYN-ACK leaves → local firewall/service; nothing arrives → upstream |
| DNS slow or failing? | `tcpdump -nn port 53` (look at queries vs responses, timing) |
| Path problems / MTU? | Retransmissions, ICMP "fragmentation needed" |
| Bond/route uses which NIC? | Capture on each interface in parallel |

## 7. Troubleshooting the Tools

| Symptom | Cause | Fix |
|---|---|---|
| `You don't have permission to capture` | Not root / not in `wireshark` group | `sudo`; `usermod -aG wireshark USER` (re-login) |
| Capture flooded with SSH lines | Capturing your own session | Add `not port 22` |
| See only your own traffic | Switched network | SPAN/mirror port, or capture on the endpoints |
| Filter error in tcpdump | Used `-f` or Wireshark display syntax | Put the BPF expression at the end; display filters belong to `tshark -Y` |
| Huge capture files | No limits | `-c`, `-C`/`-G` rotation, specific filters |

## 8. Interview Questions

| Question | Answer |
|---|---|
| Capture filter vs display filter? | Capture (BPF) decides what's recorded; display filters (Wireshark) only hide/show recorded packets. |
| Why can't you see other hosts' traffic on a switch? | Switches forward unicast only to the destination port; you need port mirroring. |
| How do you avoid capturing your own SSH session? | `not port 22` (or exclude your client IP). |
| How do you prove a service receives traffic? | `tcpdump -nn -i any port <port>` on the server and look for SYN/SYN-ACK. |
| Why is HTTPS safe from simple sniffing? | Payload is encrypted with TLS; only metadata (IPs, ports, SNI) is visible. |

## 9. Quick Revision

```bash
tcpdump -D · tcpdump -i IF|any -nn [-c N] [-w F|-r F] [-A|-X] [-e] 'host H and port P and not port 22'
tshark -i IF -f "BPF" | -r F -Y 'display filter' | -V | -x | -T fields -e FIELD
dnf install tcpdump wireshark-cli [wireshark] · root or wireshark group · authorized captures only
```

## 10. Cross-References

- [Routing](routing.md)
- [Bonding](network-bonding.md)
- [SSH (encrypted vs plaintext)](ssh-remote-access.md)
- [firewalld](../firewall-and-selinux/firewalld.md)
