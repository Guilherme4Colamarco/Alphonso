import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    property string handleStyle: "bump"
    property string batteryText: ""
    property bool batteryCharging: false
    property int batteryLevel: 0
    property string statusText: ""
    property string fontFamily: "JetBrainsMono Nerd Font"
    property bool showBattery: false
    property bool compact: false

    function a(c, o) { return Qt.rgba(c.r, c.g, c.b, o) }

    signal handleStyleRequested(string style)

    Layout.fillWidth: true
    Layout.preferredHeight: root.compact ? 15 : 17
    spacing: root.compact ? 7 : 8

    // Minimalist pill toggle
    Rectangle {
        id: toggle

        Layout.preferredWidth: root.compact ? 20 : 24
        Layout.preferredHeight: root.compact ? 10 : 12
        radius: height / 2
        color: a(Colors.fg, 0.04)
        border.width: 1
        border.color: a(Colors.accent, 0.15)

        Rectangle {
            id: dot

            width: parent.height - 4
            height: width
            radius: width / 2
            color: root.handleStyle === "bump" ? Colors.accent : a(Colors.fg, 0.35)
            y: 2
            x: root.handleStyle === "bump" ? 2 : parent.width - width - 2

            Behavior on x {
                NumberAnimation { duration: Animations.snap; easing.type: Easing.OutCubic }
            }

            Behavior on color {
                ColorAnimation { duration: Animations.snap }
            }
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: Metrics.dp(-4)
hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.handleStyleRequested(root.handleStyle === "bump" ? "strip" : "bump")
        }
    }

    Item {
        Layout.fillWidth: true

        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.statusText
            color: a(Colors.fg, 0.45)
            visible: root.statusText !== ""
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            font.family: root.fontFamily
            font.pixelSize: root.compact ? 9 : 10
            font.bold: true
        }
    }

    Row {
        spacing: Metrics.dp(3)
visible: root.showBattery && root.batteryLevel > 0

        MIcon {
            name: root.batteryCharging ? "󰂄" : root.batteryLevel <= 20 ? "󰂃" : "󰁹"
            size: root.compact ? 12 : 13
            color: root.batteryCharging ? Colors.green : root.batteryLevel <= 20 ? Colors.red : Colors.accent
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.batteryLevel + "%"
            color: Colors.fg
            font.family: root.fontFamily
            font.pixelSize: root.compact ? 9 : 10
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
