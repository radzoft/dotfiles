#!/usr/bin/env bash
# bootstrap.sh — run this on a fresh Fedora install BEFORE mise is available
# Usage: bash bootstrap.sh
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "🚀  Bootstrapping from: $DOTFILES_DIR"

# ── 1. Install mise if missing ────────────────────────────────────────────────
if ! command -v mise &>/dev/null && ! [[ -x "$HOME/.local/bin/mise" ]]; then
  echo "Installing mise..."
  curl -fsSL https://mise.run | sh
  export PATH="$HOME/.local/bin:$PATH"
fi
eval "$("$HOME/.local/bin/mise" activate bash 2>/dev/null || mise activate bash)"

# ── 2. Install stow if missing ────────────────────────────────────────────────
if ! command -v stow &>/dev/null; then
  echo "Installing stow..."
  sudo dnf install -y stow
fi

# ── 3. Run mise tasks in order ────────────────────────────────────────────────
cd "$DOTFILES_DIR"
mise run packages
mise run link
mise run tools
mise run gnome
mise run services
mise run udev

echo ""
echo "✅  Bootstrap complete!"
echo ""
echo "Next steps:"
echo "  1. cp ~/dotfiles/home/.bashrc.secrets.template ~/.bashrc.secrets"
echo "     # Edit with your actual API keys"
echo "  2. mise run python-setup   # Install pyenv + TTGO Python deps"
echo "  3. mise run extensions     # Install GNOME extensions (optional)"
echo "  4. Log out and back in to apply GNOME settings"
