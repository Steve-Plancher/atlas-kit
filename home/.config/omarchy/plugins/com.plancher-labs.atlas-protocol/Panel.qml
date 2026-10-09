// Protocols: switch the A.T.L.A.S color protocol and the Vibe switches from the bar.
// All state lives in ~/.local/bin/atlas-protocol and ~/.local/bin/atlas-vibe (voice commands and
// the terminal use them too); this widget is only a front end. It watches their state files, so
// a change made elsewhere shows here at once.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Panel {
  id: root
  ipcTarget: root.moduleName

  readonly property string home: Quickshell.env("HOME")
  readonly property string protocolCmd: root.home + "/.local/bin/atlas-protocol"
  readonly property string vibeCmd: root.home + "/.local/bin/atlas-vibe"
  readonly property color foreground: bar ? bar.barForeground : Commons.Color.foreground
  readonly property color dim: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.58)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // [{name, label, icon, desc, accent, active}] from `atlas-protocol list --json`.
  property var protocols: []
  readonly property var current: {
    for (var i = 0; i < root.protocols.length; i++)
      if (root.protocols[i].active) return root.protocols[i]
    return { name: "standard", label: "Standard", icon: "󰐷", desc: "", accent: Commons.Color.accent }
  }
  readonly property bool inVibe: root.current.name === "vibe"
  // Name of the protocol being engaged; it takes a second or two (theme re-apply is last).
  property string switching: ""

  // Keyboard cursor: 0-3 the tiles, then Music Ring, Voice Ring, Now Playing. -1 = none yet.
  // PanelKeyCatcher swallows Tab, arrows, Space and Enter, so the panel moves it itself.
  property int cursor: -1
  readonly property var switches: ["music", "voice", "nowplaying"]
  readonly property int controlCount: root.protocols.length + root.switches.length

  property bool musicOn: true
  property bool voiceOn: false
  property bool nowPlayingOn: true

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (!listProc.running) listProc.running = true
  }

  function engage(name) {
    if (root.switching !== "" || name === root.current.name) return
    root.switching = name
    engageProc.command = [root.protocolCmd, name]
    engageProc.running = true
  }

  // The switch flips at once; the state file the command writes confirms it.
  function setSwitch(name, on) {
    if (name === "music") root.musicOn = on
    else if (name === "voice") root.voiceOn = on
    else root.nowPlayingOn = on
    Quickshell.execDetached([root.vibeCmd, name, on ? "on" : "off"])
  }

  function switchOn(name) {
    return name === "music" ? root.musicOn : name === "voice" ? root.voiceOn : root.nowPlayingOn
  }

  function activate(i) {
    var n = root.protocols.length
    if (i < 0) return
    if (i < n) root.engage(root.protocols[i].name)
    else if (i - n < root.switches.length) {
      var s = root.switches[i - n]
      root.setSwitch(s, !root.switchOn(s))
    }
  }

  function tab(direction) {
    var c = root.controlCount
    if (c === 0) return
    root.cursor = root.cursor < 0 ? (direction > 0 ? 0 : c - 1) : (root.cursor + direction + c) % c
  }

  // Arrows: left/right inside a tile row; up/down through the tile rows, then the switches.
  function moveCursor(dx, dy) {
    var n = root.protocols.length
    if (root.cursor < 0) { root.cursor = 0; return }
    if (root.cursor < n) {
      var col = root.cursor % 2
      if (dx !== 0 && col + dx >= 0 && col + dx <= 1 && root.cursor + dx < n) root.cursor += dx
      if (dy !== 0) {
        var next = root.cursor + dy * 2
        if (next >= n) root.cursor = n
        else if (next >= 0) root.cursor = next
      }
    } else if (dy !== 0) {
      var down = root.cursor + dy
      if (down < n) root.cursor = Math.max(0, n - 2)
      else if (down < root.controlCount) root.cursor = down
    }
  }

  function open() {
    root.cursor = -1
    root.refresh()
    root.controller.show()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  Component.onCompleted: root.refresh()

  Process {
    id: listProc
    command: [root.protocolCmd, "list", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.protocols = JSON.parse(String(text || "[]")) } catch (e) {}
      }
    }
  }

  Process {
    id: engageProc
    onExited: {
      root.switching = ""
      root.refresh()
    }
  }

  FileView {
    path: root.home + "/.local/state/atlas-protocol/current"
    watchChanges: true
    printErrors: false
    onFileChanged: { reload(); root.refresh() }
  }

  FileView {
    path: root.home + "/.local/state/atlas-protocol/vibe-mode"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.musicOn = String(text()).trim() !== "calm"
    onLoadFailed: root.musicOn = true
  }

  FileView {
    path: root.home + "/.local/state/atlas-protocol/vibe-voice"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.voiceOn = String(text()).trim() === "on"
    onLoadFailed: root.voiceOn = false
  }

  FileView {
    path: root.home + "/.local/state/atlas-hud/nowplaying"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.nowPlayingOn = String(text()).trim() !== "off"
    onLoadFailed: root.nowPlayingOn = true
  }

  // The bar always shows the radar; only its color follows the protocol (white in Standard).
  // The tiles inside the panel keep each protocol's own icon.
  readonly property string barIcon: "󰐷"
  readonly property string currentName: root.current.name
  onCurrentNameChanged: if (root.protocols.length > 0) switchPulse.restart()

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.barIcon
    active: root.current.name !== "standard"
    activeColor: root.current.accent
    transformOrigin: Item.Center

    // One short ping when the protocol changes, then still.
    SequentialAnimation {
      id: switchPulse
      NumberAnimation { target: button; property: "scale"; to: 1.35; duration: 160; easing.type: Easing.OutQuad }
      NumberAnimation { target: button; property: "scale"; to: 1.0; duration: 420; easing.type: Easing.OutBack }
    }
    tooltipText: "Protocol: " + root.current.label + " — click to switch"
    onPressed: root.toggle()
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(640))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.tab(direction) }
      onMoveRequested: function(dx, dy) { root.moveCursor(dx, dy) }
      onActivateRequested: root.activate(root.cursor)

      Column {
        id: column
        width: parent.width
        spacing: Style.space(12)

        RowLayout {
          width: parent.width
          spacing: Style.space(10)
          Text {
            text: root.current.icon
            color: Commons.Color.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
          }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text {
              text: "Protocols"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }
            Text {
              Layout.fillWidth: true
              text: root.switching !== ""
                ? "SWITCHING TO " + root.switching.toUpperCase() + "…"
                : (root.current.label + (root.current.desc ? " · " + root.current.desc : "")).toUpperCase()
              color: root.dim
              elide: Text.ElideRight
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
            }
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        GridLayout {
          width: parent.width
          columns: 2
          columnSpacing: Style.space(8)
          rowSpacing: Style.space(8)

          Repeater {
            model: root.protocols
            delegate: BorderSurface {
              id: tile
              required property var modelData
              required property int index
              readonly property bool isActive: modelData.active
              readonly property bool isSwitching: root.switching === modelData.name
              readonly property bool hot: tileMouse.containsMouse || root.cursor === index
              readonly property color tint: modelData.accent

              Layout.fillWidth: true
              Layout.preferredWidth: 1
              implicitHeight: tileBody.implicitHeight + Style.spacing.xxl * 2
              radius: Style.cornerRadius

              color: tileMouse.pressed ? Style.pressedFillFor(root.foreground, tint)
                : isActive ? Qt.rgba(tint.r, tint.g, tint.b, hot ? 0.26 : 0.16)
                : Style.controlFill(false, hot, root.foreground, tint)
              borderSpec: isActive || isSwitching ? Border.flat(tint, Math.max(2, Style.space(2)))
                : Border.controlSpec(hot ? "hover-cursor" : "normal", root.foreground, tint)
              Behavior on color { ColorAnimation { duration: Style.duration(120) } }

              ColumnLayout {
                id: tileBody
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: tile.borderLeft + Style.spacing.rowPaddingX
                anchors.rightMargin: tile.borderRight + Style.spacing.rowPaddingX
                spacing: Style.spacing.md

                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.spacing.lg
                  Text {
                    text: tile.modelData.icon
                    color: tile.tint
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.icon
                  }
                  Text {
                    Layout.fillWidth: true
                    text: tile.modelData.label
                    color: root.foreground
                    elide: Text.ElideRight
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.subtitle
                    font.bold: true
                  }
                  Rectangle {
                    visible: tile.isActive
                    width: Style.space(8)
                    height: width
                    radius: width / 2
                    color: tile.tint
                  }
                }

                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.spacing.lg
                  Rectangle {
                    Layout.preferredWidth: Style.space(26)
                    Layout.preferredHeight: Style.space(4)
                    radius: height / 2
                    color: tile.tint
                  }
                  Text {
                    Layout.fillWidth: true
                    text: tile.isSwitching ? "Switching…" : tile.modelData.desc
                    color: root.dim
                    elide: Text.ElideRight
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }
              }

              MouseArea {
                id: tileMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: if (containsMouse) root.cursor = tile.index
                onClicked: root.engage(tile.modelData.name)
              }
            }
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        PanelSectionHeader {
          text: "VIBE RINGS"
          foreground: root.bar.foreground
          fontFamily: root.fontFamily
        }

        Toggle {
          width: parent.width
          label: "Music Ring"
          description: "Reacts to your speakers" + (root.inVibe ? "" : " · shows in Vibe")
          checked: root.musicOn
          foreground: root.bar.foreground
          fontFamily: root.fontFamily
          hasCursor: root.cursor === root.protocols.length
          onHovered: function(isHovered) { if (isHovered) root.cursor = root.protocols.length }
          onClicked: root.setSwitch("music", !root.musicOn)
        }

        Toggle {
          width: parent.width
          label: "Voice Ring"
          description: "Reacts to your voice" + (root.inVibe ? "" : " · shows in Vibe")
          checked: root.voiceOn
          foreground: root.bar.foreground
          fontFamily: root.fontFamily
          hasCursor: root.cursor === root.protocols.length + 1
          onHovered: function(isHovered) { if (isHovered) root.cursor = root.protocols.length + 1 }
          onClicked: root.setSwitch("voice", !root.voiceOn)
        }

        PanelSeparator { foreground: root.bar.foreground }

        PanelSectionHeader {
          text: "HUD"
          foreground: root.bar.foreground
          fontFamily: root.fontFamily
        }

        Toggle {
          width: parent.width
          label: "Now Playing"
          description: "Spotify panel on the HUD"
          checked: root.nowPlayingOn
          foreground: root.bar.foreground
          fontFamily: root.fontFamily
          hasCursor: root.cursor === root.protocols.length + 2
          onHovered: function(isHovered) { if (isHovered) root.cursor = root.protocols.length + 2 }
          onClicked: root.setSwitch("nowplaying", !root.nowPlayingOn)
        }
      }
    }
  }
}
