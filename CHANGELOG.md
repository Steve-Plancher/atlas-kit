# A.T.L.A.S OS changelog

## v1.3.1: Taskbar autohide fix, bar order, dock off (2026-10-09)

### 🐞 Fixes
- **Taskbar autohide works again.** The hover strip that brings the bar back when you move the mouse to the screen edge now anchors correctly (`steve.bar/Bar.qml`), so the bar reappears at the bottom.

### 🔧 Changed
- **Bar order is now Menu · Workspaces · Window title** (Steve's choice, 2026-10-09).
- **Removed `tools/dock-order-fix.py`** and its step in `install.sh`. The dock's built-in order already matches the new layout, so the patch is no longer needed.
- **Dock stays off** in `dock-settings.json`.
- Checked against Omarchy `omarchy-dev` r6818 (Oct 9 update): all lint and tests pass, including the runtime palette check.

### 📦 Apps added
- None.

### 🔒 Not included
- Personal files, keys and tokens (secret scan passed). Machine-specific hardware files stay in `machine-specific/`.

## v1.3.0: Protocols panel, voice ring and switches (2026-10-09)

### ✨ New features
- **Protocols panel on the bar.** Click the protocol icon to open a panel attached to the bar:
  - 2×2 tiles for Standard, Deadlock, Focus and Vibe, each with a stripe in its own color. The active one is
    outlined and marked with a dot.
  - Clicking a tile shows "Switching…", then the whole panel recolors without closing.
  - Real on/off switches for **Music Ring**, **Voice Ring** and **Now Playing** (no more ✓ marks).
  - Follows changes made by voice or from a terminal straight away.
  - Keyboard: Tab or the arrow keys to move, Space/Enter to press, Esc to close.
- **Voice Ring (Vibe).** A 48-bar ice-colored ring just outside the music ring reacts to your voice through the
  default microphone (`atlas-beat --mic`). It learns the room's background noise, so fans and hum stay dark.
  Off until you switch it on, and it only runs in Vibe.
- **Three Vibe switches from the terminal:** `atlas-vibe music|voice|nowplaying on|off|toggle`; `atlas-vibe`
  alone shows all three. The old `atlas-vibe on` / `calm` still work.
- **`atlas-protocol list --json`** (feeds the panel's tiles) and **`atlas-protocol resolve "<said>"`** (prints which
  protocol a spoken phrase means, changes nothing). It now also understands "let's go into vibe code mode".
- **Health check:** `tests/run.sh` runs shellcheck, pyflakes, Qt 6 qmllint, the Qt 6.12 palette scan, and unit
  tests for `atlas-vibe`, `atlas-protocol`, `atlas-beat` and the panel. `tests/run.sh --live` also restarts the bar,
  opens every bar panel, presses real keys in the Protocols panel and recolors the desktop through every protocol,
  then puts everything back.
- `tools/qt612-color-scan.py`: read-only check for QML that still uses the unqualified `Color` palette.

### 🔧 Changed
- The protocol button in the bar is now just the protocol's icon (hover for its name). The Protocols entries in
  the Omarchy menu are gone; the panel replaces them.
- Standard's description is now "Everyday blue", so it fits on its tile.
- **Wallpaper workaround removed.** `steve.background` is gone and Omarchy's own wallpaper plugin is back, now that
  Omarchy fixed it (omarchy-dev r6815). A machine that installed v1.2.5 keeps an unused
  `~/.config/omarchy/plugins/steve.background` folder; it's safe to delete.
- Needs an Omarchy build that includes the Qt 6.12 fix (omarchy-dev r6815 or newer, Oct 8 2026). Older builds
  turn the screen black when a menu opens.

### 🐞 Fixes
- **Screen went black when opening the protocol menu, and many bar widgets were white.** Cause: the Qt 6.12
  `Color` clash inside Omarchy's own core (r6807), fixed by updating to r6815. Fixed in the kit on top of that:
  - The A.T.L.A.S bell button used the clashing `Color`, so its unread dot now shows in the theme color again.
  - The notification panel's background was fixed dark blue; it now follows the protocol colors.
  - Palette errors in the shell log went from 1,705 to 0, and all 17 bar panels were opened and checked.
- An empty or corrupt protocol state file now falls back to Standard instead of breaking the protocol button.

### 📦 Apps added
- `shellcheck` and `python-pyflakes` (used by the health check).

### 🔒 Not included
Personal files, passwords, logins, browser data, SSH keys. Secret scan passed.

## v1.2.5: Wallpaper follows theme switches again (2026-10-08)

### 🐞 Fixes
- **Theme / protocol switches update the wallpaper again.** After the Oct 8 Omarchy update, Omarchy's own
  wallpaper plugin crashed on every theme switch (Qt 6.12 `Color` clash), leaving the old protocol's art behind
  the new colors (e.g. amber Focus wallpaper under a blue Standard HUD). It also made double-click wallpaper
  picks behave oddly.
- Temporary fix until Omarchy ships its fixed build: the wallpaper plugin is cloned as `steve.background`
  with the `Commons.Color` fix applied. It will be removed again once Omarchy's update includes the fix.

### 📦 Apps added
- None.

### 🔒 Not included
Personal files, passwords, logins, browser data, SSH keys. Secret scan passed.

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

