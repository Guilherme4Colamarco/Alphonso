import Quickshell
import Quickshell.Io
import QtQuick
import QtMultimedia
import QtQuick.Controls

FocusScope {
    id: root

    required property var screen
    required property string scriptPath
    required property string wallpaperDir
    property bool active: false
    property bool ready: false
    property real panelWidth: 860
    property real panelHeight: 538
    property int targetWidth: screen ? screen.width : 1920
    property int targetHeight: screen ? screen.height : 1080

    property bool loading: false
    property bool noResults: false
    property string errorMessage: ""
    property string listingMode: ""
    property string lastQuery: ""
    property int selectedIndex: 0
    property int nextPage: 1
    property bool hasMore: false
    property int totalResults: 0
    property var previewItem: null
    property bool previewOpen: false
    property string activeDownloadId: ""
    property int downloadPercent: 0
    property string downloadState: "idle"
    property string downloadMessage: ""

    signal downloaded(string path)
    signal tabRequested(string tab)

    readonly property real br: UIState.borderRadius
    readonly property real brCard: Math.round(br * 0.75)
    readonly property real brSm: Math.round(br * 0.625)

    visible: active
    focus: active

    function a(color, opacity) {
        return Colors.a(color, opacity)
    }

    function activate() {
        forceActiveFocus()
        if (liveModel.count === 0 && !liveSearchProc.running)
            runLiveListing("featured", "", 1)
    }

    function runLiveListing(mode, query, page) {
        if (liveSearchProc.running) return
        var cleanQuery = query.trim()
        if (mode === "search" && cleanQuery.length === 0) return

        listingMode = mode
        lastQuery = cleanQuery
        errorMessage = ""
        noResults = false
        loading = true
        if (page === 1 || mode === "random") {
            previewOpen = false
            previewItem = null
        }
        liveSearchProc.run(mode, cleanQuery, page)
    }

    function selectLiveItem(index) {
        if (index < 0 || index >= liveModel.count) return
        var item = liveModel.get(index)
        selectedIndex = index
        previewItem = {
            id: item.id,
            title: item.title,
            author: item.author,
            author_url: item.author_url,
            source_url: item.source_url,
            thumbnail: item.thumbnail,
            download_url: item.download_url,
            resolution: item.resolution,
            width: item.videoWidth,
            height: item.videoHeight,
            fps: item.fps,
            duration: item.duration,
            mime: item.mime,
            license: item.license,
            license_url: item.license_url,
            attribution: item.attribution,
            ext: item.ext
        }
        previewOpen = true
    }

    function startLiveDownload(item) {
        if (!item || activeDownloadId !== "") return
        activeDownloadId = item.id
        downloadPercent = 0
        downloadState = "downloading"
        downloadMessage = L10n.tr("live_downloading", "Downloading live wallpaper")
        previewOpen = false
        liveDownloadProc.command = [
            "python3", scriptPath, "download",
            "--url", item.download_url,
            "--id", item.id,
            "--width", String(item.width),
            "--height", String(item.height),
            "--ext", item.ext,
            "--out-dir", wallpaperDir
        ]
        liveDownloadProc.running = true
    }

    function openSource(url) {
        if (!url || !url.startsWith("https://")) return
        openSourceProc.command = ["xdg-open", url]
        openSourceProc.running = true
    }

    onActiveChanged: {
        if (active) activate()
        else {
            previewOpen = false
            liveSearchInput.focus = false
        }
    }

    Keys.onPressed: function(event) {
        if (!active || liveSearchInput.activeFocus) return
        if (previewOpen) {
            if (event.key === Qt.Key_Escape) previewOpen = false
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) startLiveDownload(previewItem)
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Slash) {
            liveSearchInput.forceActiveFocus()
        } else if (event.key === Qt.Key_R) {
            runLiveListing("random", "", 1)
        } else if (event.key === Qt.Key_P) {
            runLiveListing("featured", "", 1)
        } else if (event.key === Qt.Key_Tab) {
            tabRequested("local")
        } else if (event.key === Qt.Key_H || event.key === Qt.Key_Left) {
            if (selectedIndex > 0) selectedIndex--
            liveGrid.positionViewAtIndex(selectedIndex, GridView.Contain)
        } else if (event.key === Qt.Key_L || event.key === Qt.Key_Right) {
            if (selectedIndex < liveModel.count - 1) selectedIndex++
            liveGrid.positionViewAtIndex(selectedIndex, GridView.Contain)
        } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
            selectedIndex = Math.max(0, selectedIndex - 3)
            liveGrid.positionViewAtIndex(selectedIndex, GridView.Contain)
        } else if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
            selectedIndex = Math.min(liveModel.count - 1, selectedIndex + 3)
            liveGrid.positionViewAtIndex(selectedIndex, GridView.Contain)
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (liveModel.count > 0) selectLiveItem(selectedIndex)
        } else if (event.key === Qt.Key_Escape) {
            if (liveModel.count > 0) {
                liveModel.clear()
                totalResults = 0
                listingMode = ""
            } else {
                UIState.closeDropdowns()
            }
        } else {
            return
        }
        event.accepted = true
    }

    ListModel { id: liveModel }

    Process {
        id: liveSearchProc
        property int requestedPage: 1
        function run(mode, query, page) {
            var commandName = mode === "search" ? "search" : mode
            requestedPage = page
            command = [
                "python3", root.scriptPath, commandName,
                "--page", String(page),
                "--per-page", "24"
            ]
            if (mode === "search") command.push("--query", query)
            running = true
        }
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                try {
                    var response = JSON.parse(data.trim())
                    if (response.error) {
                        root.errorMessage = response.error
                        if (liveSearchProc.requestedPage === 1) liveModel.clear()
                        return
                    }
                    if (liveSearchProc.requestedPage === 1 || root.listingMode === "random") {
                        liveModel.clear()
                        root.selectedIndex = 0
                    }
                    var results = response.results || []
                    root.noResults = root.listingMode === "search"
                        && liveSearchProc.requestedPage === 1 && results.length === 0
                    for (var index = 0; index < results.length; index++) {
                        var item = results[index]
                        liveModel.append({
                            id: item.id,
                            title: item.title,
                            author: item.author,
                            author_url: item.author_url,
                            source_url: item.source_url,
                            thumbnail: item.thumbnail,
                            download_url: item.download_url,
                            resolution: item.resolution,
                            videoWidth: item.width,
                            videoHeight: item.height,
                            fps: item.fps,
                            duration: item.duration,
                            mime: item.mime,
                            license: item.license,
                            license_url: item.license_url,
                            attribution: item.attribution,
                            ext: item.ext
                        })
                    }
                    root.totalResults = response.total || results.length
                    root.nextPage = response.next_page === null ? 1 : (response.next_page || 1)
                    root.hasMore = response.has_more === true
                } catch (error) {
                    root.errorMessage = L10n.tr("live_invalid_response", "Invalid response from DesktopHut")
                }
            }
        }
        onExited: {
            root.loading = false
            liveGrid.loadingMore = false
        }
    }

    Process {
        id: liveDownloadProc
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (line.startsWith("PROGRESS:")) {
                    var parts = line.split(":")
                    root.downloadPercent = parseInt(parts[1]) || 0
                } else if (line.startsWith("SUCCESS:")) {
                    root.activeDownloadId = ""
                    root.downloadPercent = 100
                    root.downloadState = "success"
                    root.downloadMessage = L10n.tr("live_download_applied", "Live wallpaper downloaded and applied")
                    root.downloaded(line.substring(8))
                    downloadStatusTimer.restart()
                } else if (line.startsWith("ERROR:")) {
                    root.activeDownloadId = ""
                    root.downloadState = "error"
                    root.downloadMessage = L10n.tr("live_download_failed", "Live wallpaper download failed")
                    downloadStatusTimer.restart()
                }
            }
        }
    }

    Process { id: openSourceProc }

    Timer {
        id: downloadStatusTimer
        interval: 4500
        onTriggered: {
            root.downloadState = "idle"
            root.downloadMessage = ""
        }
    }

    Rectangle {
        id: liveToolbar
        anchors {
            top: parent.top
            topMargin: 104
            horizontalCenter: parent.horizontalCenter
        }
        width: root.panelWidth
        height: Metrics.dp(52)
radius: root.brCard
        color: root.a(Colors.bg, UIState.transparencyEnabled ? 0.72 : 0.94)
        border.width: 1
        border.color: root.a(Colors.fg, 0.08)

        Row {
            anchors.fill: parent
            anchors.margins: Metrics.dp(7)
spacing: Metrics.dp(8)
            Rectangle {
                width: parent.width - featuredButton.width - randomButton.width - resultCount.width - 24
                height: parent.height
                radius: root.brSm
                color: liveSearchInput.activeFocus ? root.a(Colors.fg, 0.08) : root.a(Colors.fg, 0.035)
                border.width: 1
                border.color: liveSearchInput.activeFocus ? root.a(Colors.accent, 0.65) : root.a(Colors.fg, 0.08)

                TextInput {
                    id: liveSearchInput
                    anchors.fill: parent
                    anchors.leftMargin: Metrics.dp(36)
anchors.rightMargin: Metrics.dp(12)
verticalAlignment: TextInput.AlignVCenter
                    color: Colors.fg
                    font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font" }
                    selectByMouse: true
                    clip: true
                    onAccepted: {
                        root.runLiveListing("search", text, 1)
                        root.forceActiveFocus()
                    }
                    Keys.onEscapePressed: root.forceActiveFocus()
                }

                Text {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    text: "󰍉"
                    color: liveSearchInput.activeFocus ? Colors.accent : root.a(Colors.fg, 0.45)
                    font { pixelSize: Metrics.sp(13); family: "JetBrainsMono Nerd Font" }
                }

                Text {
                    anchors { left: parent.left; leftMargin: 36; verticalCenter: parent.verticalCenter }
                    visible: liveSearchInput.text.length === 0
                    text: L10n.tr("live_search_placeholder", "Search live wallpapers…")
                    color: root.a(Colors.fg, 0.35)
                    font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font" }
                }
            }

            Rectangle {
                id: featuredButton
                width: Metrics.dp(104)
height: parent.height
                radius: root.brSm
                color: featuredMa.containsMouse || root.listingMode === "featured"
                    ? root.a(Colors.accent, 0.18) : root.a(Colors.fg, 0.045)
                border.width: 1
                border.color: root.listingMode === "featured" ? root.a(Colors.accent, 0.65) : root.a(Colors.fg, 0.09)

                Text {
                    anchors.centerIn: parent
                    text: "󰐕  " + L10n.tr("live_featured", "Featured")
                    color: root.listingMode === "featured" ? Colors.accent : root.a(Colors.fg, 0.65)
                    font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font"; bold: true }
                }
                MouseArea {
                    id: featuredMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.runLiveListing("featured", "", 1)
                }
            }

            Rectangle {
                id: randomButton
                width: Metrics.dp(104)
height: parent.height
                radius: root.brSm
                color: randomMa.containsMouse || root.listingMode === "random"
                    ? root.a(Colors.accent, 0.18) : root.a(Colors.fg, 0.045)
                border.width: 1
                border.color: root.listingMode === "random" ? root.a(Colors.accent, 0.65) : root.a(Colors.fg, 0.09)

                Text {
                    anchors.centerIn: parent
                    text: "󰇊  " + L10n.tr("wallhaven_random", "Random")
                    color: root.listingMode === "random" ? Colors.accent : root.a(Colors.fg, 0.65)
                    font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font"; bold: true }
                }
                MouseArea {
                    id: randomMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.runLiveListing("random", "", 1)
                }
            }

            Item {
                id: resultCount
                width: Metrics.dp(76)
height: parent.height
                Column {
                    anchors.centerIn: parent
                    spacing: Metrics.dp(1)
Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.totalResults > 0 ? root.totalResults.toLocaleString(Qt.locale()) : "—"
                        color: root.totalResults > 0 ? Colors.fg : root.a(Colors.fg, 0.35)
                        font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font"; bold: true }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: L10n.tr("wallhaven_results", "results")
                        color: root.a(Colors.fg, 0.35)
                        font { pixelSize: Metrics.sp(8); family: "JetBrainsMono Nerd Font" }
                    }
                }
            }
        }
    }

    GridView {
        id: liveGrid
        property bool loadingMore: false
        anchors {
            top: liveToolbar.bottom
            topMargin: 16
            bottom: parent.bottom
            bottomMargin: 64
            horizontalCenter: parent.horizontalCenter
        }
        width: root.panelWidth
        cellWidth: width / 3
        cellHeight: cellWidth / 1.55
        clip: true
        model: liveModel
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        onContentYChanged: {
            if (contentHeight <= 0 || listingMode === "random") return
            var nearBottom = contentY + height >= contentHeight - 180
            if (nearBottom && !loadingMore && !root.loading && root.hasMore) {
                loadingMore = true
                root.runLiveListing(root.listingMode, root.lastQuery, root.nextPage)
            }
        }

        delegate: Rectangle {
            id: liveCard
            required property string id
            required property string title
            required property string author
            required property string author_url
            required property string source_url
            required property string thumbnail
            required property string download_url
            required property string resolution
            required property int videoWidth
            required property int videoHeight
            required property real fps
            required property real duration
            required property string mime
            required property string license
            required property string license_url
            required property string attribution
            required property string ext
            required property int index

            width: liveGrid.cellWidth - 12
            height: liveGrid.cellHeight - 10
            radius: root.brCard
            color: root.a(Colors.bg, 0.55)
            clip: true
            border.width: root.selectedIndex === index ? 2 : 0
            border.color: Colors.accent
            scale: liveCardMa.containsMouse || root.selectedIndex === index ? 1.025 : 1
            Behavior on scale { NumberAnimation { duration: Animations.fast; easing.type: Easing.OutCubic } }

            Image {
                anchors.fill: parent
                source: liveCard.thumbnail
                sourceSize.width: Math.round(liveCard.width * 1.5)
                sourceSize.height: Math.round(liveCard.height * 1.5)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.45; color: "transparent" }
                    GradientStop { position: 1; color: root.a("#000", 0.78) }
                }
            }

            Column {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 9 }
                spacing: Metrics.dp(3)
