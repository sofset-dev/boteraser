#!/bin/bash

# Configuration variables
DOWNLOAD_URL="https://github.com/sofset-dev/boteraser/raw/refs/heads/main/be-client/be-client-latest.tar.gz"

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

# Function to check if running as root
check_root_privileges() {
    if [[ $EUID -ne 0 ]]; then
        echo "Error: This script must be run as root (use sudo)."
        exit 1
    fi
    echo "✅ Root privileges confirmed"
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
        read consent_answer

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
    echo -e "Example: /opt"
    echo -n -e "👉 Install location: "
    read install_location
}

# Function to ask for API key
ask_api_key() {
    echo -e "🔑 API Key Configuration"
    echo -e "Enter your Boteraser API key"
    echo -e "You can find/generate it at: https://user.boteraser.com/api.php"
    echo -n -e "👉 API Key: "
    read api_key
}

# Function to ask for log path
ask_log_path() {
    echo -e "📄 Access Log Path"
    echo -e "Enter the full path to your domain's access.log file"
    echo -e "Example: /var/log/nginx/access.log or /var/log/apache2/access.log"
    echo -n -e "👉 Log path: "
    read log_path
}

# Function to begin installation of boteraser client
install_boteraser_client() {
    print_header "INSTALLING BOTERASER CLIENT"
    
    print_info "Creating boteraser directory in $install_location..."
    mkdir -p "$install_location/boteraser"
    print_success "Directory created successfully"
    
    echo ""
    print_info "Downloading boteraser client package..."
    echo -e "📦 Downloading from: $DOWNLOAD_URL"
    
    if wget -O "$install_location/be-client-latest.tar.gz" "$DOWNLOAD_URL"; then
        print_success "Package downloaded successfully"
    else
        print_error "Failed to download package"
        exit 1
    fi
    
    echo ""
    print_info "Unpacking boteraser client package..."
    if tar -xzf "$install_location/be-client-latest.tar.gz" -C "$install_location"; then
        print_success "Package unpacked successfully"
    else
        print_error "Failed to unpack package"
        exit 1
    fi
    
    echo ""
    print_info "Setting file permissions..."
    find "$install_location/boteraser" -type d -exec chmod 755 {} \;
    find "$install_location/boteraser" -type f -exec chmod 644 {} \;
    print_success "Directory permissions set (755)"
    print_success "File permissions set (644)"
    
    # Change permission for the specific file `be-client`
    if [[ -f "$install_location/boteraser/be-client" ]]; then
        print_info "Granting execute permission to be-client..."
        chmod 755 "$install_location/boteraser/be-client"
        print_success "Execute permission granted (755)"
    else
        print_warning "be-client file not found in $install_location/boteraser"
    fi
    
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
    print_info "Creating configuration file (be.conf)..."
    
    # Create be.conf file with user's API key and log path
    cat > "$install_location/boteraser/be.conf" << EOF
# ============================================================================
# IMPORTANT PRIVACY INFORMATION - PLEASE READ FIRST
# ============================================================================
# This software monitors and sends visitor IP addresses and bot identifiers
# (browser type derived from device information) from your web server logs to
# user.boteraser.com (EU-based service) for security threat analysis and
# blocking of unwanted bots and blacklisted IPs.
#
# Legal basis: Legitimate interest for server security (GDPR Art. 6(1)(f))
# CCPA compliance: Data is not sold or shared (see Privacy Policy)
#
# IMPORTANT: You MUST disclose this data collection in your website's Privacy Policy.
#
# Privacy Policy: https://boteraser.com/privacy-policy/
# Terms of Service: https://boteraser.com/terms-of-service/

# User consent: By setting this to "yes", you confirm that you have read, understood,
# and agree to both our Privacy Policy and Terms of Service linked above.
# Default: no - Software will not function until set to "yes"
CONSENT_ACCEPTED="yes"
# ============================================================================

# This is config file needed for bs-client program to communicate with our server.
# For Software to function properly you need to enter following data:
# - API_KEY - generate API KEY in your user menu on https://user.boteraser.com/api.php
# - LOG_PATH - enter path where access.log for your domain is located
#   Notice: you need to have read/write permissions in the directory.

# Please, enter data. You must edit config file for your program to work properly!

# Your auth API KEY. You can find it in your user menu at https://user.boteraser.com/api.php
API_KEY="$api_key"

# Enter access log path for your domain
LOG_PATH="$log_path"
EOF
    
    if [[ -f "$install_location/boteraser/be.conf" ]]; then
        print_success "Configuration file created successfully"
        chmod 600 "$install_location/boteraser/be.conf"
        print_success "Configuration file permissions set (600)"
    else
        print_error "Failed to create configuration file"
        exit 1
    fi
    
    echo ""
    print_info "Setting up cron job for automatic execution..."
    
    # Add cron job (preserve existing crontab)
    cron_comment="# Boteraser Client - Auto IP blocking every 5 minutes"
    cron_rule="*/5 * * * * $install_location/boteraser/be-client >/dev/null 2>&1"
    
    # Check if cron job already exists
    if crontab -l 2>/dev/null | grep -q "be-client"; then
        print_warning "Boteraser cron job already exists"
    else
        # Add new cron job to existing crontab with comment on separate line
        (crontab -l 2>/dev/null; echo "$cron_comment"; echo "$cron_rule") | crontab -
        if [[ $? -eq 0 ]]; then
            print_success "Cron job added successfully"
            print_info "Boteraser will run every 5 minutes automatically"
        else
            print_error "Failed to add cron job"
            print_info "You can manually add: $cron_rule"
        fi
    fi
    
    echo ""
    print_header "INSTALLATION COMPLETED SUCCESSFULLY!"
    echo -e "🎉 Boteraser client has been installed successfully!"
    echo ""
    echo -e "📍 Installation Location: $install_location/boteraser"
    echo -e "👤 Owner User:           root"
    echo -e "👥 Owner Group:          root"
    echo -e "🔑 API Key:              Configured"
    echo -e "📄 Log Path:             $log_path"
    echo -e "⏰ Cron Job:             Every 5 minutes"
    echo ""
    print_info "Boteraser is now ready to protect your server!"
    echo ""
}

