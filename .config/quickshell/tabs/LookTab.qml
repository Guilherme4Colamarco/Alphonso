import QtQuick
import ".."

Item {
    id: root
    property var helpers
    property var animationIds: ["bubbly", "calm", "snappy", "extraslow", "none"]
    property var animationLabels: ["Elástico", "Calmo", "Rápido", "Lento", "Nenhum"]
    property var blurIds: ["frosted", "balanced", "subtle", "none"]
    property var blurLabels: ["Forte", "Equilibrado", "Suave", "Nenhum"]
    property var colorModeIds: ["auto", "adaptive-preset", "fixed-preset"]
    property var colorModeLabels: ["Automático", "Preset adaptativo", "Preset fixo"]
    property var colorPresetIds: ["catppuccin", "gruvbox", "nord", "solarized"]
    property var colorPresetLabels: ["Catppuccin", "Gruvbox", "Nord", "Solarized"]

    Flickable {
        anchors.fill: parent
        contentHeight: content.height + Metrics.dp(20)
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: content
            width: parent.width
            spacing: Metrics.dp(10)

            ConfigSection {
                title: "Skin"
                icon: "󰏘"
                expanded: true
                width: parent.width

                Grid {
                    width: parent.width
                    columns: 2
                    spacing: Metrics.dp(8)
                    Repeater {
                        model: Skins.profiles
                        SkinPreview {
                            required property var modelData
                            width: (parent.width - Metrics.dp(8)) / 2
                            profileId: modelData.id
                            onClicked: UIState.setSkinProfile(modelData.id)
                        }
                    }
                }

                TileButton {
                    width: parent.width
                    visible: UIState.skinProfile === "commonality"
                        && (UIState.colorMode !== "adaptive-preset" || UIState.colorPreset !== "solarized")
                    icon: "󰏘"
                    label: "Usar cores sugeridas"
                    sublabel: "Solarized adaptativo"
                    onClicked: {
                        UIState.setColorPreset("solarized")
                        UIState.setColorMode("adaptive-preset")
                    }
                }
            }

            ConfigSection {
                title: "Cores"
                icon: "󰏘"
                expanded: true
                width: parent.width

                ConfigSpinner {
                    label: "Fonte das cores"
                    model: root.colorModeLabels
                    currentIndex: root.colorModeIds.indexOf(UIState.colorMode)
                    onActivated: index => UIState.setColorMode(root.colorModeIds[index])
                }
                ConfigSpinner {
                    visible: UIState.colorMode !== "auto"
                    label: "Paleta"
                    model: root.colorPresetLabels
                    currentIndex: root.colorPresetIds.indexOf(UIState.colorPreset)
                    onActivated: index => UIState.setColorPreset(root.colorPresetIds[index])
                }
                Text {
                    width: parent.width
                    text: UIState.colorError !== "" ? UIState.colorError
                        : UIState.colorMode === "auto" ? "O Iris adapta toda a interface ao wallpaper."
                        : UIState.colorMode === "adaptive-preset" ? "Neutros do preset; acentos adaptados pelo Iris."
                        : "A paleta permanece fixa ao trocar o wallpaper."
                    color: UIState.colorError !== "" ? Colors.red : Colors.a(Colors.fg, 0.58)
                    wrapMode: Text.WordWrap
                    font { pixelSize: Metrics.sp(9); family: "JetBrainsMono Nerd Font" }
                }
            }

            ConfigSection {
                title: "Movimento"
                icon: "󰔡"
                expanded: true
                width: parent.width

                ConfigSpinner {
                    label: "Animações"
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
                    onClicked: helpers && helpers.openPfpPicker()
                }
            }
        }
    }
}
