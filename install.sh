#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"

# --- helpers ---

info()    { printf '\033[0;34m[info]\033[0m  %s\n' "$*"; }
success() { printf '\033[0;32m[ok]\033[0m    %s\n' "$*"; }
warn()    { printf '\033[0;33m[warn]\033[0m  %s\n' "$*"; }
error()   { printf '\033[0;31m[error]\033[0m %s\n' "$*" >&2; }

backup_and_link() {
    local src="$1"   # absolute path inside dotfiles repo
    local dst="$2"   # absolute path in $HOME

    mkdir -p "$(dirname "$dst")"

    if [[ -e "$dst" || -L "$dst" ]]; then
        if [[ "$(readlink -f "$dst")" == "$src" ]]; then
            success "already linked: $dst"
            return
        fi
        mkdir -p "$BACKUP_DIR/$(dirname "${dst#$HOME/}")"
        mv "$dst" "$BACKUP_DIR/${dst#$HOME/}"
        warn "backed up existing file: $dst -> $BACKUP_DIR/${dst#$HOME/}"
    fi

    ln -s "$src" "$dst"
    success "linked: $dst -> $src"
}

# --- dotfiles ---

link_dotfiles() {
    info "Linking dotfiles..."

    backup_and_link "$DOTFILES_DIR/.bashrc"              "$HOME/.bashrc"
    backup_and_link "$DOTFILES_DIR/.gitconfig"           "$HOME/.gitconfig"
    backup_and_link "$DOTFILES_DIR/.config/nvim"         "$HOME/.config/nvim"
    backup_and_link "$DOTFILES_DIR/.config/zellij"       "$HOME/.config/zellij"
    backup_and_link "$DOTFILES_DIR/.config/coc"          "$HOME/.config/coc"
    backup_and_link "$DOTFILES_DIR/.config/gh"           "$HOME/.config/gh"
    backup_and_link "$DOTFILES_DIR/.claude/settings.json" "$HOME/.claude/settings.json"
    backup_and_link "$DOTFILES_DIR/.claude/CLAUDE.md"    "$HOME/.claude/CLAUDE.md"
}

# --- optional package install ---

install_packages() {
    info "Installing packages..."

    if command -v apt-get &>/dev/null; then
        sudo apt-get update -qq
        sudo apt-get install -y --no-install-recommends \
            git curl wget unzip build-essential \
            neovim nodejs npm
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y \
            git curl wget unzip \
            neovim nodejs npm
    elif command -v pacman &>/dev/null; then
        sudo pacman -Sy --noconfirm \
            git curl wget unzip \
            neovim nodejs npm
    else
        warn "Unknown package manager — skipping package install."
    fi

    # zellij
    if ! command -v zellij &>/dev/null; then
        info "Installing zellij..."
        local tmp; tmp="$(mktemp -d)"
        local ver; ver="$(curl -s https://api.github.com/repos/zellij-org/zellij/releases/latest \
            | grep '"tag_name"' | cut -d'"' -f4)"
        curl -sSL "https://github.com/zellij-org/zellij/releases/download/${ver}/zellij-x86_64-unknown-linux-musl.tar.gz" \
            | tar xz -C "$tmp"
        sudo install -m755 "$tmp/zellij" /usr/local/bin/zellij
        rm -rf "$tmp"
        success "zellij installed: $(zellij --version)"
    else
        success "zellij already installed: $(zellij --version)"
    fi

    success "Packages ready."
}

# --- neovim plugin bootstrap ---

bootstrap_nvim() {
    if command -v nvim &>/dev/null; then
        info "Bootstrapping Neovim plugins (lazy.nvim headless)..."
        nvim --headless "+Lazy! sync" +qa 2>/dev/null || true
        success "Neovim plugins synced."
    else
        warn "nvim not found — skipping plugin bootstrap."
    fi
}

# --- main ---

usage() {
    cat <<EOF
Usage: $0 [options]

Options:
  --packages   Also install system packages (requires sudo)
  --nvim       Also bootstrap Neovim plugins
  --all        Run everything (--packages + --nvim)
  -h, --help   Show this help

Without options, only dotfiles symlinks are created.
EOF
}

DO_PACKAGES=false
DO_NVIM=false

for arg in "$@"; do
    case "$arg" in
        --packages) DO_PACKAGES=true ;;
        --nvim)     DO_NVIM=true ;;
        --all)      DO_PACKAGES=true; DO_NVIM=true ;;
        -h|--help)  usage; exit 0 ;;
        *) error "Unknown option: $arg"; usage; exit 1 ;;
    esac
done

info "Dotfiles directory: $DOTFILES_DIR"

$DO_PACKAGES && install_packages
link_dotfiles
$DO_NVIM     && bootstrap_nvim

success "Done! Open a new shell to apply changes."
