# Shell Scripts Collection

A collection of useful shell scripts for system setup, development environment configuration, and daily workflow automation.

## 📋 Table of Contents

- [Git & GitHub](#git--github)
- [Development Environment](#development-environment)
- [Server Configuration](#server-configuration)
- [User Management](#user-management)

---

## Git & GitHub

### `gh-initial-clone-all.sh`

Clones all your GitHub repositories to your local machine.

**Features:**
- Auto-installs GitHub CLI (supports macOS and Linux)
- Authenticates with GitHub via browser
- Prompts for target directory
- Clones all repositories (public and private)
- Updates existing repositories with safety checks
- Provides detailed summary of cloned/updated/failed repos

**Usage:**
```bash
./gh-initial-clone-all.sh
```

---

### `daily-pull-update.sh`

Updates all git repositories in the current directory.

**Features:**
- Auto-discovers git repositories in current directory
- Checks for uncommitted changes before pulling
- Shows current branch for each repo
- Skips repos with uncommitted changes
- Provides color-coded status output
- Summary report of updated/skipped/failed repos

**Usage:**
```bash
cd ~/Projects
./daily-pull-update.sh
```

---

## Development Environment

### `nvim-tmux.sh`

Sets up a complete Neovim + tmux development environment.

**Features:**
- Installs latest Neovim from official tarball
- Installs base development packages (git, ripgrep, fd, fzf, etc.)
- Configures LazyVim starter setup
- Sets up tmux with vim-style navigation
- Supports both Linux and macOS
- Backs up existing configurations with timestamps

**Usage:**
```bash
./nvim-tmux.sh           # Install
./nvim-tmux.sh uninstall # Uninstall
```

**Includes:**
- Neovim with LazyVim configuration
- Tmux with custom keybindings:
  - `Ctrl-h/j/k/l` - Navigate between panes
  - `Alt-h/j/k/l` - Resize panes
  - `Ctrl-b -` - Horizontal split
  - `Ctrl-b |` - Vertical split

---

### `zsh.sh`

Installs and configures Zsh with Oh My Zsh and popular plugins.

**Features:**
- Installs Zsh (supports macOS and Linux)
- Installs Oh My Zsh
- Installs plugins:
  - zsh-autosuggestions
  - zsh-syntax-highlighting
- Skips already installed components

**Usage:**
```bash
./zsh.sh
```

---

### `vscode.sh`

Sets up VS Code Server with Caddy reverse proxy and HTTPS.

**Features:**
- Installs VS Code Server from Microsoft
- Installs and configures Caddy as reverse proxy
- Sets up automatic HTTPS with Let's Encrypt
- Configures basic authentication
- Creates systemd services for both
- Verifies domain resolution
- Creates `/projects` directory

**Usage:**
```bash
./vscode.sh          # Install
./vscode.sh uninstall # Uninstall
```

**Requirements:**
- Domain name pointing to your server
- Ubuntu (Debian-based systems)

---

## Server Configuration

### `ufw-ssh-configs.sh`

Configures SSH and UFW firewall for enhanced server security.

**Features:**
- Updates system packages
- Changes SSH port to 2233
- Disables root login
- Disables password authentication (key-based only)
- Configures UFW firewall:
  - Allows SSH on port 2233
  - Allows HTTP (80) and HTTPS (443)
- Backs up original SSH config

**Usage:**
```bash
sudo ./ufw-ssh-configs.sh
```

**⚠️ Warning:** Ensure you have SSH key access configured before running this script.

---

### `ssh-keygen.sh`

Creates SSH keys and deploys them to remote servers.

**Features:**
- Generates ED25519 SSH key pairs
- Prompts for key name and server details
- Copies public key to server
- Tests SSH connection
- Creates SSH config entry for easy access
- Sets proper permissions

**Usage:**
```bash
./ssh-keygen.sh
```

**After completion, connect with:**
```bash
ssh <key-name>
```

---

## User Management

### `sudo-user.sh`

Creates a new user with sudo privileges.

**Features:**
- Prompts for username
- Creates user with home directory
- Adds user to sudo group
- Switches to new user automatically
- Validates input

**Usage:**
```bash
sudo ./sudo-user.sh
```

---

## 🚀 Quick Start

1. Clone this repository:
```bash
git clone https://github.com/yourusername/shell-scripts.git
cd shell-scripts
```

2. Make scripts executable:
```bash
chmod +x *.sh
```

3. Run any script:
```bash
./script-name.sh
```

---

## 🛠️ Requirements

- **Linux scripts:** Ubuntu/Debian (most scripts)
- **macOS scripts:** Homebrew (for package management)

---

## 📝 Notes

- Scripts automatically check for dependencies and install them when possible
- Most scripts include safety checks and confirmation prompts
- Existing configurations are backed up with timestamps before changes
- Scripts use color-coded output for better readability
- All scripts include error handling and informative messages

---

## 🤝 Contributing

Feel free to submit issues or pull requests for improvements.

---

## 📄 License

MIT License - feel free to use these scripts in your own projects.
