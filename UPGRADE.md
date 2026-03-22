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

## it87 hardware monitor driver

The it87 driver is installed via DKMS (`AUTOINSTALL=yes`), so it **rebuilds
automatically** when a new kernel is installed — including after a Fedora upgrade.

If it fails to load after the upgrade:
```bash
dkms status it87                         # check registration
sudo dkms autoinstall                    # force rebuild for current kernel
sudo modprobe it87                       # load the module

# If the DKMS entry is broken, reinstall from source
cd ~/oss/it87 && git pull
sudo bash dkms-install.sh
```

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

### Step 1 — Anaconda partitioning

When the installer reaches **Installation Destination → Custom storage**, set up
the partitions manually. Use these exact subvolume names — `setup-btrfs.sh` (step 3)
expects them and will create anything that's missing.

| Partition | Size | Format | Mount |
|-----------|------|--------|-------|
| EFI System Partition | 1 GB | FAT32 | `/boot/efi` |
| Main partition | rest of disk | btrfs (label: `radzoft`) | — |

**btrfs subvolumes to create in Anaconda** (these are the ones the installer UI supports):

| Subvol name | Mount point |
|-------------|-------------|
| `root`  | `/` |
| `home`  | `/home` |
| `opt`   | `/opt` |
| `log`   | `/var/log` |
| `tmp`   | `/var/tmp` |
| `cache` | `/var/cache` |
| `gdm`   | `/var/lib/gdm` |

> Anaconda doesn't support `nodatacow` or `compress=zstd` options via the UI —
> leave mount options at defaults. `setup-btrfs.sh` rewrites `/etc/fstab` with
> the correct options after install.

Do **not** create a swap partition — the system uses zram (configured automatically by Fedora).

---

### Step 2 — First boot: clone dotfiles

```bash
# Install minimal deps
sudo dnf install -y git stow curl

# Install mise
curl https://mise.run | sh
export PATH="$HOME/.local/bin:$PATH"

# Clone dotfiles
git clone git@github.com:glen/dotfiles.git ~/dotfiles
```

---

### Step 3 — btrfs post-install setup (requires sudo)

This script creates the subvolumes Anaconda doesn't handle, rewrites `/etc/fstab`
with `compress=zstd:1`, `noatime`, and `nodatacow` where appropriate, and
configures snapper + grub-btrfs.

```bash
cd ~/dotfiles
sudo bash scripts/setup-btrfs.sh
```

What it creates:

| Subvol | Mount point | Options |
|--------|-------------|---------|
| `snapshots`      | `/.snapshots`                        | — |
| `containers`     | `~/.local/share/containers`          | nodatacow |
| `docker`         | `/var/lib/docker`                    | nodatacow |
| `libvirt`        | `/var/lib/libvirt`                   | compress=zstd:1 |
| `libvirt-images` | `/var/lib/libvirt/images`            | nodatacow |
| `flatpak`        | `/var/lib/flatpak`                   | compress=zstd:1 |
| `downloads`      | `~/Downloads`                        | compress=zstd:3 |

After it completes:

```bash
sudo reboot

# Verify after reboot
findmnt --type btrfs
btrfs subvolume list /
```

---

### Step 4 — Bootstrap

```bash
cd ~/dotfiles
mise run bootstrap
```
