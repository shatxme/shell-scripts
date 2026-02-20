#!/bin/bash

# VS Code Server Setup Script
# This script installs VS Code Server from Microsoft, Caddy as a reverse proxy,
# and sets up systemd services for both.
# 
# Usage:
#   ./vscode.sh          - Install VS Code Server
#   ./vscode.sh uninstall - Uninstall VS Code Server

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print functions
print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if running on Ubuntu
check_ubuntu() {
    if ! grep -q "Ubuntu" /etc/os-release; then
        print_error "This script is designed for Ubuntu only."
        exit 1
    fi
}

# Update and upgrade system
update_system() {
    print_info "Updating system packages..."
    sudo apt update && sudo apt upgrade -y
    print_success "System updated successfully."
}

# Get user input for domain, password, and port
get_user_input() {
    # Get domain
    while true; do
        read -p "Please enter your domain (e.g., vscode.example.com): " DOMAIN
        if [ -n "$DOMAIN" ]; then
            break
        fi
        print_error "Domain cannot be empty. Please try again."
    done
    
    # Get password
    while true; do
        read -s -p "Please enter a password for basic authentication: " PASSWORD
        echo ""
        if [ -n "$PASSWORD" ]; then
            read -s -p "Please confirm your password: " PASSWORD_CONFIRM
            echo ""
            if [ "$PASSWORD" = "$PASSWORD_CONFIRM" ]; then
                break
            else
                print_error "Passwords do not match. Please try again."
            fi
        else
            print_error "Password cannot be empty. Please try again."
        fi
    done
    
    # Get username (default: admin)
    read -p "Enter username for basic authentication (default: admin): " USERNAME
    if [ -z "$USERNAME" ]; then
        USERNAME="admin"
    fi
    
    # Get port (default: 4000)
    while true; do
        read -p "Enter port for VS Code Server (default: 4000): " VSCODE_PORT
        if [ -z "$VSCODE_PORT" ]; then
            VSCODE_PORT="4000"
        fi
        
        # Validate port is a number and in valid range
        if [[ "$VSCODE_PORT" =~ ^[0-9]+$ ]] && [ "$VSCODE_PORT" -ge 1024 ] && [ "$VSCODE_PORT" -le 65535 ]; then
            break
        else
            print_error "Port must be a number between 1024 and 65535."
        fi
    done
    
    print_success "Configuration details:"
    print_info "Domain: $DOMAIN"
    print_info "Username: $USERNAME"
    print_info "Port: $VSCODE_PORT"
    print_info "Password: [hidden]"
}

# Hash password using caddy
hash_password() {
    print_info "Hashing password..."
    PASSWORD_HASH=$(caddy hash-password --plaintext "$PASSWORD" | base64 -w 0)
    print_success "Password hashed successfully."
}

# Check if domain resolves to this server
check_domain_resolution() {
    print_info "Checking if domain resolves to this server..."
    
    # Get server's public IP
    SERVER_IP=$(curl -s -4 ifconfig.me 2>/dev/null || curl -s -4 ipinfo.io/ip 2>/dev/null || echo "unknown")
    
    # Get domain's IP
    DOMAIN_IP=$(dig +short "$DOMAIN" 2>/dev/null | head -n1 || echo "unknown")
    
    if [ "$SERVER_IP" = "unknown" ]; then
        print_warning "Could not determine server's public IP address."
        print_warning "Please ensure your domain $DOMAIN points to this server."
    elif [ "$DOMAIN_IP" = "unknown" ]; then
        print_warning "Could not resolve domain $DOMAIN."
        print_warning "Please ensure your domain is properly configured."
    elif [ "$DOMAIN_IP" != "$SERVER_IP" ]; then
        print_warning "Domain $DOMAIN resolves to $DOMAIN_IP, but this server's IP is $SERVER_IP."
        print_warning "Please update your DNS records to point $DOMAIN to $SERVER_IP."
        read -p "Do you want to continue anyway? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_success "Domain $DOMAIN correctly resolves to $SERVER_IP."
    fi
}

# Install VS Code Server
install_vscode_server() {
    # Check if VS Code Server is already installed
    if [ -d "$HOME/.vscode-server" ]; then
        print_success "VS Code Server is already installed. Skipping installation."
        return 0
    fi
    
    print_info "Installing VS Code Server..."
    
    # Install prerequisites
    sudo apt install -y curl wget gpg
    
    # Add Microsoft GPG key and repository
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
    sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
    
    # Update package list and install VS Code
    sudo apt update
    sudo apt install -y code
    
    # Create systemd service for VS Code Server
    if [ ! -f /etc/systemd/system/code-server.service ]; then
        print_info "Creating systemd service for VS Code Server..."
        
        cat <<EOF | sudo tee /etc/systemd/system/code-server.service > /dev/null
[Unit]
Description=VS Code Server
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME
ExecStart=/usr/bin/code --server-data-dir=$HOME/.vscode-server --host=0.0.0.0 --port=$VSCODE_PORT --auth=none --without-connection-token
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
        
        sudo systemctl daemon-reload
        sudo systemctl enable code-server
        print_success "VS Code Server systemd service created and enabled."
    else
        print_info "VS Code Server systemd service already exists."
    fi
    
    print_success "VS Code Server has been installed successfully."
}

