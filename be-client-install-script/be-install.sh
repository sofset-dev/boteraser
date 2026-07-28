#!/bin/bash

# Configuration variables
DOWNLOAD_URL="https://github.com/sofset-dev/boteraser/raw/refs/heads/main/be-client/be-client-latest.tar.gz"
SERVICE_FILE="/etc/systemd/system/be-client.service"
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
    echo -e "⚠️ $1"
}

# Function to print info messages
print_info() {
    echo -e "ℹ️ $1"
}

# Check root privileges first - MUST be run as root
if [[ $EUID -ne 0 ]]; then
    print_header "BOTERASER CLIENT INSTALLER"
    echo ""
    print_error "This script must be run as root!"
    echo ""
    print_info "Please log in as root user or use appropriate"
    print_info "privilege escalation method for your system"
    print_info "and run the script again."
    echo ""
    echo -e "╚══════════════════════════════════════════════════════════════╝"
    exit 1
fi

print_header "BOTERASER CLIENT INSTALLER"
print_success "Root privileges confirmed - proceeding with installation..."
echo ""

# All prompts read from /dev/tty, so the installer also works when it is piped
# into bash (curl -fsSL ... | sudo bash), where stdin carries the script itself.
if [[ ! -r /dev/tty ]]; then
    print_error "No terminal available for input!"
    echo ""
    print_info "This installer is interactive and must be run from a terminal."
    echo ""
    exit 1
fi

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
    read -r input < /dev/tty
    REPLY_VALUE="${input:-$default}"
}

# Prompt for a secret (input hidden). Enter keeps the current default.
prompt_secret() {
    local label="$1" default="$2" input
    echo -n -e "👉 $label (hidden, Enter to keep default): "
    read -rs input < /dev/tty
    echo ""
    REPLY_VALUE="${input:-$default}"
}

# Ask whether the user wants to customize an optional section.
# Returns 0 (yes) or 1 (keep defaults).
section_customize() {
    local name="$1" ans
    echo ""
    echo -n -e "👉 Configure $name now? (Enter = keep defaults / y = customize): "
    read -r ans < /dev/tty
    [[ "$ans" == "y" || "$ans" == "Y" ]]
}

# Function to check and install dependencies
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
    
    # Check ipset (required for high-performance IP blocking)
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

    # Check awk
    if ! command -v awk &> /dev/null; then
        print_error "awk not found"
        missing_deps+=("gawk")
    else
        print_success "awk found"
    fi
    
    # Check curl
    if ! command -v curl &> /dev/null; then
        print_error "curl not found"
        missing_deps+=("curl")
    else
        print_success "curl found"
    fi

    # Check wget (used to download the client package)
    if ! command -v wget &> /dev/null; then
        print_error "wget not found"
        missing_deps+=("wget")
    else
        print_success "wget found"
    fi

    # Check systemd (be-client runs as a systemd service)
    if ! command -v systemctl &> /dev/null; then
        print_error "systemctl not found"
        echo ""
        print_error "This installer requires systemd, which is not available on this system."
        print_info "Please install be-client manually - see the README.md in the package."
        exit 1
    else
        print_success "systemctl found"
    fi

    echo ""
    
    # Install missing dependencies
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_warning "Installing missing dependencies: ${missing_deps[*]}"
        echo ""
        
        # Detect package manager and install
        if command -v apt-get &> /dev/null; then
            print_info "Using apt-get package manager..."
            apt-get update
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
            print_error "Could not detect package manager. Please install the following manually:"
            echo -e "${missing_deps[*]}"
            exit 1
        fi
        
        echo ""
        print_success "Dependencies installed successfully!"
    else
        print_success "All dependencies are already installed."
    fi
    echo ""
}

