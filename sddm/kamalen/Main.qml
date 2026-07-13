import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Rectangle {
    id: root

    readonly property string assetRoot: "file:///var/lib/kamalen-sddm/"
    readonly property string dynamicBackground: assetRoot + "background-blurred.jpg"
    readonly property string dynamicAvatar: assetRoot + "owner-avatar.png"
    readonly property string fallbackBackground: "assets/fallback-background.svg"
    readonly property string fallbackAvatar: "assets/fallback-avatar.svg"
    readonly property int screenOrientation: Screen.primaryOrientation
    readonly property bool isPrimaryScreen: typeof primaryScreen !== "undefined"
        ? primaryScreen : true

    readonly property color backgroundColor: configColor(config.Bg, "#1e1e2e")
    readonly property color foregroundColor: configColor(config.Fg, "#cdd6f4")
    readonly property color surfaceColor: configColor(config.Surface, "#313244")
    readonly property color accentColor: configColor(config.Accent, "#89b4fa")
    readonly property color errorColor: configColor(config.Red, "#f38ba8")
    readonly property color warningColor: configColor(config.Yellow, "#f9e2af")
    readonly property real cornerRadius: configNumber(config.BorderRadius, 16, 0, 48)
    readonly property bool darkMode: configBoolean(config.DarkMode, true)
    readonly property string owner: validOwner(config.OwnerUsername)
    readonly property string selectedBackground: {
        var blurred = configuredAsset(config.BlurredBackground, "background-blurred.jpg", "")
        var regular = configuredAsset(config.Background, "background.jpg", fallbackBackground)
        return config.BlurProfile !== "none" && blurred ? blurred : regular
    }
    readonly property string ownerAvatar: configuredAsset(config.Avatar, "owner-avatar.png", "")
    property bool authenticating: false
    property bool authenticationFailed: false
    property int selectedUser: Math.max(0, userModel.lastIndex)
    property int selectedSession: Math.max(0, sessionModel.lastIndex)
    property string timeText: Qt.formatDateTime(new Date(), "hh:mm AP")
    property string dateText: Qt.formatDateTime(new Date(), "dddd, d 'de' MMMM")

    color: backgroundColor
    focus: true

    function configColor(value, fallback) {
        return typeof value === "string" && /^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(value)
            ? value : fallback
    }

    function configNumber(value, fallback, minimum, maximum) {
        var number = Number(value)
        return isFinite(number) ? Math.max(minimum, Math.min(maximum, number)) : fallback
    }

    function configBoolean(value, fallback) {
        if (value === true || value === "true" || value === "1")
            return true
        if (value === false || value === "false" || value === "0")
            return false
        return fallback
    }

    function configuredAsset(value, filename, fallback) {
        var plain = "/var/lib/kamalen-sddm/" + filename
        var url = "file://" + plain
        return value === plain || value === url ? url : fallback
    }

    function validOwner(value) {
        return typeof value === "string" && /^[a-z_][a-z0-9_-]{0,31}$/.test(value)
            ? value : ""
    }

    function selectPreviousUser() {
        if (userModel.count > 0)
            selectedUser = (selectedUser - 1 + userModel.count) % userModel.count
    }

    function selectNextUser() {
        if (userModel.count > 0)
            selectedUser = (selectedUser + 1) % userModel.count
    }

    function submitLogin() {
        if (authenticating || passwordInput.text.length === 0 || !userChooser.currentItem)
            return
        authenticating = true
        authenticationFailed = false
        sddm.login(userChooser.currentItem.username, passwordInput.text, selectedSession)
    }

    Component.onCompleted: {
        passwordInput.forceActiveFocus()
    }

    onSelectedUserChanged: {
        userChooser.currentIndex = selectedUser
        passwordInput.text = ""
        passwordInput.forceActiveFocus()
    }

    Connections {
        target: sddm

        function onLoginFailed() {
            authenticating = false
            authenticationFailed = true
            passwordInput.text = ""
            shakeAnimation.restart()
            passwordInput.forceActiveFocus()
        }

        function onLoginSucceeded() {
            authenticating = false
            loginFade.start()
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var now = new Date()
            root.timeText = Qt.formatDateTime(now, "hh:mm AP")
            root.dateText = Qt.formatDateTime(now, "dddd, d 'de' MMMM")
        }
    }

    Image {
        id: backgroundImage
        anchors.fill: parent
        source: root.selectedBackground
        sourceSize: Qt.size(Math.min(root.width, 3840), Math.min(root.height, 2160))
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        visible: status === Image.Ready
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(root.backgroundColor.r, root.backgroundColor.g, root.backgroundColor.b,
                       root.darkMode ? 0.46 : 0.28)
    }

    ListView {
        id: userChooser
        width: 1
        height: 1
        opacity: 0
        model: userModel
        currentIndex: root.selectedUser
        interactive: false

        delegate: Item {
            required property int index
            required property string name
            required property string realName
            required property string icon
            property string username: name
            property string displayName: realName || name
            property string userIcon: icon
            width: 1
            height: 1
        }
    }

    Item {
        id: mainContent
        anchors.fill: parent
        visible: root.isPrimaryScreen

        Column {
            anchors.top: parent.top
            anchors.topMargin: Math.max(48, parent.height * 0.075)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.timeText
                color: root.foregroundColor
                font.family: config.Font || "JetBrainsMono Nerd Font"
                font.pixelSize: Math.max(46, Math.min(72, root.height * 0.067))
                font.bold: true
                style: Text.Raised
                styleColor: Qt.rgba(root.backgroundColor.r, root.backgroundColor.g, root.backgroundColor.b, 0.5)
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.dateText
                color: Qt.rgba(root.foregroundColor.r, root.foregroundColor.g, root.foregroundColor.b, 0.68)
                font.family: config.Font || "JetBrainsMono Nerd Font"
                font.pixelSize: 16
                style: Text.Raised
                styleColor: Qt.rgba(root.backgroundColor.r, root.backgroundColor.g, root.backgroundColor.b, 0.5)
            }
        }

        Column {
            id: loginColumn
            anchors.centerIn: parent
            spacing: 18

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 22

                RoundButton {
                    id: previousUserButton
                    text: "‹"
                    flat: true
                    visible: userModel.count > 1
                    font.pixelSize: 34
                    palette.buttonText: root.foregroundColor
                    Accessible.name: qsTr("Usuário anterior")
                    onClicked: root.selectPreviousUser()
                    KeyNavigation.tab: passwordInput
                }

                Rectangle {
                    width: 160
                    height: 160
                    radius: width / 2
                    color: Qt.rgba(root.backgroundColor.r, root.backgroundColor.g, root.backgroundColor.b, 0.35)
                    border.width: 3
                    border.color: root.authenticationFailed ? root.errorColor
                        : Qt.rgba(root.surfaceColor.r, root.surfaceColor.g, root.surfaceColor.b, 0.75)

                    Image {
                        id: avatarImage
                        anchors.fill: parent
                        anchors.margins: 5
                        source: {
                            if (!userChooser.currentItem)
                                return root.fallbackAvatar
                            if (root.ownerAvatar && root.owner
                                    && userChooser.currentItem.username === root.owner)
                                return root.ownerAvatar
                            return userChooser.currentItem.userIcon || root.fallbackAvatar
                        }
                        sourceSize: Qt.size(320, 320)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }

                RoundButton {
                    id: nextUserButton
                    text: "›"
                    flat: true
                    visible: userModel.count > 1
                    font.pixelSize: 34
                    palette.buttonText: root.foregroundColor
                    Accessible.name: qsTr("Próximo usuário")
                    onClicked: root.selectNextUser()
                    KeyNavigation.tab: passwordInput
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: userChooser.currentItem ? userChooser.currentItem.displayName : qsTr("Usuário")
                color: root.foregroundColor
                font.family: config.Font || "JetBrainsMono Nerd Font"
                font.pixelSize: 18
            }

            Item {
                id: inputCapsule
                width: 240
                height: 42
                anchors.horizontalCenter: parent.horizontalCenter

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: root.authenticationFailed
                        ? Qt.rgba(root.errorColor.r, root.errorColor.g, root.errorColor.b, 0.16)
                        : Qt.rgba(root.surfaceColor.r, root.surfaceColor.g, root.surfaceColor.b, 0.58)
                    border.width: 1.5
                    border.color: root.authenticationFailed ? root.errorColor
                        : root.authenticating ? root.accentColor
                        : Qt.rgba(root.foregroundColor.r, root.foregroundColor.g, root.foregroundColor.b, 0.22)
                }

                TextInput {
                    id: passwordInput
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    color: "transparent"
                    selectionColor: "transparent"
                    selectedTextColor: "transparent"
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    enabled: !root.authenticating
                    activeFocusOnTab: true
                    Accessible.name: qsTr("Senha")
                    onTextChanged: root.authenticationFailed = false
                    onAccepted: root.submitLogin()
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.submitLogin()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Escape) {
                            text = ""
                            root.authenticationFailed = false
                            event.accepted = true
                        } else if (event.key === Qt.Key_Left && text.length === 0) {
                            root.selectPreviousUser()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Right && text.length === 0) {
                            root.selectNextUser()
                            event.accepted = true
                        }
                    }
                    KeyNavigation.tab: sessionSelector
                }

                Row {
                    id: passwordDots
                    anchors.centerIn: parent
                    spacing: 6
                    visible: !root.authenticating && !root.authenticationFailed

                    Repeater {
                        model: Math.min(passwordInput.text.length, 24)

                        Rectangle {
                            required property int index
                            width: 6
                            height: 6
                            radius: 3
                            color: Qt.rgba(root.foregroundColor.r, root.foregroundColor.g,
                                           root.foregroundColor.b, 0.75)
                        }
                    }
                }

                BusyIndicator {
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    running: root.authenticating
                    visible: running
                    palette.highlight: root.accentColor
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.authenticationFailed
                    text: "×"
                    color: root.errorColor
                    font.pixelSize: 22
                    font.bold: true
                }
            }

            ComboBox {
                id: sessionSelector
                anchors.horizontalCenter: parent.horizontalCenter
                width: 240
                model: sessionModel
                textRole: "name"
                currentIndex: root.selectedSession
                font.family: config.Font || "JetBrainsMono Nerd Font"
                Accessible.name: qsTr("Sessão")
                onActivated: index => root.selectedSession = index
                KeyNavigation.tab: suspendButton
            }

            Row {
                id: powerActions
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 14

                RoundButton {
                    id: suspendButton
                    text: "󰒲"
                    palette.button: root.surfaceColor
                    palette.buttonText: root.accentColor
                    Accessible.name: qsTr("Suspender")
                    onClicked: sddm.suspend()
                    KeyNavigation.tab: rebootButton
                }

                RoundButton {
                    id: rebootButton
                    text: "󰜉"
                    palette.button: root.surfaceColor
                    palette.buttonText: root.warningColor
                    Accessible.name: qsTr("Reiniciar")
                    onClicked: sddm.reboot()
                    KeyNavigation.tab: powerOffButton
                }

                RoundButton {
                    id: powerOffButton
                    text: "⏻"
                    palette.button: root.surfaceColor
                    palette.buttonText: root.errorColor
                    Accessible.name: qsTr("Desligar")
                    onClicked: sddm.powerOff()
                    KeyNavigation.tab: previousUserButton
                }
            }
        }
    }

    SequentialAnimation {
        id: shakeAnimation
        NumberAnimation { target: loginColumn; property: "anchors.horizontalCenterOffset"; from: 0; to: 18; duration: 50 }
        NumberAnimation { target: loginColumn; property: "anchors.horizontalCenterOffset"; from: 18; to: -18; duration: 45 }
        NumberAnimation { target: loginColumn; property: "anchors.horizontalCenterOffset"; from: -18; to: 12; duration: 40 }
        NumberAnimation { target: loginColumn; property: "anchors.horizontalCenterOffset"; from: 12; to: -8; duration: 35 }
        NumberAnimation { target: loginColumn; property: "anchors.horizontalCenterOffset"; from: -8; to: 0; duration: 30 }
    }

    OpacityAnimator {
        id: loginFade
        target: mainContent
        from: 1
        to: 0
        duration: 250
    }
}
