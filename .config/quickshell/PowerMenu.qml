import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: powerMenu

    property bool showing: UIState.powerMenuVisible
    property real br: UIState.borderRadius
    property real brCard: Math.round(br * 0.75)

    visible: showing
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "power-menu"
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function a(c, o) { return Qt.rgba(c.r, c.g, c.b, o) }

    function close() {
        UIState.powerMenuVisible = false
    }

    onShowingChanged: {
        if (showing) {
            closeAnim.stop()
            openAnim.start()
        }
    }

    SequentialAnimation {
        id: openAnim
        NumberAnimation { target: mainContent; property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
    }

    SequentialAnimation {
        id: closeAnim
        NumberAnimation { target: mainContent; property: "opacity"; to: 0; duration: 150; easing.type: Easing.OutCubic }
        ScriptAction { script: powerMenu.close() }
    }

    Process { id: actionProc }

    function runAction(cmd) {
        actionProc.command = ["bash", "-c", cmd]
        actionProc.running = true
    }

    Item {
        id: mainContent
        anchors.fill: parent
        opacity: showing ? 1 : 0

        MouseArea {
            anchors.fill: parent
            onClicked: closeAnim.start()
        }

        // Small Menu Card
        Rectangle {
            width: Metrics.dp(180)
height: layoutCol.height + 24
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top
                topMargin: UIState.barMode === "floating" ? 44 : 32
            }
            radius: brCard
            color: a(Colors.bg, UIState.transparencyEnabled ? 0.9 : 1)
            border.width: 1
            border.color: a(Colors.fg, 0.1)

            Behavior on color { ColorAnimation { duration: Animations.slow } }

            Column {
                id: layoutCol
                width: parent.width - 24
                anchors.centerIn: parent
                spacing: Metrics.dp(4)
                Repeater {
                    model: [
                        { icon: "⏻", label: L10n.tr("poweroff", "Power Off"), cmd: "systemctl poweroff", color: "red" },
                        { icon: "󰜉", label: L10n.tr("reboot", "Reboot"), cmd: "systemctl reboot", color: "yellow" },
                        { icon: "󰒲", label: L10n.tr("suspend", "Suspend"), cmd: "systemctl suspend", color: "accent" },
                        { icon: "󰍃", label: L10n.tr("logout", "Log Out"), cmd: "loginctl terminate-user " + Quickshell.env("USER"), color: "fg" },
                        { icon: "󰌾", label: L10n.tr("lock", "Lock"), cmd: "echo 1 > ~/.cache/qs/lock; sleep 0.1", color: "dim" }
                    ]

                    Rectangle {
                        required property int index
                        required property var modelData
                        width: parent.width
                        height: Metrics.dp(36)
radius: Math.max(0, brCard - 4)
                        color: btnMa.containsMouse ? a(Colors.fg, 0.08) : "transparent"
                        
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: Metrics.dp(12)
spacing: Metrics.dp(12)
                            Text {
                                text: modelData.icon
                                color: btnMa.containsMouse ? (Colors[modelData.color] || Colors.fg) : a(Colors.fg, 0.7)
                                font { pixelSize: Metrics.sp(16); family: "JetBrainsMono Nerd Font" }
                            }

                            Text {
                                text: modelData.label
                                color: btnMa.containsMouse ? Colors.fg : a(Colors.fg, 0.7)
                                font { pixelSize: Metrics.sp(12); family: "JetBrainsMono Nerd Font" }
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: btnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                powerMenu.runAction(modelData.cmd)
                                closeAnim.start()
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        focus: showing
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                closeAnim.start()
                event.accepted = true
            }
        }
    }
}
