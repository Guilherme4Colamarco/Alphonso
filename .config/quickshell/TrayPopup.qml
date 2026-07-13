import Quickshell
import Quickshell.DBusMenu
import Quickshell._Window
import QtQuick

PopupBase {
    id: root

    implicitWidth: Metrics.dp(220)
contentHeight: contentCol.implicitHeight
    autoDismiss: false

    anchor.window: TrayState.parentWindow
    anchor.rect.x: TrayState.popupX
    anchor.rect.y: TrayState.popupY

    Connections {
        target: TrayState
        function onVisibleChanged() {
            root.animState = TrayState.visible ? "open" : "closing"
        }
    }

    QsMenuOpener {
        id: menuOpener
        menu: TrayState.activeItem ? TrayState.activeItem.menu : null
    }

    Column {
        id: contentCol
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: root.padding }
        spacing: Metrics.dp(3)
        Text {
            width: parent.width
            visible: Boolean(TrayState.activeItem?.title)
            text: TrayState.activeItem?.title ?? ""
            font { pixelSize: Metrics.sp(11); weight: Font.Bold; family: "JetBrainsMono Nerd Font" }
            color: Colors.dim
            bottomPadding: Metrics.dp(6)
elide: Text.ElideRight
        }

        Instantiator {
            model: menuOpener.children
            asynchronous: false

            delegate: Item {
                id: entryDelegate
                required property var modelData
                required property int index

                width: contentCol.width
                height: modelData.isSeparator ? 9 : 32

                Rectangle {
                    visible: entryDelegate.modelData.isSeparator
                    anchors.centerIn: parent
                    width: parent.width - 8
                    height: Metrics.dp(1)
color: Qt.rgba(Colors.fg.r, Colors.fg.g, Colors.fg.b, 0.08)
                    antialiasing: true
                }

                Rectangle {
                    visible: !entryDelegate.modelData.isSeparator
                    width: parent.width
                    height: Metrics.dp(32)
radius: Aesthetics.radius(Aesthetics.containerRadius, height)
                    color: rowArea.containsMouse && entryDelegate.modelData.enabled
                        ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.12)
                        : "transparent"
                    opacity: entryDelegate.modelData.enabled ? 1.0 : 0.4

                    Behavior on color {
                        ColorAnimation { duration: Animations.fast; easing.type: Easing.OutCubic }
                    }

                    Row {
                        anchors {
                            left: parent.left; leftMargin: 10
                            right: parent.right; rightMargin: 10
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: Metrics.dp(8)
                        Text {
                            visible: entryDelegate.modelData.buttonType !== QsMenuButtonType.None
                            text: {
                                if (entryDelegate.modelData.buttonType === QsMenuButtonType.CheckBox)
                                    return "✓"
                                if (entryDelegate.modelData.buttonType === QsMenuButtonType.RadioButton)
                                    return "●"
                                return ""
                            }
                            font { pixelSize: Metrics.sp(13); family: "JetBrainsMono Nerd Font" }
                            color: Colors.accent
                            width: Metrics.dp(16)
horizontalAlignment: Text.AlignHCenter
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Image {
                            visible: Boolean(entryDelegate.modelData.icon)
                            width: 16; height: 16
                            source: entryDelegate.modelData.icon || ""
                            sourceSize.width: 16; sourceSize.height: 16
                            smooth: true; mipmap: true
                            asynchronous: true
                            anchors.verticalCenter: parent.verticalCenter
                            fillMode: Image.PreserveAspectFit
                        }

                        Text {
                            text: entryDelegate.modelData.text || ""
                            font { pixelSize: Metrics.sp(13); weight: Font.Bold; family: "JetBrainsMono Nerd Font" }
                            color: Colors.fg
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - x
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: entryDelegate.modelData.enabled
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            entryDelegate.modelData.triggered()
                            TrayState.hide()
                        }
                    }
                }
            }

            onObjectAdded: (idx, obj) => obj.parent = contentCol
            onObjectRemoved: (idx, obj) => {}
        }
    }
}
