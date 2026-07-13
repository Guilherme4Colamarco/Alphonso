import Quickshell
import Quickshell.Io
import Quickshell._Window
import QtQuick

PopupBase {
    id: root

    implicitWidth: Metrics.dp(260)
contentHeight: contentCol.implicitHeight
    autoDismiss: true

    anchor.window: BluetoothState.parentWindow
    anchor.rect.x: BluetoothState.popupX
    anchor.rect.y: BluetoothState.popupY

    Connections {
        target: BluetoothState
        function onVisibleChanged() {
            root.animState = BluetoothState.visible ? "open" : "closing"
            if (BluetoothState.visible) refreshDevices.running = true
        }
    }

    Process {
        id: refreshDevices
        command: ["bluetoothctl", "devices", "Paired"]
        running: false
        stdout: SplitParser {
            onRead: {
                if (data && data.trim()) {
                    var lines = data.trim().split("\n")
                    var newDevices = []
                    for (var i = 0; i < lines.length; i++) {
                        var parts = lines[i].split(" ")
                        if (parts.length >= 3) {
                            var mac = parts[1]
                            var name = parts.slice(2).join(" ")
                            newDevices.push({ mac: mac, name: name })
                        }
                    }
                    BluetoothState.devices = newDevices
                    checkConnections.running = true
                }
            }
        }
    }

    Process {
        id: checkConnections
        command: ["bluetoothctl", "info"]
        running: false
        stdout: SplitParser {
            onRead: {
                var info = data.trim()
                if (info.includes("Connected: yes")) {
                    var lines = info.split("\n")
                    var mac = ""
                    for (var i = 0; i < lines.length; i++) {
                        if (lines[i].includes("Device ")) {
                            mac = lines[i].split(" ")[1]
                            break
                        }
                    }
                    BluetoothState.connectedMac = mac
                }
            }
        }
    }

    Process {
        id: toggleDevice
        command: ["bluetoothctl"]
        running: false
        property string targetMac: ""
        property string action: ""
        onStarted: {
            if (action === "connect") toggleDevice.command = ["bluetoothctl", "connect", targetMac]
            else if (action === "disconnect") toggleDevice.command = ["bluetoothctl", "disconnect", targetMac]
        }
        onExited: {
            refreshDevices.running = true
        }
    }

    Process {
        id: togglePower
        command: ["bluetoothctl", "power", "toggle"]
        running: false
        onExited: {
            refreshDevices.running = true
        }
    }

    Column {
        id: contentCol
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: root.padding }
        spacing: Metrics.dp(3)
        Row {
            spacing: Metrics.dp(8)
height: Metrics.dp(36)
            Rectangle {
                width: 36; height: 36
                radius: Math.round(UIState.borderRadius * 0.5)
                color: BluetoothState.power ? Colors.a(Colors.accent, 0.15) : Colors.a(Colors.fg, 0.08)
                Behavior on color { ColorAnimation { duration: Animations.fast } }

                Text {
                    anchors.centerIn: parent
                    text: BluetoothState.power ? "󰂯" : "󰂲"
                    font { pixelSize: Metrics.sp(16); family: "JetBrainsMono Nerd Font" }
                    color: BluetoothState.power ? Colors.accent : Colors.fg
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: togglePower.running = true
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Metrics.dp(2)
                Text {
                    text: "Bluetooth"
                    font { pixelSize: Metrics.sp(12); weight: Font.Bold; family: "JetBrainsMono Nerd Font" }
                    color: Colors.fg
                }

                Text {
                    text: BluetoothState.power ? "Ligado" : "Desligado"
                    font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font" }
                    color: BluetoothState.power ? Colors.a(Colors.accent, 0.85) : Colors.a(Colors.fg, 0.50)
                }
            }
        }

        Rectangle {
            visible: devicesList.length > 0
            anchors.left: parent.left
            anchors.right: parent.right
            height: Metrics.dp(1)
color: Qt.rgba(Colors.fg.r, Colors.fg.g, Colors.fg.b, 0.08)
        }

        Column {
            id: devicesList
            spacing: Metrics.dp(0)
Repeater {
                model: BluetoothState.devices
                delegate: Item {
                    required property var modelData
                    required property int index

                    width: parent.width
                    height: Metrics.dp(36)
                    Row {
                        anchors { fill: parent; margins: 4 }
                        spacing: Metrics.dp(10)
                        Rectangle {
                            width: 28; height: 28
                            radius: Math.round(UIState.borderRadius * 0.375)
                            color: modelData.mac === BluetoothState.connectedMac
                                ? Colors.a(Colors.accent, 0.15)
                                : Colors.a(Colors.fg, 0.06)

                            Text {
                                anchors.centerIn: parent
                                text: "󰂯"
                                font { pixelSize: Metrics.sp(13); family: "JetBrainsMono Nerd Font" }
                                color: modelData.mac === BluetoothState.connectedMac ? Colors.accent : Colors.fg
                            }
                        }

                        Text {
                            text: modelData.name
                            font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font" }
                            color: Colors.fg
                            elide: Text.ElideRight
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Item {
                            width: Metrics.dp(1)                        }

                        Rectangle {
                            visible: modelData.mac === BluetoothState.connectedMac
                            anchors.verticalCenter: parent.verticalCenter
                            width: 56; height: 24
                            radius: Metrics.dp(12)
color: Colors.a(Colors.accent, 0.15)
                            border.width: 1
                            border.color: Colors.accent

                            Text {
                                anchors.centerIn: parent
                                text: "Conectado"
                                font { pixelSize: Metrics.sp(9); family: "JetBrainsMono Nerd Font" }
                                color: Colors.accent
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    toggleDevice.targetMac = modelData.mac
                                    toggleDevice.action = "disconnect"
                                    toggleDevice.running = true
                                }
                            }
                        }

                        Rectangle {
                            visible: modelData.mac !== BluetoothState.connectedMac
                            anchors.verticalCenter: parent.verticalCenter
                            width: 56; height: 24
                            radius: Metrics.dp(12)
color: Colors.a(Colors.fg, 0.08)

                            Text {
                                anchors.centerIn: parent
                                text: "Conectar"
                                font { pixelSize: Metrics.sp(9); family: "JetBrainsMono Nerd Font" }
                                color: Colors.fg
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    toggleDevice.targetMac = modelData.mac
                                    toggleDevice.action = "connect"
                                    toggleDevice.running = true
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                    }

                    Behavior on opacity { NumberAnimation { duration: Animations.fast } }
                }
            }
        }

        Item {
            visible: devicesList.length === 0 && BluetoothState.power
            height: Metrics.dp(40)
anchors { left: parent.left; right: parent.right }

            Text {
                anchors.centerIn: parent
                text: "Nenhum dispositivo pareado"
                font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font" }
                color: Colors.a(Colors.fg, 0.50)
            }
        }
    }
}
