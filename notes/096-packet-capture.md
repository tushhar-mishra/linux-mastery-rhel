# 096 · Packet Capture: tcpdump, tshark and Wireshark

> **You need first:** [095 · TCP/IP deep dive](095-tcp-ip-deep-dive.md)
> **Next:** [097 · Namespaces and cgroups](097-namespaces-and-cgroups.md)

---

## What it is

**Packet capture** records the packets passing through a network interface, so you can see **exactly** what's on the wire: DNS queries, TCP handshakes, resets, retransmissions, HTTP requests, and plaintext credentials in insecure protocols.

| Tool | Package | Use |
|---|---|---|
| `tcpdump` | `tcpdump` | The standard command-line capture tool on servers |
| `tshark`, `dumpcap` | `wireshark-cli` | Terminal Wireshark, with deep protocol decoding |
| Wireshark | `wireshark` | The graphical analyser (usually on your workstation) |

Words:
- **pcap file**: the standard file format for saved captures (`.pcap` / `.pcapng`).
- **BPF** (Berkeley Packet Filter): the small filter language (`host 10.0.0.5 and port 443`) that the kernel uses to decide which packets to copy to the capture tool.
- **Promiscuous mode**: the network card accepts frames not addressed to it. On modern **switched** networks you still mostly see only your own traffic plus broadcasts; seeing others' traffic needs a **SPAN/mirror port** on the switch.

**Ethics and law:** capture only on systems and networks you own or are explicitly authorised to monitor. Captures can contain passwords and personal data, so protect and delete `.pcap` files.

## Why it exists

Logs tell you what applications **think** happened; a capture shows what **actually** happened:
- Did the SYN arrive?
- Did a SYN-ACK leave?
- Who sent the RST?
- Did DNS answer, and how fast?
- Were packets retransmitted?

When teams argue "it's the network" vs "it's the app", a capture on both ends settles it.

## Analogy

A packet capture is a **CCTV camera over the loading dock**. Staff (applications) might say "the delivery never came", but the recording shows whether the truck arrived, who signed for it, and whether a box was sent back.

## How it works inside

1. `tcpdump` opens a special **packet socket** on the interface (this needs root, or the `CAP_NET_RAW` capability, topic 092).
2. The BPF filter you write is **compiled and loaded into the kernel**, so only matching packets are copied to user space. That's why a good filter keeps captures cheap even on busy hosts.
3. Packets are timestamped and either printed (decoded) or written raw to a pcap file.
4. **Where** you capture matters:
   - On the receiving host, you see packets **before** the local firewall's INPUT filtering, so a SYN you see arriving may still be dropped by nftables (topic 095).
   - `-i any` captures on all interfaces, including bridges and veths on container hosts.
5. Encrypted protocols (SSH, TLS) show only metadata: IPs, ports, packet sizes, timing, and the TLS **SNI** hostname.

## Commands

```bash
sudo dnf install -y tcpdump wireshark-cli      # Ubuntu: apt install tcpdump tshark
sudo tcpdump -D                                # list capture interfaces
```

### tcpdump options

| Option | Meaning |
|---|---|
| `-i ens160` / `-i any` | One interface / all interfaces |
| `-nn` | Don't resolve host names or port names (faster, clearer) |
| `-c 50` | Stop after 50 packets |
| `-w file.pcap` / `-r file.pcap` | Write raw packets / read a saved capture |
| `-A` / `-X` | Print the payload as ASCII / hex + ASCII |
| `-v`, `-vv` | More protocol detail |
| `-e` | Show MAC addresses |
| `-G 3600` / `-C 100` | Rotate files every hour / every 100 MB |

### Filters (BPF): written at the end

```bash
sudo tcpdump -i any -nn host 192.168.1.20
sudo tcpdump -i any -nn tcp port 8080
sudo tcpdump -i any -nn 'src net 10.0.0.0/24 and dst port 53'
sudo tcpdump -i any -nn icmp
sudo tcpdump -i any -nn not port 22                       # skip your own SSH session
sudo tcpdump -nn -r web.pcap 'tcp[tcpflags] & (tcp-syn|tcp-rst) != 0'   # only SYNs and RSTs
```

### Reading a handshake

