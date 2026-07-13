import QtQuick
import ".."

Item {
    id: root

    property string label: ""
    property var model: []
    property int currentIndex: 0
    signal activated(int index)

    height: Skins.controlHeight
    width: parent.width

    readonly property string currentText: {
        if (!root.model || root.model.length === 0) return ""
        if (root.currentIndex < 0 || root.currentIndex >= root.model.length) return ""
        return root.model[root.currentIndex]
    }

    MaterialSurface {
        id: bg
        anchors.fill: parent
        role: "control"
        hovered: rowMa.containsMouse
        materialEnabled: Skins.currentId === "commonality"
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: Metrics.dp(2)
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: Colors.a(Colors.fg, 0.85)
        font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font" }
    }

    MouseArea {
        id: rowMa
        anchors.fill: parent
        hoverEnabled: true
        z: -1
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: Metrics.dp(2)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Metrics.dp(4)

        MaterialButton {
            width: Metrics.dp(30)
            height: Metrics.dp(30)
            role: "raised"
            onClicked: {
                if (!root.model || root.model.length === 0) return
                var idx = root.currentIndex - 1
                if (idx < 0) idx = root.model.length - 1
                root.activated(idx)
            }

            Text {
                anchors.centerIn: parent
                text: "󰅁"
                color: Colors.a(Colors.fg, 0.5)
                font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font" }
            }

        }

        MaterialButton {
            width: Math.max(Metrics.dp(80), valueText.implicitWidth + Metrics.dp(20))
            height: Metrics.dp(30)
            role: "sunken"
            onClicked: {
                if (!root.model || root.model.length === 0) return
                root.activated((root.currentIndex + 1) % root.model.length)
            }

            Text {
                id: valueText
                anchors.centerIn: parent
                text: root.currentText
                color: Colors.accent
                font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font"; bold: true }
            }

        }

        MaterialButton {
            width: Metrics.dp(30)
            height: Metrics.dp(30)
            role: "raised"
            onClicked: {
                if (!root.model || root.model.length === 0) return
                root.activated((root.currentIndex + 1) % root.model.length)
            }

            Text {
                anchors.centerIn: parent
                text: "󰅃"
                color: Colors.a(Colors.fg, 0.5)
                font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font" }
            }

        }
    }
}
