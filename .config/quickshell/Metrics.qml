pragma Singleton
import QtQuick

QtObject {
    readonly property real scale: Math.max(0.8, Math.min(2.0, UIState.uiScale))
    readonly property int touchTarget: dp(40)
    readonly property int controlHeight: dp(44)
    readonly property int rowHeight: dp(52)
    readonly property int smallGap: dp(8)
    readonly property int gap: dp(12)
    readonly property int largeGap: dp(20)
    readonly property int pageMargin: dp(24)

    function dp(value) { return Math.round(Number(value) * scale) }
    function sp(value) { return Math.max(1, Number(value) * scale) }
}
