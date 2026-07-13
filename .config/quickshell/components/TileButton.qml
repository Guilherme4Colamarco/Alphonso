import QtQuick
import ".."

Rectangle {
    property string icon
    property string label
    property string sublabel
    property bool active: false
    signal clicked()

    height: Aesthetics.rowHeight
    radius: Aesthetics.radius(Aesthetics.cardRadius, height)
    color: active ? Colors.a(Colors.accent, 0.12) : tileMa.containsMouse ? Colors.a(Colors.fg, 0.06) : Colors.a(Colors.fg, 0.025)
    border.width: active ? 1 : Aesthetics.borderWidth
    border.color: Colors.a(Colors.accent, 0.2)

    Behavior on color  { ColorAnimation { duration: Animations.fast } }
    Behavior on radius { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }

    Row {
        anchors { left: parent.left; leftMargin: Metrics.dp(14); verticalCenter: parent.verticalCenter }
        spacing: Metrics.dp(12)

        Text {
            text:  icon
            color: active ? Colors.accent : Colors.a(Colors.fg, 0.45)
            font { pixelSize: Metrics.sp(18); family: "JetBrainsMono Nerd Font" }
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Metrics.dp(2)
            Text {
                text:  label
                color: active ? Colors.accent : Colors.fg
                font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font"; bold: true }
            }

            Text {
                text:  sublabel
                color: Colors.a(Colors.fg, 0.3)
                font { pixelSize: Metrics.sp(8); family: "JetBrainsMono Nerd Font" }
            }
        }
    }

    Text {
        anchors { right: parent.right; rightMargin: Metrics.dp(14); verticalCenter: parent.verticalCenter }
        text:  "󰅂"
        color: Colors.a(Colors.fg, 0.25)
        font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font" }
    }

    MouseArea {
        id: tileMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: parent.clicked()
    }
}
