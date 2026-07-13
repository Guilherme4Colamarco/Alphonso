import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import Qt5Compat.GraphicalEffects

PanelWindow {
    id: lockscreen

    property bool showing: UIState.locked
    property string password: ""
    property bool authenticating: false
    property bool authFailed: false
    property bool authInputPending: false
    property var pfpList: []
    property string timeText: ""
    property string dateText: ""

    property real br:   UIState.borderRadius
    property real brSm: Math.round(br * 0.625)

    property string wallPath: ""
    property string wallExt: {
        var dot = wallPath.lastIndexOf(".")
        return dot >= 0 ? wallPath.slice(dot + 1).toLowerCase() : ""
    }
    property bool isVideo: ["mp4", "webm", "mkv"].indexOf(wallExt) >= 0
    property bool isGif: wallExt === "gif"
    property bool isStatic: wallPath !== "" && !isVideo && !isGif
    property string wallName: wallPath.substring(wallPath.lastIndexOf("/") + 1)
    property string videoFramePath: Quickshell.env("HOME") + "/.cache/wallpaper-thumbs/" + wallName + ".thumb.jpg"

    visible: showing
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: showing ? ExclusionMode.Normal : ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "lockscreen"
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function a(c, o) { return Qt.rgba(c.r, c.g, c.b, o) }

    function getPfpPath() {
        if (pfpList.length === 0) return ""
        var idx = UIState.pfpIndex
        if (idx < 0 || idx >= pfpList.length) return ""
        var path = pfpList[idx]
        if (!path || path.length === 0) return ""
        return path
    }

    function tryAuth() {
        if (password.length === 0 || authenticating) return
        authenticating = true
        authFailed = false
        authInputPending = true
        authProc.command = [
            "python3",
            Quickshell.env("HOME") + "/.config/quickshell/lockscreen_auth.py",
            Quickshell.env("USER")
        ]
        authProc.running = true
    }

    function blurRadius() {
        if (UIState.blurProfile === "frosted")  return 64
        if (UIState.blurProfile === "balanced") return 48
        if (UIState.blurProfile === "subtle")   return 28
        return 0
    }

    onShowingChanged: {
        if (showing) {
            password         = ""
            hiddenInput.text = ""
            authenticating   = false
            authFailed       = false
            pfpListProc.running = true
            wallPathProc.running = true
            hiddenInput.forceActiveFocus()
        } else {
            hiddenInput.focus = false
        }
    }

    Timer {
        id: failResetTimer
        interval: 600
        onTriggered: authFailed = false
    }

    Process {
        id: wallPathProc
        command: ["readlink", "-f", Quickshell.env("HOME") + "/wallpapers/current"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                wallPath = data.trim()
            }
        }
    }

    Process {
        id: pfpListProc
        command: ["bash", "-c", "ls -1 ~/.config/quickshell/assets/pfps/*.{jpg,png} 2>/dev/null"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => { pfpList = data.trim().split("\n").filter(l => l.length > 0) }
        }
    }

    Process { id: lockscreenBtnProc }

    Process {
        id: authProc
        onRunningChanged: {
            if (running && authInputPending) {
                authProc.write(password + "\n")
                authInputPending = false
                password = ""
                hiddenInput.text = ""
            }
        }
        onExited: code => {
            authenticating = false
            if (code === 0) {
                unlockAnim.start()
            } else {
                authFailed       = true
                password         = ""
                hiddenInput.text = ""
                shakeAnim.start()
                failResetTimer.restart()
            }
        }
    }

    Timer {
        interval: 1000
        running:  showing
        repeat:   true
        triggeredOnStart: true
        onTriggered: {
            var now  = new Date()
            var h    = now.getHours()
            var m    = now.getMinutes()
            var ampm = h >= 12 ? "PM" : "AM"
            h = h % 12
            if (h === 0) h = 12
            timeText = h + ":" + (m < 10 ? "0" : "") + m + " " + ampm

            var lang = L10n.lang
            if (lang === "pt") {
                var daysPt = ["Domingo", "Segunda-feira", "Terça-feira", "Quarta-feira", "Quinta-feira", "Sexta-feira", "Sábado"]
                var monthsPt = ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"]
                dateText = daysPt[now.getDay()] + ", " + now.getDate() + " de " + monthsPt[now.getMonth()]
            } else {
                var daysEn = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
                var monthsEn = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
                dateText = daysEn[now.getDay()] + ", " + monthsEn[now.getMonth()] + " " + now.getDate()
            }
        }
    }

    SequentialAnimation {
        id: unlockAnim
        NumberAnimation { target: mainContent; property: "opacity"; to: 0; duration: 250; easing.type: Easing.OutCubic }
        ScriptAction { script: {
            UIState.locked   = false
            password         = ""
            hiddenInput.text = ""
        }}
    }

    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: inputCapsule; property: "x"; to: inputCapsule.baseX + 18; duration: 50 }
        NumberAnimation { target: inputCapsule; property: "x"; to: inputCapsule.baseX - 18; duration: 45 }
        NumberAnimation { target: inputCapsule; property: "x"; to: inputCapsule.baseX + 12; duration: 40 }
        NumberAnimation { target: inputCapsule; property: "x"; to: inputCapsule.baseX - 8;  duration: 35 }
        NumberAnimation { target: inputCapsule; property: "x"; to: inputCapsule.baseX;      duration: 30 }
    }

    Item {
        id: mainContent
        anchors.fill: parent
        opacity: showing ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            color: Colors.bg
        }

        Item {
            id: wallpaperLayer
            anchors.fill: parent

            Image {
                id: wallStatic
                anchors.fill: parent
                source: isVideo ? "file://" + videoFramePath : isStatic ? "file://" + wallPath : ""
                sourceSize.width: screen ? screen.width : 1920
                sourceSize.height: screen ? screen.height : 1080
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                visible: isStatic || isVideo
            }

            AnimatedImage {
                id: wallGif
                anchors.fill: parent
                source: isGif ? "file://" + wallPath : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                playing: isGif && showing
                visible: isGif
            }

            layer.enabled: blurRadius() > 0
            layer.effect: FastBlur {
                radius: blurRadius()
            }
        }

        Rectangle {
            anchors.fill: parent
            color: a(Colors.bg, blurRadius() > 0 ? 0.4 : 0.6)
        }

        TextInput {
            id: hiddenInput
            visible: false
            focus: showing
            echoMode: TextInput.Password
            onTextChanged: password = text
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    tryAuth()
                    event.accepted = true
                } else if (event.key === Qt.Key_Escape) {
                    text       = ""
                    password   = ""
                    authFailed = false
                    event.accepted = true
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: hiddenInput.forceActiveFocus()
        }

        Column {
            anchors {
                top: parent.top
                topMargin: 80
                horizontalCenter: parent.horizontalCenter
            }
            spacing: Metrics.dp(6)
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:  timeText
                color: Colors.fg
                font { pixelSize: Metrics.sp(72); family: "JetBrainsMono Nerd Font"; bold: true }
                style: Text.Raised
                styleColor: a(Colors.bg, 0.5)
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:  dateText
                color: a(Colors.fg, 0.6)
                font { pixelSize: Metrics.sp(16); family: "JetBrainsMono Nerd Font" }
                style: Text.Raised
                styleColor: a(Colors.bg, 0.5)
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: Metrics.dp(24)
            Item {
                width:  Metrics.dp(160)
height: Metrics.dp(160)
anchors.horizontalCenter: parent.horizontalCenter

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color:  a(Colors.bg, 0.3)
                    border.width: 3
                    border.color: authFailed
                        ? a(Colors.red, 0.7)
                        : a(Colors.surface, 0.6)
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                }

                Image {
                    id: pfpImg
                    anchors.fill: parent
                    anchors.margins: Metrics.dp(4)
source: {
                        var path = getPfpPath()
                        return path.length > 0 ? "file://" + path : ""
                    }
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(320, 320)
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
                    visible: getPfpPath().length > 0
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰀄"
                    color: a(Colors.fg, 0.3)
                    font { pixelSize: Metrics.sp(64); family: "JetBrainsMono Nerd Font" }
                    visible: getPfpPath().length === 0
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:  Quickshell.env("USER")
                color: Colors.fg
                font { pixelSize: Metrics.sp(18); family: "JetBrainsMono Nerd Font" }
                style: Text.Raised
                styleColor: a(Colors.bg, 0.4)
            }

            Item {
                id: inputCapsule
                property real baseX: 0
                width:  Metrics.dp(220)
height: Metrics.dp(40)
anchors.horizontalCenter: parent.horizontalCenter
                x: baseX
                opacity: password.length > 0 || authenticating || authFailed ? 1 : 0
                scale:   password.length > 0 || authenticating || authFailed ? 1 : 0.9

                Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on scale   { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color:  authFailed
                        ? a(Colors.red, 0.15)
                        : a(Colors.surface, 0.5)
                    border.width: 1.5
                    border.color: authFailed
                        ? a(Colors.red, 0.55)
                        : authenticating
                            ? a(Colors.accent, 0.45)
                            : a(Colors.fg, 0.2)

                    Behavior on color        { ColorAnimation { duration: 100 } }
                    Behavior on border.color { ColorAnimation { duration: 100 } }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: Metrics.dp(6)
visible: !authenticating && !authFailed

                    Repeater {
                        model: Math.min(password.length, 24)
                        Rectangle {
                            width:  Metrics.dp(6)
height: Metrics.dp(6)
radius: Metrics.dp(3)
color:  a(Colors.fg, 0.7)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: authFailed
                    text:    "󰅖"
                    color:   Colors.red
                    font { pixelSize: Metrics.sp(16); family: "JetBrainsMono Nerd Font" }
                }

                Text {
                    anchors.centerIn: parent
                    visible: authenticating
                    text:    "󰔟"
                    color:   Colors.accent
                    font { pixelSize: Metrics.sp(16); family: "JetBrainsMono Nerd Font" }

                    RotationAnimation on rotation {
                        running: authenticating
                        from: 0
                        to: 360
                        duration: 800
                        loops: Animation.Infinite
                    }
                }
            }

            // Lockscreen Power Actions
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Metrics.dp(16)
opacity: password.length === 0 && !authenticating && !authFailed ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                Repeater {
                    model: [
                        { icon: "⏻", cmd: "systemctl poweroff", color: "red" },
                        { icon: "󰜉", cmd: "systemctl reboot", color: "yellow" },
                        { icon: "󰒲", cmd: "systemctl suspend", color: "accent" }
                    ]
                    Item {
                        required property int index
                        required property var modelData
                        width: Metrics.dp(44)
height: Metrics.dp(44)
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: btnMa.containsMouse ? a(Colors[modelData.color], 0.15) : a(Colors.bg, 0.4)
                            border.width: 1.5
                            border.color: btnMa.containsMouse ? a(Colors[modelData.color], 0.5) : a(Colors.fg, 0.15)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.icon
                            color: btnMa.containsMouse ? Colors[modelData.color] : a(Colors.fg, 0.7)
                            font { pixelSize: Metrics.sp(18); family: "JetBrainsMono Nerd Font" }
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        MouseArea {
                            id: btnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                lockscreenBtnProc.command = ["bash", "-c", modelData.cmd]
                                lockscreenBtnProc.running = true
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        pfpListProc.running = true
        wallPathProc.running = true
    }
}
