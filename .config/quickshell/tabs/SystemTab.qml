import QtQuick
import ".."

Item {
    property var helpers
    property string uptime: "..."

    Column {
        anchors.fill: parent
        spacing: Metrics.dp(10)
        InfoRow {
            width: parent.width
            icon: "󰔟"
            label: L10n.tr("uptime", "Uptime")
            value: uptime
        }

        TileButton {
            width: parent.width
            icon: helpers ? helpers.getPowerModeIcon() : ""
            label: helpers ? helpers.getPowerModeLabel() : ""
            sublabel: L10n.tr("power_mode", "Power Mode")
            active: true
            onClicked: helpers && helpers.cyclePowerMode()
        }

        TileButton {
            width: parent.width
            icon: helpers ? helpers.getBarModeIcon() : ""
            label: helpers ? helpers.getBarModeLabel() : ""
            sublabel: L10n.tr("bar_mode", "Bar Mode")
            active: true
            onClicked: helpers && helpers.cycleBarMode()
        }
    }
}
