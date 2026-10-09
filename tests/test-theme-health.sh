#!/bin/bash
# Theme health, two lints:
#   1. static:  no QML in the core shell or the user plugins uses the unqualified `Color` palette
#               (Qt 6.12 shadows it, so colors silently become undefined: white widgets, black menu).
#   2. runtime: after a clean shell restart, opening the Omarchy menu and the Protocols panel, the
#      shell log has no palette errors.
# Pass --no-restart to skip the restart (then only the static lint runs).
cd "$(dirname "$0")" && source ./lib.sh
SCAN=../tools/qt612-color-scan.py
echo "theme health"
out=$(python3 -I "$SCAN" /usr/share/omarchy/shell); ok "static: core shell palette refs qualified" test $? -eq 0
[[ $out == *"lines: 0"* ]] || echo "    $(tail -1 <<<"$out") in /usr/share/omarchy/shell"
# Everything user-owned that the shell loads: plugins, custom bar modules (bar.layout "type":"qml").
out=$(python3 -I "$SCAN" "$HOME/.config/omarchy/plugins" "$HOME/.config/omarchy/bar"); ok "static: user plugins + bar modules palette refs qualified" test $? -eq 0
[[ $out == *"lines: 0"* ]] || { echo "    $(tail -1 <<<"$out") in ~/.config/omarchy/{plugins,bar}"; grep -v "^files:" <<<"$out" | sed 's/^/    /'; }

if [[ ${1:-} != --no-restart ]]; then
  since=$(date '+%Y-%m-%d %H:%M:%S')
  omarchy restart shell >/dev/null 2>&1; sleep 10
  omarchy menu summon >/dev/null 2>&1; sleep 2; omarchy menu close >/dev/null 2>&1; sleep 1
  ipc=(quickshell ipc -p /usr/share/omarchy/shell call com.plancher-labs.atlas-protocol)
  "${ipc[@]}" open >/dev/null 2>&1; sleep 2; "${ipc[@]}" close >/dev/null 2>&1; sleep 1
  log=$(journalctl --user --since "$since" 2>/dev/null | grep omarchy-shell)
  pal=$(grep -cE "of undefined|Unable to assign \[undefined\] to QColor|QQuickColor|of null" <<<"$log")
  eq "runtime: palette errors in the shell log after restart + menu + Protocols panel" 0 "$pal"
  [[ $pal -eq 0 ]] || grep -E "of undefined|Unable to assign \[undefined\] to QColor|QQuickColor|of null" <<<"$log" \
    | sed -E 's/^.*omarchy-shell\[[0-9]+\]: *//; s/\[[0-9]+:-?[0-9]+\]//' | sort | uniq -c | sort -rn | head -12 | sed 's/^/    /'
fi
finish
