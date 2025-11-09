# Boteraser WordPress Plugin

Short description: Install this plugin on your WordPress site to integrate with the Boteraser service. Choose this if you want a website-level integration without managing a server yourself.

Server-side alternatives:
- Automated server install (recommended): ../be-client-install-script/README.md
- Manual server install: ../be-client/README.md

## Requirements
- A WordPress site with admin access
- Ability to upload a plugin ZIP

## Install via WordPress Admin (recommended)
1. In your WP dashboard, go to: Plugins → Add New → Upload Plugin
2. Select the `boteraser-latest.zip` file in this folder
3. Click “Install Now”, then “Activate”
4. After activation, look for the “Boteraser” menu in your dashboard to configure

## Manual (FTP/SFTP) install
1. Extract `boteraser-latest.zip`
2. Upload the extracted folder to `wp-content/plugins/`
3. In your WP dashboard, go to: Plugins → Installed Plugins → Activate “Boteraser”

## Configuration
- Open the “Boteraser” settings page in WordPress
- Provide any required API URL/keys if prompted (for self‑hosted, point to your BE Client URL)
- Save changes and verify the plugin’s status notice

## Notes
- If activation fails, verify your WordPress/PHP meets the plugin’s requirements
- For self‑hosting, ensure your server endpoint is reachable from your site
- If you self-host the BE Client, make sure it is scheduled via the system cron to run every 5 minutes (see ../be-client-install-script/README.md or ../be-client/README.md)

## Screenshots

Use the WordPress plugin or the server script to block malicious traffic, bad bots, and automated attacks.

### Dashboard Overview
This is the WordPress plugin dashboard showing API status and site-wide statistics. After configuring the API in the plugin settings, run a manual check to verify connectivity and view updated metrics immediately.

![Dashboard Overview](../images/wp-dashboard.png)

### Blocked IPs
WordPress plugin: Blocked IPs show IP + reason, auto-release time, and an Unblock button. Unblocked IPs may be re-blocked.

![Blocked IPs](../images/wp-blocked-ips.png)

### Main Dashboard (Stats)
Single view of protection metrics, traffic trends, recent activity, and quick actions with basic filters and alerts.

![Main Dashboard](../images/user-dashboard.png)

### User API
Shows Domain name, API key and request usage status. Use the verify action in your wp-plugin or script to confirm connectivity credentials. Keep the key secret.

![User API](../images/user-api.png)

### User SHIELD
Create and manage security shields with configurable rules and quick enable/disable controls.

![User SHIELD](../images/user-shield.png)