# Function to display and ask for privacy consent
ask_privacy_consent() {
    print_header "IMPORTANT PRIVACY INFORMATION"
    echo ""
    echo -e "This software monitors and sends visitor IP addresses and bot identifiers"
    echo -e "(browser type derived from device information) from your web server logs to"
    echo -e "user.boteraser.com (EU-based service) for security threat analysis and"
    echo -e "blocking of unwanted bots and blacklisted IPs."
    echo ""
    echo -e "📋 Legal basis: Legitimate interest for server security (GDPR Art. 6(1)(f))"
    echo -e "📋 CCPA compliance: Data is not sold or shared (see Privacy Policy)"
    echo ""
    print_warning "You MUST disclose this data collection in your website's Privacy Policy."
    echo ""
    echo -e "📄 Privacy Policy: https://boteraser.com/privacy-policy/"
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
        read -r consent_answer < /dev/tty

        if [[ "$consent_answer" == "y" || "$consent_answer" == "Y" ]]; then
            echo ""
            print_success "Privacy Policy and Terms of Service accepted"
            echo ""
            return 0
        elif [[ "$consent_answer" == "n" || "$consent_answer" == "N" ]]; then
            echo ""
            print_error "Privacy Policy and Terms of Service not accepted"
            echo ""
            print_info "Installation cancelled. You cannot use this software without accepting"
            print_info "our Privacy Policy and Terms of Service."
            echo ""
            exit 0
        else
            echo ""
            print_error "Invalid input. Please enter 'y' to accept or 'n' to cancel."
            echo -n -e "👉 Your choice (y/n): "
        fi
    done
}

# Function to ask for installation location
ask_install_location() {
    echo -e "📁 Installation Location"
    echo -e "Enter the directory where Boteraser will be installed"
    echo -e "Press Enter to accept the default"
    echo -n -e "👉 Install location [$DEFAULT_INSTALL_LOCATION]: "
    read -r install_location < /dev/tty
    install_location="${install_location:-$DEFAULT_INSTALL_LOCATION}"
    install_location="${install_location%/}"
}

# Function to ask for API key
ask_api_key() {
    echo -e "🔑 API Key Configuration"
    echo -e "Enter your Boteraser API key"
    echo -e "You can find/generate it at: https://user.boteraser.com/api.php"
    echo -n -e "👉 API Key: "
    read -r api_key < /dev/tty
}

# Function to gather every be.conf setting. Required values are always asked;
# optional sections show their defaults and can be kept with a single Enter.
ask_configuration() {
    echo ""
    print_info "Press Enter at any prompt to accept the [default] shown in brackets."
    echo ""

    echo -e "📄 Access Log Path (required)"
    echo -e "Full path to your domain's access.log file"
    echo -e "Example: /var/log/nginx/access.log or /var/log/apache2/access.log"
    prompt_default "Log path" ""; log_path="$REPLY_VALUE"
    echo ""

    echo -e "🌐 Domain (optional — used in email reports; hostname if left blank)"
    prompt_default "Domain" ""; domain="$REPLY_VALUE"

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

    # --- Vulnerability scan & log-based WAF ---
    vuln_enabled="yes"; waf_enabled="yes"; waf_block="60"
    if section_customize "vulnerability scan & WAF"; then
        prompt_default "Enable vulnerability scan (yes|no)" "$vuln_enabled"; vuln_enabled="$REPLY_VALUE"
        prompt_default "Enable log-based WAF (yes|no)" "$waf_enabled"; waf_enabled="$REPLY_VALUE"
        prompt_default "WAF block duration (minutes)" "$waf_block"; waf_block="$REPLY_VALUE"
    fi
}

# Function to download and unpack the package into a temp dir. Sets $pkg_dir.
fetch_package() {
    pkg_dir=$(mktemp -d)
    trap 'rm -rf "$pkg_dir"' EXIT

    print_info "Downloading boteraser client package..."
    echo -e "📦 Downloading from: $DOWNLOAD_URL"

    if wget -O "$pkg_dir/be-client-latest.tar.gz" "$DOWNLOAD_URL"; then
        print_success "Package downloaded successfully"
    else
        print_error "Failed to download package"
        exit 1
    fi

    echo ""
    print_info "Unpacking boteraser client package..."
    if tar -xzf "$pkg_dir/be-client-latest.tar.gz" -C "$pkg_dir"; then
        print_success "Package unpacked successfully"
    else
        print_error "Failed to unpack package"
        exit 1
    fi

    for f in be-client be.conf be-client.service; do
        if [[ ! -f "$pkg_dir/boteraser/$f" ]]; then
            print_error "$f not found in downloaded package"
            exit 1
        fi
    done
}

