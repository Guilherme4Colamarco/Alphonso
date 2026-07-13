import QtQuick
import ".."

Item {
    id: root

    property string label: ""
    property string colorValue: "0x000000ff"
    property string defaultValue: ""
    property bool pickerOpen: false

    signal colorChanged(string c)

    height: rowHeight + (pickerOpen ? pickerHeight + 8 : 0)
    property real rowHeight: 34
    property real pickerHeight: 118

    clip: true

    Behavior on height {
        NumberAnimation { duration: Animations.medium; easing.type: Easing.OutExpo }
    }

    // ── Mango hex <-> QML color helpers ──────────────────────────────────────

    function mangoToColor(mango) {
        if (!mango || typeof mango !== "string") return Colors.accent
        var s = mango.startsWith("0x") ? mango.slice(2) : mango.replace("#", "")
        if (s.length < 6) return Colors.accent

        var r = parseInt(s.substring(0, 2), 16) / 255
        var g = parseInt(s.substring(2, 4), 16) / 255
        var b = parseInt(s.substring(4, 6), 16) / 255
        var a = s.length >= 8 ? parseInt(s.substring(6, 8), 16) / 255 : 1.0

        if (isNaN(r) || isNaN(g) || isNaN(b) || isNaN(a)) return Colors.accent
        return Qt.rgba(r, g, b, a)
    }

    function colorToMango(c) {
        if (typeof c === "string") c = Qt.color(c)
        var toHex = function(v) {
            return Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16).padStart(2, "0")
        }
        return "0x" + toHex(c.r) + toHex(c.g) + toHex(c.b) + toHex(c.a)
    }

    readonly property color currentColor: mangoToColor(root.colorValue)

    // ── Header row ───────────────────────────────────────────────────────────

    Item {
        id: header
        width: parent.width
        height: root.rowHeight

        Rectangle {
            anchors.fill: parent
            radius: Skins.radius(Skins.controlRadius, height)
            color: rowMa.containsMouse ? Colors.a(Colors.fg, 0.05) : "transparent"
            Behavior on color { ColorAnimation { duration: Animations.fast } }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: Metrics.dp(2)
anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: Colors.a(Colors.fg, 0.85)
            font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font" }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: Metrics.dp(2)
anchors.verticalCenter: parent.verticalCenter
            spacing: Metrics.dp(8)
            Rectangle {
                width: Metrics.dp(20)
height: Metrics.dp(20)
radius: Skins.radius(Skins.buttonRadius, height)
                color: root.currentColor
                border.width: 1
                border.color: Colors.a(Colors.fg, 0.2)
            }

            Text {
                text: root.colorValue
                color: Colors.a(Colors.fg, 0.45)
                font { pixelSize: Metrics.sp(9); family: "JetBrainsMono Nerd Font" }
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: rowMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.pickerOpen = !root.pickerOpen
        }
    }

    // ── Color picker ─────────────────────────────────────────────────────────

    Rectangle {
        anchors.top: header.bottom
        anchors.topMargin: Metrics.dp(8)
width: parent.width
        height: root.pickerHeight
        radius: Skins.radius(Skins.fieldRadius, height)
        color: Colors.a(Colors.surface, 0.4)
        border.width: 1
        border.color: Colors.a(Colors.fg, 0.08)

        visible: root.pickerOpen
        opacity: root.pickerOpen ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: Animations.fast } }

        Column {
            anchors.fill: parent
            anchors.margins: Metrics.dp(8)
spacing: Metrics.dp(8)
            Grid {
                id: presetGrid
                width: parent.width
                columns: 8
                spacing: Metrics.dp(6)
                Repeater {
                    model: [
                        Colors.accent, Colors.red, Colors.green, Colors.yellow,
                        Colors.fg, Colors.surface, Colors.dim, Colors.bg,
                        "#f38ba8", "#a6e3a1", "#f9e2af", "#89b4fa",
                        "#cba6f7", "#ffffff", "#000000", "#6c7086"
                    ]

                    Rectangle {
                        required property var modelData

                        width: (presetGrid.width - (presetGrid.columns - 1) * presetGrid.spacing) / presetGrid.columns
                        height: width
                        radius: width * 0.3
                        color: modelData
                        border.width: 1
                        border.color: Colors.a(Colors.fg, 0.2)

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.colorChanged(root.colorToMango(modelData))
                        }
                    }
                }
            }

            Row {
                width: parent.width
                spacing: Metrics.dp(8)
                Rectangle {
                    width: parent.width - (root.defaultValue !== "" ? defaultBtn.width + 8 : 0)
                    height: Metrics.dp(24)
radius: Skins.radius(Skins.buttonRadius, height)
                    color: Colors.a(Colors.bg, 0.5)
                    border.width: 1
                    border.color: hexInput.activeFocus ? Colors.accent : Colors.a(Colors.fg, 0.1)

                    TextInput {
                        id: hexInput
                        anchors.fill: parent
                        anchors.margins: Metrics.dp(5)
text: root.colorValue
                        color: Colors.fg
                        font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font" }
                        verticalAlignment: TextInput.AlignVCenter
                        selectByMouse: true
                        clip: true

                        onAccepted: {
                            var c = root.mangoToColor(text)
                            root.colorChanged(root.colorToMango(c))
                        }
                    }
                }

                Rectangle {
                    id: defaultBtn
                    visible: root.defaultValue !== ""
                    width: Metrics.dp(44)
height: Metrics.dp(24)
radius: Skins.radius(Skins.buttonRadius, height)
                    color: defaultMa.containsMouse ? Colors.a(Colors.accent, 0.2) : Colors.a(Colors.accent, 0.1)
                    border.width: 1
                    border.color: Colors.a(Colors.accent, 0.25)

                    Text {
                        anchors.centerIn: parent
                        text: "Default"
                        color: Colors.accent
                        font { pixelSize: Metrics.sp(9); family: "JetBrainsMono Nerd Font" }
                    }

                    MouseArea {
                        id: defaultMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.colorChanged(root.defaultValue)
                    }
                }
            }
        }
    }

    onColorValueChanged: hexInput.text = root.colorValue
}
