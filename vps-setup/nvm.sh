#!/usr/bin/env bash
set -euo pipefail

LOG_PREFIX="[nvm-setup]"
OS_TYPE=""

log() { printf '%s %s\n' "$LOG_PREFIX" "$*"; }
die() { printf '%s ERROR: %s\n' "$LOG_PREFIX" "$*" >&2; exit 1; }
need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

detect_env() {
  case "$(uname -s)" in
    Linux) OS_TYPE="linux" ;;
    Darwin) OS_TYPE="macos" ;;
    *) die "Unsupported OS. This script supports Linux and macOS only." ;;
  esac

  log "Detected environment: $OS_TYPE"
}

install_nvm() {
  if [ -d "${NVM_DIR:-$HOME/.nvm}" ] && [ -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]; then
    log "NVM already installed"
    return 0
  fi

  need_cmd curl
  log "Installing NVM"
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
}

load_nvm() {
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  [ -s "$NVM_DIR/nvm.sh" ] || die "NVM not found at $NVM_DIR/nvm.sh"
  # shellcheck disable=SC1090
  . "$NVM_DIR/nvm.sh"
}

install_node_lts() {
  log "Installing latest LTS Node"
  nvm install --lts
  nvm alias default 'lts/*'
  nvm use default

  local ver
  ver="$(nvm version default)"
  [ "$ver" != "N/A" ] || die "Failed to set default Node version"

  log "Default Node set to $ver"
}

main() {
  detect_env
  install_nvm
  load_nvm
  install_node_lts

  cat <<MSG

$LOG_PREFIX Done.
$LOG_PREFIX Restart your shell, or run:
$LOG_PREFIX   export NVM_DIR="\$HOME/.nvm"
$LOG_PREFIX   [ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"
$LOG_PREFIX Then verify with: node -v && npm -v
MSG
}

main "$@"
