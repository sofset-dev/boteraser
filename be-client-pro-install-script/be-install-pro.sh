#!/bin/bash

# Configuration variables
DOWNLOAD_URL="https://github.com/sofset-dev/boteraser/raw/refs/heads/main/be-client-pro/be-client-pro-latest.tar.gz"
SERVICE_FILE="/etc/systemd/system/be-client-pro.service"
DEFAULT_INSTALL_LOCATION="/opt"

# Function to print headers
print_header() {
    echo -e "╔══════════════════════════════════════════════════════════════╗"
    echo -e "║$(printf "%*s" $(((62-${#1})/2)) "")$1$(printf "%*s" $(((63-${#1})/2)) "")║"
    echo -e "╚══════════════════════════════════════════════════════════════╝"
}

# Function to print success messages
print_success() {
    echo -e "✅ $1"
}

# Function to print error messages
print_error() {
    echo -e "❌ $1"
}

# Function to print warning messages
print_warning() {
    echo -e "⚠️  $1"
}

# Function to print info messages
print_info() {
    echo -e "ℹ️  $1"
}

# Escape a value for safe use on the replacement side of a sed s|...|...| command
sed_escape() {
    printf '%s' "$1" | sed -e 's/[&|\\]/\\&/g'
}

# Set KEY="value" in a conf file (replaces the whole line).
# Usage: conf_set <file> <KEY> <value>
conf_set() {
    sed -i -e "s|^$2=.*|$2=\"$(sed_escape "$3")\"|" "$1"
}

# Prompt for a value showing its [default]. Enter accepts the default.
# Result is placed in the global REPLY_VALUE.
prompt_default() {
    local label="$1" default="$2" input
    if [[ -n "$default" ]]; then
        echo -n -e "👉 $label [$default]: "
    else
        echo -n -e "👉 $label (optional, Enter to leave blank): "
    fi
    read -r -u 3 input
    REPLY_VALUE="${input:-$default}"
}

# Prompt for a secret (input hidden). Enter keeps the current default.
prompt_secret() {
    local label="$1" default="$2" input
    echo -n -e "👉 $label (hidden, Enter to keep default): "
    read -rs -u 3 input
    echo ""
    REPLY_VALUE="${input:-$default}"
}

# Ask whether the user wants to customize an optional section.
# Returns 0 (yes) or 1 (keep defaults).
section_customize() {
    local name="$1" ans
    echo ""
    echo -n -e "👉 Configure $name now? (Enter = keep defaults / y = customize): "
    read -r -u 3 ans
    [[ "$ans" == "y" || "$ans" == "Y" ]]
}

# When piped (curl ... | bash) stdin carries the script text itself, so a plain
# `read` would consume script bytes instead of the user's answer. Keep the
# terminal on fd 3 and read every prompt from there. Redirecting stdin is not an
# option: bash is still reading the script from it.
# /dev/tty can exist and still not be openable (no controlling terminal), so
# probe it in a subshell before committing the real exec.
if ( exec 3</dev/tty ) 2>/dev/null; then
    exec 3</dev/tty
elif [[ -t 0 ]]; then
    exec 3<&0
else
    print_error "No terminal available for the interactive prompts."
    print_info "Run the installer from an interactive terminal."
    exit 1
fi

# Check root privileges
if [[ $EUID -ne 0 ]]; then
    print_header "BOTERASER PRO INSTALLER"
    echo ""
    print_error "This script must be run as root!"
    echo ""
    print_info "Please log in as root user or use appropriate"
    print_info "privilege escalation method for your system"
    print_info "and run the script again."
    echo ""
    exit 1
fi

print_header "BOTERASER PRO INSTALLER"
print_success "Root privileges confirmed - proceeding with installation..."

