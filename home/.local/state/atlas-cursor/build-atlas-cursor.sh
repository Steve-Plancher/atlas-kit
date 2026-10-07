#!/usr/bin/env bash
# Build the A.T.L.A.S cyan cursor theme by recoloring an existing Xcursor theme.
# Each cursor is exploded to PNGs with xcur2png, grayscaled and mapped onto the
# A.T.L.A.S blues (dark -> outline, light -> cyan), then rebuilt with xcursorgen.
set -euo pipefail

SRC=${SRC:-/usr/share/icons/Adwaita/cursors}
NAME=${NAME:-Atlas-Cyan}
DARK=${DARK:-#062b45}
LIGHT=${LIGHT:-#35c4ff}
OUT="$HOME/.local/share/icons/$NAME"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$OUT/cursors"

cat > "$OUT/index.theme" <<EOF
[Icon Theme]
Name=$NAME
Comment=A.T.L.A.S HUD cyan cursors (recolored $(basename "$(dirname "$SRC")"))
Inherits=Adwaita
EOF

made=0
linked=0
for path in "$SRC"/*; do
  name=$(basename "$path")
  if [[ -L $path ]]; then
    ln -sf "$(basename "$(readlink "$path")")" "$OUT/cursors/$name"
    linked=$((linked + 1))
    continue
  fi
  rm -rf "$WORK/x"; mkdir -p "$WORK/x"
  if ! xcur2png -d "$WORK/x" -c "$WORK/x/cur.conf" "$path" >/dev/null 2>&1; then
    echo "skip (not an xcursor): $name" >&2
    continue
  fi
  for png in "$WORK"/x/*.png; do
    magick "$png" -channel RGB -colorspace gray +level-colors "$DARK","$LIGHT" +channel "$png"
  done
  xcursorgen "$WORK/x/cur.conf" "$OUT/cursors/$name"
  made=$((made + 1))
done

echo "built $made cursors, $linked aliases -> $OUT"
