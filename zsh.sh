#!/bin/bash

# Zsh Setup Script
# This script installs Zsh, Oh My Zsh, and popular plugins with checks at each step

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

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if Zsh is installed
install_zsh() {
    if command_exists zsh; then
        print_success "Zsh is already installed. Skipping installation."
        return 0
    fi
    
    print_info "Installing Zsh..."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command_exists brew; then
            brew install zsh
        else
            print_error "Homebrew is not installed. Please install Homebrew first."
            exit 1
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        if command_exists apt-get; then
            sudo apt-get update && sudo apt-get install -y zsh
        elif command_exists yum; then
            sudo yum install -y zsh
        elif command_exists dnf; then
            sudo dnf install -y zsh
        else
            print_error "Unsupported package manager. Please install Zsh manually."
            exit 1
        fi
    else
        print_error "Unsupported operating system."
        exit 1
    fi
    
    print_success "Zsh has been installed successfully."
}

# Check if Oh My Zsh is installed
install_ohmyzsh() {
    if [ -d "$HOME/.oh-my-zsh" ]; then
        print_success "Oh My Zsh is already installed. Skipping installation."
        return 0
    fi
    
    print_info "Installing Oh My Zsh..."
    
    # Run the Oh My Zsh installation script
    RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    
    print_success "Oh My Zsh has been installed successfully."
}

# Install Zsh plugins
install_plugins() {
    local plugins_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
    
    # Check if plugins directory exists
    if [ ! -d "$plugins_dir" ]; then
        mkdir -p "$plugins_dir"
    fi
    
    # Install zsh-autosuggestions
    if [ -d "$plugins_dir/zsh-autosuggestions" ]; then
        print_success "zsh-autosuggestions is already installed."
    else
        print_info "Installing zsh-autosuggestions..."
        git clone https://github.com/zsh-users/zsh-autosuggestions.git "$plugins_dir/zsh-autosuggestions"
        print_success "zsh-autosuggestions has been installed."
    fi
    
    # Install zsh-syntax-highlighting
    if [ -d "$plugins_dir/zsh-syntax-highlighting" ]; then
        print_success "zsh-syntax-highlighting is already installed."
    else
        print_info "Installing zsh-syntax-highlighting..."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$plugins_dir/zsh-syntax-highlighting"
        print_success "zsh-syntax-highlighting has been installed."
    fi
    
    # Check if plugins are already configured in .zshrc
    if grep -q "zsh-autosuggestions" ~/.zshrc && grep -q "zsh-syntax-highlighting" ~/.zshrc; then
        print_info "Plugins are already configured in ~/.zshrc"
    else
        print_info "Configuring plugins in ~/.zshrc..."
        
        # Enable plugins in .zshrc
        sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/g' ~/.zshrc
        
        print_success "Plugins have been configured in ~/.zshrc"
    fi
}

# Main execution
main() {
    print_info "Starting Zsh setup..."
    
    install_zsh
    install_ohmyzsh
    install_plugins
    
    print_success "Zsh setup completed successfully!"
    print_info "Please run 'zsh' to start using your new shell, or restart your terminal."
}

# Run main function
main
