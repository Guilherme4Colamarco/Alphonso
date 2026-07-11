// PillButton — botão circular reusável da barra
// Padrão: ícone + circle bg que cresce no hover (17→21px)
// Props: icon, iconSize, active, activeColor, hoverColor, onClicked, containsMouse
import QtQuick

Item {
    id: root

    // ── API ──────────────────────────────────────────
    property string icon: ""
    property int iconSize: 12
    property bool active: false
    property color activeColor: Colors.accent
    property color inactiveColor: Colors.fg
    property real activeOpacity: 0.70
    property real inactiveOpacity: 0.30
    property real hoverColorOpacity: 0.10
    property color hoverColor: active ? activeColor : Colors.fg
    signal clicked(var mouse)
    signal rightClicked(var mouse)

    // ── Read-only state ──────────────────────────────
    readonly property bool containsMouse: ma.containsMouse
    readonly property bool lit: active || ma.containsMouse

    implicitWidth: 22
    implicitHeight: 22

    Rectangle {
        anchors.centerIn: parent
        width: root.lit ? 21 : 17
        height: width
        radius: width / 2
        color: root.lit ? Qt.rgba(root.hoverColor.r, root.hoverColor.g, root.hoverColor.b, root.hoverColorOpacity) : Qt.rgba(Colors.fg.r, Colors.fg.g, Colors.fg.b, 0.035)
        Behavior on width { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutBack; easing.overshoot: Animations.springPower } }
        Behavior on color { ColorAnimation { duration: Animations.fast } }
    }

    Text {
        anchors.centerIn: parent
        text: root.icon
        color: root.active
              ? Qt.rgba(root.activeColor.r, root.activeColor.g, root.activeColor.b, root.activeOpacity)
              : ma.containsMouse
                  ? Qt.rgba(root.inactiveColor.r, root.inactiveColor.g, root.inactiveColor.b, root.activeOpacity)
                  : Qt.rgba(root.inactiveColor.r, root.inactiveColor.g, root.inactiveColor.b, root.inactiveOpacity)
        font { pixelSize: root.iconSize; family: "JetBrainsMono Nerd Font" }
        Behavior on color { ColorAnimation { duration: Animations.fast } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.margins: -6
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) root.rightClicked(mouse)
            else root.clicked(mouse)
        }
    }
}
