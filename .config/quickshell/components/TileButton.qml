import QtQuick
import ".."

MaterialButton {
    id: root
    property string icon
    property string label
    property string sublabel
    height: Skins.rowHeight
    role: "raised"

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

}
