import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell._Window

Row {
    id: root

    property int iconPx: 18
    property int itemPx: 28
    property int itemH: 24
    property int itemRadius: 6
    property int itemSpacing: 8

    spacing: itemSpacing

    Repeater {
        model: SystemTray.items
        delegate: Rectangle {
            id: trayDelegate
            required property var modelData

            width: root.itemPx
            height: root.itemH
            radius: root.itemRadius
            color: trayMouse.containsMouse
                ? Colors.a(Colors.fg, 0.10)
                : "transparent"
            scale: trayMouse.containsMouse ? Animations.hoverScale : 1.0
            transformOrigin: Item.Center

            Behavior on color { ColorAnimation { duration: Animations.fast } }
            Behavior on scale { NumberAnimation { duration: Animations.fast; easing.type: Easing.OutCubic } }

            Image {
                anchors.centerIn: parent
                width: root.iconPx; height: root.iconPx
                source: trayDelegate.modelData.icon || ""
                sourceSize: Qt.size(root.iconPx, root.iconPx)
                asynchronous: true
                smooth: true; mipmap: true
                visible: status === Image.Ready
                onStatusChanged: if (status === Image.Error) visible = false
            }

            MouseArea {
                id: trayMouse
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: function(mouse) {
                    var item = trayDelegate.modelData
                    var openMenu = false

                    if (mouse.button === Qt.RightButton) {
                        if (item.hasMenu) openMenu = true
                    } else {
                        if (item.onlyMenu) {
                            if (item.hasMenu) openMenu = true
                        } else {
                            item.activate()
                        }
                    }

                    if (openMenu) {
                        var win = trayDelegate.QsWindow?.window
                        if (win) {
                            var contentItem = win.contentItem
                            if (contentItem) {
                                var pos = trayDelegate.mapToItem(contentItem, 0, trayDelegate.height)
                                TrayState.toggle(item, win, pos.x, pos.y)
                            }
                        }
                    }
                }

                onWheel: function(wheel) {
                    trayDelegate.modelData.scroll(wheel.angleDelta.y, false)
                }
            }
        }
    }
}