# Function to remove the cron job left behind by pre-daemon installations.
# The client is a long-running daemon now, so a cron job would start a new
# instance every 5 minutes on top of the one already running.
remove_legacy_cron() {
    if crontab -l 2>/dev/null | grep -q "be-client"; then
        print_info "Removing legacy cron job..."
        crontab -l 2>/dev/null \
            | grep -v "be-client" \
            | grep -v "Boteraser Client - Auto IP blocking" \
            | crontab -
        print_success "Legacy cron job removed"
    fi
}

# Function to install the systemd unit for the given install location
install_service() {
    local target="$1"

    print_info "Installing systemd service..."

    # The packaged unit is hardcoded to /opt/boteraser - point it at the
    # location the user actually chose.
    sed "s|/opt/boteraser|$(sed_escape "$target/boteraser")|g" \
        "$pkg_dir/boteraser/be-client.service" > "$SERVICE_FILE"
    chmod 644 "$SERVICE_FILE"

    if systemctl daemon-reload; then
        print_success "Service installed ($SERVICE_FILE)"
    else
        print_error "Failed to reload systemd"
        exit 1
    fi
}

# Function to enable, start and verify the service
start_service() {
    print_info "Enabling and starting be-client service..."
    systemctl enable be-client &> /dev/null
    systemctl restart be-client

    sleep 2
    if systemctl is-active --quiet be-client; then
        print_success "Service is running and enabled on boot"
    else
        print_error "Service failed to start"
        echo ""
        print_info "Last log lines:"
        journalctl -u be-client -n 20 --no-pager
        exit 1
    fi
}

# Function to print the commands the user needs after install/update
print_service_commands() {
    print_info "Useful commands:"
    echo -e "  systemctl status be-client     # service status"
    echo -e "  systemctl restart be-client    # restart after editing be.conf"
    echo -e "  journalctl -u be-client -f     # follow the live log"
    echo ""
}

