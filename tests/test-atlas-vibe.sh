#!/bin/bash
# atlas-vibe: the three HUD switches (music ring, voice ring, Now Playing panel).
cd "$(dirname "$0")" && source ./lib.sh
VIBE=${ATLAS_VIBE:-$HOME/.local/bin/atlas-vibe}
H=$(sandbox_home); trap 'rm -rf "$H"' EXIT
v() { HOME=$H "$VIBE" "$@"; }
act() { v "$@" >/dev/null 2>&1; }
st() { cat "$H/$1" 2>/dev/null; }
MUSIC=.local/state/atlas-protocol/vibe-mode VOICE=.local/state/atlas-protocol/vibe-voice NP=.local/state/atlas-hud/nowplaying

echo "atlas-vibe"
eq "defaults: music on, voice off, now playing on" $'music on\nvoice off\nnowplaying on' "$(v)"
ok "is music on (default)" v is music on
ok "is voice off (default)" v is voice off
ok "is nowplaying on (default)" v is nowplaying on

act music off; eq "music off writes calm (HUD reads vibe-mode)" calm "$(st $MUSIC)"
ok "is music off" v is music off
fails "is music on while off" v is music on
act music on; eq "music on writes mix" mix "$(st $MUSIC)"
act music toggle; ok "music toggle on→off" v is music off
act music toggle; ok "music toggle off→on" v is music on

act voice on; eq "voice on writes on" on "$(st $VOICE)"
ok "is voice on" v is voice on
act voice toggle; ok "voice toggle on→off" v is voice off
act mic on; ok "mic is an alias for voice" v is voice on
act voice off

act nowplaying off; eq "nowplaying off writes off" off "$(st $NP)"
ok "is nowplaying off" v is nowplaying off
act nowplaying toggle; ok "nowplaying toggle off→on" v is nowplaying on
act spotify off; ok "spotify is an alias for nowplaying" v is nowplaying off
act nowplaying on

# Older commands from v1.1.0 keep working.
act calm; ok "legacy: calm = music off" v is music off
ok "legacy: is calm" v is calm
act on; ok "legacy: on = music on" v is music on
ok "legacy: is on" v is on
eq "legacy: switches stay independent" $'music on\nvoice off\nnowplaying on' "$(v)"

fails "unknown switch is an error" v sparkles on
fails "unknown value is an error" v voice loud
fails "is without a value is an error" v is voice
finish
