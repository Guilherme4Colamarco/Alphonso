import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Services.SystemTray
import Quickshell.Io

Item {
    id: root

    property string mode: "idle"
    property string appName: ""
    property string title: ""
    property string body: ""
    property string artist: ""
    property string artUrl: ""
    property int volume: 0
    property bool muted: false
    property bool playing: false
    property bool canGoPrevious: false
    property bool canTogglePlaying: false
    property bool canGoNext: false
    property bool canSeek: false
    property bool shuffleActive: false
    property bool shuffleSupported: false
    property string loopStateText: "OFF"
    property bool loopActive: false
    property bool loopSupported: false
    property real mediaPosition: 0
    property real mediaLength: 0
    property bool forceExpanded: false
    property bool mediaAvailable: false
    property string handleStyle: "bump"
    property string batteryHoverText: ""
    property bool batteryCharging: false
    property int batteryLevel: 0
    property bool wifiConnected: false
    property string wifiSsid: ""
    property int wifiSignal: 0
    property bool btEnabled: false
    property bool btConnected: false
    property string btDeviceName: ""
    property int btBattery: -1
    property int workspace: 1
    property var workspaceOccupied: [false,false,false,false,false]
    property string focusedApp: ""
    property string timeText: ""
    property string dateText: ""
    property string fontFamily: "JetBrainsMono Nerd Font"
    property string launcherQuery: ""
    property int launcherSelected: 0
    property var launcherTopApps: []
    property var launcherFiltered: []

    onModeChanged: {
        if (mode === "launcher") launcherFocusDelay.start()
    }

    readonly property color primaryText: Colors.fg
    readonly property color secondaryText: a(Colors.fg, 0.55)
    readonly property color accent: Colors.accent
    readonly property int mediaHorizontalPadding: 24
    readonly property real normalizedMediaPosition: root.normalizedSeconds(mediaPosition)
    readonly property real normalizedMediaLength: root.normalizedSeconds(mediaLength)
    readonly property real mediaProgress: normalizedMediaLength > 0 ? Math.max(0, Math.min(1, normalizedMediaPosition / normalizedMediaLength)) : 0

    function a(c, o) { return Qt.rgba(c.r, c.g, c.b, o) }

    signal previousRequested
    signal playPauseRequested
    signal nextRequested
    signal shuffleRequested
    signal loopRequested
    signal favoriteRequested
    signal dismissRequested
    signal wifiSettingsRequested
    signal btSettingsRequested
    signal seekRequested(real position)
    signal handleStyleRequested(string style)
    signal launcherSearchChanged(string query)
    signal launcherCloseRequested
    signal launcherAppLaunchRequested(var app)
    signal launcherMoveSelectionRequested(int delta)
    signal workspaceSwitchRequested(int index)

    Process { id: wifiToggleProc }
    Process { id: btToggleProc }
    Process { id: randomWallProc }

    function normalizedSeconds(value) {
        if (!isFinite(value) || value <= 0)
            return 0;

        return value > 86400 ? value / 1000000 : value;
    }

    function formatTime(seconds) {
        const normalized = root.normalizedSeconds(seconds);

        if (normalized <= 0)
            return "0:00";

        const safeSeconds = Math.floor(normalized);
        const minutes = Math.floor(safeSeconds / 60);
        const hours = Math.floor(minutes / 60);
        const remainingMinutes = minutes % 60;
        const remainingSeconds = safeSeconds % 60;
        const secondText = remainingSeconds < 10 ? "0" + remainingSeconds : String(remainingSeconds);

        if (hours > 0) {
            const minuteText = remainingMinutes < 10 ? "0" + remainingMinutes : String(remainingMinutes);

            return hours + ":" + minuteText + ":" + secondText;
        }

        return minutes + ":" + secondText;
    }

    // 1. Pílula ociosa: workspace + app name + clock (ou mídia quando tocando)
    Item {
        id: collapsedBumpMedia

        anchors.fill: parent
        opacity: root.mode === "idle" && !root.forceExpanded && root.handleStyle === "bump" ? 1 : 0
        visible: opacity > 0

        // ── Modo Normal: Workspace + App + Clock ──────────────────────
        Row {
            id: idleRow
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 17
            anchors.right: parent.right
            anchors.rightMargin: 17
            spacing: 10
            visible: !root.mediaAvailable

            // Workspace indicator
            Rectangle {
                width: wsNum.implicitWidth + 10
                height: 23
                radius: 12
                color: a(Colors.accent, 0.10)
                border.width: 1
                border.color: a(Colors.accent, 0.20)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    id: wsNum
                    anchors.centerIn: parent
                    text: root.workspace
                    color: Colors.accent
                    font.family: root.fontFamily
                    font.pixelSize: 16
                    font.bold: true
                }
            }

            // App name
            Text {
                text: root.focusedApp !== "" ? root.focusedApp : "Kamalen"
                color: a(Colors.fg, 0.65)
                font.family: root.fontFamily
                font.pixelSize: 17
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
                anchors.verticalCenter: parent.verticalCenter
            }

            // Clock
            Text {
                text: root.timeText
                color: a(Colors.fg, 0.50)
                font.family: root.fontFamily
                font.pixelSize: 17
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // ── Modo Mídia: Art + Track + Clock ──────────────────────────
        Rectangle {
            id: collapsedCover

            x: 16
            y: 6
            width: 23
            height: 23
            radius: 9
            color: a(Colors.accent, 0.05)
            border.width: 1
            border.color: a(Colors.accent, 0.15)
            clip: true
            visible: root.mediaAvailable

            Image {
                id: collapsedCoverSource

                anchors.fill: parent
                source: root.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
            }

            OpacityMask {
                anchors.fill: parent
                source: collapsedCoverSource
                visible: root.artUrl !== "" && collapsedCoverSource.status === Image.Ready

                maskSource: Rectangle {
                    width: collapsedCover.width
                    height: collapsedCover.height
                    radius: collapsedCover.radius
                }
            }

            Row {
                anchors.centerIn: parent
                spacing: 1
                visible: root.artUrl === "" || collapsedCoverSource.status !== Image.Ready

                Repeater {
                    model: 3

                    Rectangle {
                        width: 3
                        height: root.playing ? Math.max(3, 3 + UIState.cava[[1, 5, 9][index]] * 10) : 5
                        radius: 1
                        color: root.playing ? Colors.accent : a(Colors.fg, 0.35)

                        Behavior on height {
                            NumberAnimation { duration: 50; easing.type: Easing.OutQuad }
                        }
                    }
                }
            }
        }

        Rectangle {
            x: collapsedCover.x - 1
            y: collapsedCover.y + collapsedCover.height + 1
            width: collapsedCover.width + 2
            height: 2
            radius: 1
            color: a(Colors.fg, 0.05)
            visible: root.mediaAvailable

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: root.playing ? parent.width : 6
                height: parent.height
                radius: parent.radius
                color: root.playing ? Colors.accent : a(Colors.fg, 0.35)

                Behavior on width {
                    NumberAnimation {
                        duration: Animations.medium
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        Text {
            anchors.left: collapsedCover.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: root.title !== "" ? root.title : root.timeText
            color: root.primaryText
            horizontalAlignment: Text.AlignLeft
            elide: Text.ElideRight
            font.family: root.fontFamily
            font.pixelSize: 14
            font.bold: true
            visible: root.mediaAvailable
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Animations.fast
                easing.type: Easing.OutCubic
            }
        }
    }

    // 2. Modo Peek / Quick settings (Hover quando ocioso)
    Item {
        id: idleContent

        anchors.fill: parent
        opacity: root.mode === "idle" && root.forceExpanded ? 1 : 0
        visible: opacity > 0

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.topMargin: 8
            anchors.bottomMargin: 9
            spacing: 3

            HandleStyleSwitch {
                handleStyle: root.handleStyle
                batteryCharging: root.batteryCharging
                batteryLevel: root.batteryLevel
                fontFamily: root.fontFamily
                showBattery: true
                onHandleStyleRequested: style => root.handleStyleRequested(style)
            }

            // Workspace dots
            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                Repeater {
                    model: 5

                    Rectangle {
                        required property int index
                        width: root.workspace === index + 1 ? 21 : 10
                        height: 10
                        radius: 5
                        color: root.workspace === index + 1
                            ? Colors.accent
                            : root.workspaceOccupied[index]
                                ? a(Colors.fg, 0.25)
                                : a(Colors.fg, 0.08)
                        border.width: root.workspace === index + 1 ? 0 : 1
                        border.color: a(Colors.fg, 0.12)

                        Behavior on width { NumberAnimation { duration: Animations.snap; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: Animations.fast } }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.workspaceSwitchRequested(index + 1)
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: root.timeText
                        color: root.primaryText
                        elide: Text.ElideRight
                        font.family: root.fontFamily
                        font.pixelSize: 29
                        font.bold: true
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.dateText
                        color: root.secondaryText
                        elide: Text.ElideRight
                        font.family: root.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                    }
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                    Layout.preferredWidth: 160
                    spacing: 8

                    // 1. Volume Slider
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 14

                        RowLayout {
                            anchors.fill: parent
                            spacing: 6

                            MIcon {
                                name: root.muted ? "󰝟" : (root.volume < 50 ? "󰖀" : "󰕾")
                                size: 12
                                color: Colors.accent
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Item {
                                id: volTrack
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 4
                                    radius: 2
                                    color: a(Colors.fg, 0.1)
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    width: parent.width * (root.volume / 100)
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 4
                                    radius: 2
                                    color: Colors.accent
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    
                                    function updateValue(mouse) {
                                        var pct = Math.max(0, Math.min(1, mouse.x / width));
                                        UIState.setVolume(Math.round(pct * 100));
                                    }
                                    onPressed: mouse => updateValue(mouse)
                                    onPositionChanged: mouse => {
                                        if (pressed) updateValue(mouse)
                                    }
                                }
                            }

                            Text {
                                text: root.volume + "%"
                                color: a(Colors.fg, 0.45)
                                font.family: root.fontFamily
                                font.pixelSize: 8
                                font.bold: true
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }
                    }

                    // 2. Brightness Slider
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 14

                        RowLayout {
                            anchors.fill: parent
                            spacing: 6

                            MIcon {
                                name: UIState.brightness < 30 ? "󰃞" : (UIState.brightness < 70 ? "󰃟" : "󰃠")
                                size: 12
                                color: Colors.accent
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Item {
                                id: brightTrack
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 4
                                    radius: 2
                                    color: a(Colors.fg, 0.1)
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    width: parent.width * (UIState.brightness / 100)
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 4
                                    radius: 2
                                    color: Colors.accent
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    
                                    function updateValue(mouse) {
                                        var pct = Math.max(0, Math.min(1, mouse.x / width));
                                        UIState.setBrightness(Math.round(pct * 100));
                                    }
                                    onPressed: mouse => updateValue(mouse)
                                    onPositionChanged: mouse => {
                                        if (pressed) updateValue(mouse)
                                    }
                                }
                            }

                            Text {
                                text: UIState.brightness + "%"
                                color: a(Colors.fg, 0.45)
                                font.family: root.fontFamily
                                font.pixelSize: 8
                                font.bold: true
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }
                    }

                    // 3. Toggles Row (Wifi and BT)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        // Wi-Fi Button
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 22
                            radius: 6
                            color: root.wifiConnected ? a(Colors.accent, 0.15) : a(Colors.fg, 0.05)
                            border.width: root.wifiConnected ? 1 : 0
                            border.color: a(Colors.accent, 0.3)

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 4

                                MIcon {
                                    name: root.wifiConnected ? (root.wifiSsid === "Ethernet" ? "󰈀" : "󰤨") : "󰤮"
                                    size: 11
                                    color: root.wifiConnected ? Colors.accent : a(Colors.fg, 0.4)
                                }

                                Text {
                                    text: root.wifiConnected ? (root.wifiSsid === "Ethernet" ? "Cabo" : root.wifiSsid) : "Off"
                                    color: root.wifiConnected ? Colors.fg : a(Colors.fg, 0.4)
                                    font.family: root.fontFamily
                                    font.pixelSize: 8
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: 60
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: function(mouse) {
                                    if (mouse.button === Qt.RightButton) {
                                        root.wifiSettingsRequested();
                                    } else {
                                        wifiToggleProc.command = ["nmcli", "radio", "wifi", root.wifiConnected ? "off" : "on"]
                                        wifiToggleProc.running = true
                                    }
                                }
                            }
                        }

                        // Bluetooth Button
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 22
                            radius: 6
                            color: root.btConnected ? a(Colors.accent, 0.15) : a(Colors.fg, 0.05)
                            border.width: root.btConnected ? 1 : 0
                            border.color: a(Colors.accent, 0.3)

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 4

                                MIcon {
                                    name: "󰂯"
                                    size: 11
                                    color: root.btConnected ? Colors.accent : a(Colors.fg, 0.4)
                                }

                                Text {
                                    text: root.btConnected ? (root.btBattery >= 0 ? root.btBattery + "%" : "On") : "Off"
                                    color: root.btConnected ? Colors.fg : a(Colors.fg, 0.4)
                                    font.family: root.fontFamily
                                    font.pixelSize: 8
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: 60
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: function(mouse) {
                                    if (mouse.button === Qt.RightButton) {
                                        root.btSettingsRequested();
                                    } else {
                                        btToggleProc.command = ["bluetoothctl", "power", root.btConnected ? "off" : "on"]
                                        btToggleProc.running = true
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // System Tray icons
            Row {
                Layout.fillWidth: true
                Layout.topMargin: 5
                spacing: 5

                Repeater {
                    model: SystemTray.items
                    delegate: Rectangle {
                        id: trayItem
                        required property var modelData

                        width: 29
                        height: 22
                        radius: 5
                        color: trayArea.containsMouse ? Qt.rgba(Colors.fg.r, Colors.fg.g, Colors.fg.b, 0.10) : "transparent"
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on color {
                            ColorAnimation { duration: Animations.fast }
                        }

                        Image {
                            anchors.centerIn: parent
                            width: 16; height: 16
                            source: trayItem.modelData.icon || ""
                            smooth: true; mipmap: true
                            visible: source !== ""
                        }

                        MouseArea {
                            id: trayArea
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: function(mouse) {
                                if (mouse.button === Qt.RightButton && trayItem.modelData.hasMenu) {
                                    var win = trayItem.QsWindow.window
                                    var pos = trayItem.mapToItem(trayItem.QsWindow.contentItem, 0, trayItem.height)
                                    if (win) TrayState.show(trayItem.modelData, win, pos.x, pos.y)
                                } else if (mouse.button === Qt.LeftButton) {
                                    trayItem.modelData.activate()
                                }
                            }
                        }
                    }
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Animations.fast
            }
        }
    }

    // 3. Layout de Notificações
    RowLayout {
        id: notificationContent

        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 12
        opacity: root.mode === "notify" ? 1 : 0
        visible: opacity > 0

        Rectangle {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            radius: 12
            color: a(Colors.accent, 0.08)
            border.width: 1
            border.color: a(Colors.accent, 0.2)

            Text {
                anchors.centerIn: parent
                text: "󰵙"
                color: Colors.accent
                font.family: root.fontFamily
                font.pixelSize: 16
                font.bold: true
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: root.appName.toUpperCase()
                color: a(Colors.accent, 0.6)
                elide: Text.ElideRight
                font.family: root.fontFamily
                font.pixelSize: 8
                font.bold: true
            }

            Text {
                Layout.fillWidth: true
                text: root.title
                color: root.primaryText
                elide: Text.ElideRight
                font.family: root.fontFamily
                font.pixelSize: 11
                font.bold: true
            }

            Text {
                Layout.fillWidth: true
                text: root.body
                color: root.secondaryText
                elide: Text.ElideRight
                font.family: root.fontFamily
                font.pixelSize: 9
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Animations.fast
            }
        }
    }

    // 4. Layout Mídia Completo
    RowLayout {
        id: mediaContent

        anchors.fill: parent
        anchors.leftMargin: root.mediaHorizontalPadding
        anchors.rightMargin: root.mediaHorizontalPadding
        spacing: 20
        opacity: root.mode === "media" ? 1 : 0
        visible: opacity > 0

        Rectangle {
            id: mediaArtwork

            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 54
            Layout.preferredHeight: 54
            radius: 14
            color: a(Colors.accent, 0.05)
            border.width: 1
            border.color: a(Colors.accent, root.playing ? 0.35 : 0.15)
            clip: true

            Image {
                id: mediaCoverSource

                anchors.fill: parent
                source: root.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
            }

            OpacityMask {
                anchors.fill: parent
                source: mediaCoverSource
                visible: root.artUrl !== "" && mediaCoverSource.status === Image.Ready

                maskSource: Rectangle {
                    width: mediaArtwork.width
                    height: mediaArtwork.height
                    radius: mediaArtwork.radius
                }
            }

            Row {
                anchors.centerIn: parent
                spacing: 3
                visible: root.artUrl === "" || mediaCoverSource.status !== Image.Ready

                Repeater {
                    model: 3

                    Rectangle {
                        width: 4
                        height: root.playing ? Math.max(8, 8 + UIState.cava[[1, 5, 9][index]] * 24) : 10
                        radius: 2
                        color: root.playing ? Colors.accent : a(Colors.fg, 0.3)

                        Behavior on height {
                            NumberAnimation { duration: 50; easing.type: Easing.OutQuad }
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            spacing: 2

            HandleStyleSwitch {
                handleStyle: root.handleStyle
                batteryCharging: root.batteryCharging
                batteryLevel: root.batteryLevel
                statusText: root.dateText
                fontFamily: root.fontFamily
                compact: true
                showBattery: true
                onHandleStyleRequested: style => root.handleStyleRequested(style)
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Item {
                    id: titleMarqueeRoot
                    Layout.fillWidth: true
                    Layout.preferredHeight: 18
                    clip: true

                    readonly property real maxWidth: titleMarqueeRoot.width
                    readonly property real gap: 30
                    readonly property real unitWidth: titleTextA.implicitWidth + gap
                    readonly property bool scrolling: titleTextA.implicitWidth > maxWidth

                    Row {
                        id: titleMarqueeTrack
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0

                        Text {
                            id: titleTextA
                            text: root.title
                            color: root.primaryText
                            font.family: root.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                        }

                        Item {
                            width: titleMarqueeRoot.gap
                            height: 1
                            visible: titleMarqueeRoot.scrolling
                        }

                        Text {
                            id: titleTextB
                            text: root.title
                            color: root.primaryText
                            font.family: root.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                            visible: titleMarqueeRoot.scrolling
                        }
                    }

                    NumberAnimation {
                        id: titleMarqueeAnim
                        target: titleMarqueeTrack
                        property: "x"
                        from: 0
                        to: -titleMarqueeRoot.unitWidth
                        duration: titleMarqueeRoot.unitWidth * 25
                        loops: Animation.Infinite
                        running: titleMarqueeRoot.scrolling && root.playing
                        easing.type: Easing.Linear
                    }

                    onWidthChanged: {
                        titleMarqueeAnim.stop()
                        titleMarqueeTrack.x = 0
                        if (titleMarqueeRoot.scrolling && root.playing) titleMarqueeAnim.start()
                    }

                    Connections {
                        target: root
                        function onTitleChanged() {
                            titleMarqueeAnim.stop()
                            titleMarqueeTrack.x = 0
                            if (titleMarqueeRoot.scrolling && root.playing) titleMarqueeAnim.start()
                        }
                        function onPlayingChanged() {
                            if (!root.playing) {
                                titleMarqueeAnim.stop()
                                titleMarqueeTrack.x = 0
                            } else if (titleMarqueeRoot.scrolling) {
                                titleMarqueeAnim.start()
                            }
                        }
                    }
                }

                Text {
                    text: root.timeText
                    color: Colors.accent
                    visible: root.timeText !== ""
                    font.family: root.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                }

                Rectangle {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    radius: 10
                    color: dismissMouse.containsMouse ? a(Colors.accent, 0.15) : a(Colors.fg, 0.03)
                    border.width: 1
                    border.color: a(Colors.accent, 0.15)

                    MIcon {
                        anchors.centerIn: parent
                        name: "󰅖"
                        size: 11
                        color: dismissMouse.containsMouse ? Colors.red : a(Colors.fg, 0.45)
                    }

                    MouseArea {
                        id: dismissMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.dismissRequested()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.artist
                color: root.secondaryText
                elide: Text.ElideRight
                font.family: root.fontFamily
                font.pixelSize: 10
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 7
                visible: root.mediaLength > 0

                Text {
                    text: root.formatTime(root.mediaPosition)
                    color: a(Colors.fg, 0.35)
                    font.family: root.fontFamily
                    font.pixelSize: 9
                    font.bold: true
                }

                Rectangle {
                    id: mediaProgressTrack

                    Layout.fillWidth: true
                    Layout.preferredHeight: 3
                    radius: height / 2
                    color: a(Colors.fg, 0.05)

                    Rectangle {
                        width: parent.width * root.mediaProgress
                        height: parent.height
                        radius: parent.radius
                        color: Colors.accent

                        Behavior on width {
                            NumberAnimation {
                                duration: 260
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -5
                        enabled: root.canSeek
                        hoverEnabled: true
                        cursorShape: root.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor

                        function seekToX(x) {
                            const progress = Math.max(0, Math.min(1, x / Math.max(1, mediaProgressTrack.width)));
                            root.seekRequested(root.mediaLength * progress);
                        }

                        onPressed: event => seekToX(event.x)
                        onPositionChanged: event => {
                            if (pressed)
                                seekToX(event.x);
                        }
                    }
                }

                Text {
                    text: root.formatTime(root.mediaLength)
                    color: a(Colors.fg, 0.35)
                    font.family: root.fontFamily
                    font.pixelSize: 9
                    font.bold: true
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 1
                spacing: 7

                Rectangle {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    radius: 10
                    color: shuffleMouse.containsMouse && root.shuffleSupported ? a(Colors.accent, 0.1) : (root.shuffleActive ? a(Colors.accent, 0.2) : "transparent")
                    border.width: 1
                    border.color: root.shuffleActive ? Colors.accent : (root.shuffleSupported ? a(Colors.accent, 0.15) : "transparent")
                    opacity: root.shuffleSupported ? 1 : 0.35

                    MIcon {
                        anchors.centerIn: parent
                        name: "󰒝"
                        size: 13
                        color: root.shuffleActive ? Colors.accent : Colors.fg
                    }

                    MouseArea {
                        id: shuffleMouse

                        anchors.fill: parent
                        enabled: root.shuffleSupported
                        hoverEnabled: true
                        cursorShape: root.shuffleSupported ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.shuffleRequested()
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    radius: 10
                    color: previousMouse.containsMouse && root.canGoPrevious ? a(Colors.accent, 0.1) : "transparent"
                    border.width: 1
                    border.color: root.canGoPrevious ? a(Colors.accent, 0.15) : "transparent"
                    opacity: root.canGoPrevious ? 1 : 0.35

                    MIcon {
                        anchors.centerIn: parent
                        name: "󰒮"
                        size: 13
                        color: Colors.fg
                    }

                    MouseArea {
                        id: previousMouse

                        anchors.fill: parent
                        enabled: root.canGoPrevious
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.previousRequested()
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: 12
                    color: playPauseMouse.containsMouse && root.canTogglePlaying ? a(Colors.accent, 0.15) : a(Colors.accent, 0.05)
                    border.width: 1
                    border.color: root.canTogglePlaying ? a(Colors.accent, 0.25) : "transparent"
                    opacity: root.canTogglePlaying ? 1 : 0.35

                    MIcon {
                        anchors.centerIn: parent
                        name: root.playing ? "󰏤" : "󰐊"
                        size: 15
                        color: Colors.fg
                        bold: true
                    }

                    MouseArea {
                        id: playPauseMouse

                        anchors.fill: parent
                        enabled: root.canTogglePlaying
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.playPauseRequested()
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    radius: 10
                    color: nextMouse.containsMouse && root.canGoNext ? a(Colors.accent, 0.1) : "transparent"
                    border.width: 1
                    border.color: root.canGoNext ? a(Colors.accent, 0.15) : "transparent"
                    opacity: root.canGoNext ? 1 : 0.35

                    MIcon {
                        anchors.centerIn: parent
                        name: "󰒭"
                        size: 13
                        color: Colors.fg
                    }

                    MouseArea {
                        id: nextMouse

                        anchors.fill: parent
                        enabled: root.canGoNext
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.nextRequested()
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    radius: 10
                    color: loopMouse.containsMouse && root.loopSupported ? a(Colors.accent, 0.1) : (root.loopActive ? a(Colors.accent, 0.2) : "transparent")
                    border.width: 1
                    border.color: root.loopActive ? Colors.accent : (root.loopSupported ? a(Colors.accent, 0.15) : "transparent")
                    opacity: root.loopSupported ? 1 : 0.35

                    MIcon {
                        anchors.centerIn: parent
                        name: root.loopStateText === "ONE" ? "󰑘" : "󰑖"
                        size: 13
                        color: root.loopActive ? Colors.accent : Colors.fg
                    }

                    MouseArea {
                        id: loopMouse

                        anchors.fill: parent
                        enabled: root.loopSupported
                        hoverEnabled: true
                        cursorShape: root.loopSupported ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.loopRequested()
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    radius: 10
                    color: favoriteMouse.containsMouse ? a(Colors.accent, 0.1) : "transparent"
                    border.width: 1
                    border.color: a(Colors.accent, 0.15)

                    MIcon {
                        anchors.centerIn: parent
                        name: "󰋑"
                        size: 13
                        color: Colors.fg
                    }

                    MouseArea {
                        id: favoriteMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.favoriteRequested()
                    }
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Animations.fast
            }
        }
    }

    // 5. Launcher — Search + App Grid
    Item {
        id: launcherContent
        anchors.fill: parent
        opacity: root.mode === "launcher" ? 1 : 0
        visible: opacity > 0

        Timer {
            id: launcherFocusDelay
            interval: 80
            repeat: false
            onTriggered: launcherSearchInput.forceActiveFocus()
        }

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // Search bar
            Rectangle {
                width: parent.width
                height: 40
                radius: 10
                color: a(Colors.surface, 0.7)
                border.width: 1
                border.color: launcherSearchInput.activeFocus ? a(Colors.accent, 0.5) : a(Colors.fg, 0.06)

                Behavior on border.color { ColorAnimation { duration: Animations.fast } }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ""
                        color: launcherSearchInput.activeFocus ? Colors.accent : a(Colors.fg, 0.3)
                        font.family: root.fontFamily
                        font.pixelSize: 14
                        font.bold: true
                    }

                    TextInput {
                        id: launcherSearchInput
                        width: parent.width - 60
                        anchors.verticalCenter: parent.verticalCenter
                        color: Colors.fg
                        font.family: root.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                        selectByMouse: true
                        clip: true
                        maximumLength: 60

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Pesquisar apps..."
                            color: a(Colors.fg, 0.2)
                            font: parent.font
                            visible: !parent.text && !parent.activeFocus
                        }

                        onTextChanged: root.launcherSearchChanged(text)

                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Down) {
                                root.launcherMoveSelectionRequested(1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up) {
                                root.launcherMoveSelectionRequested(-1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Right) {
                                root.launcherMoveSelectionRequested(1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Left) {
                                root.launcherMoveSelectionRequested(-1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                var list = root.launcherQuery === "" ? root.launcherTopApps : root.launcherFiltered;
                                if (list.length > 0 && root.launcherSelected < list.length)
                                    root.launcherAppLaunchRequested(list[root.launcherSelected]);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Escape) {
                                root.launcherCloseRequested();
                                event.accepted = true;
                            }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰅖"
                        color: clearLauncherMa.containsMouse ? Colors.fg : a(Colors.fg, 0.25)
                        font.family: root.fontFamily
                        font.pixelSize: 11
                        visible: launcherSearchInput.text.length > 0

                        MouseArea {
                            id: clearLauncherMa
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { launcherSearchInput.text = ""; launcherSearchInput.forceActiveFocus() }
                        }
                    }
                }
            }

            // App grid (no query) / Filtered list (query active)
            Item {
                width: parent.width
                height: parent.height - 50

                // Top apps grid — 4 columns
                RowLayout {
                    anchors.fill: parent
                    spacing: 16
                    visible: root.launcherQuery === "" && root.launcherTopApps && root.launcherTopApps.length > 0

                    // Left Column: Top/Recent Apps Grid (2 columns)
                    Grid {
                        id: launcherGrid
                        Layout.preferredWidth: 260
                        Layout.fillHeight: true
                        columns: 2
                        spacing: 6

                        Repeater {
                            model: root.launcherTopApps

                            Rectangle {
                                id: gridCell
                                required property int index
                                required property var modelData

                                width: (launcherGrid.width - 6) / 2
                                height: (launcherGrid.height - 18) / 4
                                radius: 10
                                color: index === root.launcherSelected
                                    ? a(Colors.accent, 0.12)
                                    : gridCellMa.containsMouse ? a(Colors.fg, 0.05) : a(Colors.surface, 0.35)
                                border.width: index === root.launcherSelected ? 1 : 0
                                border.color: a(Colors.accent, 0.4)
                                scale: gridCellMa.pressed ? 0.92 : 1

                                Behavior on color { ColorAnimation { duration: Animations.fast } }
                                Behavior on scale { NumberAnimation { duration: Animations.snap; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    Rectangle {
                                        width: 28
                                        height: 28
                                        radius: 7
                                        color: a(Colors.fg, 0.05)
                                        Layout.alignment: Qt.AlignVCenter

                                        Image {
                                            anchors.centerIn: parent
                                            width: 18
                                            height: 18
                                            source: {
                                                var icon = gridCell.modelData.icon
                                                if (!icon || icon === "") return "image://icon/application-x-executable"
                                                if (icon.indexOf("/") === 0) return "file://" + icon
                                                return "image://icon/" + icon
                                            }
                                            fillMode: Image.PreserveAspectFit
                                            asynchronous: true
                                            cache: true
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: gridCell.modelData.name
                                        color: index === root.launcherSelected ? Colors.accent : Colors.fg
                                        font.family: root.fontFamily
                                        font.pixelSize: 10
                                        font.bold: index === root.launcherSelected
                                        elide: Text.ElideRight
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                }

                                MouseArea {
                                    id: gridCellMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.launcherAppLaunchRequested(gridCell.modelData)
                                    onContainsMouseChanged: { if (containsMouse) root.launcherSelected = gridCell.index }
                                }
                            }
                        }
                    }

                    // Right Column: Additional System Settings Toggles & Sliders
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 12

                        Text {
                            text: "Ajustes do Sistema"
                            color: Colors.accent
                            font.family: root.fontFamily
                            font.pixelSize: 12
                            font.bold: true
                            Layout.fillWidth: true
                        }

                        // Grid of 4 toggle buttons
                        Grid {
                            Layout.fillWidth: true
                            columns: 2
                            spacing: 8

                            // Button 1: DND
                            Rectangle {
                                width: (parent.width - 8) / 2
                                height: 42
                                radius: 8
                                color: UIState.dndEnabled ? a(Colors.accent, 0.15) : a(Colors.fg, 0.05)
                                border.width: UIState.dndEnabled ? 1 : 0
                                border.color: a(Colors.accent, 0.3)

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    MIcon {
                                        name: UIState.dndEnabled ? "󰍶" : "󰍷"
                                        size: 13
                                        color: UIState.dndEnabled ? Colors.accent : a(Colors.fg, 0.4)
                                    }

                                    Text {
                                        text: "DND"
                                        color: UIState.dndEnabled ? Colors.fg : a(Colors.fg, 0.45)
                                        font.family: root.fontFamily
                                        font.pixelSize: 10
                                        font.bold: true
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: UIState.toggleDnd()
                                }
                            }

                            // Button 2: Dark Mode
                            Rectangle {
                                width: (parent.width - 8) / 2
                                height: 42
                                radius: 8
                                color: UIState.darkMode ? a(Colors.accent, 0.15) : a(Colors.fg, 0.05)
                                border.width: UIState.darkMode ? 1 : 0
                                border.color: a(Colors.accent, 0.3)

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    MIcon {
                                        name: UIState.darkMode ? "󰖔" : "󰖕"
                                        size: 13
                                        color: UIState.darkMode ? Colors.accent : a(Colors.fg, 0.4)
                                    }

                                    Text {
                                        text: "Escuro"
                                        color: UIState.darkMode ? Colors.fg : a(Colors.fg, 0.45)
                                        font.family: root.fontFamily
                                        font.pixelSize: 10
                                        font.bold: true
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: UIState.toggleDarkMode()
                                }
                            }

                            // Button 3: Transparência
                            Rectangle {
                                width: (parent.width - 8) / 2
                                height: 42
                                radius: 8
                                color: UIState.transparencyEnabled ? a(Colors.accent, 0.15) : a(Colors.fg, 0.05)
                                border.width: UIState.transparencyEnabled ? 1 : 0
                                border.color: a(Colors.accent, 0.3)

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    MIcon {
                                        name: "󱡔"
                                        size: 13
                                        color: UIState.transparencyEnabled ? Colors.accent : a(Colors.fg, 0.4)
                                    }

                                    Text {
                                        text: "Vidro"
                                        color: UIState.transparencyEnabled ? Colors.fg : a(Colors.fg, 0.45)
                                        font.family: root.fontFamily
                                        font.pixelSize: 10
                                        font.bold: true
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: UIState.toggleTransparency()
                                }
                            }

                            // Button 4: Random Wallpaper
                            Rectangle {
                                width: (parent.width - 8) / 2
                                height: 42
                                radius: 8
                                color: a(Colors.fg, 0.05)

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    MIcon {
                                        name: "󰏘"
                                        size: 13
                                        color: a(Colors.fg, 0.4)
                                    }

                                    Text {
                                        text: "Wallpaper"
                                        color: a(Colors.fg, 0.45)
                                        font.family: root.fontFamily
                                        font.pixelSize: 10
                                        font.bold: true
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        randomWallProc.command = ["bash", "-c", "touch /tmp/qs-wallpaper-toggle"]
                                        randomWallProc.running = true
                                    }
                                }
                            }
                        }

                        // Divider line
                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: a(Colors.fg, 0.06)
                        }

                        // Cycling Toggles (Animations, Blur, Border Radius)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            // Row 1: Animations Profile
                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    text: "Animações"
                                    color: a(Colors.fg, 0.4)
                                    font.family: root.fontFamily
                                    font.pixelSize: 9
                                    font.bold: true
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    Layout.preferredWidth: 90
                                    Layout.preferredHeight: 20
                                    radius: 5
                                    color: a(Colors.fg, 0.05)

                                    Text {
                                        anchors.centerIn: parent
                                        text: UIState.animationProfile.toUpperCase()
                                        color: Colors.accent
                                        font.family: root.fontFamily
                                        font.pixelSize: 8
                                        font.bold: true
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var profiles = ["bubbly", "calm", "snappy", "extraslow", "none"]
                                            var idx = profiles.indexOf(UIState.animationProfile)
                                            var next = profiles[(idx + 1) % profiles.length]
                                            UIState.setAnimationProfile(next)
                                        }
                                    }
                                }
                            }

                            // Row 2: Blur Profile
                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    text: "Desfoque (Blur)"
                                    color: a(Colors.fg, 0.4)
                                    font.family: root.fontFamily
                                    font.pixelSize: 9
                                    font.bold: true
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    Layout.preferredWidth: 90
                                    Layout.preferredHeight: 20
                                    radius: 5
                                    color: a(Colors.fg, 0.05)

                                    Text {
                                        anchors.centerIn: parent
                                        text: UIState.blurProfile.toUpperCase()
                                        color: Colors.accent
                                        font.family: root.fontFamily
                                        font.pixelSize: 8
                                        font.bold: true
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var profiles = ["frosted", "balanced", "subtle", "none"]
                                            var idx = profiles.indexOf(UIState.blurProfile)
                                            var next = profiles[(idx + 1) % profiles.length]
                                            UIState.setBlurProfile(next)
                                        }
                                    }
                                }
                            }

                            // Row 3: Border Radius
                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    text: "Cantos Arredondados"
                                    color: a(Colors.fg, 0.4)
                                    font.family: root.fontFamily
                                    font.pixelSize: 9
                                    font.bold: true
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    Layout.preferredWidth: 90
                                    Layout.preferredHeight: 20
                                    radius: 5
                                    color: a(Colors.fg, 0.05)

                                    Text {
                                        anchors.centerIn: parent
                                        text: UIState.borderRadius === 16 ? "ARREDONDADO" : (UIState.borderRadius === 8 ? "CURTO" : "RETILÍNEO")
                                        color: Colors.accent
                                        font.family: root.fontFamily
                                        font.pixelSize: 8
                                        font.bold: true
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var radii = [0, 8, 16]
                                            var idx = radii.indexOf(UIState.borderRadius)
                                            var next = radii[(idx + 1) % radii.length]
                                            UIState.setBorderRadius(next)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Filtered results list
                ListView {
                    id: launcherList
                    anchors.fill: parent
                    clip: true
                    spacing: 3
                    model: root.launcherFiltered
                    visible: root.launcherQuery !== ""
                    boundsBehavior: Flickable.StopAtBounds
                    highlightMoveDuration: Animations.snap

                    highlight: Rectangle {
                        radius: 8
                        color: a(Colors.accent, 0.10)
                        border.width: 1
                        border.color: a(Colors.accent, 0.3)
                    }

                    add: Transition {
                        ParallelAnimation {
                            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Animations.medium; easing.type: Easing.OutCubic }
                            NumberAnimation { property: "x"; from: 12; to: 0; duration: Animations.medium; easing.type: Easing.OutExpo }
                        }
                    }

                    displaced: Transition {
                        NumberAnimation { property: "y"; duration: Animations.fast; easing.type: Easing.OutExpo }
                    }

                    delegate: Rectangle {
                        id: listDelegate
                        required property int index
                        required property var modelData

                        width: launcherList.width
                        height: 42
                        radius: 8
                        color: "transparent"

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            Rectangle {
                                width: 28
                                height: 28
                                radius: 7
                                color: a(Colors.fg, 0.04)
                                anchors.verticalCenter: parent.verticalCenter

                                Image {
                                    anchors.centerIn: parent
                                    width: 18
                                    height: 18
                                    source: {
                                        var icon = listDelegate.modelData.icon
                                        if (!icon || icon === "") return "image://icon/application-x-executable"
                                        if (icon.indexOf("/") === 0) return "file://" + icon
                                        return "image://icon/" + icon
                                    }
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    cache: true
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1
                                width: parent.width - 56

                                Text {
                                    text: listDelegate.modelData.name
                                    color: listDelegate.index === root.launcherSelected ? Colors.accent : Colors.fg
                                    font.family: root.fontFamily
                                    font.pixelSize: 11
                                    font.bold: listDelegate.index === root.launcherSelected
                                    width: parent.width
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: listDelegate.modelData.desc || ""
                                    color: a(Colors.fg, 0.25)
                                    font.family: root.fontFamily
                                    font.pixelSize: 8
                                    width: parent.width
                                    elide: Text.ElideRight
                                    visible: text !== ""
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "↵"
                                color: Colors.accent
                                font.family: root.fontFamily
                                font.pixelSize: 11
                                font.bold: true
                                visible: listDelegate.index === root.launcherSelected
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.launcherAppLaunchRequested(listDelegate.modelData)
                            onContainsMouseChanged: { if (containsMouse) root.launcherSelected = listDelegate.index }
                        }
                    }
                }

                // Empty state
                Text {
                    anchors.centerIn: parent
                    text: root.launcherQuery !== "" && root.launcherFiltered.length === 0 ? "Nenhum resultado" : ""
                    color: a(Colors.fg, 0.18)
                    font.family: root.fontFamily
                    font.pixelSize: 12
                    visible: text !== ""
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Animations.fast
            }
        }
    }

    MouseArea {
        id: mediaWheelArea
        anchors.fill: mediaContent
        acceptedButtons: Qt.NoButton // Allow clicks to fall through to child buttons
        visible: mediaContent.visible && mediaContent.opacity > 0
        onWheel: (wheel) => {
            if (wheel.angleDelta.y > 0) {
                root.nextRequested();
            } else {
                root.previousRequested();
            }
        }
    }
}
