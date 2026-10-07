#!/bin/bash
# A.T.L.A.S kit installer — puts Steve's A.T.L.A.S look and tools onto a fresh Omarchy install.
#
#   ./install.sh            everything: settings, apps, plugins, cursors
#   ./install.sh --no-apps  settings + plugins only (skip installing extra apps)
#
# Run it as your normal user (not root) on a machine that already has Omarchy installed.
# Anything it would overwrite is copied to ~/atlas-kit-backup-<date>/ first.
set -u
KIT=$(cd "$(dirname "$0")" && pwd)
STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP=$HOME/atlas-kit-backup-$STAMP
APPS=1; [[ ${1:-} == --no-apps ]] && APPS=0

say()  { printf '\n\033[1;36m▶ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m! %s\033[0m\n' "$*"; }

command -v omarchy >/dev/null || { echo "Omarchy isn't installed here. Install Omarchy first, then run this."; exit 1; }
[[ $EUID -eq 0 ]] && { echo "Run as your normal user, not root."; exit 1; }

say "1/6  Backing up files that will be replaced → $BACKUP"
( cd "$KIT/home" && find . -type f ) | while read -r f; do
  if [[ -e $HOME/$f ]]; then mkdir -p "$BACKUP/$(dirname "$f")"; cp -a "$HOME/$f" "$BACKUP/$f"; fi
done

say "2/6  Copying A.T.L.A.S settings, scripts, themes and wallpapers"
rsync -a "$KIT/home/" "$HOME/"
# The kit was made on a machine where home was /home/steve; point paths at this home.
if [[ $HOME != /home/steve ]]; then
  grep -rIl '/home/steve' "$KIT/home" | sed "s|^$KIT/home/||" | while read -r f; do
    sed -i "s|/home/steve|$HOME|g" "$HOME/$f"
  done
fi
chmod +x "$HOME"/.local/bin/atlas-* "$HOME"/.local/share/atlas/bin/* 2>/dev/null

if (( APPS )); then
  say "3/6  Installing extra apps (you may be asked for your password)"
  mapfile -t pkgs < <(grep -vE '^\s*(#|$)' "$KIT/apps.txt")
  mapfile -t aur  < <(grep -vE '^\s*(#|$)' "$KIT/apps-aur.txt")
  for p in "${pkgs[@]}"; do
    pacman -Qq "$p" >/dev/null 2>&1 && continue
    omarchy pkg add "$p" || omarchy pkg aur add "$p" || warn "could not install $p"
  done
  for p in "${aur[@]}"; do
    pacman -Qq "$p" >/dev/null 2>&1 || omarchy pkg aur add "$p" || warn "could not install $p (AUR)"
  done
else
  say "3/6  Skipping extra apps (--no-apps)"
fi

say "4/6  Downloading third-party bar plugins"
PLUG=$HOME/.config/omarchy/plugins
grep -vE '^\s*(#|$)' "$KIT/plugins.txt" | while read -r name url commit; do
  if [[ -d $PLUG/$name/.git ]]; then echo "  $name already present"; continue; fi
  git clone -q "$url" "$PLUG/$name" && git -C "$PLUG/$name" checkout -q "$commit" && echo "  $name ✓" || warn "could not fetch $name"
done

say "5/6  Rebuilding protocol cursors and wallpapers, applying the A.T.L.A.S theme"
"$HOME/.local/bin/atlas-protocol" build || warn "protocol build failed (needs imagemagick, xcur2png, xorg-xcursorgen)"
[[ -x $HOME/.config/omarchy/plugins/com.plancher-labs.atlas-hud/build-shader.sh ]] && \
  "$HOME/.config/omarchy/plugins/com.plancher-labs.atlas-hud/build-shader.sh" >/dev/null 2>&1
echo standby > "$HOME/.local/state/atlas-protocol/current" 2>/dev/null || true
omarchy theme set hackerman >/dev/null 2>&1 || warn "theme set failed"
omarchy-theme-bg-set "$HOME/.config/omarchy/backgrounds/hackerman/00-atlas.png" >/dev/null 2>&1
hyprctl setcursor Atlas-Cyan 24 >/dev/null 2>&1
gsettings set org.gnome.desktop.interface cursor-theme Atlas-Cyan 2>/dev/null

say "6/6  Starting services and reloading the desktop"
systemctl --user daemon-reload
systemctl --user enable --now voxtype.service 2>/dev/null || warn "voxtype service not started (is voxtype installed?)"
hyprctl reload >/dev/null 2>&1
omarchy restart shell >/dev/null 2>&1

cat <<EOF

✅ A.T.L.A.S kit installed. Log out and back in once so every app picks up the new cursor and colors.

Backup of anything replaced: $BACKUP

Not installed on purpose (tuned to the old laptop) — see $KIT/machine-specific/:
  • monitor layout (monitors.lua / workspaces.conf) — set up this machine's screens with: omarchy-display or nwg-displays
  • atlas-thermal-guard / atlas-fan — heat management for the old Intel laptop
  • atlas-display dock service (optional): systemctl --user enable --now atlas-display-dock after copying it from machine-specific/
  • fingerprint setup hook and hardware packages
EOF
