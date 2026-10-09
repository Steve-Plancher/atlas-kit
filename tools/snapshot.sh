#!/bin/bash
# Refresh this kit from the machine it's run on (Steve's A.T.L.A.S laptop).
#
#   tools/snapshot.sh
#
# 1. Rebuilds home/ and machine-specific/ from the live setup (files that no
#    longer exist on the machine are dropped from the kit).
# 2. Regenerates apps.txt, apps-aur.txt and plugins.txt.
# 3. Scans everything for secrets and EXITS WITH AN ERROR if anything looks like
#    a key, token, password or private key. Nothing is committed by this script.
set -euo pipefail
KIT=$(cd "$(dirname "$0")/.." && pwd)
STAGE=$(mktemp -d)
trap 'rm -rf -- "$STAGE"' EXIT
cd "$HOME"

EX=(--exclude='.git' --exclude='*.bak*' --exclude='*.pre*' --exclude='*.orig' --exclude='__pycache__'
    --exclude='node_modules' --exclude='*.log' --exclude='.cache' --exclude='*.qmlc')
take() { for p in "$@"; do [[ -e $p ]] && rsync -a "${EX[@]}" --relative "./$p" "$STAGE/home/"; done; }
mkdir -p "$STAGE/home" "$STAGE/machine/home"

# ── Desktop look and A.T.L.A.S tools ─────────────────────────────────────────
take .config/hypr/{atlas_glass.lua,atlas_protocol.lua,atlas_windows.lua,autostart.lua,bindings.lua,hyprland.lua,hyprsunset.conf,input.lua,looknfeel.lua,xdph.conf}
take .config/omarchy/{shell.json,shell.toml,dock-settings.json,extensions,themes,backgrounds,bar,branding,themed}
rsync -a "${EX[@]}" --relative --exclude='*.sample' --exclude='setup-fingerprint.hook' ./.config/omarchy/hooks "$STAGE/home/"
for d in .config/omarchy/plugins/*/; do [[ -d $d/.git ]] || take "${d%/}"; done   # own plugins; third-party → plugins.txt
take .config/atlas-protocol .config/atlas-power.conf .config/systemd/user/atlas-power.service .config/systemd/user/voxtype.service .config/voxtype .config/alacritty .config/ghostty \
     .config/kitty .config/foot .config/gtk-3.0 .config/gtk-4.0 .config/btop .config/starship.toml .config/wireplumber
take .local/bin/atlas-{agent,beat,display,glass,identify-monitors,power,protocol,snap,snap-overlay,version,vibe,window-manager-toggle,wordmark}
take .local/share/atlas .local/share/atlas-protocol .local/share/icons/Atlas-Cyan .icons/default/index.theme
mkdir -p "$STAGE/home/.local/state/atlas-cursor"; cp .local/state/atlas-cursor/*.{py,sh} "$STAGE/home/.local/state/atlas-cursor/"

# ── Tuned to the old laptop: kept, never auto-installed ──────────────────────
for p in .config/hypr/monitors.lua .config/hypr/monitors.conf .config/hypr/atlas-monitors.json .config/hypr/workspaces.conf \
         .local/bin/atlas-thermal-guard .local/bin/atlas-fan .config/systemd/user/atlas-thermal-guard.service \
         .config/systemd/user/atlas-display-dock.service .config/omarchy/hooks/post-update.d/setup-fingerprint.hook; do
  [[ -e $p ]] && rsync -a --relative "./$p" "$STAGE/machine/home/"
done

# Ship the everyday Standard look, whatever protocol happens to be on while snapshotting.
cp "$STAGE/home/.config/atlas-protocol/standard.colors.toml" "$STAGE/home/.config/omarchy/themes/hackerman/colors.toml"
sed -i -E 's/Atlas-(Red|Amber|Violet)/Atlas-Cyan/' "$STAGE/home/.config/gtk-3.0/settings.ini" "$STAGE/home/.icons/default/index.theme"

rsync -a --delete "$STAGE/home/" "$KIT/home/"
rsync -a --delete "$STAGE/machine/home/" "$KIT/machine-specific/home/"

# ── App and plugin lists ─────────────────────────────────────────────────────
DEF=$(mktemp); grep -hvE '^\s*(#|$)' /usr/share/omarchy/install/omarchy-{base,other}.packages | awk '{print $1}' | sort -u > "$DEF"
SKIP='^(intel-ucode|amd-ucode|linux|mkinitcpio|efibootmgr|libfprint-2-tod1-broadcom|fprintd|omarchy-keyring|omarchy-dev|omarchy-settings-dev|sudo|nvme-cli|powertop|fwupd|smartmontools|usbutils)$'
EXTRA=$(comm -23 <(pacman -Qqe | sort) "$DEF"); AUR=$(pacman -Qqm | sort)
{ echo "# Extra apps installed on top of stock Omarchy (official repos). One per line."
  comm -23 <(echo "$EXTRA") <(echo "$AUR") | grep -vE "$SKIP"; printf '%s\n' xcur2png imagemagick; } | awk '!seen[$0]++' > "$KIT/apps.txt"
{ echo "# Extra apps from the AUR."; comm -12 <(echo "$EXTRA") <(echo "$AUR") | grep -vE "$SKIP" || true; } > "$KIT/apps-aur.txt"
{ echo "# Left out on purpose: hardware/boot packages specific to the old laptop"; echo "$EXTRA" | grep -E "$SKIP" || true; } > "$KIT/machine-specific/skipped-packages.txt"
rm -f "$DEF"
{ echo "# Third-party Omarchy shell plugins: <folder> <git url> <commit>"
  for d in .config/omarchy/plugins/*/; do d=${d%/}; [[ -d $d/.git ]] && \
    echo "$(basename "$d") $(git -C "$d" remote get-url origin) $(git -C "$d" rev-parse HEAD)"; done; } > "$KIT/plugins.txt"

# ── Secret scan gate ─────────────────────────────────────────────────────────
PAT='(gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{20,}|sk-ant-[A-Za-z0-9_-]{20,}|sb_secret_[A-Za-z0-9_-]{10,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}|eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY|(api[_-]?key|secret|password|passwd|token)["'"'"' ]*[:=] *["'"'"'][A-Za-z0-9_./+=-]{12,}["'"'"'])'
if hits=$(grep -rIniE "$PAT" "$KIT" --exclude-dir=.git --exclude=snapshot.sh); then
  echo "✖ Possible secrets found — fix before committing:" >&2
  echo "$hits" | cut -c1-200 >&2
  exit 2
fi
echo "✔ Snapshot done, secret scan clean. Review with: git -C \"$KIT\" status"
