import QtQuick
import ".."

Item {
    id: root

    property string label: ""
    property bool checked: false
    signal toggled(bool c)

    height: Aesthetics.controlHeight
    width: parent.width

    Rectangle {
        anchors.fill: parent
        radius: Aesthetics.radius(Aesthetics.controlRadius, height)
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
        width: Aesthetics.switchWidth
        height: Aesthetics.switchHeight

        Rectangle {
            anchors.fill: parent
            radius: Aesthetics.radius(Aesthetics.controlRadius, height)
            border.width: Aesthetics.borderWidth
            border.color: Colors.a(Colors.fg, 0.25)
            color: root.checked ? Colors.accent : Colors.a(Colors.fg, 0.2)
            Behavior on color { ColorAnimation { duration: Animations.fast } }
        }

        Rectangle {
            x: root.checked ? parent.width - width - Metrics.dp(3) : Metrics.dp(3)
            anchors.verticalCenter: parent.verticalCenter
            width: Aesthetics.switchThumbSize
            height: Aesthetics.switchThumbSize
            radius: Aesthetics.radius(Aesthetics.controlRadius, height)
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
