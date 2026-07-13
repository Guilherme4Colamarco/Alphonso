import QtQuick
import ".."

Item {
    id: root
    property var helpers
    property var animationIds: ["bubbly", "calm", "snappy", "extraslow", "none"]
    property var animationLabels: ["Elástico", "Calmo", "Rápido", "Lento", "Nenhum"]
    property var blurIds: ["frosted", "balanced", "subtle", "none"]
    property var blurLabels: ["Forte", "Equilibrado", "Suave", "Nenhum"]

    Flickable {
        anchors.fill: parent
        contentHeight: content.height + 20
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: content
            width: parent.width
            spacing: Metrics.dp(10)
            Text {
                width: parent.width
                text: MangoConfig.styleApplying
                    ? L10n.tr("applying", "Applying…")
                    : UIState.styleError !== ""
                        ? UIState.styleError
                        : UIState.activeStylePreset === "custom"
                            ? "Personalizado · " + root.animationLabels[root.animationIds.indexOf(UIState.animationProfile)]
                                + " · " + root.blurLabels[root.blurIds.indexOf(UIState.blurProfile)]
                                + " · " + UIState.borderRadius + " px"
                            : "Preset ativo"
                color: UIState.styleError !== "" ? Colors.red : Colors.a(Colors.fg, 0.6)
                wrapMode: Text.WordWrap
                font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font" }
            }

            Grid {
                width: parent.width
                columns: 2
                spacing: Metrics.dp(8)
                Repeater {
                    model: StyleProfiles.presets
                    Rectangle {
                        required property var modelData
                        width: (parent.width - 8) / 2
                        height: Metrics.dp(68)
                        radius: UIState.borderRadius * 0.75
                        color: UIState.activeStylePreset === modelData.id
                            ? Colors.a(Colors.accent, 0.18)
                            : presetMouse.containsMouse ? Colors.a(Colors.fg, 0.07) : Colors.a(Colors.surface, 0.35)
                        border.width: UIState.activeStylePreset === modelData.id ? 1 : 0
                        border.color: Colors.a(Colors.accent, 0.4)

                        Row {
                            anchors.centerIn: parent
                            spacing: Metrics.dp(10)
Text { text: modelData.icon; color: Colors.accent; font { pixelSize: Metrics.sp(20); family: "JetBrainsMono Nerd Font" } }
                            Text { text: modelData.label; color: Colors.fg; font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font"; bold: true } }
                        }
                        MouseArea {
                            id: presetMouse
                            anchors.fill: parent
                            enabled: !MangoConfig.styleApplying
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: UIState.applyStylePreset(modelData.id)
                        }
                    }
                }
            }

            ConfigSection {
                title: "Personalizar estética"
                icon: "󰏘"
                expanded: true
                width: parent.width

                ConfigSlider {
                    label: "Arredondamento"
                    value: UIState.borderRadius
                    minValue: 0; maxValue: 32; stepSize: 1; unit: "px"
                    onValueModified: value => UIState.setBorderRadius(value)
                }
                ConfigSpinner {
                    label: "Movimento"
                    model: root.animationLabels
                    currentIndex: root.animationIds.indexOf(UIState.animationProfile)
                    onActivated: index => UIState.setAnimationProfile(root.animationIds[index])
                }
                ConfigSpinner {
                    label: "Desfoque"
                    model: root.blurLabels
                    currentIndex: root.blurIds.indexOf(UIState.blurProfile)
                    onActivated: index => UIState.setBlurProfile(root.blurIds[index])
                }
            }

            ConfigSection {
                title: "Interface"
                icon: "󰍹"
                expanded: true
                width: parent.width

                ConfigSlider {
                    label: "Escala global"
                    value: UIState.uiScale * 100
                    minValue: 80; maxValue: 200; stepSize: 5; unit: "%"
                    onValueModified: value => UIState.setUiScale(value / 100)
                }
                ConfigToggle {
                    label: "Navegação Vim (h/j/k/l, g/G)"
                    checked: UIState.vimNavigationEnabled
                    onToggled: value => UIState.setVimNavigationEnabled(value)
                }
                TileButton {
                    width: parent.width
                    icon: "󰑐"
                    label: "Restaurar 100%"
                    sublabel: "Redefinir tamanho da interface"
                    active: false
                    onClicked: UIState.setUiScale(1.0)
                }
            }

            TileButton {
                width: parent.width
                icon: UIState.darkMode ? "󰖔" : "󰖕"
                label: UIState.darkMode ? L10n.tr("dark", "Dark") : L10n.tr("light", "Light")
                sublabel: L10n.tr("theme", "Theme")
                active: UIState.darkMode
                onClicked: UIState.toggleDarkMode()
            }
            TileButton {
                width: parent.width
                icon: "󱡔"
                label: UIState.transparencyEnabled ? L10n.tr("transparent", "Glass") : L10n.tr("opaque", "Solid")
                sublabel: L10n.tr("transparency", "Transparency")
                active: UIState.transparencyEnabled
                onClicked: UIState.toggleTransparency()
            }
            TileButton {
                width: parent.width
                icon: "󰀄"
                label: L10n.tr("avatar", "Avatar")
                sublabel: L10n.tr("choose_avatar", "Choose profile picture")
                active: false
                onClicked: helpers && helpers.openPfpPicker()
            }
        }
    }
}
