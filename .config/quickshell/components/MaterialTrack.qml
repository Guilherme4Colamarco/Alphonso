import QtQuick
import ".."

Item {
    id: root
    property real value: 0
    property bool active: false

    MaterialSurface { anchors.fill: parent; role: "sunken"; cornerRadius: Skins.radius(Skins.controlRadius, height) }
    MaterialSurface {
        width: Math.max(0, Math.min(parent.width, parent.width * root.value))
        height: parent.height
        role: "accent"
        active: root.active
        cornerRadius: Skins.radius(Skins.controlRadius, height)
    }
}
