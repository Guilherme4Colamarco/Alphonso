import QtQuick
import ".."

Item {
    id: root
    property string role: "panel"
    property bool hovered: false
    property bool pressed: false
    property bool active: false
    property bool materialEnabled: true
    property real fillOpacity: 1
    property string skinId: ""
    readonly property string resolvedSkinId: skinId !== "" ? skinId : Skins.currentId
    readonly property var skinRecipe: Skins.recipe(resolvedSkinId)
    readonly property real recipeRadius: Metrics.dp(
        role === "control" ? skinRecipe.controlRadius
        : role === "raised" ? skinRecipe.cardRadius
        : skinRecipe.containerRadius)
    property real cornerRadius: Skins.radius(recipeRadius, height)
    default property alias content: contentHost.data

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: Skins.roleBase(root.role, root.active)
        border.width: root.materialEnabled ? Metrics.dp(root.skinRecipe.borderWidth) : 0
        border.color: root.active ? Colors.accent : Skins.bevelDark(root.pressed)
        gradient: Gradient {
            GradientStop { position: 0; color: Skins.materialTop(root.role, root.pressed, root.active, root.resolvedSkinId) }
            GradientStop { position: 1; color: Skins.materialBottom(root.role, root.pressed, root.active, root.resolvedSkinId) }
        }
        opacity: root.fillOpacity
        Behavior on color { ColorAnimation { duration: Animations.fast } }
    }

    Image {
        anchors.fill: parent
        source: root.skinRecipe.textureSource
        fillMode: Image.Tile
        opacity: root.materialEnabled && (root.role === "background" || root.role === "panel")
            ? root.skinRecipe.textureOpacity * root.fillOpacity : 0
        visible: opacity > 0 && source !== ""
    }

    Rectangle {
        visible: root.materialEnabled && root.skinRecipe.bevelWidth > 0
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: Metrics.dp(root.skinRecipe.bevelWidth)
        color: Skins.bevelLight(root.pressed)
        opacity: root.fillOpacity
    }
    Rectangle {
        visible: root.materialEnabled && root.skinRecipe.bevelWidth > 0
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
        width: Metrics.dp(root.skinRecipe.bevelWidth)
        color: Skins.bevelLight(root.pressed)
        opacity: root.fillOpacity
    }
    Rectangle {
        visible: root.materialEnabled && root.skinRecipe.bevelWidth > 0
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: Metrics.dp(root.skinRecipe.bevelWidth)
        color: Skins.bevelDark(root.pressed)
        opacity: root.fillOpacity
    }
    Rectangle {
        visible: root.materialEnabled && root.skinRecipe.bevelWidth > 0
        anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
        width: Metrics.dp(root.skinRecipe.bevelWidth)
        color: Skins.bevelDark(root.pressed)
        opacity: root.fillOpacity
    }

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: root.hovered ? Colors.a(Colors.fg, 0.05) : "transparent"
        Behavior on color { ColorAnimation { duration: Animations.fast } }
    }

    Item { id: contentHost; anchors.fill: parent }
}
