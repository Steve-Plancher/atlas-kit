import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import qs.Commons as Commons
import "Model.js" as Model

// A.T.L.A.S Display panel — a clone of omarchy.monitor extended into a per-display
// control centre. Pick a display with the tabs, then brightness, rotation, scale,
// resolution, refresh rate and on/off all apply to that display only. Every change
// goes through ~/.local/bin/atlas-display, which saves it into
// ~/.config/hypr/atlas-monitors.json and regenerates monitors.lua, so nothing is
// lost on a Hyprland reload, reconnect or dock. "Arrange" opens nwg-displays for
// dragging displays into position; its saves are merged back the same way.
Panel {
  id: root
  moduleName: "omarchy.monitor"
  ipcTarget: "omarchy.monitor"
  manageIpc: false

  readonly property string atlasDisplay: Quickshell.env("HOME") + "/.local/bin/atlas-display"

  // ---- State from `atlas-display state` ----
  property var displays: []
  property bool laptopOffWhenDocked: false
  property bool docked: false
  property string selectedName: ""
  readonly property var selected: {
    for (var i = 0; i < displays.length; i++)
      if (displays[i].name === selectedName) return displays[i]
    return displays.length > 0 ? displays[0] : null
  }
  readonly property int enabledDisplayCount: {
    var n = 0
    for (var i = 0; i < displays.length; i++) if (displays[i].enabled) n++
    return n
  }

  // Brightness for the selected display (laptop backlight, or DDC for externals).
  property int brightnessPercent: 0
  property int pendingBrightnessPercent: 0
  property bool brightnessSetQueued: false
  property bool brightnessAvailable: false
  property string brightnessFor: ""
  property real wheelAccumulator: 0

  // Status line: "APPLYING…" while atlas-display runs, errors for a few seconds.
  property string statusText: ""
  property bool statusIsError: false
  property var pendingAction: null

  readonly property var scalePresets: ["1", "1.25", "1.6", "2", "3", "4"]
  readonly property var scaleValues: selected
    ? Model.availableScales(scalePresets, selected.width, selected.height) : scalePresets
  readonly property var rotations: [
    { transform: 0, label: "0°" }, { transform: 1, label: "90°" },
    { transform: 2, label: "180°" }, { transform: 3, label: "270°" }
  ]
  readonly property var resolutions: Model.resolutionsFor(selected)
  readonly property var refreshRates: Model.refreshRatesFor(selected)
  // Turning a display off needs another display that is on. "no-other" = nothing else is
  // connected; "others-off" = other displays are connected but all switched off.
  readonly property string powerBlockReason: {
    if (!selected || !selected.enabled) return ""
    if (enabledDisplayCount > 1) return ""
    return displays.length <= 1 ? "no-other" : "others-off"
  }
  readonly property string powerBlockText: powerBlockReason === "no-other"
    ? "No other monitors detected — connect a display before turning this one off."
    : powerBlockReason === "others-off"
      ? "No other display is on — turn another display on before turning this one off."
      : ""
  // Warnings use a fixed amber: some themes (Hackerman) make Color.urgent green, which
  // reads as success rather than "you can't do this".
  readonly property color warningColor: "#ffb347"
  readonly property var powerItems: {
    if (!selected) return []
    var items = ["enabled"]
    if (selected.internal && displays.length > 1) items.push("dockPolicy")
    return items
  }

  // Text size — unchanged from Omarchy; it is global, not per display.
  readonly property var textSizeStops: [9, 10, 11, 12, 14, 16, 20]
  property int textSizePreviewIndex: -1
  property bool reflowingText: false
  function markReflowing() {
    root.reflowingText = true
    reflowSettle.restart()
  }

  // ---- Keyboard cursor ----
  // Every section is one horizontal row: sliders adjust with h/l, button rows walk
  // their buttons with h/l, and j/k moves between sections.
  property string focusSection: "tabs"
  property int selectedIndex: 0
  property bool cursorActive: false

  readonly property bool selectedOn: selected !== null && selected.enabled
  readonly property var visibleSections: {
    var list = ["arrange"]
    if (displays.length > 1) list.push("tabs")
    if (brightnessAvailable && selectedOn) list.push("brightness")
    if (selectedOn) {
      list.push("rotation")
      list.push("scale")
      if (resolutions.length > 1) list.push("resolution")
      if (refreshRates.length > 1) list.push("refresh")
    }
    if (powerItems.length > 0) list.push("power")
    list.push("textsize")
    return list
  }

  function isSlider(section) { return section === "brightness" || section === "textsize" }

  function sectionCount(section) {
    switch (section) {
    case "arrange": return 1
    case "tabs": return displays.length
    case "rotation": return rotations.length
    case "scale": return scaleValues.length
    case "resolution": return resolutions.length
    case "refresh": return refreshRates.length
    case "power": return powerItems.length
    }
    return 0
  }

  function moveCursor(delta) {
    var sections = visibleSections
    if (!sections || sections.length === 0) return
    var sIdx = sections.indexOf(focusSection)
    if (sIdx < 0) sIdx = 0
    sIdx = Math.max(0, Math.min(sections.length - 1, sIdx + delta))
    focusSection = sections[sIdx]
    selectedIndex = isSlider(focusSection) ? -1 : Math.max(0, activeIndexIn(focusSection))
  }

  function moveCursorH(delta) {
    if (focusSection === "brightness") { adjustBrightness(delta * 5); return }
    if (focusSection === "textsize") { adjustTextSize(delta); return }
    var next = selectedIndex + delta
    selectedIndex = Math.max(0, Math.min(sectionCount(focusSection) - 1, next))
  }

  function activeIndexIn(section) {
    if (!selected) return 0
    switch (section) {
    case "tabs": return displays.indexOf(selected)
    case "rotation": return selected.transform <= 3 ? selected.transform : 0
    case "scale": return Model.matchingScaleIndex(scaleValues, String(selected.scale), selected.width, selected.height)
    case "resolution": return Model.indexOfResolution(resolutions, selected.width, selected.height)
    case "refresh": return Model.indexOfRefresh(refreshRates, selected.refresh)
    }
    return 0
  }

  function activateCursor() {
    var i = selectedIndex
    switch (focusSection) {
    case "arrange": openArrange(); break
    case "tabs": if (i >= 0 && i < displays.length) selectDisplay(displays[i].name); break
    case "rotation": if (i >= 0 && i < rotations.length) setRotation(rotations[i].transform); break
    case "scale": if (i >= 0 && i < scaleValues.length) setScale(scaleValues[i]); break
    case "resolution": if (i >= 0 && i < resolutions.length) setResolution(resolutions[i]); break
    case "refresh": if (i >= 0 && i < refreshRates.length) setRefresh(refreshRates[i]); break
    case "power": activatePower(powerItems[i]); break
    }
  }

  function clampCursor() {
    var sections = visibleSections
    if (!sections || sections.length === 0) return
    if (sections.indexOf(focusSection) < 0) {
      focusSection = sections.indexOf("tabs") >= 0 ? "tabs" : sections[0]
      selectedIndex = isSlider(focusSection) ? -1 : 0
      return
    }
    if (isSlider(focusSection)) { selectedIndex = -1; return }
    var count = sectionCount(focusSection)
    if (selectedIndex > count - 1) selectedIndex = count - 1
    if (selectedIndex < 0) selectedIndex = 0
  }

  function hoverCursor(section, index) {
    if (root.reflowingText) return
    root.cursorActive = true
    root.focusSection = section
    root.selectedIndex = index
  }

  function ensureCursorVisible(item) {
    if (!item || !scrollArea) return
    var flick = scrollArea.contentItem
    if (!flick || flick.contentY === undefined) return
    var pt = item.mapToItem(flick.contentItem || flick, 0, 0)
    var top = pt.y
    var bottom = top + (item.height || 0)
    var margin = 6
    if (top < flick.contentY + margin) flick.contentY = Math.max(0, top - margin)
    else if (bottom > flick.contentY + flick.height - margin)
      flick.contentY = bottom + margin - flick.height
  }

  // ---- IPC (same target and methods as Omarchy's panel) ----
  function brightnessIpc(percent) {
    root.setBrightness(Number(percent))
    return "got " + root.pendingBrightnessPercent
  }

  function stateIpc() {
    return JSON.stringify({
      brightness: root.brightnessPercent,
      brightnessAvailable: root.brightnessAvailable,
      selected: root.selectedName,
      displays: root.displays
    })
  }

  IpcHandler {
    target: "omarchy.monitor"

    function brightness(percent: string): string { return root.brightnessIpc(percent) }
    function state(): string { return root.stateIpc() }
    function open() { root.open() }
    function close() { root.close() }
    function toggle() { root.toggle() }
    function show() { root.open() }
    function hide() { root.close() }
  }

  // ---- Actions ----
  function refresh() {
    if (!stateProc.running) stateProc.running = true
  }

  function selectDisplay(name) {
    if (!name || name === root.selectedName) return
    root.selectedName = name
    root.readBrightness()
  }

  function runAtlas(args, label) {
    if (!selected && args[0] === "set") return
    var command = [root.atlasDisplay].concat(args)
    if (actionProc.running) {
      root.pendingAction = { command: command, label: label }
      return
    }
    root.statusIsError = false
    root.statusText = label
    actionProc.command = command
    actionProc.running = true
  }

  function setRotation(transform) {
    runAtlas(["set", selected.name, "--transform", String(transform)], "ROTATING…")
  }

  function setScale(scale) {
    runAtlas(["set", selected.name, "--scale", String(scale)], "SCALING…")
  }

  function setResolution(res) {
    // Best refresh rate the display offers at that resolution.
    runAtlas(["set", selected.name, "--mode", res.width + "x" + res.height + "@" + res.bestRefresh.toFixed(2)], "CHANGING RESOLUTION…")
  }

  function setRefresh(rate) {
    runAtlas(["set", selected.name, "--mode", selected.width + "x" + selected.height + "@" + rate.toFixed(2)], "CHANGING REFRESH RATE…")
  }

  function activatePower(item) {
    if (item === "enabled") {
      if (root.powerBlockReason !== "") {
        showError(root.powerBlockReason === "no-other" ? "NO OTHER MONITORS DETECTED" : "NO OTHER DISPLAY IS ON")
        return
      }
      runAtlas(["set", selected.name, "--enabled", selected.enabled ? "0" : "1"], selected.enabled ? "TURNING OFF…" : "TURNING ON…")
    } else if (item === "dockPolicy") {
      runAtlas(["dock-policy", root.laptopOffWhenDocked ? "off" : "on"], "SAVING…")
    }
  }

  function openArrange() {
    Quickshell.execDetached([root.atlasDisplay, "arrange"])
    root.close()
  }

  function showError(text) {
    root.statusIsError = true
    root.statusText = text
    statusClear.restart()
  }

  // ---- Brightness ----
  function readBrightness() {
    if (!selected) return
    brightnessProc.command = ["omarchy-brightness-display", "--monitor", selected.name]
    root.brightnessFor = selected.name
    if (!brightnessProc.running) brightnessProc.running = true
  }

  function setBrightness(value) {
    if (!selected) return
    var percent = Model.clampBrightness(value)
    root.brightnessPercent = percent
    root.pendingBrightnessPercent = percent
    if (setBrightnessProc.running) {
      root.brightnessSetQueued = true
      return
    }
    root.brightnessSetQueued = false
    setBrightnessProc.command = ["omarchy-brightness-display", "--no-osd", "--monitor", selected.name, percent + "%"]
    setBrightnessProc.running = true
  }

  function previewBrightness(value) {
    root.brightnessPercent = Model.clampBrightness(value)
    brightnessDebounce.restart()
  }

  function adjustBrightness(delta) {
    if (!brightnessAvailable) return
    setBrightness(root.brightnessPercent + delta)
  }

  function showBrightnessOsd(percent) {
    if (!bar || !bar.shell) return
    bar.shell.summon("omarchy.osd", JSON.stringify({ icon: "brightness", value: percent }))
  }

  function brightnessName(percent) {
    return Model.brightnessName(percent)
  }

  function effectiveScale(scale) {
    return selected ? Model.cleanScale(scale, selected.width, selected.height) : Model.normalizeScale(scale)
  }

  // ---- Text size (unchanged) ----
  function nearestTextStop(px) {
    var best = 0
    var bestDist = 1e9
    for (var i = 0; i < textSizeStops.length; i++) {
      var d = Math.abs(textSizeStops[i] - px)
      if (d < bestDist) { bestDist = d; best = i }
    }
    return best
  }

  function currentTextIndex() {
    return textSizePreviewIndex >= 0 ? textSizePreviewIndex : nearestTextStop(Style.font.baseSize)
  }

  function displayedTextPx() {
    return textSizePreviewIndex >= 0 ? textSizeStops[textSizePreviewIndex] : Style.font.baseSize
  }

  function setTextSize(px) {
    textScaleProc.command = ["omarchy-display-text-size", String(px)]
    if (!textScaleProc.running) textScaleProc.running = true
  }

  function adjustTextSize(deltaSteps) {
    var idx = Math.max(0, Math.min(textSizeStops.length - 1, currentTextIndex() + deltaSteps))
    markReflowing()
    textSizePreviewIndex = idx
    setTextSize(textSizeStops[idx])
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Component.onCompleted: refresh()

  onOpenedChanged: {
    if (opened) {
      // Start on the display under the pointer, like Omarchy's panel did.
      root.selectedName = ""
      refresh()
      focusSection = "tabs"
      selectedIndex = 0
      cursorActive = false
    }
  }

  onDisplaysChanged: clampCursor()
  onVisibleSectionsChanged: clampCursor()

  Timer {
    interval: 3000
    running: root.opened
    repeat: true
    onTriggered: root.refresh()
  }

  Timer {
    id: statusClear
    interval: 4500
    onTriggered: { root.statusText = ""; root.statusIsError = false }
  }

  Process {
    id: stateProc
    command: [root.atlasDisplay, "state"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var data = null
        try { data = JSON.parse(String(text || "")) } catch (e) { return }
        if (!data || !data.displays) return
        root.displays = Model.withUniqueLabels(data.displays)
        root.laptopOffWhenDocked = !!data.laptopOffWhenDocked
        root.docked = !!data.docked
        var keep = false
        for (var i = 0; i < root.displays.length; i++)
          if (root.displays[i].name === root.selectedName) keep = true
        if (!keep) {
          var pick = root.displays.length > 0 ? root.displays[0].name : ""
          for (var j = 0; j < root.displays.length; j++)
            if (root.displays[j].focused) pick = root.displays[j].name
          root.selectedName = pick
        }
        if (root.brightnessFor !== root.selectedName) root.readBrightness()
      }
    }
  }

  Process {
    id: brightnessProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var v = parseInt(String(text || "").trim(), 10)
        root.brightnessAvailable = !isNaN(v)
        if (!isNaN(v) && !setBrightnessProc.running) root.brightnessPercent = Math.max(0, Math.min(100, v))
      }
    }
  }

  Timer {
    id: brightnessDebounce
    interval: 180
    onTriggered: root.setBrightness(root.brightnessPercent)
  }

  Process {
    id: setBrightnessProc
    stdout: StdioCollector { waitForEnd: true }
    onRunningChanged: {
      if (running) return
      if (root.brightnessSetQueued) root.setBrightness(root.pendingBrightnessPercent)
    }
  }

  Process {
    id: actionProc
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector {
      id: actionErr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        var msg = String(actionErr.text || "").trim().split("\n").pop()
        root.showError((msg || "COULDN'T APPLY THAT").toUpperCase())
      } else {
        root.statusText = ""
      }
      if (root.pendingAction) {
        var next = root.pendingAction
        root.pendingAction = null
        root.statusText = next.label
        actionProc.command = next.command
        actionProc.running = true
        return
      }
      root.refresh()
    }
  }

  Process {
    id: textScaleProc
    stdout: StdioCollector { waitForEnd: true }
  }

  Timer {
    id: reflowSettle
    interval: 300
    onTriggered: root.reflowingText = false
  }

  Connections {
    target: Style
    function onFontBaseSizeChanged() {
      root.markReflowing()
      if (root.textSizePreviewIndex >= 0
          && root.nearestTextStop(Style.font.baseSize) === root.textSizePreviewIndex)
        root.textSizePreviewIndex = -1
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: Quickshell.screens.length > 1 ? "󰍺" : "󰍹"
    onPressed: function(b) { root.toggle() }
    onWheelMoved: function(delta) {
      if (!root.brightnessAvailable) return
      var wheel = Util.wheelSteps(root.wheelAccumulator, delta)
      root.wheelAccumulator = wheel.remainder
      if (wheel.steps === 0) return
      root.setBrightness(root.brightnessPercent + wheel.steps * 5)
      root.showBrightnessOsd(root.brightnessPercent)
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(640))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (dy !== 0) root.moveCursor(dy)
        else if (dx !== 0) root.moveCursorH(dx)
      }
      onActivateRequested: if (root.cursorActive) root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      ScrollView {
        id: scrollArea
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: panelColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        Binding {
          target: scrollArea.contentItem
          property: "interactive"
          value: panelColumn.implicitHeight > scrollArea.height
        }

        Column {
          id: panelColumn
          width: scrollArea.availableWidth
          spacing: Style.space(14)

          // ---------- Hero: icon · title/status · Arrange ----------
          Item {
            width: parent.width
            implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, arrangeButton.implicitHeight)

            Text {
              id: heroIcon
              textFormat: Text.PlainText
              text: root.displays.length > 1 ? "󰍺" : "󰍹"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.display
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Column {
              id: heroLabels
              anchors.left: heroIcon.right
              anchors.leftMargin: Style.space(14)
              anchors.right: arrangeButton.left
              anchors.rightMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                text: "Display"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
                elide: Text.ElideRight
                width: parent.width
              }

              Text {
                textFormat: Text.PlainText
                text: {
                  if (root.statusText !== "") return root.statusText
                  if (!root.selected) return "NO DISPLAYS"
                  if (!root.selected.enabled) return root.selected.label.toUpperCase() + " · OFF"
                  return (root.selected.label + " · " + root.selected.width + "×" + root.selected.height
                          + " · " + Model.formatRefresh(root.selected.refresh) + "HZ").toUpperCase()
                }
                color: root.statusIsError ? root.warningColor : Qt.darker(root.bar.foreground, 1.4)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.2
                elide: Text.ElideRight
                width: parent.width
              }
            }

            Button {
              id: arrangeButton
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: "Arrange"
              iconText: "󰍺"
              tooltipText: "Drag displays into position (nwg-displays)"
              fontSize: Style.font.caption
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              bordered: true
              hasCursor: root.cursorActive && root.focusSection === "arrange"
              onClicked: root.openArrange()
              onHovered: function(h) { if (h) root.hoverCursor("arrange", 0) }
            }
          }

          // ---------- Display tabs ----------
          PanelSeparator {
            visible: root.displays.length > 1
            foreground: root.bar.foreground
          }

          Column {
            width: parent.width
            spacing: Style.space(10)
            visible: root.displays.length > 1

            Item {
              width: parent.width
              implicitHeight: displaysHeader.implicitHeight

              PanelSectionHeader {
                id: displaysHeader
                text: "DISPLAYS"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                textFormat: Text.PlainText
                text: root.selected ? root.selected.name : ""
                color: Qt.darker(root.bar.foreground, 1.4)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.right: parent.right
                anchors.rightMargin: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            ChipRow {
              section: "tabs"
              model: root.displays
              labelFor: function(d) { return (d.internal ? "󰌢 " : "󰍹 ") + d.label + (d.enabled ? "" : " (off)") }
              isActive: function(d, i) { return root.selected && d.name === root.selected.name }
              onChosen: function(d, i) { root.selectDisplay(d.name) }
            }
          }

          // ---------- Brightness ----------
          PanelSeparator {
            visible: root.brightnessAvailable && root.selectedOn
            foreground: root.bar.foreground
          }

          Column {
            visible: root.brightnessAvailable && root.selectedOn
            width: parent.width
            spacing: Style.space(6)

            Item {
              width: parent.width
              implicitHeight: Math.max(brightnessHeader.implicitHeight, brightnessValue.implicitHeight)

              PanelSectionHeader {
                id: brightnessHeader
                text: "BRIGHTNESS"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: brightnessValue
                textFormat: Text.PlainText
                text: {
                  var p = Math.round(brightnessSlider.dragging ? brightnessSlider.liveValue : root.brightnessPercent)
                  return root.brightnessName(p).toUpperCase() + " · " + p + "%"
                }
                color: Qt.darker(root.bar.foreground, 1.4)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.right: parent.right
                anchors.rightMargin: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            CursorSurface {
              id: brightnessRow
              width: parent.width
              height: brightnessSlider.implicitHeight + Style.spacing.controlGap
              hasCursor: root.cursorActive && root.focusSection === "brightness"
              onHasCursorChanged: if (hasCursor) root.ensureCursorVisible(brightnessRow)
              foreground: root.bar.foreground
              outline: true

              PanelSlider {
                id: brightnessSlider
                bar: root.bar
                anchors.fill: parent
                anchors.leftMargin: Style.space(6)
                anchors.rightMargin: Style.space(6)
                minimum: 1
                maximum: 100
                step: 1
                value: root.brightnessPercent
                integer: true
                onMoved: function(v) { root.previewBrightness(v) }
                onReleased: function(v) {
                  brightnessDebounce.stop()
                  root.setBrightness(v)
                }
              }

              HoverHandler {
                onHoveredChanged: if (hovered) root.hoverCursor("brightness", -1)
              }
            }
          }

          // ---------- Rotation ----------
          PanelSeparator {
            visible: root.selectedOn
            foreground: root.bar.foreground
          }

          Column {
            visible: root.selectedOn
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: "ROTATION"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
            }

            ChipRow {
              section: "rotation"
              model: root.rotations
              labelFor: function(r) { return r.label }
              isActive: function(r, i) { return root.selected && root.selected.transform === r.transform }
              onChosen: function(r, i) { root.setRotation(r.transform) }
            }
          }

          // ---------- Scale ----------
          PanelSeparator {
            visible: root.selectedOn
            foreground: root.bar.foreground
          }

          Column {
            visible: root.selectedOn
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: "SCALE"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
            }

            ChipRow {
              section: "scale"
              model: root.scaleValues
              labelFor: function(s) { return root.effectiveScale(s) + "x" }
              isActive: function(s, i) { return root.activeIndexIn("scale") === i }
              onChosen: function(s, i) { root.setScale(s) }
            }
          }

          // ---------- Resolution ----------
          PanelSeparator {
            visible: root.selectedOn && root.resolutions.length > 1
            foreground: root.bar.foreground
          }

          Column {
            visible: root.selectedOn && root.resolutions.length > 1
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: "RESOLUTION"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
            }

            ChipRow {
              section: "resolution"
              model: root.resolutions
              columns: 3
              labelFor: function(r) { return r.width + "×" + r.height }
              isActive: function(r, i) { return root.selected && r.width === root.selected.width && r.height === root.selected.height }
              onChosen: function(r, i) { root.setResolution(r) }
            }
          }

          // ---------- Refresh rate ----------
          PanelSeparator {
            visible: root.selectedOn && root.refreshRates.length > 1
            foreground: root.bar.foreground
          }

          Column {
            visible: root.selectedOn && root.refreshRates.length > 1
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: "REFRESH RATE"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
            }

            ChipRow {
              section: "refresh"
              model: root.refreshRates
              labelFor: function(r) { return Model.formatRefresh(r) + " Hz" }
              isActive: function(r, i) { return root.activeIndexIn("refresh") === i }
              onChosen: function(r, i) { root.setRefresh(r) }
            }
          }

          // ---------- Power ----------
          PanelSeparator {
            visible: root.powerItems.length > 0
            foreground: root.bar.foreground
          }

          Column {
            visible: root.powerItems.length > 0
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: "POWER"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
            }

            ChipRow {
              section: "power"
              model: root.powerItems
              columns: 1
              labelFor: function(item) {
                if (item === "enabled") {
                  if (root.powerBlockReason !== "") return "󰄬  Display on — can't turn off"
                  return root.selected && root.selected.enabled ? "󰄬  Display on — click to turn off" : "󰅖  Display off — click to turn on"
                }
                return (root.laptopOffWhenDocked ? "󰄬  " : "󰄱  ") + "Turn laptop screen off when docked (2+ displays)"
              }
              isActive: function(item, i) {
                return item === "enabled" ? (root.selected && root.selected.enabled) : root.laptopOffWhenDocked
              }
              isEnabled: function(item, i) { return item !== "enabled" || root.powerBlockReason === "" }
              onChosen: function(item, i) { root.activatePower(item) }
            }

            Text {
              visible: root.powerBlockText !== ""
              width: parent.width
              textFormat: Text.PlainText
              text: "⚠  " + root.powerBlockText
              wrapMode: Text.WordWrap
              color: root.warningColor
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              leftPadding: Style.space(6)
              rightPadding: Style.space(6)
            }
          }

          // ---------- Text size ----------
          PanelSeparator {
            foreground: root.bar.foreground
          }

          Column {
            width: parent.width
            spacing: Style.space(6)

            Item {
              width: parent.width
              implicitHeight: Math.max(textSizeHeader.implicitHeight, textSizePx.implicitHeight)

              PanelSectionHeader {
                id: textSizeHeader
                text: "TEXT SIZE · ALL DISPLAYS"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: textSizePx
                textFormat: Text.PlainText
                text: (textSizeSlider.dragging
                       ? root.textSizeStops[Math.round(textSizeSlider.liveValue)]
                       : root.displayedTextPx()) + "px"
                color: Qt.darker(root.bar.foreground, 1.4)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.right: parent.right
                anchors.rightMargin: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            CursorSurface {
              id: textSizeRow
              width: parent.width
              height: textSizeSlider.implicitHeight + Style.spacing.controlGap
              hasCursor: root.cursorActive && root.focusSection === "textsize"
              onHasCursorChanged: if (hasCursor) root.ensureCursorVisible(textSizeRow)
              foreground: root.bar.foreground
              outline: true

              PanelSlider {
                id: textSizeSlider
                bar: root.bar
                anchors.fill: parent
                anchors.leftMargin: Style.space(6)
                anchors.rightMargin: Style.space(6)
                minimum: 0
                maximum: root.textSizeStops.length - 1
                step: 1
                integer: true
                tickCount: root.textSizeStops.length
                value: root.currentTextIndex()
                onReleased: function(v) { root.setTextSize(root.textSizeStops[Math.round(v)]) }
              }

              HoverHandler {
                onHoveredChanged: if (hovered) root.hoverCursor("textsize", -1)
              }
            }
          }

          Item {
            width: parent.width
            height: Style.space(4)
          }
        }
      }
    }
  }

  // A wrapping row of option buttons bound to one keyboard section.
  component ChipRow: Grid {
    id: chips
    property string section: ""
    property var model: []
    property var labelFor: function(item) { return String(item) }
    property var isActive: function(item, index) { return false }
    property var isEnabled: function(item, index) { return true }
    signal chosen(var item, int index)

    width: parent ? parent.width : 0
    columns: Math.max(1, Math.min(model.length, 4))
    spacing: Style.spacing.xs
    readonly property real cellWidth: (width - spacing * (columns - 1)) / columns

    Repeater {
      model: chips.model

      Button {
        id: chip
        required property var modelData
        required property int index

        width: chips.cellWidth
        text: chips.labelFor(modelData)
        fontSize: Style.font.caption
        foreground: root.bar.foreground
        fontFamily: root.bar.fontFamily
        horizontalPadding: Style.spacing.sm
        verticalPadding: Style.spacing.controlPaddingY
        bordered: true
        leftAlign: chips.columns === 1
        active: chips.isActive(modelData, index)
        // A disabled chip can't be clicked; keyboard activation still reaches activatePower,
        // which shows the same warning in the header instead of acting.
        enabled: chips.isEnabled(modelData, index)
        opacity: enabled ? 1.0 : 0.45
        hasCursor: root.cursorActive && root.focusSection === chips.section && root.selectedIndex === index
        onHasCursorChanged: if (hasCursor) root.ensureCursorVisible(chip)
        onClicked: chips.chosen(modelData, index)
        onHovered: function(h) { if (h) root.hoverCursor(chips.section, chip.index) }
      }
    }
  }
}
