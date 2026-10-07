// A.T.L.A.S Snap preview.
//
// Runs `atlas-snap run` for as long as the shell runs. That helper watches the left mouse
// button and the dragged window, applies the snap on release, and prints one JSON line
// whenever the preview should change:
//   {"show": true, "monitor": "HDMI-A-1", "zone": "left", "x", "y", "w", "h",
//    "cx", "cy", "blocks": [{"zone", "x", "y", "w", "h"}, ...]}
//   {"show": false, "commit": true}     the window was dropped into the zone
//   {"show": false}                     the pointer left the zone
// Coordinates are logical and relative to that monitor: the same space as the overlay.
//
// Animation: the overlay layer is only mapped while needed, and a no_anim layer rule keeps
// Hyprland's own layer fade-in/out from fighting these animations. The highlight pops out from under the
// cursor, morphs between zones with a little overshoot, flashes when a window is dropped,
// and the other blocks of the layout being chosen glow faintly behind it.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string helper: Quickshell.env("HOME") + "/.local/bin/atlas-snap"
  readonly property color accent: "#35c4ff"
  readonly property color ice: "#a8ecff"

  property bool showing: false
  property string monitorName: ""
  property string zone: ""
  property rect target: Qt.rect(0, 0, 0, 0)
  property point cursor: Qt.point(0, 0)
  property var blocks: []
  property bool committed: false
  // Bumped on every message so each screen reacts even to repeated values.
  property int serial: 0

  readonly property var zoneInfo: ({
    "left": { icon: "󰕭", label: "Left half" },
    "right": { icon: "󰕬", label: "Right half" },
    "max": { icon: "󰊓", label: "Maximize" },
    "top-left": { icon: "󰕰", label: "Top-left quarter" },
    "top-right": { icon: "󰕰", label: "Top-right quarter" },
    "bottom-left": { icon: "󰕰", label: "Bottom-left quarter" },
    "bottom-right": { icon: "󰕰", label: "Bottom-right quarter" }
  })

  function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

  Process {
    id: watcher
    command: [root.helper, "run"]
    running: true
    stdout: SplitParser {
      onRead: function(line) {
        var msg
        try { msg = JSON.parse(line) } catch (e) { return }
        if (msg.show) {
          root.monitorName = msg.monitor
          root.zone = msg.zone
          root.target = Qt.rect(msg.x, msg.y, msg.w, msg.h)
          root.cursor = Qt.point(msg.cx !== undefined ? msg.cx : msg.x + msg.w / 2,
                                 msg.cy !== undefined ? msg.cy : msg.y + msg.h / 2)
          root.blocks = msg.blocks || []
          root.committed = false
          root.showing = true
        } else {
          root.committed = !!msg.commit
          root.showing = false
        }
        root.serial++
      }
    }
    onExited: restart.restart()
  }

  // Keep the watcher alive if it ever exits (for example across a Hyprland restart).
  Timer {
    id: restart
    interval: 2000
    onTriggered: watcher.running = true
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData

      screen: modelData
      // Mapped only while a zone is shown or its exit animation is still playing. A no_anim layer
      // rule (atlas_windows.lua) stops Hyprland's layer fade from fighting these animations.
      visible: mine || highlight.opacity > 0.01
      anchors { top: true; bottom: true; left: true; right: true }
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      mask: Region {}
      WlrLayershell.namespace: "atlas-snap-preview"
      WlrLayershell.layer: WlrLayer.Top
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      property bool mine: false
      property string lastZone: ""
      // Ghost blocks are rebuilt only when the *layout* changes (halves vs quarters), so moving
      // between blocks of the same layout doesn't restart their fade-in.
      property var ghostBlocks: []
      property string ghostKey: ""

      Connections {
        target: root
        function onSerialChanged() {
          var here = root.monitorName === panel.modelData.name
          if (root.showing && here) {
            var key = root.blocks.map(function(b) { return b.zone }).join(",")
            if (key !== panel.ghostKey) {
              panel.ghostKey = key
              panel.ghostBlocks = root.blocks
            }
            if (!panel.mine) highlight.appear()
            else if (panel.lastZone !== root.zone) highlight.morph()
            panel.mine = true
            panel.lastZone = root.zone
          } else if (panel.mine) {
            if (root.committed) highlight.commit()
            else highlight.vanish()
            panel.mine = false
            panel.lastZone = ""
            panel.ghostKey = ""
            panel.ghostBlocks = []
          }
        }
      }

      // ── Ghost blocks: the rest of the layout being chosen ─────────────────
      Repeater {
        model: panel.ghostBlocks
        Rectangle {
          id: ghost
          required property var modelData
          required property int index
          x: modelData.x + 4
          y: modelData.y + 4
          width: modelData.w - 8
          height: modelData.h - 8
          radius: 12
          color: root.alpha(root.accent, 0.04)
          border.color: root.alpha(root.accent, 0.3)
          border.width: 1
          opacity: 0
          scale: 0.96
          // The hovered block is drawn by the highlight itself.
          visible: modelData.zone !== root.zone
          Component.onCompleted: ghostIn.start()
          ParallelAnimation {
            id: ghostIn
            SequentialAnimation {
              PauseAnimation { duration: 60 + ghost.index * 40 }
              NumberAnimation { target: ghost; property: "opacity"; to: 1; duration: 170; easing.type: Easing.OutQuad }
            }
            SequentialAnimation {
              PauseAnimation { duration: 60 + ghost.index * 40 }
              NumberAnimation { target: ghost; property: "scale"; to: 1; duration: 240; easing.type: Easing.OutBack }
            }
          }
        }
      }

      // ── The highlight ──────────────────────────────────────────────────────
      Item {
        id: highlight
        opacity: 0
        transformOrigin: Item.Center
        property real breathe: 0

        function morphTo(duration, overshoot) {
          morphAnim.stop()
          ax.duration = duration; ay.duration = duration; aw.duration = duration; ah.duration = duration
          ax.easing.overshoot = overshoot; ay.easing.overshoot = overshoot
          aw.easing.overshoot = overshoot; ah.easing.overshoot = overshoot
          ax.to = root.target.x; ay.to = root.target.y
          aw.to = root.target.width; ah.to = root.target.height
          morphAnim.start()
        }

        // Pop out of the cursor and spring open to the zone.
        function appear() {
          exitAnim.stop(); flashAnim.stop()
          x = root.cursor.x - 28; y = root.cursor.y - 28
          width = 56; height = 56
          scale = 1
          flash.opacity = 0
          rim.border.width = 2
          appearFade.restart()
          morphTo(320, 1.1)
          labelPop.restart()
        }

        // Jump to a neighbouring block: quick, with a little bounce.
        function morph() {
          morphTo(200, 1.4)
          labelPop.restart()
          bump.restart()
        }

        function vanish() {
          morphAnim.stop()
          exitAnim.restart()
        }

        // Dropped: flash bright, then melt into the window landing underneath.
        function commit() {
          morphAnim.stop()
          flashAnim.restart()
        }

        ParallelAnimation {
          id: morphAnim
          NumberAnimation { id: ax; target: highlight; property: "x"; easing.type: Easing.OutBack }
          NumberAnimation { id: ay; target: highlight; property: "y"; easing.type: Easing.OutBack }
          NumberAnimation { id: aw; target: highlight; property: "width"; easing.type: Easing.OutBack }
          NumberAnimation { id: ah; target: highlight; property: "height"; easing.type: Easing.OutBack }
        }

        NumberAnimation { id: appearFade; target: highlight; property: "opacity"; from: 0; to: 1; duration: 120; easing.type: Easing.OutQuad }

        ParallelAnimation {
          id: exitAnim
          NumberAnimation { target: highlight; property: "opacity"; to: 0; duration: 140; easing.type: Easing.InQuad }
          NumberAnimation { target: highlight; property: "scale"; to: 0.93; duration: 140; easing.type: Easing.InQuad }
        }

        SequentialAnimation {
          id: bump
          NumberAnimation { target: highlight; property: "scale"; to: 1.02; duration: 70; easing.type: Easing.OutQuad }
          NumberAnimation { target: highlight; property: "scale"; to: 1; duration: 150; easing.type: Easing.OutQuad }
        }

        SequentialAnimation {
          id: flashAnim
          ParallelAnimation {
            NumberAnimation { target: flash; property: "opacity"; to: 1; duration: 80; easing.type: Easing.OutQuad }
            NumberAnimation { target: highlight; property: "scale"; to: 1.025; duration: 80; easing.type: Easing.OutQuad }
            NumberAnimation { target: rim; property: "border.width"; to: 4; duration: 80 }
          }
          ParallelAnimation {
            NumberAnimation { target: highlight; property: "opacity"; to: 0; duration: 280; easing.type: Easing.InCubic }
            NumberAnimation { target: highlight; property: "scale"; to: 1; duration: 280; easing.type: Easing.OutCubic }
          }
          PropertyAction { target: flash; property: "opacity"; value: 0 }
          PropertyAction { target: rim; property: "border.width"; value: 2 }
        }

        SequentialAnimation {
          running: highlight.opacity > 0
          loops: Animation.Infinite
          NumberAnimation { target: highlight; property: "breathe"; to: 4; duration: 520; easing.type: Easing.InOutSine }
          NumberAnimation { target: highlight; property: "breathe"; to: 0; duration: 520; easing.type: Easing.InOutSine }
        }

        // Glass fill.
        Rectangle {
          anchors.fill: parent
          radius: 16
          gradient: Gradient {
            GradientStop { position: 0.0; color: root.alpha(root.accent, 0.24) }
            GradientStop { position: 1.0; color: root.alpha(root.accent, 0.10) }
          }
        }

        // Drop flash.
        Rectangle {
          id: flash
          anchors.fill: parent
          radius: 16
          opacity: 0
          color: root.alpha(root.ice, 0.35)
        }

        // Rim.
        Rectangle {
          id: rim
          anchors.fill: parent
          radius: 16
          color: "transparent"
          border.color: root.alpha(root.ice, 0.9)
          border.width: 2
        }

        // Inner glow line.
        Rectangle {
          anchors.fill: parent
          anchors.margins: 6
          radius: 11
          color: "transparent"
          border.color: root.alpha(root.accent, 0.3)
          border.width: 1
        }

        // Corner brackets that breathe while a zone is held.
        Repeater {
          model: [[0, 0], [1, 0], [0, 1], [1, 1]]
          Item {
            id: bracket
            required property var modelData
            readonly property real inset: 12 + highlight.breathe
            width: 22
            height: 22
            x: modelData[0] ? highlight.width - width - inset : inset
            y: modelData[1] ? highlight.height - height - inset : inset
            visible: highlight.width > 90 && highlight.height > 90
            Rectangle {
              width: bracket.width; height: 3; radius: 1.5
              y: bracket.modelData[1] ? bracket.height - height : 0
              color: root.ice
            }
            Rectangle {
              width: 3; height: bracket.height; radius: 1.5
              x: bracket.modelData[0] ? bracket.width - width : 0
              color: root.ice
            }
          }
        }

        // Zone label.
        Rectangle {
          id: label
          anchors.centerIn: parent
          width: labelRow.implicitWidth + 28
          height: 38
          radius: 19
          color: Qt.rgba(0.02, 0.06, 0.09, 0.85)
          border.color: root.alpha(root.accent, 0.75)
          border.width: 1
          visible: highlight.width > width + 24 && highlight.height > height + 24

          Row {
            id: labelRow
            anchors.centerIn: parent
            spacing: 10
            Text {
              text: (root.zoneInfo[root.zone] || {}).icon || ""
              color: root.ice
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 18
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              text: ((root.zoneInfo[root.zone] || {}).label || "").toUpperCase()
              color: root.ice
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 13
              font.bold: true
              font.letterSpacing: 1.5
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          NumberAnimation {
            id: labelPop
            target: label
            property: "scale"
            from: 0.7
            to: 1
            duration: 230
            easing.type: Easing.OutBack
            easing.overshoot: 2
          }
        }
      }
    }
  }
}
