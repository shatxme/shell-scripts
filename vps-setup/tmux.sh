#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# tmux Setup/Uninstall Script
#
# Usage:
#   ./tmux.sh           - Install tmux and write ~/.tmux.conf
#   ./tmux.sh uninstall - Remove ~/.tmux.conf and optionally uninstall tmux
###############################################################################

OS_TYPE=""
PKG_MANAGER=""
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

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

detect_system() {
  local os
  os="$(uname -s)"

  case "$os" in
    Linux*)
      OS_TYPE="linux"
      ;;
    Darwin*)
      OS_TYPE="macos"
      ;;
    *)
      err "Unsupported OS: $os. This script supports Linux and macOS only."
      ;;
  esac

  log "Detected OS: $OS_TYPE"

  if [[ "$OS_TYPE" == "macos" ]]; then
    if command -v brew >/dev/null 2>&1; then
      PKG_MANAGER="brew"
    else
      err "Homebrew not found. Please install Homebrew first: https://brew.sh"
    fi
    return 0
  fi

  if command -v apt-get >/dev/null 2>&1; then
    PKG_MANAGER="apt"
  elif command -v pacman >/dev/null 2>&1; then
    PKG_MANAGER="pacman"
  elif command -v dnf >/dev/null 2>&1; then
    PKG_MANAGER="dnf"
  elif command -v brew >/dev/null 2>&1; then
    PKG_MANAGER="brew"
  else
    err "No supported package manager found on Linux. Supported: apt, pacman, dnf, brew"
  fi

  log "Using package manager: $PKG_MANAGER"
}

install_tmux_package() {
  if command -v tmux >/dev/null 2>&1; then
    log "tmux already installed, skipping package install."
    return 0
  fi

  case "$PKG_MANAGER" in
    apt)
      log "Installing tmux via apt..."
      sudo apt-get update
      sudo apt-get install -y tmux
      ;;
    pacman)
      log "Installing tmux via pacman..."
      sudo pacman -Sy --noconfirm tmux
      ;;
    dnf)
      log "Installing tmux via dnf..."
      sudo dnf install -y tmux
      ;;
    brew)
      log "Installing tmux via Homebrew..."
      brew install tmux
      ;;
    *)
      err "Unsupported package manager: $PKG_MANAGER"
      ;;
  esac
}

install_tmux_config() {
  local tmux_conf backup
  tmux_conf="$HOME/.tmux.conf"

  if [[ -f "$tmux_conf" ]]; then
    backup="${tmux_conf}.bak-${TIMESTAMP}"
    log "Backing up existing tmux config: $tmux_conf -> $backup"
    mv "$tmux_conf" "$backup"
  fi

  log "Writing new tmux config to $tmux_conf..."

  cat > "$tmux_conf" << 'TMUX_EOF'
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
TMUX_EOF

  log "tmux config installed."
}

remove_if_exists() {
  local path
  path="$1"

  if [[ -e "$path" ]]; then
    log "Removing $path..."
    rm -rf "$path"
  else
    log "$path not found, skipping..."
  fi
}

uninstall() {
  local tmux_conf
  tmux_conf="$HOME/.tmux.conf"

  log "Starting tmux uninstall process..."
  echo ""

  warn "This script will remove:"
  echo "  - tmux config: ~/.tmux.conf"
  echo "  - tmux plugins: ~/.tmux (if exists)"
  echo ""
  warn "Backup files (*.bak-*) will NOT be removed."
  echo ""

  read -r -p "Are you sure you want to continue? [y/N] " -n 1
  echo
  if [[ ! ${REPLY:-} =~ ^[Yy]$ ]]; then
    log "Uninstall cancelled."
    exit 0
  fi

  remove_if_exists "$tmux_conf"
  remove_if_exists "$HOME/.tmux"

  echo ""
  read -r -p "Would you like to uninstall tmux package as well? [y/N] " -n 1
  echo

  if [[ ${REPLY:-} =~ ^[Yy]$ ]]; then
    case "$PKG_MANAGER" in
      apt)
        log "Uninstalling tmux via apt..."
        sudo apt-get remove -y tmux || warn "tmux could not be removed"
        sudo apt-get autoremove -y
        ;;
      pacman)
        log "Uninstalling tmux via pacman..."
        sudo pacman -R --noconfirm tmux || warn "tmux could not be removed"
        ;;
      dnf)
        log "Uninstalling tmux via dnf..."
        sudo dnf remove -y tmux || warn "tmux could not be removed"
        ;;
      brew)
        log "Uninstalling tmux via Homebrew..."
        brew uninstall tmux 2>/dev/null || warn "tmux could not be removed"
        ;;
    esac
  else
    log "Skipping tmux package uninstallation."
  fi

  log "Uninstall complete!"

  cat << 'UNINSTALL_EOF'

tmux config has been removed.

Backup files (*.bak-*) were preserved and can be found in:
  - ~/.tmux.conf.bak-*

You can manually delete these if you no longer need them.

UNINSTALL_EOF
}

install() {
  log "Starting tmux installation..."

  install_tmux_package
  install_tmux_config

  log "All done!"

  cat << 'INSTALL_EOF'

tmux environment is now set up.

- tmux:
    tmux new -s dev       # create a new session called "dev"
    Ctrl-b "              # horizontal split (default)
    Ctrl-b %              # vertical split (default)
    Ctrl-b -              # horizontal split (extra)
    Ctrl-b |              # vertical split (extra)
    Ctrl-h/j/k/l          # move between panes (no prefix)
    tmux attach -t dev    # reattach later

You can safely re-run this script any time:
- tmux package install is skipped if already present
- Existing tmux config is backed up with a timestamp

To uninstall, run: ./tmux.sh uninstall
INSTALL_EOF
}

main() {
  if [[ "$(id -u)" -eq 0 ]]; then
    err "Run this script as a normal user (it will use sudo when needed)."
  fi

  detect_system

  if [[ "$PKG_MANAGER" != "brew" ]] && [[ ! -x "$(command -v sudo || true)" ]]; then
    err "sudo not found. Install sudo or run as a user with sudo privileges."
  fi

  if [[ "${1:-}" == "uninstall" ]]; then
    uninstall
    exit 0
  fi

  install
}

main "$@"
