import QtQuick
import ".."

Item {
    id: root

    property string label: ""
    property bool checked: false
    signal toggled(bool c)

    height: Metrics.controlHeight
    width: parent.width

    Rectangle {
        anchors.fill: parent
        radius: UIState.borderRadius * 0.625
        color: rowMa.containsMouse ? Colors.a(Colors.fg, 0.05) : "transparent"
        Behavior on color { ColorAnimation { duration: Animations.fast } }
    }

    Text {
        id: labelText
        anchors.left: parent.left
        anchors.leftMargin: Metrics.dp(2)
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: Colors.a(Colors.fg, 0.85)
        font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font" }
    }

    Item {
        id: pill
        anchors.right: parent.right
        anchors.rightMargin: Metrics.dp(2)
        anchors.verticalCenter: parent.verticalCenter
        width: Metrics.dp(42)
        height: Metrics.dp(24)

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: root.checked ? Colors.accent : Colors.a(Colors.fg, 0.2)
            Behavior on color { ColorAnimation { duration: Animations.fast } }
        }

        Rectangle {
            x: root.checked ? parent.width - width - 2 : 2
            anchors.verticalCenter: parent.verticalCenter
            width: Metrics.dp(18)
            height: Metrics.dp(18)
            radius: height / 2
            color: Colors.bg

            Behavior on x {
                NumberAnimation { duration: Animations.medium; easing.type: Easing.OutBack; easing.overshoot: Animations.springPower }
            }
        }
    }

    MouseArea {
        id: rowMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
