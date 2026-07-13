// PopupBase — base component for bar-anchored popup windows
// State machine: "closed" → "open" → "closing" → "closed"
// Children are placed directly inside the inner panel via default property.
//
// Inspired by meloworld-dotfiles' PopupBase, adapted to Kamalen's
// Colors / Animations / UIState singletons and bubbly aesthetic.
//
// Usage:
//   PopupBase {
//       implicitWidth: 240
//       contentHeight: myCol.implicitHeight
//       Connections { target: MyState; function onFlagChanged() { animState = flag ? "open" : "closing" } }
//       Column { id: myCol; ... }
//   }
import Quickshell
import Quickshell._Window
import QtQuick

PopupWindow {
    id: root

    property string animState: "closed"
    property color borderColor: Qt.rgba(Colors.fg.r, Colors.fg.g, Colors.fg.b, 0.08)
    property bool clipContent: true
    property int contentHeight: 0
    property int padding: 12
    property bool autoDismiss: true
    property int autoDismissDelay: 3000
    property bool showBorder: true

    default property alias panelContent: innerRect.data

    visible: animState !== "closed"
    implicitHeight: Metrics.dp(800)
color: "transparent"
    grabFocus: true
    mask: Region { item: innerRect }

    MaterialSurface {
        id: innerRect
        width: parent.width
        height: root.contentHeight + (root.padding * 2)
        role: "background"
        fillOpacity: UIState.transparencyEnabled ? 0.92 : 1.0
        materialEnabled: root.showBorder
        clip: root.clipContent

        Behavior on height {
            SmoothedAnimation { velocity: 800; easing.type: Easing.OutExpo }
        }

        y: 0
        opacity: 1.0
        scale: 1.0

        states: [
            State {
                name: "open"
                when: root.animState === "open"
                PropertyChanges { target: innerRect; y: 0; opacity: 1.0; scale: 1.0 }
            },
            State {
                name: "closing"
                when: root.animState === "closing"
                PropertyChanges { target: innerRect; y: -16; opacity: 0.0; scale: Animations.enterScale }
            }
        ]

        transitions: [
            Transition {
                to: "open"
                SequentialAnimation {
                    PropertyAction { target: innerRect; property: "y"; value: -16 }
                    PropertyAction { target: innerRect; property: "opacity"; value: 0.0 }
                    PropertyAction { target: innerRect; property: "scale"; value: Animations.enterScale }
                    ParallelAnimation {
                        NumberAnimation { target: innerRect; property: "y"; to: 0; duration: Animations.medium; easing.type: Easing.OutBack; easing.overshoot: Animations.springPower }
                        NumberAnimation { target: innerRect; property: "opacity"; to: 1.0; duration: Animations.fast; easing.type: Easing.OutCubic }
                        NumberAnimation { target: innerRect; property: "scale"; to: 1.0; duration: Animations.medium; easing.type: Easing.OutBack; easing.overshoot: Animations.springPower }
                    }
                }
            },
            Transition {
                to: "closing"
                SequentialAnimation {
                    ParallelAnimation {
                        NumberAnimation { target: innerRect; property: "y"; to: -16; duration: Animations.fast; easing.type: Easing.InCubic }
                        NumberAnimation { target: innerRect; property: "opacity"; to: 0.0; duration: Animations.snap; easing.type: Easing.InCubic }
                        NumberAnimation { target: innerRect; property: "scale"; to: Animations.enterScale; duration: Animations.fast; easing.type: Easing.InCubic }
                    }
                    ScriptAction { script: root.animState = "closed" }
                }
            }
        ]

        HoverHandler { id: hover }

        Timer {
            interval: root.autoDismissDelay
            running: root.animState === "open" && !hover.hovered && root.autoDismiss
            onTriggered: root.animState = "closing"
        }
    }

    function open()  { animState = "open" }
    function close() { animState = "closing" }
}
