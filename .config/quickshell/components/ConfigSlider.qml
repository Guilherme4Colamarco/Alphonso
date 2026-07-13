import QtQuick
import ".."

Item {
    id: root

    property string label: ""
    property real value: 0
    property real minValue: 0
    property real maxValue: 100
    property real stepSize: 1
    property string unit: ""

    property real currentValue: root.value
    signal valueModified(real v)

    height: Metrics.dp(54)
    width: parent.width

    onValueChanged: root.currentValue = root.value

    function _snap(v) {
        if (root.stepSize <= 0) return v
        return Math.round(v / root.stepSize) * root.stepSize
    }

    function _valueFromX(x) {
        var t = Math.max(0, Math.min(1, x / trackArea.width))
        return root._snap(root.minValue + t * (root.maxValue - root.minValue))
    }

    function _format(v) {
        var rounded = Math.round(v)
        if (Math.abs(v - rounded) < 0.0001) return rounded.toString()
        return v.toFixed(2)
    }

    Text {
        id: labelText
        anchors.left: parent.left
        anchors.top: parent.top
        text: root.label
        color: Colors.a(Colors.fg, 0.8)
        font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font" }
    }

    Text {
        anchors.right: parent.right
        anchors.top: parent.top
        text: root._format(root.currentValue) + (root.unit ? " " + root.unit : "")
        color: Colors.accent
        font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font"; bold: true }
    }

    Item {
        id: trackArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: labelText.bottom
        anchors.topMargin: Metrics.dp(12)
        height: Metrics.dp(6)

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Colors.a(Colors.fg, 0.08)
        }

        Rectangle {
            width: {
                var range = root.maxValue - root.minValue
                if (range <= 0) return 0
                return Math.max(0, Math.min(parent.width,
                    parent.width * (root.currentValue - root.minValue) / range))
            }
            height: parent.height
            radius: height / 2
            color: Colors.accent
        }

        Rectangle {
            x: {
                var range = root.maxValue - root.minValue
                if (range <= 0) return 0
                return Math.max(0, Math.min(parent.width - width,
                    parent.width * (root.currentValue - root.minValue) / range))
            }
            anchors.verticalCenter: parent.verticalCenter
            width: Metrics.dp(16)
            height: Metrics.dp(16)
            radius: height / 2
            color: Colors.accent
            scale: sliderMa.containsMouse || sliderMa.pressed ? 1.2 : 1.0

            Behavior on scale {
                NumberAnimation { duration: Animations.snap; easing.type: Easing.OutBack; easing.overshoot: Animations.springPower }
            }
        }

        MouseArea {
            id: sliderMa
            anchors.fill: parent
            anchors.margins: -Metrics.dp(10)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: true

            onPressed: mouse => root.currentValue = root._valueFromX(mouse.x)
            onPositionChanged: mouse => { if (pressed) root.currentValue = root._valueFromX(mouse.x) }
            onReleased: root.valueModified(root.currentValue)
        }
    }
}
