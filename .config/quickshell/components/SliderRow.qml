import QtQuick
import ".."

Item {
    property string icon
    property color  iconColor
    property int    value
    property int    minValue: 0
    signal moved(int v)

    height: Metrics.dp(24)
    Row {
        anchors.fill: parent
        spacing: Metrics.dp(14)
        Text {
            width: Metrics.dp(22)
text:  icon
            color: iconColor
            font { pixelSize: Metrics.sp(16); family: "JetBrainsMono Nerd Font" }
            anchors.verticalCenter: parent.verticalCenter
        }

        Item {
            width:  parent.width - 78
            height: Metrics.dp(6)
anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.fill: parent; radius: 3
                color: Colors.a(Colors.fg, 0.08)
            }

            Rectangle {
                width:  parent.width * value / 100
                height: parent.height; radius: 3
                color:  iconColor
                Behavior on width { NumberAnimation { duration: 40 } }
            }

            Rectangle {
                x: Math.max(0, (parent.width * value / 100) - 7)
                anchors.verticalCenter: parent.verticalCenter
                width:  14; height: 14; radius: 7
                color:  iconColor
                scale:   sliderMa.containsMouse || sliderMa.pressed ? 1 : 0.6
                opacity: sliderMa.containsMouse || sliderMa.pressed ? 1 : 0

                Behavior on scale   { NumberAnimation { duration: Animations.snap; easing.type: Easing.OutBack; easing.overshoot: Animations.springPower } }
                Behavior on opacity { NumberAnimation { duration: Animations.snap } }
            }

            MouseArea {
                id: sliderMa
                anchors.fill: parent; anchors.margins: -12
                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onPressed:         mouse => updateVal(mouse.x)
                onPositionChanged: mouse => { if (pressed) updateVal(mouse.x) }
                function updateVal(x) { moved(Math.round(Math.max(minValue, Math.min(100, x / parent.width * 100)))) }
            }
        }

        Text {
            width: Metrics.dp(28)
text:  value
            color: Colors.a(Colors.fg, 0.4)
            font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font" }
            horizontalAlignment: Text.AlignRight
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
