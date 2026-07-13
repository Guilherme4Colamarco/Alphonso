import QtQuick
import ".."

Item {
    id: root

    property string title: ""
    property string icon: ""
    property bool expanded: true
    property real headerHeight: Aesthetics.controlHeight
    default property alias content: contentCol.data

    height: headerHeight + (expanded ? contentCol.height : 0)
    implicitHeight: height
    clip: true

    Behavior on height {
        NumberAnimation { duration: Animations.medium; easing.type: Easing.OutExpo }
    }

    // ── Header ───────────────────────────────────────────────────────────────
    Item {
        id: header
        width: parent.width
        height: root.headerHeight

        Rectangle {
            anchors.fill: parent
            radius: Aesthetics.radius(Aesthetics.controlRadius, height)
            color: headerMa.containsMouse ? Colors.a(Colors.fg, 0.05) : "transparent"
            Behavior on color { ColorAnimation { duration: Animations.fast } }
        }

        Text {
            id: headerIcon
            anchors.left: parent.left
            anchors.leftMargin: Metrics.dp(10)
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            color: root.expanded ? Colors.accent : Colors.a(Colors.fg, 0.55)
            font { pixelSize: Metrics.sp(13); family: "JetBrainsMono Nerd Font" }
            Behavior on color { ColorAnimation { duration: Animations.fast } }
        }

        Text {
            id: headerTitle
            anchors.left: headerIcon.right
            anchors.leftMargin: Metrics.dp(8)
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            color: Colors.a(Colors.fg, 0.85)
            font { pixelSize: Metrics.sp(12); family: "JetBrainsMono Nerd Font"; bold: true }
        }

        Text {
            id: headerChevron
            anchors.right: parent.right
            anchors.rightMargin: Metrics.dp(10)
            anchors.verticalCenter: parent.verticalCenter
            text: root.expanded ? "󰅀" : "󰅂"
            color: Colors.a(Colors.fg, 0.45)
            font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font" }
            Behavior on color { ColorAnimation { duration: Animations.fast } }
        }

        MouseArea {
            id: headerMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    // ── Content column ───────────────────────────────────────────────────────
    Column {
        id: contentCol
        anchors.top: header.bottom
        anchors.topMargin: Metrics.dp(8)
        width: parent.width
        spacing: Metrics.dp(8)
    }

    // ── Bottom divider ───────────────────────────────────────────────────────
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: Metrics.dp(1)
color: Colors.a(Colors.fg, 0.06)
    }
}
