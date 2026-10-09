// A.T.L.A.S Live HUD
//
// An animated JARVIS-style layer drawn over the A.T.L.A.S wallpaper. It sits on
// the Bottom layer (above the wallpaper, below every window), takes no input so
// desktop clicks still reach the background, and is registered to the
// artwork's own pixel grid: everything below is placed in 00-atlas.png's
// 1672x941 coordinates and scaled exactly the way the wallpaper is cropped, so
// the rings, pad and traces land on the painted ones at any resolution.
//
// Nothing animates unless the Atlas wallpaper is the current background, and
// the whole scene freezes when the screensaver takes over, a window is fullscreen, the
// power profile is low-power, or ~/.local/state/atlas-hud/paused exists
// (toggle.sh flips it). Motion runs on a shared 30 fps clock to keep the laptop cool.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris

Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string home: Quickshell.env("HOME")
  readonly property string pluginDir: home + "/.config/omarchy/plugins/com.plancher-labs.atlas-hud"

  // Artwork registration, measured from the image itself.
  readonly property string artName: "00-atlas.png"
  readonly property real artW: 1672
  readonly property real artH: 941
  readonly property real coreX: 836
  readonly property real coreY: 440
  readonly property real padX: 836
  readonly property real padY: 790
  readonly property real floorY: 735

  // Palette follows the active A.T.L.A.S Protocol (atlas-protocol writes
  // ~/.local/state/atlas-protocol/hud as "name accent ice deep"). Blue = Standby.
  property color cyan: "#35c4ff"
  property color ice: "#a8ecff"
  property color deep: "#1478e6"
  property string protocol: "standby"
  // Canvases paint their colors once into a texture, so they repaint on this.
  signal hudPaletteChanged()

  FileView {
    path: root.home + "/.local/state/atlas-protocol/hud"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.readProtocol(text())
    onLoadFailed: root.readProtocol("standby #35c4ff #a8ecff #1478e6")
  }

  function readProtocol(content) {
    var f = String(content || "").trim().split(/\s+/)
    var hex = /^#[0-9a-fA-F]{6}$/
    if (f.length < 4 || !hex.test(f[1]) || !hex.test(f[2]) || !hex.test(f[3])) return
    protocol = /^[a-z-]+$/.test(f[0]) ? f[0] : "standby"
    cyan = f[1]; ice = f[2]; deep = f[3]
    hudPaletteChanged()
  }
  readonly property string hudFont: "JetBrainsMono Nerd Font"

  property bool artActive: false
  property bool pausedByUser: false
  property bool powerSaver: false
  // The thermal guard writes its state the instant it switches the power profile, and this watch
  // fires on that write. Without it the scene keeps animating until the next telemetry line, up to
  // 2 s later. powerSaver stays in the freeze condition as the backstop: it also covers the profile
  // being set to quiet by hand, and it clears a stale "engaged" left behind by a killed guard.
  property bool thermalEngaged: false
  // Mirrors Omarchy's idle service: same timeout, same inhibitors, and only
  // when a screensaver will actually replace the HUD. With stay-awake on or
  // the screensaver disabled, idling alone never freezes the scene.
  property int screensaverSeconds: 150
  property bool screensaverRuns: true
  readonly property bool userIdle: idleMonitor.isIdle && screensaverRuns
  readonly property bool animate: artActive && !pausedByUser && !powerSaver && !thermalEngaged && !userIdle

  FileView {
    path: root.home + "/.local/state/atlas-thermal-guard/state.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.readThermalState(text())
    onLoadFailed: root.thermalEngaged = false
  }

  function readThermalState(content) {
    try {
      var parsed = JSON.parse(String(content || ""))
      thermalEngaged = !!(parsed && parsed.engaged)
    } catch (e) {
      thermalEngaged = false
    }
  }

  // Boot sequence progress, 0 -> 1 each time the HUD comes up.
  property real boot: 0

  // ── Wordmark animator ──────────────────────────────────────────────────
  // The painted "A.T.L.A.S" lettering is animated by drawing a pixel-exact
  // copy of its box back over itself and running a shader on that copy. The
  // mode arrives through stats.sh (from ~/.local/state/atlas-hud/wordmark),
  // so atlas-wordmark switches effects live without a shell restart.
  property string wordmarkMode: "off"
  readonly property var wordmarkIds: ({ "off": 0, "power-on": 1, "sweep": 2, "glitch": 3, "reactive": 4, "holo": 5 })
  readonly property int wordmarkId: wordmarkIds[wordmarkMode] !== undefined ? wordmarkIds[wordmarkMode] : 0
  // Input pressure for the reactive mode: energy is the slow envelope, pulse
  // the per-keystroke spike. Both decay on the shared clock.
  property real wmEnergy: 0
  property real wmPulse: 0

  // ── Vibe: music-reactive HUD ───────────────────────────────────────────
  // In the Vibe protocol, atlas-beat (cava on the speakers' monitor, never the
  // mic) streams 32 frequency levels, loudness, beats and drops. The spectrum
  // ring is always on; drops add a lettering glitch (and atlas-beat flashes the
  // window borders). `atlas-vibe calm` turns it off: Vibe colors only.
  property string vibeMode: "mix"
  readonly property bool musicOn: protocol === "vibe" && vibeMode !== "calm"
  property var mBands: []

  // Voice ring (`atlas-vibe voice on`): `atlas-beat --mic` streams 24 levels from
  // the default mic, with the room's steady background already subtracted.
  property bool voiceSwitch: false
  readonly property bool voiceOn: protocol === "vibe" && voiceSwitch
  property var vBands: []
  property real vLevel: 0
  function vband(i) { var a = vBands; return a.length > i ? a[i] : 0 }
  onVoiceOnChanged: if (!voiceOn) { vBands = []; vLevel = 0 }

  // Now Playing panel switch (`atlas-vibe nowplaying on|off`), any protocol.
  property bool nowPlayingOn: true

  // ── Now Playing (Spotify) ──────────────────────────────────────────────
  // The Spotify MPRIS player, if one is running. The panel shows only while it plays.
  readonly property var spotify: {
    var ps = Mpris.players.values
    for (var i = 0; i < ps.length; i++) {
      var p = ps[i]
      if (String(p.identity).toLowerCase().indexOf("spotify") >= 0 || String(p.dbusName).toLowerCase().indexOf("spotify") >= 0) return p
    }
    return null
  }
  readonly property bool spotifyPlaying: !!spotify && spotify.isPlaying && String(spotify.trackTitle || "") !== ""
  function clockTime(sec) {
    sec = Math.max(0, Math.floor(sec || 0))
    var m = Math.floor(sec / 60), s = sec % 60
    return m + ":" + (s < 10 ? "0" : "") + s
  }
  // MPRIS position has no change signal; nudge it once a second while visible.
  Timer {
    interval: 1000; repeat: true
    running: root.spotifyPlaying && root.nowPlayingOn && root.artActive
    onTriggered: if (root.spotify) root.spotify.positionChanged()
  }
  property real mLevel: 0
  property real mBeat: 0
  property real mDrop: 0
  readonly property int effectiveWordmark: musicOn ? (mDrop > 0.35 ? 3 : 4) : wordmarkId
  function band(i) { var a = mBands; return a.length > i ? a[i] : 0 }
  onMusicOnChanged: if (!musicOn) { mBands = []; mLevel = 0; mBeat = 0; mDrop = 0 }

  FileView {
    path: root.home + "/.local/state/atlas-protocol/vibe-mode"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.vibeMode = String(text()).trim() === "calm" ? "calm" : "mix"
    onLoadFailed: root.vibeMode = "mix"
  }

  FileView {
    path: root.home + "/.local/state/atlas-protocol/vibe-voice"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.voiceSwitch = String(text()).trim() === "on"
    onLoadFailed: root.voiceSwitch = false
  }

  FileView {
    path: root.home + "/.local/state/atlas-hud/nowplaying"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.nowPlayingOn = String(text()).trim() !== "off"
    onLoadFailed: root.nowPlayingOn = true
  }

  Process {
    id: micProc
    running: root.voiceOn && root.animate
    command: [root.home + "/.local/bin/atlas-beat", "--mic"]
    stdout: SplitParser {
      onRead: function(line) {
        var e
        try { e = JSON.parse(line) } catch (err) { return }
        root.vBands = e.v || []
        root.vLevel = e.l || 0
      }
    }
    onRunningChanged: if (!running) { root.vBands = []; root.vLevel = 0 }
  }

  Process {
    id: beatProc
    running: root.musicOn && root.animate
    command: [root.home + "/.local/bin/atlas-beat"]
    stdout: SplitParser {
      onRead: function(line) {
        var e
        try { e = JSON.parse(line) } catch (err) { return }
        root.mBands = e.b || []
        root.mLevel = e.l || 0
        root.wmEnergy = Math.min(1, Math.max(root.wmEnergy, root.mLevel * 1.8))
        if (e.beat) { root.mBeat = 1; root.wmPulse = 1 }
        if (e.drop) root.mDrop = 1
      }
    }
    onRunningChanged: if (!running) { root.mBands = []; root.mLevel = 0 }
  }

  // Telemetry
  property real cpu: 0
  property real mem: 0
  property real temp: 0
  property int battery: -1
  property string batteryState: ""
  property real netDown: 0
  property real netUp: 0
  property real uptimeSec: 0
  property var prevCpu: null
  property var prevNet: null

  function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

  // ── 30 fps clock ─────────────────────────────────────────────────────────
  // Every looping motion is a pure function of time on one shared 33 ms tick, so the scene
  // redraws at most 30 times a second (it used ~60, with the compositor re-blending the whole
  // screen each frame). Each screen advances its own clock only while it is live.
  readonly property int frameMs: 33
  property int tick: 0
  function phase(ms, period, offset) {
    var p = ((ms - (offset || 0)) % period + period) % period
    return p / period
  }
  function wave(ms, period, lo, hi) { return lo + (hi - lo) * (0.5 - 0.5 * Math.cos(2 * Math.PI * phase(ms, period))) }
  function inQuad(x) { return x * x }
  function outQuad(x) { return 1 - (1 - x) * (1 - x) }
  function outCubic(x) { return 1 - Math.pow(1 - x, 3) }
  function inOutQuad(x) { return x < 0.5 ? 2 * x * x : 1 - Math.pow(-2 * x + 2, 2) / 2 }
  function inOutSine(x) { return -(Math.cos(Math.PI * x) - 1) / 2 }
  // Deterministic "random" per index, so drifting dots need no per-frame state.
  function rnd(i, k) { var x = Math.sin(i * 127.1 + k * 311.7) * 43758.5453; return x - Math.floor(x) }
  function stage(from, to) { return Math.max(0, Math.min(1, (boot - from) / (to - from))) }

  function formatRate(bps) {
    if (bps >= 1048576) return (bps / 1048576).toFixed(1) + " MB/s"
    if (bps >= 1024) return Math.round(bps / 1024) + " KB/s"
    return Math.round(bps) + " B/s"
  }

  function formatUptime(s) {
    var d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60)
    return (d > 0 ? d + "D " : "") + h + "H " + (m < 10 ? "0" : "") + m + "M"
  }

  function ingest(line) {
    var f = String(line).trim().split(" ")
    if (f.length < 16) return
    var total = Number(f[0]), idle = Number(f[1])
    if (prevCpu && total > prevCpu.total)
      cpu = Math.max(0, Math.min(1, 1 - (idle - prevCpu.idle) / (total - prevCpu.total)))
    prevCpu = { total: total, idle: idle }
    if (Number(f[2]) > 0) mem = 1 - Number(f[3]) / Number(f[2])
    // Package temperature spikes for a second or two under turbo; smooth it
    // so the gauge tracks the trend instead of flashing red on every burst.
    var t = Number(f[4]) / 1000
    temp = temp > 0 ? temp * 0.7 + t * 0.3 : t
    battery = Number(f[5])
    batteryState = String(f[6]).replace(/_/g, " ").toUpperCase()
    var now = Date.now(), rx = Number(f[7]), tx = Number(f[8])
    if (prevNet) {
      var secs = (now - prevNet.t) / 1000
      if (secs > 0) {
        netDown = Math.max(0, (rx - prevNet.rx) / secs)
        netUp = Math.max(0, (tx - prevNet.tx) / secs)
      }
    }
    prevNet = { rx: rx, tx: tx, t: now }
    uptimeSec = Number(f[9])
    powerSaver = f[10] === "low-power" || f[10] === "quiet"
    pausedByUser = f[11] === "1"
    if (Number(f[12]) > 0) screensaverSeconds = Number(f[12])
    screensaverRuns = f[13] === "1"
    wordmarkMode = f[14]
    // Background name is last because a filename may contain spaces.
    var bgName = f.slice(15).join(" ")
    artActive = bgName === artName || /^00-atlas-protocol-[a-z-]+\.png$/.test(bgName)
  }

  onArtActiveChanged: if (artActive) { boot = 0; bootAnim.restart() }

  NumberAnimation {
    id: bootAnim
    target: root
    property: "boot"
    from: 0
    to: 1
    duration: 2600
    easing.type: Easing.OutQuad
  }

  Process {
    id: statsProc
    command: [root.pluginDir + "/stats.sh"]
    stdout: SplitParser { onRead: function(line) { root.ingest(line) } }
  }

  Timer {
    interval: 2000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: if (!statsProc.running) statsProc.running = true
  }

  // Reactive mode only: the evdev daemon built for A.T.L.A.S Canvas. It buckets
  // every keycode to a class (letter/number/modifier/...) at the moment it reads
  // it and discards the code, so what is typed can never be reconstructed. It
  // runs only while this mode is on and the scene is live.
  Process {
    id: pulseProc
    running: root.wordmarkId === 4 && root.animate
    command: [root.home + "/Work/atlas-canvas/bin/atlas-pulse"]
    stdout: SplitParser {
      onRead: function(line) {
        var e
        try { e = JSON.parse(line) } catch (err) { return }
        if (e.e === "key") {
          root.wmPulse = 1
          root.wmEnergy = Math.min(1, root.wmEnergy + (e.c === "enter" ? 0.45 : 0.22))
        } else if (e.e === "click") {
          root.wmPulse = 1
          root.wmEnergy = Math.min(1, root.wmEnergy + 0.3)
        } else if (e.e === "scroll") {
          root.wmEnergy = Math.min(1, root.wmEnergy + 0.08)
        }
      }
    }
  }

  IdleMonitor {
    id: idleMonitor
    timeout: root.screensaverSeconds
    respectInhibitors: true
  }

  SystemClock {
    id: clock
    precision: SystemClock.Seconds
  }

  // Typewriter status line under the subtitle.
  readonly property var messages: [
    "ALL SYSTEMS NOMINAL",
    "CPU LOAD " + Math.round(cpu * 100) + "%  ·  MEMORY " + Math.round(mem * 100) + "%",
    "CORE TEMPERATURE " + Math.round(temp) + "°C  ·  WITHIN LIMITS",
    battery >= 0 ? "POWER CELL " + battery + "%  ·  " + batteryState : "EXTERNAL POWER",
    "NETWORK LINK ACTIVE  ·  ↓ " + formatRate(netDown),
    "WELCOME BACK, STEVE"
  ]
  property int messageIndex: 0
  property int typed: 0
  property int holdTicks: 0
  property bool erasing: false
  readonly property string currentMessage: messages[messageIndex] || ""

  Timer {
    interval: root.frameMs
    repeat: true
    running: root.animate
    onTriggered: {
      root.tick++
      if (root.wmPulse > 0) root.wmPulse = Math.max(0, root.wmPulse - 0.055)
      if (root.wmEnergy > 0) root.wmEnergy = Math.max(0, root.wmEnergy - 0.018)
      if (root.mBeat > 0) root.mBeat = Math.max(0, root.mBeat - 0.09)
      if (root.mDrop > 0) root.mDrop = Math.max(0, root.mDrop - 0.03)
      if (root.tick % 2) return  // typewriter steps every other frame (~15/s)
      var msg = root.currentMessage
      if (root.erasing) {
        root.typed = Math.max(0, root.typed - 3)
        if (root.typed === 0) {
          root.erasing = false
          root.messageIndex = (root.messageIndex + 1) % root.messages.length
        }
      } else if (root.typed < msg.length) {
        root.typed++
      } else if (++root.holdTicks > 60) {
        root.holdTicks = 0
        root.erasing = true
      }
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData

      screen: modelData
      visible: root.artActive
      anchors { top: true; bottom: true; left: true; right: true }
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      mask: Region {}
      WlrLayershell.namespace: "atlas-hud"
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      readonly property var hyprMonitor: Hyprland.monitorFor(modelData)
      readonly property bool fullscreenHere: hyprMonitor && hyprMonitor.activeWorkspace
        ? hyprMonitor.activeWorkspace.hasFullscreen : false
      // Keeps animating behind windows (Steve's choice, 2026-09-16); only a
      // fullscreen window, which hides the desktop completely, freezes it.
      readonly property bool live: root.animate && !fullscreenHere
      // This screen's animation time in ms; stands still while the screen is frozen.
      property real t: 0
      // Extra ring rotation earned by loud music (Vibe); added to the rings' clock.
      property real boost: 0
      Connections {
        target: root
        function onTickChanged() {
          if (!panel.live) return
          panel.t += root.frameMs
          if (root.musicOn) panel.boost += root.frameMs * root.mLevel * 2.5
        }
      }

      // Same cover-fit as the wallpaper's PreserveAspectCrop.
      readonly property real fit: Math.max(width / root.artW, height / root.artH)

      Item {
        id: art
        width: root.artW
        height: root.artH
        x: (panel.width - root.artW * panel.fit) / 2
        y: (panel.height - root.artH * panel.fit) / 2
        transformOrigin: Item.TopLeft
        scale: panel.fit

        // First child, so the HUD's own glow and sweeps pass over the animated
        // lettering exactly as they pass over the painted wallpaper today.
        Wordmark { t: panel.t }

        // ── Core glow ───────────────────────────────────────────────
        // Everything round is painted once into a texture and then only
        // transformed, which is nearly free for the GPU. Stroking the vector
        // shapes live redrew hundreds of overlapping full-size quads a frame.
        Item {
          x: root.coreX - 360; y: root.coreY - 360
          width: 720; height: 720
          opacity: root.stage(0.0, 0.4)

          GlowDisc {
            anchors.fill: parent
            opacity: Math.min(1, root.wave(panel.t, 5600, 0.4, 0.85) + root.mLevel * 0.6 + root.vLevel * 0.5)
            stops: [[0.0, root.alpha(root.cyan, 0.20)], [0.5, root.alpha(root.deep, 0.07)], [1.0, root.alpha(root.deep, 0.0)]]
          }
        }

        // ── Radar sweep ─────────────────────────────────────────────
        Item {
          x: root.coreX - 222; y: root.coreY - 222
          width: 444; height: 444
          opacity: root.stage(0.25, 0.55)

          Canvas {
            id: radar
            anchors.fill: parent
            Connections { target: root; function onHudPaletteChanged() { radar.requestPaint() } }
            onPaint: {
              var ctx = getContext("2d")
              ctx.reset()
              var g = ctx.createConicalGradient(222, 222, 0)
              g.addColorStop(0.0, root.alpha(root.cyan, 0.24))
              g.addColorStop(0.14, root.alpha(root.cyan, 0.0))
              g.addColorStop(1.0, root.alpha(root.cyan, 0.0))
              ctx.fillStyle = g
              ctx.beginPath()
              ctx.arc(222, 222, 222, 0, Math.PI * 2, false)
              ctx.fill()
              var l = ctx.createLinearGradient(222, 0, 444, 0)
              l.addColorStop(0.0, root.alpha(root.ice, 0.0))
              l.addColorStop(1.0, root.alpha(root.ice, 0.7))
              ctx.fillStyle = l
              ctx.fillRect(222, 221, 222, 2)
            }
            rotation: 360 * root.phase(panel.t, 6500)
          }
        }

        // ── Ring system ─────────────────────────────────────────────
        Item {
          anchors.fill: parent
          opacity: root.stage(0.05, 0.45)
          transform: Scale { origin.x: root.coreX; origin.y: root.coreY; xScale: 1 + root.mBeat * 0.035; yScale: 1 + root.mBeat * 0.035 }

          // Heavy outer arcs, slow clockwise.
          Ring {
            ms: panel.t + panel.boost
            radius: 276; lineWidth: 3.5; period: 48000
            strokeColor: root.alpha(root.cyan, 0.8)
            segments: [[200, 52], [292, 38], [20, 52], [112, 38]]
          }
          // Fine tick ring, counter-clockwise.
          Ring {
            ms: panel.t + panel.boost
            radius: 238; lineWidth: 2; period: -70000
            strokeColor: root.alpha(root.ice, 0.35)
            segments: root.ticks(36, 4)
          }
          // Outer graduation ring, very slow.
          Ring {
            ms: panel.t + panel.boost
            radius: 304; lineWidth: 7; period: 140000
            strokeColor: root.alpha(root.deep, 0.45)
            segments: root.ticks(72, 1.1)
          }
          // Thin halo.
          Ring {
            ms: panel.t + panel.boost
            radius: 322; lineWidth: 1; period: 0
            strokeColor: root.alpha(root.cyan, 0.22)
            segments: [[0, 360]]
          }
          // Fast scanner pair.
          Ring {
            ms: panel.t + panel.boost
            radius: 222; lineWidth: 3; period: 7000
            strokeColor: root.alpha(root.ice, 0.95)
            segments: [[0, 16], [180, 16]]
          }
        }
        // ── Vibe voice ring ─────────────────────────────────────────
        // 48 short bars in the gap between the fine tick ring (r 238) and the
        // heavy arcs (r 276): bass at the top, treble at the bottom, mirrored,
        // like the music ring outside. White tips set it apart from the music.
        // At rest it is a faint ring of ticks: the mic is listening.
        Item {
          x: root.coreX; y: root.coreY
          opacity: root.voiceOn ? root.stage(0.1, 0.5) : 0
          visible: opacity > 0
          Behavior on opacity { NumberAnimation { duration: 600 } }
          Repeater {
            model: 48
            Rectangle {
              required property int index
              readonly property real v: Math.pow(root.vband(index < 24 ? index : 47 - index), 0.7)
              width: 4; height: 3 + v * 27
              x: -width / 2; y: -(245 + height)
              radius: 2
              antialiasing: true
              color: v > 0.55 ? "#ffffff" : root.ice
              opacity: 0.3 + v * 0.7
              transform: Rotation { origin.x: 2; origin.y: 245 + height; angle: (index + 0.5) * 360 / 48 }
            }
          }
        }

        // ── Vibe spectrum ring ──────────────────────────────────────
        // 64 bars just outside the halo: bass at the top, treble at the bottom,
        // mirrored left/right. Plain rectangles, so a frame is only geometry.
        Item {
          x: root.coreX; y: root.coreY
          opacity: root.musicOn ? root.stage(0.1, 0.5) : 0
          visible: opacity > 0
          Behavior on opacity { NumberAnimation { duration: 600 } }
          Repeater {
            model: 64
            Rectangle {
              required property int index
              // pow(…, 0.6) lifts the mid levels so everyday music fills the ring, not just loud peaks.
              readonly property real v: Math.pow(root.band(index < 32 ? index : 63 - index), 0.6)
              width: 6; height: 8 + v * 96
              x: -width / 2; y: -(334 + height)
              radius: 2
              antialiasing: true
              color: v > 0.7 ? root.ice : root.cyan
              opacity: 0.35 + v * 0.65
              transform: Rotation { origin.x: 2.5; origin.y: 334 + height; angle: (index + 0.5) * 360 / 64 }
            }
          }
        }

        // ── Holo-pad and beam ───────────────────────────────────────
        Item {
          anchors.fill: parent
          opacity: root.stage(0.1, 0.45)

          // Beam from pad up to the ring.
          Rectangle {
            id: beam
            x: root.padX - 1.5; y: 700
            width: 3; height: root.padY - 700
            opacity: root.wave(panel.t, 2800, 0.35, 0.9)
            gradient: Gradient {
              GradientStop { position: 0.0; color: root.alpha(root.ice, 0.0) }
              GradientStop { position: 1.0; color: root.alpha(root.ice, 0.9) }
            }
          }

          // Energy packet riding the beam.
          Glint {
            id: beamGlint
            // 1.5 s rise up the beam, then 0.9 s rest.
            readonly property real p: root.phase(panel.t, 2400) * 2400
            x: root.padX
            y: p < 1500 ? root.padY + (698 - root.padY) * root.inQuad(p / 1500) : root.padY
            opacity: p < 250 ? p / 250 : p < 1200 ? 1 : p < 1500 ? 1 - (p - 1200) / 300 : 0
          }

          // Core of the pad.
          Item {
            x: root.padX - 70; y: root.padY - 70
            width: 140; height: 140
            transform: Scale { origin.x: 70; origin.y: 70; yScale: 0.2 }
            GlowDisc {
              id: padCore
              anchors.fill: parent
              opacity: Math.min(1, root.wave(panel.t, 2800, 0.5, 1.0) + root.mBeat * 0.5)
              scale: 1 + root.mBeat * 0.35
              stops: [[0.0, root.alpha(root.ice, 0.9)], [0.35, root.alpha(root.cyan, 0.45)], [1.0, root.alpha(root.cyan, 0.0)]]
            }
          }

          // Expanding ripples, staggered on a shared 5.4s period.
          Repeater {
            model: 3
            Item {
              id: ripple
              required property int index
              x: root.padX - 240; y: root.padY - 30
              width: 480; height: 60
              // 3 s expansion, staggered 1.2 s apart on a shared 5.4 s period.
              readonly property real p: root.phase(panel.t, 5400, ripple.index * 1200) * 5400
              scale: p < 3000 ? 0.15 + 1.15 * root.outCubic(p / 3000) : 0.15
              opacity: p < 3000 ? 0.9 * (1 - root.inQuad(p / 3000)) : 0
              Canvas {
                id: rippleCanvas
                anchors.fill: parent
                Connections { target: root; function onHudPaletteChanged() { rippleCanvas.requestPaint() } }
                onPaint: {
                  var ctx = getContext("2d")
                  ctx.reset()
                  ctx.strokeStyle = root.ice
                  ctx.lineWidth = 2.5
                  ctx.beginPath()
                  ctx.ellipse(4, 4, 472, 52)
                  ctx.stroke()
                }
              }
            }
          }
        }

        // ── Circuit and floor pulses ────────────────────────────────
        Item {
          anchors.fill: parent
          opacity: root.stage(0.4, 0.7)

          Repeater {
            model: [
              // [x1, y1, x2, y2, travelMs, delayMs, periodMs]
              [163, 81, 496, 78, 1600, 0, 5200],
              [1509, 81, 1176, 78, 1600, 2600, 5200],
              [92, 158, 92, 470, 1900, 1200, 6100],
              [1580, 158, 1580, 470, 1900, 4200, 6100],
              [268, 416, 380, 416, 700, 600, 3900],
              [1403, 416, 1292, 416, 700, 2500, 3900],
              [100, 538, 226, 538, 800, 1800, 4700],
              [1572, 538, 1446, 538, 800, 300, 4700],
              [0, root.floorY, 560, root.floorY, 2300, 0, 4400],
              [1672, root.floorY, 1112, root.floorY, 2300, 900, 4400],
              [0, root.floorY, 560, root.floorY, 2300, 2200, 4400],
              [1672, root.floorY, 1112, root.floorY, 2300, 3300, 4400]
            ]
            Glint {
              id: pulse
              required property var modelData
              // [x1, y1, x2, y2, travelMs, delayMs, periodMs]
              readonly property real period: Math.max(modelData[6], modelData[4] + modelData[5])
              readonly property real q: (root.phase(panel.t, period) * period - modelData[5]) / modelData[4]
              readonly property real t: q >= 0 && q <= 1 ? root.inOutQuad(q) : 0
              x: modelData[0] + (modelData[2] - modelData[0]) * t
              y: modelData[1] + (modelData[3] - modelData[1]) * t
              opacity: q < 0 || q > 1 ? 0 : q < 0.15 ? q / 0.15 : q < 0.8 ? 1 : (1 - q) / 0.2
              trail: true
              trailAngle: Math.atan2(modelData[3] - modelData[1], modelData[2] - modelData[0]) * 180 / Math.PI

            }
          }

          // Node beacons at trace junctions.
          Repeater {
            model: [[45, 81], [45, 148], [1626, 81], [1626, 148], [230, 538], [1441, 538],
                    [335, 278], [1338, 278], [496, 77], [1176, 77], [268, 416], [1403, 416]]
            Rectangle {
              id: node
              required property var modelData
              required property int index
              x: modelData[0] - 11; y: modelData[1] - 11
              width: 22; height: 22; radius: 11
              color: root.alpha(root.cyan, 0.12)
              border.color: root.ice
              border.width: 1.5
              // Blink: 0.35 s up, 0.9 s fade, staggered on a 3.2 s period.
              readonly property real p: root.phase(panel.t, 3200, node.index * 530 % 3200) * 3200
              opacity: p < 350 ? 0.9 * p / 350 : p < 1250 ? 0.9 * (1 - root.outQuad((p - 350) / 900)) : 0
            }
          }

          // Light sweeps across the chevron groups.
          Repeater {
            model: [[334, 32, 78, 24, 0], [1258, 32, 78, 24, 1800], [218, 438, 80, 24, 900], [1374, 438, 80, 24, 2700]]
            Item {
              id: chevron
              required property var modelData
              x: modelData[0]; y: modelData[1]
              width: modelData[2]; height: modelData[3]
              clip: true
              readonly property real p: root.phase(panel.t, 4400, modelData[4]) * 4400
              Rectangle {
                id: shine
                x: chevron.p < 800 ? -24 + (chevron.width + 28) * root.inOutQuad(chevron.p / 800) : -24
                y: 0
                width: 20; height: chevron.height
                gradient: Gradient {
                  orientation: Gradient.Horizontal
                  GradientStop { position: 0.0; color: "transparent" }
                  GradientStop { position: 0.5; color: root.alpha(root.ice, 0.75) }
                  GradientStop { position: 1.0; color: "transparent" }
                }
              }
            }
          }
        }

        // ── Drifting particles ──────────────────────────────────────
        // 18 motes rising off the floor and 6 quicker ones off the pad, all computed from the
        // clock (Qt's particle system would redraw at 60 fps on its own).
        Item {
          anchors.fill: parent
          opacity: root.stage(0.3, 0.8)
          Repeater {
            model: 24
            Rectangle {
              id: mote
              required property int index
              readonly property bool fromPad: index >= 18
              readonly property real life: fromPad ? 2800 + root.rnd(index, 3) * 1400 : 5000 + root.rnd(index, 3) * 4000
              readonly property real p: root.phase(panel.t, life, root.rnd(index, 4) * life)
              readonly property real speed: fromPad ? 45 + root.rnd(index, 5) * 25 : 12 + root.rnd(index, 5) * 12
              readonly property real size: (fromPad ? 4 : 5) + root.rnd(index, 6) * 4
              readonly property real baseX: fromPad ? root.padX - 110 + root.rnd(index, 1) * 220 : 260 + root.rnd(index, 1) * 1152
              readonly property real baseY: fromPad ? root.padY : root.floorY + root.rnd(index, 2) * 150
              width: size * (1 - 0.6 * p)
              height: width
              radius: width / 2
              x: baseX + Math.sin(p * 6.28 + index) * 8 - width / 2
              y: baseY - speed * life / 1000 * p
              color: root.alpha(root.cyan, 0.75)
              opacity: 0.6 * (p < 0.15 ? p / 0.15 : p > 0.7 ? (1 - p) / 0.3 : 1)
            }
          }
        }

        // ── Scanline ────────────────────────────────────────────────
        Item {
          id: scan
          // 7.5 s sweep down, 5 s rest.
          readonly property real p: root.phase(panel.t, 12500) * 12500
          x: 0
          y: p < 7500 ? -80 + (root.artH + 80) * root.inOutSine(p / 7500) : -80
          width: root.artW; height: 80
          opacity: root.stage(0.6, 0.9)
          Rectangle {
            anchors.fill: parent
            gradient: Gradient {
              GradientStop { position: 0.0; color: "transparent" }
              GradientStop { position: 0.97; color: root.alpha(root.cyan, 0.06) }
              GradientStop { position: 1.0; color: root.alpha(root.ice, 0.22) }
            }
          }
        }

        // ── Title shimmer ───────────────────────────────────────────
        // The original static-wordmark gloss. Any wordmark mode replaces it:
        // its clipped gradient shows a faint rectangle that the shader's own
        // border fade does not have.
        Item {
          x: 420; y: 368
          width: 830; height: 125
          clip: true
          visible: root.effectiveWordmark === 0
          Rectangle {
            id: shimmer
            // 3 s wait, 1.7 s sweep, 5.5 s rest.
            readonly property real p: root.phase(panel.t, 10200) * 10200
            x: p >= 3000 && p < 4700 ? -160 + 1080 * root.inOutQuad((p - 3000) / 1700) : -160
            y: -70
            width: 70; height: 265
            rotation: 18
            gradient: Gradient {
              orientation: Gradient.Horizontal
              GradientStop { position: 0.0; color: "transparent" }
              GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.16) }
              GradientStop { position: 1.0; color: "transparent" }
            }
          }
        }

        // ── Status line ─────────────────────────────────────────────
        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          y: 566
          spacing: 6
          opacity: root.stage(0.75, 1.0)
          HudText {
            text: "›  " + root.currentMessage.substring(0, root.typed)
            color: root.cyan
            size: 17
            spacing: 3
          }
          HudText {
            id: cursorGlyph
            text: "▍"
            color: root.ice
            size: 17
            readonly property real p: root.phase(panel.t, 900) * 900
            opacity: p < 450 ? 1 - p / 450 : (p - 450) / 450
          }
        }

        // ── Telemetry: left ─────────────────────────────────────────
        Column {
          x: 70; y: 588
          spacing: 12
          opacity: root.stage(0.55, 0.9)

          HudText { text: "▌SYSTEM TELEMETRY"; color: root.ice; size: 15; spacing: 3; bold: true }
          Gauge { label: "CPU "; value: root.cpu; readout: Math.round(root.cpu * 100) + "%" }
          Gauge { label: "MEM "; value: root.mem; readout: Math.round(root.mem * 100) + "%" }
          Gauge {
            label: "TEMP"
            value: Math.max(0, Math.min(1, (root.temp - 30) / 70))
            readout: Math.round(root.temp) + "°C"
            hot: root.temp >= 85
          }
        }

        // ── Now Playing: left, under telemetry (only while Spotify plays) ──
        Column {
          id: nowPlaying
          x: 70; y: 712
          spacing: 10
          opacity: root.spotifyPlaying && root.nowPlayingOn ? root.stage(0.55, 0.9) : 0
          visible: opacity > 0.01
          Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }

          HudText { text: "▌NOW PLAYING  ·  SPOTIFY"; color: root.ice; size: 15; spacing: 3; bold: true }

          Row {
            spacing: 14
            // Album art in a HUD frame with corner brackets.
            Item {
              width: 78; height: 78
              Rectangle { anchors.fill: parent; color: root.alpha(root.cyan, 0.10); border.color: root.alpha(root.cyan, 0.55); border.width: 1 }
              Image {
                anchors.fill: parent; anchors.margins: 3
                source: root.spotify ? (root.spotify.trackArtUrl || "") : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true; cache: true; smooth: true
                sourceSize.width: 160; sourceSize.height: 160
              }
              Repeater {
                model: 4
                Item {
                  required property int index
                  x: index % 2 ? parent.width - 10 : -2; y: index < 2 ? -2 : parent.height - 10
                  width: 12; height: 12
                  Rectangle { x: index % 2 ? 10 : 0; width: 2; height: 12; color: root.ice }
                  Rectangle { y: index < 2 ? 0 : 10; width: 12; height: 2; color: root.ice }
                }
              }
            }
            Column {
              spacing: 5
              anchors.verticalCenter: parent.verticalCenter
              HudText {
                width: 260; elide: Text.ElideRight
                text: root.spotify ? String(root.spotify.trackTitle || "").toUpperCase() : ""
                color: root.ice; size: 18; spacing: 2; bold: true
              }
              HudText {
                width: 260; elide: Text.ElideRight
                text: root.spotify ? String(root.spotify.trackArtist || "") : ""
                color: root.cyan; size: 14; spacing: 2
              }
              HudText {
                width: 260; elide: Text.ElideRight
                text: root.spotify ? String(root.spotify.trackAlbum || "") : ""
                color: root.alpha(root.ice, 0.6); size: 12; spacing: 2
              }
            }
          }

          // Progress, built like the telemetry gauges.
          Gauge {
            label: "TIME"
            value: root.spotify && root.spotify.length > 0 ? Math.min(1, root.spotify.position / root.spotify.length) : 0
            readout: root.spotify ? root.clockTime(root.spotify.position) + " / " + root.clockTime(root.spotify.length) : ""
          }

          // Live mini equalizer in Vibe (fed by atlas-beat); hidden elsewhere.
          Row {
            visible: root.musicOn && root.mBands.length > 0
            spacing: 3
            Repeater {
              model: 24
              Rectangle {
                required property int index
                readonly property real v: Math.pow(root.band(index), 0.6)
                width: 9; height: 22
                color: "transparent"
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2 + parent.v * 20; color: parent.v > 0.7 ? root.ice : root.cyan; opacity: 0.4 + parent.v * 0.6 }
              }
            }
          }
        }

        // ── Telemetry: right ────────────────────────────────────────
        Column {
          x: 1602 - width; y: 540
          spacing: 6
          opacity: root.stage(0.55, 0.9)

          HudText {
            x: parent.width - width
            text: Qt.formatTime(clock.date, "HH:mm:ss")
            color: root.ice
            size: 46
            spacing: 4
          }
          HudText {
            x: parent.width - width
            text: Qt.formatDate(clock.date, "dddd  d MMM yyyy").toUpperCase()
            color: root.cyan
            size: 14
            spacing: 3
          }
          Item { width: 1; height: 6 }
          HudText {
            x: parent.width - width
            text: root.battery >= 0 ? "PWR  " + root.battery + "%  " + root.batteryState : "PWR  AC"
            color: root.alpha(root.ice, 0.85); size: 14; spacing: 2
          }
          HudText {
            x: parent.width - width
            text: "NET  ↓ " + root.formatRate(root.netDown) + "   ↑ " + root.formatRate(root.netUp)
            color: root.alpha(root.ice, 0.85); size: 14; spacing: 2
          }
          HudText {
            x: parent.width - width
            text: "UPTIME  " + root.formatUptime(root.uptimeSec)
            color: root.alpha(root.ice, 0.85); size: 14; spacing: 2
          }
        }
      }
    }
  }

  // Evenly spaced tick segments for a ring: count ticks, each sweep degrees.
  function ticks(count, sweep) {
    var out = []
    for (var i = 0; i < count; i++) out.push([i * 360 / count, sweep])
    return out
  }

  component Ring: Canvas {
    id: ring
    property real radius: 100
    property real lineWidth: 2
    property color strokeColor: root.cyan
    onStrokeColorChanged: requestPaint()
    property var segments: [[0, 360]]
    // Milliseconds per revolution; negative spins counter-clockwise, 0 is still.
    property int period: 20000
    // Animation time from the screen's 30 fps clock.
    property real ms: 0
    rotation: period === 0 ? 0 : (period < 0 ? -360 : 360) * root.phase(ms, Math.abs(period))

    width: Math.ceil((radius + lineWidth) * 2 + 4)
    height: width
    x: root.coreX - width / 2
    y: root.coreY - height / 2

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.strokeStyle = ring.strokeColor
      ctx.lineWidth = ring.lineWidth
      ctx.lineCap = "butt"
      var c = ring.width / 2
      for (var i = 0; i < ring.segments.length; i++) {
        var seg = ring.segments[i]
        ctx.beginPath()
        ctx.arc(c, c, ring.radius, seg[0] * Math.PI / 180, (seg[0] + seg[1]) * Math.PI / 180, false)
        ctx.stroke()
      }
    }

  }

  // A pixel-exact copy of the wallpaper's title box (830x125 at 420,368) drawn
  // back over its own pixels, with a shader running on the copy. Because the
  // copy includes the dark plate the letters sit on, effects can dim and
  // displace the glyphs, not just add light over them; wordmark.frag masks
  // every effect to the lettering and fades it at the crop border so no
  // rectangle can show against the wallpaper behind it.
  component Wordmark: Item {
    id: wm
    required property real t

    x: 420
    y: 368
    width: 830
    height: 125
    visible: root.effectiveWordmark > 0

    Image {
      id: plate
      source: "file://" + root.pluginDir + (root.protocol === "standby" ? "/wordmark.png" : "/wordmark-" + root.protocol + ".png")
      sourceSize.width: 830
      sourceSize.height: 125
      visible: false
      smooth: true
    }

    ShaderEffect {
      anchors.fill: parent
      // Absolute path: Qt.resolvedUrl() does not resolve shaders under
      // Quickshell, and a miss silently draws nothing.
      fragmentShader: "file://" + root.pluginDir + "/build/wordmark.frag.qsb"
      property variant src: plate
      property real uTime: wm.t / 1000
      property real uMode: root.effectiveWordmark
      property real uEnergy: root.wmEnergy
      property real uPulse: root.wmPulse
      property real uBoot: root.boot
      property color uIce: root.ice
      property color uCyan: root.cyan
    }
  }

  // Soft radial glow painted once; stops are [position, color] pairs.
  component GlowDisc: Canvas {
    id: disc
    property var stops: []
    onStopsChanged: requestPaint()
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var r = Math.min(width, height) / 2
      var g = ctx.createRadialGradient(width / 2, height / 2, 0, width / 2, height / 2, r)
      for (var i = 0; i < disc.stops.length; i++) g.addColorStop(disc.stops[i][0], disc.stops[i][1])
      ctx.fillStyle = g
      ctx.fillRect(0, 0, width, height)
    }
  }

  // A bright point with a soft halo, optionally dragging a short trail.
  component Glint: Item {
    id: glint
    property bool trail: false
    property real trailAngle: 0
    width: 0; height: 0

    Rectangle {
      visible: glint.trail
      x: -70; y: -1
      width: 70; height: 2
      transformOrigin: Item.Right
      rotation: glint.trailAngle
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: 1.0; color: root.alpha(root.ice, 0.8) }
      }
    }
    Rectangle {
      x: -9; y: -9; width: 18; height: 18; radius: 9
      color: root.alpha(root.cyan, 0.28)
    }
    Rectangle {
      x: -3; y: -3; width: 6; height: 6; radius: 3
      color: "#ffffff"
    }
  }

  component HudText: Text {
    property real size: 14
    property real spacing: 1
    property bool bold: false
    font.family: root.hudFont
    font.pixelSize: size
    font.letterSpacing: spacing
    font.bold: bold
    renderType: Text.QtRendering
  }

  component Gauge: Row {
    id: gauge
    property string label: ""
    property real value: 0
    property string readout: ""
    property bool hot: false
    spacing: 12

    HudText { text: gauge.label; color: root.alpha(root.ice, 0.85); size: 14; spacing: 2; anchors.verticalCenter: parent.verticalCenter }
    Item {
      width: 200; height: 8
      anchors.verticalCenter: parent.verticalCenter
      Rectangle { anchors.fill: parent; color: root.alpha(root.cyan, 0.12); border.color: root.alpha(root.cyan, 0.35); border.width: 1 }
      Rectangle {
        x: 1; y: 1
        height: parent.height - 2
        width: Math.max(0, (parent.width - 2) * gauge.value)
        color: gauge.hot ? "#ff6b6b" : root.cyan
      }
      Repeater {
        model: 9
        Rectangle { required property int index; x: (index + 1) * 20; y: 0; width: 1; height: 8; color: root.alpha("#000000", 0.45) }
      }
    }
    HudText { text: gauge.readout; color: root.ice; size: 14; spacing: 1; anchors.verticalCenter: parent.verticalCenter }
  }
}
