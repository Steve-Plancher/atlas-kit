# A.T.L.A.S OS changelog

## v1.2.4: Cursor + bar order after the update (2026-10-08)

### 🐞 Fixes (after the Oct 8 update + reboot)
- **Invisible mouse cursor fixed.** On the new Hyprland/mesa build, forced *software* cursors drew nothing on
  this Intel GPU. `hypr/looknfeel.lua` now uses hardware cursors (`no_hardware_cursors = false`). If ghost
  cursors ever appear on dock displays, try `2` (auto) rather than `true`.
- **Bar order stays put.** The dock re-sorts the whole bar whenever it saves and forced workspaces before the
  window title. Its preferred order now includes the window title: menu · window title · workspaces.

### ✨ New
- `tools/dock-order-fix.py`, run by `install.sh` after the third-party plugins download.

### 📦 Apps added
- None.

### 🔒 Not included
Personal files, passwords, logins, browser data, SSH keys. Secret scan passed.

## v1.2.3: Omarchy update compatibility (Qt 6.12) (2026-10-08)

### 🐞 Fixes: compatibility with the Oct 8 Omarchy update (omarchy-dev r6807, Quickshell 0.3.2, Qt 6.12)
- **Invisible bar text/icons fixed.** Qt 6.12 adds a built-in `Color` type that hides Omarchy's palette, so
  widgets silently lost their colors. Every A.T.L.A.S and third-party widget now uses `Commons.Color`
  (Omarchy's official fix, upstream commit b83d3df): the custom bar, lock screen, notifications, speaker
  panel, agents, monitor, glass, and the dock, GitHub, activity monitor and other plugins.
- **Dock fixed** (updated to upstream v1.8.32 plus the color fix).
- **HUD:** renamed an internal signal that now clashes with Qt 6.12's built-in `paletteChanged`, so protocol
  switches keep repainting the rings.

### ✨ New
- `tools/qt612-color-fix.py`: idempotent fixer. `install.sh` runs it on all plugins after downloading the
  third-party ones, so a fresh machine gets working widgets too.

### 🔧 Changed
- World clock widget renamed by Omarchy: `omacom.elsewhen` → `omarchy.elsewhen` (settings kept).
- Bar left order restored: menu · window title · workspaces.

### 📦 Apps
- None added by the kit. Omarchy itself now ships Monologue, Hype, Disktree and Papers.

### 🔒 Not included
Personal files, passwords, logins, browser data, SSH keys. Secret scan passed.

## v1.2.2: Public kit, simpler install (2026-10-08)

### 🔧 Changed
- **The kit is now public:** installing no longer needs a GitHub login. Step 4.1 is just
  `git clone https://github.com/Steve-Plancher/atlas-kit.git ~/atlas-kit` (the GitHub sign-in steps were removed).
- Install-steps illustration updated: step 2 is now "Download the kit".
- `atlas-version --check` checks for new releases without needing a GitHub login.

### 📦 Apps added
- None.

### 🔒 Not included
Personal files, passwords, logins, browser data, SSH keys. Full-history review before going public: no secrets found.

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