# Function to begin installation of boteraser client
install_boteraser_client() {
    print_header "INSTALLING BOTERASER CLIENT"

    fetch_package

    echo ""
    print_info "Creating boteraser directory in $install_location..."
    mkdir -p "$install_location/boteraser"
    print_success "Directory created successfully"

    echo ""
    print_info "Installing files..."
    cp "$pkg_dir/boteraser/be-client" "$install_location/boteraser/be-client"
    cp "$pkg_dir/boteraser/be.conf" "$install_location/boteraser/be.conf"
    if [[ -f "$pkg_dir/boteraser/README.md" ]]; then
        cp "$pkg_dir/boteraser/README.md" "$install_location/boteraser/README.md"
    fi
    print_success "Files installed successfully"

    echo ""
    print_info "Configuring be.conf with your settings..."

    # Write every value the user chose (or accepted as default) into be.conf.
    conf="$install_location/boteraser/be.conf"
    conf_set "$conf" CONSENT_ACCEPTED "yes"
    conf_set "$conf" API_KEY          "$api_key"
    conf_set "$conf" LOG_PATH         "$log_path"
    conf_set "$conf" DOMAIN           "$domain"
    conf_set "$conf" SMTP_HOST        "$smtp_host"
    conf_set "$conf" SMTP_PORT        "$smtp_port"
    conf_set "$conf" SMTP_USER        "$smtp_user"
    conf_set "$conf" SMTP_PASS        "$smtp_pass"
    conf_set "$conf" SMTP_FROM        "$smtp_from"
    conf_set "$conf" SMTP_SECURITY    "$smtp_security"
    conf_set "$conf" NOTIFY_EMAIL     "$notify_email"
    conf_set "$conf" REPORT_INTERVAL  "$report_interval"
    conf_set "$conf" BF_ENABLED       "$bf_enabled"
    conf_set "$conf" AUTH_LOG         "$auth_log"
    conf_set "$conf" BF_MAX_ATTEMPTS  "$bf_max"
    conf_set "$conf" BF_WINDOW        "$bf_window"
    conf_set "$conf" BF_BLOCK         "$bf_block"
    conf_set "$conf" MALWARE_ENABLED  "$malware_enabled"
    conf_set "$conf" SCAN_PATH        "$scan_path"
    conf_set "$conf" QUARANTINE_ENABLED "$quarantine_enabled"
    conf_set "$conf" QUARANTINE_PATH  "$quarantine_path"
    conf_set "$conf" VULN_ENABLED     "$vuln_enabled"
    conf_set "$conf" WAF_ENABLED      "$waf_enabled"
    conf_set "$conf" WAF_BLOCK        "$waf_block"

    if grep -qF "API_KEY=\"$api_key\"" "$conf"; then
        print_success "Configuration file written successfully"
    else
        print_error "Failed to write configuration file"
        exit 1
    fi

    echo ""
    print_info "Setting file permissions..."
    find "$install_location/boteraser" -type d -exec chmod 755 {} \;
    find "$install_location/boteraser" -type f -exec chmod 644 {} \;
    chmod 755 "$install_location/boteraser/be-client"
    chmod 600 "$conf"
    print_success "Directory permissions set (755)"
    print_success "File permissions set (644)"
    print_success "Execute permission granted to be-client (755)"
    print_success "Configuration file permissions set (600)"

    echo ""
    print_info "Setting ownership to root:root..."

    if chown -R root:root "$install_location/boteraser"; then
        print_success "Ownership configured successfully"
        echo -e "  👤 User:  root"
        echo -e "  👥 Group: root"
    else
        print_warning "Failed to change ownership"
    fi

    echo ""
    install_service "$install_location"

    echo ""
    start_service

    echo ""
    print_header "INSTALLATION COMPLETED SUCCESSFULLY!"
    echo -e "🎉 Boteraser client has been installed successfully!"
    echo ""
    echo -e "📍 Installation Location: $install_location/boteraser"
    echo -e "👤 Owner User:           root"
    echo -e "👥 Owner Group:          root"
    echo -e "🔑 API Key:              Configured"
    echo -e "📄 Log Path:             $log_path"
    echo -e "🔄 Service:              be-client (running, starts on boot)"
    echo ""
    print_info "Optional settings (email reports, brute-force, WAF, malware scan)"
    print_info "can be edited in: $conf"
    echo ""
    print_service_commands
    print_info "Boteraser is now ready to protect your server!"
    echo ""
}

# Function to update existing installation
update_boteraser_client() {
    print_header "UPDATING BOTERASER CLIENT"

    fetch_package

    echo ""
    if systemctl is-active --quiet be-client 2>/dev/null; then
        print_info "Stopping be-client service..."
        systemctl stop be-client
        print_success "Service stopped"
    fi

    remove_legacy_cron

    echo ""
    print_info "Replacing be-client binary..."
    cp "$pkg_dir/boteraser/be-client" "$existing_install/boteraser/be-client"
    chmod 755 "$existing_install/boteraser/be-client"
    chown root:root "$existing_install/boteraser/be-client"
    print_success "Binary updated successfully"

    if [[ -f "$pkg_dir/boteraser/README.md" ]]; then
        cp "$pkg_dir/boteraser/README.md" "$existing_install/boteraser/README.md"
        chmod 644 "$existing_install/boteraser/README.md"
        chown root:root "$existing_install/boteraser/README.md"
    fi

    echo ""
    install_service "$existing_install"

    echo ""
    start_service

    echo ""
    print_header "UPDATE COMPLETED SUCCESSFULLY!"
    echo -e "🎉 Boteraser client has been updated successfully!"
    echo ""
    echo -e "📍 Installation Location: $existing_install/boteraser"
    echo -e "🔑 API Key:              Unchanged"
    echo -e "📄 Log Path:             Unchanged"
    echo -e "🔄 Service:              be-client (running, starts on boot)"
    echo ""
    print_service_commands
    print_info "Boteraser is now running the latest version!"
    echo ""
}

