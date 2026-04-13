# BE Client PRO (Manual VPS/Dedicated Install)

Short description: Advanced network-level threat detection client that monitors **all network traffic** in real-time. Unlike the standard BE Client which analyzes web server logs, BE Client PRO uses tcpdump to capture and analyze live network packets across every service on your server.

## Disclaimer
DISCLAIMER: This is powerful security software that runs with elevated privileges and modifies your system. It is provided "AS-IS" and "AS-AVAILABLE" without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose, or non-infringement. Your use of the software is at your own risk. By downloading, installing or using this software, you agree to our [Terms of Service](https://boteraser.com/terms-of-service/) and [Privacy Policy](https://boteraser.com/privacy-policy/).

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
- iptables installed
- ipset installed
- systemd

## Quick start

1. Download be-client-pro-latest.tar.gz to your preferred location (recommended: /opt):

```bash
cd /opt
wget https://github.com/sofset-dev/boteraser/raw/refs/heads/main/be-client-pro/be-client-pro-latest.tar.gz
```

2. Extract the archive and enter the directory:

```bash
tar -xzvf be-client-pro-latest.tar.gz
cd boteraser-pro
```

3. Edit the configuration file. Open be-pro.conf with a text editor:

```bash
nano be-pro.conf
```
or
```bash
vi be-pro.conf
```

In be-pro.conf, enter:

- Your API KEY – you can get it at: https://user.boteraser.com/api.php
- Set `INTERFACE="auto"` to use the first detected interface, `"any"` for all interfaces except loopback, or specify one directly (e.g., `eth0`). Example:

```
API_KEY_PRO="<YOUR API KEY>"
INTERFACE="auto"
```

Save and exit.

4. Create a systemd service file using a text editor such as nano or vi:

```bash
vi /etc/systemd/system/be-client-pro.service
```

Then add this in the file:

```ini
[Unit]
Description=Boteraser PRO Client
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/boteraser-pro
ExecStart=/opt/boteraser-pro/be-client-pro
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Save and exit.

5. Reload systemd, enable the service, and start it:

```bash
systemctl daemon-reload
systemctl enable be-client-pro
systemctl start be-client-pro
```

6. Check the service status and view logs:

```bash
systemctl status be-client-pro
journalctl -u be-client-pro -f
```

✅ That's it! The Boteraser PRO client will now run every 5 minutes and help protect your server automatically.

## Notes
- BE Client PRO requires a PRO subscription
- Runs as a daemon — continuously monitors network traffic
- Analyzes last 10000 packets every 5 minutes
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