# Function to update existing installation
update_boteraser_client() {
    print_header "UPDATING BOTERASER CLIENT"

    print_info "Downloading latest package..."
    echo -e "📦 Downloading from: $DOWNLOAD_URL"

    if wget -O "/tmp/be-client-latest.tar.gz" "$DOWNLOAD_URL"; then
        print_success "Package downloaded successfully"
    else
        print_error "Failed to download package"
        exit 1
    fi

    echo ""
    print_info "Unpacking package..."
    if tar -xzf "/tmp/be-client-latest.tar.gz" -C "/tmp"; then
        print_success "Package unpacked successfully"
    else
        print_error "Failed to unpack package"
        exit 1
    fi

    echo ""
    print_info "Replacing be-client binary..."
    if [[ -f "/tmp/boteraser/be-client" ]]; then
        cp "/tmp/boteraser/be-client" "$existing_install/boteraser/be-client"
        chmod 755 "$existing_install/boteraser/be-client"
        chown root:root "$existing_install/boteraser/be-client"
        print_success "Binary updated successfully"
    else
        print_error "be-client binary not found in downloaded package"
        exit 1
    fi

    # Cleanup
    rm -rf "/tmp/be-client-latest.tar.gz" "/tmp/boteraser"

    echo ""
    print_header "UPDATE COMPLETED SUCCESSFULLY!"
    echo -e "🎉 Boteraser client has been updated successfully!"
    echo ""
    echo -e "📍 Installation Location: $existing_install/boteraser"
    echo -e "🔑 API Key:              Unchanged"
    echo -e "📄 Log Path:             Unchanged"
    echo -e "⏰ Cron Job:             Unchanged"
    echo ""
    print_info "Boteraser is now running the latest version!"
    echo ""
}

# Check and install dependencies
check_dependencies

# Detect existing installation
existing_install=""
for dir in /opt /usr/local /root /home; do
    if [[ -f "$dir/boteraser/be-client" && -f "$dir/boteraser/be.conf" ]]; then
        existing_install="$dir"
        break
    fi
done

if [[ -n "$existing_install" ]]; then
    print_header "EXISTING INSTALLATION DETECTED"
    echo ""
    print_info "Boteraser is already installed at: $existing_install/boteraser"
    echo ""
    echo -e "Do you want to update to the latest version?"
    echo -e "[y] Yes - Update binary (be.conf and cron will remain unchanged)"
    echo -e "[n] No  - Cancel"
    echo -n -e "👉 Your choice (y/n): "
    read update_answer
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
    ask_log_path

    echo ""
    print_header "CONFIGURATION SUMMARY"
    echo -e "Please review your configuration:"
    echo ""
    echo -e "📁 Install location: $install_location"
    echo -e "🔑 API Key: ${api_key:0:8}...${api_key: -8}"
    echo -e "📄 Log path: $log_path"
    echo ""

    # Confirm with the user if the information is correct
    echo -e "Is this information correct?"
    echo -e "[y] Yes - Begin installation"
    echo -e "[n] No - Re-enter information"
    echo -n -e "👉 Your choice (y/n): "
    read confirm

    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        # Validate inputs before proceeding
        if [[ -z "$install_location" || -z "$api_key" || -z "$log_path" ]]; then
            echo ""
            print_error "All fields are required. Please enter all information."
            echo ""
            echo -e "Press Enter to continue..."
            read
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
                read
            fi
        else
            echo ""
            print_error "The specified directory does not exist: $install_location"
            print_info "Please enter a valid path."
            echo ""
            echo -e "Press Enter to continue..."
            read
        fi
    elif [[ "$confirm" == "n" || "$confirm" == "N" ]]; then
        # Ask for the information again
        echo ""
        print_info "Please enter the information again."
        echo ""
        echo -e "Press Enter to continue..."
        read
    else
        # Handle invalid input
        echo ""
        print_error "Invalid input. Please enter 'y' to confirm or 'n' to re-enter information."
        echo ""
        echo -e "Press Enter to continue..."
        read
    fi
done

