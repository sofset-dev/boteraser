# BE Client PRO (Manual VPS/Dedicated Install)

Short description: Advanced network-level threat detection client that monitors **all network traffic** in real-time. Unlike the standard BE Client which analyzes web server logs, BE Client PRO uses tcpdump to capture and analyze live network packets across every service on your server.

## Disclaimer
This is powerful security software and should be used responsibly. It is provided "AS-IS" without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose, or non-infringement. Your use of the software is at your own risk. By downloading, installing or using this software, you agree to our [Terms of Service](https://boteraser.com/terms-of-service/) and [Privacy Policy](https://boteraser.com/privacy-policy/).

## 🛡️ Comprehensive Server Monitoring

BE Client PRO operates at the **network layer**, monitoring ALL protocols and services:

- **HTTP/HTTPS** (ports 80, 443) — Web applications, APIs, CDN
- **SSH** (port 22) — Brute force attack detection, unauthorized access attempts
- **FTP/SFTP** (ports 21, 22) — File transfer security monitoring
- **MySQL/MariaDB** (port 3306) — Database intrusion attempt detection
- **PostgreSQL** (port 5432) — Database attack pattern recognition
- **MongoDB** (port 27017) — NoSQL threat monitoring
- **Redis** (port 6379) — Cache server threat detection
- **SMTP/IMAP/POP3** (ports 25, 465, 587, 993, 995) — Email server threat monitoring
- **DNS** (port 53) — DNS amplification attack detection
- **VPN/OpenVPN** (port 1194) — VPN server threat monitoring
- **Docker API** (ports 2375, 2376) — Container security monitoring
- **Kubernetes** (ports 6443, 10250) — K8s cluster threat detection
- **Game Servers** (Minecraft 25565, etc.) — DDoS attack pattern detection
- **ANY TCP/UDP service** — Full-spectrum network monitoring

## When to use
- You need monitoring across **all services**, not just web traffic
- You want real-time network traffic analysis
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
- For web-only monitoring with bot name detection, use standard BE Client

## Screenshots

BE Client PRO provides comprehensive network-level monitoring. Below are example screenshots:

### Script Execution
Real-time network traffic capture, analysis, and IP blocking in action.

![BE Client PRO Execution](../images/be-client-pro-execution.png)

### Configuration File
Simple configuration with API key and network interface settings.

![BE Client PRO Config](../images/be-client-pro-config.png)
