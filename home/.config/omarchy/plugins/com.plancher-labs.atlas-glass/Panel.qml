// Glass: how see-through windows are, so the A.T.L.A.S wallpaper/HUD shows behind them.
// All state lives in ~/.local/bin/atlas-glass (which also applies it to Hyprland live);
// this widget is only a front end. Scroll on the bar icon to adjust, middle-click to flip
// between solid and the last glass level.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  ipcTarget: root.moduleName

  readonly property string glass: Quickshell.env("HOME") + "/.local/bin/atlas-glass"
  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property color dim: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.58)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  property int level: 0
  property int maxLevel: 60
  property bool blur: false
  property bool fullscreen: false
  // Restored by middle-click when currently solid.
  property int lastGlassLevel: 20

  // Slider drags fire far faster than hyprctl should be called; keep one run in flight
  // and send only the newest value when it finishes.
  property var pending: null

  readonly property var presets: [
    { label: "Solid", level: 0 },
    { label: "Subtle", level: 10 },
    { label: "Iron Man", level: 20 },
    { label: "Ghost", level: 35 }
  ]

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function run(args) {
    if (runProc.running) {
      root.pending = args
      return
    }
    runProc.command = [root.glass].concat(args)
    runProc.running = true
  }

  function setLevel(v) {
    var next = Math.max(0, Math.min(root.maxLevel, Math.round(v)))
    root.level = next
    if (next > 0) root.lastGlassLevel = next
    root.run(["set", String(next)])
  }

  function readState(text) {
    var s = null
    try { s = JSON.parse(String(text || "")) } catch (e) { return }
    if (!s) return
    // Don't let an older reply yank the slider back while a newer value is queued.
    if (root.pending === null) root.level = s.level
    root.maxLevel = s.max || 60
    root.blur = !!s.blur
    root.fullscreen = !!s.fullscreen
    if (s.level > 0) root.lastGlassLevel = s.level
  }

  function open() {
    root.run(["status"])
    root.controller.show()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  Component.onCompleted: root.run(["status"])

  Process {
    id: runProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.readState(text)
    }
    onExited: {
      if (root.pending !== null) {
        var args = root.pending
        root.pending = null
        root.run(args)
      }
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰂵"
    active: root.level > 0
    tooltipText: root.level > 0
      ? "Glass windows: " + root.level + "% see-through — scroll to adjust"
      : "Glass windows: solid — click to make windows see-through"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.MiddleButton) root.setLevel(root.level > 0 ? 0 : root.lastGlassLevel)
      else root.toggle()
    }
    onWheelMoved: function(delta) {
      root.setLevel(root.level + (delta > 0 ? 5 : -5))
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(520))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      Column {
        id: column
        width: parent.width
        spacing: Style.space(12)

        RowLayout {
          width: parent.width
          spacing: Style.space(10)
          Text {
            text: "󰂵"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
          }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text {
              text: "Glass"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }
            Text {
              text: root.level > 0 ? root.level + "% SEE-THROUGH" : "SOLID WINDOWS"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
            }
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        RowLayout {
          width: parent.width
          spacing: Style.space(10)
          Text {
            text: "Solid"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
          PanelSlider {
            Layout.fillWidth: true
            bar: root.bar
            minimum: 0
            maximum: root.maxLevel
            step: 5
            integer: true
            value: root.level
            onMoved: function(v) { root.setLevel(v) }
          }
          Text {
            text: "Ghost"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        RowLayout {
          width: parent.width
          spacing: Style.space(6)
          Repeater {
            model: root.presets
            delegate: Button {
              required property var modelData
              Layout.fillWidth: true
              text: modelData.label
              fontSize: Style.font.caption
              foreground: root.bar.foreground
              fontFamily: root.fontFamily
              bordered: true
              selected: root.level === modelData.level
              onClicked: root.setLevel(modelData.level)
            }
          }
        }

        Toggle {
          width: parent.width
          label: "Frosted blur"
          description: "Blur what's behind windows, like HUD glass. Uses more GPU."
          checked: root.blur
          foreground: root.bar.foreground
          fontFamily: root.fontFamily
          onClicked: {
            root.blur = !root.blur
            root.run(["blur", root.blur ? "on" : "off"])
          }
        }

        Toggle {
          width: parent.width
          label: "Fullscreen windows too"
          description: "Off keeps fullscreen apps and videos solid."
          checked: root.fullscreen
          foreground: root.bar.foreground
          fontFamily: root.fontFamily
          onClicked: {
            root.fullscreen = !root.fullscreen
            root.run(["fullscreen", root.fullscreen ? "on" : "off"])
          }
        }
      }
    }
  }
}
