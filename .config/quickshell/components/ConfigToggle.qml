import QtQuick
import ".."

Item {
    id: root

    property string label: ""
    property bool checked: false
    signal toggled(bool c)

    height: Skins.controlHeight
    width: parent.width

    MaterialSurface {
        anchors.fill: parent
        role: "control"
        hovered: rowMa.containsMouse
        materialEnabled: Skins.currentId === "commonality"
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
        width: Skins.switchWidth
        height: Skins.switchHeight

        MaterialSurface {
            anchors.fill: parent
            role: root.checked ? "accent" : "sunken"
            active: root.checked
            cornerRadius: Skins.radius(Skins.controlRadius, height)
        }

        MaterialSurface {
            x: root.checked ? parent.width - width - Metrics.dp(3) : Metrics.dp(3)
            anchors.verticalCenter: parent.verticalCenter
            width: Skins.switchThumbSize
            height: Skins.switchThumbSize
            role: "raised"
            cornerRadius: Skins.radius(Skins.controlRadius, height)

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
