import Quickshell
import Quickshell.Io
import QtQuick
import ".."

Item {
    id: root
    property var helpers
    property var monitors: []
    property var draft: []
    property int selectedIndex: 0
    property string errorMessage: ""
    property string previewToken: ""
    property int previewSeconds: 0
    property bool loading: false
    property string scriptPath: Quickshell.env("HOME") + "/.config/mango/mango_config.py"
    readonly property var selected: draft.length > selectedIndex ? draft[selectedIndex] : null
    readonly property real layoutScale: {
        var maxEdge = 1
        for (var i = 0; i < draft.length; i++)
            maxEdge = Math.max(maxEdge, Number(draft[i].x) + Number(draft[i].width) / Number(draft[i].scale || 1))
        return Math.min(0.16, (arrangementCanvas.width - Metrics.dp(40)) / maxEdge)
    }

    function clone(value) { return JSON.parse(JSON.stringify(value)) }

    function loadMonitors() {
        loading = true
        errorMessage = ""
        probeProc.running = false
        probeProc.running = true
    }

    function updateSelected(key, value) {
        if (!selected) return
        var next = clone(draft)
        next[selectedIndex][key] = value
        draft = next
    }

    function moveMonitor(index, px, py) {
        var next = clone(draft)
        next[index].x = Math.max(0, Math.round((px - Metrics.dp(20)) / layoutScale))
        next[index].y = Math.max(0, Math.round((py - Metrics.dp(20)) / layoutScale))
        var minX = Math.min.apply(null, next.map(item => Number(item.x)))
        var minY = Math.min.apply(null, next.map(item => Number(item.y)))
        for (var i = 0; i < next.length; i++) {
            next[i].x -= minX
            next[i].y -= minY
        }
        draft = next
    }

    function resolutionModel() {
        if (!selected) return []
        var result = []
        for (var i = 0; i < selected.modes.length; i++) {
            var label = selected.modes[i].width + " × " + selected.modes[i].height
            if (result.indexOf(label) < 0) result.push(label)
        }
        return result
    }

    function refreshModel() {
        if (!selected) return []
        var result = []
        for (var i = 0; i < selected.modes.length; i++) {
            var mode = selected.modes[i]
            if (Number(mode.width) === Number(selected.width) && Number(mode.height) === Number(selected.height))
                result.push(Number(mode.refresh).toFixed(2) + " Hz")
        }
        return result
    }

    function applyPreview() {
        if (draft.length === 0 || previewToken !== "") return
        errorMessage = ""
        previewProc.command = ["python3", scriptPath, "preview-monitors", JSON.stringify(draft)]
        previewProc.running = true
    }

    function confirmPreview() {
        if (previewToken === "") return
        confirmProc.command = ["python3", scriptPath, "confirm-monitor-preview", previewToken]
        confirmProc.running = true
    }

    function revertPreview() {
        if (previewToken === "") return
        revertProc.command = ["python3", scriptPath, "revert-monitor-preview", previewToken]
        revertProc.running = true
    }

    onVisibleChanged: if (visible) loadMonitors()

    Process {
        id: probeProc
        command: ["python3", root.scriptPath, "probe-monitors"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                try {
                    var response = JSON.parse(data)
                    if (!response.ok) throw new Error(response.error)
                    root.monitors = response.monitors
                    root.draft = root.clone(response.monitors)
                    root.selectedIndex = Math.min(root.selectedIndex, Math.max(0, root.draft.length - 1))
                } catch (error) { root.errorMessage = String(error) }
            }
        }
        onExited: code => root.loading = false
    }

    Process {
        id: previewProc
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                try {
                    var response = JSON.parse(data)
                    if (!response.ok) throw new Error(response.error)
                    root.previewToken = response.token
                    root.previewSeconds = response.timeout
                    previewTimer.start()
                } catch (error) { root.errorMessage = String(error) }
            }
        }
    }
    Process {
        id: confirmProc
        stdout: SplitParser { splitMarker: ""; onRead: data => {
            var response = JSON.parse(data)
            if (response.ok) { root.previewToken = ""; previewTimer.stop(); root.loadMonitors() }
            else root.errorMessage = response.error
        }}
    }
    Process {
        id: revertProc
        stdout: SplitParser { splitMarker: ""; onRead: data => {
            var response = JSON.parse(data)
            root.previewToken = ""
            previewTimer.stop()
            if (!response.ok) root.errorMessage = response.error
            root.loadMonitors()
        }}
    }
    Timer {
        id: previewTimer
        interval: 1000
        repeat: true
        onTriggered: {
            root.previewSeconds--
            if (root.previewSeconds <= 0) {
                stop()
                root.previewToken = ""
                root.loadMonitors()
            }
        }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: page.implicitHeight + Metrics.dp(24)
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: page
            width: parent.width
            spacing: Metrics.dp(16)

            Text {
                visible: root.errorMessage !== "" || root.loading
                width: parent.width
                text: root.loading ? "Detectando monitores…" : root.errorMessage
                color: root.errorMessage !== "" ? Colors.red : Colors.accent
                wrapMode: Text.WordWrap
                font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font" }
            }

            Rectangle {
                id: arrangementCanvas
                width: parent.width
                height: Metrics.dp(230)
                radius: Metrics.dp(UIState.borderRadius * 0.75)
                color: Colors.a(Colors.bg, 0.35)
                border.width: 1
                border.color: Colors.a(Colors.fg, 0.09)
                clip: true

                Text {
                    anchors.centerIn: parent
                    visible: root.draft.length === 0 && !root.loading
                    text: "Nenhum monitor detectado"
                    color: Colors.a(Colors.fg, 0.5)
                    font { pixelSize: Metrics.sp(12); family: "JetBrainsMono Nerd Font" }
                }

                Repeater {
                    model: root.draft
                    Rectangle {
                        id: monitorCard
                        required property int index
                        required property var modelData
                        x: Metrics.dp(20) + Number(modelData.x) * root.layoutScale
                        y: Metrics.dp(20) + Number(modelData.y) * root.layoutScale
                        width: Math.max(Metrics.dp(120), Number(modelData.width) / Number(modelData.scale || 1) * root.layoutScale)
                        height: Math.max(Metrics.dp(72), Number(modelData.height) / Number(modelData.scale || 1) * root.layoutScale)
                        radius: Metrics.dp(8)
                        color: root.selectedIndex === index ? Colors.a(Colors.accent, 0.28) : Colors.a(Colors.surface, 0.9)
                        border.width: root.selectedIndex === index ? 2 : 1
                        border.color: root.selectedIndex === index ? Colors.accent : Colors.a(Colors.fg, 0.18)
                        Drag.active: dragArea.drag.active
                        Drag.hotSpot.x: width / 2
                        Drag.hotSpot.y: height / 2

                        Column {
                            anchors.centerIn: parent
                            spacing: Metrics.dp(4)
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: index + 1; color: Colors.fg; font { pixelSize: Metrics.sp(18); family: "JetBrainsMono Nerd Font"; bold: true } }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.name; color: Colors.a(Colors.fg, 0.7); font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font" } }
                        }
                        MouseArea {
                            id: dragArea
                            anchors.fill: parent
                            drag.target: monitorCard
                            drag.minimumX: 0; drag.minimumY: 0
                            drag.maximumX: arrangementCanvas.width - monitorCard.width
                            drag.maximumY: arrangementCanvas.height - monitorCard.height
                            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            onPressed: root.selectedIndex = index
                            onReleased: root.moveMonitor(index, monitorCard.x, monitorCard.y)
                        }
                    }
                }
            }

            Text {
                visible: root.selected !== null
                text: root.selected ? root.selected.description : ""
                color: Colors.fg
                font { pixelSize: Metrics.sp(14); family: "JetBrainsMono Nerd Font"; bold: true }
            }

            ConfigSection {
                visible: root.selected !== null
                title: "Configuração"
                icon: "󰍹"
                expanded: true
                width: parent.width

                ConfigSpinner {
                    label: "Resolução"
                    model: root.resolutionModel()
                    currentIndex: Math.max(0, model.indexOf(root.selected ? root.selected.width + " × " + root.selected.height : ""))
                    onActivated: index => {
                        var parts = model[index].split(" × ")
                        root.updateSelected("width", Number(parts[0]))
                        root.updateSelected("height", Number(parts[1]))
                    }
                }
                ConfigSpinner {
                    label: "Taxa de atualização"
                    model: root.refreshModel()
                    currentIndex: {
                        if (!root.selected) return 0
                        var target = Number(root.selected.refresh).toFixed(2) + " Hz"
                        return Math.max(0, model.indexOf(target))
                    }
                    onActivated: index => root.updateSelected("refresh", Number(model[index].replace(" Hz", "")))
                }
                ConfigSpinner {
                    label: "Escala"
                    model: ["100%", "125%", "150%", "175%", "200%"]
                    currentIndex: Math.max(0, model.indexOf(Math.round(Number(root.selected ? root.selected.scale : 1) * 100) + "%"))
                    onActivated: index => root.updateSelected("scale", Number(model[index].replace("%", "")) / 100)
                }
                ConfigSpinner {
                    label: "Orientação"
                    model: UIState.advancedMonitorParameters
                        ? ["Normal", "90°", "180°", "270°", "Flip", "Flip 90°", "Flip 180°", "Flip 270°"]
                        : ["Normal", "90°", "180°", "270°"]
                    currentIndex: Math.min(model.length - 1, Number(root.selected ? root.selected.rr : 0))
                    onActivated: index => root.updateSelected("rr", index)
                }
                ConfigToggle {
                    label: "Taxa de atualização variável (VRR)"
                    checked: root.selected ? Number(root.selected.vrr) === 1 : false
                    onToggled: checked => root.updateSelected("vrr", checked ? 1 : 0)
                }
            }

            ConfigSection {
                visible: root.selected !== null
                title: "Parâmetros complexos"
                icon: "󰒓"
                expanded: true
                width: parent.width

                ConfigToggle {
                    label: "Parâmetros complexos"
                    checked: UIState.advancedMonitorParameters
                    onToggled: checked => UIState.setAdvancedMonitorParameters(checked)
                }
                ConfigToggle {
                    visible: UIState.advancedMonitorParameters
                    label: "Modo personalizado (pode apagar a tela)"
                    checked: root.selected ? Number(root.selected.custom) === 1 : false
                    onToggled: checked => root.updateSelected("custom", checked ? 1 : 0)
                }
                ConfigToggle {
                    visible: UIState.advancedMonitorParameters
                    label: "Identificar por fabricante, modelo e serial"
                    checked: root.selected ? Boolean(root.selected.match_by_identity) : false
                    onToggled: checked => root.updateSelected("match_by_identity", checked)
                }
                Text {
                    visible: UIState.advancedMonitorParameters && root.selected !== null
                    width: parent.width
                    text: root.selected ? "make=" + root.selected.make + "  model=" + root.selected.model + "  serial=" + root.selected.serial : ""
                    color: Colors.a(Colors.fg, 0.5)
                    wrapMode: Text.WrapAnywhere
                    font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font" }
                }
            }

            Row {
                anchors.right: parent.right
                spacing: Metrics.dp(10)
                Rectangle {
                    visible: root.previewToken !== ""
                    width: keepText.implicitWidth + Metrics.dp(28); height: Metrics.controlHeight
                    radius: Metrics.dp(8); color: Colors.a(Colors.green, 0.2)
                    Text { id: keepText; anchors.centerIn: parent; text: "Manter alterações (" + root.previewSeconds + ")"; color: Colors.green; font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font"; bold: true } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.confirmPreview() }
                }
                Rectangle {
                    visible: root.previewToken !== ""
                    width: revertText.implicitWidth + Metrics.dp(28); height: Metrics.controlHeight
                    radius: Metrics.dp(8); color: Colors.a(Colors.red, 0.15)
                    Text { id: revertText; anchors.centerIn: parent; text: "Reverter"; color: Colors.red; font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font"; bold: true } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.revertPreview() }
                }
                Rectangle {
                    visible: root.previewToken === ""
                    width: applyText.implicitWidth + Metrics.dp(32); height: Metrics.controlHeight
                    radius: Metrics.dp(8); color: Colors.accent
                    Text { id: applyText; anchors.centerIn: parent; text: "Aplicar"; color: Colors.bg; font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font"; bold: true } }
                    MouseArea { anchors.fill: parent; enabled: root.draft.length > 0; cursorShape: Qt.PointingHandCursor; onClicked: root.applyPreview() }
                }
            }
        }
    }
}
