#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Neovim + tmux Setup/Uninstall Script
#
# Usage:
#   ./nvim-tmux.sh          - Install Neovim and tmux
#   ./nvim-tmux.sh uninstall - Uninstall Neovim and tmux
###############################################################################

###############################################################################
# Config
###############################################################################

# These will be set based on detected OS
NVIM_TARBALL_URL=""
NVIM_EXTRACT_DIR=""
OS_TYPE=""
ARCH_TYPE=""
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

###############################################################################
# Helpers
###############################################################################

log() {
  printf "\033[1;32m>>> %s\033[0m\n" "$*"
}

warn() {
  printf "\033[1;33m[!] %s\033[0m\n" "$*"
}

err() {
  printf "\033[1;31m[✗] %s\033[0m\n" "$*"
  exit 1
}

###############################################################################
# Detect OS and Architecture
###############################################################################

detect_system() {
  # Detect OS
  OS="$(uname -s)"
  case "$OS" in
    Linux*)
      OS_TYPE="linux"
      ;;
    Darwin*)
      OS_TYPE="macos"
      ;;
    *)
      err "Unsupported OS: $OS. This script supports Linux and macOS only."
      ;;
  esac

  log "Detected OS: $OS_TYPE"

  # Detect Architecture
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64|amd64)
      ARCH_TYPE="x86_64"
      ;;
    arm64|aarch64)
      ARCH_TYPE="arm64"
      ;;
    *)
      err "Unsupported architecture: $ARCH"
      ;;
  esac

  log "Detected architecture: $ARCH_TYPE"

  # Set Neovim download URL based on OS and architecture
  if [[ "$OS_TYPE" == "linux" ]]; then
    if ! command -v apt >/dev/null 2>&1; then
      err "apt not found. This script supports Debian/Ubuntu on Linux."
    fi
    NVIM_TARBALL_URL="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"
    NVIM_EXTRACT_DIR="nvim-linux-x86_64"
  elif [[ "$OS_TYPE" == "macos" ]]; then
    if ! command -v brew >/dev/null 2>&1; then
      err "Homebrew not found. Please install Homebrew first: https://brew.sh"
    fi
    NVIM_TARBALL_URL="https://github.com/neovim/neovim/releases/latest/download/nvim-macos-${ARCH_TYPE}.tar.gz"
    NVIM_EXTRACT_DIR="nvim-macos-${ARCH_TYPE}"
  fi
}

###############################################################################
# Install base packages
###############################################################################

