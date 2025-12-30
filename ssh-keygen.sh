#!/bin/bash

# SSH Key Management Script
# Creates an SSH key and copies it to a remote server

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

# Get user input for SSH key name
get_ssh_key_name() {
    while true; do
        read -p "Enter a name for your SSH key (e.g., work-server, github): " KEY_NAME
        if [ -n "$KEY_NAME" ]; then
            break
        fi
        print_error "SSH key name cannot be empty. Please try again."
    done
}

# Get server details for SSH key deployment
get_server_details() {
    while true; do
        read -p "Enter server IP address: " SERVER_IP
        if [ -n "$SERVER_IP" ]; then
            break
        fi
        print_error "Server IP cannot be empty. Please try again."
    done
    
    while true; do
        read -p "Enter server username: " SERVER_USER
        if [ -n "$SERVER_USER" ]; then
            break
        fi
        print_error "Server username cannot be empty. Please try again."
    done
}

# Create SSH key
create_ssh_key() {
    KEY_PATH="$HOME/.ssh/${KEY_NAME}"
    
    if [ -f "$KEY_PATH" ]; then
        print_info "SSH key already exists at $KEY_PATH"
        read -p "Do you want to overwrite it? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Using existing SSH key."
            return 0
        fi
    fi
    
    print_info "Creating SSH key: $KEY_PATH"
    
    # Create SSH directory if it doesn't exist
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    
    # Generate SSH key without passphrase
    ssh-keygen -t ed25519 -f "$KEY_PATH" -N "" -C "$KEY_NAME"
    
    # Set proper permissions
    chmod 600 "$KEY_PATH"
    chmod 644 "${KEY_PATH}.pub"
    
    print_success "SSH key created successfully."
}

# Copy SSH key to server
copy_ssh_key() {
    print_info "Copying SSH key to server..."
    
    # Check if ssh-copy-id is available
    if command -v ssh-copy-id >/dev/null; then
        ssh-copy-id -i "${KEY_PATH}.pub" "${SERVER_USER}@${SERVER_IP}"
    else
        print_info "ssh-copy-id not found. Using manual method."
        
        # Display the public key for manual copy
        print_info "Public key to add to server:"
        cat "${KEY_PATH}.pub"
        
        print_info "Run the following on the server:"
        echo "mkdir -p ~/.ssh"
        echo "chmod 700 ~/.ssh"
        echo "echo '$(cat "${KEY_PATH}.pub")' >> ~/.ssh/authorized_keys"
        echo "chmod 600 ~/.ssh/authorized_keys"
    fi
    
    print_success "SSH key deployed to server."
}

# Test SSH connection
test_ssh_connection() {
    print_info "Testing SSH connection to server..."
    
    if ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no "${SERVER_USER}@${SERVER_IP}" "echo 'Connection successful'"; then
        print_success "SSH connection test passed."
    else
        print_error "SSH connection test failed."
        exit 1
    fi
}

# Create SSH config entry
create_ssh_config() {
    print_info "Adding entry to SSH config..."
    
    SSH_CONFIG="$HOME/.ssh/config"
    
    # Create config file if it doesn't exist
    if [ ! -f "$SSH_CONFIG" ]; then
        touch "$SSH_CONFIG"
        chmod 600 "$SSH_CONFIG"
    fi
    
    # Check if entry already exists
    if grep -q "Host $KEY_NAME" "$SSH_CONFIG"; then
        print_info "SSH config entry already exists for $KEY_NAME."
        return 0
    fi
    
    # Add config entry
    cat >> "$SSH_CONFIG" <<EOF

Host $KEY_NAME
    HostName $SERVER_IP
    User $SERVER_USER
    Port 22
    IdentityFile $KEY_PATH
    IdentitiesOnly yes
EOF
    
    print_success "SSH config entry added. You can now connect with: ssh $KEY_NAME"
}

# Main execution
main() {
    print_info "Starting SSH key setup..."
    
    get_ssh_key_name
    create_ssh_key
    get_server_details
    copy_ssh_key
    test_ssh_connection
    create_ssh_config
    
    print_success "SSH key setup completed successfully!"
    print_info "You can now connect to your server with: ssh $KEY_NAME"
}

# Run main function
main
