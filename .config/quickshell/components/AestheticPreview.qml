import QtQuick
import ".."

Rectangle {
    id: root
    property string profileId: "pills"
    property var profile: Aesthetics.profile(profileId)
    property var tokens: Aesthetics.tokensFor(profileId)
    property bool selected: UIState.aestheticProfile === profileId
    signal clicked()

    height: Metrics.dp(116)
    radius: Aesthetics.radius(Metrics.dp(tokens.cardRadius), height)
    color: selected ? Colors.a(Colors.accent, 0.16) : previewMouse.containsMouse ? Colors.a(Colors.fg, 0.07) : Colors.a(Colors.surface, 0.35)
    border.width: selected ? Metrics.dp(2) : Math.max(Metrics.dp(tokens.borderWidth), Metrics.dp(1))
    border.color: selected ? Colors.accent : Colors.a(Colors.fg, 0.12)

    Column {
        anchors { fill: parent; margins: Metrics.dp(12) }
        spacing: Metrics.dp(9)
        Text { text: root.profile.icon + "  " + root.profile.label; color: root.selected ? Colors.accent : Colors.fg; font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font"; bold: true } }
        Row {
            spacing: Metrics.dp(8)
            Rectangle { width: Metrics.dp(62); height: Metrics.dp(25); radius: Aesthetics.radius(Metrics.dp(root.tokens.buttonRadius), height); color: Colors.a(Colors.accent, 0.8) }
            Rectangle {
                width: Metrics.dp(root.tokens.switchWidth); height: Metrics.dp(root.tokens.switchHeight)
                radius: Aesthetics.radius(Metrics.dp(root.tokens.controlRadius), height); color: Colors.a(Colors.accent, 0.7)
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: Metrics.dp(3)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Metrics.dp(root.tokens.switchThumbSize)
                    height: width
                    radius: Aesthetics.radius(Metrics.dp(root.tokens.controlRadius), height)
                    color: Colors.bg
                }
            }
        }
        Rectangle {
            width: parent.width; height: Metrics.dp(root.tokens.sliderTrackHeight)
            radius: Aesthetics.radius(Metrics.dp(root.tokens.controlRadius), height); color: Colors.a(Colors.fg, 0.12)
            Rectangle { width: parent.width * 0.64; height: parent.height; radius: parent.radius; color: Colors.accent }
        }
        Text { text: root.profile.description; color: Colors.a(Colors.fg, 0.55); font { pixelSize: Metrics.sp(8); family: "JetBrainsMono Nerd Font" } }
    }
    MouseArea { id: previewMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
