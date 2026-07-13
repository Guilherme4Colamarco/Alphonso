import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

FloatingWindow {
    id: root

    title: "Kamalen Settings"
    visible: UIState.settingsVisible
    implicitWidth: Math.min(screen ? screen.width * 0.86 : Metrics.dp(1100), Metrics.dp(1100))
    implicitHeight: Math.min(screen ? screen.height * 0.86 : Metrics.dp(760), Metrics.dp(760))
    minimumSize: Qt.size(Metrics.dp(680), Metrics.dp(500))
    maximumSize: Qt.size(4096, 2160)
    color: "transparent"

    property int activeSection: 0
    property bool pfpPicker: false
    property var pfpList: []
    property bool compactNavigation: width < Metrics.dp(850)
    property var sections: [
        { icon: "󰏘", label: L10n.tr("appearance", "Appearance") },
        { icon: "󰍹", label: L10n.tr("monitors", "Monitors") },
        { icon: "󰒈", label: L10n.tr("mango", "Mango") },
        { icon: "󰌌", label: L10n.tr("binds", "Binds") },
        { icon: "󰁍", label: L10n.tr("rules", "Rules") }
    ]

    onVisibleChanged: {
        if (!visible && UIState.settingsVisible) UIState.closeSettings()
        if (visible) pfpListProc.running = true
    }

    function cycleBlur() {
        if (!UIState.transparencyEnabled) return
        var values = ["frosted", "balanced", "subtle", "none"]
        UIState.setBlurProfile(values[(values.indexOf(UIState.blurProfile) + 1) % values.length])
    }
    function getBlurIcon() {
        return UIState.blurProfile === "frosted" ? "󰂵" : UIState.blurProfile === "balanced" ? "󰂶" : UIState.blurProfile === "subtle" ? "󰂷" : "󰂸"
    }
    function getBlurLabel() {
        return UIState.blurProfile === "frosted" ? L10n.tr("frosted", "Strong") : UIState.blurProfile === "balanced" ? L10n.tr("balanced_blur", "Medium") : UIState.blurProfile === "subtle" ? L10n.tr("subtle", "Subtle") : L10n.tr("none", "None")
    }
    function cycleBorderRadius() {
        var values = [0, 8, 16]
        UIState.setBorderRadius(values[(values.indexOf(UIState.borderRadius) + 1) % values.length])
    }
    function getBorderRadiusIcon() { return UIState.borderRadius === 0 ? "󰝤" : UIState.borderRadius === 8 ? "󰄱" : "󰄰" }
    function getBorderRadiusLabel() { return UIState.borderRadius === 0 ? L10n.tr("flat", "Flat") : UIState.borderRadius === 8 ? L10n.tr("rounded_short", "Round.") : L10n.tr("rounded", "Rounded") }

    QtObject {
        id: settingsHelpers
        function cycleBlur() { root.cycleBlur() }
        function getBlurIcon() { return root.getBlurIcon() }
        function getBlurLabel() { return root.getBlurLabel() }
        function cycleBorderRadius() { root.cycleBorderRadius() }
        function getBorderRadiusIcon() { return root.getBorderRadiusIcon() }
        function getBorderRadiusLabel() { return root.getBorderRadiusLabel() }
        function openPfpPicker() { root.pfpPicker = true }
    }

    Process {
        id: pfpListProc
        command: ["bash", "-c", "ls -1 ~/.config/quickshell/assets/pfps/*.{jpg,png} 2>/dev/null"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => root.pfpList = data.trim().split("\n").filter(path => path.length > 0)
        }
    }

    Rectangle {
        anchors.fill: parent
        focus: UIState.vimNavigationEnabled
        color: Colors.a(Colors.bg, UIState.transparencyEnabled ? 0.96 : 1)
        radius: Aesthetics.radius(Aesthetics.containerRadius, height)
        border.width: Math.max(1, Aesthetics.borderWidth)
        border.color: Colors.a(Colors.fg, 0.1)

        Keys.onPressed: event => {
            var shiftedLast = event.text === "G" && event.modifiers === Qt.ShiftModifier
            if (!UIState.vimNavigationEnabled || (event.modifiers !== Qt.NoModifier && !shiftedLast)) return
            if (event.text === "j" || event.text === "l") {
                root.activeSection = Math.min(root.sections.length - 1, root.activeSection + 1)
                event.accepted = true
            } else if (event.text === "k" || event.text === "h") {
                root.activeSection = Math.max(0, root.activeSection - 1)
                event.accepted = true
            } else if (event.text === "g") {
                root.activeSection = 0
                event.accepted = true
            } else if (event.text === "G") {
                root.activeSection = root.sections.length - 1
                event.accepted = true
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: Metrics.dp(16)
            spacing: Metrics.dp(16)

            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: root.compactNavigation ? Metrics.dp(72) : Metrics.dp(230)
                radius: Aesthetics.radius(Aesthetics.cardRadius, height)
                color: Colors.a(Colors.surface, 0.55)

                Column {
                    anchors.fill: parent
                    anchors.margins: Metrics.dp(12)
                    spacing: Metrics.dp(8)

                    Text {
                        text: "Kamalen Settings"
                        color: Colors.fg
                        visible: !root.compactNavigation
                        font { pixelSize: Metrics.sp(17); family: "JetBrainsMono Nerd Font"; bold: true }
                        bottomPadding: Metrics.dp(12)
                    }

                    Repeater {
                        model: root.sections
                        Rectangle {
                            required property int index
                            required property var modelData
                            width: parent.width
                            height: Metrics.dp(52)
                            radius: Aesthetics.radius(Aesthetics.controlRadius, height)
                            color: root.activeSection === index ? Colors.a(Colors.accent, 0.18) : navMouse.containsMouse ? Colors.a(Colors.fg, 0.07) : "transparent"

                            Row {
                                anchors.centerIn: root.compactNavigation ? parent : undefined
                                anchors { left: root.compactNavigation ? undefined : parent.left; leftMargin: Metrics.dp(12); verticalCenter: parent.verticalCenter }
                                spacing: Metrics.dp(10)
                                Text { text: modelData.icon; color: root.activeSection === index ? Colors.accent : Colors.a(Colors.fg, 0.55); font { pixelSize: Metrics.sp(18); family: "JetBrainsMono Nerd Font" } }
                                Text { visible: !root.compactNavigation; text: modelData.label; color: root.activeSection === index ? Colors.accent : Colors.fg; font { pixelSize: Metrics.sp(12); family: "JetBrainsMono Nerd Font"; bold: root.activeSection === index } }
                            }
                            MouseArea { id: navMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.activeSection = index }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Aesthetics.radius(Aesthetics.cardRadius, height)
                color: Colors.a(Colors.surface, 0.32)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Metrics.dp(22)
                    spacing: Metrics.dp(14)

                    Text {
                        text: root.sections[root.activeSection].label
                        color: Colors.fg
                        font { pixelSize: Metrics.sp(22); family: "JetBrainsMono Nerd Font"; bold: true }
                    }

                    StackLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        currentIndex: root.activeSection
                        LookTab { helpers: settingsHelpers }
                        MonitorsTab { helpers: settingsHelpers }
                        MangoTab {}
                        BindsTab { helpers: settingsHelpers }
                        WindowRulesTab { helpers: settingsHelpers }
                    }
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: root.pfpPicker
            color: Colors.a(Colors.bg, 0.97)
            radius: Aesthetics.radius(Aesthetics.containerRadius, height)
            z: 10

            Column {
                anchors.fill: parent
                anchors.margins: Metrics.dp(28)
spacing: Metrics.dp(18)
Row {
                    width: parent.width
                    Text { text: L10n.tr("choose_avatar", "Choose profile picture"); color: Colors.fg; font { pixelSize: Metrics.sp(18); family: "JetBrainsMono Nerd Font"; bold: true } }
                    Item { width: parent.width - 260; height: 1 }
                    Text {
                        text: "󰅖"
                        color: Colors.fg
                        font { pixelSize: Metrics.sp(18); family: "JetBrainsMono Nerd Font" }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: Metrics.dp(-8)
cursorShape: Qt.PointingHandCursor
                            onClicked: root.pfpPicker = false
                        }
                    }
                }
                GridView {
                    width: parent.width
                    height: parent.height - 50
                    cellWidth: 130
                    cellHeight: 130
                    model: root.pfpList
                    clip: true
                    delegate: Item {
                        required property int index
                        required property string modelData
                        width: 120; height: 120
                        Image { id: avatar; anchors.fill: parent; anchors.margins: 8; source: "file://" + modelData; fillMode: Image.PreserveAspectCrop; visible: false }
                        Rectangle { id: avatarMask; anchors.fill: avatar; radius: width / 2; visible: false }
                        OpacityMask { anchors.fill: avatar; source: avatar; maskSource: avatarMask }
                        Rectangle { anchors.fill: avatar; radius: width / 2; color: "transparent"; border.width: UIState.pfpIndex === index ? 3 : 1; border.color: UIState.pfpIndex === index ? Colors.accent : Colors.a(Colors.fg, 0.15) }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { UIState.setPfpIndex(index); root.pfpPicker = false } }
                    }
                }
            }
        }
    }
}
