import QtQuick
import ".."

MaterialButton {
    id: root
    property string profileId: "kamalen"
    property var profile: Skins.profile(profileId)
    property var recipe: Skins.recipe(profileId)
    active: UIState.skinProfile === profileId
    role: "raised"
    skinId: root.profileId
    height: Metrics.dp(118)
    clip: true

    Column {
        anchors { fill: parent; margins: Metrics.dp(12) }
        spacing: Metrics.dp(7)
        Text {
            width: parent.width
            text: root.profile.icon + "  " + root.profile.label
            color: root.active ? Colors.accent : Colors.fg
            elide: Text.ElideRight
            font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font"; bold: true }
        }
        Row {
            width: parent.width
            spacing: Metrics.dp(8)
            MaterialSurface {
                width: Metrics.dp(72)
                height: Metrics.dp(26)
                role: "control"
                active: true
                skinId: root.profileId
                Text {
                    anchors.centerIn: parent
                    text: "Botão"
                    color: Colors.fg
                    font { pixelSize: Metrics.sp(8); family: "JetBrainsMono Nerd Font"; bold: true }
                }
            }
            MaterialSurface {
                width: Math.max(Metrics.dp(56), parent.width - Metrics.dp(80))
                height: Metrics.dp(26)
                role: "sunken"
                skinId: root.profileId
                Text {
                    anchors { left: parent.left; leftMargin: Metrics.dp(8); verticalCenter: parent.verticalCenter }
                    text: "Campo"
                    color: Colors.a(Colors.fg, 0.64)
                    font { pixelSize: Metrics.sp(8); family: "JetBrainsMono Nerd Font" }
                }
            }
        }
        Row {
            width: parent.width
            spacing: Metrics.dp(10)
            MaterialTrack {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Metrics.dp(54)
                height: Metrics.dp(root.recipe.sliderTrackHeight)
                value: 0.62
                active: true
                skinId: root.profileId
            }
            MaterialSurface {
                anchors.verticalCenter: parent.verticalCenter
                width: Metrics.dp(root.recipe.switchWidth)
                height: Metrics.dp(root.recipe.switchHeight)
                role: "control"
                active: true
                skinId: root.profileId
                MaterialSurface {
                    anchors { right: parent.right; rightMargin: Metrics.dp(3); verticalCenter: parent.verticalCenter }
                    width: Metrics.dp(root.recipe.switchThumbSize)
                    height: width
                    role: "raised"
                    skinId: root.profileId
                }
            }
        }
        Text {
            width: parent.width
            text: root.profile.description
            color: Colors.a(Colors.fg, 0.58)
            elide: Text.ElideRight
            font { pixelSize: Metrics.sp(8); family: "JetBrainsMono Nerd Font" }
        }
    }
}
