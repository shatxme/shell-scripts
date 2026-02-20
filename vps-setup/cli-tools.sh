#!/usr/bin/env bash
set -euo pipefail

TOOLS_NOTE="ripgrep fd fzf jq yq bat zoxide delta"
OS_TYPE=""
PKG_MANAGER=""

log() { printf '[install-cli] %s\n' "$*"; }
die() { printf '[install-cli] ERROR: %s\n' "$*" >&2; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

detect_env() {
  case "$(uname -s)" in
    Linux) OS_TYPE="linux" ;;
    Darwin) OS_TYPE="macos" ;;
    *) die "Unsupported OS. This script supports Linux and macOS only." ;;
  esac

  if [ "$OS_TYPE" = "macos" ]; then
    command -v brew >/dev/null 2>&1 || die "Homebrew is required on macOS. Install it from https://brew.sh"
    PKG_MANAGER="brew"
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
    die "Unsupported Linux package manager. Supported: apt, pacman, dnf, brew"
  fi
}

install_apt() {
  need_cmd sudo
  log "Installing via apt: $TOOLS_NOTE"
  sudo apt-get update
  sudo apt-get install -y ripgrep fd-find fzf jq yq bat zoxide git-delta

  mkdir -p "$HOME/.local/bin"
  if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
  fi
  if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
    ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
  fi
}

install_brew() {
  need_cmd brew
  log "Installing via brew: $TOOLS_NOTE"
  brew update
  brew install ripgrep fd fzf jq yq bat zoxide git-delta
}

install_pacman() {
  need_cmd sudo
  log "Installing via pacman: $TOOLS_NOTE"
  sudo pacman -Sy --noconfirm ripgrep fd fzf jq yq bat zoxide git-delta
}

install_dnf() {
  need_cmd sudo
  log "Installing via dnf: $TOOLS_NOTE"
  sudo dnf install -y ripgrep fd-find fzf jq yq bat zoxide git-delta
}

detect_env
log "Detected environment: $OS_TYPE ($PKG_MANAGER)"

case "$PKG_MANAGER" in
  apt) install_apt ;;
  brew) install_brew ;;
  pacman) install_pacman ;;
  dnf) install_dnf ;;
  *) die "Unsupported package manager: $PKG_MANAGER" ;;
esac

log "Verifying installs..."
for t in rg fd fzf jq yq bat zoxide delta; do
  if command -v "$t" >/dev/null 2>&1; then
    printf '  %-8s %s\n' "$t" "$(command -v "$t")"
  else
    printf '  %-8s %s\n' "$t" "NOT FOUND (open a new shell and re-check)"
  fi
done

log "Done."
