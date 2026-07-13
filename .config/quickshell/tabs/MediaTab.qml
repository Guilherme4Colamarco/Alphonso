import QtQuick
import ".."

Item {
    property var helpers

    Column {
        anchors.fill: parent
        spacing: Metrics.dp(16)
        SliderRow {
            width:     parent.width
            icon:      UIState.volume == 0 ? "󰝟" : UIState.volume < 50 ? "󰖀" : "󰕾"
            iconColor: Colors.accent
            value:     UIState.volume
            onMoved:   v => UIState.setVolume(v)
        }

        TileButton {
            width: parent.width
            icon: Animations.getIcon()
            label: Animations.getLabel()
            sublabel: L10n.tr("animations", "Animations")
            active: Animations.profile !== "none"
            onClicked: helpers && helpers.cycleAnimations()
        }
    }
}