```bash
sudo tcpdump -i any -nn -c 6 port 8080
```
```
10:41:02.112233 enp0s8 In  IP 192.168.56.10.51234 > 192.168.56.11.8080: Flags [S], seq 1000, win 64240, options [mss 1460,...], length 0
10:41:02.112301 enp0s8 Out IP 192.168.56.11.8080 > 192.168.56.10.51234: Flags [S.], seq 5000, ack 1001, win 65160, ..., length 0
10:41:02.112540 enp0s8 In  IP 192.168.56.10.51234 > 192.168.56.11.8080: Flags [.], ack 1, win 502, length 0
10:41:02.112811 enp0s8 In  IP 192.168.56.10.51234 > 192.168.56.11.8080: Flags [P.], seq 1:79, ack 1, length 78: HTTP: GET /health HTTP/1.1
10:41:02.113402 enp0s8 Out IP 192.168.56.11.8080 > 192.168.56.10.51234: Flags [P.], seq 1:150, ack 79, length 149: HTTP: HTTP/1.1 200 OK
10:41:02.113650 enp0s8 In  IP 192.168.56.10.51234 > 192.168.56.11.8080: Flags [F.], seq 79, ack 150, length 0
```

| Flag | Meaning |
|---|---|
| `[S]` | SYN (open) |
| `[S.]` | SYN-ACK (`.` = ACK) |
| `[.]` | Plain ACK |
| `[P.]` | PUSH + ACK: data |
| `[F.]` | FIN (close) |
| `[R]` / `[R.]` | **RST**: refused or aborted |

- `In`/`Out` shows direction on `-i any`. Here: a full handshake, a GET, a 200 OK, then the client closes. After the handshake, tcpdump prints **relative** sequence numbers (`seq 1:79`, `ack 1`) so they're easy to follow; add `-S` to see the real 32-bit numbers.

**What failures look like:**
- **Refused:** `[S]` in, `[R.]` out immediately. Nothing is listening, or there's a reject rule.
- **Dropped:** `[S]` in, nothing out, then `[S]` again 1 s, 3 s, 7 s later (retransmissions). The firewall or the app isn't answering.
- **Nothing arrives at all:** the problem is upstream (routing, a network firewall, the security group).

### DNS

```bash
sudo tcpdump -i any -nn port 53
```
```
10:45:10.001 IP 192.168.56.10.40211 > 192.168.56.2.53: 31337+ A? api.example.com. (33)
10:45:12.004 IP 192.168.56.10.40211 > 192.168.56.2.53: 31337+ A? api.example.com. (33)
10:45:12.020 IP 192.168.56.2.53 > 192.168.56.10.40211: 31337 1/0/0 A 203.0.113.10 (49)
```
- The first query got no reply; the retry 2 s later was answered. That's a 2-second delay per lookup from a flaky resolver.

### Save and analyse elsewhere

```bash
sudo tcpdump -i any -nn -c 2000 -w /tmp/web.pcap port 80
scp server1:/tmp/web.pcap .                                   # then open it in Wireshark
tshark -r /tmp/web.pcap -Y http.request -T fields -e ip.src -e http.host -e http.request.uri
tshark -r /tmp/web.pcap -Y tcp.analysis.retransmission | wc -l
```

