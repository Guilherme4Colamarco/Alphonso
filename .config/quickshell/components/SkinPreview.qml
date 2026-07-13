import QtQuick
import ".."

MaterialButton {
    id: root
    property string profileId: "kamalen"
    property var profile: Skins.profile(profileId)
    active: UIState.skinProfile === profileId
    role: "raised"
    height: Metrics.dp(104)

    Column {
        anchors { fill: parent; margins: Metrics.dp(12) }
        spacing: Metrics.dp(8)
        Text { text: root.profile.icon + "  " + root.profile.label; color: root.active ? Colors.accent : Colors.fg; font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font"; bold: true } }
        Row {
            spacing: Metrics.dp(8)
            MaterialSurface { width: Metrics.dp(58); height: Metrics.dp(24); role: "control"; active: true }
            MaterialSurface { width: Metrics.dp(42); height: Metrics.dp(24); role: "sunken" }
        }
        Text { text: root.profile.description; color: Colors.a(Colors.fg, 0.58); font { pixelSize: Metrics.sp(8); family: "JetBrainsMono Nerd Font" } }
    }
}