# Check and install dependencies
check_dependencies

# Detect existing installation - the installed unit file knows the real path,
# so prefer it over guessing the common locations.
existing_install=""
if [[ -f "$SERVICE_FILE" ]]; then
    exec_path=$(grep -m1 '^ExecStart=' "$SERVICE_FILE" | sed 's|^ExecStart=||' | awk '{print $1}')
    if [[ -n "$exec_path" && -f "$exec_path" ]]; then
        existing_install=$(dirname "$(dirname "$exec_path")")
    fi
fi

if [[ -z "$existing_install" ]]; then
    for dir in /opt /usr/local /root /home; do
        if [[ -f "$dir/boteraser/be-client" && -f "$dir/boteraser/be.conf" ]]; then
            existing_install="$dir"
            break
        fi
    done
fi

if [[ -n "$existing_install" ]]; then
    print_header "EXISTING INSTALLATION DETECTED"
    echo ""
    print_info "Boteraser is already installed at: $existing_install/boteraser"
    echo ""
    echo -e "Do you want to update to the latest version?"
    echo -e "[y] Yes - Update binary (be.conf will remain unchanged)"
    echo -e "[n] No  - Cancel"
    echo -n -e "👉 Your choice (y/n): "
    read -r update_answer < /dev/tty
    echo ""
    if [[ "$update_answer" == "y" || "$update_answer" == "Y" ]]; then
        update_boteraser_client
    else
        print_info "Update cancelled."
        echo ""
    fi
    exit 0
fi

# Ask for privacy consent BEFORE configuration
ask_privacy_consent

# Main loop
while true; do
    print_header "CONFIGURATION SETUP"
    
    ask_install_location
    ask_api_key
    ask_configuration

    echo ""
    print_header "CONFIGURATION SUMMARY"
    echo -e "Please review your configuration:"
    echo ""
    echo -e "📁 Install location: $install_location"
    echo -e "🔑 API Key: ${api_key:0:8}...${api_key: -8}"
    echo -e "📄 Log path: $log_path"
    echo -e "🌐 Domain: ${domain:-<hostname>}"
    echo -e "📧 SMTP host: ${smtp_host:-<not set>}   Notify: ${notify_email:-<not set>}"
    echo -e "🛡️ Brute-force: $bf_enabled   Malware: $malware_enabled   Vuln: $vuln_enabled   WAF: $waf_enabled"
    echo ""

    # Confirm with the user if the information is correct
    echo -e "Is this information correct?"
    echo -e "[y] Yes - Begin installation"
    echo -e "[n] No - Re-enter information"
    echo -n -e "👉 Your choice (y/n): "
    read -r confirm < /dev/tty

    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        # Validate inputs before proceeding
        if [[ -z "$install_location" || -z "$api_key" || -z "$log_path" ]]; then
            echo ""
            print_error "All fields are required. Please enter all information."
            echo ""
            echo -e "Press Enter to continue..."
            read -r < /dev/tty
            continue
        fi
        
        # Check if install directory exists
        if [[ -d "$install_location" ]]; then
            # Check if log file exists
            if [[ -f "$log_path" ]]; then
                echo ""
                install_boteraser_client
                break
            else
                echo ""
                print_error "The specified log file does not exist: $log_path"
                print_info "Please enter a valid log file path."
                echo ""
                echo -e "Press Enter to continue..."
                read -r < /dev/tty
            fi
        else
            echo ""
            print_error "The specified directory does not exist: $install_location"
            print_info "Please enter a valid path."
            echo ""
            echo -e "Press Enter to continue..."
            read -r < /dev/tty
        fi
    elif [[ "$confirm" == "n" || "$confirm" == "N" ]]; then
        # Ask for the information again
        echo ""
        print_info "Please enter the information again."
        echo ""
        echo -e "Press Enter to continue..."
        read -r < /dev/tty
    else
        # Handle invalid input
        echo ""
        print_error "Invalid input. Please enter 'y' to confirm or 'n' to re-enter information."
        echo ""
        echo -e "Press Enter to continue..."
        read -r < /dev/tty
    fi
done

