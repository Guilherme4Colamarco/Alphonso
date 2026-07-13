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
    property real cornerRadius: Skins.radius(role === "control" ? Skins.controlRadius : role === "raised" ? Skins.cardRadius : Skins.containerRadius, height)
    default property alias content: contentHost.data

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: Skins.roleBase(root.role, root.active)
        border.width: root.materialEnabled ? Skins.borderWidth : 0
        border.color: root.active ? Colors.accent : Skins.bevelDark(root.pressed)
        gradient: Gradient {
            GradientStop { position: 0; color: Skins.materialTop(root.role, root.pressed, root.active) }
            GradientStop { position: 1; color: Skins.materialBottom(root.role, root.pressed, root.active) }
        }
        opacity: root.fillOpacity
        Behavior on color { ColorAnimation { duration: Animations.fast } }
    }

    Image {
        anchors.fill: parent
        source: Skins.textureSource
        fillMode: Image.Tile
        opacity: root.materialEnabled && (root.role === "background" || root.role === "panel") ? Skins.textureOpacity * root.fillOpacity : 0
        visible: opacity > 0 && source !== ""
    }

    Rectangle {
        visible: root.materialEnabled && Skins.bevelWidth > 0
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: Skins.bevelWidth
        color: Skins.bevelLight(root.pressed)
        opacity: root.fillOpacity
    }
    Rectangle {
        visible: root.materialEnabled && Skins.bevelWidth > 0
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
        width: Skins.bevelWidth
        color: Skins.bevelLight(root.pressed)
        opacity: root.fillOpacity
    }
    Rectangle {
        visible: root.materialEnabled && Skins.bevelWidth > 0
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: Skins.bevelWidth
        color: Skins.bevelDark(root.pressed)
        opacity: root.fillOpacity
    }
    Rectangle {
        visible: root.materialEnabled && Skins.bevelWidth > 0
        anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
        width: Skins.bevelWidth
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
