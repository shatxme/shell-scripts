#!/bin/bash

# Server Security Configuration Script
# Configures SSH and UFW for enhanced security

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

# Check if running on Ubuntu
check_ubuntu() {
    if ! grep -q "Ubuntu" /etc/os-release; then
        print_error "This script is designed for Ubuntu only."
        exit 1
    fi
}

# Check if running as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        print_error "This script must be run as root. Use 'sudo $0'."
        exit 1
    fi
}

# Update system
update_system() {
    print_info "Updating system packages..."
    apt update && apt upgrade -y
    print_success "System updated successfully."
}

# Configure SSH
configure_ssh() {
    SSH_CONFIG="/etc/ssh/sshd_config"
    SSH_PORT="2233"
    
    print_info "Configuring SSH..."
    
    # Backup original SSH config
    cp "$SSH_CONFIG" "${SSH_CONFIG}.backup.$(date +%Y%m%d%H%M%S)"
    
    # Change SSH port
    sed -i "s/#Port 22/Port $SSH_PORT/" "$SSH_CONFIG"
    sed -i "s/Port 22/Port $SSH_PORT/" "$SSH_CONFIG"
    
    # Configure authentication
    sed -i "s/#PermitRootLogin yes/PermitRootLogin no/" "$SSH_CONFIG"
    sed -i "s/PermitRootLogin yes/PermitRootLogin no/" "$SSH_CONFIG"
    sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin no/" "$SSH_CONFIG"
    sed -i "s/PermitRootLogin prohibit-password/PermitRootLogin no/" "$SSH_CONFIG"
    
    sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/" "$SSH_CONFIG"
    sed -i "s/PasswordAuthentication yes/PasswordAuthentication no/" "$SSH_CONFIG"
    
    sed -i "s/#PubkeyAuthentication yes/PubkeyAuthentication yes/" "$SSH_CONFIG"
    sed -i "s/PubkeyAuthentication no/PubkeyAuthentication yes/" "$SSH_CONFIG"
    
    print_success "SSH configured to use port $SSH_PORT with key-based authentication only."
}

# Configure UFW
configure_ufw() {
    print_info "Configuring UFW firewall..."
    
    # Reset UFW rules
    ufw --force reset
    
    # Set default policies
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow SSH on new port
    ufw allow 2233/tcp
    
    # Allow HTTP and HTTPS
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    # Enable UFW
    print_warning "Enabling UFW firewall. This may disconnect your current SSH session."
    print_warning "Make sure you have SSH key access configured before proceeding."
    
    read -p "Do you want to continue? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "UFW configuration skipped."
        return 0
    fi
    
    ufw --force enable
    
    print_success "UFW firewall configured and enabled."
}

# Restart SSH service
restart_ssh() {
    print_info "Restarting SSH service..."
    systemctl restart sshd
    
    print_success "SSH service restarted."
    print_warning "SSH is now running on port 2233. Make sure to update your SSH client configuration."
}

# Main execution
main() {
    print_info "Starting server security configuration..."
    
    check_root
    check_ubuntu
    update_system
    configure_ssh
    configure_ufw
    restart_ssh
    
    print_success "Server security configuration completed!"
    print_info "SSH is now running on port 2233 with key-based authentication only."
    print_info "Firewall rules allow connections on ports 2233, 80, and 443."
    print_warning "Remember to update your SSH client to use port 2233."
}

# Run main function
main
