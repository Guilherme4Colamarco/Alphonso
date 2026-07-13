import QtQuick
import ".."

Item {
    id: root
    property real value: 0
    property bool active: false
    property string skinId: ""
    readonly property string resolvedSkinId: skinId !== "" ? skinId : Skins.currentId
    readonly property var skinRecipe: Skins.recipe(resolvedSkinId)
    readonly property real localRadius: Metrics.dp(skinRecipe.controlRadius)

    MaterialSurface { anchors.fill: parent; role: "sunken"; skinId: root.resolvedSkinId; cornerRadius: Skins.radius(root.localRadius, height) }
    MaterialSurface {
        width: Math.max(0, Math.min(parent.width, parent.width * root.value))
        height: parent.height
        role: "accent"
        active: root.active
        skinId: root.resolvedSkinId
        cornerRadius: Skins.radius(root.localRadius, height)
    }
}
