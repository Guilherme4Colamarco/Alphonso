import QtQuick
import ".."

Item {
    property string icon
    property string label
    property string value

    height: Metrics.controlHeight

    Rectangle {
        anchors.fill: parent
        radius: UIState.borderRadius * 0.75
        color: Colors.a(Colors.fg, 0.025)
    }

    Row {
        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
        spacing: Metrics.dp(10)
        Text {
            text:  icon
            color: Colors.a(Colors.fg, 0.45)
            font { pixelSize: Metrics.sp(14); family: "JetBrainsMono Nerd Font" }
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text:  label
            color: Colors.a(Colors.fg, 0.55)
            font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font" }
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Text {
        anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
        text:  value
        color: Colors.fg
        font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font"; bold: true }
    }
}
