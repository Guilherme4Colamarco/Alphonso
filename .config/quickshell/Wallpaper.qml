import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtMultimedia
import QtQuick.Controls

PanelWindow {
    id: wallpaper

    property bool showing: UIState.activeDropdown === "wallpaper"
    property bool ready: false
    property var walls: []
    property var filtered: []
    property string query: ""
    property int selected: 0
    property var _wallsBuild: []
    property string currentWall: ""
    property int thumbVersion: 0
    property bool _skipInitialAnim: true
    property bool searching: false
    property bool _extractionRan: false

    property string currentTab: "local"
    property bool loadingSearch: false
    property string activeDownloadId: ""
    property int downloadPercent: 0
    property string wallhavenScript: Quickshell.env("HOME") + "/.config/quickshell/wallhaven/wallhaven.py"
    property int onlineSelected: 0
    property int currentPage: 1
    property int totalPages: 1
    property int totalResults: 0
    property bool showDeleteConfirm: false
    property var pendingDeleteWall: null
    property bool showHelp: false
    property bool _escPressedRecently: false
    property bool showFilters: false

    // Filter properties
    property string whCategories: "111"  // General/Anime/People bitmask
    property string whPurity: "100"      // SFW/Sketchy/NSFW bitmask
    property string whSorting: "relevance"  // relevance, date_added, views, favorites, toplist, random
    property string whAtleast: ""        // Minimum resolution (e.g. "1920x1080")
    property string whRatios: ""         // Aspect ratios (e.g. "16x9,16x10")
    property string whTypes: ""          // File types (e.g. "png,jpg")
    property string whTopRange: "1w"     // Top range for toplist (1d,3d,1w,1M,3M,6M,1y)

    property real smoothSelected: 0
    Behavior on smoothSelected {
        NumberAnimation { duration: _skipInitialAnim ? 0 : Animations.slow; easing.type: Easing.OutExpo }
    }

    property string cachePath: Quickshell.env("HOME") + "/.cache/wallpaper-thumbs"
    property string wallDir:   Quickshell.env("HOME") + "/wallpapers"

    property real br:     UIState.borderRadius
    property real brCard: Math.round(br * 0.75)
    property real brSm:   Math.round(br * 0.625)

    property real cardW: Math.min(screen ? screen.width * 0.46 : 680, 860)
    property real cardH: Math.round(cardW / 1.6)

    property real angleStep: 38

    visible: showing
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "wallpaper"
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function a(c, o) { return Qt.rgba(c.r, c.g, c.b, o) }

    Component.onCompleted: cacheLoadProc.running = true

    onSelectedChanged: smoothSelected = selected

    onShowingChanged: {
        if (showing) {
            query            = ""
            selected         = 0
            smoothSelected   = 0
            keyInput.text    = ""
            _skipInitialAnim = true
            searching        = false
            ready            = false
            currentWallProc.running = true
        } else {
            ready     = false
            searching = false
        }
    }

    Timer {
        id: listReadyDelay
        interval: 50
        onTriggered: {
            ready = true
            enableAnimDelay.start()
            focusDelay.start()
        }
    }

    Timer {
        id: focusDelay
        interval: 80
        onTriggered: keyInput.forceActiveFocus()
    }

    Timer {
        id: enableAnimDelay
        interval: 120
        onTriggered: _skipInitialAnim = false
    }

    Timer {
        id: escResetTimer
        interval: 400
        onTriggered: _escPressedRecently = false
    }

    function resetOnlineSearch() {
        keyInput.text = ""
        query = ""
        onlineModel.clear()
        onlineSelected = 0
        currentPage = 1
        totalPages = 1
        totalResults = 0
        loadingSearch = false
        _escPressedRecently = false
        showFilters = false
    }

    function filterWalls(preserve) {
        var prevName = preserve && selected < filtered.length ? filtered[selected].name : ""
        var result   = walls.slice()
        if (query !== "") {
            var q = query.toLowerCase()
            result = result.filter(w => w.name.toLowerCase().includes(q))
            result.sort((a, b) => {
                var ai = a.name.toLowerCase().indexOf(q)
                var bi = b.name.toLowerCase().indexOf(q)
                if (ai !== bi) return ai - bi
                return a.name.length - b.name.length
            })
        }
        filtered = result
        if (prevName) {
            for (var i = 0; i < result.length; i++) {
                if (result[i].name === prevName) { selected = i; return }
            }
        }
        selected = 0
    }

    function selectCurrentWall() {
        for (var i = 0; i < filtered.length; i++) {
            if (filtered[i].name === currentWall) { selected = i; return }
        }
    }

    function applyWallpaper(wall) {
        if (!wall) return
        var path = wallDir + "/" + wall.name
        if (wall.isVideo) {
            var tempFrame = cachePath + "/temp_firstframe.jpg"
            applyProc.command = ["bash", "-c",
                "pkill mpvpaper 2>/dev/null; " +
                "ln -sf '" + path + "' '" + wallDir + "/current' && " +
                "ffmpeg -y -i '" + path + "' -ss 00:00:01 -vframes 1 -q:v 2 '" + tempFrame + "' 2>/dev/null && " +
                "awww img '" + tempFrame + "' " +
                "--transition-type wipe " +
                "--transition-angle 30 " +
                "--transition-duration 1.5 " +
                "--transition-fps 60 && " +
                "sleep 1.5 && " +
                "mpvpaper --fork -o 'no-audio loop panscan=1.0' '*' '" + path + "'"]
        } else {
            applyProc.command = ["bash", "-c",
                "pkill mpvpaper 2>/dev/null; " +
                "ln -sf '" + path + "' '" + wallDir + "/current' && " +
                "awww img '" + path + "' " +
                "--transition-type wipe " +
                "--transition-angle 30 " +
                "--transition-duration 1.5 " +
                "--transition-fps 60"]
        }
        applyProc.running = true
        currentWall = wall.name
    }

    function prettyName(name) {
        var dot = name.lastIndexOf(".")
        var n   = dot > 0 ? name.substring(0, dot) : name
        return n.replace(/[-_]/g, " ")
    }

    function pickRandom() {
        if (filtered.length < 2) return
        var idx = selected
        while (idx === selected)
            idx = Math.floor(Math.random() * filtered.length)
        selected = idx
    }

    function writeCache() {
        var arr = []
        for (var i = 0; i < walls.length; i++)
            arr.push({ name: walls[i].name })
        var json = JSON.stringify(arr)
        writeCacheProc.command = ["bash", "-c",
            "mkdir -p '" + cachePath + "' && cat > '" + cachePath + "/walls.json' << 'WCEOF'\n" + json + "\nWCEOF"]
        writeCacheProc.running = true
    }

    Process {
        id: cacheLoadProc
        command: ["cat", cachePath + "/walls.json"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                try {
                    var arr    = JSON.parse(data.trim())
                    var result = []
                    for (var i = 0; i < arr.length; i++) {
                        var name  = arr[i].name
                        var lower = name.toLowerCase()
                        result.push({
                            name:    name,
                            isVideo: lower.endsWith(".mp4") || lower.endsWith(".webm") || lower.endsWith(".mkv"),
                            isGif:   lower.endsWith(".gif")
                        })
                    }
                    walls        = result
                    filtered     = walls.slice()
                    thumbVersion = 1
                } catch(e) {}
            }
        }
    }

    Process {
        id: currentWallProc
        command: ["bash", "-c", "basename $(readlink -f $HOME/wallpapers/current) 2>/dev/null"]
        stdout: SplitParser { onRead: data => currentWall = data.trim() }
        onExited: {
            if (walls.length > 0) {
                filterWalls()
                selectCurrentWall()
                listReadyDelay.start()
            }
            _wallsBuild = []
            wallListProc.running = true
        }
    }

    Process {
        id: wallListProc
        command: ["bash", "-c", [
            "shopt -s nullglob",
            "for f in \"$HOME\"/wallpapers/*.{jpg,jpeg,png,gif,webp,mp4,webm,mkv}; do",
            "  [ -L \"$f\" ] && continue",
            "  basename \"$f\"",
            "done"
        ].join("\n")]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (line.length === 0) return
                var lower = line.toLowerCase()
                _wallsBuild.push({
                    name:    line,
                    isVideo: lower.endsWith(".mp4") || lower.endsWith(".webm") || lower.endsWith(".mkv"),
                    isGif:   lower.endsWith(".gif")
                })
            }
        }
        onExited: {
            var seen   = {}
            var result = []
            for (var i = 0; i < _wallsBuild.length; i++) {
                if (!seen[_wallsBuild[i].name]) {
                    seen[_wallsBuild[i].name] = true
                    result.push(_wallsBuild[i])
                }
            }
            walls       = result
            _wallsBuild = []
            if (ready) {
                filterWalls(true)
            } else {
                filterWalls()
                selectCurrentWall()
                listReadyDelay.start()
            }
            writeCache()
            if (!_extractionRan) {
                _extractionRan = true
                colorExtractDelay.start()
            }
        }
    }

    Timer {
        id: colorExtractDelay
        interval: 1500
        onTriggered: colorExtractProc.running = true
    }

    Process {
        id: colorExtractProc
        command: ["bash", "-c", [
            "shopt -s nullglob",
            "CACHE=\"$HOME/.cache/wallpaper-thumbs\"",
            "LOCK=\"$CACHE/.extraction.lock\"",
            "mkdir -p \"$CACHE\"",
            "[ -f \"$LOCK\" ] && exit 0",
            "touch \"$LOCK\"",
            "trap 'rm -f \"$LOCK\"' EXIT",
            "",
            "for f in \"$HOME\"/wallpapers/*.{jpg,jpeg,png,gif,webp,mp4,webm,mkv}; do",
            "  [ -L \"$f\" ] && continue",
            "  name=$(basename \"$f\")",
            "  thumb=\"$CACHE/${name}.thumb.jpg\"",
            "  [ -f \"$thumb\" ] && continue",
            "  ext=\"${name##*.}\"",
            "  if [[ \"$ext\" == \"mp4\" || \"$ext\" == \"webm\" || \"$ext\" == \"mkv\" ]]; then",
            "    nice -n 19 ionice -c3 ffmpeg -y -i \"$f\" -ss 00:00:01 -vframes 1 -vf scale=600:-1 \"$thumb\" 2>/dev/null &",
            "  else",
            "    nice -n 19 magick \"${f}[0]\" -resize 600x -quality 85 \"$thumb\" 2>/dev/null &",
            "  fi",
            "done",
            "wait",
            "echo 'THUMBS_READY'"
        ].join("\n")]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (line === "THUMBS_READY") thumbVersion++
            }
        }
    }

    Process { id: applyProc }
    Process { id: writeCacheProc }

    Process {
        id: deleteProc
        running: false

        function deleteWallpaper(wall) {
            if (!wall) return
            var path = wallDir + "/" + wall.name
            command = ["bash", "-c",
                "rm -f '" + path + "' && " +
                "rm -f '" + cachePath + "/" + wall.name + ".thumb.jpg' && " +
                "echo 'DELETED'"]
            running = true
        }

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data.trim() === "DELETED") {
                    // Reload local list
                    currentWallProc.running = true
                }
            }
        }
    }

    ListModel {
        id: onlineModel
    }

    Process {
        id: searchProc
        running: false
        
        function runSearch(q, p) {
            currentPage = p ? p : 1
            command = ["python3", wallhavenScript, "search",
                "--query", q,
                "--categories", whCategories,
                "--purity", whPurity,
                "--sorting", whSorting,
                "--page", currentPage.toString()]
            if (whAtleast) { command.push("--atleast"); command.push(whAtleast) }
            if (whRatios) { command.push("--ratios"); command.push(whRatios) }
            if (whTypes) { command.push("--types"); command.push(whTypes) }
            if (whSorting === "toplist" && whTopRange) { command.push("--topRange"); command.push(whTopRange) }
            if (UIState.wallhavenApiKey) { command.push("--apikey"); command.push(UIState.wallhavenApiKey) }
            running = false
            running = true
        }

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    var resp = JSON.parse(data.trim())
                    onlineModel.clear()
                    onlineSelected = 0
                    if (resp.error) {
                        console.log("Search error:", resp.error)
                        return
                    }
                    var list = resp.results || resp
                    totalResults = resp.total || 0
                    totalPages = resp.last_page || 1
                    for (var i = 0; i < list.length; i++) {
                        onlineModel.append(list[i])
                    }
                } catch(e) {
                    console.log("JSON Parse Error: ", e)
                }
            }
        }
        onExited: {
            loadingSearch = false
            onlineGrid._loadingMore = false
        }
    }

    Process {
        id: downloadProc
        running: false

        function downloadFile(url, id, ext) {
            command = ["python3", wallhavenScript, "download", "--url", url, "--id", id, "--ext", ext, "--out-dir", wallDir]
            running = false
            running = true
        }

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var line = data.trim()
                if (line.startsWith("PROGRESS:")) {
                    downloadPercent = parseInt(line.substring(9)) || 0
                } else if (line.startsWith("SUCCESS:")) {
                    var fullPath = line.substring(8)
                    downloadPercent = 100
                    activeDownloadId = ""
                    
                    var filename = fullPath.substring(fullPath.lastIndexOf('/') + 1)
                    var isVideo = filename.endsWith(".mp4") || filename.endsWith(".webm")
                    applyWallpaper({ name: filename, isVideo: isVideo })
                    
                    // Reload local list
                    currentWallProc.running = true
                } else if (line.startsWith("ERROR:")) {
                    activeDownloadId = ""
                    console.log("Download failed: " + line.substring(6))
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: UIState.closeDropdowns()
    }

    TextInput {
        id: keyInput
        visible: false
        color: Colors.fg
        font { pixelSize: 11; family: "JetBrainsMono Nerd Font" }
        selectByMouse: true
        readOnly: !searching

        onTextChanged: {
            query = text.toLowerCase()
            filterWalls()
        }

        Keys.onPressed: function(event) {
            if (searching) {
                if (event.key === Qt.Key_Escape) {
                    searching = false
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    searching = false
                    if (currentTab === "online" && text.trim().length > 0) {
                        loadingSearch = true
                        searchProc.runSearch(text.trim(), 1)
                    }
                    event.accepted = true
                }
            } else {
                if (event.key === Qt.Key_Slash) {
                    text = ""
                    query = ""
                    searching = true
                    event.accepted = true
                } else if (event.key === Qt.Key_Tab) {
                    currentTab = currentTab === "local" ? "online" : "local"
                    event.accepted = true
                } else if (event.key === Qt.Key_H || event.key === Qt.Key_Left) {
                    if (currentTab === "local" && selected > 0) {
                        selected--
                    } else if (currentTab === "online") {
                        if (onlineSelected > 0) {
                            onlineSelected--
                            onlineGrid.positionViewAtIndex(onlineSelected, GridView.Contain)
                        } else if (currentPage > 1) {
                            // Na primeira coluna, volta pra página anterior
                            currentPage--
                            searchProc.runSearch(keyInput.text.trim(), currentPage)
                            onlineSelected = Math.max(0, onlineModel.count - 3)
                            onlineGrid.positionViewAtIndex(onlineSelected, GridView.Contain)
                        }
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_L || event.key === Qt.Key_Right) {
                    if (currentTab === "local" && selected < filtered.length - 1) {
                        selected++
                    } else if (currentTab === "online") {
                        if (onlineSelected < onlineModel.count - 1) {
                            onlineSelected++
                            onlineGrid.positionViewAtIndex(onlineSelected, GridView.Contain)
                        }
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
                    if (currentTab === "online") {
                        if (onlineSelected >= 3) {
                            onlineSelected -= 3
                            onlineGrid.positionViewAtIndex(onlineSelected, GridView.Contain)
                        } else if (currentPage > 1) {
                            // No topo da primeira linha, volta pra página anterior
                            currentPage--
                            searchProc.runSearch(keyInput.text.trim(), currentPage)
                            onlineSelected = Math.max(0, onlineModel.count - 3)
                            onlineGrid.positionViewAtIndex(onlineSelected, GridView.Contain)
                        }
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
                    if (currentTab === "online") {
                        if (onlineSelected + 3 < onlineModel.count) {
                            onlineSelected += 3
                            onlineGrid.positionViewAtIndex(onlineSelected, GridView.Contain)
                        }
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_Home) {
                    if (currentTab === "local") selected = 0
                    else if (currentTab === "online") { onlineSelected = 0; onlineGrid.positionViewAtIndex(0, GridView.Contain) }
                    event.accepted = true
                } else if (event.key === Qt.Key_End) {
                    if (currentTab === "local") selected = Math.max(0, filtered.length - 1)
                    else if (currentTab === "online") { onlineSelected = Math.max(0, onlineModel.count - 1); onlineGrid.positionViewAtIndex(onlineSelected, GridView.Contain) }
                    event.accepted = true
                } else if (event.key === Qt.Key_PageUp) {
                    if (currentTab === "local") selected = Math.max(0, selected - 5)
                    event.accepted = true
                } else if (event.key === Qt.Key_PageDown) {
                    if (currentTab === "local") selected = Math.min(filtered.length - 1, selected + 5)
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (currentTab === "local") {
                        if (filtered.length > 0) applyWallpaper(filtered[selected])
                    } else if (currentTab === "online") {
                        if (onlineModel.count > 0 && activeDownloadId === "") {
                            var item = onlineModel.get(onlineSelected)
                            activeDownloadId = item.id
                            downloadPercent = 0
                            downloadProc.downloadFile(item.url, item.id, item.ext)
                        }
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_R) {
                    if (currentTab === "local") pickRandom()
                    event.accepted = true
                } else if (event.key === Qt.Key_Y) {
                    if (showDeleteConfirm && pendingDeleteWall) {
                        deleteProc.deleteWallpaper(pendingDeleteWall)
                        showDeleteConfirm = false
                        pendingDeleteWall = null
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_N) {
                    if (showDeleteConfirm) {
                        showDeleteConfirm = false
                        pendingDeleteWall = null
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_D) {
                    if (currentTab === "local" && filtered.length > 0 && !showDeleteConfirm) {
                        pendingDeleteWall = filtered[selected]
                        showDeleteConfirm = true
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_F) {
                    if (currentTab === "online" && !searching) {
                        showFilters = !showFilters
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_Question) {
                    showHelp = !showHelp
                    event.accepted = true
                } else if (event.key === Qt.Key_Escape) {
                    if (showHelp) {
                        showHelp = false
                    } else if (showDeleteConfirm) {
                        showDeleteConfirm = false
                        pendingDeleteWall = null
                    } else if (currentTab === "online" && onlineModel.count > 0) {
                        if (_escPressedRecently) {
                            resetOnlineSearch()
                        } else {
                            _escPressedRecently = true
                            escResetTimer.start()
                            if (query !== "") {
                                keyInput.text = ""
                                query = ""
                            }
                        }
                    } else if (query !== "") {
                        keyInput.text = ""
                        query = ""
                        if (currentTab === "local") filterWalls()
                    } else {
                        UIState.closeDropdowns()
                    }
                    event.accepted = true
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        opacity: ready ? 1 : 0
        scale:   ready ? 1 : Animations.enterScale

        Behavior on opacity {
            NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: Animations.slow; easing.type: Easing.OutBack; easing.overshoot: Animations.springPower }
        }

        // Tab selection row
        Row {
            id: tabRow
            anchors {
                top: parent.top
                topMargin: 40
                horizontalCenter: parent.horizontalCenter
            }
            spacing: 16

            Repeater {
                model: [
                    { name: "local", label: L10n.tr("local", "Local") },
                    { name: "online", label: "Wallhaven" }
                ]

                Rectangle {
                    width:  120
                    height: 32
                    radius: brSm
                    color:  currentTab === modelData.name ? a(Colors.accent, 0.12) : a(Colors.bg, 0.4)
                    border.width: currentTab === modelData.name ? 1.5 : 1
                    border.color: currentTab === modelData.name ? Colors.accent : a(Colors.fg, 0.08)

                    Text {
                        anchors.centerIn: parent
                        text:  modelData.label
                        color: currentTab === modelData.name ? Colors.accent : a(Colors.fg, 0.6)
                        font { pixelSize: 11; family: "JetBrainsMono Nerd Font"; bold: true }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            currentTab = modelData.name
                            keyInput.forceActiveFocus()
                        }
                    }
                }
            }
        }

        Item {
            id: sceneRoot
            anchors.centerIn: parent
            width:  parent.width
            height: cardH
            clip:   true
            visible: currentTab === "local"

            function slotX(offset) {
                var rad = offset * angleStep * Math.PI / 180
                return parent.width / 2 - cardW / 2 + Math.sin(rad) * (cardW * 0.82)
            }

            function slotAngle(offset) {
                return offset * angleStep
            }

            function slotScale(offset) {
                var rad = offset * angleStep * Math.PI / 180
                return Math.max(0.35, 0.5 + 0.5 * Math.cos(rad))
            }

            function slotOpacity(offset) {
                var dist = Math.abs(offset)
                if (dist < 0.5)  return 1.0
                if (dist < 1.5)  return 1.0  - (dist - 0.5) * 0.25
                if (dist < 2.5)  return 0.75 - (dist - 1.5) * 0.30
                if (dist < 3.0)  return 0.45 * (3.0 - dist) / 0.5
                return 0.0
            }

            function thumbSource(idx) {
                if (idx < 0 || idx >= filtered.length) return ""
                if (thumbVersion > 0)
                    return "file://" + cachePath + "/" + filtered[idx].name + ".thumb.jpg"
                return "file://" + wallDir + "/" + filtered[idx].name
            }

            Repeater {
                model: filtered

                Item {
                    id: slotItem
                    required property int index
                    required property var modelData

                    property real offset:    index - smoothSelected
                    property real absOffset: Math.abs(offset)
                    property bool isCenter:  index === selected

                    width:  cardW
                    height: cardH
                    x:      sceneRoot.slotX(offset)
                    y:      0
                    scale:  sceneRoot.slotScale(offset)
                    opacity: sceneRoot.slotOpacity(offset)
                    visible: absOffset < 3.0
                    z:      isCenter ? 999 : Math.round((1.0 - Math.min(absOffset, 2.0) / 2.0) * 100)

                    transform: Rotation {
                        origin.x: cardW / 2
                        origin.y: cardH / 2
                        axis { x: 0; y: 1; z: 0 }
                        angle: sceneRoot.slotAngle(slotItem.offset)
                    }

                    Rectangle {
                        id: slotRect
                        anchors.fill: parent
                        radius: br
                        color:  "#000"
                        clip:   true

                        Behavior on radius { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }

                        property bool isGif:   slotItem.isCenter && modelData.isGif
                        property bool isVideo: slotItem.isCenter && modelData.isVideo

                        Image {
                            anchors.fill: parent
                            source: slotItem.isCenter && !slotRect.isGif && !slotRect.isVideo
                                ? (thumbVersion > 0
                                    ? "file://" + cachePath + "/" + slotItem.modelData.name + ".thumb.jpg"
                                    : "file://" + wallDir   + "/" + slotItem.modelData.name)
                                : (!slotItem.isCenter
                                    ? sceneRoot.thumbSource(slotItem.index)
                                    : "")
                            onStatusChanged: {
                                if (status === Image.Error && slotItem.isCenter)
                                    source = "file://" + wallDir + "/" + slotItem.modelData.name
                            }
                            fillMode: slotItem.isCenter ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                            sourceSize.width: slotItem.isCenter ? 1920 : 400
                            asynchronous: true
                            cache: true
                            visible: !slotRect.isGif && !slotRect.isVideo
                        }

                        Loader {
                            anchors.fill: parent
                            active: slotRect.isGif
                            sourceComponent: AnimatedImage {
                                anchors.fill: parent
                                source: "file://" + wallDir + "/" + slotItem.modelData.name
                                fillMode: Image.PreserveAspectFit
                                playing: true
                                asynchronous: true
                            }
                        }

                        Loader {
                            anchors.fill: parent
                            active: slotRect.isVideo
                            sourceComponent: Item {
                                anchors.fill: parent
                                MediaPlayer {
                                    id: slotVid
                                    source: "file://" + wallDir + "/" + slotItem.modelData.name
                                    loops: MediaPlayer.Infinite
                                    audioOutput: AudioOutput { muted: true }
                                    videoOutput: slotVidOut
                                    Component.onCompleted: play()
                                }
                                VideoOutput {
                                    id: slotVidOut
                                    anchors.fill: parent
                                    fillMode: VideoOutput.PreserveAspectFit
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: slotItem.isCenter ? "transparent" : a("#000", 0.35)
                            Behavior on color { ColorAnimation { duration: Animations.medium } }
                        }

                        Item {
                            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                            height: 56
                            visible: slotItem.isCenter
                            opacity: slotItem.isCenter ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Animations.fast } }

                            Rectangle {
                                anchors.fill: parent
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 1.0; color: a("#000", 0.72) }
                                }
                            }

                            Row {
                                anchors { left: parent.left; bottom: parent.bottom }
                                anchors { leftMargin: 18; bottomMargin: 14 }
                                spacing: 10

                                Text {
                                    text:  prettyName(slotItem.modelData.name)
                                    color: "#fff"
                                    font { pixelSize: 12; family: "JetBrainsMono Nerd Font" }
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    visible: slotItem.modelData.name === currentWall
                                    text:    "●"
                                    color:   Colors.green
                                    font { pixelSize: 8; family: "JetBrainsMono Nerd Font" }
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: br
                            color:  "transparent"
                            border.width: slotItem.isCenter ? 2 : slotItem.modelData.name === currentWall ? 1.5 : 0
                            border.color: slotItem.modelData.name === currentWall ? Colors.green : Colors.accent
                            Behavior on border.color { ColorAnimation  { duration: Animations.fast } }
                            Behavior on border.width { NumberAnimation { duration: Animations.fast } }
                            Behavior on radius       { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: slotItem.isCenter ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (slotItem.isCenter) applyWallpaper(slotItem.modelData)
                            else selected = slotItem.index
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                propagateComposedEvents: true
                z: -999
                onWheel: function(wheel) {
                    if (wheel.angleDelta.y > 0 || wheel.angleDelta.x > 0) {
                        if (selected > 0) selected--
                    } else {
                        if (selected < filtered.length - 1) selected++
                    }
                }
            }
        }

        Rectangle {
            id: emptyCard
            anchors.centerIn: sceneRoot
            width:  cardW
            height: cardH
            radius: br
            color:  a(Colors.bg, UIState.transparencyEnabled ? 0.7 : 0.92)
            border.width: 1
            border.color: a(Colors.fg, 0.06)
            visible: ready && filtered.length === 0 && currentTab === "local"
            opacity: visible ? 1 : 0
            scale:   visible ? 1 : 0.96

            Behavior on opacity { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }
            Behavior on scale   { NumberAnimation { duration: Animations.slow;   easing.type: Easing.OutBack; easing.overshoot: Animations.springPower } }
            Behavior on radius  { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }
            Behavior on color   { ColorAnimation  { duration: Animations.slow } }

            Column {
                anchors.centerIn: parent
                spacing: 18

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text:  walls.length === 0 ? "󰏗" : "󰍉"
                    color: a(Colors.fg, 0.1)
                    font { pixelSize: 48; family: "JetBrainsMono Nerd Font" }
                }

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text:  walls.length === 0 ? "Scanning wallpapers" : "No results"
                        color: a(Colors.fg, 0.4)
                        font { pixelSize: 14; family: "JetBrainsMono Nerd Font" }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: query !== ""
                        text:    "\"" + query + "\""
                        color:   a(Colors.fg, 0.2)
                        font { pixelSize: 11; family: "JetBrainsMono Nerd Font" }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8
                    visible: filtered.length === 0 && query !== ""

                    Text {
                        text: "Press"
                        color: a(Colors.fg, 0.2)
                        font { pixelSize: 10; family: "JetBrainsMono Nerd Font" }
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        width:  escLbl.width + 14
                        height: 20
                        radius: brSm
                        color:  a(Colors.fg, 0.05)
                        border.width: 1
                        border.color: a(Colors.fg, 0.08)
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            id: escLbl
                            anchors.centerIn: parent
                            text:  "Esc"
                            color: a(Colors.fg, 0.3)
                            font { pixelSize: 9; family: "JetBrainsMono Nerd Font" }
                        }
                    }

                    Text {
                        text: "to clear"
                        color: a(Colors.fg, 0.2)
                        font { pixelSize: 10; family: "JetBrainsMono Nerd Font" }
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // Online Search Grid
        Item {
            id: onlineRoot
            anchors.centerIn: parent
            width:  cardW
            height: cardH
            visible: currentTab === "online"

            GridView {
                id: onlineGrid
                anchors.fill: parent
                cellWidth:  cardW / 3
                cellHeight: cellWidth / 1.5
                clip: true
                model: onlineModel
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                property bool _loadingMore: false

                onContentYChanged: {
                    if (contentHeight <= 0) return
                    var threshold = 200
                    var atBottom = (contentY + height) >= (contentHeight - threshold)
                    if (atBottom && !_loadingMore && !loadingSearch && currentPage < totalPages && keyInput.text.trim().length > 0) {
                        _loadingMore = true
                        currentPage++
                        searchProc.runSearch(keyInput.text.trim(), currentPage)
                    }
                }

                delegate: Rectangle {
                    id: gridItem
                    required property string id
                    required property string url
                    required property string thumbnail
                    required property string resolution
                    required property int file_size
                    required property string ext
                    required property int index
                    property var tags: modelData ? (modelData.tags || []) : []
                    property var colors: modelData ? (modelData.colors || []) : []

                    width:  (cardW / 3) - 12
                    height: (width / 1.6)
                    radius: brCard
                    color:  a(Colors.bg, 0.4)
                    clip:   true
                    border.width: onlineSelected === index ? 2 : (activeDownloadId === id ? 2.5 : 0)
                    border.color: onlineSelected === index ? Colors.accent : (activeDownloadId === id ? Colors.accent : "transparent")

                    Behavior on scale { NumberAnimation { duration: Animations.fast; easing.type: Easing.OutCubic } }
                    Behavior on border.color { ColorAnimation { duration: Animations.fast } }
                    Behavior on border.width { NumberAnimation { duration: Animations.fast } }
                    scale: gridMa.containsMouse || onlineSelected === index ? 1.03 : 1.0

                    // Selection highlight overlay (inside clip, but visible)
                    Rectangle {
                        anchors.fill: parent
                        radius: brCard
                        color: onlineSelected === index ? a(Colors.accent, 0.15) : "transparent"
                        border.width: onlineSelected === index ? 2 : 0
                        border.color: Colors.accent
                        visible: onlineSelected === index
                        z: 999
                        opacity: 1.0

                        Behavior on color { ColorAnimation { duration: Animations.fast } }
                    }

                    // Corner selection indicator
                    Rectangle {
                        anchors { top: parent.top; left: parent.left; margins: 4 }
                        width: 20; height: 20
                        radius: 10
                        color: Colors.accent
                        visible: onlineSelected === index
                        z: 999

                        Text {
                            anchors.centerIn: parent
                            text: "✓"
                            color: "#fff"
                            font { pixelSize: 10; family: "JetBrainsMono Nerd Font"; bold: true }
                        }
                    }

                    Image {
                        anchors.fill: parent
                        source: thumbnail
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                    }

                    // Resolution badge (top-right)
                    Rectangle {
                        anchors { top: parent.top; right: parent.right; margins: 6 }
                        width: resBadge.width + 10; height: 18
                        radius: 4
                        color: a("#000", 0.6)
                        visible: activeDownloadId !== id

                        Text {
                            id: resBadge
                            anchors.centerIn: parent
                            text: gridItem.resolution
                            color: "#fff"
                            font { pixelSize: 8; family: "JetBrainsMono Nerd Font"; bold: true }
                        }
                    }

                    // File type badge (bottom-left)
                    Rectangle {
                        anchors { bottom: parent.bottom; left: parent.left; margins: 6 }
                        width: typeBadge.width + 8; height: 16
                        radius: 3
                        color: a(Colors.accent, 0.85)
                        visible: activeDownloadId !== id

                        Text {
                            id: typeBadge
                            anchors.centerIn: parent
                            text: gridItem.ext.replace(".", "").toUpperCase()
                            color: "#fff"
                            font { pixelSize: 7; family: "JetBrainsMono Nerd Font"; bold: true }
                        }
                    }

                    // Hover overlay with gradient
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        visible: gridMa.containsMouse && activeDownloadId !== id

                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: a("#000", 0.05) }
                                GradientStop { position: 0.4; color: a("#000", 0.45) }
                                GradientStop { position: 1.0; color: a("#000", 0.78) }
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 5
                            width: parent.width - 16

                            Text {
                                text: "󰔟"
                                color: Colors.accent
                                font { pixelSize: 18; family: "JetBrainsMono Nerd Font" }
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Text {
                                text: gridItem.resolution
                                color: "#fff"
                                font { pixelSize: 12; family: "JetBrainsMono Nerd Font"; bold: true }
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Text {
                                text: (gridItem.file_size / (1024 * 1024)).toFixed(1) + " MB • " + gridItem.ext.replace(".", "").toUpperCase()
                                color: a("#fff", 0.7)
                                font { pixelSize: 9; family: "JetBrainsMono Nerd Font" }
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 4
                                visible: gridItem.tags && gridItem.tags.length > 0
                                Repeater {
                                    model: Math.min((gridItem.tags || []).length, 3)
                                    Rectangle {
                                        width: tagLabel.width + 8; height: 16
                                        radius: 3
                                        color: a(Colors.accent, 0.25)
                                        Text {
                                            id: tagLabel
                                            anchors.centerIn: parent
                                            text: (gridItem.tags || [])[index] || ""
                                            color: Colors.accent
                                            font { pixelSize: 7; family: "JetBrainsMono Nerd Font" }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: enterHint.width + 12; height: 20
                                radius: 4
                                color: a(Colors.accent, 0.2)
                                border.width: 1
                                border.color: a(Colors.accent, 0.4)
                                anchors.horizontalCenter: parent.horizontalCenter

                                Text {
                                    id: enterHint
                                    anchors.centerIn: parent
                                    text: "Enter ⏎"
                                    color: Colors.accent
                                    font { pixelSize: 8; family: "JetBrainsMono Nerd Font" }
                                }
                            }
                        }
                    }

                    // Download progress overlay
                    Rectangle {
                        anchors.fill: parent
                        color: a("#000", 0.82)
                        visible: activeDownloadId === id

                        Column {
                            anchors.centerIn: parent
                            spacing: 10
                            width: parent.width - 20

                            Text {
                                id: dlIcon
                                text: "󰔟"
                                color: Colors.accent
                                font { pixelSize: 22; family: "JetBrainsMono Nerd Font" }
                                anchors.horizontalCenter: parent.horizontalCenter
                                RotationAnimation on rotation {
                                    running: activeDownloadId === gridItem.id && downloadPercent < 100
                                    from: 0; to: 360; duration: 800; loops: Animation.Infinite
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 5
                                radius: 3
                                color: a(Colors.fg, 0.1)
                                anchors.horizontalCenter: parent.horizontalCenter

                                Rectangle {
                                    width: parent.width * (downloadPercent / 100)
                                    height: parent.height
                                    radius: parent.radius
                                    color: Colors.accent
                                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                }
                            }

                            Text {
                                text: downloadPercent + "%"
                                color: Colors.fg
                                font { pixelSize: 11; family: "JetBrainsMono Nerd Font"; bold: true }
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }

                    MouseArea {
                        id: gridMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (activeDownloadId === "") {
                                activeDownloadId = id
                                downloadPercent = 0
                                downloadProc.downloadFile(url, id, ext)
                            }
                        }
                    }
                }
            }
        }

        // Online Loading Indicator
        Rectangle {
            anchors.centerIn: parent
            width:  180
            height: 110
            radius: brCard
            color:  a(Colors.bg, UIState.transparencyEnabled ? 0.72 : 0.9)
            border.width: 1
            border.color: a(Colors.fg, 0.08)
            visible: currentTab === "online" && loadingSearch

            Column {
                anchors.centerIn: parent
                spacing: 14

                Text {
                    text: "󰔟"
                    color: Colors.accent
                    font { pixelSize: 28; family: "JetBrainsMono Nerd Font" }
                    anchors.horizontalCenter: parent.horizontalCenter
                    RotationAnimation on rotation {
                        running: currentTab === "online" && loadingSearch
                        from: 0; to: 360; duration: 800; loops: Animation.Infinite
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 2

                    Text {
                        text: "Searching"
                        color: Colors.fg
                        font { pixelSize: 11; family: "JetBrainsMono Nerd Font"; bold: true }
                    }

                    Text {
                        id: loadingDots
                        text: ""
                        color: Colors.fg
                        font { pixelSize: 11; family: "JetBrainsMono Nerd Font"; bold: true }
                        SequentialAnimation on text {
                            running: currentTab === "online" && loadingSearch
                            loops: Animation.Infinite
                            ScriptAction { script: loadingDots.text = "." }
                            PauseAnimation { duration: 300 }
                            ScriptAction { script: loadingDots.text = ".." }
                            PauseAnimation { duration: 300 }
                            ScriptAction { script: loadingDots.text = "..." }
                            PauseAnimation { duration: 300 }
                        }
                    }
                }

                Text {
                    text: "Wallhaven"
                    color: a(Colors.fg, 0.3)
                    font { pixelSize: 9; family: "JetBrainsMono Nerd Font" }
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        // Online Empty State
        Rectangle {
            anchors.centerIn: parent
            width:  cardW
            height: cardH
            radius: br
            color:  a(Colors.bg, UIState.transparencyEnabled ? 0.7 : 0.92)
            border.width: 1
            border.color: a(Colors.fg, 0.06)
            visible: currentTab === "online" && onlineModel.count === 0 && !loadingSearch

            Column {
                anchors.centerIn: parent
                spacing: 20

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "󰏗"
                    color: a(Colors.fg, 0.15)
                    font { pixelSize: 56; family: "JetBrainsMono Nerd Font" }
                    opacity: 0.8
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.4; duration: 1500; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.8; duration: 1500; easing.type: Easing.InOutSine }
                    }
                }

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    Text {
                        text: L10n.tr("no_online_results", "No wallpapers found")
                        color: a(Colors.fg, 0.5)
                        font { pixelSize: 16; family: "JetBrainsMono Nerd Font"; bold: true }
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: "Try a different search term"
                        color: a(Colors.fg, 0.3)
                        font { pixelSize: 11; family: "JetBrainsMono Nerd Font" }
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    Repeater {
                        model: ["nature", "space", "abstract", "city", "dark"]

                        Rectangle {
                            width: suggText.width + 14; height: 26
                            radius: brSm
                            color: suggMa.containsMouse ? a(Colors.accent, 0.15) : a(Colors.fg, 0.05)
                            border.width: 1
                            border.color: suggMa.containsMouse ? a(Colors.accent, 0.3) : a(Colors.fg, 0.08)

                            Text {
                                id: suggText
                                anchors.centerIn: parent
                                text: modelData
                                color: suggMa.containsMouse ? Colors.accent : a(Colors.fg, 0.5)
                                font { pixelSize: 10; family: "JetBrainsMono Nerd Font" }
                            }

                            MouseArea {
                                id: suggMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    keyInput.text = modelData
                                    searching = true
                                    loadingSearch = true
                                    searchProc.runSearch(modelData, 1)
                                }
                            }
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6

                    Text {
                        text: "Press"
                        color: a(Colors.fg, 0.2)
                        font { pixelSize: 9; family: "JetBrainsMono Nerd Font" }
                    }

                    Rectangle {
                        width: slashW.width + 8; height: 18
                        radius: 3
                        color: a(Colors.fg, 0.05)
                        border.width: 1
                        border.color: a(Colors.fg, 0.08)

                        Text {
                            id: slashW
                            anchors.centerIn: parent
                            text: "/"
                            color: a(Colors.fg, 0.4)
                            font { pixelSize: 9; family: "JetBrainsMono Nerd Font" }
                        }
                    }

                    Text {
                        text: "to search"
                        color: a(Colors.fg, 0.2)
                        font { pixelSize: 9; family: "JetBrainsMono Nerd Font" }
                    }
                }
            }
        }

        // Loading more indicator (at bottom of online grid)
        Rectangle {
            anchors {
                bottom: searchBar.top
                bottomMargin: 12
                horizontalCenter: parent.horizontalCenter
            }
            width: 140
            height: 34
            radius: brSm
            color: a(Colors.bg, 0.8)
            border.width: 1
            border.color: a(Colors.fg, 0.08)
            visible: currentTab === "online" && onlineGrid._loadingMore

            Row {
                anchors.centerIn: parent
                spacing: 8

                Text {
                    text: "󰔟"
                    color: Colors.accent
                    font { pixelSize: 14; family: "JetBrainsMono Nerd Font" }
                    RotationAnimation on rotation {
                        running: currentTab === "online" && onlineGrid._loadingMore
                        from: 0; to: 360; duration: 800; loops: Animation.Infinite
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Loading more..."
                    color: Colors.fg
                    font { pixelSize: 9; family: "JetBrainsMono Nerd Font"; bold: true }
                }
            }
        }

        Rectangle {
            id: searchBar
            anchors {
                top:              sceneRoot.bottom
                topMargin:        24
                horizontalCenter: parent.horizontalCenter
            }
            width:  400
            height: 42
            radius: brSm
            color:  a(Colors.bg, 0.35)
            border.width: 1
            border.color: searching ? a(Colors.accent, 0.3) : a(Colors.fg, 0.05)
            opacity: ready ? 1 : 0
            scale:   ready ? 1 : 0.95

            Behavior on border.color { ColorAnimation  { duration: Animations.fast } }
            Behavior on radius       { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }
            Behavior on opacity      { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }
            Behavior on scale        { NumberAnimation { duration: Animations.slow;   easing.type: Easing.OutBack; easing.overshoot: Animations.springPower } }

            Row {
                anchors.fill: parent
                anchors.leftMargin:  12
                anchors.rightMargin: 12
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text:  ""
                    color: searching ? Colors.accent : a(Colors.fg, 0.3)
                    font { pixelSize: 12; family: "JetBrainsMono Nerd Font" }
                    Behavior on color { ColorAnimation { duration: Animations.fast } }
                    SequentialAnimation on scale {
                        running: searching
                        loops: Animation.Infinite
                        NumberAnimation { to: 1.1; duration: 800; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                    }
                }

                Text {
                    width: parent.width - 80
                    anchors.verticalCenter: parent.verticalCenter
                    text: keyInput.text || (searching ? "" : (currentTab === "online" ? "/ search wallhaven..." : "/ search local..."))
                    color: keyInput.text ? Colors.fg : a(Colors.fg, 0.25)
                    font { pixelSize: 11; family: "JetBrainsMono Nerd Font" }
                    elide: Text.ElideRight
                }

                Rectangle {
                    visible: searching
                    width: escHint.width + 8; height: 18
                    radius: 3
                    color: a(Colors.fg, 0.05)
                    border.width: 1
                    border.color: a(Colors.fg, 0.08)
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        id: escHint
                        anchors.centerIn: parent
                        text: "Esc"
                        color: a(Colors.fg, 0.3)
                        font { pixelSize: 8; family: "JetBrainsMono Nerd Font" }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text:    "󰅖"
                    color:   clrMa.containsMouse ? Colors.fg : a(Colors.fg, 0.3)
                    font { pixelSize: 10; family: "JetBrainsMono Nerd Font" }
                    visible: keyInput.text.length > 0
                    Behavior on color { ColorAnimation { duration: Animations.fast } }

                    MouseArea {
                        id: clrMa
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { keyInput.text = ""; keyInput.forceActiveFocus() }
                    }
                }
            }

            MouseArea {
                id: searchMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.IBeamCursor
                onClicked: {
                    if (!searching) { searching = true; keyInput.text = ""; query = "" }
                    keyInput.forceActiveFocus()
                }
            }
        }

        // Bottom Help Label
        Text {
            anchors {
                bottom: parent.bottom
                bottomMargin: 24
                horizontalCenter: parent.horizontalCenter
            }
            text: L10n.tr("wallpaper_help", "Tab: switch tabs • /: search • HJKL: navigate • Enter: select • D: delete • R: random")
            color: a(Colors.fg, 0.25)
            font { pixelSize: 9; family: "JetBrainsMono Nerd Font" }
        }

        // Delete confirmation popup
        Rectangle {
            id: deletePopup
            anchors.centerIn: parent
            width: 280
            height: 140
            radius: brCard
            color: a(Colors.bg, UIState.transparencyEnabled ? 0.95 : 1.0)
            border.width: 2
            border.color: Colors.red
            visible: showDeleteConfirm
            opacity: showDeleteConfirm ? 1 : 0
            scale: showDeleteConfirm ? 1 : 0.9

            Behavior on opacity { NumberAnimation { duration: Animations.fast; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Animations.fast; easing.type: Easing.OutBack; easing.overshoot: Animations.springPower } }

            Column {
                anchors.centerIn: parent
                spacing: 16

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "󰩺"
                        color: Colors.red
                        font { pixelSize: 28; family: "JetBrainsMono Nerd Font" }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Delete this wallpaper?"
                        color: Colors.fg
                        font { pixelSize: 13; family: "JetBrainsMono Nerd Font"; bold: true }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: pendingDeleteWall ? prettyName(pendingDeleteWall.name) : ""
                        color: a(Colors.fg, 0.5)
                        font { pixelSize: 10; family: "JetBrainsMono Nerd Font" }
                        elide: Text.ElideRight
                        width: 240
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12

                    Rectangle {
                        id: yesBtn
                        width: 80; height: 32
                        radius: brSm
                        color: yesMa.containsMouse ? a(Colors.red, 0.2) : a(Colors.fg, 0.05)
                        border.width: 1
                        border.color: yesMa.containsMouse ? Colors.red : a(Colors.fg, 0.1)

                        Text {
                            anchors.centerIn: parent
                            text: "Y - Yes"
                            color: yesMa.containsMouse ? Colors.red : Colors.fg
                            font { pixelSize: 10; family: "JetBrainsMono Nerd Font"; bold: true }
                        }

                        MouseArea {
                            id: yesMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (pendingDeleteWall) {
                                    deleteProc.deleteWallpaper(pendingDeleteWall)
                                    showDeleteConfirm = false
                                    pendingDeleteWall = null
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: noBtn
                        width: 80; height: 32
                        radius: brSm
                        color: noMa.containsMouse ? a(Colors.fg, 0.1) : a(Colors.fg, 0.05)
                        border.width: 1
                        border.color: noMa.containsMouse ? a(Colors.fg, 0.2) : a(Colors.fg, 0.1)

                        Text {
                            anchors.centerIn: parent
                            text: "N - No"
                            color: Colors.fg
                            font { pixelSize: 10; family: "JetBrainsMono Nerd Font"; bold: true }
                        }

                        MouseArea {
                            id: noMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                showDeleteConfirm = false
                                pendingDeleteWall = null
                            }
                        }
                    }
                }
            }
        }

        // Help popup with keybinds
        Rectangle {
            id: helpPopup
            anchors.centerIn: parent
            width: 340
            height: helpColumn.implicitHeight + 40
            radius: brCard
            color: a(Colors.bg, UIState.transparencyEnabled ? 0.95 : 1.0)
            border.width: 1.5
            border.color: a(Colors.accent, 0.4)
            visible: showHelp
            opacity: showHelp ? 1 : 0
            scale: showHelp ? 1 : 0.9

            Behavior on opacity { NumberAnimation { duration: Animations.fast; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Animations.fast; easing.type: Easing.OutBack; easing.overshoot: Animations.springPower } }

            Column {
                id: helpColumn
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: 20
                }
                spacing: 14

                // Header
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    Text {
                        text: ""
                        color: Colors.accent
                        font { pixelSize: 16; family: "JetBrainsMono Nerd Font" }
                    }

                    Text {
                        text: "Keyboard Shortcuts"
                        color: Colors.fg
                        font { pixelSize: 14; family: "JetBrainsMono Nerd Font"; bold: true }
                    }
                }

                // Separator
                Rectangle {
                    width: parent.width
                    height: 1
                    color: a(Colors.fg, 0.08)
                }

                // Common shortcuts section
                Text {
                    text: "Common"
                    color: Colors.accent
                    font { pixelSize: 10; family: "JetBrainsMono Nerd Font"; bold: true }
                }

                Column {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: [
                            { key: "Tab", desc: "Switch between Local / Wallhaven" },
                            { key: "/", desc: "Start search" },
                            { key: "Esc", desc: "Close popup / clear search" },
                            { key: "?", desc: "Toggle this help" }
                        ]

                        Row {
                            width: parent.width
                            spacing: 12

                            Rectangle {
                                width: 50; height: 20
                                radius: 4
                                color: a(Colors.accent, 0.12)
                                border.width: 1
                                border.color: a(Colors.accent, 0.25)

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.key
                                    color: Colors.accent
                                    font { pixelSize: 9; family: "JetBrainsMono Nerd Font"; bold: true }
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.desc
                                color: a(Colors.fg, 0.7)
                                font { pixelSize: 10; family: "JetBrainsMono Nerd Font" }
                            }
                        }
                    }
                }

                // Local tab shortcuts
                Text {
                    text: "Local Tab"
                    color: Colors.accent
                    font { pixelSize: 10; family: "JetBrainsMono Nerd Font"; bold: true }
                    visible: currentTab === "local"
                }

                Column {
                    width: parent.width
                    spacing: 6
                    visible: currentTab === "local"

                    Repeater {
                        model: [
                            { key: "H / ←", desc: "Previous wallpaper" },
                            { key: "L / →", desc: "Next wallpaper" },
                            { key: "Enter", desc: "Apply wallpaper" },
                            { key: "R", desc: "Random wallpaper" },
                            { key: "D", desc: "Delete wallpaper" }
                        ]

                        Row {
                            width: parent.width
                            spacing: 12

                            Rectangle {
                                width: 50; height: 20
                                radius: 4
                                color: a(Colors.accent, 0.12)
                                border.width: 1
                                border.color: a(Colors.accent, 0.25)

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.key
                                    color: Colors.accent
                                    font { pixelSize: 9; family: "JetBrainsMono Nerd Font"; bold: true }
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.desc
                                color: a(Colors.fg, 0.7)
                                font { pixelSize: 10; family: "JetBrainsMono Nerd Font" }
                            }
                        }
                    }
                }

                // Online tab shortcuts
                Text {
                    text: "Wallhaven Tab"
                    color: Colors.accent
                    font { pixelSize: 10; family: "JetBrainsMono Nerd Font"; bold: true }
                    visible: currentTab === "online"
                }

                Column {
                    width: parent.width
                    spacing: 6
                    visible: currentTab === "online"

                    Repeater {
                        model: [
                            { key: "HJKL", desc: "Navigate grid" },
                            { key: "Enter", desc: "Download wallpaper" },
                            { key: "Scroll", desc: "Infinite scroll loads more" },
                            { key: "F", desc: "Filters panel" }
                        ]

                        Row {
                            width: parent.width
                            spacing: 12

                            Rectangle {
                                width: 50; height: 20
                                radius: 4
                                color: a(Colors.accent, 0.12)
                                border.width: 1
                                border.color: a(Colors.accent, 0.25)

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.key
                                    color: Colors.accent
                                    font { pixelSize: 9; family: "JetBrainsMono Nerd Font"; bold: true }
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.desc
                                color: a(Colors.fg, 0.7)
                                font { pixelSize: 10; family: "JetBrainsMono Nerd Font" }
                            }
                        }
                    }
                }

                // Footer hint
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Press ? or Esc to close"
                    color: a(Colors.fg, 0.35)
                    font { pixelSize: 9; family: "JetBrainsMono Nerd Font" }
                }
            }
        }

        // Filters panel
        Rectangle {
            id: filtersPopup
            anchors.centerIn: parent
            width: 420
            height: filtersColumn.implicitHeight + 40
            radius: brCard
            color: a(Colors.bg, UIState.transparencyEnabled ? 0.95 : 1.0)
            border.width: 1.5
            border.color: a(Colors.accent, 0.4)
            visible: showFilters && currentTab === "online"
            opacity: showFilters ? 1 : 0
            scale: showFilters ? 1 : 0.9

            Behavior on opacity { NumberAnimation { duration: Animations.fast; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Animations.fast; easing.type: Easing.OutBack; easing.overshoot: Animations.springPower } }

            Flickable {
                anchors.fill: parent
                anchors.margins: 20
                contentHeight: filtersColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: filtersColumn
                    width: parent.width
                    spacing: 14

                    // Header
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8

                        Text {
                            text: ""
                            color: Colors.accent
                            font { pixelSize: 16; family: "JetBrainsMono Nerd Font" }
                        }

                        Text {
                            text: "Search Filters"
                            color: Colors.fg
                            font { pixelSize: 14; family: "JetBrainsMono Nerd Font"; bold: true }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: a(Colors.fg, 0.08) }

                    // Categories
                    Text { text: "Categories"; color: Colors.accent; font { pixelSize: 10; family: "JetBrainsMono Nerd Font"; bold: true } }
                    Row {
                        spacing: 8
                        Repeater {
                            model: [
                                { label: "General", bit: 0 },
                                { label: "Anime", bit: 1 },
                                { label: "People", bit: 2 }
                            ]
                            Rectangle {
                                width: 90; height: 28
                                radius: brSm
                                color: (parseInt(whCategories[parseInt(modelData.bit)] || "0") === 1) ? a(Colors.accent, 0.2) : a(Colors.fg, 0.05)
                                border.width: 1
                                border.color: (parseInt(whCategories[parseInt(modelData.bit)] || "0") === 1) ? Colors.accent : a(Colors.fg, 0.1)

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: (parseInt(whCategories[parseInt(modelData.bit)] || "0") === 1) ? Colors.accent : a(Colors.fg, 0.6)
                                    font { pixelSize: 10; family: "JetBrainsMono Nerd Font"; bold: true }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var bits = whCategories.split("")
                                        bits[parseInt(modelData.bit)] = bits[parseInt(modelData.bit)] === "1" ? "0" : "1"
                                        whCategories = bits.join("")
                                    }
                                }
                            }
                        }
                    }

                    // Sorting
                    Text { text: "Sort By"; color: Colors.accent; font { pixelSize: 10; family: "JetBrainsMono Nerd Font"; bold: true } }
                    Row {
                        spacing: 6
                        Repeater {
                            model: [
                                { label: "Relevance", value: "relevance" },
                                { label: "Date", value: "date_added" },
                                { label: "Views", value: "views" },
                                { label: "Favorites", value: "favorites" },
                                { label: "Toplist", value: "toplist" },
                                { label: "Random", value: "random" }
                            ]
                            Rectangle {
                                width: 60; height: 28
                                radius: brSm
                                color: whSorting === modelData.value ? a(Colors.accent, 0.2) : a(Colors.fg, 0.05)
                                border.width: 1
                                border.color: whSorting === modelData.value ? Colors.accent : a(Colors.fg, 0.1)

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: whSorting === modelData.value ? Colors.accent : a(Colors.fg, 0.6)
                                    font { pixelSize: 9; family: "JetBrainsMono Nerd Font"; bold: true }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: whSorting = modelData.value
                                }
                            }
                        }
                    }

                    // Top Range (only visible when toplist is selected)
                    Column {
                        visible: whSorting === "toplist"
                        spacing: 6
                        width: parent.width

                        Text { text: "Top Range"; color: Colors.accent; font { pixelSize: 10; family: "JetBrainsMono Nerd Font"; bold: true } }
                        Row {
                            spacing: 6
                            Repeater {
                                model: [
                                    { label: "1 Day", value: "1d" },
                                    { label: "3 Days", value: "3d" },
                                    { label: "1 Week", value: "1w" },
                                    { label: "1 Month", value: "1M" },
                                    { label: "3 Months", value: "3M" },
                                    { label: "6 Months", value: "6M" },
                                    { label: "1 Year", value: "1y" }
                                ]
                                Rectangle {
                                    width: 50; height: 26
                                    radius: brSm
                                    color: whTopRange === modelData.value ? a(Colors.accent, 0.2) : a(Colors.fg, 0.05)
                                    border.width: 1
                                    border.color: whTopRange === modelData.value ? Colors.accent : a(Colors.fg, 0.1)

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        color: whTopRange === modelData.value ? Colors.accent : a(Colors.fg, 0.6)
                                        font { pixelSize: 8; family: "JetBrainsMono Nerd Font"; bold: true }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: whTopRange = modelData.value
                                    }
                                }
                            }
                        }
                    }

                    // Min Resolution
                    Text { text: "Min Resolution"; color: Colors.accent; font { pixelSize: 10; family: "JetBrainsMono Nerd Font"; bold: true } }
                    Row {
                        spacing: 6
                        Repeater {
                            model: [
                                { label: "Any", value: "" },
                                { label: "1080p", value: "1920x1080" },
                                { label: "1440p", value: "2560x1440" },
                                { label: "4K", value: "3840x2160" },
                                { label: "8K", value: "7680x4320" }
                            ]
                            Rectangle {
                                width: 60; height: 26
                                radius: brSm
                                color: whAtleast === modelData.value ? a(Colors.accent, 0.2) : a(Colors.fg, 0.05)
                                border.width: 1
                                border.color: whAtleast === modelData.value ? Colors.accent : a(Colors.fg, 0.1)

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: whAtleast === modelData.value ? Colors.accent : a(Colors.fg, 0.6)
                                    font { pixelSize: 9; family: "JetBrainsMono Nerd Font"; bold: true }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: whAtleast = modelData.value
                                }
                            }
                        }
                    }

                    // Aspect Ratio
                    Text { text: "Aspect Ratio"; color: Colors.accent; font { pixelSize: 10; family: "JetBrainsMono Nerd Font"; bold: true } }
                    Row {
                        spacing: 6
                        Repeater {
                            model: [
                                { label: "Any", value: "" },
                                { label: "16:9", value: "16x9" },
                                { label: "16:10", value: "16x10" },
                                { label: "21:9", value: "21x9" },
                                { label: "32:9", value: "32x9" },
                                { label: "4:3", value: "4x3" },
                                { label: "5:4", value: "5x4" }
                            ]
                            Rectangle {
                                width: 50; height: 26
                                radius: brSm
                                color: whRatios === modelData.value ? a(Colors.accent, 0.2) : a(Colors.fg, 0.05)
                                border.width: 1
                                border.color: whRatios === modelData.value ? Colors.accent : a(Colors.fg, 0.1)

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: whRatios === modelData.value ? Colors.accent : a(Colors.fg, 0.6)
                                    font { pixelSize: 9; family: "JetBrainsMono Nerd Font"; bold: true }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: whRatios = modelData.value
                                }
                            }
                        }
                    }

                    // File Type
                    Text { text: "File Type"; color: Colors.accent; font { pixelSize: 10; family: "JetBrainsMono Nerd Font"; bold: true } }
                    Row {
                        spacing: 6
                        Repeater {
                            model: [
                                { label: "Any", value: "" },
                                { label: "PNG", value: "png" },
                                { label: "JPG", value: "jpg" },
                                { label: "WEBP", value: "webp" }
                            ]
                            Rectangle {
                                width: 50; height: 26
                                radius: brSm
                                color: whTypes === modelData.value ? a(Colors.accent, 0.2) : a(Colors.fg, 0.05)
                                border.width: 1
                                border.color: whTypes === modelData.value ? Colors.accent : a(Colors.fg, 0.1)

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: whTypes === modelData.value ? Colors.accent : a(Colors.fg, 0.6)
                                    font { pixelSize: 9; family: "JetBrainsMono Nerd Font"; bold: true }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: whTypes = modelData.value
                                }
                            }
                        }
                    }

                    // Apply button
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 120; height: 32
                        radius: brSm
                        color: applyFiltersMa.containsMouse ? a(Colors.accent, 0.3) : a(Colors.accent, 0.15)
                        border.width: 1.5
                        border.color: Colors.accent

                        Text {
                            anchors.centerIn: parent
                            text: "Apply Filters"
                            color: Colors.accent
                            font { pixelSize: 11; family: "JetBrainsMono Nerd Font"; bold: true }
                        }

                        MouseArea {
                            id: applyFiltersMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                showFilters = false
                                if (keyInput.text.trim().length > 0) {
                                    loadingSearch = true
                                    searchProc.runSearch(keyInput.text.trim(), 1)
                                }
                            }
                        }
                    }

                    // Footer
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Press F to toggle filters"
                        color: a(Colors.fg, 0.35)
                        font { pixelSize: 9; family: "JetBrainsMono Nerd Font" }
                    }
                }
            }
        }
    }
}