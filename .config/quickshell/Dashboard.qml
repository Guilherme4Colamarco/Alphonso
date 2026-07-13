import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

PanelWindow {
    id: dashboard

    property bool showing: UIState.activeDropdown === "dashboard"
    property bool _visible: false
    property real panelWidth:  screen ? Math.min(380, Math.max(320, screen.width * 0.26))  : 360
    property real panelHeight: screen ? Math.min(820, Math.max(600, screen.height * 0.82)) : 720

    visible: _visible
    anchors { top: true }
    margins { top: 62 }
    implicitWidth:  panelWidth
    implicitHeight: panelHeight
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dashboard"

    function a(c, o) { return Qt.rgba(c.r, c.g, c.b, o) }

    property real br:    UIState.borderRadius
    property real brTile: Math.round(br * 0.875)
    property real brCard: Math.round(br * 0.75)
    property real brSm:   Math.round(br * 0.625)

    property string uptime: "..."
    property var pfpList: []
    property bool pfpPicker:   false
    property bool powerMenu:   false

    property int activeTab: 0
    property var tabs: [
        { icon: "󰍜", label: L10n.tr("quick", "Quick") },
        { icon: "󰎆", label: L10n.tr("media", "Media") },
        { icon: "󰒓", label: L10n.tr("system", "System") }
    ]

    property string powerMode: "balanced"

    Component.onCompleted: {
        pfpListProc.running = true
        checkPowerModeProc.running = true
    }

    onShowingChanged: {
        if (showing) {
            _visible = true
            uptimeProc.running = true
            checkPowerModeProc.running = true
        } else {
            powerMenuResetDelay.start()
            closeDelay.start()
        }
    }

    Timer {
        id: closeDelay
        interval: Animations.exitDuration + 60
        onTriggered: {
            _visible       = false
            pfpPicker      = false
        }
    }

    Timer {
        id: powerMenuResetDelay
        interval: Animations.medium + 40
        onTriggered: powerMenu = false
    }

    Process {
        id: pfpListProc
        command: ["bash", "-c", "ls -1 ~/.config/quickshell/assets/pfps/*.{jpg,png} 2>/dev/null"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => { pfpList = data.trim().split("\n").filter(l => l.length > 0) }
        }
    }

    Process {
        id: uptimeProc
        command: ["bash", "-c", "uptime -p | sed 's/up //'"]
        stdout: SplitParser { onRead: data => uptime = data.trim() }
    }

    Process {
        id: checkPowerModeProc
        command: ["powerprofilesctl", "get"]
        stdout: SplitParser { onRead: data => powerMode = data.trim() }
    }

    Process { id: powerModeProc }

    function cyclePowerMode() {
        var modes = ["balanced", "power-saver", "performance"]
        var idx   = modes.indexOf(powerMode)
        var next  = modes[(idx + 1) % modes.length]
        powerModeProc.command = ["powerprofilesctl", "set", next]
        powerModeProc.running = true
        powerMode = next
    }

    function getPowerModeIcon() {
        if (powerMode === "power-saver") return ""
        if (powerMode === "performance") return "󱐋"
        return ""
    }

    function getPowerModeLabel() {
        if (powerMode === "power-saver") return L10n.tr("economy", "Power Saver")
        if (powerMode === "performance") return L10n.tr("performance", "Perform.")
        return L10n.tr("balanced", "Balanced")
    }

    function cycleAnimations() {
        var profiles = ["bubbly", "calm", "snappy", "extraslow", "none"]
        var idx      = profiles.indexOf(Animations.profile)
        var next     = profiles[(idx + 1) % profiles.length]
        Animations.setProfile(next)
    }

    function cycleBlur() {
        if (!UIState.transparencyEnabled) return
        var profiles = ["frosted", "balanced", "subtle", "none"]
        var idx      = profiles.indexOf(UIState.blurProfile)
        var next     = profiles[(idx + 1) % profiles.length]
        UIState.setBlurProfile(next)
    }

    function getBlurLabel() {
        if (UIState.blurProfile === "frosted")  return L10n.tr("frosted", "Strong")
        if (UIState.blurProfile === "balanced") return L10n.tr("balanced_blur", "Medium")
        if (UIState.blurProfile === "subtle")   return L10n.tr("subtle", "Subtle")
        return L10n.tr("none", "None")
    }

    function getBlurIcon() {
        if (UIState.blurProfile === "frosted")  return "󰂵"
        if (UIState.blurProfile === "balanced") return "󰂶"
        if (UIState.blurProfile === "subtle")   return "󰂷"
        return "󰂸"
    }

    function cycleBarMode() {
        var modes = ["fixed", "floating", "autohide", "pill"]
        var idx   = modes.indexOf(UIState.barMode)
        var next  = modes[(idx + 1) % modes.length]
        UIState.setBarMode(next)
    }

    function getBarModeIcon() {
        if (UIState.barMode === "pill")     return "󰑯"
        if (UIState.barMode === "floating") return "󰉈"
        if (UIState.barMode === "autohide") return "󰁐"
        return "󰑮"
    }

    function getBarModeLabel() {
        if (UIState.barMode === "pill")     return L10n.tr("pill", "Pill")
        if (UIState.barMode === "floating") return L10n.tr("floating", "Floating")
        if (UIState.barMode === "autohide") return L10n.tr("autohide", "Autohide")
        return L10n.tr("fixed", "Fixed")
    }

    function cycleBorderRadius() {
        var radii = [0, 8, 16]
        var idx   = radii.indexOf(UIState.borderRadius)
        var next  = radii[(idx + 1) % radii.length]
        UIState.setBorderRadius(next)
    }

    function getBorderRadiusIcon() {
        if (UIState.borderRadius === 0)  return "󰝤"
        if (UIState.borderRadius === 8)  return "󰄱"
        return "󰄰"
    }

    function getBorderRadiusLabel() {
        if (UIState.borderRadius === 0)  return L10n.tr("flat", "Flat")
        if (UIState.borderRadius === 8)  return L10n.tr("rounded_short", "Round.")
        return L10n.tr("rounded", "Rounded")
    }

    QtObject {
        id: dashHelpers
        function cyclePowerMode()      { dashboard.cyclePowerMode() }
        function getPowerModeIcon()    { return dashboard.getPowerModeIcon() }
        function getPowerModeLabel()   { return dashboard.getPowerModeLabel() }
        function cycleAnimations()     { dashboard.cycleAnimations() }
        function cycleBlur()           { dashboard.cycleBlur() }
        function getBlurIcon()         { return dashboard.getBlurIcon() }
        function getBlurLabel()        { return dashboard.getBlurLabel() }
        function cycleBarMode()        { dashboard.cycleBarMode() }
        function getBarModeIcon()      { return dashboard.getBarModeIcon() }
        function getBarModeLabel()     { return dashboard.getBarModeLabel() }
        function cycleBorderRadius()   { dashboard.cycleBorderRadius() }
        function getBorderRadiusIcon() { return dashboard.getBorderRadiusIcon() }
        function getBorderRadiusLabel(){ return dashboard.getBorderRadiusLabel() }
        function openPfpPicker()       { dashboard.pfpPicker = true }
    }

    Rectangle {
        id: bg
        width:   parent.width
        height:  parent.height
        y:       showing ? 0 : -panelHeight - 20
        opacity: showing ? 1 : 0
        scale:   showing ? 1 : 0.97
        transformOrigin: Item.Top
        color:  a(Colors.bg, UIState.transparencyEnabled ? 0.82 : 1)
        radius: br

        Behavior on y {
            NumberAnimation {
                duration: Animations.enterDuration
                easing.type: Animations.profile === "extraslow" ? Easing.InOutQuart : Easing.OutExpo
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Animations.medium
                easing.type: Animations.profile === "extraslow" ? Easing.InOutQuart : Easing.OutCubic
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Animations.enterDuration
                easing.type: Animations.profile === "extraslow" ? Easing.InOutQuart : Easing.OutCubic
            }
        }
        Behavior on color  { ColorAnimation  { duration: Animations.slow } }
        Behavior on radius { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }

        Item {
            anchors.fill: parent
            anchors.margins: Metrics.dp(20)
            Column {
                id: mainCol
                anchors.fill: parent
                spacing: Metrics.dp(16)
                Row {
                    id: userRow
                    width:   parent.width
                    height:  Metrics.dp(72)
spacing: Metrics.dp(18)
                    Item {
                        width:  64; height: 64
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color:  a(Colors.accent, 0.12)
                            border.width: 2.5
                            border.color: a(Colors.accent, 0.4)
                        }

                        Image {
                            id: pfpImg
                            anchors.fill: parent
                            anchors.margins: Metrics.dp(3)
source: pfpList.length > 0 ? "file://" + pfpList[UIState.pfpIndex] : ""
                            fillMode: Image.PreserveAspectCrop
                            sourceSize: Qt.size(128, 128)
                            smooth: true
                            antialiasing: true
                            visible: false
                        }

                        Rectangle {
                            id: pfpMask
                            anchors.fill: pfpImg
                            radius: width / 2
                            visible: false
                        }

                        OpacityMask {
                            anchors.fill: pfpImg
                            source: pfpImg
                            maskSource: pfpMask
                            visible: pfpList.length > 0
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "󰀄"
                            color: Colors.accent
                            font { pixelSize: Metrics.sp(30); family: "JetBrainsMono Nerd Font" }
                            visible: pfpList.length === 0
                        }

                        scale: pfpMa.containsMouse ? 1.06 : 1
                        Behavior on scale {
                            NumberAnimation { duration: Animations.medium; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                        }

                        MouseArea {
                            id: pfpMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: pfpPicker = !pfpPicker
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Metrics.dp(6)
                        Item {
                            width: userText.implicitWidth
                            height: userText.implicitHeight

                            Text {
                                id: userText
                                text: Quickshell.env("USER")
                                color: userMa.containsMouse ? Colors.accent : Colors.fg
                                font { pixelSize: Metrics.sp(22); family: "JetBrainsMono Nerd Font"; bold: true }
                                Behavior on color { ColorAnimation { duration: Animations.fast } }
                            }

                            Rectangle {
                                anchors {
                                    bottom: parent.bottom
                                    bottomMargin: -2
                                    horizontalCenter: parent.horizontalCenter
                                }
                                width: userMa.containsMouse ? parent.width + 4 : 0
                                height: Metrics.dp(2)
radius: Metrics.dp(1)
color: Colors.accent
                                Behavior on width {
                                    NumberAnimation { duration: Animations.medium; easing.type: Easing.OutBack; easing.overshoot: Animations.springPower }
                                }
                            }

                            MouseArea {
                                id: userMa
                                anchors.fill: parent
                                anchors.margins: Metrics.dp(-4)
hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: powerMenu = !powerMenu
                            }
                        }

                        Text {
                            text: uptime
                            color: a(Colors.fg, 0.4)
                            font { pixelSize: Metrics.sp(12); family: "JetBrainsMono Nerd Font" }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: powerMenu ? powerRow.implicitHeight + 8 : 0
                    clip: true

                    Behavior on height {
                        NumberAnimation { duration: Animations.medium; easing.type: Easing.OutExpo }
                    }

                    Row {
                        id: powerRow
                        anchors.top: parent.top
                        anchors.topMargin: Metrics.dp(4)
anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Metrics.dp(10)
                        Repeater {
                            model: [
                                { icon: "⏻",  label: L10n.tr("poweroff", "Power Off"), cmd: "systemctl poweroff" },
                                { icon: "󰜉", label: L10n.tr("reboot", "Reboot"),   cmd: "systemctl reboot" },
                                { icon: "󰌾", label: L10n.tr("lock", "Lock"),     cmd: "echo 1 > ~/.cache/qs/lock" },
                                { icon: "󰒲", label: L10n.tr("suspend", "Suspend"),    cmd: "systemctl suspend" },
                                { icon: "󰍃", label: L10n.tr("logout", "Log Out"),   cmd: "loginctl terminate-user " + Quickshell.env("USER") }
                            ]

                            Item {
                                required property int index
                                required property var modelData
                                width:  Metrics.dp(58)
height: Metrics.dp(52)
                                Rectangle {
                                    anchors.fill: parent
                                    radius: brCard
                                    color: pwrMa.containsMouse ? a(Colors.fg, 0.12) : a(Colors.fg, 0.05)
                                    border.width: pwrMa.containsMouse ? 1 : 0
                                    border.color: a(Colors.fg, 0.1)
                                    Behavior on color  { ColorAnimation { duration: Animations.fast } }
                                    Behavior on border.width { NumberAnimation { duration: Animations.fast } }
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: Metrics.dp(5)
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text:  modelData.icon
                                        color: pwrMa.containsMouse ? Colors.fg : a(Colors.fg, 0.5)
                                        font { pixelSize: Metrics.sp(18); family: "JetBrainsMono Nerd Font" }
                                        Behavior on color { ColorAnimation { duration: Animations.fast } }
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text:  modelData.label
                                        color: pwrMa.containsMouse ? a(Colors.fg, 0.7) : a(Colors.fg, 0.3)
                                        font { pixelSize: Metrics.sp(8); family: "JetBrainsMono Nerd Font" }
                                        Behavior on color { ColorAnimation { duration: Animations.fast } }
                                    }
                                }

                                Process { id: pwrExec }
                                MouseArea {
                                    id: pwrMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { pwrExec.command = ["bash", "-c", modelData.cmd]; pwrExec.running = true }
                                }
                            }
                        }
                    }
                }

                // ── Tab bar ─────────────────────────────────────────────────────
                TileButton {
                    id: settingsButton
                    width: parent.width
                    icon: "󰒓"
                    label: L10n.tr("settings", "Settings")
                    sublabel: L10n.tr("settings_open", "Open the configuration window")
                    active: UIState.settingsVisible
                    onClicked: UIState.openSettings()
                }

                Rectangle {
                    id: tabBarContainer
                    width: parent.width
                    height: Metrics.dp(42)
radius: brCard
                    color: a(Colors.surface, 0.4)
                    border.width: 1
                    border.color: a(Colors.fg, 0.06)

                    Row {
                        id: tabBar
                        anchors.fill: parent
                        anchors.margins: Metrics.dp(4)
spacing: Metrics.dp(4)
                        Repeater {
                            model: tabs

                            Item {
                                required property int index
                                required property var modelData
                                width:  (tabBar.width - tabBar.spacing * (tabs.length - 1)) / tabs.length
                                height: tabBar.height

                                Rectangle {
                                    anchors.fill: parent
                                    radius: brSm
                                    color: activeTab === index
                                        ? a(Colors.accent, 0.18)
                                        : tabMa.containsMouse
                                            ? a(Colors.fg, 0.08)
                                            : "transparent"
                                    border.width: activeTab === index ? 1.5 : 0
                                    border.color: a(Colors.accent, 0.35)

                                    Behavior on color  { ColorAnimation { duration: Animations.fast } }
                                    Behavior on border.width { NumberAnimation { duration: Animations.fast } }
                                }

                                // Indicador de tab ativa (barra inferior)
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: parent.width * 0.6
                                    height: Metrics.dp(2.5)
radius: Metrics.dp(1)
color: Colors.accent
                                    visible: activeTab === index
                                    opacity: activeTab === index ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: Metrics.dp(3)
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text:  modelData.icon
                                        color: activeTab === index ? Colors.accent : (tabMa.containsMouse ? a(Colors.fg, 0.6) : a(Colors.fg, 0.4))
                                        font { pixelSize: Metrics.sp(14); family: "JetBrainsMono Nerd Font" }
                                        Behavior on color { ColorAnimation { duration: Animations.fast } }
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text:  modelData.label
                                        color: activeTab === index ? Colors.accent : (tabMa.containsMouse ? a(Colors.fg, 0.7) : a(Colors.fg, 0.35))
                                        font { pixelSize: Metrics.sp(8); family: "JetBrainsMono Nerd Font"; bold: activeTab === index }
                                        Behavior on color { ColorAnimation { duration: Animations.fast } }
                                    }
                                }

                                MouseArea {
                                    id: tabMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: activeTab = index
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: separator
                    width: parent.width * 0.9
                    height: Metrics.dp(1)
anchors.horizontalCenter: parent.horizontalCenter
                    color: a(Colors.fg, 0.08)
                }

                // ── Tab content ──────────────────────────────────────────────────
                StackLayout {
                    id: tabStack
                    currentIndex: activeTab
                    width: parent.width
                    height: parent.height - settingsButton.height - tabBarContainer.height - separator.height - userRow.height - mainCol.spacing * 4

                    QuickTab { helpers: dashHelpers }
                    MediaTab { helpers: dashHelpers }
                    SystemTab { helpers: dashHelpers; uptime: dashboard.uptime }
                }
            }
        }

        Rectangle {
            id: pfpPickerOverlay
            anchors.fill: parent
            color:   a(Colors.bg, UIState.transparencyEnabled ? 0.95 : 1)
            radius:  br
            opacity: pfpPicker ? 1 : 0
            scale:   pfpPicker ? 1 : 0.97
            visible: opacity > 0
            transformOrigin: Item.Center

            Behavior on opacity { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }
            Behavior on scale   { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
            Behavior on color   { ColorAnimation  { duration: Animations.slow } }
            Behavior on radius  { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }

            Column {
                anchors.fill: parent
                anchors.margins: Metrics.dp(20)
spacing: Metrics.dp(18)
                Item {
                    width: parent.width; height: 32

                    Text {
                        text:  "Escolher Avatar"
                        color: Colors.fg
                        font { pixelSize: Metrics.sp(18); family: "JetBrainsMono Nerd Font"; bold: true }
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    }

                    Rectangle {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        width: 28; height: 28
                        radius: brSm
                        color: pfpCloseMa.containsMouse ? a(Colors.fg, 0.1) : "transparent"
                        border.width: 1
                        border.color: pfpCloseMa.containsMouse ? a(Colors.fg, 0.2) : a(Colors.fg, 0.1)
                        Behavior on color { ColorAnimation { duration: Animations.fast } }
                        Behavior on border.color { ColorAnimation { duration: Animations.fast } }

                        Text {
                            anchors.centerIn: parent
                            text:  "󰅖"
                            color: pfpCloseMa.containsMouse ? Colors.fg : a(Colors.fg, 0.5)
                            font { pixelSize: Metrics.sp(14); family: "JetBrainsMono Nerd Font" }
                            Behavior on color { ColorAnimation { duration: Animations.fast } }
                        }

                        MouseArea {
                            id: pfpCloseMa
                            anchors.fill: parent; anchors.margins: -4
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: pfpPicker = false
                        }
                    }
                }

                Flickable {
                    width:         parent.width
                    height:        parent.height - 50
                    contentHeight: pfpGrid.height
                    clip:          true
                    boundsBehavior: Flickable.StopAtBounds

                    Grid {
                        id: pfpGrid
                        width:   parent.width
                        columns: 4
                        spacing: Metrics.dp(14)
                        Repeater {
                            model: pfpList

                            Item {
                                required property int index
                                required property string modelData
                                width:  (pfpGrid.width - 42) / 4
                                height: width

                                scale: pfpItemMa.containsMouse ? 1.08 : 1
                                Behavior on scale {
                                    NumberAnimation { duration: Animations.medium; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: Metrics.dp(2)
radius: width / 2
                                    color: UIState.pfpIndex === index ? a(Colors.accent, 0.25) : pfpItemMa.containsMouse ? a(Colors.fg, 0.12) : a(Colors.surface, 0.8)
                                    border.width: UIState.pfpIndex === index ? 3 : 0
                                    border.color: Colors.accent

                                    Behavior on color        { ColorAnimation { duration: Animations.fast } }
                                    Behavior on border.width { NumberAnimation { duration: Animations.fast } }
                                }

                                Image {
                                    id: pfpItemImg
                                    anchors.fill: parent
                                    anchors.margins: Metrics.dp(5)
source: "file://" + modelData
                                    fillMode: Image.PreserveAspectCrop
                                    sourceSize: Qt.size(96, 96)
                                    smooth: true
                                    antialiasing: true
                                    visible: false
                                }

                                Rectangle {
                                    id: pfpItemMask
                                    anchors.fill: pfpItemImg
                                    radius: width / 2
                                    visible: false
                                }

                                OpacityMask {
                                    anchors.fill: pfpItemImg
                                    source: pfpItemImg
                                    maskSource: pfpItemMask
                                }

                                MouseArea {
                                    id: pfpItemMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { UIState.setPfpIndex(index); pfpPicker = false }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
