import QtQuick
import QtQuick.Shapes
import qs.Commons

// A.T.L.A.S standby screen: the lock-screen take on the terminal screensaver
// (branding/screensaver.txt). Everything here is a render-thread animator or a
// static item, so it stays cheap while the session sits locked.
Item {
  id: root

  property bool animating: false
  property date now: new Date()

  readonly property color deep: "#1478e6"
  readonly property color mid: "#35c4ff"
  readonly property color pale: "#a8ecff"
  readonly property real ringSize: Math.min(width, height) * 0.78
  readonly property int cornerLen: Math.round(Math.min(width, height) * 0.08)

  Rectangle {
    anchors.fill: parent
    gradient: Gradient {
      GradientStop { position: 0.0; color: "#03070f" }
      GradientStop { position: 0.5; color: "#06111f" }
      GradientStop { position: 1.0; color: "#03070f" }
    }
  }

  // Rotating HUD rings behind the wordmark.
  Item {
    id: rings
    width: root.ringSize
    height: root.ringSize
    anchors.centerIn: parent
    opacity: 0.35

    Shape {
      id: outerRing
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeColor: root.deep
        strokeWidth: 2
        fillColor: "transparent"
        strokeStyle: ShapePath.DashLine
        dashPattern: [14, 10]
        PathAngleArc {
          centerX: rings.width / 2; centerY: rings.height / 2
          radiusX: rings.width / 2 - 2; radiusY: rings.height / 2 - 2
          startAngle: 0; sweepAngle: 360
        }
      }
      RotationAnimator on rotation {
        from: 0; to: 360; duration: 90000
        loops: Animation.Infinite
        running: root.animating
      }
    }

    Shape {
      anchors.fill: parent
      anchors.margins: rings.width * 0.08
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeColor: root.mid
        strokeWidth: 3
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc {
          centerX: rings.width * 0.42; centerY: rings.height * 0.42
          radiusX: rings.width * 0.42 - 3; radiusY: rings.height * 0.42 - 3
          startAngle: -20; sweepAngle: 70
        }
      }
      ShapePath {
        strokeColor: root.mid
        strokeWidth: 3
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc {
          centerX: rings.width * 0.42; centerY: rings.height * 0.42
          radiusX: rings.width * 0.42 - 3; radiusY: rings.height * 0.42 - 3
          startAngle: 160; sweepAngle: 70
        }
      }
      RotationAnimator on rotation {
        from: 360; to: 0; duration: 40000
        loops: Animation.Infinite
        running: root.animating
      }
    }

    Rectangle {
      anchors.fill: parent
      anchors.margins: rings.width * 0.2
      radius: width / 2
      color: "transparent"
      border.color: root.deep
      border.width: 1
      opacity: 0.7
    }
  }

  Column {
    anchors.centerIn: parent
    spacing: Math.round(root.height * 0.025)

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      textFormat: Text.PlainText
      text: "◢◤   SYSTEM STANDBY   ◥◣"
      color: root.mid
      font.family: Style.font.family
      font.pixelSize: Math.max(14, Math.round(root.height * 0.022))
      font.letterSpacing: 6
    }

    Image {
      id: wordmark
      anchors.horizontalCenter: parent.horizontalCenter
      source: "wordmark.png"
      width: Math.min(root.width * 0.62, 1100)
      fillMode: Image.PreserveAspectFit
      smooth: true
      mipmap: true

      SequentialAnimation on opacity {
        running: root.animating
        loops: Animation.Infinite
        NumberAnimation { from: 1.0; to: 0.72; duration: 2600; easing.type: Easing.InOutSine }
        NumberAnimation { from: 0.72; to: 1.0; duration: 2600; easing.type: Easing.InOutSine }
      }
    }

    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      width: wordmark.width * 0.55
      height: 2
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: 0.5; color: root.mid }
        GradientStop { position: 1.0; color: "transparent" }
      }
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      textFormat: Text.PlainText
      text: Qt.formatDateTime(root.now, "HH:mm")
      color: root.pale
      font.family: Style.font.family
      font.pixelSize: Math.max(32, Math.round(root.height * 0.075))
      font.letterSpacing: 8
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      textFormat: Text.PlainText
      text: Qt.formatDateTime(root.now, "dddd d MMMM yyyy").toUpperCase()
      color: root.mid
      opacity: 0.85
      font.family: Style.font.family
      font.pixelSize: Math.max(13, Math.round(root.height * 0.019))
      font.letterSpacing: 5
    }

    Item { width: 1; height: Math.round(root.height * 0.03) }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      textFormat: Text.PlainText
      text: "PRESS ANY KEY TO RESUME"
      color: root.pale
      font.family: Style.font.family
      font.pixelSize: Math.max(12, Math.round(root.height * 0.016))
      font.letterSpacing: 6

      SequentialAnimation on opacity {
        running: root.animating
        loops: Animation.Infinite
        NumberAnimation { from: 0.9; to: 0.25; duration: 1400; easing.type: Easing.InOutQuad }
        NumberAnimation { from: 0.25; to: 0.9; duration: 1400; easing.type: Easing.InOutQuad }
      }
    }
  }

  // Slow scan line sweeping the screen.
  Rectangle {
    id: scan
    width: parent.width
    height: Math.max(60, parent.height * 0.08)
    opacity: 0.12
    gradient: Gradient {
      GradientStop { position: 0.0; color: "transparent" }
      GradientStop { position: 0.8; color: root.mid }
      GradientStop { position: 0.97; color: root.pale }
      GradientStop { position: 1.0; color: "transparent" }
    }
    YAnimator on y {
      from: -scan.height; to: root.height
      duration: 7000
      loops: Animation.Infinite
      running: root.animating
    }
  }

  // Frame corners, as in the terminal art.
  Repeater {
    model: 4
    Item {
      readonly property bool isRight: index % 2 === 1
      readonly property bool isBottom: index >= 2
      x: isRight ? root.width - width - 40 : 40
      y: isBottom ? root.height - height - 40 : 40
      width: root.cornerLen
      height: root.cornerLen
      opacity: 0.8

      Rectangle {
        width: parent.width; height: 3
        y: parent.isBottom ? parent.height - 3 : 0
        color: root.mid
      }
      Rectangle {
        width: 3; height: parent.height
        x: parent.isRight ? parent.width - 3 : 0
        color: root.mid
      }
    }
  }

  Timer {
    interval: 1000
    repeat: true
    triggeredOnStart: true
    // The password view reads this clock too, so it ticks even when hidden.
    running: true
    onTriggered: root.now = new Date()
  }
}
