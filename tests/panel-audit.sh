#!/bin/bash
# Live audit of every bar widget panel: opens each one (shell IPC), then checks the shell log for
# palette errors and the screen for large white areas (an unthemed panel falls back to white).
# Panels load on first open, so the startup lint (test-theme-health.sh) can't see them.
cd "$(dirname "$0")" && source ./lib.sh
SHELL_DIR=/usr/share/omarchy/shell
shot=$(mktemp --suffix=.png); trap 'rm -f "$shot"' EXIT
white() {  # fraction of near-white pixels on the focused monitor
  local m; m=$(hyprctl monitors -j | python3 -c "import json,sys;print(next(x['name'] for x in json.load(sys.stdin) if x['focused']))")
  grim -o "$m" "$shot" && magick "$shot" -colorspace gray -threshold 92% -format "%[fx:mean]" info:
}
# Every IPC target that has both open() and close(); never the lock screen or switchers.
mapfile -t targets < <(quickshell ipc -p "$SHELL_DIR" show 2>/dev/null | awk '
  /^target /{t=$2} /function open\(\)/{o[t]=1} /function close\(\)/{c[t]=1}
  END{for (t in o) if (c[t] && t !~ /^(lock|altswitch)$/) print t}' | sort)
echo "panel audit (${#targets[@]} panels)"
base=$(white)
for t in "${targets[@]}"; do
  since=$(date '+%Y-%m-%d %H:%M:%S')
  quickshell ipc -p "$SHELL_DIR" call "$t" open >/dev/null 2>&1; sleep 1.5
  w=$(white)
  quickshell ipc -p "$SHELL_DIR" call "$t" close >/dev/null 2>&1; sleep 0.6
  n=$(journalctl --user --since "$since" 2>/dev/null | grep omarchy-shell \
      | grep -cE "of undefined|Unable to assign \[undefined\] to QColor|QQuickColor|of null")
  eq "$t: palette errors while open" 0 "$n"
  ok "$t: no large white area (white $w vs base $base)" python3 -c "import sys; sys.exit(0 if float('$w') - float('$base') < 0.03 else 1)"
done
finish
