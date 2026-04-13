#!/bin/bash

# Configuration variables
DOWNLOAD_URL="https://github.com/sofset-dev/boteraser/raw/refs/heads/main/be-client-pro/be-client-pro-latest.tar.gz"
SERVICE_NAME="be-client-pro"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

# Function to print headers
print_header() {
    echo ""
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
        read consent_answer
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
    if [[ "$interface" == "auto" ]]; then
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
        echo -e "Example: /opt"
        echo -n -e "👉 Install location [/opt]: "
        read install_location
        if [[ -z "$install_location" ]]; then
            install_location="/opt"
        fi
        echo ""

        # API key
        echo -e "🔑 API Key Configuration (PRO)"
        echo -e "Enter your Boteraser PRO API key"
        echo -e "You can find/generate it at: https://user.boteraser.com/api.php"
        echo -n -e "👉 API Key: "
        read api_key
        echo ""

        # Network interface
        local available_interfaces
        available_interfaces=$(get_network_interfaces)
        echo -e "🌐 Network Interface Configuration"
        echo -e "Available interfaces: $available_interfaces"
        echo -e "Enter 'auto' to auto-detect interface (recommended)"
        echo -n -e "👉 Interface [auto]: "
        read network_interface
        if [[ -z "$network_interface" ]]; then
            network_interface="auto"
        fi
        echo ""

        # Summary
        print_header "CONFIGURATION SUMMARY"
        echo -e "Please review your configuration:"
        echo ""
        echo -e "📁 Install location:  $install_location"
        echo -e "🔑 API Key:           ${api_key:0:8}...${api_key: -4}"
        echo -e "🌐 Interface:         $network_interface"
        echo ""
        echo -e "Is this information correct?"
        echo -e "[y] Yes - Begin installation"
        echo -e "[n] No  - Re-enter information"
        echo -n -e "👉 Your choice (y/n): "
        read confirm
        echo ""

        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            # Validate inputs
            if [[ -z "$install_location" || -z "$api_key" ]]; then
                print_error "Install location and API key are required."
                echo -e "Press Enter to continue..."
                read
                continue
            fi
            if [[ ! -d "$install_location" ]]; then
                print_error "Directory does not exist: $install_location"
                print_info "Please enter a valid path."
                echo -e "Press Enter to continue..."
                read
                continue
            fi
            if ! validate_interface "$network_interface"; then
                print_error "Network interface does not exist: $network_interface"
                print_info "Available interfaces: $available_interfaces"
                echo -e "Press Enter to continue..."
                read
                continue
            fi
            break
        elif [[ "$confirm" == "n" || "$confirm" == "N" ]]; then
            print_info "Please enter the information again."
            echo ""
        else
            print_error "Invalid input. Please enter 'y' or 'n'."
            echo -e "Press Enter to continue..."
            read
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

    # Create be-pro.conf
    print_info "Creating configuration file (be-pro.conf)..."
    cat > "$install_location/boteraser-pro/be-pro.conf" << EOF
# ============================================================================
# IMPORTANT PRIVACY INFORMATION - PLEASE READ FIRST
# ============================================================================
# This software monitors network traffic on your server and sends IP addresses
# to user.boteraser.com (EU-based service) for security threat analysis and
# blocking of blacklisted IPs.
#
# Legal basis: Legitimate interest for server security (GDPR Art. 6(1)(f))
# CCPA compliance: Data is not sold or shared (see Privacy Policy)
#
# Privacy Policy: https://boteraser.com/privacy-policy/
# Terms of Service: https://boteraser.com/terms-of-service/

# User consent: By setting this to "yes", you confirm that you have read,
# understood, and agree to both our Privacy Policy and Terms of Service.
CONSENT_ACCEPTED="yes"
# ============================================================================

# Your PRO API KEY. You can find it at: https://user.boteraser.com/api.php
API_KEY_PRO="$api_key"

# Network interface to monitor.
# "auto" = auto-detect, or specify interface name (e.g. eth0, ens3)
# Loopback (lo) is always excluded automatically.
INTERFACE="$network_interface"
EOF
    chmod 600 "$install_location/boteraser-pro/be-pro.conf"
    print_success "Configuration file created (permissions: 600)"

    echo ""

    # Create systemd service
    print_info "Creating systemd service file..."
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Boteraser PRO Client
After=network.target

[Service]
Type=simple
WorkingDirectory=$install_location/boteraser-pro
ExecStart=$install_location/boteraser-pro/be-client-pro
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    print_success "Service file created: $SERVICE_FILE"

    echo ""

    # Enable and start service
    print_info "Enabling and starting service..."
    systemctl daemon-reload
    print_success "systemctl daemon-reload"

    systemctl enable "$SERVICE_NAME"
    print_success "Service enabled (starts on boot)"

    systemctl start "$SERVICE_NAME"
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "Service started successfully"
    else
        print_warning "Service may not have started. Check: journalctl -u $SERVICE_NAME"
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
    echo -e "⚙️  Service:          $SERVICE_NAME (systemd)"
    echo ""
    echo -e "╔══════════════════════════════════════════════════════════════╗"
    echo -e "║                    USEFUL COMMANDS                           ║"
    echo -e "╚══════════════════════════════════════════════════════════════╝"
    echo -e "  systemctl status $SERVICE_NAME"
    echo -e "  systemctl stop $SERVICE_NAME"
    echo -e "  systemctl restart $SERVICE_NAME"
    echo -e "  journalctl -u $SERVICE_NAME -f"
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
    systemctl stop "$SERVICE_NAME"
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
        systemctl start "$SERVICE_NAME"
        exit 1
    fi

    # Cleanup
    rm -rf "/tmp/be-client-pro-latest.tar.gz" "/tmp/boteraser-pro"

    echo ""
    print_info "Starting service..."
    systemctl start "$SERVICE_NAME"
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "Service started successfully"
    else
        print_warning "Service may not have started. Check: journalctl -u $SERVICE_NAME"
    fi

    echo ""
    print_header "UPDATE COMPLETED SUCCESSFULLY"
    echo ""
    echo -e "🎉 Boteraser PRO has been updated successfully!"
    echo ""
    echo -e "📍 Install location: $existing_install/boteraser-pro"
    echo -e "🔑 API Key:          Unchanged"
    echo -e "🌐 Interface:        Unchanged"
    echo -e "⚙️  Service:          $SERVICE_NAME (systemd)"
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
    read update_answer
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
