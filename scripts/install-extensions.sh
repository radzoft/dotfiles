#!/usr/bin/env bash
# Install GNOME extensions via gnome-extensions-cli or Extension Manager
# Requires: pip install gnome-extensions-cli  OR  flatpak Extension Manager
set -euo pipefail

GNOME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../gnome" && pwd)"

# Check for gext (gnome-extensions-cli)
if ! command -v gext &>/dev/null; then
  echo "Installing gnome-extensions-cli (gext)..."
  pip install --user gnome-extensions-cli 2>/dev/null \
    || pipx install gnome-extensions-cli 2>/dev/null \
    || { echo "Warning: could not install gext. Install extensions manually via Extension Manager."; exit 0; }
fi

echo "Installing GNOME extensions..."
mapfile -t EXTS < <(grep -v "^\s*#" "$GNOME_DIR/extensions.txt" | grep -v "^\s*$")

for ext in "${EXTS[@]}"; do
  echo "  → $ext"
  # gext install uses the extension UUID
  gext install "$ext" 2>/dev/null \
    || echo "    (skipped — already installed or not found)"
done

# Enable all of them
for ext in "${EXTS[@]}"; do
  gnome-extensions enable "$ext" 2>/dev/null || true
done

echo "✅  Extensions installed + enabled"
echo "   Note: some extensions may need a GNOME Shell restart (Alt+F2 → r) to activate."