# =============================================================================
# STEP 1: CHECK AND INSTALL DEPENDENCIES
# =============================================================================
check_dependencies() {
    print_header "CHECKING SYSTEM DEPENDENCIES"

    local missing_deps=()

    # Check iptables
    if ! command -v iptables &> /dev/null; then
        print_error "iptables not found"
        missing_deps+=("iptables")
    else
        print_success "iptables found"
    fi

    # Check ipset
    if ! command -v ipset &> /dev/null; then
        print_error "ipset not found"
        missing_deps+=("ipset")
    else
        print_success "ipset found"
    fi

    # Check ip6tables (optional)
    if command -v ip6tables &> /dev/null; then
        print_success "ip6tables found (IPv6 support enabled)"
    else
        print_warning "ip6tables not found (IPv6 support disabled)"
    fi

    echo ""

    # Install missing dependencies
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_warning "Installing missing dependencies: ${missing_deps[*]}"
        echo ""

        if command -v apt-get &> /dev/null; then
            print_info "Using apt-get package manager..."
            apt-get update -qq
            apt-get install -y "${missing_deps[@]}"
        elif command -v yum &> /dev/null; then
            print_info "Using yum package manager..."
            yum install -y "${missing_deps[@]}"
        elif command -v dnf &> /dev/null; then
            print_info "Using dnf package manager..."
            dnf install -y "${missing_deps[@]}"
        elif command -v pacman &> /dev/null; then
            print_info "Using pacman package manager..."
            pacman -S --noconfirm "${missing_deps[@]}"
        else
            print_error "Could not detect package manager. Please install manually:"
            echo -e "  ${missing_deps[*]}"
            exit 1
        fi

        echo ""
        print_success "Dependencies installed successfully!"
    else
        print_success "All dependencies are already installed."
    fi
}

# =============================================================================
# STEP 2: PRIVACY CONSENT
# =============================================================================
ask_privacy_consent() {
    print_header "IMPORTANT PRIVACY INFORMATION"
    echo ""
    echo -e "This software monitors network traffic on your server and sends"
    echo -e "IP addresses to user.boteraser.com (EU-based service) for security"
    echo -e "threat analysis and blocking of blacklisted IPs."
    echo ""
    echo -e "📋 Legal basis: Legitimate interest for server security (GDPR Art. 6(1)(f))"
    echo -e "📋 CCPA compliance: Data is not sold or shared (see Privacy Policy)"
    echo ""
    print_info "If you provide services to end-users (e.g., email, web hosting), you may"
    print_info "need to inform them about security monitoring per applicable privacy laws."
    echo ""
    echo -e "📄 Privacy Policy:   https://boteraser.com/privacy-policy/"
    echo -e "📄 Terms of Service: https://boteraser.com/terms-of-service/"
    echo ""
    echo -e "╔══════════════════════════════════════════════════════════════╗"
    echo -e "║  By proceeding, you confirm that you have read, understood,  ║"
    echo -e "║  and agree to both our Privacy Policy and Terms of Service   ║"
    echo -e "║  linked above.                                               ║"
    echo -e "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    print_warning "If you answer 'no', the installation will be cancelled."
    echo ""
    echo -e "Do you accept our Privacy Policy and Terms of Service?"
    echo -e "[y] Yes - I have read and accept both documents"
    echo -e "[n] No  - Cancel installation"
    echo -n -e "👉 Your choice (y/n): "

    while true; do
        read -r -u 3 consent_answer
        if [[ "$consent_answer" == "y" || "$consent_answer" == "Y" ]]; then
            echo ""
            print_success "Privacy Policy and Terms of Service accepted"
            return 0
        elif [[ "$consent_answer" == "n" || "$consent_answer" == "N" ]]; then
            echo ""
            print_error "Privacy Policy and Terms of Service not accepted"
            print_info "Installation cancelled."
            echo ""
            exit 0
        else
            echo ""
            print_error "Invalid input. Please enter 'y' to accept or 'n' to cancel."
            echo -n -e "👉 Your choice (y/n): "
        fi
    done
}

# =============================================================================
# STEP 3: CONFIGURATION
# =============================================================================
get_network_interfaces() {
    ip -o link show | awk -F': ' '{print $2}' | grep -v "^lo$" | tr '\n' ' '
}

