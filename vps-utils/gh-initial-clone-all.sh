#!/usr/bin/env bash

# GitHub Repository Clone-All Script
# Installs GitHub CLI (if needed), authenticates, and clones/pulls all your repositories

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Linux*)
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                OS_TYPE="linux"
                OS_NAME="$NAME"
            else
                OS_TYPE="linux"
                OS_NAME="Linux"
            fi
            ;;
        Darwin*)
            OS_TYPE="macos"
            OS_NAME="macOS"
            ;;
        *)
            print_error "Unsupported operating system: $(uname -s)"
            exit 1
            ;;
    esac

    print_info "Detected OS: $OS_NAME"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install GitHub CLI
install_gh() {
    if command_exists gh; then
        print_success "GitHub CLI is already installed. Skipping installation."
        return 0
    fi

    print_info "Installing GitHub CLI..."

    if [ "$OS_TYPE" = "linux" ]; then
        # Linux installation
        if command_exists apt; then
            # Debian/Ubuntu
            sudo apt install -y curl
            curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
            sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
            sudo apt update
            sudo apt install -y gh
        elif command_exists yum; then
            # Red Hat/CentOS/Fedora
            sudo yum install -y 'dnf-command(config-manager)'
            sudo yum-config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
            sudo yum install -y gh
        elif command_exists dnf; then
            # Fedora
            sudo dnf install -y 'dnf-command(config-manager)'
            sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
            sudo dnf install -y gh
        else
            print_error "Unsupported Linux package manager. Please install GitHub CLI manually:"
            print_info "https://github.com/cli/cli#installation"
            exit 1
        fi
    elif [ "$OS_TYPE" = "macos" ]; then
        # macOS installation
        if command_exists brew; then
            brew install gh
        else
            print_error "Homebrew is not installed. Please install Homebrew first:"
            print_info "https://brew.sh"
            exit 1
        fi
    fi

    print_success "GitHub CLI installed successfully."
}

# Authenticate with GitHub
authenticate_gh() {
    if gh auth status >/dev/null 2>&1; then
        print_success "Already authenticated with GitHub."
        return 0
    fi

    print_info "Authenticating with GitHub..."
    print_info "You will be redirected to a browser to authenticate."
    echo ""

    gh auth login

    if gh auth status >/dev/null 2>&1; then
        print_success "Authentication with GitHub successful."
    else
        print_error "Authentication with GitHub failed."
        exit 1
    fi
}

# Get target directory
get_target_directory() {
    echo ""
    print_info "Where would you like to clone your repositories?"

    # Suggest default based on OS
    if [ "$OS_TYPE" = "macos" ]; then
        DEFAULT_DIR="$HOME/Projects"
    else
        DEFAULT_DIR="$HOME/projects"
    fi

    read -p "Enter directory path (default: $DEFAULT_DIR): " TARGET_DIR

    if [ -z "$TARGET_DIR" ]; then
        TARGET_DIR="$DEFAULT_DIR"
    fi

    # Expand tilde
    TARGET_DIR="${TARGET_DIR/#\~/$HOME}"

    # Create directory if it doesn't exist
    if [ ! -d "$TARGET_DIR" ]; then
        print_info "Directory does not exist. Creating: $TARGET_DIR"
        mkdir -p "$TARGET_DIR"
    fi

    print_success "Target directory: $TARGET_DIR"
}

# Get all repositories
get_repos() {
    print_info "Fetching your repositories from GitHub..."

    # Get all repositories (including private)
    REPOS=$(gh repo list --limit 1000 --json nameWithOwner --jq '.[].nameWithOwner')

    if [ -z "$REPOS" ]; then
        print_error "No repositories found or authentication failed."
        exit 1
    fi

    REPO_COUNT=$(echo "$REPOS" | wc -l | tr -d ' ')
    print_success "Found $REPO_COUNT repositories."
}

# Clone or pull repositories
clone_or_pull_repos() {
    local cloned=0
    local updated=0
    local skipped=0
    local failed=0

    echo ""
    print_info "Processing repositories..."
    echo ""

    while IFS= read -r REPO; do
        REPO_NAME=$(basename "$REPO")
        REPO_PATH="$TARGET_DIR/$REPO_NAME"

        if [ -d "$REPO_PATH" ]; then
            print_info "Repository '$REPO_NAME' already exists. Pulling latest changes..."

            cd "$REPO_PATH"

            # Check for uncommitted changes
            if ! git diff-index --quiet HEAD -- 2>/dev/null; then
                print_warning "Repository '$REPO_NAME' has uncommitted changes. Skipping pull..."
                skipped=$((skipped + 1))
                continue
            fi

            if git pull --ff-only 2>/dev/null; then
                print_success "Repository '$REPO_NAME' updated."
                updated=$((updated + 1))
            else
                print_error "Failed to update repository '$REPO_NAME'."
                failed=$((failed + 1))
            fi
        else
            print_info "Cloning repository '$REPO_NAME'..."

            if gh repo clone "$REPO" "$REPO_PATH" 2>/dev/null; then
                print_success "Repository '$REPO_NAME' cloned."
                cloned=$((cloned + 1))
            else
                print_error "Failed to clone repository '$REPO_NAME'."
                failed=$((failed + 1))
            fi
        fi

        echo ""
    done <<< "$REPOS"

    # Print summary
    echo "════════════════════════════════════════════════════════════════"
    echo "                           SUMMARY"
    echo "════════════════════════════════════════════════════════════════"
    echo -e "Total repositories:          ${BLUE}$REPO_COUNT${NC}"
    echo -e "Newly cloned:                ${GREEN}$cloned${NC}"
    echo -e "Updated:                     ${GREEN}$updated${NC}"

    if [ $skipped -gt 0 ]; then
        echo -e "Skipped (uncommitted):       ${YELLOW}$skipped${NC}"
    fi

    if [ $failed -gt 0 ]; then
        echo -e "Failed:                      ${RED}$failed${NC}"
    fi

    echo "════════════════════════════════════════════════════════════════"
}

# Main execution
main() {
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║          GitHub Repository Clone-All Tool                      ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""

    detect_os
    install_gh
    authenticate_gh
    get_target_directory
    get_repos
    clone_or_pull_repos

    echo ""
    print_success "All repositories have been set up in $TARGET_DIR"
}

# Run main function
main
