// A.T.L.A.S Universal Adaptive Titlebar
// User plugin: reversible Quickshell overlay, no core Omarchy files modified.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

Item {
  id: root

  property var shell: null
  property var manifest: null
  property string windowTitle: ""
  property string windowClass: ""
  property string windowAddress: ""
  property int windowX: 0
  property int windowY: 0
  property int windowW: 0
  property int windowH: 0
  property int fullscreen: 0
  property bool floating: false
  property bool mapped: true
  property bool acceptsInput: true
  property int workspaceId: 0
  property int monitorId: -1
  property int tick: 0
  property bool fullscreenReveal: false

  readonly property int barHeight: 34
  readonly property int windowInset: 6
  readonly property int topInset: 4
  readonly property int minWidth: 220
  readonly property int hoverZoneHeight: 8
  readonly property bool excludedSurface: isExcludedSurface(windowClass, windowTitle)
  readonly property bool hasWindow: windowAddress !== "" && windowW >= root.minWidth && windowH > 80 && mapped && acceptsInput && !excludedSurface
  readonly property bool isFullscreen: fullscreen !== 0
  readonly property bool showTitlebar: hasWindow && (!isFullscreen || fullscreenReveal)
  readonly property int commandWidth: Math.max(root.minWidth, root.windowW - (root.windowInset * 2))
  readonly property int commandX: root.windowX + root.windowInset
  readonly property int commandY: Math.max(0, root.windowY + root.topInset)
  readonly property string displayClass: cleanText(windowClass, "WINDOW").toUpperCase()
  readonly property string displayTitle: cleanText(windowTitle, "")
  readonly property string titleLine: displayTitle !== "" && displayTitle !== displayClass ? displayClass + " — " + displayTitle : displayClass

  function cleanText(value, fallback) {
    var s = String(value || "").replace(/^\s+|\s+$/g, "")
    if (!s) return fallback || ""
    return s.replace(/[\n\r\t]+/g, " ").replace(/\s+/g, " ")
  }

  function containsAny(haystack, needles) {
    var h = String(haystack || "").toLowerCase()
    for (var i = 0; i < needles.length; i++) {
      if (h.indexOf(needles[i]) >= 0) return true
    }
    return false
  }

  function isExcludedSurface(appClass, title) {
    var combined = String(appClass || "") + " " + String(title || "")
    return containsAny(combined, [
      "quickshell", "omarchy shell", "omarchy-bar", "omarchy launcher",
      "wofi", "rofi", "walker", "hyprlock", "hyprpaper",
      "notifications", "screenshot", "tooltip"
    ])
  }

  function resetWindow() {
    root.windowTitle = ""
    root.windowClass = ""
    root.windowAddress = ""
    root.windowX = 0
    root.windowY = 0
    root.windowW = 0
    root.windowH = 0
    root.fullscreen = 0
    root.floating = false
    root.mapped = false
    root.acceptsInput = false
    root.workspaceId = 0
    root.monitorId = -1
    root.fullscreenReveal = false
  }

  function parseActiveWindow(raw) {
    var text = String(raw || "").trim()
    if (!text || text === "null" || text === "{}") {
      resetWindow()
      return
    }

    var obj = null
    try { obj = JSON.parse(text) } catch (e) { return }
    if (!obj || !obj.address) {
      resetWindow()
      return
    }

    var oldAddress = root.windowAddress
    var oldFullscreen = root.fullscreen

    root.windowTitle = cleanText(obj.title || obj.initialTitle || "", "")
    root.windowClass = cleanText(obj.class || obj.initialClass || "Window", "Window")
    root.windowAddress = String(obj.address || "")
    root.windowX = obj.at && obj.at.length > 1 ? Number(obj.at[0]) : 0
    root.windowY = obj.at && obj.at.length > 1 ? Number(obj.at[1]) : 0
    root.windowW = obj.size && obj.size.length > 1 ? Number(obj.size[0]) : 0
    root.windowH = obj.size && obj.size.length > 1 ? Number(obj.size[1]) : 0
    root.fullscreen = Number(obj.fullscreen || obj.fullscreenClient || 0)
    root.floating = obj.floating === true
    root.mapped = obj.mapped !== false && obj.hidden !== true
    root.acceptsInput = obj.acceptsInput !== false
    root.workspaceId = obj.workspace && obj.workspace.id ? Number(obj.workspace.id) : 0
    root.monitorId = obj.monitor !== undefined ? Number(obj.monitor) : -1

    if (oldAddress !== root.windowAddress || oldFullscreen !== root.fullscreen) {
      root.fullscreenReveal = false
      fullscreenHideTimer.stop()
    }
  }

  function refresh() {
    activeWindowProc.running = false
    activeWindowProc.command = ["hyprctl", "activewindow", "-j"]
    activeWindowProc.running = true
  }

  function revealFullscreenBar() {
    if (!root.hasWindow || !root.isFullscreen) return
    root.fullscreenReveal = true
    fullscreenHideTimer.stop()
  }

  function scheduleFullscreenHide() {
    if (root.isFullscreen) fullscreenHideTimer.restart()
  }

  function windowDispatch(action) {
    if (action === "minimize") Quickshell.execDetached(["hyprctl", "dispatch", "movetoworkspacesilent", "special:minimized"])
    else if (action === "maximize") Quickshell.execDetached(["hyprctl", "dispatch", "fullscreen", "1"])
    else if (action === "close") Quickshell.execDetached(["hyprctl", "dispatch", "killactive"])
    root.fullscreenReveal = false
    root.refresh()
  }

  Component.onCompleted: root.refresh()

  // ATLAS_TITLEBAR_POLL_BALANCED: reduce Hyprland active-window polling to 700ms.
  Timer {
    interval: 700
    running: true
    repeat: true
    onTriggered: {
      root.tick += 1
      root.refresh()
    }
  }

  Timer {
    id: fullscreenHideTimer
    interval: 900
    repeat: false
    onTriggered: root.fullscreenReveal = false
  }

  Process {
    id: activeWindowProc
    running: false
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.parseActiveWindow(text) }
  }

  PanelWindow {
    id: layer
    visible: root.hasWindow
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "atlas-universal-adaptive-titlebar"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    MouseArea {
      id: fullscreenHoverZone
      visible: root.hasWindow && root.isFullscreen && !root.fullscreenReveal
      x: root.commandX
      y: Math.max(0, root.windowY)
      width: root.commandWidth
      height: root.hoverZoneHeight
      hoverEnabled: true
      acceptedButtons: Qt.NoButton
      onEntered: root.revealFullscreenBar()
    }

    Rectangle {
      id: shadow
      visible: root.showTitlebar
      x: root.commandX + 1
      y: root.commandY + 2
      width: root.commandWidth
      height: root.barHeight
      radius: 12
      color: "#00121988"
      opacity: 0.65
    }

    Rectangle {
      id: commandGlass
      visible: root.showTitlebar
      x: root.commandX
      y: root.commandY
      width: root.commandWidth
      height: root.barHeight
      radius: 12
      clip: true
      color: "#061018dd"
      border.width: 1
      border.color: root.isFullscreen ? "#8f3cffcc" : "#00f5ff99"

      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: "#061018ee" }
        GradientStop { position: 0.48; color: "#082420dd" }
        GradientStop { position: 1.0; color: "#160b2add" }
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: fullscreenHideTimer.stop()
        onExited: root.scheduleFullscreenHide()
      }

      Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 1
        opacity: 0.9
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0.0; color: "#00f5ff" }
          GradientStop { position: 0.55; color: "#00ff88" }
          GradientStop { position: 1.0; color: "#8f3cff" }
        }
      }

      Rectangle {
        id: pulse
        y: parent.height - 2
        width: parent.width * 0.22
        height: 2
        radius: 1
        color: root.isFullscreen ? "#8f3cff" : "#00ff88"
        opacity: 0.50
        x: ((root.tick * 17) % Math.max(1, parent.width + width)) - width
        Behavior on x { NumberAnimation { duration: 420; easing.type: Easing.Linear } }
      }

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 8
        spacing: 9

        Text {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          text: root.titleLine
          color: "#dffcff"
          opacity: 0.96
          font.family: "monospace"
          font.pixelSize: 12
          font.bold: true
          elide: Text.ElideRight
        }

        Text {
          Layout.preferredWidth: 50
          Layout.alignment: Qt.AlignVCenter
          text: root.floating ? "FLOAT" : (root.workspaceId > 0 ? "W" + root.workspaceId : "")
          color: root.floating ? "#8f3cff" : "#00f5ff"
          opacity: 0.62
          font.family: "monospace"
          font.pixelSize: 9
          horizontalAlignment: Text.AlignRight
        }

        Row {
          Layout.preferredWidth: 86
          Layout.preferredHeight: 24
          Layout.alignment: Qt.AlignVCenter
          spacing: 8

          Repeater {
            model: [
              { label: "−", tip: "minimize", color: "#00f5ff" },
              { label: root.isFullscreen ? "❐" : "□", tip: "maximize", color: "#00ff88" },
              { label: "×", tip: "close", color: "#ff5577" }
            ]
            delegate: Rectangle {
              required property var modelData
              width: 20
              height: 20
              radius: 6
              color: mouse.containsMouse ? modelData.color : "#07191fcc"
              border.width: 1
              border.color: modelData.color
              opacity: mouse.containsMouse ? 1.0 : 0.84
              Text {
                anchors.centerIn: parent
                text: modelData.label
                color: mouse.containsMouse ? "#061018" : modelData.color
                font.family: "monospace"
                font.pixelSize: 13
                font.bold: true
              }
              MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: fullscreenHideTimer.stop()
                onExited: root.scheduleFullscreenHide()
                onClicked: root.windowDispatch(modelData.tip)
              }
            }
          }
        }
      }
    }
  }
}
