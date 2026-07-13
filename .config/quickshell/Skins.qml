pragma Singleton
import QtQuick

QtObject {
    readonly property var profiles: [
        { id: "kamalen", label: "Kamalen", icon: "󰌪", description: "Leve, arredondado e translúcido", recommendedMode: "auto", recommendedPreset: "catppuccin" },
        { id: "commonality", label: "Commonality", icon: "󰇀", description: "CDE/Motif compacto, físico e modular", recommendedMode: "adaptive-preset", recommendedPreset: "solarized" }
    ]

    readonly property var _recipes: ({
        "kamalen": {
            containerRadius: 20, cardRadius: 16, controlRadius: 999, buttonRadius: 999, fieldRadius: 999,
            sliderTrackHeight: 8, sliderThumbSize: 18, sliderThumbWidth: 18, progressHeight: 8,
            switchWidth: 44, switchHeight: 24, switchThumbSize: 18, controlHeight: 44, rowHeight: 52,
            borderWidth: 0, bevelWidth: 0, gap: 8, textureSource: "", textureOpacity: 0, mangoRadius: 16
        },
        "commonality": {
            containerRadius: 0, cardRadius: 0, controlRadius: 0, buttonRadius: 0, fieldRadius: 0,
            sliderTrackHeight: 8, sliderThumbSize: 18, sliderThumbWidth: 12, progressHeight: 8,
            switchWidth: 42, switchHeight: 24, switchThumbSize: 16, controlHeight: 40, rowHeight: 44,
            borderWidth: 1, bevelWidth: 2, gap: 6,
            textureSource: Qt.resolvedUrl("assets/materials/commonality-grid.svg"), textureOpacity: 0.09, mangoRadius: 0
        }
    })

    function recipe(id) { return _recipes[id] || _recipes.kamalen }
    function profile(id) {
        for (var i = 0; i < profiles.length; i++) if (profiles[i].id === id) return profiles[i]
        return profiles[0]
    }
    function valid(id) { return _recipes[id] !== undefined }
    function radius(value, height) { return Math.min(value, height / 2) }
    function mix(a, b, amount) {
        var t = Math.max(0, Math.min(1, amount))
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t)
    }
    function roleBase(role, active) {
        if (role === "background") return Colors.bg
        if (role === "sunken") return mix(Colors.bg, Colors.surface, 0.42)
        if (role === "accent") return Colors.accent
        if (role === "separator") return Colors.dim
        if (role === "control") return active ? mix(Colors.surface, Colors.accent, 0.34) : Colors.surface
        if (role === "raised") return active ? mix(Colors.surface, Colors.accent, 0.24) : Colors.surface
        return Colors.surface
    }
    function materialTop(role, pressed, active) {
        var base = roleBase(role, active)
        if (currentId !== "commonality") return base
        return pressed ? mix(base, Colors.bg, 0.16) : mix(base, Colors.fg, 0.13)
    }
    function materialBottom(role, pressed, active) {
        var base = roleBase(role, active)
        if (currentId !== "commonality") return base
        return pressed ? mix(base, Colors.fg, 0.13) : mix(base, Colors.bg, 0.18)
    }
    function bevelLight(pressed) { return pressed ? mix(Colors.bg, Colors.dim, 0.35) : mix(Colors.fg, Colors.surface, 0.38) }
    function bevelDark(pressed) { return pressed ? mix(Colors.fg, Colors.surface, 0.38) : mix(Colors.bg, Colors.dim, 0.35) }

    readonly property string currentId: UIState.skinProfile
    readonly property var current: recipe(currentId)
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
    readonly property real bevelWidth: Metrics.dp(current.bevelWidth)
    readonly property real gap: Metrics.dp(current.gap)
    readonly property url textureSource: current.textureSource
    readonly property real textureOpacity: current.textureOpacity
    readonly property int mangoRadius: current.mangoRadius
}