install_packages() {

  if [[ "$OS_TYPE" == "linux" ]]; then
    log "Updating package index and installing base packages (Linux)..."

    sudo apt update -y

    PACKAGES=(git tmux curl ripgrep fd-find fzf build-essential unzip python3 python3-venv ca-certificates)
    TO_INSTALL=()

    for pkg in "${PACKAGES[@]}"; do
      if ! dpkg -l | grep -q "^ii  $pkg "; then
        TO_INSTALL+=("$pkg")
      else
        log "Package $pkg is already installed, skipping..."
      fi
    done

    if [[ ${#TO_INSTALL[@]} -gt 0 ]]; then
      log "Installing packages: ${TO_INSTALL[*]}"
      sudo apt install -y "${TO_INSTALL[@]}"
    else
      log "All required packages are already installed."
    fi

    # On Debian/Ubuntu, fd is called fdfind; create 'fd' alias if needed
    if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
      log "Creating /usr/local/bin/fd -> fdfind symlink..."
      sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd
    fi

  elif [[ "$OS_TYPE" == "macos" ]]; then
    log "Installing base packages (macOS via Homebrew)..."

    PACKAGES=(git tmux curl ripgrep fd fzf python3)
    TO_INSTALL=()

    for pkg in "${PACKAGES[@]}"; do
      if ! brew list --formula | grep -q "^${pkg}$"; then
        TO_INSTALL+=("$pkg")
      else
        log "Package $pkg is already installed, skipping..."
      fi
    done

    if [[ ${#TO_INSTALL[@]} -gt 0 ]]; then
      log "Installing packages: ${TO_INSTALL[*]}"
      brew install "${TO_INSTALL[@]}"
    else
      log "All required packages are already installed."
    fi
  fi
}

###############################################################################
# Install Neovim (latest) from official tarball
###############################################################################

install_neovim() {
  log "Installing latest Neovim from tarball..."

  TMPDIR="$(mktemp -d)"
  pushd "$TMPDIR" >/dev/null

  TARBALL_NAME="nvim-${OS_TYPE}-${ARCH_TYPE}.tar.gz"

  log "Downloading Neovim tarball..."
  curl -fL -o "$TARBALL_NAME" "$NVIM_TARBALL_URL"

  NVIM_INSTALL_DIR="/opt/${NVIM_EXTRACT_DIR}"

  log "Removing any previous $NVIM_INSTALL_DIR..."
  sudo rm -rf "$NVIM_INSTALL_DIR"

  log "Extracting Neovim into /opt..."
  sudo tar -C /opt -xzf "$TARBALL_NAME"

  # Verify the binary exists
  if [[ ! -x "${NVIM_INSTALL_DIR}/bin/nvim" ]]; then
    err "Neovim binary not found at ${NVIM_INSTALL_DIR}/bin/nvim after extraction."
  fi

  log "Linking /usr/local/bin/nvim -> ${NVIM_INSTALL_DIR}/bin/nvim ..."
  sudo ln -sf "${NVIM_INSTALL_DIR}/bin/nvim" /usr/local/bin/nvim

  popd >/dev/null
  rm -rf "$TMPDIR"

  log "Neovim version installed:"
  nvim --version | head -n 3
}

###############################################################################
# Install LazyVim starter config
###############################################################################

backup_if_exists() {
  local path="$1"
  if [[ -e "$path" ]]; then
    local backup="${path}.bak-${TIMESTAMP}"
    log "Backing up $path -> $backup"
    mv "$path" "$backup"
  fi
}

install_lazyvim() {
  NVIM_CONFIG="$HOME/.config/nvim"
  NVIM_LOCAL_SHARE="$HOME/.local/share/nvim"
  NVIM_LOCAL_STATE="$HOME/.local/state/nvim"
  NVIM_CACHE="$HOME/.cache/nvim"

  log "Backing up any existing Neovim config/state..."
  backup_if_exists "$NVIM_CONFIG"
  backup_if_exists "$NVIM_LOCAL_SHARE"
  backup_if_exists "$NVIM_LOCAL_STATE"
  backup_if_exists "$NVIM_CACHE"

  log "Cloning LazyVim starter into $NVIM_CONFIG..."
  git clone https://github.com/LazyVim/starter "$NVIM_CONFIG"

  log "Removing LazyVim starter .git directory so you own the config..."
  rm -rf "$NVIM_CONFIG/.git"
}

###############################################################################
# Add minimal LazyVim options override
###############################################################################

configure_lazyvim() {
  NVIM_CONFIG="$HOME/.config/nvim"

  log "Writing LazyVim custom options..."

  mkdir -p "$NVIM_CONFIG/lua/config"

  cat > "$NVIM_CONFIG/lua/config/options.lua" << 'EOF'
-- Custom options for LazyVim

local opt = vim.opt

-- Line numbers
opt.number = true
opt.relativenumber = true

-- Use system clipboard
opt.clipboard = "unnamedplus"

-- Better search
opt.ignorecase = true
opt.smartcase = true

-- More intuitive splits
opt.splitbelow = true
opt.splitright = true
EOF
}

###############################################################################
# Install tmux config with vim-style navigation
###############################################################################

install_tmux_config() {
  TMUX_CONF="$HOME/.tmux.conf"

  if [[ -f "$TMUX_CONF" ]]; then
    backup="${TMUX_CONF}.bak-${TIMESTAMP}"
    log "Backing up existing tmux config: $TMUX_CONF -> $backup"
    mv "$TMUX_CONF" "$backup"
  fi

  log "Writing new tmux config to $TMUX_CONF..."

  cat > "$TMUX_CONF" << 'EOF'
##### Base Config #####

set -g mouse on
set -g history-limit 10000
setw -g mode-keys vi

##### Splits #####
# Default tmux:
#   prefix + "   -> horizontal split
#   prefix + %   -> vertical split
#
# Extra ergonomics:
bind - split-window -v   # prefix + -  -> horizontal
bind | split-window -h   # prefix + |  -> vertical

##### Vim-style pane navigation (no prefix) #####

bind -n C-h select-pane -L
bind -n C-j select-pane -D
bind -n C-k select-pane -U
bind -n C-l select-pane -R

##### Resize panes quickly with Alt + h/j/k/l #####

bind -n M-h resize-pane -L 5
bind -n M-j resize-pane -D 5
bind -n M-k resize-pane -U 5
bind -n M-l resize-pane -R 5

##### Status bar #####

set -g status-bg black
set -g status-fg white
set -g status-left-length 20
set -g status-right-length 100
set -g status-left "#[bold]#S"
set -g status-right "%Y-%m-%d %H:%M "
EOF

  log "tmux config installed."
}

###############################################################################
# Uninstall function
###############################################################################

remove_if_exists() {
  local path="$1"
  if [[ -e "$path" ]]; then
    log "Removing $path..."
    rm -rf "$path"
  else
    log "$path not found, skipping..."
  fi
}

uninstall() {
  log "Starting uninstall process..."
  echo ""

  warn "This script will remove:"
  echo "  - Neovim installation from /opt"
  echo "  - Neovim symlink from /usr/local/bin/nvim"
  echo "  - Neovim config: ~/.config/nvim"
  echo "  - Neovim data: ~/.local/share/nvim"
  echo "  - Neovim state: ~/.local/state/nvim"
  echo "  - Neovim cache: ~/.cache/nvim"
  echo "  - tmux config: ~/.tmux.conf"
  echo "  - tmux plugins: ~/.tmux (if exists)"
  echo ""
  warn "Backup files (*.bak-*) will NOT be removed."
  echo ""

  read -p "Are you sure you want to continue? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "Uninstall cancelled."
    exit 0
  fi

  ###############################################################################
  # Remove Neovim
  ###############################################################################

  log "Removing Neovim installation..."

  # Remove the /usr/local/bin/nvim symlink
  if [[ -L /usr/local/bin/nvim ]]; then
    log "Removing /usr/local/bin/nvim symlink..."
    sudo rm -f /usr/local/bin/nvim
  else
    log "/usr/local/bin/nvim not found, skipping..."
  fi

  # Try to remove both possible installation directories
  if [[ "$OS_TYPE" == "linux" ]]; then
    if [[ -d /opt/nvim-linux-x86_64 ]]; then
      log "Removing /opt/nvim-linux-x86_64..."
      sudo rm -rf /opt/nvim-linux-x86_64
    else
      log "/opt/nvim-linux-x86_64 not found, skipping..."
    fi
  elif [[ "$OS_TYPE" == "macos" ]]; then
    # Check both x86_64 and arm64
    for arch in x86_64 arm64; do
      if [[ -d "/opt/nvim-macos-${arch}" ]]; then
        log "Removing /opt/nvim-macos-${arch}..."
        sudo rm -rf "/opt/nvim-macos-${arch}"
      fi
    done

    if ! find /opt -maxdepth 1 -name "nvim-macos-*" -type d 2>/dev/null | grep -q .; then
      log "No Neovim installations found in /opt, skipping..."
    fi
  fi

  ###############################################################################
  # Remove Neovim config and data
  ###############################################################################

  log "Removing Neovim config and data directories..."

  NVIM_CONFIG="$HOME/.config/nvim"
  NVIM_LOCAL_SHARE="$HOME/.local/share/nvim"
  NVIM_LOCAL_STATE="$HOME/.local/state/nvim"
  NVIM_CACHE="$HOME/.cache/nvim"

  remove_if_exists "$NVIM_CONFIG"
  remove_if_exists "$NVIM_LOCAL_SHARE"
  remove_if_exists "$NVIM_LOCAL_STATE"
  remove_if_exists "$NVIM_CACHE"

  ###############################################################################
  # Remove tmux config
  ###############################################################################

  log "Removing tmux configuration..."

  TMUX_CONF="$HOME/.tmux.conf"
  TMUX_PLUGINS="$HOME/.tmux"

  remove_if_exists "$TMUX_CONF"
  remove_if_exists "$TMUX_PLUGINS"

  ###############################################################################
  # Optional: Uninstall packages
  ###############################################################################

  echo ""
  warn "Package uninstallation:"
  echo "The following packages were installed by the setup script:"
  echo "  Linux: git, tmux, curl, ripgrep, fd-find, fzf, build-essential, unzip, python3, python3-venv, ca-certificates"
  echo "  macOS: git, tmux, curl, ripgrep, fd, fzf, python3"
  echo ""
  echo "These packages are commonly used by other tools and were not removed automatically."
  echo ""

  read -p "Would you like to uninstall these packages as well? [y/N] " -n 1 -r
  echo

  if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [[ "$OS_TYPE" == "linux" ]]; then
      log "Uninstalling packages via apt..."

      # Remove fd symlink if it exists
      if [[ -L /usr/local/bin/fd ]] && [[ "$(readlink /usr/local/bin/fd)" == *"fdfind"* ]]; then
        log "Removing /usr/local/bin/fd symlink..."
        sudo rm -f /usr/local/bin/fd
      fi

      sudo apt remove -y \
        tmux \
        ripgrep \
        fd-find \
        fzf \
        unzip \
        python3-venv || warn "Some packages could not be removed"

      log "Running apt autoremove..."
      sudo apt autoremove -y

    elif [[ "$OS_TYPE" == "macos" ]]; then
      log "Uninstalling packages via Homebrew..."

      if command -v brew >/dev/null 2>&1; then
        brew uninstall tmux ripgrep fd fzf 2>/dev/null || warn "Some packages could not be removed"
      else
        warn "Homebrew not found, skipping package uninstallation"
      fi
    fi

    log "Packages uninstalled."
  else
    log "Skipping package uninstallation."
  fi

  ###############################################################################
  # Done
  ###############################################################################

  log "Uninstall complete!"

  cat << 'EOF'

Neovim and tmux have been removed from your system.

Backup files (*.bak-*) were preserved and can be found in:
  - ~/.config/nvim.bak-*
  - ~/.local/share/nvim.bak-*
  - ~/.local/state/nvim.bak-*
  - ~/.cache/nvim.bak-*
  - ~/.tmux.conf.bak-*

You can manually delete these if you no longer need them.

EOF
}

###############################################################################
# Install function
###############################################################################

install() {
  log "Starting Neovim + tmux installation..."

  install_packages
  install_neovim
  install_lazyvim
  configure_lazyvim
  install_tmux_config

  log "All done!"

  cat << 'EOF'

Reproducible Neovim + tmux environment is now set up.

- Neovim:
    nvim         # runs latest Neovim

- LazyVim:
    First run 'nvim' and wait for plugins to install.

- tmux:
    tmux new -s dev       # create a new session called "dev"
    Ctrl-b "              # horizontal split (default)
    Ctrl-b %              # vertical split (default)
    Ctrl-b -              # horizontal split (extra)
    Ctrl-b |              # vertical split (extra)
    Ctrl-h/j/k/l          # move between panes (no prefix)
    tmux attach -t dev    # reattach later

You can safely re-run this script any time:
- Neovim will be updated from the latest tarball
- Previous nvim and tmux configs will be backed up with a timestamp

To uninstall, run: ./nvim-tmux.sh uninstall
EOF
}

###############################################################################
# Main execution
###############################################################################

main() {
  # Sanity checks
  if [[ "$(id -u)" -eq 0 ]]; then
    err "Run this script as a normal user (it will use sudo when needed)."
  fi

  if ! command -v sudo >/dev/null 2>&1; then
    err "sudo not found. Install sudo or run as a user with sudo privileges."
  fi

  # Detect system
  detect_system

  # Check if uninstall is requested
  if [[ "${1:-}" == "uninstall" ]]; then
    uninstall
    exit 0
  fi

  # Run installation
  install
}

# Run main function
main "$@"
