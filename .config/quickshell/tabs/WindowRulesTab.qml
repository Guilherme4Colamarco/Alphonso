import Quickshell
import Quickshell.Io
import QtQuick
import ".."

Item {
    id: root
    property var helpers

    property var ruleList: []
    property string addRule: ""
    property string operationError: ""

    function loadRules() {
        MangoConfig.listDirectives("windowrules", function(data) {
            ruleList = data
        })
    }

    function deleteRule(index) {
        MangoConfig.removeDirective("windowrules", index)
    }

    function addRuleFn() {
        if (!addRule.trim()) return
        MangoConfig.addDirective("windowrules", "windowrule", addRule.trim())
        addRule = ""
    }

    onVisibleChanged: { if (visible) loadRules() }

    Connections {
        target: MangoConfig
        function onDirectiveApplied(module, action) {
            if (module !== "windowrules") return
            root.operationError = ""
            if (action !== "list") root.loadRules()
        }
        function onDirectiveFailed(module, action, message) {
            if (module === "windowrules") root.operationError = message
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
                visible: root.operationError !== "" || MangoConfig.directiveBusy("windowrules")
                width: parent.width
                text: root.operationError !== "" ? root.operationError : L10n.tr("applying", "Applying…")
                color: root.operationError !== "" ? Colors.red : Colors.accent
                wrapMode: Text.WordWrap
                font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font" }
            }

            ConfigSection {
                title: L10n.tr("window_rules", "Window Rules")
                icon: "󰁍"
                expanded: true
                width: parent.width

                Repeater {
                    model: ruleList

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
                            text: modelData.value
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
                                enabled: !MangoConfig.directiveBusy("windowrules")
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: deleteRule(modelData.index)
                            }
                        }
                    }
                }
            }

            // ── Add rule form ────────────────────────────────────────────────
            ConfigSection {
                title: L10n.tr("add_rule", "Add Rule")
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
                            width: (parent.width - 70) * 1
                            height: Metrics.dp(40)

                            Rectangle {
                                anchors.fill: parent
                                radius: UIState.borderRadius * 0.625
                                color: Colors.a(Colors.fg, 0.06)
                                border.width: 1
                                border.color: Colors.a(Colors.fg, 0.1)

                                TextInput {
                                    id: ruleInput
                                    anchors.fill: parent; anchors.margins: 8
                                    text: root.addRule
                                    color: Colors.fg
                                    font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font" }
                                    verticalAlignment: TextInput.AlignVCenter
                                    onTextChanged: root.addRule = text
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
                                    enabled: !MangoConfig.directiveBusy("windowrules")
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: addRuleFn()
                                }
                            }
                        }
                    }

                    Text {
                        text: L10n.tr("rule_format", "Format: prop:val,prop:val,appid:name")
                        color: Colors.a(Colors.fg, 0.35)
                        font { pixelSize: Metrics.sp(9); family: "JetBrainsMono Nerd Font" }
                    }
                }
            }

            // ── Rule examples ─────────────────────────────────────────────────
            ConfigSection {
                title: L10n.tr("examples", "Examples")
                icon: "󰋗"
                expanded: false
                width: parent.width

                Column {
                    width: parent.width
                    spacing: Metrics.dp(4)
                    Repeater {
                        model: [
                            "isfloating:1,appid:mpv",
                            "isfloating:1,width:700,height:400,appid:floatterm",
                            "animation_type_open:zoom,appid:floatterm",
                            "movecenter:1,appid:calculator",
                            "monitor:1,appid:firefox",
                            "tag:3,appid:discord",
                            "pseudo:1,appid:alacritty"
                        ]

                        Item {
                            required property string modelData
                            width: parent.width
                            height: Metrics.dp(20)
                            Text {
                                anchors.left: parent.left; anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: "•  " + modelData
                                color: Colors.a(Colors.fg, 0.5)
                                font { pixelSize: Metrics.sp(9); family: "JetBrainsMono Nerd Font" }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.addRule = modelData
                            }
                        }
                    }
                }
            }
        }
    }
}
