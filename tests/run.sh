#!/bin/bash
# A.T.L.A.S protocol, HUD switch and theme checks: lint, then unit tests. --live also restarts the
# shell for a runtime palette lint, opens every bar widget panel, drives the Protocols panel with real
# key presses, and recolors the real desktop through every protocol (about 2 minutes), putting
# everything back.
cd "$(dirname "$0")" || exit 1
B=$HOME/.local/bin
rc=0
step() { echo "── $1"; shift; if "$@"; then echo "   ok"; else echo "   FAILED"; rc=1; fi; }

step "shellcheck" shellcheck -x "$B/atlas-vibe" "$B/atlas-protocol" \
  "$HOME/.local/share/atlas/bin/omarchy-theme-bg-set" "$HOME/.local/share/atlas/bin/omarchy-theme-bg-switcher" \
  lib.sh test-atlas-vibe.sh test-atlas-protocol.sh test-theme-health.sh panel-audit.sh panel-keys-check.sh live-check.sh run.sh
step "pyflakes" python3 -m pyflakes "$B/atlas-beat" test-atlas-beat.py test-protocol-panel.py ../tools/qt612-color-scan.py ../tools/qt612-color-fix.py
step "luac (atlas_protocol.lua)" luac -p "$HOME/.config/hypr/atlas_protocol.lua"
# Qt 6's qmllint (the one on PATH is Qt 5 and checks nothing). Only syntax-level errors fail;
# the HUD's 14 known style warnings (unqualified access in inline components) are reported, not fatal.
# shellcheck disable=SC2329  # called through step
hudlint() { /usr/lib/qt6/bin/qmllint "$HOME/.config/omarchy/plugins/com.plancher-labs.atlas-hud/Hud.qml" 2>&1 | grep -E "\[syntax\]|^Error" && return 1; return 0; }
step "qmllint (Hud.qml syntax)" hudlint
step "atlas-vibe" ./test-atlas-vibe.sh
step "atlas-protocol" ./test-atlas-protocol.sh
step "protocol panel" python3 -I test-protocol-panel.py
step "atlas-beat (music + voice analyzers)" python3 -I test-atlas-beat.py
if [[ ${1:-} == --live ]]; then
  step "theme health: static + runtime palette lint (restarts the shell)" ./test-theme-health.sh
  step "panel audit: every bar widget panel themed" ./panel-audit.sh
  step "protocol panel keys (real key presses)" ./panel-keys-check.sh
  step "live desktop check" ./live-check.sh
else
  step "theme health: static palette lint" ./test-theme-health.sh --no-restart
fi
exit $rc
