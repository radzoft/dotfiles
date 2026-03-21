#!/usr/bin/env bash
# Restore GNOME keybindings, PaperWM settings, and media keys from dconf snapshots
set -euo pipefail

GNOME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../gnome" && pwd)"

echo "Restoring GNOME settings..."

# ── PaperWM ────────────────────────────────────────────────────────────────
echo "  → PaperWM settings"
dconf load /org/gnome/shell/extensions/paperwm/ < "$GNOME_DIR/paperwm.dconf"

# ── WM keybindings ────────────────────────────────────────────────────────
echo "  → WM keybindings"
dconf load /org/gnome/desktop/wm/keybindings/ < "$GNOME_DIR/wm-keybindings.dconf"

# ── Media keys + custom shortcuts ─────────────────────────────────────────
echo "  → Media keys + custom shortcuts"
dconf load /org/gnome/settings-daemon/plugins/media-keys/ < "$GNOME_DIR/media-keys.dconf"

# ── Favourite dock apps ───────────────────────────────────────────────────
echo "  → Dock favourites"
gsettings set org.gnome.shell favorite-apps \
  "['org.gnome.Ptyxis.desktop', 'com.toolstack.Folio.desktop', 'code.desktop', 'code-insiders.desktop', 'google-chrome.desktop', 'org.gnome.Nautilus.desktop', 'org.gnome.TextEditor.desktop']"

echo "✅  GNOME settings restored"
echo "   Note: log out / log in for all changes to take effect."
echo "   PaperWM: disable + re-enable the extension to apply user.css changes."
