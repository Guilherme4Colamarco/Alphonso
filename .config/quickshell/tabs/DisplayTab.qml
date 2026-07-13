import QtQuick
import ".."

Item {
    property var helpers

    Column {
        anchors.fill: parent
        spacing: Metrics.dp(16)
        SliderRow {
            width:     parent.width
            icon:      UIState.brightness < 30 ? "󰃞" : UIState.brightness < 70 ? "󰃟" : "󰃠"
            iconColor: Colors.yellow
            value:     UIState.brightness
            minValue:  1
            onMoved:   v => UIState.setBrightness(v)
        }

        TileButton {
            width: parent.width
            icon: helpers ? helpers.getBlurIcon() : ""
            label: helpers ? helpers.getBlurLabel() : ""
            sublabel: L10n.tr("blur_profile", "Blur")
            active: UIState.blurProfile !== "none"
            onClicked: helpers && helpers.cycleBlur()
        }

        TileButton {
            width: parent.width
            icon: helpers ? helpers.getBorderRadiusIcon() : ""
            label: helpers ? helpers.getBorderRadiusLabel() : ""
            sublabel: L10n.tr("border_radius", "Radius")
            active: UIState.borderRadius > 0
            onClicked: helpers && helpers.cycleBorderRadius()
        }
    }
}