Text {
                    text: liveCard.resolution + "  •  " + liveCard.ext.substring(1).toUpperCase()
                    color: "#ffffff"
                    font { pixelSize: Metrics.sp(9); family: "JetBrainsMono Nerd Font"; bold: true }
                    elide: Text.ElideRight
                    width: parent.width
                }
                Text {
                    text: L10n.tr("live_by_author", "by %1").replace("%1", liveCard.author)
                    color: root.a("#ffffff", 0.65)
                    font { pixelSize: Metrics.sp(8); family: "JetBrainsMono Nerd Font" }
                    elide: Text.ElideRight
                    width: parent.width
                }
            }

            Rectangle {
                anchors { top: parent.top; right: parent.right; margins: 7 }
                width: Metrics.dp(30)
height: Metrics.dp(22)
radius: Metrics.dp(6)
color: root.a("#000", 0.62)
                Text {
                    anchors.centerIn: parent
                    text: "󰕧"
                    color: Colors.accent
                    font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font" }
                }
            }

            MouseArea {
                id: liveCardMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selectLiveItem(index)
            }
        }
    }

    Rectangle {
        anchors.centerIn: liveGrid
        width: Math.min(root.panelWidth * 0.68, 580)
        height: Metrics.dp(250)
radius: root.brCard
        color: root.a(Colors.bg, UIState.transparencyEnabled ? 0.84 : 0.97)
        border.width: 1
        border.color: root.errorMessage !== "" ? root.a(Colors.red, 0.4) : root.a(Colors.fg, 0.09)
        visible: liveModel.count === 0 && !root.loading

        Column {
            anchors.centerIn: parent
            width: parent.width - 48
            spacing: Metrics.dp(15)
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "󰕧"
                color: Colors.accent
                font { pixelSize: Metrics.sp(38); family: "JetBrainsMono Nerd Font" }
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.errorMessage !== ""
                    ? root.errorMessage
                    : root.noResults
                        ? L10n.tr("live_no_results", "No matching videos found")
                        : L10n.tr("live_discover", "Discover live wallpapers on DesktopHut")
                color: Colors.fg
                font { pixelSize: Metrics.sp(14); family: "JetBrainsMono Nerd Font"; bold: true }
                wrapMode: Text.Wrap
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: L10n.tr("live_discover_hint", "Search a theme or explore featured and random videos, with attribution")
                color: root.a(Colors.fg, 0.43)
                font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font" }
                wrapMode: Text.Wrap
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Metrics.dp(180)
height: Metrics.dp(34)
radius: root.brSm
                color: exploreFeaturedMa.containsMouse ? root.a(Colors.accent, 0.28) : root.a(Colors.accent, 0.16)
                border.width: 1
                border.color: Colors.accent
                Text {
                    anchors.centerIn: parent
                    text: L10n.tr("live_featured", "Featured")
                    color: Colors.accent
                    font { pixelSize: Metrics.sp(9); family: "JetBrainsMono Nerd Font"; bold: true }
                }
                MouseArea {
                    id: exploreFeaturedMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.runLiveListing("featured", "", 1)
                }
            }
        }
    }

    Rectangle {
        anchors.centerIn: liveGrid
        width: Metrics.dp(180)
height: Metrics.dp(104)
radius: root.brCard
        color: root.a(Colors.bg, 0.92)
        border.width: 1
        border.color: root.a(Colors.fg, 0.09)
        visible: root.loading
        Column {
            anchors.centerIn: parent
            spacing: Metrics.dp(12)
Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "󰔟"
                color: Colors.accent
                font { pixelSize: Metrics.sp(25); family: "JetBrainsMono Nerd Font" }
                RotationAnimation on rotation {
                    running: root.loading
                    from: 0
                    to: 360
                    duration: 800
                    loops: Animation.Infinite
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: L10n.tr("live_searching", "Searching DesktopHut…")
                color: Colors.fg
                font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font"; bold: true }
            }
        }
    }

    Loader {
        id: livePreviewLoader
        anchors.fill: parent
        active: root.previewOpen && root.previewItem !== null
        sourceComponent: Component {
            Item {
                Rectangle {
                    anchors.fill: parent
                    color: root.a("#000", 0.38)
                    MouseArea { anchors.fill: parent; onClicked: root.previewOpen = false }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(root.panelWidth * 0.92, 790)
                    height: Math.min(root.panelHeight * 0.82, 450)
                    radius: root.brCard
                    color: root.a(Colors.bg, 0.98)
                    border.width: 1.5
                    border.color: root.a(Colors.accent, 0.55)

                    Row {
                        anchors.fill: parent
                        anchors.margins: Metrics.dp(14)
spacing: Metrics.dp(18)
                        Rectangle {
                            width: parent.width * 0.64
                            height: parent.height
                            radius: root.brSm
                            color: root.a(Colors.surface, 0.8)
                            clip: true

                            MediaPlayer {
                                id: previewPlayer
                                source: root.previewItem ? root.previewItem.download_url : ""
                                videoOutput: previewVideo
                                audioOutput: AudioOutput { muted: true }
                                loops: MediaPlayer.Infinite
                                Component.onCompleted: play()
                            }
                            VideoOutput {
                                id: previewVideo
                                anchors.fill: parent
                                fillMode: VideoOutput.PreserveAspectCrop
                            }
                        }

                        Column {
                            width: parent.width - (parent.width * 0.64) - parent.spacing
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Metrics.dp(13)
Text {
                                width: parent.width
                                text: root.previewItem ? root.previewItem.title : ""
                                color: Colors.fg
                                font { pixelSize: Metrics.sp(14); family: "JetBrainsMono Nerd Font"; bold: true }
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: root.previewItem
                                    ? root.previewItem.resolution
                                      + (root.previewItem.duration > 0 ? "  •  " + Math.round(root.previewItem.duration) + "s" : "")
                                      + "\n" + root.previewItem.mime + "  •  " + root.previewItem.ext.substring(1).toUpperCase()
                                    : ""
                                color: root.a(Colors.fg, 0.55)
                                font { pixelSize: Metrics.sp(9); family: "JetBrainsMono Nerd Font" }
                                wrapMode: Text.Wrap
                            }
                            Text {
                                width: parent.width
                                text: root.previewItem
                                    ? L10n.tr("live_by_author", "by %1").replace("%1", root.previewItem.author)
                                    : ""
                                color: Colors.accent
                                font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font"; bold: true }
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: root.previewItem ? root.previewItem.license : ""
                                color: root.a(Colors.fg, 0.65)
                                font { pixelSize: Metrics.sp(9); family: "JetBrainsMono Nerd Font"; bold: true }
                                elide: Text.ElideRight
                            }
                            Rectangle {
                                width: parent.width
                                height: Metrics.dp(38)
radius: root.brSm
                                color: downloadLiveMa.containsMouse ? root.a(Colors.accent, 0.3) : root.a(Colors.accent, 0.18)
                                border.width: 1.5
                                border.color: Colors.accent
                                Text {
                                    anchors.centerIn: parent
                                    text: L10n.tr("wallhaven_download_apply", "Download & Apply")
                                    color: Colors.accent
                                    font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font"; bold: true }
                                }
                                MouseArea {
                                    id: downloadLiveMa
                                    anchors.fill: parent
                                    enabled: root.activeDownloadId === ""
                                    hoverEnabled: true
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: root.startLiveDownload(root.previewItem)
                                }
                            }
                            Rectangle {
                                width: parent.width
                                height: Metrics.dp(32)
radius: root.brSm
                                color: sourceMa.containsMouse ? root.a(Colors.fg, 0.09) : root.a(Colors.fg, 0.045)
                                border.width: 1
                                border.color: root.a(Colors.fg, 0.1)
                                Text {
                                    anchors.centerIn: parent
                                    text: L10n.tr("live_open_source", "Open file page")
                                    color: root.a(Colors.fg, 0.7)
                                    font { pixelSize: Metrics.sp(9); family: "JetBrainsMono Nerd Font"; bold: true }
                                }
                                MouseArea {
                                    id: sourceMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openSource(root.previewItem.source_url)
                                }
                            }
                            Rectangle {
                                width: parent.width
                                height: Metrics.dp(32)
radius: root.brSm
                                color: licenseMa.containsMouse ? root.a(Colors.fg, 0.09) : root.a(Colors.fg, 0.045)
                                border.width: 1
                                border.color: root.a(Colors.fg, 0.1)
                                Text {
                                    anchors.centerIn: parent
                                    text: L10n.tr("live_open_license", "Open license")
                                    color: root.a(Colors.fg, 0.7)
                                    font { pixelSize: Metrics.sp(9); family: "JetBrainsMono Nerd Font"; bold: true }
                                }
                                MouseArea {
                                    id: licenseMa
                                    anchors.fill: parent
                                    enabled: root.previewItem && root.previewItem.license_url !== ""
                                    hoverEnabled: true
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: root.openSource(root.previewItem.license_url)
                                }
                            }
                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: root.previewItem ? root.previewItem.attribution : ""
                                color: root.a(Colors.fg, 0.35)
                                font { pixelSize: Metrics.sp(8); family: "JetBrainsMono Nerd Font" }
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        anchors { bottom: parent.bottom; bottomMargin: 54; horizontalCenter: parent.horizontalCenter }
        width: Math.min(downloadStatusRow.implicitWidth + 34, root.panelWidth)
        height: Metrics.dp(42)
radius: root.brSm
        color: root.a(Colors.bg, 0.96)
        border.width: 1
        border.color: root.downloadState === "error" ? Colors.red
            : root.downloadState === "success" ? Colors.green : Colors.accent
        visible: root.downloadState !== "idle"
        z: 100
        Row {
            id: downloadStatusRow
            anchors.centerIn: parent
            spacing: Metrics.dp(10)
Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.downloadState === "error" ? "󰅚" : root.downloadState === "success" ? "󰄬" : "󰇚"
                color: root.downloadState === "error" ? Colors.red
                    : root.downloadState === "success" ? Colors.green : Colors.accent
                font { pixelSize: Metrics.sp(14); family: "JetBrainsMono Nerd Font" }
                RotationAnimation on rotation {
                    running: root.downloadState === "downloading"
                    from: 0
                    to: 360
                    duration: 850
                    loops: Animation.Infinite
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.downloadState === "downloading"
                    ? root.downloadMessage + "  " + root.downloadPercent + "%"
                    : root.downloadMessage
                color: Colors.fg
                font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font"; bold: true }
            }
        }
    }

    Text {
        anchors { bottom: parent.bottom; bottomMargin: 24; horizontalCenter: parent.horizontalCenter }
        text: L10n.tr("live_help", "Arrows/HJKL: navigate • Enter: preview • P: featured • R: random • /: search")
        color: root.a(Colors.fg, 0.28)
        font { pixelSize: Metrics.sp(9); family: "JetBrainsMono Nerd Font" }
    }
}
