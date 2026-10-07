#!/bin/bash
# Pause or resume the A.T.L.A.S HUD animation (it freezes in place while paused).
flag=$HOME/.local/state/atlas-hud/paused
mkdir -p "${flag%/*}"
if [[ -e $flag ]]; then rm -f "$flag"; echo resumed; else touch "$flag"; echo paused; fi
