# Fedora 43 Upgrade Guide

## Before upgrading (on Fedora 42)

```bash
cd ~/dotfiles

# 1. Snapshot current GNOME settings + package lists
mise run snapshot
git add -A && git commit -m "snapshot: pre-Fedora-43 upgrade"
git push

# 2. Note your current mise tools (in case mise needs reinstall)
mise list

# 3. Push dotfiles to remote
git remote add origin git@github.com:glen/dotfiles.git
git push -u origin main
```

## Perform the upgrade

```bash
# Standard Fedora system upgrade
sudo dnf upgrade --refresh
sudo dnf install dnf5-plugin-system-upgrade
sudo dnf system-upgrade download --releasever=43
sudo dnf system-upgrade reboot
```

## After upgrading (on Fedora 43)

GNOME settings often survive the upgrade intact, but extensions will likely
be **disabled** because GNOME Shell bumps its version. PaperWM in particular
needs to be re-enabled after each major GNOME upgrade.

```bash
# 1. Re-enable extensions (they survive but may be disabled)
gnome-extensions enable paperwm@paperwm.github.com
# Or use Extension Manager (flatpak) to bulk-enable

# 2. Restore keybindings + PaperWM settings (they survive in dconf, but reapply anyway)
cd ~/dotfiles && mise run gnome

# 3. Check if any packages need reinstall (3rd party repos may need updating)
mise run packages   # idempotent, safe to re-run

# 4. Restart mic-ttgo service (pyenv path may shift)
systemctl --user restart mic-ttgo.service
journalctl --user -u mic-ttgo.service -f   # check logs
```

## If GNOME extensions don't work after upgrade

Some extensions may not yet support GNOME 48 (Fedora 43). Options:
1. **Wait** for the extension author to update
2. **Use Extension Manager** (flatpak) — it shows compatible versions
3. **Install from git** for extensions you rely on (PaperWM publishes quickly)

PaperWM tracks GNOME releases closely. Check:
https://github.com/paperwm/PaperWM/releases

## If the TTGO service breaks

The service now uses `uv run` — no Python version is hardcoded.
`uv` reads the inline `pyserial` dependency from `ttgo2.py` and manages the venv automatically.

```bash
# Test the script directly
uv run ~/apps/ttgo2.py

# Check service logs
journalctl --user -u mic-ttgo.service -f

# If uv shim path changed (rare), update the service and relink
cd ~/dotfiles
# edit home/.config/systemd/user/mic-ttgo.service
mise run link
systemctl --user daemon-reload && systemctl --user restart mic-ttgo.service
```

## Fresh install (new machine or reinstall)

```bash
# 1. Install minimal deps
sudo dnf install -y git stow curl

# 2. Install mise
curl https://mise.run | sh
export PATH="$HOME/.local/bin:$PATH"

# 3. Clone and bootstrap
git clone git@github.com:glen/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash scripts/bootstrap.sh
```
