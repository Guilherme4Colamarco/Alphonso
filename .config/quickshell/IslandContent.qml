import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

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
    property string timeText: ""
    property string dateText: ""
    property string fontFamily: "JetBrainsMono Nerd Font"

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

    // 1. Mídia minimizada (pílula ociosa ativa)
    Item {
        id: collapsedBumpMedia

        anchors.fill: parent
        opacity: root.mode === "idle" && !root.forceExpanded && root.handleStyle === "bump" ? 1 : 0
        visible: opacity > 0

        Rectangle {
            id: collapsedCover

            x: 9
            y: 4
            width: 14
            height: 14
            radius: 5
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
                        width: 2
                        height: root.playing ? (5 + index * 2) : 4
                        radius: 1
                        color: root.playing ? Colors.accent : a(Colors.fg, 0.35)

                        SequentialAnimation on height {
                            running: collapsedBumpMedia.visible && root.playing
                            loops: Animation.Infinite

                            NumberAnimation {
                                to: 4 + index
                                duration: 280 + index * 70
                                easing.type: Easing.InOutSine
                            }

                            NumberAnimation {
                                to: 8 - index
                                duration: 320 + index * 70
                                easing.type: Easing.InOutSine
                            }
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
            anchors.left: root.mediaAvailable ? collapsedCover.right : parent.left
            anchors.leftMargin: root.mediaAvailable ? 9 : 0
            anchors.right: parent.right
            anchors.rightMargin: root.mediaAvailable ? 9 : 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.timeText
            color: root.primaryText
            horizontalAlignment: root.mediaAvailable ? Text.AlignLeft : Text.AlignHCenter
            elide: Text.ElideRight
            font.family: root.fontFamily
            font.pixelSize: 11
            font.bold: true
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
            anchors.topMargin: 6
            anchors.bottomMargin: 7
            spacing: 2

            HandleStyleSwitch {
                handleStyle: root.handleStyle
                batteryCharging: root.batteryCharging
                batteryLevel: root.batteryLevel
                fontFamily: root.fontFamily
                showBattery: true
                onHandleStyleRequested: style => root.handleStyleRequested(style)
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
                        font.pixelSize: 22
                        font.bold: true
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.dateText
                        color: root.secondaryText
                        elide: Text.ElideRight
                        font.family: root.fontFamily
                        font.pixelSize: 10
                        font.bold: true
                    }
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                    spacing: 5

                    // WiFi
                    Item {
                        Layout.alignment: Qt.AlignRight
                        Layout.preferredWidth: wifiRow.width
                        Layout.preferredHeight: wifiRow.height

                        Row {
                            id: wifiRow
                            spacing: 4

                            MIcon {
                                name: root.wifiConnected ? (root.wifiSsid === "Ethernet" ? "󰈀" : (root.wifiSignal >= 70 ? "󰤨" : root.wifiSignal >= 40 ? "󰤥" : "󰤢")) : "󰤮"
                                size: 12
                                color: root.wifiConnected ? Colors.accent : a(Colors.fg, 0.3)
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: root.wifiConnected ? root.wifiSsid : "Desconectado"
                                color: root.wifiConnected ? Colors.fg : a(Colors.fg, 0.35)
                                font.family: root.fontFamily
                                font.pixelSize: 9
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.wifiSettingsRequested()
                        }
                    }

                    // Bluetooth
                    Item {
                        Layout.alignment: Qt.AlignRight
                        Layout.preferredWidth: btRow.width
                        Layout.preferredHeight: btRow.height

                        Row {
                            id: btRow
                            spacing: 4

                            MIcon {
                                name: "󰂯"
                                size: 12
                                color: root.btConnected ? Colors.accent : (root.btEnabled ? Colors.fg : a(Colors.fg, 0.3))
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: root.btConnected ? (root.btBattery >= 0 ? root.btDeviceName + " " + root.btBattery + "%" : root.btDeviceName) : (root.btEnabled ? "Ativo" : "Inativo")
                                color: root.btConnected ? Colors.fg : a(Colors.fg, 0.35)
                                font.family: root.fontFamily
                                font.pixelSize: 9
                                font.bold: true
                                elide: Text.ElideRight
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.btSettingsRequested()
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
                        height: root.playing ? (12 + index * 5) : 10
                        radius: 2
                        color: root.playing ? Colors.accent : a(Colors.fg, 0.3)

                        SequentialAnimation on height {
                            running: root.mode === "media" && root.playing
                            loops: Animation.Infinite

                            NumberAnimation {
                                to: 10 + index * 4
                                duration: 360 + index * 80
                                easing.type: Easing.InOutSine
                            }

                            NumberAnimation {
                                to: 23 - index * 3
                                duration: 420 + index * 80
                                easing.type: Easing.InOutSine
                            }
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

                Text {
                    Layout.fillWidth: true
                    text: root.title
                    color: root.primaryText
                    elide: Text.ElideRight
                    font.family: root.fontFamily
                    font.pixelSize: 13
                    font.bold: true
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
}
