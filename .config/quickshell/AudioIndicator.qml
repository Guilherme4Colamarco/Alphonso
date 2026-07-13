import QtQuick

// Waveform de barras animadas estilo CAVA para indicar reproducao de audio.
// Exibido na bandeja da ilha quando musica esta tocando.
Item {
    id: root

    property bool active: false
    property bool playing: false
    property bool dismissed: false
    property color barColor: Colors.accent
    property color backgroundColor: Colors.bg
    property color borderColor: a(Colors.accent, 0.15)
    readonly property bool showing: active && !dismissed
    readonly property bool animating: showing && playing
    readonly property var cavaIndices: [1, 5, 9]

    function a(c, o) { return Qt.rgba(c.r, c.g, c.b, o) }

    signal clicked

    width: chip.width
    height: chip.height
    opacity: showing ? 1 : 0
    visible: opacity > 0
    scale: showing ? 1 : 0.7

    Rectangle {
        id: chip

        width: Metrics.dp(18)
height: Metrics.dp(18)
radius: height / 2
        color: chipMouse.containsMouse ? a(Colors.accent, 0.10) : root.backgroundColor
        border.width: 1
        border.color: chipMouse.containsMouse ? a(Colors.accent, 0.35) : root.borderColor

        Row {
            anchors.centerIn: parent
            spacing: Metrics.dp(1)
            Repeater {
                model: 3

                Rectangle {
                    id: bar

                    width: Metrics.dp(2)
height: root.animating ? Math.max(3, 3 + UIState.cava[root.cavaIndices[index]] * 7) : 3
                    radius: Metrics.dp(1)
color: root.barColor
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on height {
                        NumberAnimation { duration: 50; easing.type: Easing.OutQuad }
                    }
                }
            }
        }

        MouseArea {
            id: chipMouse

            anchors.fill: parent
            anchors.margins: Metrics.dp(-4)
hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.dismissed = true;
                root.clicked();
            }
        }
    }

    Behavior on opacity {
        NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic }
    }

    Behavior on scale {
        NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic }
    }
}
