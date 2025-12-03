# BE Client PRO (Manual VPS/Dedicated Install)

Short description: Advanced network-level protection client that monitors **all network traffic** in real-time. Unlike the standard BE Client which analyzes web server logs, BE Client PRO uses tcpdump to capture and analyze live network packets—protecting every service on your server.

## 🛡️ Complete Server Protection

BE Client PRO operates at the **network layer**, providing protection for ALL protocols and services:

- **HTTP/HTTPS** (ports 80, 443) — Web applications, APIs, CDN
- **SSH** (port 22) — Brute force prevention, unauthorized access blocking
- **FTP/SFTP** (ports 21, 22) — File transfer security
- **MySQL/MariaDB** (port 3306) — Database intrusion prevention
- **PostgreSQL** (port 5432) — Database attack mitigation
- **MongoDB** (port 27017) — NoSQL protection
- **Redis** (port 6379) — Cache server security
- **SMTP/IMAP/POP3** (ports 25, 465, 587, 993, 995) — Email server protection
- **DNS** (port 53) — DNS amplification attack prevention
- **VPN/OpenVPN** (port 1194) — VPN server protection
- **Docker API** (ports 2375, 2376) — Container security
- **Kubernetes** (ports 6443, 10250) — K8s cluster protection
- **Game Servers** (Minecraft 25565, etc.) — DDoS mitigation
- **ANY TCP/UDP service** — Full network coverage

## When to use
- You need protection for **all services**, not just web traffic
- You want real-time network analysis
- Your server runs SSH, databases, mail servers, or other non-HTTP services
- You prefer manual installation with full control

## Prerequisites
- Linux server (VPS or Dedicated)
- Shell access (bash) with sudo/root privileges
- tcpdump installed
- ipset installed (auto-installed if missing)

## Quick start
1. Copy the archive to your server and extract it:

```bash
cd /path/where/you/placed/the/archive
ls -lh be-client-pro-latest.tar.gz
sudo tar -xzf be-client-pro-latest.tar.gz
cd boteraser-pro/
```

2. Configure your API key:

```bash
sudo nano be-pro.conf
```

Add your PRO API key:
```bash
API_KEY_PRO="your-pro-api-key-here"
```

3. Run the client:

```bash
chmod +x be-client-pro 2>/dev/null || true
sudo ./be-client-pro
```

## Schedule via cron (every 5 minutes)

### With logging
```bash
*/5 * * * * /absolute/path/to/your/be-client-pro >> /var/log/be-client-pro.log 2>&1
```

### Without logging (silent)
```bash
*/5 * * * * /absolute/path/to/your/be-client-pro >/dev/null 2>&1
```

**Note:** Use absolute paths. The script **must run as root** for tcpdump and iptables access.

## Notes
- BE Client PRO requires a PRO subscription
- The script captures live network traffic for 30 seconds (configurable)
- Blocked IPs auto-expire after 24 hours
- Supports both IPv4 and IPv6 (dual-stack)
- Uses ipset + iptables for high-performance O(1) blocking
- For web-only protection with bot name detection, use standard BE Client

## Screenshots

BE Client PRO provides comprehensive network-level protection. Below are example screenshots:

### Script Execution
Real-time network traffic capture, analysis, and IP blocking in action.

![BE Client PRO Execution](../images/be-client-pro-execution.png)

### Configuration File
Simple configuration with API key and network interface settings.

![BE Client PRO Config](../images/be-client-pro-config.png)
