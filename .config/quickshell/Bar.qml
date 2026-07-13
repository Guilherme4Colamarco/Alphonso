import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

Scope {
    id: root

    property string time: ""
    property bool wifi: false
    property bool bt: false
    property bool eth: false
    property int bat: 100
    property bool plug: false
    property bool batFull: plug && bat >= 100
    property bool hasBattery: false
    property real pulse: 1
    property int tag: 1
    property var occ: [false,false,false,false,false]
    property bool barReady: false
    property string distroIcon: "󰺔"

    property bool attachedVisible: false

    Binding {
        target: BluetoothState
        property: "power"
        value: root.bt
    }

    Binding {
        target: root
        property: "bt"
        value: BluetoothState.power
        when: !btToggle.running
    }

    function parseTagOutput(data) {
        if (!data || data.trim() === "") return;
        try {
            var json = JSON.parse(data.trim());
            if (json.all_tags && json.all_tags.length > 0) {
                // Assuming primary monitor is first; adjust if multi-monitor specific tags are needed.
                var tags = json.all_tags[0].tags;
                var newOcc = [false, false, false, false, false];
                for (var i = 0; i < tags.length; i++) {
                    var t = tags[i];
                    var n = t.index;
                    if (n >= 1 && n <= 5) {
                        if (t.is_active) tag = n;
                        newOcc[n - 1] = t.client_count > 0;
                    }
                }
                occ = newOcc;
            }
        } catch (e) {
            console.warn("Failed to parse mmsg output:", e, "Data:", data);
        }
    }

    function volIcon() {
        if (UIState.muted) return "󰖁"
        if (UIState.volume > 60) return "󰕾"
        if (UIState.volume > 25) return "󰖀"
        return "󰕿"
    }

    function batIcon() {
        if (batFull) return "󰁹"
        if (plug) return "󰂄"
        if (bat > 90) return "󰁹"
        if (bat > 70) return "󰂁"
        if (bat > 50) return "󰁿"
        if (bat > 30) return "󰁾"
        if (bat > 15) return "󰁼"
        return "󰂃"
    }

    function batColor() {
        if (batFull) return Colors.green
        if (plug) return Colors.accent
        if (bat <= 15) return Colors.red
        if (bat <= 30) return Colors.yellow
        return Colors.fg
    }

    function adjustVol(delta) {
        UIState.setVolume(Math.max(0, Math.min(100, UIState.volume + delta)))
    }

    function showAttached() {
        attachedVisible = true
        attachedHideTimer.restart()
    }

    Process {
        id: tagWatch
        command: ["mmsg", "watch", "all-tags"]
        running: true
        stdout: SplitParser { splitMarker: "\n"; onRead: data => parseTagOutput(data) }
        onExited: tagRestart.start()
    }

    Timer { id: tagRestart; interval: 1000; onTriggered: tagWatch.running = true }

    Process {
        id: tagGet
        command: ["mmsg", "get", "all-tags"]
        running: true
        stdout: SplitParser { splitMarker: "\n"; onRead: data => parseTagOutput(data) }
    }

    Process { id: tagSet }

    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: time = Qt.formatDateTime(new Date(), "h:mm A")
    }

    Process {
        id: wifiWatch
        command: ["nmcli", "monitor"]
        running: true
        stdout: SplitParser { onRead: data => wifiDebounce.restart() }
        onExited: wifiWatchRestart.start()
    }

    Timer { id: wifiWatchRestart; interval: 1000; onTriggered: wifiWatch.running = true }
    Timer { id: wifiDebounce; interval: 80; onTriggered: wifiProc.running = true }

    Process {
        id: wifiProc
        command: ["bash", "-c", "nmcli -t -f active dev wifi 2>/dev/null | grep -q yes && echo 1 || echo 0"]
        running: true
        stdout: SplitParser { onRead: data => wifi = data.trim() === "1" }
    }

    Process {
        id: ethProc
        command: ["bash", "-c", "nmcli -t -f TYPE,STATE con show --active 2>/dev/null | grep -q '^802-3-ethernet:activated' && echo 1 || echo 0"]
        running: true
        stdout: SplitParser { onRead: data => eth = data.trim() === "1" }
    }

    Timer {
        id: ethPoll
        interval: 3000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: ethProc.running = true
    }

    Process {
        id: btWatch
        command: ["dbus-monitor", "--system", "type='signal',sender='org.bluez'"]
        running: true
        stdout: SplitParser { onRead: data => btDebounce.restart() }
        onExited: btWatchRestart.start()
    }

    Timer { id: btWatchRestart; interval: 1000; onTriggered: btWatch.running = true }
    Timer { id: btDebounce; interval: 80; onTriggered: btProc.running = true }

    Process {
        id: btProc
        command: ["bash", "-c", "for m in $(bluetoothctl devices 2>/dev/null | awk '{print $2}'); do bluetoothctl info $m 2>/dev/null | grep -q 'Connected: yes' && echo 1 && exit; done; echo 0"]
        running: true
        stdout: SplitParser { onRead: data => bt = data.trim() === "1" }
    }

    Process {
        id: batDetect
        command: ["bash", "-c", "ls /sys/class/power_supply/BAT* >/dev/null 2>&1 && echo 1 || echo 0"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                hasBattery = (data.trim() === "1")
                if (hasBattery) {
                    batWatch.running = true
                    batProc.running = true
                }
            }
        }
    }

    Process {
        id: batWatch
        command: ["upower", "--monitor-detail"]
        running: false
        stdout: SplitParser { onRead: data => { if (hasBattery) batDebounce.restart() } }
        onExited: { if (hasBattery) batWatchRestart.start() }
    }

    Timer { id: batWatchRestart; interval: 1000; onTriggered: { if (hasBattery) batWatch.running = true } }
    Timer { id: batDebounce; interval: 80; onTriggered: { if (hasBattery) batProc.running = true } }

    Process {
        id: batProc
        command: ["bash", "-c", "c=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1); s=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1); [ -z \"$c\" ] && c=100; echo \"$c|$s\""]
        running: false
        stdout: SplitParser {
            onRead: data => {
                var p = data.trim().split("|")
                bat = parseInt(p[0]) || 100
                plug = (p[1] === "Charging" || p[1] === "Full")
            }
        }
    }

    Process { id: volToggle; command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"] }
    Process { id: wifiToggle; command: ["bash", "-c", "nmcli radio wifi $(nmcli radio wifi | grep -qi disabled && echo on || echo off)"] }
    Process { id: btToggle; command: ["bluetoothctl", "power", "toggle"] }
    Process { id: wifiManager; command: ["nm-connection-editor"] }
    Process { id: btManager; command: ["blueman-manager"] }

    Process {
        id: distroDetect
        command: ["bash", "-c", ". /etc/os-release 2>/dev/null && echo \"$ID\" \"$ID_LIKE\" || echo unknown"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var id = data.trim().toLowerCase()
                var icons = {
                    "arch": "\uF303", "cachyos": "\uF303", "artix": "\uF303",
                    "endeavouros": "\uF303", "manjaro": "\uF303",
                    "nixos": "\uF313",
                    "fedora": "\uF30A",
                    "void": "\uF31E",
                    "gentoo": "\uF30D",
                    "debian": "\uF306", "ubuntu": "\uF31C",
                    "linuxmint": "\uF311", "pop": "\uF306",
                    "alpine": "\uF300", "opensuse": "\uF314",
                    "freebsd": "\uF30B", "raspbian": "\uF315"
                }
                var found = false
                for (var key in icons) {
                    if (id.indexOf(key) !== -1) {
                        distroIcon = icons[key]
                        found = true
                        break
                    }
                }
                if (!found) {
                    // check ID_LIKE
                    distroIcon = "\uF31A" // tux fallback
                }
            }
        }
    }

    SequentialAnimation {
        running: plug && !batFull
        loops: Animation.Infinite
        NumberAnimation { target: root; property: "pulse"; to: 0.4; duration: Animations.xslow; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "pulse"; to: 1;   duration: Animations.xslow; easing.type: Easing.InOutSine }
    }

    Timer {
        id: startDelay
        interval: 80
        running: Colors.revision >= 0
        onTriggered: barReady = true
    }

    Timer {
        id: attachedHideTimer
        interval: 800
        onTriggered: {
            var dropdownOpen = UIState.activeDropdown === "dashboard"
                            || UIState.activeDropdown === "calendar"
                            || UIState.activeDropdown === "media"
            if (!dropdownOpen) attachedVisible = false
        }
    }

    Connections {
        target: UIState
        function onNotificationReceived() {
            if (UIState.barMode === "autohide") showAttached()
        }
    }

    Connections {
        target: UIState
        function onActiveDropdownChanged() {
            if (UIState.barMode === "autohide") {
                var dropdownOpen = UIState.activeDropdown === "dashboard"
                                || UIState.activeDropdown === "calendar"
                                || UIState.activeDropdown === "media"
                if (dropdownOpen) {
                    attachedVisible = true
                    attachedHideTimer.stop()
                }
            }
        }
    }

    component BarContent: Item {
        property bool compact: false

        anchors.fill: parent
        anchors.leftMargin: Metrics.dp(14)
anchors.rightMargin: Metrics.dp(14)
        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Metrics.dp(14)
            Item {
                width: clockText.implicitWidth
                height: compact ? 20 : 24
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    id: clockText
                    anchors.centerIn: parent
                    text: time
                    color: clockMa.containsMouse ? Colors.a(Colors.accent, 0.85) : Colors.a(Colors.fg, 0.70)
                    font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font"; letterSpacing: 0.5 }
                    Behavior on color { ColorAnimation { duration: Animations.fast } }
                }

                Rectangle {
                    anchors {
                        bottom: parent.bottom
                        bottomMargin: 1
                        horizontalCenter: parent.horizontalCenter
                    }
                    width: clockMa.containsMouse ? parent.width + 4 : 0
                    height: Metrics.dp(2)
radius: Metrics.dp(1)
color: Colors.a(Colors.accent, 0.25)
                    Behavior on width { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutBack; easing.overshoot: Animations.springPower } }
                }

                MouseArea {
                    id: clockMa
                    anchors.fill: parent
                    anchors.margins: compact ? -6 : -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: UIState.toggleDropdown("calendar")
                }
            }

            Row {
                spacing: Metrics.dp(3)
anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: 5

                    Item {
                        required property int index
                        property bool active: tag === index + 1
                        property bool used:   occ[index]
                        property bool show:   active || used
                        property bool hov:    tagMa.containsMouse

                        width:  show ? pill.width + 4 : 0
                        height: compact ? 20 : 24
                        clip:   true
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on width { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }

                        onActiveChanged: {
                            if (active) activePop.restart()
                        }

                        SequentialAnimation {
                            id: activePop
                            NumberAnimation { target: pill; property: "scale"; to: 1.22; duration: Animations.snap; easing.type: Easing.OutQuad }
                            NumberAnimation { target: pill; property: "scale"; to: 1.0;  duration: Animations.medium; easing.type: Easing.OutBack; easing.overshoot: Animations.springPower }
                        }

                        Rectangle {
                            id: pill
                            width:  tagNum.implicitWidth + (compact ? 14 : 16)
                            height: compact ? 16 : 18
                            radius: compact ? 8 : 9
                            anchors.centerIn: parent
                            color: active ? Colors.a(Colors.accent, 0.10) : hov ? Colors.a(Colors.fg, 0.045) : "transparent"
                            border.width: active ? 1 : 0
                            border.color: Colors.a(Colors.accent, 0.15)
                            Behavior on color { ColorAnimation { duration: Animations.fast } }
                            Behavior on border.color { ColorAnimation { duration: Animations.fast } }

                            Text {
                                id: tagNum
                                anchors.centerIn: parent
                                text: index + 1
                                color: active ? Colors.a(Colors.accent, 0.85) : hov ? Colors.a(Colors.fg, 0.70) : Colors.a(Colors.fg, 0.40)
                                font { pixelSize: Metrics.sp(compact ? 9 : 10); family: "JetBrainsMono Nerd Font"; bold: active }
                                Behavior on color { ColorAnimation { duration: Animations.fast } }
                            }
                        }

                        MouseArea {
                            id: tagMa
                            anchors.fill: parent
                            anchors.margins: Metrics.dp(-4)
hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                tagSet.command = ["mmsg", "dispatch", "view," + String(index + 1)]
                                tagSet.running = true
                            }
                            onWheel: (wheel) => {
                                var newTag = (wheel.angleDelta.y > 0) ? (tag - 1) : (tag + 1)
                                if (newTag < 1) newTag = 5
                                if (newTag > 5) newTag = 1
                                tagSet.command = ["mmsg", "dispatch", "view," + String(newTag)]
                                tagSet.running = true
                            }
                        }
                    }
                }
            }
        }

        Item {
            anchors.centerIn: parent
            width: mediaVisible ? centerRow.implicitWidth : 0
            height: parent.height

            property bool mediaVisible: UIState.hasMedia

            opacity: mediaVisible ? 1 : 0
            scale:   mediaVisible ? 1 : 0.86

            Behavior on width   { NumberAnimation { duration: Animations.slow;   easing.type: Easing.OutExpo } }
            Behavior on opacity { NumberAnimation { duration: Animations.medium;  easing.type: Easing.OutCubic } }
            Behavior on scale   { NumberAnimation { duration: Animations.medium;  easing.type: Easing.OutBack; easing.overshoot: 1.4 } }

            Row {
                id: centerRow
                anchors.centerIn: parent
                spacing: Metrics.dp(10)
                Row {
                    spacing: Metrics.dp(2)
anchors.verticalCenter: parent.verticalCenter

                    Repeater {
                        model: 12
                        Rectangle {
                            required property int index
                            width:  Metrics.dp(2.5)
height: Math.max(3, UIState.cava[index] * (compact ? 13 : 16))
                            radius: Metrics.dp(1.25)
anchors.verticalCenter: parent.verticalCenter
                            color: UIState.mediaState !== "playing"
                                ? Colors.a(Colors.accent, 0.10 + UIState.cava[index] * 0.35)
                                : UIState.cava[index] > 0.7
                                    ? Colors.a(Colors.accent, 0.70)
                                    : Colors.a(Colors.accent, 0.25 + UIState.cava[index] * 0.30)
                            Behavior on height { NumberAnimation { duration: Animations.snap; easing.type: Easing.OutQuad } }
                        }
                    }
                }

                Text {
                    text: UIState.mediaState === "playing" ? "󰏤" : "󰐊"
                    color: Colors.a(Colors.fg, 0.30)
                    font { pixelSize: Metrics.sp(compact ? 9 : 10); family: "JetBrainsMono Nerd Font" }
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    id: marqueeRoot
                    property int  maxWidth:  140
                    property real gap:       36
                    property real unitWidth: marqueeA.implicitWidth + gap
                    property bool scrolling: marqueeA.implicitWidth > maxWidth

                    width:  scrolling ? maxWidth : marqueeA.implicitWidth
                    height: compact ? 20 : 24
                    clip:   true
                    anchors.verticalCenter: parent.verticalCenter

                    Row {
                        id: marqueeTrack
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Metrics.dp(0)
                        Text {
                            id: marqueeA
                            text:  UIState.mediaDisplay
                            color: mediaMa.containsMouse ? Colors.a(Colors.fg, 0.85) : Colors.a(Colors.fg, UIState.mediaState === "playing" ? 0.55 : 0.32)
                            font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font" }
                            Behavior on color { ColorAnimation { duration: Animations.fast } }
                        }

                        Item { width: marqueeRoot.gap; height: 1; visible: marqueeRoot.scrolling }

                        Text {
                            id: marqueeB
                            text:    UIState.mediaDisplay
                            color:   mediaMa.containsMouse ? Colors.a(Colors.fg, 0.85) : Colors.a(Colors.fg, UIState.mediaState === "playing" ? 0.55 : 0.32)
                            font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font" }
                            visible: marqueeRoot.scrolling
                            Behavior on color { ColorAnimation { duration: Animations.fast } }
                        }
                    }

                    NumberAnimation {
                        id: marqueeAnim
                        target:   marqueeTrack
                        property: "x"
                        from:     0
                        to:       -marqueeRoot.unitWidth
                        duration: marqueeRoot.unitWidth * 24
                        loops:    Animation.Infinite
                        running:  marqueeRoot.scrolling
                        easing.type: Easing.Linear
                    }

                    Connections {
                        target: UIState
                        function onMediaDisplayChanged() {
                            marqueeAnim.stop()
                            marqueeTrack.x = 0
                            if (marqueeRoot.scrolling) marqueeAnim.start()
                        }
                    }

                    Rectangle {
                        anchors {
                            bottom: parent.bottom
                            bottomMargin: 1
                            horizontalCenter: parent.horizontalCenter
                        }
                        width:  mediaMa.containsMouse ? parent.width + 4 : 0
                        height: Metrics.dp(2)
radius: Metrics.dp(1)
color:  Colors.a(Colors.accent, 0.25)
                        Behavior on width { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutBack; easing.overshoot: Animations.springPower } }
                    }
                }
            }

            MouseArea {
                id: mediaMa
                anchors.fill: parent
                anchors.margins: Metrics.dp(-8)
hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: function(mouse) {
                    if (mouse.button === Qt.RightButton) UIState.toggleDropdown("media")
                    else UIState.doMedia("play-pause")
                }
                onWheel: function(wheel) {
                    UIState.doMedia(wheel.angleDelta.y > 0 ? "next" : "previous")
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Metrics.dp(12)
            TrayBar {
                anchors.verticalCenter: parent.verticalCenter
            }

            Row {
                spacing: Metrics.dp(6)
anchors.verticalCenter: parent.verticalCenter

                PillButton {
                    icon: wifi ? "󰤨" : "󰤭"
                    iconSize: 13
                    active: wifi
                    inactiveColor: wifiMa_hov ? Colors.red : Colors.fg
                    property bool wifiMa_hov: containsMouse && !wifi
                    activeColor: Colors.accent
                    onClicked: wifiToggle.running = true
                }

                PillButton {
                    icon: bt ? "󰂯" : "󰂲"
                    iconSize: 12
                    active: bt
                    activeOpacity: 0.55
                    inactiveColor: btMa_hov ? Colors.red : Colors.fg
                    property bool btMa_hov: containsMouse && !bt
                    activeColor: Colors.fg
                    onClicked: btToggle.running = true
                }
            }

            Item {
                width:  volRow.width
                height: compact ? 20 : 24
                anchors.verticalCenter: parent.verticalCenter

                scale: volMa.containsMouse ? Animations.hoverScale : 1.0
                transformOrigin: Item.Center
                Behavior on scale { NumberAnimation { duration: Animations.fast; easing.type: Easing.OutCubic } }

                Row {
                    id: volRow
                    spacing: Metrics.dp(5)
anchors.centerIn: parent

                    Text {
                        text:  volIcon()
                        color: UIState.muted ? Colors.a(Colors.fg, 0.18) : volMa.containsMouse ? Colors.a(Colors.fg, 0.85) : Colors.a(Colors.fg, 0.60)
                        font { pixelSize: Metrics.sp(13); family: "JetBrainsMono Nerd Font" }
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: Animations.fast } }
                    }

                    Text {
                        text:  UIState.volume
                        color: UIState.muted ? Colors.a(Colors.fg, 0.18) : volMa.containsMouse ? Colors.a(Colors.fg, 0.85) : Colors.a(Colors.fg, 0.45)
                        font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font" }
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: Animations.fast } }
                    }
                }

                Rectangle {
                    anchors {
                        bottom: parent.bottom
                        bottomMargin: 1
                        horizontalCenter: parent.horizontalCenter
                    }
                    width: volMa.containsMouse ? parent.width + 4 : 0
                    height: Metrics.dp(2)
radius: Metrics.dp(1)
color: Colors.a(Colors.accent, 0.25)
                    Behavior on width { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutBack; easing.overshoot: Animations.springPower } }
                }

                MouseArea {
                    id: volMa
                    anchors.fill: parent
                    anchors.margins: Metrics.dp(-8)
hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: volToggle.running = true
                    onWheel: function(wheel) { adjustVol(wheel.angleDelta.y > 0 ? 5 : -5) }
                }
            }

            Item {
                visible: hasBattery
                width:  hasBattery ? batRow.width : 0
                height: compact ? 20 : 24
                anchors.verticalCenter: parent.verticalCenter

                Row {
                    id: batRow
                    spacing: Metrics.dp(4)
anchors.centerIn: parent

                    Text {
                        text:    batIcon()
                        color:   batColor()
                        Behavior on color { ColorAnimation { duration: Animations.fast } }
                        font { pixelSize: Metrics.sp(14); family: "JetBrainsMono Nerd Font" }
                        opacity: plug && !batFull ? pulse : 1
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text:  bat + "%"
                        color: batColor()
                        Behavior on color { ColorAnimation { duration: Animations.fast } }
                        font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font" }
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: bat <= 30 || plug || batMa.containsMouse ? 1 : 0.50
                        Behavior on opacity { NumberAnimation { duration: Animations.fast; easing.type: Easing.OutCubic } }
                    }
                }

                MouseArea {
                    id: batMa
                    anchors.fill: parent
                    anchors.margins: Metrics.dp(-6)
hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: UIState.toggleDropdown("dashboard")
                }
            }

            PillButton {
                icon: "⏻"
                iconSize: lit ? 12 : 11
                active: UIState.powerMenuVisible
                activeColor: Colors.red
                inactiveColor: Colors.fg
                hoverColor: Colors.red
                property bool lit: containsMouse || UIState.powerMenuVisible
                onClicked: UIState.togglePowerMenu()
            }

            PillButton {
                icon: distroIcon
                iconSize: lit ? 12 : 11
                active: UIState.activeDropdown === "dashboard"
                activeColor: Colors.accent
                hoverColor: Colors.accent
                property bool lit: containsMouse || UIState.activeDropdown === "dashboard"
                onClicked: UIState.toggleDropdown("dashboard")
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            property var modelData
            screen: modelData
            visible: UIState.barMode === "floating"
            anchors { top: true; left: true; right: true }
            implicitHeight: Metrics.dp(38)
color: "transparent"
            exclusionMode: ExclusionMode.Auto
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "bar"

            MaterialSurface {
                anchors.fill: parent
                anchors.topMargin:    Metrics.dp(5)
anchors.leftMargin:   barReady ? 8 : parent.width * 0.4
                anchors.rightMargin:  barReady ? 8 : parent.width * 0.4
                anchors.bottomMargin: Metrics.dp(3)
                role: "background"
                fillOpacity: UIState.barOpacity
                opacity: barReady ? 1 : 0
                scale:   barReady ? 1 : 0.94

                Behavior on anchors.leftMargin  { NumberAnimation { duration: Animations.xslow; easing.type: Easing.OutExpo } }
                Behavior on anchors.rightMargin { NumberAnimation { duration: Animations.xslow; easing.type: Easing.OutExpo } }
                Behavior on opacity { NumberAnimation { duration: Animations.slow; easing.type: Easing.OutCubic } }
                Behavior on scale   { NumberAnimation { duration: Animations.slow; easing.type: Easing.OutBack; easing.overshoot: Animations.springPower } }

                BarContent {
                    compact: false
                    opacity: barReady ? 1 : 0
                    scale:   barReady ? 1 : 0.92
                    Behavior on opacity { NumberAnimation { duration: Animations.slow; easing.type: Easing.OutCubic } }
                    Behavior on scale   { NumberAnimation { duration: Animations.slow; easing.type: Easing.OutCubic } }
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: attachedBar
            property var modelData
            screen: modelData
            visible: UIState.barMode === "autohide"
            anchors { top: true; left: true; right: true }
            implicitHeight: Metrics.dp(30)
color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "bar-autohide"

            MouseArea {
                id: peekZone
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: Metrics.dp(3)
enabled: !attachedVisible
                hoverEnabled: true
                onEntered: {
                    attachedVisible = true
                    attachedHideTimer.stop()
                }
            }

            MaterialSurface {
                anchors.left: parent.left
                anchors.right: parent.right
                implicitHeight: Metrics.dp(24)
y: attachedVisible ? 0 : -implicitHeight
                role: "background"
                fillOpacity: UIState.transparencyEnabled ? 0.88 : 1
                Behavior on y     { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutExpo } }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left:   parent.left
                    anchors.right:  parent.right
                    height: Metrics.dp(1)
color:  Colors.a(Colors.fg, 0.07)
                }

                BarContent {
                    compact: true
                }

                HoverHandler {
                    id: barHover
                    enabled: attachedVisible
                    margin: 6
                    onHoveredChanged: {
                        if (hovered) {
                            attachedVisible = true
                            attachedHideTimer.stop()
                        } else {
                            attachedHideTimer.restart()
                        }
                    }
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            property var modelData
            screen: modelData
            visible: UIState.barMode === "fixed"
            anchors { top: true; left: true; right: true }
            implicitHeight: Metrics.dp(24)
color: "transparent"
            exclusionMode: ExclusionMode.Auto
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "bar-fixed"

            MaterialSurface {
                anchors.fill: parent
                role: "background"
                fillOpacity: UIState.transparencyEnabled ? 0.88 : 1

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left:   parent.left
                    anchors.right:  parent.right
                    height: Metrics.dp(1)
color:  Colors.a(Colors.fg, 0.07)
                }

                BarContent {
                    compact: true
                }
            }
        }
    }

    component PillBarContent: Item {
        implicitWidth:  pillRow.implicitWidth
        implicitHeight: pillRow.implicitHeight
        anchors.centerIn: parent

        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: Metrics.dp(12)
            // ── left: battery ──
            Row {
                spacing: Metrics.dp(8)
anchors.verticalCenter: parent.verticalCenter
                visible: hasBattery

                Text {
                    text:    batIcon()
                    color:   batColor()
                    Behavior on color { ColorAnimation { duration: Animations.fast } }
                    font { pixelSize: Metrics.sp(14); family: "JetBrainsMono Nerd Font" }
                    opacity: plug && !batFull ? pulse : 1
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text:  bat + "%"
                    color: batColor()
                    Behavior on color { ColorAnimation { duration: Animations.fast } }
                    font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font" }
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: bat <= 30 || plug ? 1 : 0.55
                }
            }

            // ── center: tags ──
            Row {
                spacing: Metrics.dp(4)
anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: 5

                    Item {
                        required property int index
                        property bool active: tag === index + 1
                        property bool used:   occ[index]
                        property bool show:   active || used
                        property bool hov:    tagMa.containsMouse

                        width:  show ? pill.width + 4 : 0
                        height: Metrics.dp(24)
clip:   true
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on width { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }

                        Rectangle {
                            id: pill
                            width:  tagNum.implicitWidth + 14
                            height: Metrics.dp(20)
radius: Metrics.dp(10)
anchors.centerIn: parent
                            color: active ? Colors.a(Colors.accent, 0.12) : hov ? Colors.a(Colors.fg, 0.045) : "transparent"
                            border.width: active ? 1 : 0
                            border.color: Colors.a(Colors.accent, 0.15)
                            Behavior on color { ColorAnimation { duration: Animations.fast } }
                            Behavior on border.color { ColorAnimation { duration: Animations.fast } }

                            Text {
                                id: tagNum
                                anchors.centerIn: parent
                                text: index + 1
                                color: active ? Colors.a(Colors.accent, 0.85) : hov ? Colors.a(Colors.fg, 0.70) : Colors.a(Colors.fg, 0.40)
                                font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font"; bold: active }
                                Behavior on color { ColorAnimation { duration: Animations.fast } }
                            }
                        }

                        MouseArea {
                            id: tagMa
                            anchors.fill: parent
                            anchors.margins: Metrics.dp(-4)
hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                tagSet.command = ["mmsg", "dispatch", "view," + String(index + 1)]
                                tagSet.running = true
                            }
                            onWheel: (wheel) => {
                                var newTag = (wheel.angleDelta.y > 0) ? (tag - 1) : (tag + 1)
                                if (newTag < 1) newTag = 5
                                if (newTag > 5) newTag = 1
                                tagSet.command = ["mmsg", "dispatch", "view," + String(newTag)]
                                tagSet.running = true
                            }
                        }
                    }
                }
            }

