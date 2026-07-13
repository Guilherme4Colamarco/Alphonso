pragma Singleton
import QtQuick

QtObject {
    readonly property var profiles: [
        { id: "tui-style", label: "TUI Style", icon: "󰆍", description: "Reto, compacto e preciso" },
        { id: "pills", label: "Pills", icon: "󰪶", description: "Cápsulas macias e elásticas" },
        { id: "gnome-like", label: "GNOME-like", icon: "󰊬", description: "Sóbrio, espaçoso e familiar" }
    ]

    readonly property var _tokens: ({
        "tui-style": { containerRadius: 0, cardRadius: 0, controlRadius: 0, buttonRadius: 0, fieldRadius: 0,
            sliderTrackHeight: 4, sliderThumbSize: 16, sliderThumbWidth: 8, progressHeight: 4,
            switchWidth: 36, switchHeight: 20, switchThumbSize: 14, controlHeight: 40, rowHeight: 42,
            borderWidth: 1, gap: 6 },
        "pills": { containerRadius: 20, cardRadius: 16, controlRadius: 999, buttonRadius: 999, fieldRadius: 999,
            sliderTrackHeight: 8, sliderThumbSize: 18, sliderThumbWidth: 18, progressHeight: 8,
            switchWidth: 44, switchHeight: 24, switchThumbSize: 18, controlHeight: 44, rowHeight: 52,
            borderWidth: 0, gap: 8 },
        "gnome-like": { containerRadius: 12, cardRadius: 12, controlRadius: 8, buttonRadius: 8, fieldRadius: 8,
            sliderTrackHeight: 6, sliderThumbSize: 18, sliderThumbWidth: 18, progressHeight: 6,
            switchWidth: 44, switchHeight: 24, switchThumbSize: 18, controlHeight: 44, rowHeight: 52,
            borderWidth: 1, gap: 8 }
    })

    function tokensFor(id) { return _tokens[id] || _tokens.pills }
    function profile(id) {
        for (var i = 0; i < profiles.length; i++) if (profiles[i].id === id) return profiles[i]
        return profiles[1]
    }
    function radius(value, height) { return Math.min(value, height / 2) }

    readonly property var current: tokensFor(UIState.aestheticProfile)
    readonly property real containerRadius: Metrics.dp(current.containerRadius)
    readonly property real cardRadius: Metrics.dp(current.cardRadius)
    readonly property real controlRadius: Metrics.dp(current.controlRadius)
    readonly property real buttonRadius: Metrics.dp(current.buttonRadius)
    readonly property real fieldRadius: Metrics.dp(current.fieldRadius)
    readonly property real sliderTrackHeight: Metrics.dp(current.sliderTrackHeight)
    readonly property real sliderThumbSize: Metrics.dp(current.sliderThumbSize)
    readonly property real sliderThumbWidth: Metrics.dp(current.sliderThumbWidth)
    readonly property real progressHeight: Metrics.dp(current.progressHeight)
    readonly property real switchWidth: Metrics.dp(current.switchWidth)
    readonly property real switchHeight: Metrics.dp(current.switchHeight)
    readonly property real switchThumbSize: Metrics.dp(current.switchThumbSize)
    readonly property real controlHeight: Metrics.dp(current.controlHeight)
    readonly property real rowHeight: Metrics.dp(current.rowHeight)
    readonly property real borderWidth: Metrics.dp(current.borderWidth)
    readonly property real gap: Metrics.dp(current.gap)
}
