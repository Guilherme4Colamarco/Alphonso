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
    anchors { top: true; right: true }
    margins { top: 44; right: 12 }
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
        { icon: "󰍹", label: L10n.tr("display", "Display") },
        { icon: "󰎆", label: L10n.tr("media", "Media") },
        { icon: "󰒓", label: L10n.tr("system", "System") },
        { icon: "󰏘", label: L10n.tr("appearance", "Look") },
        { icon: "󰒈", label: L10n.tr("mango", "Mango") }
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
        x:       showing ? 0 : panelWidth + 20
        opacity: showing ? 1 : 0
        scale:   showing ? 1 : 0.97
        transformOrigin: Item.TopRight
        color:  a(Colors.bg, UIState.transparencyEnabled ? 0.82 : 1)
        radius: br

        Behavior on x {
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
            anchors.margins: 20

            Column {
                id: mainCol
                anchors.fill: parent
                spacing: 14

                Row {
                    id: userRow
                    width:   parent.width
                    height:  68
                    spacing: 16

                    Item {
                        width:  62; height: 62
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color:  a(Colors.accent, 0.1)
                            border.width: 2.5
                            border.color: a(Colors.accent, 0.35)
                        }

                        Image {
                            id: pfpImg
                            anchors.fill: parent
                            anchors.margins: 3
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
                            font { pixelSize: 28; family: "JetBrainsMono Nerd Font" }
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
                        spacing: 4

                        Item {
                            width: userText.implicitWidth
                            height: userText.implicitHeight

                            Text {
                                id: userText
                                text: Quickshell.env("USER")
                                color: userMa.containsMouse ? Colors.accent : Colors.fg
                                font { pixelSize: 20; family: "JetBrainsMono Nerd Font"; bold: true }
                                Behavior on color { ColorAnimation { duration: Animations.fast } }
                            }

                            Rectangle {
                                anchors {
                                    bottom: parent.bottom
                                    bottomMargin: -2
                                    horizontalCenter: parent.horizontalCenter
                                }
                                width: userMa.containsMouse ? parent.width + 4 : 0
                                height: 2
                                radius: 1
                                color: Colors.accent
                                Behavior on width {
                                    NumberAnimation { duration: Animations.medium; easing.type: Easing.OutBack; easing.overshoot: Animations.springPower }
                                }
                            }

                            MouseArea {
                                id: userMa
                                anchors.fill: parent
                                anchors.margins: -4
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: powerMenu = !powerMenu
                            }
                        }

                        Text {
                            text: uptime
                            color: a(Colors.fg, 0.35)
                            font { pixelSize: 11; family: "JetBrainsMono Nerd Font" }
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
                        anchors.topMargin: 4
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8

                        Repeater {
                            model: [
                                { icon: "⏻",  label: L10n.tr("poweroff", "Power Off"), cmd: "systemctl poweroff" },
                                { icon: "󰜉", label: L10n.tr("reboot", "Reboot"),   cmd: "systemctl reboot" },
                                { icon: "󰌾", label: L10n.tr("lock", "Lock"),     cmd: "echo 1 > ~/.cache/qs/lock" },
                                { icon: "󰒲", label: L10n.tr("suspend", "Suspend"),    cmd: "systemctl suspend" },
                                { icon: "󰍃", label: L10n.tr("logout", "Log Out"),   cmd: "loginctl terminate-user " + Quickshell.env("USER") }
                            ]

                            Item {
                                width:  52
                                height: 46

                                Rectangle {
                                    anchors.fill: parent
                                    radius: brCard
                                    color: pwrMa.containsMouse ? a(Colors.fg, 0.10) : a(Colors.fg, 0.04)
                                    Behavior on color  { ColorAnimation { duration: Animations.fast } }
                                    Behavior on radius { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text:  modelData.icon
                                        color: pwrMa.containsMouse ? Colors.fg : a(Colors.fg, 0.45)
                                        font { pixelSize: 16; family: "JetBrainsMono Nerd Font" }
                                        Behavior on color { ColorAnimation { duration: Animations.fast } }
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text:  modelData.label
                                        color: pwrMa.containsMouse ? a(Colors.fg, 0.65) : a(Colors.fg, 0.25)
                                        font { pixelSize: 7; family: "JetBrainsMono Nerd Font" }
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
                Row {
                    id: tabBar
                    width: parent.width
                    height: 32
                    spacing: 6

                    Repeater {
                        model: tabs

                        Item {
                            required property int index
                            required property var modelData
                            width:  (tabBar.width - 30) / 6
                            height: 32

                            Rectangle {
                                anchors.fill: parent
                                radius: brSm
                                color: activeTab === index
                                    ? a(Colors.accent, 0.15)
                                    : tabMa.containsMouse
                                        ? a(Colors.fg, 0.07)
                                        : a(Colors.fg, 0.03)
                                border.width: activeTab === index ? 1 : 0
                                border.color: a(Colors.accent, 0.25)

                                Behavior on color  { ColorAnimation { duration: Animations.fast } }
                                Behavior on radius { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 2

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text:  modelData.icon
                                    color: activeTab === index ? Colors.accent : a(Colors.fg, 0.35)
                                    font { pixelSize: 12; family: "JetBrainsMono Nerd Font" }
                                    Behavior on color { ColorAnimation { duration: Animations.fast } }
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text:  modelData.label
                                    color: activeTab === index ? Colors.accent : a(Colors.fg, 0.25)
                                    font { pixelSize: 7; family: "JetBrainsMono Nerd Font" }
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

                Rectangle {
                    id: separator
                    width: parent.width; height: 1; color: a(Colors.fg, 0.06)
                }

                // ── Tab content ──────────────────────────────────────────────────
                StackLayout {
                    id: tabStack
                    currentIndex: activeTab
                    width: parent.width
                    height: parent.height - tabBar.height - separator.height - userRow.height - mainCol.spacing * 3

                    QuickTab { helpers: dashHelpers }
                    DisplayTab { helpers: dashHelpers }
                    MediaTab { helpers: dashHelpers }
                    SystemTab { helpers: dashHelpers; uptime: dashboard.uptime }
                    LookTab { helpers: dashHelpers }
                    MangoTab {}
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
                anchors.margins: 20
                spacing: 16

                Item {
                    width: parent.width; height: 28

                    Text {
                        text:  "Escolher Avatar"
                        color: Colors.fg
                        font { pixelSize: 16; family: "JetBrainsMono Nerd Font"; bold: true }
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    }

                    Text {
                        text:  "󰅖"
                        color: pfpCloseMa.containsMouse ? Colors.fg : a(Colors.fg, 0.4)
                        font { pixelSize: 16; family: "JetBrainsMono Nerd Font" }
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        Behavior on color { ColorAnimation { duration: Animations.fast } }

                        MouseArea {
                            id: pfpCloseMa
                            anchors.fill: parent; anchors.margins: -6
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: pfpPicker = false
                        }
                    }
                }

                Flickable {
                    width:         parent.width
                    height:        parent.height - 44
                    contentHeight: pfpGrid.height
                    clip:          true
                    boundsBehavior: Flickable.StopAtBounds

                    Grid {
                        id: pfpGrid
                        width:   parent.width
                        columns: 4
                        spacing: 12

                        Repeater {
                            model: pfpList

                            Item {
                                required property int index
                                required property string modelData
                                width:  (pfpGrid.width - 36) / 4
                                height: width

                                scale: pfpItemMa.containsMouse ? 1.06 : 1
                                Behavior on scale {
                                    NumberAnimation { duration: Animations.medium; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    radius: width / 2
                                    color: UIState.pfpIndex === index ? a(Colors.accent, 0.2) : pfpItemMa.containsMouse ? a(Colors.fg, 0.1) : a(Colors.surface, 0.8)
                                    border.width: UIState.pfpIndex === index ? 2.5 : 0
                                    border.color: Colors.accent

                                    Behavior on color        { ColorAnimation { duration: Animations.fast } }
                                    Behavior on border.width { NumberAnimation { duration: Animations.fast } }
                                }

                                Image {
                                    id: pfpItemImg
                                    anchors.fill: parent
                                    anchors.margins: 5
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
