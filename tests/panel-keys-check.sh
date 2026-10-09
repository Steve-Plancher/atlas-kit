#!/bin/bash
# Live keyboard check of the Protocols bar panel with real key presses (ydotool): Tab reaches the
# Music Ring switch, Space flips it and flips it back, Esc closes the panel. Puts the switch back.
cd "$(dirname "$0")" && source ./lib.sh
export YDOTOOL_SOCKET=${YDOTOOL_SOCKET:-$XDG_RUNTIME_DIR/.ydotool_socket}
IPC=(quickshell ipc -p /usr/share/omarchy/shell call com.plancher-labs.atlas-protocol)
VIBE=$HOME/.local/bin/atlas-vibe
key() { ydotool key "$1:1" "$1:0" >/dev/null; sleep 0.3; }   # 15 Tab, 57 Space, 1 Esc
panel_open() { hyprctl layers -j | grep -q '"omarchy-keyboard-panel"'; }
music() { "$VIBE" | awk '$1 == "music" {print $2}'; }
start=$(music); trap '"$VIBE" music "$start" >/dev/null; "${IPC[@]}" close >/dev/null 2>&1' EXIT
flip() { [[ $1 == on ]] && echo off || echo on; }

echo "protocol panel keys"
ok "ydotool daemon reachable" test -S "$YDOTOOL_SOCKET"
"${IPC[@]}" close >/dev/null 2>&1; sleep 0.4
# The cursor follows the mouse, so park the pointer away from the panel before counting Tabs.
hyprctl dispatch "hl.dsp.cursor.move({ x = 200, y = 200 })" >/dev/null
"${IPC[@]}" open >/dev/null 2>&1; sleep 1.2
ok "panel opens" panel_open
for _ in 1 2 3 4 5; do key 15; done          # 4 tiles, then Music Ring
key 57; sleep 0.4
eq "Tab ×5 then Space flips Music Ring" "$(flip "$start")" "$(music)"
key 57; sleep 0.4
eq "Space again flips it back" "$start" "$(music)"
key 1; sleep 0.6
fails "Esc closes the panel" panel_open
finish
