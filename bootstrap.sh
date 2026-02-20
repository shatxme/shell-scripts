#!/usr/bin/env bash
set -euo pipefail

LOG_PREFIX="[bootstrap]"

log() { printf '%s %s\n' "$LOG_PREFIX" "$*"; }
die() { printf '%s ERROR: %s\n' "$LOG_PREFIX" "$*" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_DIR="$SCRIPT_DIR/vps-setup"

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

all_cli_tools_installed() {
  local ok=0
  have_cmd rg || ok=1
  (have_cmd fd || have_cmd fdfind) || ok=1
  have_cmd fzf || ok=1
  have_cmd jq || ok=1
  have_cmd yq || ok=1
  (have_cmd bat || have_cmd batcat) || ok=1
  have_cmd zoxide || ok=1
  have_cmd delta || ok=1
  [ "$ok" -eq 0 ]
}

zsh_is_configured() {
  local zshrc="$HOME/.zshrc"
  local aliases_present=1

  if grep -q "^# >>> codex managed aliases >>>$" "$zshrc" 2>/dev/null; then
    aliases_present=0
  elif grep -q "^# Prefer modern CLI tools when available\\.$" "$zshrc" 2>/dev/null &&
    grep -q "^alias reload='source ~/.zshrc'$" "$zshrc" 2>/dev/null &&
    grep -q "^alias dev='tmux attach -t dev'$" "$zshrc" 2>/dev/null; then
    aliases_present=0
  fi

  [ -d "$HOME/.oh-my-zsh" ] &&
    [ -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ] &&
    [ -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" ] &&
    [ "$aliases_present" -eq 0 ]
}

nvm_is_configured() {
  [ -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ] && have_cmd node && have_cmd npm
}

micro_is_configured() {
  have_cmd micro &&
    have_cmd tsc &&
    have_cmd typescript-language-server &&
    [ -d "$HOME/.config/micro/plug/lsp" ]
}

tmux_is_configured() {
  have_cmd tmux && [ -f "$HOME/.tmux.conf" ]
}

run_step() {
  local script_name="$1"
  local script_path="$SETUP_DIR/$script_name"

  [ -f "$script_path" ] || die "Missing script: $script_path"
  [ -x "$script_path" ] || chmod +x "$script_path"

  log "Running $script_name"
  "$script_path"
}

main() {
  [ "$(id -u)" -ne 0 ] || die "Run as a normal user (not root)."

  # Requested order: zsh, nvm, cli, micro, tmux
  if zsh_is_configured; then
    log "Skipping zsh.sh (already configured)"
  else
    run_step "zsh.sh"
  fi

  if nvm_is_configured; then
    log "Skipping nvm.sh (already configured)"
  else
    run_step "nvm.sh"
  fi

  if all_cli_tools_installed; then
    log "Skipping cli-tools.sh (tools already installed)"
  else
    run_step "cli-tools.sh"
  fi

  if micro_is_configured; then
    log "Skipping micro.sh (already configured)"
  else
    run_step "micro.sh"
  fi

  if tmux_is_configured; then
    log "Skipping tmux.sh (already configured)"
  else
    run_step "tmux.sh"
  fi

  cat <<MSG

$LOG_PREFIX Done.

MSG

  log "Verification:"
  if command -v node >/dev/null 2>&1; then
    printf '%s node: %s\n' "$LOG_PREFIX" "$(node -v)"
  else
    printf '%s node: NOT FOUND\n' "$LOG_PREFIX"
  fi

  if command -v npm >/dev/null 2>&1; then
    printf '%s npm: %s\n' "$LOG_PREFIX" "$(npm -v)"
  else
    printf '%s npm: NOT FOUND\n' "$LOG_PREFIX"
  fi

  if command -v tmux >/dev/null 2>&1; then
    printf '%s tmux: %s\n' "$LOG_PREFIX" "$(tmux -V)"
  else
    printf '%s tmux: NOT FOUND\n' "$LOG_PREFIX"
  fi

  if command -v micro >/dev/null 2>&1; then
    printf '%s micro: %s\n' "$LOG_PREFIX" "$(micro -version | head -n 1)"
  else
    printf '%s micro: NOT FOUND\n' "$LOG_PREFIX"
  fi

  if command -v zsh >/dev/null 2>&1; then
    printf '%s zsh: %s\n' "$LOG_PREFIX" "$(zsh --version)"
  else
    printf '%s zsh: NOT FOUND\n' "$LOG_PREFIX"
  fi
  printf '%s shell: %s\n' "$LOG_PREFIX" "${SHELL:-UNKNOWN}"

  echo
  printf '%s Run: source ~/.zshrc\n' "$LOG_PREFIX"
}

main "$@"
