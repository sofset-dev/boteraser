# BE Client (Manual VPS/Dedicated Install)

Short description: Self-hosted backend client to run on your own VPS or dedicated server. Choose this if you prefer full control and a manual setup.

## Disclaimer
DISCLAIMER: This is powerful security software that runs with elevated privileges and modifies your system. It is provided "AS-IS" and "AS-AVAILABLE" without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose, or non-infringement. Your use of the software is at your own risk. By downloading, installing or using this software, you agree to our [Terms of Service](https://boteraser.com/terms-of-service/) and [Privacy Policy](https://boteraser.com/privacy-policy/).

## When to use
- You need a manual install on your own server
- You want to customize each step
- Alternative (recommended): use the automated installer here: ../be-client-install-script/README.md

## Prerequisites
- Linux server (VPS or Dedicated)
- Shell access (bash) with sudo/root privileges
- tar installed (to extract the archive)

## Quick start

1. Download be-client-latest.tar.gz to your preferred location (recommended: /opt):

```bash
cd /opt
wget https://github.com/sofset-dev/boteraser/raw/refs/heads/main/be-client/be-client-latest.tar.gz
```

2. Extract the archive and enter the directory:

```bash
tar -xzvf be-client-latest.tar.gz
cd boteraser
```

3. Edit the configuration file. Open be.conf with a text editor:

```bash
nano be.conf
```
or
```bash
vi be.conf
```

In be.conf, enter:

- Your API KEY – you can get it at: https://user.boteraser.com/api.php
- The full path to the access.log of the domain you want to protect

Example:

```
API_KEY="<YOUR API KEY>"
LOG_PATH="/path/to/your/access.log"
```

4. Set up automatic execution every 5 minutes using cron. Open the crontab editor:

```bash
crontab -e
```

Then add this line at the end:

```
*/5 * * * * /your/desired/folder/boteraser/be-client >/dev/null 2>&1
```

Save and exit.

✅ That's it! The Boteraser client will now run every 5 minutes and help protect your website automatically.

## Notes
- Prefer the one‑command automated install? See: ../be-client-install-script/README.md

## Screenshots

Install the script with the automated installer or set it up manually—both provide the same monitoring functionality. Below are some example screenshots showing the BE Client in action:

### Script Analyzing and Blocking IPs
This script analyzes web server logs and blocks identified blacklisted IPv4 and IPv6 addresses or CIDR ranges by adding firewall rules to help mitigate abusive traffic.

![Script BLOCKING IPS](../images/script-blocking-ips.png)

### Script CONFIG
Central configuration for the blocking script, specifying API credentials and path to your log file.

![Script CONFIG](../images/script-config.png)
