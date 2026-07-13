import QtQuick
import ".."

Item {
    id: root
    property string role: "raised"
    property bool active: false
    default property alias content: contentHost.data
    signal clicked()

    MaterialSurface {
        anchors.fill: parent
        role: root.role
        hovered: mouse.containsMouse
        pressed: mouse.pressed
        active: root.active
        opacity: root.enabled ? 1 : 0.5
        Item { id: contentHost; anchors.fill: parent }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
