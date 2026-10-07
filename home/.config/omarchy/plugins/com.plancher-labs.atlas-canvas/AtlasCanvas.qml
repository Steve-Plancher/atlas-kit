// A.T.L.A.S Canvas
//
// The live field itself. This component is deliberately free of any preview or
// layer-shell specifics so it can be dropped straight into the shell plugin at
// phase 3 without edits -- it owns the shader, the uniform state, the wavefront
// pool and the adaptive clock, and nothing else.
//
// Two things keep it cheap, and both are visible here rather than buried in the
// shader:
//
//   * renderScale -- the shader runs into a texture at a fraction of native size
//     and is upscaled. The look is low-frequency glow, which survives it; at
//     2560x1440, 0.6 is ~2.8x less fragment work for no visible loss.
//
//   * the adaptive clock -- the field idles at idleFps and only ramps to
//     activeFps for burstMs after real input. Typing is bursty, so the average
//     lands far below the peak, and motion now correlates with what you did,
//     which reads as *more* reactive rather than less.

import QtQuick
import Quickshell

Item {
    id: root

    readonly property string home: Quickshell.env("HOME")

    // ── tuning ───────────────────────────────────────────────────────────────
    // The internal buffer's vertical resolution, stated outright rather than as
    // a multiplier. Qt reports devicePixelRatio as 2.0 on this 1.25-scaled
    // screen, so any multiplier-based scheme silently over- or under-shoots the
    // panel; an explicit target cannot.
    //
    //   1440  native for this panel
    //   2160  true 4K, filtered down to the panel -- the sharpest option, and
    //         about 2.25x the fragment work of native
    //
    // 0 falls back to Qt's own ratio.
    property int targetHeight: 2160

    readonly property real dpr: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1.0
    readonly property real pixelScale: (targetHeight > 0 && height > 0)
        ? targetHeight / height : dpr

    // Kept so the preview's [ ] keys still work; it nudges the target.
    property real renderScale: 1.0
    onRenderScaleChanged: if (height > 0) targetHeight = Math.round(height * dpr * renderScale)
    property int  idleFps:     10
    property int  activeFps:   60
    property int  burstMs:     1500

    // Set false to freeze everything (covered, locked, fullscreen, too hot).
    property bool animate: true

    // ── artwork ──────────────────────────────────────────────────────────────
    // The painted A.T.L.A.S design is the base of the scene, not a fallback:
    // the shader samples it, parallaxes it and lights it. Tracking the live
    // wallpaper link means a background change follows through to the canvas.
    property string artPath: home + "/.config/omarchy/backgrounds/hackerman/00-atlas.png"

    Image {
        id: art
        source: "file://" + root.artPath
        visible: false
        smooth: true
        mipmap: true
        cache: true
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 1672
        sourceSize.height: 941
    }

    // ── palette ──────────────────────────────────────────────────────────────
    // Blue only for phase 0-2; the other four arrive at phase 4.
    property color deepColor:   "#04121f"
    property color traceColor:  "#35c4ff"
    property color accentColor: "#a8ecff"
    property color coreColor:   "#4fd4ff"

    // ── live drive ───────────────────────────────────────────────────────────
    property real energy:    0.0   // sustained typing, 0..1
    property real corePulse: 0.0   // instantaneous hit, decays fast
    property real audio:     0.0   // 0..1, phase 2+
    property real load:      0.0   // cpu 0..1

    // The surface's own geometry in Hyprland's logical space. atlas-pulse emits
    // ABSOLUTE pointer coordinates, and each surface maps them into itself --
    // so a monitor move, a rescale or a second screen can never offset it.
    property rect screenRect: Qt.rect(0, 0, 0, 0)

    property real mouseX:    0.5
    property real mouseY:    0.5
    property real clickAge:  -1.0  // <0 = no click in flight
    property real scrollAcc: 0.0

    // ── internals ────────────────────────────────────────────────────────────
    readonly property int waveCount: 8
    property var  _waves: []
    property int  _waveNext: 0
    property real _time: 0
    property real _activeUntil: 0
    readonly property bool _bursting: Date.now() < _activeUntil

    // Exposed so the preview can show what the clock is actually doing.
    readonly property int currentFps: _bursting ? activeFps : idleFps

    readonly property real waveLife: 2.2   // must match WAVE_LIFE in field.frag

    Component.onCompleted: {
        var w = []
        for (var i = 0; i < waveCount; ++i) w.push({ age: -1, strength: 0, width: 0, kind: 0 })
        _waves = w
    }

    // ── input API ────────────────────────────────────────────────────────────
    // Everything the daemon can report funnels through these. Keeping them as
    // plain functions means the preview's synthetic input and the real evdev
    // feed drive the exact same code path.

    // kind: 0 letter, 1 enter, 2 backspace, 3 modifier, 4 click
    function pushWave(kind, strength, width) {
        var w = _waves
        w[_waveNext] = {
            age: 0,
            strength: strength === undefined ? 1.0 : strength,
            width: width === undefined ? 0.055 : width,
            kind: kind
        }
        _waveNext = (_waveNext + 1) % waveCount
        _waves = w
        _wake()
    }

    function onKey(cls) {
        switch (cls) {
        case "enter":     pushWave(1, 1.35, 0.075); corePulse = 1.0;  energy += 0.22; break
        case "backspace": pushWave(2, 0.85, 0.050); corePulse = 0.55; energy += 0.10; break
        case "modifier":  pushWave(3, 0.45, 0.038); corePulse = 0.28; energy += 0.05; break
        case "number":    pushWave(0, 0.90, 0.050); corePulse = 0.62; energy += 0.13; break
        case "space":     pushWave(0, 1.00, 0.062); corePulse = 0.70; energy += 0.15; break
        default:          pushWave(0, 0.85, 0.048); corePulse = 0.60; energy += 0.13; break
        }
        energy = Math.min(energy, 1.0)
        _wake()
    }

    function onClick() {
        clickAge = 0
        pushWave(4, 0.7, 0.045)
        corePulse = Math.max(corePulse, 0.5)
        _wake()
    }

    // Absolute logical px in, local 0..1 out.
    function onMoveAbs(ax, ay) {
        var r = screenRect
        if (r.width <= 0 || r.height <= 0) return
        mouseX = (ax - r.x) / r.width
        mouseY = (ay - r.y) / r.height
        _wake()
    }

    // Already-local 0..1 (the preview's own window input).
    function onMove(nx, ny) { mouseX = nx; mouseY = ny; _wake() }

    function onScroll(dy) { scrollAcc += dy * 0.06; _wake() }

    function _wake() { _activeUntil = Date.now() + burstMs }

    // ── clock ────────────────────────────────────────────────────────────────
    Timer {
        id: clock
        running: root.animate
        repeat: true
        interval: Math.round(1000 / root.currentFps)
        onTriggered: root._step(interval / 1000)
    }

    function _step(dt) {
        _time += dt

        // decays, all frame-rate independent
        energy    *= Math.pow(0.22, dt)   // ~1.5s to fall away
        corePulse *= Math.pow(0.02, dt)   // ~250ms, snappy
        scrollAcc *= Math.pow(0.05, dt)
        audio     *= Math.pow(0.35, dt)

        if (energy    < 0.002) energy = 0
        if (corePulse < 0.002) corePulse = 0
        if (Math.abs(scrollAcc) < 0.001) scrollAcc = 0

        if (clickAge >= 0) {
            clickAge += dt
            if (clickAge > 1.0) clickAge = -1.0
        }

        var live = false
        var w = _waves
        for (var i = 0; i < w.length; ++i) {
            if (w[i].age >= 0) {
                w[i].age += dt
                if (w[i].age > waveLife) w[i].age = -1
                else live = true
            }
        }
        _waves = w

        // Stay awake while anything is still in flight, so a wavefront never
        // stutters to a halt at the idle rate halfway across the screen.
        if (live || energy > 0.01 || clickAge >= 0) _activeUntil = Date.now() + 120
    }

    function _wv(i) {
        var w = _waves
        if (!w || i >= w.length || w[i].age < 0) return Qt.vector4d(-1, 0, 0, 0)
        return Qt.vector4d(w[i].age, w[i].strength, w[i].width, w[i].kind)
    }

    // Quickshell loads QML through its own path handling, so Qt.resolvedUrl() does
    // NOT resolve against this file's directory the way it does under plain qml --
    // it silently misses and Qt falls back to its blackhole shader, drawing nothing.
    // The shader is addressed absolutely instead.
    property string shaderDir: Quickshell.env("HOME") + "/.config/omarchy/plugins/com.plancher-labs.atlas-canvas/build/"

    // ── the field ────────────────────────────────────────────────────────────
    ShaderEffect {
        id: field
        anchors.fill: parent

        fragmentShader: "file://" + root.shaderDir + "field.frag.qsb"

        // Render small, draw big. This is the single biggest saving here.
        layer.enabled: Math.abs(root.pixelScale - 1.0) > 0.001
        layer.smooth: true
        layer.textureSize: Qt.size(Math.max(16, Math.round(width  * root.pixelScale)),
                                   Math.max(16, Math.round(height * root.pixelScale)))

        // the artwork texture; name matches `uniform sampler2D uArt`
        property variant uArt: art

        // uniforms -- names must match the std140 block in field.frag exactly
        property real uTime:      root._time
        property real uAspect:    height > 0 ? width / height : 1.0
        property real uScale:     root.pixelScale
        property real uEnergy:    root.energy
        property real uCorePulse: root.corePulse
        property real uAudio:     root.audio
        property real uLoad:      root.load

        property color uDeep:   root.deepColor
        property color uTrace:  root.traceColor
        property color uAccent: root.accentColor
        property color uCore:   root.coreColor

        property vector4d uMouse: Qt.vector4d(root.mouseX, root.mouseY,
                                              root.clickAge, root.scrollAcc)

        property vector4d uWave0: root._wv(0)
        property vector4d uWave1: root._wv(1)
        property vector4d uWave2: root._wv(2)
        property vector4d uWave3: root._wv(3)
        property vector4d uWave4: root._wv(4)
        property vector4d uWave5: root._wv(5)
        property vector4d uWave6: root._wv(6)
        property vector4d uWave7: root._wv(7)
    }
}
