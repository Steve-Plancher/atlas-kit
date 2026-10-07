// A.T.L.A.S Canvas -- shell surface.
//
// Thin wrapper: one opaque fullscreen surface per monitor, holding the same
// AtlasCanvas that the preview window runs. All the behaviour lives in
// AtlasCanvas.qml; this file only decides where it is drawn and when it stops.
//
// It sits on the Bottom layer -- above the wallpaper, below every window --
// and paints opaquely, so it covers the wallpaper rather than replacing it.
// That is deliberate: if this plugin ever fails to load, the real wallpaper is
// still underneath and the desktop looks normal instead of black.
//
// It freezes whenever nothing can see it: a fullscreen window on that monitor,
// the lock screen, the screensaver, or the low-power profile.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string home: Quickshell.env("HOME")
  readonly property string pluginDir: home + "/.config/omarchy/plugins/com.plancher-labs.atlas-canvas"

  // Mirrors the wallpaper plugin's own reasoning about when nothing is visible.
  readonly property var lockService: shell && shell.services ? shell.firstPartyServiceFor("omarchy.lock") : null
  readonly property var idleService: shell && shell.services ? shell.firstPartyServiceFor("omarchy.idle") : null
  readonly property var batteryService: shell && shell.services ? shell.firstPartyServiceFor("omarchy.battery") : null

  readonly property bool lockActive: lockService ? lockService.locked : false
  readonly property bool screensaverActive: idleService ? idleService.screensaverWindowCount > 0 : false
  readonly property bool powerSaverActive: batteryService ? batteryService.powerSaverOnBattery : false
  readonly property bool sessionObscured: lockActive || screensaverActive

  // User pause, same convention as the HUD: a file in ~/.local/state.
  property bool pausedByUser: false

  FileView {
    path: root.home + "/.local/state/atlas-canvas/paused"
    watchChanges: true
    onLoaded: root.pausedByUser = true
    onLoadFailed: root.pausedByUser = false
    onFileChanged: reload()
  }

  // ── the input bus ────────────────────────────────────────────────────────
  // One daemon for every monitor; each surface reacts to the same stream.
  Process {
    id: pulse
    running: !root.sessionObscured && !root.pausedByUser
    command: [root.home + "/Work/atlas-canvas/bin/atlas-pulse", "run"]
    stdout: SplitParser { onRead: function (line) { root.ingest(line) } }
  }

  property var surfaces: []

  function ingest(line) {
    line = String(line).trim()
    if (!line || line[0] !== "{") return
    var e
    try { e = JSON.parse(line) } catch (err) { return }

    for (var i = 0; i < surfaces.length; ++i) {
      var c = surfaces[i]
      if (!c || !c.animate) continue
      switch (e.e) {
      case "key":    c.onKey(e.c); break
      case "click":  c.onClick(); break
      case "move":   c.onMoveAbs(e.ax, e.ay); break
      case "scroll": c.onScroll(e.d); break
      }
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData

      screen: modelData
      anchors { top: true; bottom: true; left: true; right: true }
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      // Takes no input, so desktop clicks still reach the wallpaper beneath.
      mask: Region {}

      WlrLayershell.namespace: "atlas-canvas"
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      readonly property var hyprMonitor: Hyprland.monitorFor(modelData)
      readonly property bool fullscreenHere: hyprMonitor && hyprMonitor.activeWorkspace
        ? hyprMonitor.activeWorkspace.hasFullscreen : false

      AtlasCanvas {
        id: canvas
        anchors.fill: parent

        // True 4K internal buffer, filtered down to the 2560x1440 panel. The
        // earlier 0.6 multiplier was chosen for cost, but measured GPU load came
        // back at ~12% of ceiling, so the headroom was there. Drop to 1440 for
        // plain native if this proves too warm.
        targetHeight: 2160

        // This surface's own place in the logical layout, so absolute pointer
        // coordinates land correctly on any monitor, at any scale or position.
        screenRect: Qt.rect(panel.modelData.x, panel.modelData.y,
                            panel.modelData.width / panel.modelData.devicePixelRatio,
                            panel.modelData.height / panel.modelData.devicePixelRatio)

        animate: !root.sessionObscured
                 && !root.powerSaverActive
                 && !root.pausedByUser
                 && !panel.fullscreenHere

        Component.onCompleted: {
          var s = root.surfaces
          s.push(canvas)
          root.surfaces = s
        }
      }
    }
  }
}
