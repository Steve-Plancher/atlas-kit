# A.T.L.A.S OS changelog

## v1.2.1: Version tracking (2026-10-08)

### ✨ New features
- **A.T.L.A.S OS version tracking:** every change now ships as a numbered release.
  - `VERSION` file and a full `CHANGELOG.md` in the repo
  - `atlas-version` shows the version a machine runs; `atlas-version --check` compares it with the latest GitHub release
  - The installer records the installed version on the new machine
  - `tools/release.sh` bumps the version, updates the changelog, runs the secret-scanning snapshot, tags and publishes the release

### 📦 Apps added
- None.

### 🔒 Not included
Personal files, passwords, logins, browser data, SSH keys. Secret scan passed.

## v1.2.0: Now Playing (Spotify) HUD (2026-10-08)

### ✨ New features
- **Now Playing HUD panel (Spotify):** fades in under *System Telemetry* whenever Spotify is playing, styled to match.
  - Cover art in a bracketed HUD frame
  - Title, artist and album
  - Live **TIME** gauge (elapsed / total)
  - Mini equalizer that dances with the music in the **Vibe** protocol
  - Fades out when the music pauses or Spotify closes; works in every protocol

### 📦 Apps added
- None. Uses Quickshell's built-in media (MPRIS) support.

### 🔒 Not included
Personal files, passwords, logins, browser data, SSH keys. Secret scan passed.

## v1.1.0: Voice-ready protocols & music-reactive Vibe (2026-10-08)

### ✨ New features
- **Voice-ready protocol names:** Standard (blue), Deadlock (crimson), Focus (amber), Vibe (violet).
  `atlas-protocol` understands whole sentences, e.g. `atlas-protocol "Atlas, initiate Deadlock Protocol"`
  (filler words like *initiate / engage / activate / please* are ignored; old names and colors still work).
- **Music-reactive Vibe:** 64-bar spectrum ring around the HUD core, rings swell and spin with the beat,
  floor pad flashes on kicks; big drops glitch the lettering and flash the window borders.
  New tools: `atlas-beat` (music analysis) and `atlas-vibe on|calm`. Bar menu rows: *Vibe · Music reactive* / *Vibe · Calm*.
- **`tools/snapshot.sh`:** refreshes the kit from the machine and refuses to finish if anything looks like a secret.

### 🔧 Changed
- Protocols change **colors only** (theme, wallpaper art, HUD, borders, cursor). Earlier behaviors (mute, Do Not Disturb, glass, lock timer, app launching) were removed.
- Ghost Protocol removed.
- Speaker panel replaced with a copy (`steve.audio`) without the microphone level meter.
- The kit always ships the Standard (blue) look, whichever protocol was active when it was snapshotted.

### 🐞 Fixes
- Music no longer goes thin/glitchy when the speaker icon is clicked (the mic meter forced the headset into call mode).
- Headset no longer drags the volume down: its automatic volume-key presses are ignored (`hypr/input.lua`).
- Music analyzer runs with a relaxed audio buffer, so it can't cause Spotify dropouts.

### 📦 Apps added
- `cava`: audio analyzer used by Vibe's music reaction.

### 🗑️ Removed
- EasyEffects (and `calf`), the audio-preset bar widget and its 17 menu entries. Apps play straight to the headset.

### 🔒 Not included
Personal files, passwords, logins, browser data, SSH keys. Secret scan passed.

## v1.0.0: First A.T.L.A.S kit (2026-10-07)

First A.T.L.A.S kit: Steve's A.T.L.A.S desktop for a fresh Omarchy install.

### Features
- A.T.L.A.S blue theme (Hackerman overlay), A.T.L.A.S wallpapers and the live animated HUD
- Color protocols (first version), switchable from the bar and the desktop wallpaper picker
- Custom bar layout and widgets: glass (see-through windows), snap and title bars, lock screen, notifications, agents
- Atlas-Cyan animated cursor, window look and keybindings, terminal configs, Voxtype voice typing config
- `install.sh`: backs up, copies settings, installs apps, fetches bar plugins, applies the theme
- Step-by-step illustrated install guide (README)

### Apps added on top of Omarchy
See `apps.txt` / `apps-aur.txt`, installed automatically by `install.sh`.

### Not included
Personal files, passwords, logins, browser data, SSH keys; laptop-only parts are in `machine-specific/`.

