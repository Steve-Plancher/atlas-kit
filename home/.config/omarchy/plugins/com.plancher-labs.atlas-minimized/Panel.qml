// Minimized windows: the title bar's minimize button (atlas-snap minimize) parks windows on
// the hidden special:minimized workspace. This widget shows how many are parked and lists
// them; clicking one brings it back to the workspace on screen. It collapses to nothing when
// no window is minimized.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

Panel {
  id: root
  ipcTarget: root.moduleName

  readonly property string snap: Quickshell.env("HOME") + "/.local/bin/atlas-snap"
  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property color dim: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.58)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  property var windows: []

  // Hidden while nothing is minimized. Width stays fixed (like Omarchy's SystemUpdate
  // widget): tying it to visibility locks the widget at zero width, hidden for good.
  visible: windows.length > 0
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (!listProc.running) listProc.running = true
  }

  function restore(address) {
    restoreProc.command = address ? [root.snap, "restore", address] : [root.snap, "restore"]
    restoreProc.running = true
    if (!address || root.windows.length <= 1) root.close()
  }

  function open() {
    root.refresh()
    root.controller.show()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  Component.onCompleted: refresh()

  // Window moves, opens and closes all arrive as Hyprland events; re-list on those.
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = event && event.name ? String(event.name) : ""
      if (name.indexOf("movewindow") === 0 || name.indexOf("closewindow") === 0 || name.indexOf("openwindow") === 0)
        refreshDebounce.restart()
    }
  }

  Timer {
    id: refreshDebounce
    interval: 150
    onTriggered: root.refresh()
  }

  // Backstop in case an event is missed.
  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: listProc
    command: [root.snap, "list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = []
        try { parsed = JSON.parse(String(text || "[]")) } catch (e) { parsed = [] }
        root.windows = Array.isArray(parsed) ? parsed : []
        if (root.windows.length === 0 && root.opened) root.close()
      }
    }
  }

  Process {
    id: restoreProc
    onExited: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰖰"
    active: true
    tooltipText: root.windows.length + " minimized window" + (root.windows.length === 1 ? "" : "s") + " — click to restore"
    onPressed: function(buttonCode) {
      // Middle-click restores everything at once.
      if (buttonCode === Qt.MiddleButton) root.restore("")
      else root.toggle()
    }
  }

  // Count badge.
  Rectangle {
    visible: root.windows.length > 1
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.rightMargin: 1
    anchors.topMargin: 2
    width: Math.max(12, badgeText.implicitWidth + 6)
    height: 12
    radius: 6
    color: Color.accent
    Text {
      id: badgeText
      anchors.centerIn: parent
      text: root.windows.length
      color: Color.background
      font.family: root.fontFamily
      font.pixelSize: 9
      font.bold: true
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
    contentHeight: panel.fittedContentHeight(listColumn.implicitHeight, Style.space(520))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      Flickable {
        id: scroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: listColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: listColumn
          width: scroll.width
          spacing: Style.space(10)

          RowLayout {
            width: parent.width
            spacing: Style.space(10)
            Text {
              text: "󰖰"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 1
              Text {
                text: "Minimized"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }
              Text {
                text: (root.windows.length + " WINDOW" + (root.windows.length === 1 ? "" : "S")).toUpperCase()
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.2
              }
            }
            Button {
              visible: root.windows.length > 1
              text: "Restore all"
              fontSize: Style.font.caption
              foreground: root.bar.foreground
              fontFamily: root.fontFamily
              bordered: true
              onClicked: root.restore("")
            }
          }

          PanelSeparator { foreground: root.bar.foreground }

          Repeater {
            model: root.windows
            delegate: CursorSurface {
              id: row
              required property var modelData
              width: listColumn.width
              implicitHeight: rowInner.implicitHeight + Style.spacing.lg
              foreground: root.bar.foreground
              fill: Style.hoverFillFor(root.bar.foreground, Color.accent)
              hasCursor: rowMouse.containsMouse

              RowLayout {
                id: rowInner
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.space(8)
                anchors.rightMargin: Style.space(8)
                spacing: Style.space(10)

                Text {
                  text: "󰖯"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                }
                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 1
                  Text {
                    Layout.fillWidth: true
                    text: row.modelData.title || row.modelData.class
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    elide: Text.ElideRight
                  }
                  Text {
                    Layout.fillWidth: true
                    text: String(row.modelData.class || "").toUpperCase()
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                  }
                }
                Text {
                  text: "󰁞"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                }
              }

              MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.restore(row.modelData.address)
              }
            }
          }
        }
      }
    }
  }
}
