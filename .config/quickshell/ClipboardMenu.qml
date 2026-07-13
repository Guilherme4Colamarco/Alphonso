import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

PanelWindow {
    id: clipboardMenu

    property bool showing: UIState.clipboardMenuVisible
    property int selectedIndex: 0
    property string query: ""
    property var filteredItems: []
    property bool isDeleting: false

    property real br: Skins.containerRadius
    property real brCard: Math.round(br * 0.75)
    property real brSm:   Math.round(br * 0.625)

    visible: showing
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "clipboard-menu"
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function a(c, o) { return Qt.rgba(c.r, c.g, c.b, o) }

    onShowingChanged: {
        if (showing) {
            query = ""
            searchInput.text = ""
            selectedIndex = 0
            load()
            focusDelay.start()
        }
    }

    Timer {
        id: focusDelay
        interval: 100
        onTriggered: searchInput.forceActiveFocus()
    }

    function load() {
        clipboardProc.running = false
        clipboardProc.running = true
    }

    function filterItems() {
        var q = query.toLowerCase()
        var result = []
        for (var i = 0; i < clipboardModel.count; i++) {
            var e = clipboardModel.get(i)
            if (q === "" || e.content.toLowerCase().includes(q)) {
                result.push({ itemId: e.itemId, content: e.content, rawLine: e.rawLine, isImage: e.isImage })
            }
        }
        filteredItems = result
        if (selectedIndex >= result.length) {
            selectedIndex = Math.max(0, result.length - 1)
        }
    }

    function moveSelection(delta) {
        if (filteredItems.length === 0) return
        var next = selectedIndex + delta
        if (next < 0) next = 0
        if (next >= filteredItems.length) next = filteredItems.length - 1
        selectedIndex = next
        clipList.positionViewAtIndex(next, ListView.Contain)
    }

    function confirmSelection() {
        if (selectedIndex >= 0 && selectedIndex < filteredItems.length) {
            actionProc.copyItem(filteredItems[selectedIndex].rawLine)
        }
    }

    function deleteSelected() {
        if (filteredItems.length > 0 && selectedIndex >= 0 && selectedIndex < filteredItems.length) {
            isDeleting = true
            actionProc.deleteItem(filteredItems[selectedIndex].rawLine)
        }
    }

    function showDeleteAllConfirm() {
        if (filteredItems.length === 0) return
        confirmPopup.opacity = 1
    }

    function close() {
        UIState.clipboardMenuVisible = false
    }

    // Model & processes
    ListModel { id: clipboardModel }

    Process {
        id: clipboardProc
        command: ["cliphist", "list"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n")
                clipboardModel.clear()
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()
                    if (line === "") continue
                    var parts = line.split("\t")
                    if (parts.length >= 2) {
                        var content = parts.slice(1).join("\t")
                        var isImage = content.startsWith("[[ binary data")
                        clipboardModel.append({ itemId: parts[0], content: content, rawLine: line, isImage: isImage })
                    }
                }
                filterItems()
                isDeleting = false
            }
        }
    }

    Process {
        id: actionProc
        running: false
        command: ["true"]
        property bool isDeleteOp: false

        function copyItem(rawLine) {
            isDeleteOp = false
            var e = rawLine.replace(/'/g, "'\\''")
            actionProc.command = ["bash", "-c", "printf '%s\n' '" + e + "' | cliphist decode | wl-copy"]
            actionProc.running = true
            clipboardMenu.close()
        }

        function deleteItem(rawLine) {
            isDeleteOp = true
            var e = rawLine.replace(/'/g, "'\\''")
            actionProc.command = ["bash", "-c", "printf '%s\n' '" + e + "' | cliphist delete"]
            actionProc.running = true
        }

        function deleteAll() {
            isDeleteOp = true
            actionProc.command = ["bash", "-c", "cliphist wipe"]
            actionProc.running = true
        }

        onRunningChanged: {
            if (!running && isDeleteOp) {
                isDeleteOp = false
                clipboardMenu.load()
            }
        }
    }

    // Image decoder queue
    property var    _decodeQueue: []
    property string decodingId:   ""
    property bool   decodeReady:  false

    function _enqueueImage(itemId, rawLine) {
        for (var i = 0; i < _decodeQueue.length; i++) {
            if (_decodeQueue[i].itemId === itemId) return
        }
        _decodeQueue.push({ itemId: itemId, rawLine: rawLine })
        if (!imgDecodeProc.running && decodingId === "")
            _processNextImage()
    }

    function _processNextImage() {
        if (_decodeQueue.length === 0) {
            decodingId = ""
            return
        }
        var job = _decodeQueue.shift()
        decodingId  = job.itemId
        decodeReady = false
        var e = job.rawLine.replace(/'/g, "'\\''")
        imgDecodeProc.command = ["bash", "-c",
            "printf '%s\n' '" + e + "' | cliphist decode > '/tmp/qs-clip-" + job.itemId + ".png'"]
        imgDecodeProc.running = true
    }

    Process {
        id: imgDecodeProc
        running: false
        onRunningChanged: {
            if (!running) {
                clipboardMenu.decodeReady = true
                clipboardMenu._processNextImage()
            }
        }
    }

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
        onClicked: if (confirmPopup.opacity === 0) clipboardMenu.close()
    }

    // Card Window
    Rectangle {
        id: card
        width: Metrics.dp(500)
height: Metrics.dp(440)
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
            anchors.margins: Metrics.dp(20)
spacing: Metrics.dp(14)
            // Header
            Row {
                width: parent.width
                spacing: Metrics.dp(12)
                Text {
                    text: "📋"
                    color: Colors.accent
                    font { pixelSize: Metrics.sp(22); family: "JetBrainsMono Nerd Font" }
                }

                Column {
                    width: parent.width - 150
                    spacing: Metrics.dp(2)
Text {
                        text: L10n.tr("clipboard", "Clipboard")
                        color: Colors.fg
                        font { pixelSize: Metrics.sp(15); family: "JetBrainsMono Nerd Font"; bold: true }
                    }
                    Text {
                        text: filteredItems.length + " " + L10n.tr("items_found", "items found")
                        color: a(Colors.fg, 0.4)
                        font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font" }
                    }
                }

                // Clear all button
                Rectangle {
                    width: Metrics.dp(90)
height: Metrics.dp(28)
radius: brSm
                    color: clearAllMa.containsMouse ? a(Colors.red, 0.15) : a(Colors.fg, 0.05)
                    border.width: clearAllMa.containsMouse ? 1 : 0
                    border.color: a(Colors.red, 0.4)
                    anchors.verticalCenter: parent.verticalCenter
                    visible: filteredItems.length > 0

                    Behavior on color { ColorAnimation { duration: Animations.fast } }

                    Text {
                        anchors.centerIn: parent
                        text: L10n.tr("clear_all", "Clear All")
                        color: clearAllMa.containsMouse ? Colors.red : a(Colors.fg, 0.6)
                        font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font"; bold: true }
                    }

                    MouseArea {
                        id: clearAllMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: showDeleteAllConfirm()
                    }
                }
            }

            // Search bar
            Rectangle {
                width:  parent.width
                height: Metrics.dp(40)
radius: brCard
                color:  a(Colors.surface, 0.7)
                border.width: searchInput.activeFocus ? 2 : 1
                border.color: searchInput.activeFocus ? a(Colors.accent, 0.55) : a(Colors.fg, 0.06)

                Behavior on border.color { ColorAnimation { duration: Animations.fast } }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Metrics.dp(12)
anchors.rightMargin: Metrics.dp(12)
spacing: Metrics.dp(8)
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text:  "󰍉"
                        color: searchInput.activeFocus ? Colors.accent : a(Colors.fg, 0.3)
                        font { pixelSize: Metrics.sp(14); family: "JetBrainsMono Nerd Font" }
                    }

                    TextInput {
                        id: searchInput
                        width: parent.width - 50
                        anchors.verticalCenter: parent.verticalCenter
                        color: Colors.fg
                        font { pixelSize: Metrics.sp(12); family: "JetBrainsMono Nerd Font" }
                        selectByMouse: true
                        clip: true

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text:    L10n.tr("search_placeholder", "Search...")
                            color:   a(Colors.fg, 0.25)
                            font:    parent.font
                            visible: !parent.text && !parent.activeFocus
                        }

                        onTextChanged: {
                            query = text
                            filterItems()
                        }

                        Keys.onPressed: function(event) {
                            var keyStr = event.text.toLowerCase()

                            if (event.key === Qt.Key_Escape) {
                                clipboardMenu.close()
                                event.accepted = true
                            } else if (event.key === Qt.Key_Down || (event.modifiers === Qt.ControlModifier && keyStr === 'j')) {
                                moveSelection(1)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Up || (event.modifiers === Qt.ControlModifier && keyStr === 'k')) {
                                moveSelection(-1)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                confirmSelection()
                                event.accepted = true
                            } else if (event.key === Qt.Key_Delete) {
                                deleteSelected()
                                event.accepted = true
                            }
                        }
                    }

                    // Clear search text button
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text:  "󰅖"
                        color: clearQueryMa.containsMouse ? Colors.fg : a(Colors.fg, 0.3)
                        font { pixelSize: Metrics.sp(12); family: "JetBrainsMono Nerd Font" }
                        visible: searchInput.text.length > 0

                        MouseArea {
                            id: clearQueryMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { searchInput.text = ""; searchInput.forceActiveFocus() }
                        }
                    }
                }
            }

            // List of items
            Item {
                width: parent.width
                height: parent.height - 48 - 40 - 28

                ListView {
                    id: clipList
                    anchors.fill: parent
                    clip: true
                    spacing: Metrics.dp(4)
model: filteredItems
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    delegate: Rectangle {
                        id: listItem
                        required property int index
                        required property var modelData

                        readonly property bool isImg: modelData.isImage
                        readonly property bool isSelected: index === selectedIndex
                        readonly property string tmpPath: "/tmp/qs-clip-" + modelData.itemId + ".png"

                        width: clipList.width
                        height: isImg ? 120 : 44
                        radius: brCard
                        color: isSelected
                            ? a(Colors.accent, 0.12)
                            : itemMa.containsMouse ? a(Colors.fg, 0.05) : "transparent"
                        border.width: isSelected ? 1 : 0
                        border.color: a(Colors.accent, 0.3)

                        Behavior on color { ColorAnimation { duration: Animations.fast } }

                        Component.onCompleted: {
                            if (isImg) _enqueueImage(modelData.itemId, modelData.rawLine)
                        }

                        // Left select indicator bar
                        Rectangle {
                            visible: isSelected
                            width: Metrics.dp(3)
height: parent.height - 16
                            radius: Metrics.dp(1.5)
color: Colors.accent
                            anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
                        }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: Metrics.dp(16)
anchors.rightMargin: Metrics.dp(16)
spacing: Metrics.dp(12)
                            // ── Text Row ──
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 36
                                visible: !isImg
                                text: modelData.content
                                color: isSelected ? Colors.accent : Colors.fg
                                font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font"; bold: isSelected }
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                wrapMode: Text.NoWrap
                            }

                            // ── Image Row ──
                            Item {
                                visible: isImg
                                height: parent.height - 12
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(180, parent.width - 40)

                                Rectangle {
                                    anchors.fill: parent
                                    color: a(Colors.fg, 0.03)
                                    radius: brSm
                                    visible: clipImg.status !== Image.Ready
                                }

                                Image {
                                    id: clipImg
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    cache: false
                                    sourceSize: Qt.size(200, 200)

                                    Connections {
                                        target: clipboardMenu
                                        function onDecodeReadyChanged() {
                                            if (clipboardMenu.decodeReady && clipboardMenu.decodingId === modelData.itemId) {
                                                clipImg.source = ""
                                                clipImg.source = "file://" + tmpPath
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Delete button (X) on hover
                        Rectangle {
                            id: deleteItemBtn
                            width: Metrics.dp(24)
height: Metrics.dp(24)
radius: Metrics.dp(6)
color: deleteItemMa.containsMouse ? a(Colors.red, 0.15) : "transparent"
                            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            visible: itemMa.containsMouse || deleteItemMa.containsMouse

                            Text {
                                anchors.centerIn: parent
                                text: ""
                                color: deleteItemMa.containsMouse ? Colors.red : a(Colors.fg, 0.4)
                                font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font" }
                            }

                            MouseArea {
                                id: deleteItemMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    actionProc.deleteItem(modelData.rawLine)
                                }
                            }
                        }

                        MouseArea {
                            id: itemMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!deleteItemMa.containsMouse) {
                                    actionProc.copyItem(modelData.rawLine)
                                }
                            }
                            onContainsMouseChanged: {
                                if (containsMouse && !isDeleting) selectedIndex = index
                            }
                        }
                    }
                }

                // Empty state text
                Text {
                    anchors.centerIn: parent
                    text: "Histórico vazio"
                    color: a(Colors.fg, 0.25)
                    font { pixelSize: Metrics.sp(13); family: "JetBrainsMono Nerd Font" }
                    visible: filteredItems.length === 0 && !clipboardProc.running
                }
            }
        }
    }

    // Delete All Confirmation Popup Overlay
    Rectangle {
        id: confirmPopup
        visible: opacity > 0
        opacity: 0
        z: 10
        anchors.fill: parent
        color: a(Colors.bg, 0.6)

        Behavior on opacity { NumberAnimation { duration: Animations.fast } }

        // Click outside popup doesn't close it
        MouseArea { anchors.fill: parent }

        Rectangle {
            width:  Metrics.dp(320)
height: Metrics.dp(160)
radius: br
            color:  Colors.bg
            border.width: 1
            border.color: a(Colors.fg, 0.15)
            anchors.centerIn: parent

            Column {
                anchors.fill: parent
                anchors.margins: Metrics.dp(18)
spacing: Metrics.dp(14)
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: L10n.tr("clear_history_title", "Clear History?")
                    color: Colors.fg
                    font { pixelSize: Metrics.sp(14); family: "JetBrainsMono Nerd Font"; bold: true }
                }

                Text {
                    width: parent.width
                    text: L10n.tr("clear_history_body", "This will permanently delete all saved items.")
                    color: a(Colors.fg, 0.45)
                    font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font" }
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Metrics.dp(12)
                    // Cancel
                    Rectangle {
                        width:  Metrics.dp(120)
height: Metrics.dp(32)
radius: brSm
                        color:  cancelMa.containsMouse ? a(Colors.fg, 0.1) : a(Colors.fg, 0.04)
                        border.width: 1
                        border.color: a(Colors.fg, 0.08)

                        Text {
                            anchors.centerIn: parent
                            text: L10n.tr("cancel", "Cancel")
                            color: Colors.fg
                            font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font"; bold: true }
                        }

                        MouseArea {
                            id: cancelMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: confirmPopup.opacity = 0
                        }
                    }

                    // Delete
                    Rectangle {
                        width:  Metrics.dp(120)
height: Metrics.dp(32)
radius: brSm
                        color:  deleteConfirmMa.containsMouse ? Colors.red : a(Colors.red, 0.1)

                        Text {
                            anchors.centerIn: parent
                            text: L10n.tr("clear_all", "Clear All")
                            color: deleteConfirmMa.containsMouse ? Colors.bg : Colors.red
                            font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font"; bold: true }
                        }

                        MouseArea {
                            id: deleteConfirmMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                confirmPopup.opacity = 0
                                actionProc.deleteAll()
                            }
                        }
                    }
                }
            }
        }
    }
}