// ── right: tray + volume + clock + power + dashboard ──
            Row {
                spacing: Metrics.dp(10)
anchors.verticalCenter: parent.verticalCenter

                TrayBar {
                    anchors.verticalCenter: parent.verticalCenter
                    iconPx: 16
                    itemPx: 24
                    itemH: 20
                    itemRadius: 10
                    itemSpacing: 6
                }

                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width:  volPillRow.implicitWidth
                    height: volPillRow.implicitHeight

                    Row {
                        id: volPillRow
                        spacing: Metrics.dp(6)
anchors.verticalCenter: parent.verticalCenter
                        scale: volMa.containsMouse ? Animations.hoverScale : 1.0
                        transformOrigin: Item.Center
                        Behavior on scale { NumberAnimation { duration: Animations.fast; easing.type: Easing.OutCubic } }

                        Text {
                            text:  volIcon()
                            color: UIState.muted ? Colors.a(Colors.fg, 0.18) : volMa.containsMouse ? Colors.a(Colors.fg, 0.85) : Colors.a(Colors.fg, 0.60)
                            font { pixelSize: Metrics.sp(13); family: "JetBrainsMono Nerd Font" }
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: Animations.fast } }
                        }

                        Text {
                            text:  UIState.volume
                            color: UIState.muted ? Colors.a(Colors.fg, 0.18) : volMa.containsMouse ? Colors.a(Colors.fg, 0.85) : Colors.a(Colors.fg, 0.45)
                            font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font" }
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: Animations.fast } }
                        }
                    }

                    MouseArea {
                        id: volMa
                        anchors.fill: parent
                        anchors.margins: Metrics.dp(-8)
hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: volToggle.running = true
                        onWheel: function(wheel) { adjustVol(wheel.angleDelta.y > 0 ? 5 : -5) }
                    }
                }

                Item {
                    width:  clockTextPill.implicitWidth
                    height: Metrics.dp(24)
anchors.verticalCenter: parent.verticalCenter

                    Text {
                        id: clockTextPill
                        anchors.centerIn: parent
                        text: time
                        color: clockMaPill.containsMouse ? Colors.a(Colors.accent, 0.85) : Colors.a(Colors.fg, 0.70)
                        font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font"; letterSpacing: 0.5 }
                        Behavior on color { ColorAnimation { duration: Animations.fast } }
                    }

                    MouseArea {
                        id: clockMaPill
                        anchors.fill: parent
                        anchors.margins: Metrics.dp(-6)
hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: UIState.toggleDropdown("calendar")
                    }
                }

                PillButton {
                    icon: "⏻"
                    iconSize: lit ? 12 : 11
                    active: UIState.powerMenuVisible
                    activeColor: Colors.red
                    inactiveColor: Colors.fg
                    hoverColor: Colors.red
                    property bool lit: containsMouse || UIState.powerMenuVisible
                    onClicked: UIState.togglePowerMenu()
                }

                PillButton {
                    icon: distroIcon
                    iconSize: 12
                    active: UIState.activeDropdown === "dashboard"
                    activeColor: Colors.accent
                    hoverColor: Colors.accent
                    property bool lit: containsMouse || UIState.activeDropdown === "dashboard"
                    onClicked: UIState.toggleDropdown("dashboard")
                }

                PillButton {
                    icon: bt ? "󰂯" : "󰂲"
                    iconSize: 13
                    active: bt
                    activeColor: Colors.accent
                    inactiveColor: btMa_hov ? Colors.red : Colors.fg
                    property bool btMa_hov: containsMouse && !bt
                    onClicked: btManager.running = true
                    onRightClicked: btToggle.running = true
                }

                PillButton {
                    visible: eth
                    icon: "󰈀"
                    iconSize: 13
                    active: eth
                    activeColor: Colors.accent
                    inactiveColor: Colors.fg
                    onClicked: {}
                }

                PillButton {
                    visible: !eth
                    icon: wifi ? "󰤨" : "󰤭"
                    iconSize: 13
                    active: wifi
                    activeColor: Colors.accent
                    inactiveColor: wifiMa_hov ? Colors.red : Colors.fg
                    property bool wifiMa_hov: containsMouse && !wifi
                    onClicked: wifiManager.running = true
                    onRightClicked: wifiToggle.running = true
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            property var modelData
            screen: modelData
            visible: UIState.barMode === "pill"
            anchors { top: true; left: true; right: true }
            implicitHeight: Metrics.dp(56)
color: "transparent"
            exclusionMode: ExclusionMode.Auto
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "bar-pill"

            MaterialSurface {
                anchors.top: parent.top
                anchors.topMargin:    barReady ? 10 : 0
                anchors.horizontalCenter: parent.horizontalCenter
                width:  pillLayout.implicitWidth + 28
                height: Metrics.dp(40)
                role: "background"
                active: true
                fillOpacity: UIState.barOpacity
                opacity: barReady ? 1 : 0
                scale:   barReady ? 1 : 0.9

                Behavior on anchors.topMargin { NumberAnimation { duration: Animations.xslow; easing.type: Easing.OutExpo } }
                Behavior on opacity { NumberAnimation { duration: Animations.slow; easing.type: Easing.OutCubic } }
                Behavior on scale   { NumberAnimation { duration: Animations.slow; easing.type: Easing.OutBack; easing.overshoot: Animations.springPower } }

                PillBarContent {
                    id: pillLayout
                    anchors.centerIn: parent
                }
            }
        }
    }

    // ── tray popup (styled menu) ─────────────────────────────────────
    TrayPopup {}

    // ── bluetooth management popup ──────────────────────────────────
    BluetoothPopup {}
}