# Install Caddy
install_caddy() {
    if command_exists caddy; then
        print_success "Caddy is already installed. Skipping installation."
        return 0
    fi
    
    print_info "Installing Caddy..."
    
    # Install Caddy using official documentation steps
    sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
    chmod o+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    chmod o+r /etc/apt/sources.list.d/caddy-stable.list
    sudo apt update
    sudo apt install -y caddy
    
    # Create systemd service for Caddy
    if [ ! -f /etc/systemd/system/caddy.service ]; then
        print_info "Creating systemd service for Caddy..."
        
        cat <<EOF | sudo tee /etc/systemd/system/caddy.service > /dev/null
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=caddy
Group=caddy
ExecStart=/usr/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/bin/caddy reload --config /etc/caddy/Caddyfile
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=infinity
PrivateTmp=yes
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF
        
        sudo systemctl daemon-reload
        sudo systemctl enable caddy
        print_success "Caddy systemd service created and enabled."
    else
        print_info "Caddy systemd service already exists."
    fi
    
    print_success "Caddy has been installed successfully."
}

# Create projects directory
create_projects_dir() {
    if [ -d "/projects" ]; then
        print_info "Projects directory already exists."
    else
        print_info "Creating projects directory..."
        sudo mkdir -p /projects
        sudo chown $USER:$USER /projects
        print_success "Projects directory created at /projects."
    fi
}

# Configure Caddy as reverse proxy
configure_caddy() {
    if [ -f "/etc/caddy/Caddyfile" ] && grep -q "$DOMAIN" /etc/caddy/Caddyfile; then
        print_info "Caddy is already configured for VS Code Server with domain $DOMAIN."
        return 0
    fi
    
    print_info "Configuring Caddy as reverse proxy for VS Code Server..."
    
    # Create Caddyfile with user input
    cat <<EOF | sudo tee /etc/caddy/Caddyfile > /dev/null
$DOMAIN {
    basic_auth {
        $USERNAME $PASSWORD_HASH
    }
    
    reverse_proxy localhost:$VSCODE_PORT
}
EOF
    
    print_success "Caddy has been configured as reverse proxy for VS Code Server."
}

# Verify installation
verify_installation() {
    print_info "Verifying installation..."
    
    # Check if services are running
    if ! systemctl is-active --quiet code-server; then
        print_error "VS Code Server service is not running."
        return 1
    fi
    
    if ! systemctl is-active --quiet caddy; then
        print_error "Caddy service is not running."
        return 1
    fi
    
    # Check if Caddyfile is valid
    if ! caddy validate --config /etc/caddy/Caddyfile; then
        print_error "Caddyfile configuration is invalid."
        return 1
    fi
    
    # Check if port is accessible
    if ! nc -z localhost "$VSCODE_PORT" 2>/dev/null; then
        print_error "VS Code Server is not accessible on port $VSCODE_PORT."
        return 1
    fi
    
    print_success "Installation verified successfully."
}

# Start services
start_services() {
    print_info "Starting services..."
    
    # Start and enable VS Code Server
    sudo systemctl start code-server
    print_success "VS Code Server started."
    
    # Start and enable Caddy
    sudo systemctl start caddy
    print_success "Caddy started."
}

# Uninstall VS Code Server and Caddy
uninstall() {
    print_info "Uninstalling VS Code Server and Caddy..."
    
    # Stop and disable services
    sudo systemctl stop code-server caddy 2>/dev/null || true
    sudo systemctl disable code-server caddy 2>/dev/null || true
    
    # Remove service files
    sudo rm -f /etc/systemd/system/code-server.service /etc/systemd/system/caddy.service
    sudo systemctl daemon-reload
    
    # Remove packages
    sudo apt remove --purge -y caddy code 2>/dev/null || true
    sudo apt autoremove -y 2>/dev/null || true
    
    # Remove directories
    sudo rm -rf /etc/caddy
    rm -rf ~/.vscode-server
    
    # Remove repository files
    sudo rm -f /etc/apt/sources.list.d/vscode.list
    sudo rm -f /etc/apt/sources.list.d/caddy-stable.list
    sudo rm -f /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    
    print_success "Uninstallation completed."
}

# Main installation process
install() {
    print_info "Starting VS Code Server setup..."
    
    check_ubuntu
    update_system
    get_user_input
    hash_password
    check_domain_resolution
    install_vscode_server
    install_caddy
    create_projects_dir
    configure_caddy
    start_services
    verify_installation
    
    print_success "VS Code Server setup completed successfully!"
    print_info "You can now access VS Code Server at https://$DOMAIN"
    print_info "Your projects are available in the /projects directory"
}

# Main execution
main() {
    # Check if uninstall is requested
    if [ "$1" = "uninstall" ]; then
        uninstall
        exit 0
    fi
    
    # Run installation
    install
}

# Run main function
main "$@"
