import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Razer DeathAdder V2 Pro battery widget — v2 layout.
//
// Installed side by side with `naoko.razer-battery`: this plugin reads only
// files inside its own directory and can be removed without touching v1.
//
// Layout: one hero (percentage + status), one battery bar, then a 2x2 stat
// grid. Every fact appears once; the bar icon carries the level glyph and a
// hover tooltip so the panel does not need to show the number twice.
Panel {
  id: root

  moduleName: "naoko.razer-battery-v2"
  ipcTarget: "naoko.razer-battery-v2"
  manageIpc: false

  property int batteryLevel: 0
  property bool isCharging: false
  property int dpi: 0
  property int pollRate: 0
  property bool available: false
  property string firmware: ""
  property string driver: ""
  property bool fullNotified: false

  // Kept from v1 so the widget still reads as Naoko's in a themed bar.
  readonly property string deviceName: "Razer DeathAdder V2 Pro"
  readonly property color accentColor: "#c78bf5"
  readonly property color ink: root.bar ? root.bar.foreground : Commons.Color.foreground
  readonly property color mutedInk: Commons.Util.alpha(root.ink, 0.7)
  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family

  readonly property bool lowBattery: root.available && !root.isCharging && root.batteryLevel <= 20
  readonly property color levelColor: root.lowBattery
    ? Commons.Color.urgent
    : root.available ? root.accentColor : root.mutedInk

  // Resolve next to this QML file so the plugin still works if its directory
  // is moved; accept both file:// and the shell's qs:// loading scheme.
  readonly property string scriptPath: decodeURIComponent(
    Qt.resolvedUrl("battery.py").toString().replace(/^[a-z]+:\/\//, "")
  )

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // Ten-band ladder for the bar glyph. This is the table Omarchy itself ships
  // for batteries, so the icon reads the same as the system one.
  // (Same codepoints as hancore.shibumi.state BarSymbols.js.)
  function batteryGlyph() {
    if (!root.available) return "󰍽"
    var chargingIcons = ["󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"]
    var defaultIcons = ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
    var index = Math.max(0, Math.min(9, Math.floor(root.batteryLevel / 10)))
    if (root.isCharging && root.batteryLevel >= 100) return "󰂅"
    return root.isCharging ? chargingIcons[index] : defaultIcons[index]
  }

  readonly property string tooltipText: !root.available
    ? root.deviceName + " · not connected"
    : root.isCharging
      ? root.batteryLevel + "% · charging"
      : root.batteryLevel + "%"

  // --- Sampling -----------------------------------------------------------

  Process {
    id: batteryProcess

    command: ["/usr/bin/python3", root.scriptPath]
    running: true

    stdout: SplitParser {
      onRead: data => {
        const value = data.trim()

        if (value === "") {
          root.available = false
          return
        }

        const parts = value.split("|")

        if (parts.length < 2)
          return

        const level = parseInt(parts[0])

        if (isNaN(level))
          return

        root.batteryLevel = Math.min(Math.max(level, 0), 100)
        root.isCharging = parts[1] === "1"

        if (parts.length >= 3) {
          const dpiValue = parseInt(parts[2])

          if (!isNaN(dpiValue))
            root.dpi = dpiValue
        }

        if (parts.length >= 4) {
          const pollValue = parseInt(parts[3])

          if (!isNaN(pollValue))
            root.pollRate = pollValue
        }

        if (parts.length >= 5)
          root.firmware = parts[4]

        if (parts.length >= 6)
          root.driver = parts[5]

        if (!root.isCharging) {
          root.fullNotified = false
        } else if (root.batteryLevel >= 100 && !root.fullNotified) {
          root.fullNotified = true
          fullNotify.running = true
        }

        root.available = true
      }
    }
  }

  Process {
    id: fullNotify

    command: [
      "notify-send",
      root.deviceName,
      "Fully charged. You can unplug it."
    ]
  }

  Timer {
    interval: 7000
    running: true
    repeat: true

    onTriggered: {
      if (!batteryProcess.running)
        batteryProcess.running = true
    }
  }

  // --- Bar button ---------------------------------------------------------

  BarIconButton {
    id: button

    anchors.fill: parent
    bar: root.bar

    text: root.batteryGlyph()
    tooltipText: root.tooltipText

    // Same accent as v1's bar icon; only a low battery overrides it.
    foreground: root.accentColor
    active: root.lowBattery
    activeColor: Commons.Color.urgent

    onPressed: function (buttonCode) {
      if (buttonCode === Qt.LeftButton)
        root.toggle()
    }
  }

  // --- Popup --------------------------------------------------------------

  KeyboardPanel {
    id: panel

    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    gap: Style.space(4)
    focusTarget: panel.loadedContent

    contentWidth: panel.fittedContentWidth(Style.space(300))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight, Style.space(420))

    content: PanelKeyCatcher {
      id: keyCatcher

      anchors.fill: parent
      implicitHeight: column.implicitHeight

      onCloseRequested: root.close()

      Column {
        id: column

        width: parent.width
        spacing: Style.space(10)

        // --- Header -------------------------------------------------------

        Item {
          width: parent.width
          implicitHeight: Math.max(headerLabel.implicitHeight, closeButton.height)

          PanelSectionHeader {
            id: headerLabel

            text: root.deviceName
            foreground: root.ink
            fontFamily: root.fontFamily
            fontSize: Style.font.body

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }

          CursorSurface {
            id: closeButton

            width: Style.space(22)
            height: width

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            hasCursor: closeArea.containsMouse
            foreground: root.ink
            accent: root.accentColor

            Text {
              anchors.centerIn: parent

              text: "󰅖"
              textFormat: Text.PlainText
              color: closeButton.hasCursor ? root.ink : root.mutedInk
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              renderType: Text.NativeRendering
            }

            MouseArea {
              id: closeArea

              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor

              onClicked: root.close()
            }
          }
        }

        PanelSeparator {
          foreground: root.ink
        }

        // --- Empty state --------------------------------------------------

        Column {
          visible: !root.available

          width: parent.width
          spacing: Style.space(6)

          Item {
            width: 1
            height: Style.space(10)
          }

          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter

            text: "󰍽"
            textFormat: Text.PlainText
            color: root.mutedInk
            opacity: 0.6
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
            renderType: Text.NativeRendering
          }

          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter

            text: "Mouse not connected"
            textFormat: Text.PlainText
            color: root.ink
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
            renderType: Text.NativeRendering
          }

          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter

            text: "Wake the mouse or plug in the USB cable."
            textFormat: Text.PlainText
            color: root.mutedInk
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
            renderType: Text.NativeRendering
          }

          Item {
            width: 1
            height: Style.space(6)
          }
        }

        // --- Hero + grid --------------------------------------------------

        Column {
          visible: root.available

          width: parent.width
          spacing: Style.space(8)

          Item {
            width: parent.width
            implicitHeight: heroLabels.implicitHeight

            Text {
              id: heroGlyph

              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter

              text: root.batteryGlyph()
              textFormat: Text.PlainText
              color: root.levelColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
              renderType: Text.NativeRendering
            }

            Column {
              id: heroLabels

              anchors.left: heroGlyph.right
              anchors.leftMargin: Style.space(14)
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(1)

              Text {
                text: root.batteryLevel + "%"
                textFormat: Text.PlainText
                color: root.levelColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.displayLarge
                font.bold: true
                renderType: Text.NativeRendering
              }

              Text {
                text: root.isCharging ? "Charging · Wired" : "Wireless"
                textFormat: Text.PlainText
                color: root.mutedInk
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.2
                renderType: Text.NativeRendering
              }
            }
          }

          Rectangle {
            width: parent.width
            height: Style.space(6)
            radius: height / 2
            color: Commons.Util.alpha(root.levelColor, 0.18)
            clip: true

            Rectangle {
              width: parent.width * Math.max(0, Math.min(100, root.batteryLevel)) / 100
              height: parent.height
              radius: parent.radius
              color: root.levelColor

              Behavior on width {
                NumberAnimation {
                  duration: Style.duration(300)
                  easing.type: Easing.OutCubic
                }
              }
            }
          }

          PanelSeparator {
            foreground: root.ink
          }

          Grid {
            id: stats

            width: parent.width
            columns: 2
            columnSpacing: Style.space(8)
            rowSpacing: Style.space(8)

            StatCell {
              width: (stats.width - stats.columnSpacing) / 2
              visible: root.dpi > 0
              label: "DPI"
              value: root.dpi
            }

            StatCell {
              width: (stats.width - stats.columnSpacing) / 2
              visible: root.pollRate > 0
              label: "Polling rate"
              value: root.pollRate + " Hz"
            }

            StatCell {
              width: (stats.width - stats.columnSpacing) / 2
              visible: root.firmware !== ""
              label: "Firmware"
              value: root.firmware
            }

            StatCell {
              width: (stats.width - stats.columnSpacing) / 2
              visible: root.driver !== ""
              label: "Driver"
              value: root.driver
            }
          }
        }
      }
    }
  }

  // Value above, small-caps label below — the same read as the CPU and AI
  // panels, so metadata stays scannable instead of looking like a form.
  component StatCell: Column {
    id: cell

    required property string label
    required property var value

    spacing: Style.space(2)

    Text {
      width: parent.width

      text: String(cell.value)
      textFormat: Text.PlainText
      elide: Text.ElideRight
      color: root.ink
      font.family: root.fontFamily
      font.pixelSize: Style.font.subtitle
      renderType: Text.NativeRendering
    }

    Text {
      width: parent.width

      text: cell.label.toUpperCase()
      textFormat: Text.PlainText
      elide: Text.ElideRight
      color: root.mutedInk
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      font.letterSpacing: 1
      renderType: Text.NativeRendering
    }
  }
}
