#!/bin/bash

# Zsh Setup Script
# This script installs Zsh, Oh My Zsh, and popular plugins with checks at each step

set -e
set -o pipefail

OS_TYPE=""
PKG_MANAGER=""

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

detect_env() {
    case "$(uname -s)" in
        Linux) OS_TYPE="linux" ;;
        Darwin) OS_TYPE="macos" ;;
        *)
            print_error "Unsupported OS. This script supports Linux and macOS only."
            exit 1
            ;;
    esac

    if [ "$OS_TYPE" = "macos" ]; then
        if command_exists brew; then
            PKG_MANAGER="brew"
        else
            print_error "Homebrew is required on macOS. Install it first: https://brew.sh"
            exit 1
        fi
        return 0
    fi

    if command_exists apt-get; then
        PKG_MANAGER="apt"
    elif command_exists dnf; then
        PKG_MANAGER="dnf"
    elif command_exists yum; then
        PKG_MANAGER="yum"
    elif command_exists pacman; then
        PKG_MANAGER="pacman"
    elif command_exists brew; then
        PKG_MANAGER="brew"
    else
        print_error "Unsupported Linux package manager. Supported: apt, dnf, yum, pacman, brew"
        exit 1
    fi
}

sed_in_place() {
    local expr="$1"
    local target="$2"

    if [ "$OS_TYPE" = "macos" ]; then
        sed -i '' "$expr" "$target"
    else
        sed -i "$expr" "$target"
    fi
}

# Check if Zsh is installed
install_zsh() {
    if command_exists zsh; then
        print_success "Zsh is already installed. Skipping installation."
        return 0
    fi
    
    print_info "Installing Zsh..."
    
    case "$PKG_MANAGER" in
        brew)
            brew install zsh
            ;;
        apt)
            sudo apt-get update
            sudo apt-get install -y zsh
            ;;
        yum)
            sudo yum install -y zsh
            ;;
        dnf)
            sudo dnf install -y zsh
            ;;
        pacman)
            sudo pacman -Sy --noconfirm zsh
            ;;
        *)
            print_error "Unsupported package manager. Please install Zsh manually."
            exit 1
            ;;
    esac
    
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
    touch "$HOME/.zshrc"
    if grep -q "zsh-autosuggestions" "$HOME/.zshrc" && grep -q "zsh-syntax-highlighting" "$HOME/.zshrc"; then
        print_info "Plugins are already configured in ~/.zshrc"
    else
        print_info "Configuring plugins in ~/.zshrc..."

        if grep -q '^plugins=' "$HOME/.zshrc"; then
            sed_in_place 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' "$HOME/.zshrc"
        else
            echo 'plugins=(git zsh-autosuggestions zsh-syntax-highlighting)' >> "$HOME/.zshrc"
        fi

        print_success "Plugins have been configured in ~/.zshrc"
    fi
}

configure_aliases() {
    local zshrc="$HOME/.zshrc"
    local start_marker="# >>> codex managed aliases >>>"
    local end_marker="# <<< codex managed aliases <<<"
    local tmp_file cleaned_file

    print_info "Configuring aliases in ~/.zshrc..."
    touch "$zshrc"
    tmp_file="$(mktemp)"
    cleaned_file="$(mktemp)"

    awk -v start="$start_marker" -v end="$end_marker" '
        $0 == start { in_block = 1; next }
        $0 == end { in_block = 0; next }
        !in_block { print }
    ' "$zshrc" > "$tmp_file"

    # Remove legacy alias blocks/lines so aliases are not duplicated when rerun.
    awk '
        BEGIN { skip = 0 }

        # Drop previous unmanaged modern-cli blocks.
        /^# Prefer modern CLI tools when available\.$/ { next }
        /^if command -v bat >\/dev\/null 2>&1; then$/ { skip = 1; next }
        /^if command -v rg >\/dev\/null 2>&1; then$/ { skip = 1; next }
        /^if command -v fd >\/dev\/null 2>&1; then$/ { skip = 1; next }
        /^if command -v zoxide >\/dev\/null 2>&1; then$/ { skip = 1; next }
        skip == 1 {
            if ($0 == "fi") skip = 0
            next
        }

        # Drop duplicate alias lines that this script manages.
        /^alias cat='\''bat --paging=never'\''$/ { next }
        /^alias cat='\''batcat --paging=never'\''$/ { next }
        /^alias grep='\''rg'\''$/ { next }
        /^alias find='\''fd'\''$/ { next }
        /^alias find='\''fdfind'\''$/ { next }
        /^alias cd='\''z'\''$/ { next }
        /^alias reload='\''source ~\/\.zshrc'\''$/ { next }
        /^alias dev='\''tmux attach -t dev'\''$/ { next }
        /^  alias cd='\''z'\''$/ { next }
        /^  eval "\$\(zoxide init zsh\)"$/ { next }

        { print }
    ' "$tmp_file" > "$cleaned_file"

    cat >> "$cleaned_file" <<'EOF'
# >>> codex managed aliases >>>
# Prefer modern CLI tools when available.
if command -v bat >/dev/null 2>&1; then
  alias cat='bat --paging=never'
elif command -v batcat >/dev/null 2>&1; then
  alias cat='batcat --paging=never'
fi

if command -v rg >/dev/null 2>&1; then
  alias grep='rg'
fi

if command -v fd >/dev/null 2>&1; then
  alias find='fd'
elif command -v fdfind >/dev/null 2>&1; then
  alias find='fdfind'
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
  alias cd='z'
fi

alias reload='source ~/.zshrc'
alias dev='tmux attach -t dev'
# <<< codex managed aliases <<<
EOF

    mv "$cleaned_file" "$zshrc"
    rm -f "$tmp_file"
    print_success "Aliases configured in ~/.zshrc"
}

# Main execution
main() {
    print_info "Starting Zsh setup..."
    detect_env
    print_info "Detected environment: $OS_TYPE ($PKG_MANAGER)"

    command_exists curl || { print_error "curl is required but not installed."; exit 1; }
    command_exists git || { print_error "git is required but not installed."; exit 1; }

    install_zsh
    install_ohmyzsh
    install_plugins
    configure_aliases
    
    print_success "Zsh setup completed successfully!"
    print_info "Please run 'zsh' to start using your new shell, or restart your terminal."
}

# Run main function
main
