#!/usr/bin/env bash
# Install Flatpak apps
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLATPAKS_FILE="$SCRIPT_DIR/../system/flatpaks.txt"

# Ensure Flathub is added
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

echo "Installing Flatpak apps..."
mapfile -t APPS < <(grep -v "^\s*#" "$FLATPAKS_FILE" | grep -v "^\s*$")
for app in "${APPS[@]}"; do
  echo "  → $app"
  flatpak install --user --noninteractive flathub "$app" 2>/dev/null \
    || echo "    (skipped — not found on flathub or already installed)"
done
echo "✅  Flatpaks installed"
