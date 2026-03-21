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

# Install packages from list
mapfile -t PKGS < <(grep -v "^\s*#" "$PACKAGES_FILE" | grep -v "^\s*$")
echo "→ Installing ${#PKGS[@]} packages..."
sudo dnf install -y "${PKGS[@]}"

echo "✅  DNF packages installed"
