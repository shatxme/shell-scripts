#!/usr/bin/env bash
set -euo pipefail

LOG_PREFIX="[micro-setup]"
SCRIPT_NAME="$(basename "$0")"
OS_TYPE=""
PKG_MANAGER=""

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
  log "Installing micro via apt"
  sudo apt-get update
  sudo apt-get install -y micro
}

install_brew() {
  need_cmd brew
  log "Installing micro via Homebrew"
  brew update
  brew install micro
}

install_pacman() {
  need_cmd sudo
  log "Installing micro via pacman"
  sudo pacman -Sy --noconfirm micro
}

install_dnf() {
  need_cmd sudo
  log "Installing micro via dnf"
  sudo dnf install -y micro
}

install_base_packages() {
  case "$PKG_MANAGER" in
    apt) install_apt ;;
    brew) install_brew ;;
    pacman) install_pacman ;;
    dnf) install_dnf ;;
    *) die "Unsupported package manager: $PKG_MANAGER" ;;
  esac
}

npm_global_install() {
  local pkg="$1"

  if npm install -g "$pkg"; then
    return 0
  fi

  if command -v sudo >/dev/null 2>&1; then
    log "Retrying npm global install with sudo: $pkg"
    sudo npm install -g "$pkg"
  else
    die "Failed to install npm package '$pkg' globally and sudo is unavailable"
  fi
}

ensure_npm_global_bin_in_path() {
  local npm_prefix npm_bin profile

  npm_prefix="$(npm config get prefix 2>/dev/null || true)"
  [ -n "$npm_prefix" ] || return 0

  npm_bin="$npm_prefix/bin"
  if [ ! -d "$npm_bin" ]; then
    return 0
  fi

  case ":$PATH:" in
    *":$npm_bin:"*) return 0 ;;
  esac

  profile="$HOME/.profile"
  if [ ! -f "$profile" ]; then
    touch "$profile"
  fi

  if ! grep -Fq "# Added by $SCRIPT_NAME" "$profile"; then
    {
      echo
      echo "# Added by $SCRIPT_NAME"
      echo "export PATH=\"$npm_bin:\$PATH\""
    } >> "$profile"
    log "Added npm global bin to $profile"
  fi
}

install_micro_lsp_plugin() {
  need_cmd micro
  log "Installing micro lsp plugin"

  if micro -plugin install lsp; then
    return 0
  fi

  log "micro plugin command failed, falling back to direct git clone"
  need_cmd git
  mkdir -p "$HOME/.config/micro/plug"

  if [ -d "$HOME/.config/micro/plug/lsp/.git" ]; then
    git -C "$HOME/.config/micro/plug/lsp" pull --ff-only
  else
    rm -rf "$HOME/.config/micro/plug/lsp"
    git clone https://github.com/AndCake/micro-plugin-lsp "$HOME/.config/micro/plug/lsp"
  fi
}

configure_micro_settings() {
  local settings backup_ts
  settings="$HOME/.config/micro/settings.json"
  mkdir -p "$(dirname "$settings")"

  if [ ! -f "$settings" ]; then
    printf '{}\n' > "$settings"
  fi

  backup_ts="$(date +%Y%m%d-%H%M%S)"
  cp "$settings" "$settings.bak.$backup_ts"

  node - "$settings" <<'NODE'
const fs = require('fs');
const file = process.argv[2];

let data = {};
try {
  const raw = fs.readFileSync(file, 'utf8').trim();
  data = raw ? JSON.parse(raw) : {};
} catch (err) {
  console.error(`Failed to parse ${file}: ${err.message}`);
  process.exit(1);
}

data["lsp.server"] = "typescript=typescript-language-server --stdio,javascript=typescript-language-server --stdio";
data["lsp.tabcompletion"] = true;
data["lsp.formatOnSave"] = false;
data["lsp.autocompleteDetails"] = false;

fs.writeFileSync(file, JSON.stringify(data, null, 2) + '\n');
NODE

  log "Updated $settings"
}

verify_install() {
  local missing=0

  for cmd in micro node npm typescript-language-server tsc; do
    if command -v "$cmd" >/dev/null 2>&1; then
      printf '  %-26s %s\n' "$cmd" "$(command -v "$cmd")"
    else
      printf '  %-26s %s\n' "$cmd" "NOT FOUND"
      missing=1
    fi
  done

  [ "$missing" -eq 0 ] || die "One or more required commands are missing"
}

main() {
  detect_env
  log "Detected environment: $OS_TYPE ($PKG_MANAGER)"
  install_base_packages

  need_cmd node
  need_cmd npm

  log "Installing TypeScript language tooling"
  npm_global_install typescript
  npm_global_install typescript-language-server

  ensure_npm_global_bin_in_path
  install_micro_lsp_plugin
  configure_micro_settings

  log "Verification"
  verify_install

  cat <<MSG

$LOG_PREFIX Done.
$LOG_PREFIX If PATH changed, restart your shell (or run: source ~/.profile).
$LOG_PREFIX Open any .ts/.tsx/.js/.jsx file in micro to start the TypeScript LSP.
MSG
}

main "$@"
