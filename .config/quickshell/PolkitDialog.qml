import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit

PanelWindow {
    id: root
    visible: false
    color: "transparent"
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    WlrLayershell.namespace: "polkit-dialog"

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    PolkitAgent { id: agent }

    property real br:     UIState.borderRadius
    property real brCard: Math.round(br * 0.75)
    property real brSm:   Math.round(br * 0.625)

    function a(c, o) { return Qt.rgba(c.r, c.g, c.b, o) }

    // Extract binary name from message, e.g. `/usr/bin/true` → `true`
    readonly property string appName: {
        var msg = agent.flow?.message ?? ""
        var match = msg.match(/`([^`]+)`/)
        if (match) {
            var parts = match[1].split("/")
            return parts[parts.length - 1]
        }
        // fallback: last segment of actionId
        var idParts = (agent.flow?.actionId ?? "").split(".")
        return idParts[idParts.length - 1]
    }

    Connections {
        target: agent
        function onAuthenticationRequestStarted() {
            root.visible = true
            passField.text = ""
            passField.forceActiveFocus()
        }
        function onFlowChanged() {
            if (!agent.flow) {
                root.visible = false
                passField.text = ""
            }
        }
    }

    Connections {
        target: agent.flow
        function onAuthenticationFailed() {
            shakeAnim.start()
            passField.text = ""
            passField.forceActiveFocus()
        }
        function onIsResponseRequiredChanged() {
            if (agent.flow?.isResponseRequired)
                passField.forceActiveFocus()
        }
    }

    // Dimmed backdrop
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: root.visible ? 0.45 : 0
        Behavior on opacity { NumberAnimation { duration: Animations.fast } }
    }

    // Card dialog
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Metrics.dp(380)
height: cardCol.implicitHeight + 48
        radius: br
        color: a(Colors.bg, UIState.transparencyEnabled ? 0.82 : 1)
        border.width: 1
        border.color: passField.activeFocus && !shakeAnim.running
            ? a(Colors.accent, 0.5)
            : a(Colors.fg, 0.1)

        scale: root.visible ? 1.0 : Animations.enterScale

        Behavior on scale {
            NumberAnimation {
                duration: Animations.enterDuration
                easing.type: Easing.OutBack
                easing.overshoot: Animations.springPower
            }
        }
        Behavior on border.color { ColorAnimation { duration: Animations.fast } }

        SequentialAnimation {
            id: shakeAnim
            NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; from: 0;   to: 10;  duration: 50; easing.type: Easing.OutQuad }
            NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; from: 10;  to: -10; duration: 50; easing.type: Easing.OutQuad }
            NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; from: -10; to: 10;  duration: 50; easing.type: Easing.OutQuad }
            NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; from: 10;  to: 0;   duration: 50; easing.type: Easing.OutQuad }
        }

        Column {
            id: cardCol
            anchors.centerIn: parent
            width: parent.width - 48
            spacing: Metrics.dp(0)
            // Header
            Row {
                width: parent.width
                spacing: Metrics.dp(12)
                Rectangle {
                    width: 40; height: 40; radius: brSm
                    anchors.top: parent.top
                    color: a(Colors.fg, 0.05)
                    Text {
                        anchors.centerIn: parent
                        text: "󰯄"
                        font.pixelSize: Metrics.sp(20)
                        font.family: "JetBrainsMono Nerd Font"
                        color: Colors.accent
                    }
                }

                Column {
                    width: parent.width - 52
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Metrics.dp(4)
                    Text {
                        width: parent.width
                        text: "Autenticação Necessária"
                        color: Colors.fg
                        font.pixelSize: Metrics.sp(15)
                        font.bold: true
                        font.family: "JetBrainsMono Nerd Font"
                    }

                    Text {
                        width: parent.width
                        text: root.appName + " está solicitando privilégios"
                        color: a(Colors.fg, 0.45)
                        font.pixelSize: Metrics.sp(11)
                        font.family: "JetBrainsMono Nerd Font"
                        elide: Text.ElideRight
                    }
                }
            }

            Item { width: parent.width; height: 14 }

            // Divider
            Rectangle {
                width: parent.width
                height: Metrics.dp(1)
color: a(Colors.fg, 0.1)
            }

            Item { width: parent.width; height: 14 }

            // Supplementary message (Error or Info)
            Text {
                visible: (agent.flow?.supplementaryMessage ?? "") !== ""
                width: parent.width
                text: agent.flow?.supplementaryMessage ?? ""
                color: (agent.flow?.supplementaryIsError ?? false)
                    ? Colors.red : a(Colors.fg, 0.45)
                font.pixelSize: Metrics.sp(11)
                font.family: "JetBrainsMono Nerd Font"
                wrapMode: Text.WordWrap
                bottomPadding: visible ? 10 : 0
            }

            // Password field
            Rectangle {
                width: parent.width
                height: Metrics.dp(38)
radius: brCard
                color: a(Colors.surface, 0.7)
                border.width: passField.activeFocus && !shakeAnim.running ? 2 : 1
                border.color: passField.activeFocus && !shakeAnim.running ? a(Colors.accent, 0.55) : a(Colors.fg, 0.06)

                Behavior on border.color { ColorAnimation { duration: Animations.fast } }

                TextInput {
                    id: passField
                    anchors {
                        left: parent.left; leftMargin: 14
                        right: parent.right; rightMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: (agent.flow?.responseVisible ?? false)
                        ? TextInput.Normal : TextInput.Password
                    color: Colors.fg
                    font.pixelSize: Metrics.sp(12)
                    font.bold: true
                    font.family: "JetBrainsMono Nerd Font"

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: agent.flow?.inputPrompt ?? "Senha"
                        color: a(Colors.fg, 0.25)
                        font: parent.font
                        visible: parent.text.length === 0
                    }

                    onAccepted: {
                        if (agent.flow?.isResponseRequired) {
                            agent.flow.submit(passField.text)
                            passField.text = ""
                        }
                    }

                    Keys.onEscapePressed: agent.flow?.cancelAuthenticationRequest()
                }

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: passField.forceActiveFocus()
                }
            }

            Item { width: parent.width; height: 14 }

            // Action Buttons
            Row {
                width: parent.width
                spacing: Metrics.dp(12)
                // Cancel button
                Rectangle {
                    id: cancelBtn
                    width: (parent.width / 2) - 6
                    height: Metrics.dp(38)
radius: brCard
                    color: cancelMa.containsMouse
                        ? a(Colors.fg, 0.15)
                        : a(Colors.fg, 0.05)
                    border.width: 1
                    border.color: a(Colors.fg, 0.08)

                    Row {
                        anchors.centerIn: parent
                        spacing: Metrics.dp(8)
Text {
                            text: "esc"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Metrics.sp(10)
                            color: a(Colors.fg, 0.4)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "Cancelar"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Metrics.sp(12)
                            color: Colors.fg
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: cancelMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: agent.flow?.cancelAuthenticationRequest()
                    }

                    Behavior on color { ColorAnimation { duration: Animations.fast } }
                }

                // Authenticate button
                Rectangle {
                    id: authBtn
                    width: (parent.width / 2) - 6
                    height: Metrics.dp(38)
radius: brCard
                    color: authMa.containsMouse
                        ? a(Colors.accent, 0.85)
                        : Colors.accent

                    Text {
                        anchors.centerIn: parent
                        text: "Autenticar"
                        font.family: "JetBrainsMono Nerd Font"
                        font.bold: true
                        font.pixelSize: Metrics.sp(12)
                        color: Colors.bg
                    }

                    MouseArea {
                        id: authMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (agent.flow?.isResponseRequired) {
                                agent.flow.submit(passField.text)
                                passField.text = ""
                            }
                        }
                    }

                    Behavior on color { ColorAnimation { duration: Animations.fast } }
                }
            }
        }
    }
}
