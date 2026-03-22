#!/usr/bin/env bash
# setup-btrfs.sh — Post-install btrfs subvolume setup for Fedora
#
# Run ONCE after a fresh Fedora install, BEFORE mise run bootstrap.
# Creates the subvolumes that Anaconda doesn't set up, updates /etc/fstab
# with correct mount options, and configures snapper + grub-btrfs.
#
# Usage: sudo bash ~/dotfiles/scripts/setup-btrfs.sh
# ----------------------------------------------------------------------------
set -euo pipefail

# ── Config ───────────────────────────────────────────────────────────────────
USERNAME="${SUDO_USER:-glen}"
HOME_DIR="/home/$USERNAME"

# ── Colors ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
info()    { echo -e "${GREEN}→${NC}  $*"; }
warn()    { echo -e "${YELLOW}⚠${NC}   $*"; }
die()     { echo -e "${RED}✗${NC}  $*" >&2; exit 1; }
section() { echo -e "\n${BOLD}── $* ──${NC}"; }

[[ $EUID -eq 0 ]] || die "Run as root: sudo bash $0"

# ── 1. Detect btrfs ──────────────────────────────────────────────────────────
section "Detecting btrfs"

FSTYPE=$(findmnt -n -o FSTYPE /)
[[ "$FSTYPE" == "btrfs" ]] || die "Root filesystem is not btrfs (found: $FSTYPE)"

BTRFS_DEV=$(findmnt -n -o SOURCE /)
BTRFS_UUID=$(findmnt -n -o UUID /)
[[ -n "$BTRFS_UUID" ]] || die "Could not detect btrfs UUID"

info "Device: $BTRFS_DEV"
info "UUID:   $BTRFS_UUID"
info "User:   $USERNAME ($HOME_DIR)"

# ── 2. Mount btrfs top-level ─────────────────────────────────────────────────
MNTDIR=$(mktemp -d /tmp/btrfs-setup-XXXXXX)
trap 'umount "$MNTDIR" 2>/dev/null || true; rmdir "$MNTDIR" 2>/dev/null || true' EXIT

mount -o subvolid=5 "$BTRFS_DEV" "$MNTDIR"
info "Mounted top-level at $MNTDIR"

section "Existing subvolumes"
btrfs subvolume list "$MNTDIR" | awk '{printf "  id=%-5s  %s\n", $2, $NF}'

# ── 3. Create subvolumes ─────────────────────────────────────────────────────
section "Creating subvolumes"

create_subvol() {
  local name="$1" nocow="${2:-no}" path="$MNTDIR/$name"
  if [[ -d "$path" ]]; then
    warn "  '$name' already exists — skipping"
  else
    btrfs subvolume create "$path"
    info "  created: $name"
  fi
  if [[ "$nocow" == "yes" ]]; then
    chattr +C "$path" 2>/dev/null \
      && info "    nodatacow ✓" \
      || warn "    nodatacow failed (non-empty directory?)"
  fi
}

# These may already exist from Anaconda — idempotent
create_subvol root
create_subvol home
create_subvol opt
create_subvol log
create_subvol tmp   yes   # ephemeral — no CoW needed
create_subvol cache
create_subvol gdm   yes   # GDM session state — written constantly

# New subvolumes Anaconda doesn't create
create_subvol snapshots                # /.snapshots — required by snapper + grub-btrfs
create_subvol containers  yes          # ~/.local/share/containers — rootless podman
create_subvol docker      yes          # /var/lib/docker — system docker daemon
create_subvol libvirt                  # /var/lib/libvirt — VM config (keep CoW)
create_subvol libvirt-images  yes      # /var/lib/libvirt/images — VM disks (no CoW)
create_subvol flatpak                  # /var/lib/flatpak — isolate from root snapshots
create_subvol downloads               # ~/Downloads — compress=zstd:3

umount "$MNTDIR"
info "Unmounted top-level"

# ── 4. Update /etc/fstab ─────────────────────────────────────────────────────
section "Updating /etc/fstab"

U="UUID=$BTRFS_UUID"
STD="compress=zstd:1,noatime,ssd,discard=async,space_cache=v2"
NOCOW="nodatacow,noatime,ssd,discard=async,space_cache=v2"
DL="compress=zstd:3,noatime,x-gvfs-hide,ssd,discard=async,space_cache=v2"
SNAP="noatime,ssd,discard=async,space_cache=v2"

FSTAB_BAK="/etc/fstab.bak-$(date +%Y%m%d-%H%M%S)"
cp /etc/fstab "$FSTAB_BAK"
info "Backed up: $FSTAB_BAK"

