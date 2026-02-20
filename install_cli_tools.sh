#!/usr/bin/env bash
set -euo pipefail

TOOLS_NOTE="ripgrep fd fzf jq yq bat zoxide delta"

log() { printf '[install-cli] %s\n' "$*"; }
die() { printf '[install-cli] ERROR: %s\n' "$*" >&2; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
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

if command -v apt-get >/dev/null 2>&1; then
  install_apt
elif command -v brew >/dev/null 2>&1; then
  install_brew
elif command -v pacman >/dev/null 2>&1; then
  install_pacman
elif command -v dnf >/dev/null 2>&1; then
  install_dnf
else
  die "Unsupported package manager. Supported: apt, brew, pacman, dnf"
fi

log "Verifying installs..."
for t in rg fd fzf jq yq bat zoxide delta; do
  if command -v "$t" >/dev/null 2>&1; then
    printf '  %-8s %s\n' "$t" "$(command -v "$t")"
  else
    printf '  %-8s %s\n' "$t" "NOT FOUND (open a new shell and re-check)"
  fi
done

log "Done."
