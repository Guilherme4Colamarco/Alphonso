import Quickshell
import Quickshell.Io
import QtQuick
import Qt5Compat.GraphicalEffects
import ".."

Item {
    property var helpers
    property bool qsExpanded: false
    property bool wifiOn: true
    property bool btOn: false
    property bool nightLightOn: false
    property var expandedGroups: ({})

    property var quickSettings: [
        { icon: "󰤨", iconOff: "󰤭", label: "Wi-Fi",   active: () => wifiOn,                        toggle: toggleWifi },
        { icon: "󰂯", iconOff: "󰂲", label: "BT",      active: () => btOn,                          toggle: toggleBt },
        { icon: "󰍶", iconOff: "󰍷", label: "DND",     active: () => UIState.dndEnabled,            toggle: UIState.toggleDnd },
        { icon: "󰽥", iconOff: "", label: L10n.tr("nightlight", "Night"), active: () => nightLightOn,                  toggle: toggleNightLight },
        { icon: "󰖔", iconOff: "󰖕", label: L10n.tr("darkmode", "Dark"),   active: () => UIState.darkMode,              toggle: UIState.toggleDarkMode },
        { icon: "󱡔", iconOff: "󱡔", label: L10n.tr("opaque", "Opaque"),    active: () => UIState.transparencyEnabled,   toggle: UIState.toggleTransparency },
        { icon: "",  iconOff: "",  label: "",         active: () => Animations.profile !== "none", toggle: function() { if (helpers) helpers.cycleAnimations() } },
        { icon: "",  iconOff: "",  label: "",         active: () => UIState.transparencyEnabled && UIState.blurProfile !== "none", toggle: function() { if (helpers) helpers.cycleBlur() } },
        { icon: "",  iconOff: "",  label: "",         active: () => true,                          toggle: function() { if (helpers) helpers.cyclePowerMode() } },
        { icon: "",  iconOff: "",  label: "",         active: () => true,   toggle: function() { if (helpers) helpers.cycleBarMode() } },
        { icon: "",  iconOff: "",  label: "",         active: () => UIState.borderRadius > 0,      toggle: function() { if (helpers) helpers.cycleBorderRadius() } }
    ]

    function isGroupExpanded(app) { return expandedGroups[app] === true }

    function toggleGroup(app) {
        var copy  = Object.assign({}, expandedGroups)
        copy[app] = !copy[app]
        expandedGroups = copy
    }

    function toggleWifi() {
        wifiOn = !wifiOn
        wifiToggleProc.command = ["nmcli", "radio", "wifi", wifiOn ? "on" : "off"]
        wifiToggleProc.running = true
    }

    function toggleBt() {
        btOn = !btOn
        btToggleProc.command = ["bluetoothctl", "power", btOn ? "on" : "off"]
        btToggleProc.running = true
    }

    function toggleNightLight() {
        if (nightLightOn) {
            nightLightProc.command = ["bash", "-c", "pid=$(cat /tmp/qs-nightlight.pid 2>/dev/null); kill $pid 2>/dev/null; rm -f /tmp/qs-nightlight.pid"]
            nightLightProc.running = true
            nightLightOn = false
        } else {
            nightLightProc.command = ["bash", "-c", "gammastep -O 4500 & echo $! > /tmp/qs-nightlight.pid"]
            nightLightProc.running = true
            nightLightOn = true
        }
    }

    function rebuildGrouped() {
        var groups = {}
        var order  = []
        var notifs = UIState.notifications
        for (var i = 0; i < notifs.length; i++) {
            var n   = notifs[i]
            var app = n.app || "Unknown"
            if (!groups[app]) { groups[app] = []; order.push(app) }
            groups[app].push(n)
        }

        var newApps = {}
        for (var j = 0; j < order.length; j++)
            newApps[order[j]] = groups[order[j]]

        for (var k = groupedModel.count - 1; k >= 0; k--) {
            if (!newApps[groupedModel.get(k).app])
                groupedModel.remove(k)
        }

        for (var l = 0; l < order.length; l++) {
            var app2  = order[l]
            var found = false
            for (var m = 0; m < groupedModel.count; m++) {
                if (groupedModel.get(m).app === app2) {
                    var oldCount = JSON.parse(groupedModel.get(m).items).length
                    var newCount = groups[app2].length
                    var oldBump  = groupedModel.get(m).bump
                    groupedModel.set(m, {
                        app:   app2,
                        items: JSON.stringify(groups[app2]),
                        bump:  newCount > oldCount ? oldBump + 1 : oldBump
                    })
                    found = true
                    break
                }
            }
            if (!found)
                groupedModel.insert(l, { app: app2, items: JSON.stringify(groups[app2]), bump: 0 })
        }
    }

    onVisibleChanged: {
        if (visible) {
            stateProc.running = true
            checkNightLightProc.running = true
        } else {
            qsExpanded = false
            expandedGroups = ({})
        }
    }

    Component.onCompleted: {
        rebuildGrouped()
        checkNightLightProc.running = true
    }

    Connections {
        target: UIState
        function onNotificationsChanged() { rebuildGrouped() }
    }

    Process { id: wifiToggleProc }
    Process { id: btToggleProc }
    Process { id: nightLightProc }

    Process {
        id: stateProc
        command: ["bash", "-c", [
            "w=$(nmcli radio wifi 2>/dev/null)",
            "b=$(bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo on || echo off)",
            "echo \"$w|$b\""
        ].join("; ")]
        stdout: SplitParser {
            onRead: data => {
                var p = data.trim().split("|")
                wifiOn = p[0] === "enabled"
                btOn   = p[1] === "on"
            }
        }
    }

    Process {
        id: checkNightLightProc
        command: ["bash", "-c", "[ -f /tmp/qs-nightlight.pid ] && kill -0 $(cat /tmp/qs-nightlight.pid) 2>/dev/null && echo 1 || echo 0"]
        stdout: SplitParser { onRead: data => nightLightOn = data.trim() === "1" }
    }

    ListModel { id: groupedModel }

    Column {
        anchors.fill: parent
        spacing: 8

        Item {
            width:  parent.width
            height: qsExpanded ? Math.ceil(quickSettings.length / 4) * 66 : 58
            clip:   true

            Behavior on height {
                NumberAnimation { duration: Animations.medium; easing.type: Easing.OutExpo }
            }

            Grid {
                id: qsGrid
                width:   parent.width
                columns: 4
                spacing: 8

                Repeater {
                    model: quickSettings

                    Rectangle {
                        property int row: Math.floor(index / 4)
                        property bool shouldShow:    row === 0 || qsExpanded
                        property bool isDarkTile:    index === 4
                        property bool isAnimTile:    index === 6
                        property bool isBlurTile:    index === 7
                        property bool isPowerTile:   index === 8
                        property bool isBarModeTile: index === 9
                        property bool isBorderTile:  index === 10
                        property bool isOn:          modelData.active()

                        width:  (qsGrid.width - 24) / 4
                        height: 58
                        radius: UIState.borderRadius * 0.875
                        color:  isOn ? Colors.a(Colors.accent, 0.15) : qsMa.containsMouse ? Colors.a(Colors.fg, 0.07) : Colors.a(Colors.surface, 0.8)
                        border.width: isOn ? 1 : 0
                        border.color: Colors.a(Colors.accent, 0.25)
                        opacity:      shouldShow ? 1 : 0
                        scale:        shouldShow ? (qsMa.pressed ? 0.92 : 1) : 0.82
                        transformOrigin: Item.Top

                        Behavior on color   { ColorAnimation  { duration: Animations.fast } }
                        Behavior on opacity { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }
                        Behavior on scale   { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutBack; easing.overshoot: Animations.springPower } }
                        Behavior on radius  { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: {
                                    if (isAnimTile)    return Animations.getIcon()
                                    if (isBlurTile)    return helpers ? helpers.getBlurIcon() : ""
                                    if (isPowerTile)   return helpers ? helpers.getPowerModeIcon() : ""
                                    if (isBarModeTile) return helpers ? helpers.getBarModeIcon() : ""
                                    if (isBorderTile)  return helpers ? helpers.getBorderRadiusIcon() : ""
                                    return isOn ? modelData.icon : modelData.iconOff
                                }
                                color: isOn ? Colors.accent : Colors.a(Colors.fg, 0.35)
                                font { pixelSize: 18; family: "JetBrainsMono Nerd Font" }
                                Behavior on color { ColorAnimation { duration: Animations.fast } }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: {
                                    if (isAnimTile)    return Animations.getLabel()
                                    if (isBlurTile)    return helpers ? helpers.getBlurLabel() : ""
                                    if (isPowerTile)   return helpers ? helpers.getPowerModeLabel() : ""
                                    if (isBarModeTile) return helpers ? helpers.getBarModeLabel() : ""
                                    if (isBorderTile)  return helpers ? helpers.getBorderRadiusLabel() : ""
                                    return modelData.label
                                }
                                color: isOn ? Colors.accent : Colors.a(Colors.fg, 0.25)
                                font { pixelSize: 8; family: "JetBrainsMono Nerd Font" }
                                Behavior on color { ColorAnimation { duration: Animations.fast } }
                            }
                        }

                        Rectangle {
                            visible: isDarkTile && UIState.darkModeLocked
                            anchors { top: parent.top; right: parent.right; topMargin: 4; rightMargin: 4 }
                            width: 16; height: 16; radius: 8
                            color: Colors.a(Colors.accent, 0.25)

                            Text {
                                anchors.centerIn: parent
                                text: "󰌾"
                                color: Colors.accent
                                font { pixelSize: 8; family: "JetBrainsMono Nerd Font" }
                            }
                        }

                        MouseArea {
                            id: qsMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: function(mouse) {
                                if (mouse.button === Qt.RightButton && isDarkTile)
                                    UIState.toggleDarkModeLock()
                                else
                                    modelData.toggle()
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            width:  36; height: 16; radius: UIState.borderRadius * 0.625
            anchors.horizontalCenter: parent.horizontalCenter
            color:    expandMa.containsMouse ? Colors.a(Colors.fg, 0.08) : Colors.a(Colors.fg, 0.04)
            rotation: qsExpanded ? 180 : 0

            Behavior on rotation { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
            Behavior on color    { ColorAnimation  { duration: Animations.fast } }
            Behavior on radius   { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }

            Text {
                anchors.centerIn: parent
                text:  "󰅀"
                color: Colors.a(Colors.fg, 0.35)
                font { pixelSize: 11; family: "JetBrainsMono Nerd Font" }
            }

            MouseArea {
                id: expandMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: qsExpanded = !qsExpanded
            }
        }

        Item {
            width: parent.width
            height: 18

            Text {
                text:  L10n.tr("notifications", "Notifications")
                color: Colors.a(Colors.fg, 0.45)
                font { pixelSize: 12; family: "JetBrainsMono Nerd Font"; bold: true }
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            }

            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 8

                Text {
                    text:  UIState.notifications.length > 0 ? UIState.notifications.length : ""
                    color: Colors.a(Colors.fg, 0.3)
                    font { pixelSize: 10; family: "JetBrainsMono Nerd Font" }
                }

                Text {
                    text:  UIState.notifications.length > 0 ? L10n.tr("clear_all", "Clear all") : ""
                    color: clearMa.containsMouse ? Colors.accent : Colors.a(Colors.accent, 0.5)
                    font { pixelSize: 10; family: "JetBrainsMono Nerd Font" }
                    Behavior on color { ColorAnimation { duration: Animations.fast } }

                    MouseArea {
                        id: clearMa
                        anchors.fill: parent; anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: UIState.notifications.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: UIState.clearNotifs()
                    }
                }
            }
        }

        Item {
            width:  parent.width
            height: parent.height - y
            clip:   true

            Rectangle {
                anchors.fill: parent
                radius: UIState.borderRadius * 0.75
                color:  Colors.a(Colors.surface, 0.5)
                Behavior on radius { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }
            }

            Text {
                anchors.centerIn: parent
                visible: UIState.notifications.length === 0
                text:    L10n.tr("all_clean", "All clean 󰸞")
                color:   Colors.a(Colors.fg, 0.15)
                font { pixelSize: 12; family: "JetBrainsMono Nerd Font" }
            }

            ListView {
                id: notifList
                anchors.fill: parent
                anchors.margins: 10
                clip:   true
                model:  groupedModel
                spacing: 8
                boundsBehavior: Flickable.StopAtBounds

                add: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Animations.medium; easing.type: Easing.OutCubic }
                        NumberAnimation { property: "x"; from: 24; to: 0; duration: Animations.medium; easing.type: Easing.OutExpo }
                    }
                }

                remove: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Animations.fast; easing.type: Easing.OutCubic }
                        NumberAnimation { property: "x"; to: 24; duration: Animations.fast; easing.type: Easing.OutCubic }
                    }
                }

                displaced: Transition {
                    NumberAnimation { property: "y"; duration: Animations.medium; easing.type: Easing.OutExpo }
                }

                delegate: Item {
                    id: groupDelegate
                    width:  notifList.width
                    height: groupCol.implicitHeight
                    clip:   true

                    property string groupApp:  model.app
                    property var parsedItems:  JSON.parse(model.items)
                    property bool expanded:    isGroupExpanded(model.app)
                    property int itemCount:    parsedItems.length
                    property var latestItem:   parsedItems[0]
                    property int bump:         model.bump

                    onBumpChanged: {
                        if (bump > 0) {
                            headerFlashAnim.start()
                            badgePopAnim.start()
                        }
                    }

                    Column {
                        id: groupCol
                        width:   parent.width
                        spacing: 6

                        Rectangle {
                            id: groupHeader
                            width:  parent.width
                            height: 36
                            radius: UIState.borderRadius * 0.75
                            color:  groupHeaderMa.containsMouse ? Colors.a(Colors.accent, 0.1) : Colors.a(Colors.fg, 0.04)
                            border.width: 1
                            border.color: groupHeaderMa.containsMouse ? Colors.a(Colors.accent, 0.15) : "transparent"

                            Behavior on color  { ColorAnimation { duration: Animations.fast } }
                            Behavior on radius { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }

                            SequentialAnimation {
                                id: headerFlashAnim
                                ColorAnimation { target: groupHeader; property: "color"; to: Colors.a(Colors.accent, 0.2); duration: 120 }
                                ColorAnimation { target: groupHeader; property: "color"; to: Colors.a(Colors.fg, 0.04); duration: Animations.slow; easing.type: Easing.OutCubic }
                            }

                            Row {
                                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                                spacing: 8

                                Text {
                                    text: "󰅂"
                                    color: Colors.a(Colors.fg, 0.35)
                                    font { pixelSize: 10; family: "JetBrainsMono Nerd Font" }
                                    anchors.verticalCenter: parent.verticalCenter
                                    rotation: groupDelegate.expanded ? 90 : 0
                                    Behavior on rotation {
                                        NumberAnimation { duration: Animations.medium; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
                                    }
                                }

                                Rectangle {
                                    width: 6; height: 6; radius: 3
                                    color: Colors.accent
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text:  groupDelegate.groupApp.toUpperCase()
                                    color: Colors.a(Colors.accent, 0.7)
                                    font { pixelSize: 9; family: "JetBrainsMono Nerd Font"; bold: true; letterSpacing: 0.8 }
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Row {
                                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                                spacing: 10

                                Rectangle {
                                    id: countBadge
                                    width:  countText.implicitWidth + 12
                                    height: 20; radius: UIState.borderRadius * 0.625
                                    color:  Colors.a(Colors.accent, 0.12)
                                    anchors.verticalCenter: parent.verticalCenter

                                    Behavior on radius { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }

                                    SequentialAnimation {
                                        id: badgePopAnim
                                        NumberAnimation { target: countBadge; property: "scale"; to: 1.4; duration: Animations.snap; easing.type: Easing.OutQuad }
                                        NumberAnimation { target: countBadge; property: "scale"; to: 1.0; duration: Animations.medium; easing.type: Easing.OutBack; easing.overshoot: Animations.springPower }
                                    }

                                    Text {
                                        id: countText
                                        anchors.centerIn: parent
                                        text:  groupDelegate.itemCount
                                        color: Colors.accent
                                        font { pixelSize: 9; family: "JetBrainsMono Nerd Font"; bold: true }
                                    }
                                }

                                Text {
                                    text:  "󰅖"
                                    color: groupDismissMa.containsMouse ? Colors.red : Colors.a(Colors.fg, 0.25)
                                    font { pixelSize: 12; family: "JetBrainsMono Nerd Font" }
                                    anchors.verticalCenter: parent.verticalCenter
                                    Behavior on color { ColorAnimation { duration: Animations.fast } }

                                    MouseArea {
                                        id: groupDismissMa
                                        anchors.fill: parent; anchors.margins: -6
                                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            groupDismissAnim.targetApp = groupDelegate.groupApp
                                            groupDismissAnim.start()
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: groupHeaderMa
                                anchors.fill: parent
                                anchors.rightMargin: 70
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: toggleGroup(groupDelegate.groupApp)
                            }
                        }

                        Rectangle {
                            visible: !groupDelegate.expanded
                            width:   parent.width
                            height:  visible ? previewContent.implicitHeight + 16 : 0
                            radius:  UIState.borderRadius * 0.625
                            color:   previewMa.containsMouse ? Colors.a(Colors.fg, 0.045) : Colors.a(Colors.fg, 0.025)
                            Behavior on color  { ColorAnimation { duration: Animations.fast } }
                            Behavior on radius { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }

                            MouseArea {
                                id: previewMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: toggleGroup(groupDelegate.groupApp)
                            }

                            Column {
                                id: previewContent
                                x: 14; y: 8
                                width:   parent.width - 28
                                spacing: 3

                                Text {
                                    text:  groupDelegate.latestItem ? groupDelegate.latestItem.title : ""
                                    color: Colors.fg
                                    font { pixelSize: 10; family: "JetBrainsMono Nerd Font"; bold: true }
                                    width: parent.width; elide: Text.ElideRight
                                }

                                Text {
                                    text:  groupDelegate.latestItem ? groupDelegate.latestItem.body : ""
                                    color: Colors.a(Colors.fg, 0.4)
                                    font { pixelSize: 9; family: "JetBrainsMono Nerd Font" }
                                    width: parent.width; elide: Text.ElideRight
                                    visible: text !== ""
                                }

                                Text {
                                    text:    groupDelegate.itemCount > 1 ? "+" + (groupDelegate.itemCount - 1) + " mais" : ""
                                    color:   Colors.a(Colors.accent, 0.5)
                                    font { pixelSize: 9; family: "JetBrainsMono Nerd Font" }
                                    visible: groupDelegate.itemCount > 1
                                }
                            }
                        }

                        Item {
                            width:  parent.width
                            height: groupDelegate.expanded ? expandedCol.implicitHeight : 0
                            clip:   true

                            Behavior on height {
                                NumberAnimation { duration: Animations.medium; easing.type: Easing.OutExpo }
                            }

                            Column {
                                id: expandedCol
                                width:   parent.width
                                spacing: 6

                                Repeater {
                                    model: groupDelegate.expanded ? groupDelegate.parsedItems : []

                                    Rectangle {
                                        id: notifCard
                                        width:  parent.width
                                        height: nTitle.implicitHeight + (nBody.visible ? nBody.implicitHeight + 6 : 0) + 32
                                        radius: UIState.borderRadius * 0.75
                                        color:  nItemMa.containsMouse ? Colors.a(Colors.fg, 0.055) : Colors.a(Colors.fg, 0.03)
                                        border.width: nItemMa.containsMouse ? 1 : 0
                                        border.color: Colors.a(Colors.accent, 0.12)
                                        opacity: 0
                                        x: 16

                                        Behavior on color  { ColorAnimation { duration: Animations.fast } }
                                        Behavior on radius { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }

                                        Component.onCompleted: cardAppearAnim.start()

                                        ParallelAnimation {
                                            id: cardAppearAnim
                                            NumberAnimation { target: notifCard; property: "opacity"; from: 0; to: 1; duration: Animations.medium; easing.type: Easing.OutCubic }
                                            NumberAnimation { target: notifCard; property: "x"; from: 16; to: 0; duration: Animations.medium; easing.type: Easing.OutExpo }
                                        }

                                        SequentialAnimation {
                                            id: cardDismissAnim
                                            ParallelAnimation {
                                                NumberAnimation { target: notifCard; property: "opacity"; to: 0; duration: Animations.fast; easing.type: Easing.OutCubic }
                                                NumberAnimation { target: notifCard; property: "x"; to: 24; duration: Animations.fast; easing.type: Easing.OutCubic }
                                            }
                                            ScriptAction { script: UIState.dismissNotif(modelData.id) }
                                        }

                                        MouseArea {
                                            id: nItemMa
                                            anchors.fill: parent
                                            anchors.rightMargin: 30
                                            hoverEnabled: true
                                        }

                                        Text {
                                            id: nTitle
                                            x: 14; y: 12
                                            width: notifCard.width - 42
                                            text:  modelData.title
                                            color: Colors.fg
                                            font { pixelSize: 11; family: "JetBrainsMono Nerd Font"; bold: true }
                                            wrapMode: Text.WordWrap
                                        }

                                        Text {
                                            id: nBody
                                            x: 14
                                            anchors.top: nTitle.bottom
                                            anchors.topMargin: 6
                                            width: notifCard.width - 42
                                            text:  modelData.body
                                            color: Colors.a(Colors.fg, 0.5)
                                            font { pixelSize: 10; family: "JetBrainsMono Nerd Font" }
                                            wrapMode: Text.WordWrap
                                            lineHeight: 1.35
                                            visible: modelData.body !== ""
                                        }

                                        Text {
                                            anchors { right: parent.right; top: parent.top; rightMargin: 10; topMargin: 12 }
                                            text:  "󰅖"
                                            color: nDismissMa.containsMouse ? Colors.red : Colors.a(Colors.fg, 0.2)
                                            font { pixelSize: 11; family: "JetBrainsMono Nerd Font" }
                                            Behavior on color { ColorAnimation { duration: Animations.fast } }

                                            MouseArea {
                                                id: nDismissMa
                                                anchors.fill: parent; anchors.margins: -6
                                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: cardDismissAnim.start()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    SequentialAnimation {
                        id: groupDismissAnim
                        property string targetApp: ""
                        ParallelAnimation {
                            NumberAnimation { target: groupDelegate; property: "opacity"; to: 0; duration: Animations.fast; easing.type: Easing.OutCubic }
                            NumberAnimation { target: groupDelegate; property: "x"; to: 24; duration: Animations.fast; easing.type: Easing.OutCubic }
                        }
                        ScriptAction { script: UIState.dismissGroup(groupDismissAnim.targetApp) }
                    }
                }
            }
        }
    }
}