# Drop existing btrfs lines — rewrite them cleanly below
# awk: keep everything where field 3 is NOT "btrfs" (covers blanks, comments, EFI, swap)
awk '$3 != "btrfs"' /etc/fstab > /tmp/fstab.new

# Append the full btrfs subvolume block
cat >> /tmp/fstab.new << FSTAB

# ── btrfs subvolumes (managed by dotfiles/scripts/setup-btrfs.sh) ────────────
$U  /                              btrfs  subvol=root,$STD          0 0
$U  /home                          btrfs  subvol=home,$STD          0 0
$U  /opt                           btrfs  subvol=opt,$STD           0 0
$U  /var/log                       btrfs  subvol=log,$STD           0 0
$U  /var/tmp                       btrfs  subvol=tmp,$NOCOW         0 0
$U  /var/cache                     btrfs  subvol=cache,$STD         0 0
$U  /var/lib/gdm                   btrfs  subvol=gdm,$NOCOW         0 0
$U  /.snapshots                    btrfs  subvol=snapshots,$SNAP    0 0
$U  /var/lib/docker                btrfs  subvol=docker,$NOCOW      0 0
$U  /var/lib/libvirt               btrfs  subvol=libvirt,$STD       0 0
$U  /var/lib/libvirt/images        btrfs  subvol=libvirt-images,$NOCOW  0 0
$U  /var/lib/flatpak               btrfs  subvol=flatpak,$STD       0 0
$U  $HOME_DIR/.local/share/containers  btrfs  subvol=containers,$NOCOW  0 0
$U  $HOME_DIR/Downloads            btrfs  subvol=downloads,$DL      0 0
FSTAB

cp /tmp/fstab.new /etc/fstab
info "fstab updated — preview:"
echo ""
grep "subvol=" /etc/fstab | sed 's/^/    /'

# ── 5. Create mount point directories ────────────────────────────────────────
section "Creating mount point directories"

dirs=(
  "/.snapshots"
  "/var/lib/docker"
  "/var/lib/flatpak"
  "/var/lib/libvirt"
  "/var/lib/libvirt/images"
  "$HOME_DIR/.local/share/containers"
  "$HOME_DIR/Downloads"
)

for dir in "${dirs[@]}"; do
  mkdir -p "$dir"
  info "  $dir"
done

# Ensure user owns their own dirs
chown -R "$USERNAME:$USERNAME" "$HOME_DIR/.local"
info "  ownership: $HOME_DIR/.local → $USERNAME"

# ── 6. Mount everything ──────────────────────────────────────────────────────
section "Mounting subvolumes"

systemctl daemon-reload
mount -a && info "mount -a succeeded" \
         || warn "Some mounts may have failed — check 'findmnt --type btrfs' after reboot"

# ── 7. Snapper setup ─────────────────────────────────────────────────────────
section "Configuring snapper"

if ! rpm -q snapper &>/dev/null; then
  info "Installing snapper packages..."
  dnf install -y snapper grub-btrfs inotify-tools python3-dnf-plugin-snapper
fi

if snapper list-configs 2>/dev/null | grep -q "^root "; then
  warn "Snapper root config already exists — skipping create"
else
  snapper -c root create-config /
  info "Created snapper config: root"
fi

# Tune snapshot retention limits
snapper -c root set-config \
  NUMBER_LIMIT=10 \
  NUMBER_LIMIT_IMPORTANT=5 \
  TIMELINE_LIMIT_HOURLY=5 \
  TIMELINE_LIMIT_DAILY=7 \
  TIMELINE_LIMIT_WEEKLY=4 \
  TIMELINE_LIMIT_MONTHLY=3
info "Snapper limits tuned"

for unit in snapper-timeline.timer snapper-cleanup.timer btrfs-scrub.timer btrfs-balance.timer grub-btrfsd.service; do
  systemctl enable --now "$unit" 2>/dev/null \
    && info "  enabled: $unit" \
    || warn "  skipped: $unit (package not installed yet — bootstrap will handle it)"
done

# ── 8. Done ───────────────────────────────────────────────────────────────────
section "Done"
cat << EOF

✅  btrfs setup complete.

Next steps:
  1. Reboot to verify all subvolumes mount cleanly:
       sudo reboot

  2. After reboot, verify:
       findmnt --type btrfs
       btrfs subvolume list /

  3. Run dotfiles bootstrap:
       cd ~/dotfiles && mise run bootstrap

Subvolume highlights:
  Rootless podman:   $HOME_DIR/.local/share/containers  (nodatacow)
  System docker:     /var/lib/docker                    (nodatacow)
  VM disk images:    /var/lib/libvirt/images             (nodatacow)
  Snapshots:         /.snapshots                        (snapper + grub-btrfs)
  Downloads:         $HOME_DIR/Downloads                (compress=zstd:3)

EOF
