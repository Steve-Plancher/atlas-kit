import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bell for the A.T.L.A.S notification center. Built on BarIconButton so its
// slot, glyph size and optical centering come from the same Style.bar tokens as
// every native bar icon, and track shell.toml's font size instead of fixed px.
Item {
  id: root

  property var bar
  property string moduleName
  property var settings

  property int urgentCount: 0
  property int historyCount: 0

  implicitWidth: button.implicitWidth
  implicitHeight: bar ? bar.barSize : Style.bar.sizeHorizontal

  function parseStatus(raw) {
    var urgent = 0
    var total = 0
    try {
      var payload = JSON.parse(String(raw || "{}"))
      var rows = payload && payload.rows ? payload.rows : []
      total = rows.length
      for (var i = 0; i < rows.length; i++) {
        if (Number(rows[i].urgency || 1) >= 2) urgent++
      }
    } catch(e) {}
    root.urgentCount = urgent
    root.historyCount = total
  }

  Process {
    id: statusProc
    running: false
    command: [Quickshell.env("HOME") + "/.config/omarchy/plugins/com.plancher-labs.atlas-notifications/atlas-notification-center-helper", "list"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.parseStatus(text) }
  }

  Process {
    id: toggleProc
    running: false
    command: ["omarchy-shell", "-q", "com.plancher-labs.atlas-notifications", "toggle"]
  }

  Timer {
    interval: 30000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: statusProc.running = true
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // Urgent uses the bar's own active colour, like the other native icons.
    text: root.urgentCount > 0 ? "󰂚" : "󰂜"
    active: root.urgentCount > 0
    tooltipText: root.historyCount > 0
      ? (root.historyCount + " notification" + (root.historyCount === 1 ? "" : "s"))
      : "Notifications"
    onPressed: function(buttonCode) {
      toggleProc.running = true
      statusProc.running = true
    }
  }

  // Unread dot, sized off the icon canvas so it scales with the glyph.
  Rectangle {
    visible: root.historyCount > 0 && root.urgentCount === 0
    readonly property int dotSize: Math.max(3, Math.round(Style.bar.iconCanvas / 4))
    width: dotSize
    height: dotSize
    radius: dotSize / 2
    color: Color.accent
    x: Math.round((root.width + Style.bar.iconCanvas) / 2 - dotSize)
    y: Math.round((root.height - Style.bar.iconCanvas) / 2)
  }
}