| tshark option | Meaning |
|---|---|
| `-f "tcp port 22"` | **Capture** filter (BPF, decides what's recorded) |
| `-Y 'http.request'` | **Display** filter (Wireshark syntax, only hides/shows recorded packets) |
| `-T fields -e FIELD` | Print chosen fields |
| `-V` | The full protocol tree |

Useful Wireshark display filters: `http`, `dns`, `tls.handshake`, `tcp.flags.reset==1`, `tcp.analysis.retransmission`, `ip.addr==10.0.0.5`.

### Plaintext vs encrypted (a lab demo)

```bash
sudo tcpdump -i any -nn -A port 80     # curl http://server/ → GET line, headers and cookies readable
sudo tcpdump -i any -nn -A port 21     # FTP login → USER and PASS readable (topic 082)
sudo tcpdump -i any -nn -A port 22     # SSH → unreadable binary
sudo tcpdump -i any -nn -A port 443    # HTTPS → only handshake metadata such as the SNI hostname
```
This is why Telnet, FTP and HTTP are replaced by SSH, SFTP and HTTPS.

### Containers and Kubernetes nodes

```bash
sudo tcpdump -i podman0 -nn                    # the container bridge
sudo nsenter -t <PID> -n tcpdump -i eth0 -nn   # inside one container's network namespace (topic 097)
```

### Try it
1. Capture `curl http://localhost` on `lo` and label each line of the handshake.
2. Point `curl` at a closed port and see the `[R.]`. Add a firewall drop rule and see the SYN retransmissions instead.
3. Capture DNS while running `dig` against a working server and then a non-existent one.
4. Write a pcap, copy it to your workstation and find retransmissions in Wireshark.

**Check your work:** on your lab VM, from the notes folder, run `sudo ./checks/check 096` for every step, or `sudo ./checks/check 096 STEP` for one (topic 002 shows how to get the notes there).

## Where you'll use it

- **"Is the request reaching the server?"**: run tcpdump on the server.
- **Firewall debugging:** SYN in but no SYN-ACK out = local firewall or app; nothing in = upstream.
- **Slow DNS, TLS problems, MTU black holes** (ICMP "fragmentation needed", retransmitted large packets).
- **Kubernetes:** capturing on node interfaces, the CNI bridge, or inside a pod's network namespace (`nsenter`, or `kubectl debug` with a tools image).
- **Security reviews:** proving a protocol is (or isn't) sending secrets in plaintext.

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `You don't have permission to capture` | Not root | `sudo` (or the `wireshark` group for `dumpcap`) |
| The output is flooded with SSH lines | You're capturing your own session | Add `not port 22` |
| You only see your own traffic | A switched network | Capture on the endpoints, or use a mirror port |
| A tcpdump filter error | Wireshark display syntax used in BPF | BPF at the end of tcpdump; display filters go in `tshark -Y` |
| Huge capture files | No limits | `-c`, `-C`/`-G` rotation, tighter filters |
| You see the SYN but the app logs nothing | The local firewall drops it after capture, or the app isn't listening | `nft list ruleset`, `ss -tlnp` |

## Quick recap

- `tcpdump -i IF|any -nn [-c N] [-w F | -r F] [-A] 'BPF filter'`. Exclude your SSH session with `not port 22`.
- Flags: `[S]` SYN, `[S.]` SYN-ACK, `[.]` ACK, `[P.]` data, `[F.]` FIN, `[R]` RST.
- Capture filter (BPF) = what's recorded; display filter (Wireshark/tshark `-Y`) = what's shown.
- Capture on the server, analyse in Wireshark. Only capture where you're authorised.

**Interview questions**

1. *How do you prove whether traffic reaches a server?* Run `tcpdump -nn -i any port PORT` on the server: see if SYNs arrive and whether SYN-ACKs (or RSTs) go back.
2. *Capture filter vs display filter?* A capture filter (BPF) decides which packets are recorded at all; a display filter only hides or shows packets already recorded.
3. *What does a refused connection look like in tcpdump?* The client's `[S]` is answered immediately by an `[R.]` (RST) from the server.

**Scenario question** (answer out loud first, then compare)

> *"The application team says 'the network is dropping our requests'. The network team says 'the network is fine'. How do you settle it with evidence?"*

**Model answer:**
1. Capture at **both ends** at the same time, filtered to the flow: `tcpdump -i any -nn -w /tmp/side.pcap host 10.0.0.5 and port 8443` on client and server.
2. Reproduce the failure, stop the captures, and compare:
   - The SYN leaves the client but never arrives at the server → something in between drops it (firewall, routing, security group).
   - The SYN arrives and the server answers `[R.]` → the server side refuses (nothing listening, or a reject rule).
   - The SYN arrives and nothing goes back → the server's own firewall or no return route.
   - The handshake completes, then retransmissions or resets mid-stream → MTU, a middlebox timeout, or the app.
3. Open the pcaps in Wireshark (`tcp.analysis.retransmission`, `tcp.flags.reset == 1`) and show the timeline.
4. Packets don't lie, so this ends the argument quickly, and points at the right team.

**Likely follow-ups:**
- *Capture filter vs display filter?* BPF decides what's recorded; Wireshark's filter only hides or shows.
- *Why `not port 22` when capturing over SSH?* Otherwise you capture your own session, which generates more traffic: a feedback loop.
