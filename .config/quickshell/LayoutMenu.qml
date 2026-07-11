import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import Qt5Compat.GraphicalEffects

PanelWindow {
    id: layoutMenu

    property bool showing: UIState.layoutMenuVisible
    property int selectedIndex: 0
    property string activeLayoutAbbr: ""

    property real br:     UIState.borderRadius
    property real brCard: Math.round(br * 0.75)
    property real brSm:   Math.round(br * 0.625)

    visible: showing
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "layout-menu"
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function a(c, o) { return Qt.rgba(c.r, c.g, c.b, o) }

    onShowingChanged: {
        if (showing) {
            getActiveLayoutProc.running = true
            selectedIndex = 0
            focusDelay.start()
        }
    }

    Timer {
        id: focusDelay
        interval: 100
        onTriggered: keyboardHandler.forceActiveFocus()
    }

    // Action executor
    Process { id: actionProc }

    function runAction(cmd) {
        actionProc.command = ["bash", "-c", cmd]
        actionProc.running = true
    }

    function selectLayout(name) {
        runAction("mmsg dispatch setlayout," + name)
        close()
    }

    function close() {
        UIState.layoutMenuVisible = false
    }

    // Query current layout
    Process {
        id: getActiveLayoutProc
        command: ["mmsg", "get", "all-tags"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var obj = JSON.parse(data.trim())
                    if (obj && obj.all_tags && obj.all_tags.length > 0) {
                        var tags = obj.all_tags[0].tags
                        for (var i = 0; i < tags.length; i++) {
                            if (tags[i].is_active) {
                                activeLayoutAbbr = tags[i].layout
                                // Pre-select the active layout in the grid
                                for (var j = 0; j < layoutModel.length; j++) {
                                    if (layoutModel[j].abbr === activeLayoutAbbr) {
                                        selectedIndex = j
                                        break
                                    }
                                }
                                break
                            }
                        }
                    }
                } catch(e) {}
            }
        }
    }

    property var layoutModel: [
        { name: "tile",              abbr: "T",  label: "Tile",              icon: "󰕰", key: "T" },
        { name: "scroller",          abbr: "S",  label: "Scroller",          icon: "󰾍", key: "S" },
        { name: "monocle",           abbr: "M",  label: "Monocle",           icon: "󰝤", key: "M" },
        { name: "grid",              abbr: "G",  label: "Grid",              icon: "󰝘", key: "G" },
        { name: "deck",              abbr: "K",  label: "Deck",              icon: "󰘚", key: "D" },
        { name: "center_tile",       abbr: "CT", label: "Center Tile",       icon: "󰝥", key: "C" },
        { name: "vertical_tile",     abbr: "VT", label: "Vertical Tile",     icon: "󰕳", key: "V" },
        { name: "right_tile",        abbr: "RT", label: "Right Tile",        icon: "󰕴", key: "R" },
        { name: "vertical_scroller", abbr: "VS", label: "Vertical Scroller", icon: "󰾎", key: "F" },
        { name: "vertical_grid",     abbr: "VG", label: "Vertical Grid",     icon: "󰝚", key: "Z" },
        { name: "vertical_deck",     abbr: "VK", label: "Vertical Deck",     icon: "󰘛", key: "E" },
        { name: "dwindle",           abbr: "DW", label: "Dwindle",           icon: "󰕦", key: "W" },
        { name: "fair",              abbr: "FA", label: "Fair",              icon: "󰝢", key: "X" },
        { name: "vertical_fair",     abbr: "VF", label: "Vertical Fair",     icon: "󰝣", key: "B" }
    ]

    // Dimmed backdrop
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: showing ? 0.45 : 0
        Behavior on opacity { NumberAnimation { duration: Animations.fast } }
    }

    // Dismiss when clicking outside the card
    MouseArea {
        anchors.fill: parent
        onClicked: layoutMenu.close()
    }

    Rectangle {
        id: card
        width: 620
        height: 460
        anchors.centerIn: parent
        transformOrigin: Item.Center
        radius: br
        color: a(Colors.bg, UIState.transparencyEnabled ? 0.82 : 1)
        border.width: 1
        border.color: a(Colors.fg, 0.1)
        scale: showing ? 1.0 : Animations.enterScale

        Behavior on scale {
            NumberAnimation {
                duration: Animations.enterDuration
                easing.type: Easing.OutBack
                easing.overshoot: Animations.springPower
            }
        }
        Behavior on color { ColorAnimation { duration: Animations.slow } }

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            // Header
            Row {
                width: parent.width
                spacing: 12

                Text {
                    text: "󰕰"
                    color: Colors.accent
                    font { pixelSize: 22; family: "JetBrainsMono Nerd Font" }
                }

                Column {
                    spacing: 2
                    Text {
                        text: L10n.tr("tiling_layouts", "Tiling Layouts")
                        color: Colors.fg
                        font { pixelSize: 15; family: "JetBrainsMono Nerd Font"; bold: true }
                    }
                    Text {
                        text: L10n.tr("active_layout", "Active Layout: ") + (activeLayoutAbbr ? activeLayoutAbbr : L10n.tr("no_active_layout", "None"))
                        color: a(Colors.fg, 0.4)
                        font { pixelSize: 10; family: "JetBrainsMono Nerd Font" }
                    }
                }
            }

            // Grid of Layouts
            Item {
                width: parent.width
                height: layoutGrid.implicitHeight

                Grid {
                    id: layoutGrid
                    anchors.horizontalCenter: parent.horizontalCenter
                    columns: 4
                    spacing: 10

                    Repeater {
                        model: layoutMenu.layoutModel

                        Item {
                            required property int index
                            required property var modelData

                            width: 108
                            height: 76

                            property bool isSelected: index === selectedIndex
                            property bool isActive: modelData.abbr === activeLayoutAbbr

                            Rectangle {
                                anchors.fill: parent
                                radius: brCard
                                color: isSelected ? a(Colors.accent, 0.15) : (itemMa.containsMouse ? a(Colors.fg, 0.08) : a(Colors.fg, 0.03))
                                border.width: isSelected ? 2 : (isActive ? 1.5 : 0)
                                border.color: isSelected ? Colors.accent : (isActive ? a(Colors.accent, 0.4) : "transparent")

                                Behavior on color { ColorAnimation { duration: Animations.fast } }
                                Behavior on border.color { ColorAnimation { duration: Animations.fast } }
                            }

                            // Hotkey Keycap Badge (Top-left)
                            Rectangle {
                                width: 14
                                height: 14
                                radius: 3
                                color: isSelected ? a(Colors.accent, 0.25) : a(Colors.fg, 0.06)
                                border.width: 1
                                border.color: isSelected ? a(Colors.accent, 0.5) : a(Colors.fg, 0.08)
                                anchors { top: parent.top; left: parent.left; margins: 6 }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.key
                                    color: isSelected || isActive ? Colors.accent : a(Colors.fg, 0.45)
                                    font { pixelSize: 8; family: "JetBrainsMono Nerd Font"; bold: true }
                                }
                            }

                            // Active Indicator dot (Top-right)
                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                color: Colors.accent
                                anchors { top: parent.top; right: parent.right; margins: 8 }
                                visible: isActive
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.icon
                                    color: isSelected || isActive ? Colors.accent : a(Colors.fg, 0.5)
                                    font { pixelSize: 22; family: "JetBrainsMono Nerd Font" }
                                    Behavior on color { ColorAnimation { duration: Animations.fast } }
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.label
                                    color: isSelected || isActive ? Colors.fg : a(Colors.fg, 0.45)
                                    font { pixelSize: 9; family: "JetBrainsMono Nerd Font"; bold: isActive }
                                    Behavior on color { ColorAnimation { duration: Animations.fast } }
                                }
                            }

                            MouseArea {
                                id: itemMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    selectedIndex = index
                                    layoutMenu.selectLayout(modelData.name)
                                }
                            }
                        }
                    }
                }
            }

            // Bottom bar
            Item {
                width: parent.width
                height: 20

                Text {
                    anchors.centerIn: parent
                    text: L10n.tr("navigation_hint", "Vim Keys (HJKL) or Arrows to navigate • Enter to select • Shortcuts top-left • ESC to close")
                    color: a(Colors.fg, 0.3)
                    font { pixelSize: 9; family: "JetBrainsMono Nerd Font" }
                }
            }
        }
    }

    // Keyboard navigation handler
    Item {
        id: keyboardHandler
        focus: showing
        Keys.onPressed: function(event) {
            var keyStr = event.text.toLowerCase()

            // Check hotkeys (only if it's a single letter and matches layout hotkey)
            if (keyStr.length === 1 && keyStr >= 'a' && keyStr <= 'z' && keyStr !== 'h' && keyStr !== 'j' && keyStr !== 'k' && keyStr !== 'l') {
                for (var i = 0; i < layoutModel.length; i++) {
                    if (layoutModel[i].key.toLowerCase() === keyStr) {
                        layoutMenu.selectLayout(layoutModel[i].name)
                        event.accepted = true
                        return
                    }
                }
            }

            if (event.key === Qt.Key_Escape) {
                layoutMenu.close()
                event.accepted = true
            } else if (event.key === Qt.Key_Left || keyStr === 'h') {
                if (selectedIndex > 0) selectedIndex--
                event.accepted = true
            } else if (event.key === Qt.Key_Right || keyStr === 'l') {
                if (selectedIndex < layoutModel.length - 1) selectedIndex++
                event.accepted = true
            } else if (event.key === Qt.Key_Up || keyStr === 'k') {
                if (selectedIndex >= 4) selectedIndex -= 4
                event.accepted = true
            } else if (event.key === Qt.Key_Down || keyStr === 'j') {
                if (selectedIndex + 4 < layoutModel.length) selectedIndex += 4
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                layoutMenu.selectLayout(layoutModel[selectedIndex].name)
                event.accepted = true
            }
        }
    }
}
