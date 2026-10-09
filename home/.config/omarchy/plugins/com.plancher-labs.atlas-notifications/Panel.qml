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
  readonly property color foreground: bar ? bar.barForeground : Commons.Color.foreground
  readonly property color urgent: bar ? bar.urgent : Commons.Color.urgent
  readonly property color accent: Commons.Color.accent
  readonly property color dim: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.58)
  // Panel glass follows the theme background (stays correct in every theme and protocol).
  readonly property color glass: Qt.rgba(Commons.Color.background.r, Commons.Color.background.g, Commons.Color.background.b, 0.94)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var notificationService: bar && bar.shell ? bar.shell.firstPartyServiceFor("omarchy.notifications") : null
  readonly property int activeCount: notificationService && notificationService.popupModel ? notificationService.popupModel.count : 0
  readonly property int historyCount: historyModel.count
  readonly property bool hasSelection: selectedCount > 0
  property int selectedCount: 0
  property bool selectMode: false
  property string statusLine: "SYSTEM CLEAR"

  function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

  function refreshHistory() {
    historyProc.command = [root.helperPath(), "list"]
    historyProc.running = true
  }

  function helperPath() {
    return Quickshell.env("HOME") + "/.config/omarchy/plugins/com.plancher-labs.atlas-notifications/atlas-notification-center-helper"
  }

  function open() {
    root.refreshHistory()
    root.controller.show()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function") return root.bar.switchPanelFrom(root, direction)
    return false
  }

  function updateSelectedCount() {
    var n = 0
    for (var i = 0; i < historyModel.count; i++) if (historyModel.get(i).selected) n++
    selectedCount = n
  }

  function setAllSelected(value) {
    for (var i = 0; i < historyModel.count; i++) historyModel.setProperty(i, "selected", value)
    updateSelectedCount()
  }

  function clearSelected() {
    var args = [root.helperPath(), "clear-selected"]
    for (var i = 0; i < historyModel.count; i++) {
      var row = historyModel.get(i)
      if (row.selected) args.push(row.file)
    }
    if (args.length <= 2) return
    clearProc.command = args
    clearProc.running = true
  }

  function clearAllHistory() {
    clearProc.command = [root.helperPath(), "clear-all"]
    clearProc.running = true
  }

  function dismissAllActive() {
    if (notificationService && typeof notificationService.clearPopups === "function") notificationService.clearPopups()
  }

  function dismissNewestActive() {
    if (notificationService && typeof notificationService.dismissPopup === "function" && root.activeCount > 0) notificationService.dismissPopup(0)
  }

  function loadHistory(raw) {
    historyModel.clear()
    var payload = null
    try { payload = JSON.parse(String(raw || "{}")) } catch(e) { payload = null }
    var rows = payload && payload.rows ? payload.rows : []
    for (var i = 0; i < rows.length; i++) {
      var r = rows[i]
      historyModel.append({
        file: String(r.file || ""),
        app: String(r.app || "SYSTEM"),
        summary: String(r.summary || "Notification"),
        body: String(r.body || ""),
        glyph: String(r.glyph || ""),
        urgency: Number(r.urgency || 1),
        timestamp: Number(r.timestamp || 0),
        selected: false
      })
    }
    selectedCount = 0
    statusLine = rows.length > 0 ? (rows.length + " HISTORY ITEM" + (rows.length === 1 ? "" : "S") + " LOADED") : "SYSTEM CLEAR"
  }

  function timeLabel(ms) {
    if (!ms || ms <= 0) return "RECENT"
    var d = new Date(ms)
    return Qt.formatDateTime(d, "h:mm AP")
  }

  ListModel { id: historyModel }

  Process {
    id: historyProc
    running: false
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.loadHistory(text) }
  }

  Process {
    id: clearProc
    running: false
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: { root.statusLine = "CLEARED"; root.refreshHistory() } }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.activeCount > 0 ? "!" : "N"
    active: root.activeCount > 0
    tooltipText: root.activeCount > 0 ? (root.activeCount + " active notification" + (root.activeCount === 1 ? "" : "s")) : "Notifications"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.dismissAllActive()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(430))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(650))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "r" || t === "R") root.refreshHistory()
        else if (t === "s" || t === "S") root.selectMode = !root.selectMode
        else if (t === "a" || t === "A") root.clearAllHistory()
      }

      Flickable {
        id: scroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: panelColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: panelColumn
          width: scroll.width
          spacing: Style.space(12)

          BorderSurface {
            width: parent.width
            implicitHeight: headerCol.implicitHeight + Style.space(24)
            radius: Style.cornerRadius
            color: root.glass
            borderSpec: Border.flat(root.alpha(root.accent, 0.85), 1)

            Column {
              id: headerCol
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: Style.space(12)
              spacing: Style.space(10)

              RowLayout {
                width: parent.width
                spacing: Style.space(10)
                Text {
                  text: "󰂚"
                  color: root.activeCount > 0 ? root.accent : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.display
                }
                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 1
                  Text {
                    Layout.fillWidth: true
                    text: "A.T.L.A.S NOTIFICATIONS"
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.heading
                    font.bold: true
                  }
                  Text {
                    Layout.fillWidth: true
                    text: root.activeCount + " active  •  " + root.historyCount + " history  •  " + root.statusLine
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                  }
                }
                AtlasPill { label: root.selectMode ? "DONE" : "SELECT"; onClicked: root.selectMode = !root.selectMode }
              }

              Row {
                spacing: Style.space(8)
                AtlasPill { label: "CLEAR ALL"; danger: true; enabled: root.historyCount > 0; onClicked: root.clearAllHistory() }
                AtlasPill { label: "CLEAR SELECTED"; enabled: root.hasSelection; onClicked: root.clearSelected() }
                AtlasPill { label: "DISMISS ACTIVE"; enabled: root.activeCount > 0; onClicked: root.dismissAllActive() }
              }
            }
          }

          BorderSurface {
            visible: root.historyCount === 0
            width: parent.width
            implicitHeight: emptyCol.implicitHeight + Style.space(44)
            radius: Style.cornerRadius
            color: root.alpha(Commons.Color.popups.background, 0.72)
            borderSpec: Border.flat(root.alpha(root.foreground, 0.20), 1)
            Column {
              id: emptyCol
              anchors.centerIn: parent
              spacing: Style.space(6)
              Text { text: "󰂜"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.displayLarge; anchors.horizontalCenter: parent.horizontalCenter }
              Text { text: "No recent notifications"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
              Text { text: "SYSTEM CLEAR"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.horizontalCenter: parent.horizontalCenter }
            }
          }

          Repeater {
            model: historyModel
            delegate: NotificationRow {
              required property int index
              required property string file
              required property string app
              required property string summary
              required property string body
              required property string glyph
              required property int urgency
              required property double timestamp
              required property bool selected
              width: panelColumn.width
              appName: app
              title: summary
              detail: body
              glyphText: glyph
              urgent: urgency >= 2
              timeText: root.timeLabel(timestamp)
              selectMode: root.selectMode
              isSelected: selected
              onToggleSelected: {
                historyModel.setProperty(index, "selected", !selected)
                root.updateSelectedCount()
              }
              onClearOne: {
                clearProc.command = [root.helperPath(), "clear-selected", file]
                clearProc.running = true
              }
            }
          }
        }
      }
    }
  }

  component AtlasPill: Rectangle {
    id: pill
    property string label: ""
    property bool danger: false
    signal clicked()
    radius: height / 2
    width: Math.max(Style.space(72), pillText.implicitWidth + Style.space(18))
    height: Style.space(26)
    color: !enabled ? root.alpha(root.foreground, 0.05) : root.alpha(danger ? root.urgent : root.accent, mouse.containsMouse ? 0.24 : 0.14)
    border.color: !enabled ? root.alpha(root.foreground, 0.12) : root.alpha(danger ? root.urgent : root.accent, mouse.containsMouse ? 0.95 : 0.55)
    border.width: 1
    opacity: enabled ? 1 : 0.45
    Text { id: pillText; anchors.centerIn: parent; text: pill.label; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; enabled: pill.enabled; cursorShape: Qt.PointingHandCursor; onClicked: pill.clicked() }
  }

  component NotificationRow: BorderSurface {
    id: row
    property string appName: ""
    property string title: ""
    property string detail: ""
    property string glyphText: ""
    property string timeText: ""
    property bool urgent: false
    property bool selectMode: false
    property bool isSelected: false
    signal toggleSelected()
    signal clearOne()

    implicitHeight: bodyCol.implicitHeight + Style.space(22)
    radius: Style.cornerRadius
    color: root.alpha(row.urgent ? root.urgent : Commons.Color.popups.background, row.isSelected ? 0.32 : 0.82)
    borderSpec: Border.flat(root.alpha(row.isSelected ? root.accent : (row.urgent ? root.urgent : root.foreground), row.isSelected ? 0.95 : 0.26), row.isSelected ? 2 : 1)

    RowLayout {
      id: bodyCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Style.space(10)
      spacing: Style.space(10)

      Rectangle {
        visible: row.selectMode
        Layout.preferredWidth: Style.space(22)
        Layout.preferredHeight: Style.space(22)
        Layout.alignment: Qt.AlignTop
        radius: Style.space(5)
        color: row.isSelected ? root.alpha(root.accent, 0.32) : root.alpha(root.foreground, 0.06)
        border.color: row.isSelected ? root.accent : root.alpha(root.foreground, 0.38)
        border.width: 1
        Text { anchors.centerIn: parent; text: row.isSelected ? "✓" : ""; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: row.toggleSelected() }
      }

      Rectangle {
        Layout.preferredWidth: Style.space(36)
        Layout.preferredHeight: Style.space(36)
        Layout.alignment: Qt.AlignTop
        radius: Style.space(10)
        color: root.alpha(row.urgent ? root.urgent : root.accent, 0.16)
        border.color: root.alpha(row.urgent ? root.urgent : root.accent, 0.46)
        border.width: 1
        Text { anchors.centerIn: parent; text: row.glyphText.length > 0 ? row.glyphText : "󰂚"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.iconLarge }
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(3)
        RowLayout {
          Layout.fillWidth: true
          Text { Layout.fillWidth: true; text: row.appName.length > 0 ? row.appName.toUpperCase() : "SYSTEM"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
          Text { text: row.timeText; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
        }
        Text { Layout.fillWidth: true; text: row.title; color: root.foreground; font.family: "Liberation Sans"; font.pixelSize: Style.font.title; font.bold: true; maximumLineCount: 2; elide: Text.ElideRight; wrapMode: Text.WordWrap }
        Text { visible: row.detail.length > 0; Layout.fillWidth: true; text: row.detail.replace(/\r\n|\r|\n/g, " "); color: root.alpha(root.foreground, 0.78); font.family: "Liberation Sans"; font.pixelSize: Style.font.body; maximumLineCount: 2; elide: Text.ElideRight; wrapMode: Text.WordWrap }
      }

      Rectangle {
        Layout.preferredWidth: Style.space(24)
        Layout.preferredHeight: Style.space(24)
        Layout.alignment: Qt.AlignTop
        radius: width / 2
        color: xMouse.containsMouse ? root.alpha(root.urgent, 0.24) : root.alpha(root.foreground, 0.06)
        border.color: xMouse.containsMouse ? root.urgent : root.alpha(root.foreground, 0.18)
        border.width: 1
        Text { anchors.centerIn: parent; text: "×"; color: xMouse.containsMouse ? root.urgent : root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
        MouseArea { id: xMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: row.clearOne() }
      }
    }

    MouseArea {
      anchors.fill: parent
      z: -1
      enabled: row.selectMode
      onClicked: row.toggleSelected()
    }
  }
}
