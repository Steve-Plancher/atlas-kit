#!/bin/bash
# Live check on the real desktop: engages every protocol (the screen recolors several times),
# flips each HUD switch and confirms the HUD starts/stops the right analyzers, then puts
# everything back the way it was. Run from a desktop session; takes about a minute.
cd "$(dirname "$0")" && source ./lib.sh
PROTO=$HOME/.local/bin/atlas-protocol VIBE=$HOME/.local/bin/atlas-vibe
orig_proto=$("$PROTO" show); orig=$("$VIBE")
sw() { awk -v k="$1" '$1==k{print $2}' <<<"$orig"; }
restore() {
  "$VIBE" music "$(sw music)" >/dev/null; "$VIBE" voice "$(sw voice)" >/dev/null; "$VIBE" nowplaying "$(sw nowplaying)" >/dev/null
  [[ $("$PROTO" show) == "$orig_proto" ]] || "$PROTO" "$orig_proto" 2>/dev/null
}
trap restore EXIT
since=$(date '+%Y-%m-%d %H:%M:%S')
# wait_for <seconds> <cmd...>: poll until cmd succeeds
wait_for() { local n=$(($1 * 4)); shift; while ((n-- > 0)); do "$@" >/dev/null 2>&1 && return 0; sleep 0.25; done; return 1; }
# Exact matches only: `pgrep -f atlas-beat` would also match any shell whose command line merely
# mentions atlas-beat (e.g. the one running test-atlas-beat.py) and the cava config paths.
analyzers() { ps -eo pid=,args= | awk '$2 ~ /python3?$/ && $3 ~ /\/atlas-beat$/ {print}'; }
music_proc() { analyzers | awk 'NF == 3' | grep -q .; }
mic_proc() { analyzers | awk '$4 == "--mic"' | grep -q .; }
any_proc() { analyzers | grep -q .; }
both_proc() { music_proc && mic_proc; }
no() { ! "$@"; }
# Theme switches are CPU-heavy; if the thermal guard engages, the HUD freezes on purpose and stops
# its analyzers. Wait for it to release before judging them.
cool() { ! grep -q '"engaged": true' "$HOME/.local/state/atlas-thermal-guard/state.json" 2>/dev/null; }
settle() { wait_for 120 cool || echo "  (thermal guard still engaged after 120 s: HUD checks below will fail for heat, not code)"; }

echo "live: protocols"
for n in standard deadlock focus vibe; do
  "$PROTO" "$n" 2>/dev/null
  eq "$n: state" "$n" "$("$PROTO" show)"
  bg=$(basename "$(readlink -f "$HOME/.local/state/omarchy/current/background")")
  if [[ $n == standard ]]; then ok "$n: wallpaper is not protocol art" test "${bg#00-atlas-protocol-}" = "$bg"
  else eq "$n: wallpaper" "00-atlas-protocol-$n.png" "$bg"; fi
  acc=$(awk -F= '/^accent=/{print $2}' "$HOME/.local/state/atlas-protocol/state.conf")
  ok "$n: window borders use the protocol accent" bash -c "hyprctl getoption general:col.active_border | grep -qi '$acc'"
  eq "$n: Protocols panel marks it active" "$n" "$("$PROTO" list --json | python3 -c 'import json,sys; print(" ".join(x["name"] for x in json.load(sys.stdin) if x["active"]))')"
done

echo "live: HUD switches (in Vibe)"
settle
"$VIBE" music on >/dev/null; "$VIBE" voice off >/dev/null
ok "music on → music analyzer runs" wait_for 6 music_proc
ok "voice off → no mic analyzer" no mic_proc
"$VIBE" voice on >/dev/null
ok "voice on → mic analyzer runs" wait_for 6 mic_proc
"$VIBE" music off >/dev/null
ok "music off → music analyzer stops" wait_for 6 no music_proc
ok "music off leaves the voice ring alone" mic_proc
"$VIBE" voice off >/dev/null
ok "voice off → mic analyzer stops" wait_for 6 no mic_proc
"$VIBE" music on >/dev/null; "$VIBE" voice on >/dev/null
ok "both on → both run" wait_for 6 both_proc
"$PROTO" standard 2>/dev/null
ok "leaving Vibe stops both analyzers" wait_for 8 no any_proc || analyzers | sed 's/^/    still running: /'
"$PROTO" vibe 2>/dev/null; settle
ok "back in Vibe restarts them" wait_for 15 both_proc

echo "live: shell log"
errs=$(journalctl --user --since "$since" 2>/dev/null | grep omarchy-shell | grep -E "atlas-hud|Hud\.qml" | grep -iE "error|warn|undefined|not a function" | head -5)
eq "no HUD errors or warnings in the shell log" "" "$errs"
finish
