# glen's dotfiles

Fedora workstation configuration, managed with [mise](https://mise.jdx.dev/) + [stow](https://www.gnu.org/software/stow/).

## Quick start (fresh Fedora install)

```bash
# 1. Install git + stow + mise (if not already present)
sudo dnf install -y git stow curl

# Install mise
curl https://mise.run | sh
echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
source ~/.bashrc

# 2. Clone this repo
git clone https://github.com/glen/dotfiles.git ~/dotfiles
cd ~/dotfiles

# 3. Run full bootstrap
mise run bootstrap
```

That's it. The bootstrap will:
1. Install system packages (dnf + flatpak)
2. Symlink dotfiles via stow
3. Install mise-managed tools
4. Restore GNOME / PaperWM settings
5. Enable systemd user services (mic-ttgo, autoforge)
6. Set up pyenv with Python 3.13

## Individual tasks

```bash
mise run link          # Symlink dotfiles only (stow home/ → ~/)
mise run packages      # Install DNF packages
mise run flatpaks      # Install Flatpak apps
mise run gnome         # Restore GNOME keybindings + PaperWM dconf
mise run services      # Enable systemd user services
mise run udev          # Install udev rules (requires sudo)
```

## Repo structure

```
dotfiles/
├── mise.toml           # Tools + tasks (entry point)
├── home/               # Stow package → ~/
│   ├── .bashrc
│   ├── .bash_profile
│   ├── .gitconfig
│   └── .config/
│       ├── mise/config.toml      # Global mise tools
│       ├── ghostty/config
│       ├── paperwm/user.css
│       └── systemd/user/
│           ├── mic-ttgo.service  # TTGO display service
│           └── autoforge.service
├── gnome/
│   ├── paperwm.dconf             # PaperWM settings snapshot
│   ├── wm-keybindings.dconf      # WM keyboard shortcuts
│   ├── media-keys.dconf          # Media key / custom shortcuts
│   └── extensions.txt            # GNOME extensions to install
├── system/
│   ├── packages.txt              # DNF packages to install
│   ├── flatpaks.txt              # Flatpak app IDs
│   └── udev/
│       └── 50-usb-hub-no-autosuspend.rules
├── apps/
│   └── ttgo2.py                  # TTGO mic-status display script
└── scripts/
    ├── bootstrap.sh
    ├── install-packages.sh
    ├── install-flatpaks.sh
    ├── restore-gnome.sh
    └── install-extensions.sh
```

## Secrets

API keys and tokens live in `~/.bashrc.secrets` (not tracked by git).
Copy the template:
```bash
cp ~/dotfiles/home/.bashrc.secrets.template ~/.bashrc.secrets
# Edit with your actual keys
```

## TTGO device

The `mic-ttgo` service talks to the TTGO T-Display over USB serial.
Python deps are managed via pyenv (3.13.7). After bootstrap, run:
```bash
pyenv install 3.13.7
pip install pyserial psutil
systemctl --user enable --now mic-ttgo.service
```

The service is defined in `home/.config/systemd/user/mic-ttgo.service`.

## Upgrading Fedora

Before `dnf system-upgrade`:
```bash
cd ~/dotfiles
mise run snapshot   # exports fresh dconf + package lists
git add -A && git commit -m "snapshot before Fedora XX upgrade"
```

After the upgrade, re-run `mise run gnome` to restore settings (GNOME may reset them).
