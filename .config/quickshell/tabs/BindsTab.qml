import Quickshell
import Quickshell.Io
import QtQuick
import ".."

Item {
    id: root
    property var helpers

    property var bindList: []
    property string addMods: "SUPER"
    property string addKey: ""
    property string addAction: "spawn"
    property string addArgs: ""
    property string operationError: ""

    property var prefixIcons: ({
        "bind": "󰌌",
        "mousebind": "󰍽",
        "axisbind": "󰔄",
        "gesturebind": "󰀘"
    })

    property var actionHints: ({
        "spawn": "command",
        "killclient": "",
        "togglefloating": "",
        "togglefullscreen": "",
        "focusdir": "direction (left/right/up/down)",
        "movecenter": "",
        "exchange_client": "direction",
        "resizewin": "dx,dy",
        "view": "tag number",
        "tag": "tag number",
        "setlayout": "layout name",
        "setoption": "key,value",
        "toggleoverview": "",
        "spawn_shell": "shell command",
        "reload_config": "",
        "focusstack": "next/prev",
        "togglegaps": "",
        "toggleglobal": "",
        "setmfact": "delta",
        "switch_layout": "",
        "switch_proportion_preset": "",
        "moveresize": "curmove/curresize"
    })

    function loadBinds() {
        MangoConfig.listDirectives("binds", function(data) {
            bindList = data
        })
    }

    function deleteBind(index) {
        MangoConfig.removeDirective("binds", index)
    }

    function addBind() {
        if (!addKey.trim()) return
        var value = addMods + "," + addKey + "," + addAction
        if (addArgs.trim()) value += "," + addArgs
        MangoConfig.addDirective("binds", "bind", value)
        addKey = ""; addArgs = ""; addAction = "spawn"
    }

    function formatBind(item) {
        var parts = item.value.split(",")
        if (item.prefix === "bind" && parts.length >= 3) {
            var mods = parts[0], key = parts[1], action = parts[2]
            var args = parts.slice(3).join(",")
            return mods + " + " + key + "  →  " + action + (args ? "  " + args : "")
        }
        return item.value
    }

    onVisibleChanged: { if (visible) loadBinds() }

    Connections {
        target: MangoConfig
        function onDirectiveApplied(module, action) {
            if (module !== "binds") return
            root.operationError = ""
            if (action !== "list") root.loadBinds()
        }
        function onDirectiveFailed(module, action, message) {
            if (module === "binds") root.operationError = message
        }
    }

    Flickable {
        width: parent.width
        height: parent.height
        contentHeight: col.height + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: parent.width
            spacing: Metrics.dp(10)
topPadding: Metrics.dp(6)
            Text {
                visible: root.operationError !== "" || MangoConfig.directiveBusy("binds")
                width: parent.width
                text: root.operationError !== "" ? root.operationError : L10n.tr("applying", "Applying…")
                color: root.operationError !== "" ? Colors.red : Colors.accent
                wrapMode: Text.WordWrap
                font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font" }
            }

            // ── Existing binds ────────────────────────────────────────────────
            ConfigSection {
                title: L10n.tr("keybinds", "Keybinds")
                icon: "󰌌"
                expanded: true
                width: parent.width

                Repeater {
                    model: bindList

                    Item {
                        required property int index
                        required property var modelData
                        width: parent.width
                        height: Metrics.dp(42)

                        Rectangle {
                            anchors.fill: parent
                            radius: UIState.borderRadius * 0.5
                            color: delMa.containsMouse ? Colors.a(Colors.red, 0.12) : Colors.a(Colors.fg, 0.04)
                            Behavior on color { ColorAnimation { duration: Animations.fast } }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: Metrics.dp(10)
anchors.verticalCenter: parent.verticalCenter
                            text: (prefixIcons[modelData.prefix] || "󰅣") + "  " + formatBind(modelData)
                            color: Colors.a(Colors.fg, 0.8)
                            font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font" }
                            elide: Text.ElideRight
                            width: parent.width - 50
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: Metrics.dp(8)
anchors.verticalCenter: parent.verticalCenter
                            text: "󰅖"
                            color: delMa.containsMouse ? Colors.red : Colors.a(Colors.fg, 0.25)
                            font { pixelSize: Metrics.sp(13); family: "JetBrainsMono Nerd Font" }
                            Behavior on color { ColorAnimation { duration: Animations.fast } }

                            MouseArea {
                                id: delMa
                                anchors.fill: parent; anchors.margins: -4
                                enabled: !MangoConfig.directiveBusy("binds")
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: deleteBind(modelData.index)
                            }
                        }
                    }
                }
            }

            // ── Add bind form ─────────────────────────────────────────────────
            ConfigSection {
                title: L10n.tr("add_bind", "Add Bind")
                icon: "󰐕"
                expanded: true
                width: parent.width

                Column {
                    width: parent.width
                    spacing: Metrics.dp(8)
                    Row {
                        width: parent.width
                        spacing: Metrics.dp(6)
                        Item {
                            width: (parent.width - 6) * 0.4
                            height: Metrics.dp(40)
                            Rectangle {
                                anchors.fill: parent
                                radius: UIState.borderRadius * 0.625
                                color: Colors.a(Colors.fg, 0.06)
                                border.width: 1
                                border.color: Colors.a(Colors.fg, 0.1)

                                TextInput {
                                    id: modsInput
                                    anchors.fill: parent; anchors.margins: 8
                                    text: root.addMods
                                    color: Colors.fg
                                    font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font" }
                                    verticalAlignment: TextInput.AlignVCenter
                                    onTextChanged: root.addMods = text
                                }
                            }
                        }

                        Item {
                            width: (parent.width - 6) * 0.25
                            height: Metrics.dp(40)
                            Rectangle {
                                anchors.fill: parent
                                radius: UIState.borderRadius * 0.625
                                color: Colors.a(Colors.fg, 0.06)
                                border.width: 1
                                border.color: Colors.a(Colors.fg, 0.1)

                                TextInput {
                                    id: keyInput
                                    anchors.fill: parent; anchors.margins: 8
                                    text: root.addKey
                                    color: Colors.fg
                                    font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font" }
                                    verticalAlignment: TextInput.AlignVCenter
                                    onTextChanged: root.addKey = text
                                }
                            }
                        }

                        Item {
                            width: (parent.width - 6) * 0.35
                            height: Metrics.dp(40)
                            Rectangle {
                                anchors.fill: parent
                                radius: UIState.borderRadius * 0.625
                                color: Colors.a(Colors.fg, 0.06)
                                border.width: 1
                                border.color: Colors.a(Colors.fg, 0.1)

                                TextInput {
                                    id: actionInput
                                    anchors.fill: parent; anchors.margins: 8
                                    text: root.addAction
                                    color: Colors.fg
                                    font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font" }
                                    verticalAlignment: TextInput.AlignVCenter
                                    onTextChanged: root.addAction = text
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Metrics.dp(6)
                        Item {
                            width: (parent.width - 70) * 1
                            height: Metrics.dp(40)
                            Rectangle {
                                anchors.fill: parent
                                radius: UIState.borderRadius * 0.625
                                color: Colors.a(Colors.fg, 0.06)
                                border.width: 1
                                border.color: Colors.a(Colors.fg, 0.1)

                                TextInput {
                                    id: argsInput
                                    anchors.fill: parent; anchors.margins: 8
                                    text: root.addArgs
                                    color: Colors.fg
                                    font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font" }
                                    verticalAlignment: TextInput.AlignVCenter
                                    onTextChanged: root.addArgs = text
                                }
                            }
                        }

                        Item {
                            width: Metrics.dp(64)
height: Metrics.dp(40)

                            Rectangle {
                                anchors.fill: parent
                                radius: UIState.borderRadius * 0.625
                                color: addBtnMa.containsMouse ? Colors.a(Colors.accent, 0.25) : Colors.a(Colors.accent, 0.12)
                                Behavior on color { ColorAnimation { duration: Animations.fast } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰐕"
                                    color: Colors.accent
                                    font { pixelSize: Metrics.sp(14); family: "JetBrainsMono Nerd Font" }
                                }

                                MouseArea {
                                    id: addBtnMa
                                    anchors.fill: parent
                                    enabled: !MangoConfig.directiveBusy("binds")
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: addBind()
                                }
                            }
                        }
                    }
                }
            }

            // ── Quick action picker ──────────────────────────────────────────
            ConfigSection {
                title: L10n.tr("quick_actions", "Quick Actions")
                icon: "󰁔"
                expanded: false
                width: parent.width

                Flow {
                    width: parent.width
                    spacing: Metrics.dp(6)
                    Repeater {
                        model: [
                            { action: "spawn", key: "Return", mods: "SUPER", args: "kitty", label: "Terminal" },
                            { action: "spawn", key: "d", mods: "SUPER", args: "touch /tmp/qs-launcher-toggle", label: "Launcher" },
                            { action: "spawn", key: "w", mods: "SUPER", args: "touch /tmp/qs-wallpaper-toggle", label: "Wallpaper" },
                            { action: "spawn", key: "e", mods: "SUPER", args: "thunar", label: "File Manager" },
                            { action: "killclient", key: "q", mods: "SUPER+SHIFT", args: "", label: "Kill Client" },
                            { action: "togglefloating", key: "space", mods: "SUPER+SHIFT", args: "", label: "Toggle Float" },
                            { action: "togglefullscreen", key: "f", mods: "SUPER", args: "", label: "Fullscreen" },
                            { action: "toggleoverview", key: "o", mods: "SUPER", args: "", label: "Overview" },
                            { action: "reload_config", key: "r", mods: "SUPER+CTRL", args: "", label: "Reload" }
                        ]

                        Item {
                            required property var modelData
                            width: (parent.width - 12) / 3
                            height: Metrics.dp(38)

                            Rectangle {
                                anchors.fill: parent
                                radius: UIState.borderRadius * 0.5
                                color: qaMa.containsMouse ? Colors.a(Colors.accent, 0.15) : Colors.a(Colors.fg, 0.04)
                                Behavior on color { ColorAnimation { duration: Animations.fast } }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: qaMa.containsMouse ? Colors.accent : Colors.a(Colors.fg, 0.7)
                                    font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font" }
                                }

                                MouseArea {
                                    id: qaMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.addMods = modelData.mods
                                        root.addKey = modelData.key
                                        root.addAction = modelData.action
                                        root.addArgs = modelData.args
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Legend ───────────────────────────────────────────────────────
            ConfigSection {
                title: L10n.tr("prefix_legend", "Prefix Legend")
                icon: "󰋗"
                expanded: false
                width: parent.width

                Column {
                    width: parent.width
                    spacing: Metrics.dp(4)
                    Repeater {
                        model: [
                            { prefix: "bind", desc: "Keyboard shortcut" },
                            { prefix: "mousebind", desc: "Mouse button bind" },
                            { prefix: "axisbind", desc: "Scroll axis bind" },
                            { prefix: "gesturebind", desc: "Touch gesture bind" }
                        ]

                        Item {
                            required property var modelData
                            width: parent.width
                            height: Metrics.dp(22)
                            Text {
                                anchors.left: parent.left; anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.prefix
                                color: Colors.accent
                                font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font"; bold: true }
                            }

                            Text {
                                anchors.right: parent.right; anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.desc
                                color: Colors.a(Colors.fg, 0.5)
                                font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font" }
                            }
                        }
                    }
                }
            }
        }
    }
}