validate_interface() {
    local interface="$1"
    if [[ "$interface" == "auto" || "$interface" == "any" ]]; then
        return 0
    fi
    if ip link show "$interface" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

ask_configuration() {
    while true; do
        print_header "CONFIGURATION SETUP"

        # Install location
        echo -e "📁 Installation Location"
        echo -e "Enter the directory where Boteraser PRO will be installed"
        echo -e "Press Enter to accept the default"
        echo -n -e "👉 Install location [$DEFAULT_INSTALL_LOCATION]: "
        read -r -u 3 install_location
        install_location="${install_location:-$DEFAULT_INSTALL_LOCATION}"
        install_location="${install_location%/}"
        echo ""

        # API key
        echo -e "🔑 API Key Configuration (PRO)"
        echo -e "Enter your Boteraser PRO API key"
        echo -e "You can find/generate it at: https://user.boteraser.com/api.php"
        echo -n -e "👉 API Key: "
        read -r -u 3 api_key
        echo ""

        # Network interface
        local available_interfaces
        available_interfaces=$(get_network_interfaces)
        echo -e "🌐 Network Interface Configuration"
        echo -e "Available interfaces: $available_interfaces"
        echo -e "Enter 'auto' to auto-detect, 'any' for all interfaces, or a name (e.g. eth0)"
        echo -n -e "👉 Interface [auto]: "
        read -r -u 3 network_interface
        if [[ -z "$network_interface" ]]; then
            network_interface="auto"
        fi
        echo ""

        print_info "Press Enter at any prompt to accept the [default] shown in brackets."
        echo ""

        # Domain / block timeout
        echo -e "🌐 Domain (optional — used in email reports; hostname if left blank)"
        prompt_default "Domain" ""; domain="$REPLY_VALUE"
        prompt_default "Server blocklist block timeout in seconds" "86400"; block_timeout="$REPLY_VALUE"

        # --- Email reports (SMTP) ---
        smtp_host=""; smtp_port="587"; smtp_user=""; smtp_pass=""; smtp_from=""
        smtp_security="starttls"; notify_email=""; report_interval="24h"
        if section_customize "email reports (SMTP)"; then
            prompt_default "SMTP host" "$smtp_host"; smtp_host="$REPLY_VALUE"
            prompt_default "SMTP port" "$smtp_port"; smtp_port="$REPLY_VALUE"
            prompt_default "SMTP user" "$smtp_user"; smtp_user="$REPLY_VALUE"
            prompt_secret  "SMTP password" "$smtp_pass"; smtp_pass="$REPLY_VALUE"
            prompt_default "From address (blank = SMTP user)" "$smtp_from"; smtp_from="$REPLY_VALUE"
            prompt_default "Security (starttls|tls|none)" "$smtp_security"; smtp_security="$REPLY_VALUE"
            prompt_default "Notify email (report recipient)" "$notify_email"; notify_email="$REPLY_VALUE"
            prompt_default "Report interval (6h|12h|24h)" "$report_interval"; report_interval="$REPLY_VALUE"
        fi

        # --- Brute-force protection ---
        bf_enabled="yes"; auth_log="/var/log/auth.log"; bf_max="5"; bf_window="15"; bf_block="60"
        if section_customize "brute-force protection"; then
            prompt_default "Enable brute-force protection (yes|no)" "$bf_enabled"; bf_enabled="$REPLY_VALUE"
            prompt_default "Auth log path" "$auth_log"; auth_log="$REPLY_VALUE"
            prompt_default "Max failed attempts" "$bf_max"; bf_max="$REPLY_VALUE"
            prompt_default "Window (minutes)" "$bf_window"; bf_window="$REPLY_VALUE"
            prompt_default "Block duration (minutes)" "$bf_block"; bf_block="$REPLY_VALUE"
        fi

        # --- Malware scan ---
        malware_enabled="yes"; scan_path="/var/www"; quarantine_enabled="yes"; quarantine_path="quarantine"
        if section_customize "malware scan"; then
            prompt_default "Enable malware scan (yes|no)" "$malware_enabled"; malware_enabled="$REPLY_VALUE"
            prompt_default "Scan path" "$scan_path"; scan_path="$REPLY_VALUE"
            prompt_default "Enable quarantine (yes|no)" "$quarantine_enabled"; quarantine_enabled="$REPLY_VALUE"
            prompt_default "Quarantine path" "$quarantine_path"; quarantine_path="$REPLY_VALUE"
        fi

        # --- Vulnerability scan ---
        vuln_enabled="yes"
        if section_customize "vulnerability scan"; then
            prompt_default "Enable vulnerability scan (yes|no)" "$vuln_enabled"; vuln_enabled="$REPLY_VALUE"
        fi
        echo ""

        # Summary
        print_header "CONFIGURATION SUMMARY"
        echo -e "Please review your configuration:"
        echo ""
        echo -e "📁 Install location:  $install_location"
        echo -e "🔑 API Key:           ${api_key:0:8}...${api_key: -4}"
        echo -e "🌐 Interface:         $network_interface"
        echo -e "🌐 Domain:            ${domain:-<hostname>}"
        echo -e "📧 SMTP host:         ${smtp_host:-<not set>}   Notify: ${notify_email:-<not set>}"
        echo -e "🛡️  Brute-force: $bf_enabled   Malware: $malware_enabled   Vuln: $vuln_enabled"
        echo ""
        echo -e "Is this information correct?"
        echo -e "[y] Yes - Begin installation"
        echo -e "[n] No  - Re-enter information"
        echo -n -e "👉 Your choice (y/n): "
        read -r -u 3 confirm
        echo ""

        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            # Validate inputs
            if [[ -z "$install_location" || -z "$api_key" ]]; then
                print_error "Install location and API key are required."
                echo -e "Press Enter to continue..."
                read -r -u 3
                continue
            fi
            if [[ ! -d "$install_location" ]]; then
                print_error "Directory does not exist: $install_location"
                print_info "Please enter a valid path."
                echo -e "Press Enter to continue..."
                read -r -u 3
                continue
            fi
            if ! validate_interface "$network_interface"; then
                print_error "Network interface does not exist: $network_interface"
                print_info "Available interfaces: $available_interfaces"
                echo -e "Press Enter to continue..."
                read -r -u 3
                continue
            fi
            break
        elif [[ "$confirm" == "n" || "$confirm" == "N" ]]; then
            print_info "Please enter the information again."
            echo ""
        else
            print_error "Invalid input. Please enter 'y' or 'n'."
            echo -e "Press Enter to continue..."
            read -r -u 3
        fi
    done
}

# =============================================================================
# STEP 4: INSTALL
# =============================================================================
install_boteraser_pro() {
    print_header "INSTALLING BOTERASER PRO CLIENT"

    # Create directory
    print_info "Creating directory: $install_location/boteraser-pro"
    mkdir -p "$install_location/boteraser-pro"
    print_success "Directory created"

    echo ""

    # Download
    print_info "Downloading Boteraser PRO client..."
    echo -e "📦 Source: $DOWNLOAD_URL"
    if wget -q --show-progress -O "$install_location/be-client-pro-latest.tar.gz" "$DOWNLOAD_URL"; then
        print_success "Package downloaded successfully"
    else
        print_error "Failed to download package"
        exit 1
    fi

    echo ""

    # Unpack
    print_info "Unpacking package..."
    if tar -xzf "$install_location/be-client-pro-latest.tar.gz" -C "$install_location"; then
        print_success "Package unpacked successfully"
    else
        print_error "Failed to unpack package"
        exit 1
    fi

    # Cleanup archive
    rm -f "$install_location/be-client-pro-latest.tar.gz"
    print_success "Archive removed"

    echo ""

    # Permissions
    print_info "Setting file permissions..."
    find "$install_location/boteraser-pro" -type d -exec chmod 755 {} \;
    find "$install_location/boteraser-pro" -type f -exec chmod 644 {} \;
    if [[ -f "$install_location/boteraser-pro/be-client-pro" ]]; then
        chmod 755 "$install_location/boteraser-pro/be-client-pro"
        print_success "Execute permission granted to be-client-pro"
    else
        print_warning "be-client-pro binary not found in $install_location/boteraser-pro"
    fi
    chown -R root:root "$install_location/boteraser-pro"
    print_success "Ownership set to root:root"

    echo ""

    # Configure be-pro.conf (shipped with the package — patch values in place)
    local conf_file="$install_location/boteraser-pro/be-pro.conf"
    print_info "Configuring be-pro.conf..."
    if [[ ! -f "$conf_file" ]]; then
        print_error "be-pro.conf not found in package: $conf_file"
        exit 1
    fi
    conf_set "$conf_file" CONSENT_ACCEPTED "yes"
    conf_set "$conf_file" API_KEY_PRO      "$api_key"
    conf_set "$conf_file" INTERFACE        "$network_interface"
    conf_set "$conf_file" DOMAIN           "$domain"
    conf_set "$conf_file" BLOCK_TIMEOUT    "$block_timeout"
    conf_set "$conf_file" SMTP_HOST        "$smtp_host"
    conf_set "$conf_file" SMTP_PORT        "$smtp_port"
    conf_set "$conf_file" SMTP_USER        "$smtp_user"
    conf_set "$conf_file" SMTP_PASS        "$smtp_pass"
    conf_set "$conf_file" SMTP_FROM        "$smtp_from"
    conf_set "$conf_file" SMTP_SECURITY    "$smtp_security"
    conf_set "$conf_file" NOTIFY_EMAIL     "$notify_email"
    conf_set "$conf_file" REPORT_INTERVAL  "$report_interval"
    conf_set "$conf_file" BF_ENABLED       "$bf_enabled"
    conf_set "$conf_file" AUTH_LOG         "$auth_log"
    conf_set "$conf_file" BF_MAX_ATTEMPTS  "$bf_max"
    conf_set "$conf_file" BF_WINDOW        "$bf_window"
    conf_set "$conf_file" BF_BLOCK         "$bf_block"
    conf_set "$conf_file" MALWARE_ENABLED  "$malware_enabled"
    conf_set "$conf_file" SCAN_PATH        "$scan_path"
    conf_set "$conf_file" QUARANTINE_ENABLED "$quarantine_enabled"
    conf_set "$conf_file" QUARANTINE_PATH  "$quarantine_path"
    conf_set "$conf_file" VULN_ENABLED     "$vuln_enabled"
    chmod 600 "$conf_file"
    print_success "Configuration file updated (permissions: 600)"

    echo ""

    # Install systemd service
    print_info "Installing systemd service file..."
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Boteraser PRO Client (traffic-fingerprinting daemon)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$install_location/boteraser-pro
ExecStart=$install_location/boteraser-pro/be-client-pro --daemon
Restart=on-failure
RestartSec=10
# Needs root for raw-socket capture, eBPF (JA4H over HTTPS), iptables/ipset
# and reading the SSH auth log.
User=root
# eBPF maps require a high memlock limit.
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOF
    chmod 644 "$SERVICE_FILE"
    print_success "Service file installed: $SERVICE_FILE"

    echo ""

    # Enable and start service
    print_info "Enabling and starting service..."
    systemctl daemon-reload
    print_success "systemctl daemon-reload"

    systemctl enable be-client-pro
    print_success "Service enabled (starts on boot)"

    systemctl start be-client-pro
    if systemctl is-active --quiet be-client-pro; then
        print_success "Service started successfully"
    else
        print_warning "Service may not have started. Check: journalctl -u be-client-pro"
    fi
}

# =============================================================================
# STEP 5: SUMMARY
# =============================================================================
print_summary() {
    print_header "INSTALLATION COMPLETED SUCCESSFULLY"
    echo ""
    echo -e "🎉 Boteraser PRO has been installed and started!"
    echo ""
    echo -e "📍 Install location: $install_location/boteraser-pro"
    echo -e "🔑 API Key:          Configured"
    echo -e "🌐 Interface:        $network_interface"
    echo -e "⚙️  Service:          be-client-pro (systemd)"
    echo ""
    echo -e "╔══════════════════════════════════════════════════════════════╗"
    echo -e "║                    USEFUL COMMANDS                           ║"
    echo -e "╚══════════════════════════════════════════════════════════════╝"
    echo -e "  systemctl status be-client-pro"
    echo -e "  systemctl stop be-client-pro"
    echo -e "  systemctl restart be-client-pro"
    echo -e "  journalctl -u be-client-pro -f"
    echo ""
    echo -e "╔══════════════════════════════════════════════════════════════╗"
    echo -e "║                  BEHIND A NAT OR PROXY?                      ║"
    echo -e "╚══════════════════════════════════════════════════════════════╝"
    print_info "Traffic from private addresses is ignored (EXCLUDE_LOCAL=\"yes\")."
    echo -e "  This keeps the capture buffer for real visitors and is correct"
    echo -e "  for almost every server."
    echo ""
    print_info "Plain port forwarding (DNAT) is fine — it rewrites the destination"
    echo -e "  only, so real visitor IPs stay visible. Nothing to change."
    echo ""
    print_warning "Only a reverse proxy (nginx, HAProxy, Cloudflare), a load balancer"
    echo -e "  in proxy mode, or inbound SNAT rewrites the visitor's SOURCE address."
    echo -e "  Then every visitor looks private and nothing is analysed. In that case:"
    echo ""
    echo -e "    $install_location/boteraser-pro/be-pro.conf"
    echo -e "    EXCLUDE_LOCAL=\"no\""
    echo -e "    systemctl restart be-client-pro"
    echo ""
    echo -e "  Check with: journalctl -u be-client-pro | grep 'TOP 30' -A 5"
    echo -e "  Public visitor IPs listed there mean the default is fine."
    echo ""
    print_info "Boteraser PRO is now protecting your server!"
    echo ""
}

# =============================================================================
# UPDATE
# =============================================================================
update_boteraser_pro() {
    print_header "UPDATING BOTERASER PRO CLIENT"

    print_info "Downloading latest package..."
    echo -e "📦 Source: $DOWNLOAD_URL"
    if wget -q --show-progress -O "/tmp/be-client-pro-latest.tar.gz" "$DOWNLOAD_URL"; then
        print_success "Package downloaded successfully"
    else
        print_error "Failed to download package"
        exit 1
    fi

    echo ""
    print_info "Unpacking package..."
    if tar -xzf "/tmp/be-client-pro-latest.tar.gz" -C "/tmp"; then
        print_success "Package unpacked successfully"
    else
        print_error "Failed to unpack package"
        exit 1
    fi

    echo ""
    print_info "Stopping service..."
    systemctl stop be-client-pro
    print_success "Service stopped"

    echo ""
    print_info "Replacing be-client-pro binary..."
    if [[ -f "/tmp/boteraser-pro/be-client-pro" ]]; then
        cp "/tmp/boteraser-pro/be-client-pro" "$existing_install/boteraser-pro/be-client-pro"
        chmod 755 "$existing_install/boteraser-pro/be-client-pro"
        chown root:root "$existing_install/boteraser-pro/be-client-pro"
        print_success "Binary updated successfully"
    else
        print_error "be-client-pro binary not found in downloaded package"
        systemctl start be-client-pro
        exit 1
    fi

    # Cleanup
    rm -rf "/tmp/be-client-pro-latest.tar.gz" "/tmp/boteraser-pro"

    echo ""
    print_info "Starting service..."
    systemctl start be-client-pro
    if systemctl is-active --quiet be-client-pro; then
        print_success "Service started successfully"
    else
        print_warning "Service may not have started. Check: journalctl -u be-client-pro"
    fi

    echo ""
    print_header "UPDATE COMPLETED SUCCESSFULLY"
    echo ""
    echo -e "🎉 Boteraser PRO has been updated successfully!"
    echo ""
    echo -e "📍 Install location: $existing_install/boteraser-pro"
    echo -e "🔑 API Key:          Unchanged"
    echo -e "🌐 Interface:        Unchanged"
    echo -e "⚙️  Service:          be-client-pro (systemd)"
    echo ""
    print_info "Boteraser PRO is now running the latest version!"
    echo ""
}

# =============================================================================
# RUN
# =============================================================================
check_dependencies

# Detect existing installation
existing_install=""
for dir in /opt /usr/local /root /home; do
    if [[ -f "$dir/boteraser-pro/be-client-pro" && -f "$dir/boteraser-pro/be-pro.conf" ]]; then
        existing_install="$dir"
        break
    fi
done

if [[ -n "$existing_install" ]]; then
    print_header "EXISTING INSTALLATION DETECTED"
    echo ""
    print_info "Boteraser PRO is already installed at: $existing_install/boteraser-pro"
    echo ""
    echo -e "Do you want to update to the latest version?"
    echo -e "[y] Yes - Update binary (be-pro.conf and service will remain unchanged)"
    echo -e "[n] No  - Cancel"
    echo -n -e "👉 Your choice (y/n): "
    read -r -u 3 update_answer
    echo ""
    if [[ "$update_answer" == "y" || "$update_answer" == "Y" ]]; then
        update_boteraser_pro
    else
        print_info "Update cancelled."
        echo ""
    fi
    exit 0
fi

ask_privacy_consent
ask_configuration
install_boteraser_pro
print_summary
