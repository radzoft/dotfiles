# Fedora Setup & Upgrade Guide

## Fresh install (primary path)

### Step 1 — Anaconda partitioning

When the installer reaches **Installation Destination → Custom storage**, set up
the partitions manually. Use these exact subvolume names — `setup-btrfs.sh` (step 3)
expects them and will create anything that's missing.

| Partition | Size | Format | Mount |
|-----------|------|--------|-------|
| EFI System Partition | 1 GB | FAT32 | `/boot/efi` |
| Main partition | rest of disk | btrfs (label: `radzoft`) | — |

**btrfs subvolumes to create in Anaconda:**

| Subvol name | Mount point |
|-------------|-------------|
| `root`  | `/` |
| `home`  | `/home` |
| `opt`   | `/opt` |
| `log`   | `/var/log` |
| `tmp`   | `/var/tmp` |
| `cache` | `/var/cache` |
| `gdm`   | `/var/lib/gdm` |

> Anaconda doesn't support `nodatacow` or `compress=zstd` via the UI — leave
> mount options at defaults. `setup-btrfs.sh` rewrites `/etc/fstab` with the
> correct options after install.

Do **not** create a swap partition — Fedora uses zram automatically.

---

### Step 2 — First boot: clone dotfiles + install pi

```bash
sudo dnf install -y git stow curl

curl https://mise.run | sh
export PATH="$HOME/.local/bin:$PATH"

git clone git@github.com:glen/dotfiles.git ~/dotfiles

# Install pi via mise so Claude can assist with the rest of setup
mise use -g npm:@mariozechner/pi-coding-agent
export PATH="$HOME/.local/share/mise/shims:$PATH"

# Now start pi and let Claude guide you through steps 3 → 4
pi
```

> From here you can ask Claude to walk you through btrfs setup and bootstrap.

---

### Step 3 — btrfs post-install setup (requires sudo)

Creates the subvolumes Anaconda doesn't handle, rewrites `/etc/fstab` with
`compress=zstd:1`, `noatime`, and `nodatacow` where appropriate, and
configures snapper + grub-btrfs.

```bash
cd ~/dotfiles
sudo bash scripts/setup-btrfs.sh
# or: mise run btrfs-setup
```

**What it adds** (on top of what Anaconda created):

| Subvol | Mount point | Notable option |
|--------|-------------|----------------|
| `snapshots`      | `/.snapshots`                     | — |
| `containers`     | `~/.local/share/containers`       | nodatacow |
| `docker`         | `/var/lib/docker`                 | nodatacow |
| `libvirt`        | `/var/lib/libvirt`                | compress=zstd:1 |
| `libvirt-images` | `/var/lib/libvirt/images`         | nodatacow |
| `flatpak`        | `/var/lib/flatpak`                | compress=zstd:1 |
| `downloads`      | `~/Downloads`                     | compress=zstd:3 |

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

> `bootstrap` runs `dnf update` first before installing packages, so the
> system is fully current before repos and dependencies are added.

---

### Step 5 — Post-bootstrap checks

```bash
# Re-enable GNOME extensions (Shell version bump disables them)
gnome-extensions enable paperwm@paperwm.github.com
# or use Extension Manager (flatpak) to bulk-enable

# Check mic-ttgo service
systemctl --user status mic-ttgo.service
journalctl --user -u mic-ttgo.service -f
```

---

## In-place upgrade (F42 → F43)

### Before upgrading

```bash
cd ~/dotfiles

# Snapshot current GNOME settings + package lists
mise run snapshot
git add -A && git commit -m "snapshot: pre-Fedora-43 upgrade"
git push

# Note your current mise tools (in case mise needs reinstall)
mise list
```

### Perform the upgrade

```bash
sudo dnf upgrade --refresh
sudo dnf install dnf5-plugin-system-upgrade
sudo dnf system-upgrade download --releasever=43
sudo dnf system-upgrade reboot
```

### After upgrading

GNOME settings often survive the upgrade intact, but extensions will likely
be **disabled** because GNOME Shell bumps its version.

```bash
# 1. Re-enable extensions
gnome-extensions enable paperwm@paperwm.github.com

# 2. Reapply keybindings + PaperWM settings
cd ~/dotfiles && mise run gnome

# 3. Reinstall packages (3rd party repos may need updating)
mise run packages

# 4. Restart mic-ttgo service (pyenv path may shift)
systemctl --user restart mic-ttgo.service
journalctl --user -u mic-ttgo.service -f
```

---

## Troubleshooting

### GNOME extensions don't work after upgrade

Some extensions may not yet support the new GNOME Shell version. Options:
1. **Wait** for the extension author to update
2. **Use Extension Manager** (flatpak) — shows compatible versions
3. **Install from git** — PaperWM publishes quickly:
   https://github.com/paperwm/PaperWM/releases

### it87 hardware monitor driver

The it87 driver is installed via DKMS (`AUTOINSTALL=yes`) and rebuilds
automatically when a new kernel is installed.

If it fails to load after an upgrade:
```bash
dkms status it87
sudo dkms autoinstall
sudo modprobe it87

# If the DKMS entry is broken, reinstall from source
cd ~/oss/it87 && git pull
sudo bash dkms-install.sh
```

### mic-ttgo service breaks

The service uses `uv run` — no Python version is hardcoded.

```bash
uv run ~/apps/ttgo2.py          # test directly

journalctl --user -u mic-ttgo.service -f

# If uv shim path changed (rare)
cd ~/dotfiles
# edit home/.config/systemd/user/mic-ttgo.service
mise run link
systemctl --user daemon-reload && systemctl --user restart mic-ttgo.service
```
