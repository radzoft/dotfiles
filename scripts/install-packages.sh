#!/usr/bin/env bash
# Install curated DNF packages
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_FILE="$SCRIPT_DIR/../system/packages.txt"

echo "Installing DNF packages..."

# Add required repos first
echo "→ Adding RPM Fusion repos..."
sudo dnf install -y \
  "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
  "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" \
  2>/dev/null || true

echo "→ Adding Docker repo..."
sudo dnf config-manager addrepo \
  --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo 2>/dev/null || true

echo "→ Adding Tailscale repo..."
sudo dnf config-manager addrepo \
  --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo 2>/dev/null || true

echo "→ Adding GitHub CLI repo..."
sudo dnf config-manager addrepo \
  --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo 2>/dev/null || true

echo "→ Adding Cloudflared repo..."
sudo dnf config-manager addrepo \
  --from-repofile=https://pkg.cloudflare.com/cloudflared-ascii.repo 2>/dev/null || true

echo "→ Adding VS Code repo..."
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc 2>/dev/null || true
echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" \
  | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null

# Install packages from list
mapfile -t PKGS < <(grep -v "^\s*#" "$PACKAGES_FILE" | grep -v "^\s*$")
echo "→ Installing ${#PKGS[@]} packages..."
sudo dnf install -y --skip-unavailable "${PKGS[@]}"

echo "✅  DNF packages installed"
