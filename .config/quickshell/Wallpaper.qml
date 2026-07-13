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
    property string onlineSearchError: ""
    property string lastOnlineQuery: ""
    property string activeDownloadId: ""
    property int downloadPercent: 0
    property string downloadState: "idle"
    property string downloadMessage: ""
    property bool onlinePreviewOpen: false
    property var onlinePreviewItem: null
    property string wallhavenScript: Quickshell.env("HOME") + "/.config/quickshell/wallhaven/wallhaven.py"
    property string livewallpaperScript: Quickshell.env("HOME") + "/.config/quickshell/livewallpaper/livewallpaper.py"
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
    readonly property int activeFilterCount:
        (whCategories !== "111" ? 1 : 0)
        + (whPurity !== "100" ? 1 : 0)
        + (whSorting !== "relevance" ? 1 : 0)
        + (whAtleast !== "" ? 1 : 0)
        + (whRatios !== "" ? 1 : 0)
        + (whTypes !== "" ? 1 : 0)

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

    function largestScreenWidth() {
        var selectedWidth = screen ? screen.width : 1920
        var selectedHeight = screen ? screen.height : 1080
        for (var index = 0; index < Quickshell.screens.length; index++) {
            var candidate = Quickshell.screens[index]
            if (candidate.width * candidate.height > selectedWidth * selectedHeight) {
                selectedWidth = candidate.width
                selectedHeight = candidate.height
            }
        }
        return selectedWidth
    }

    function largestScreenHeight() {
        var selectedWidth = screen ? screen.width : 1920
        var selectedHeight = screen ? screen.height : 1080
        for (var index = 0; index < Quickshell.screens.length; index++) {
            var candidate = Quickshell.screens[index]
            if (candidate.width * candidate.height > selectedWidth * selectedHeight) {
                selectedWidth = candidate.width
                selectedHeight = candidate.height
            }
        }
        return selectedHeight
    }

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
            onlinePreviewOpen = false
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
        onlineSearchError = ""
        lastOnlineQuery = ""
        onlinePreviewOpen = false
        onlinePreviewItem = null
        _escPressedRecently = false
        showFilters = false
    }

    function runOnlineSearch(term, page, allowEmpty) {
        var cleanTerm = term.trim()
        if (cleanTerm.length === 0 && !allowEmpty && whSorting !== "random") return

        onlineSearchError = ""
        lastOnlineQuery = cleanTerm
        if (page === 1) {
            loadingSearch = true
            onlinePreviewOpen = false
            onlinePreviewItem = null
        }
        searchProc.runSearch(cleanTerm, page)
    }

    function showRandomWallpapers() {
        whSorting = "random"
        keyInput.text = ""
        searching = false
        runOnlineSearch("", 1, true)
    }

    function selectOnlineItem(index) {
        if (index < 0 || index >= onlineModel.count) return
        var item = onlineModel.get(index)
        onlineSelected = index
        onlinePreviewItem = {
            id: item.id,
            url: item.url,
            thumbnail: item.thumbnail,
            resolution: item.resolution,
            file_size: item.file_size,
            ext: item.ext,
            tags: item.tags || [],
            views: item.views || 0,
            favorites: item.favorites || 0,
            purity: item.purity || "sfw",
            category: item.category || "general"
        }
        onlinePreviewOpen = true
    }

    function startOnlineDownload(item) {
        if (!item || activeDownloadId !== "") return
        activeDownloadId = item.id
        downloadPercent = 0
        downloadState = "downloading"
        downloadMessage = L10n.tr("wallhaven_downloading", "Downloading wallhaven-%1").replace("%1", item.id)
        onlinePreviewOpen = false
        downloadProc.downloadFile(item.url, item.id, item.ext)
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
                "mpvpaper --fork -o 'no-audio loop-file=inf hwdec=auto-safe panscan=1.0' '*' '" + path + "'"]
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
                    if (resp.error) {
                        onlineSearchError = resp.error
                        if (currentPage === 1) onlineModel.clear()
                        console.log("Search error:", resp.error)
                        return
                    }
                    if (currentPage === 1) onlineModel.clear()
                    if (currentPage === 1) onlineSelected = 0
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
                    downloadState = "success"
                    downloadMessage = L10n.tr("wallhaven_download_applied", "Wallpaper downloaded and applied")
                    downloadStatusTimer.restart()
                    
                    var filename = fullPath.substring(fullPath.lastIndexOf('/') + 1)
                    var isVideo = filename.endsWith(".mp4") || filename.endsWith(".webm")
                    applyWallpaper({ name: filename, isVideo: isVideo })
                    
                    // Reload local list
                    currentWallProc.running = true
                } else if (line.startsWith("ERROR:")) {
                    activeDownloadId = ""
                    downloadState = "error"
                    downloadMessage = L10n.tr("wallhaven_download_failed", "Download failed: %1").replace("%1", line.substring(6))
                    downloadStatusTimer.restart()
                    console.log("Download failed: " + line.substring(6))
                }
            }
        }
    }

    Timer {
        id: downloadStatusTimer
        interval: 4500
        onTriggered: {
            downloadState = "idle"
            downloadMessage = ""
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
        font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font" }
        selectByMouse: true
        readOnly: !searching

        onTextChanged: {
            query = text.toLowerCase()
            filterWalls()
        }

        Keys.onPressed: function(event) {
            if (onlinePreviewOpen) {
                if (event.key === Qt.Key_Escape) {
                    onlinePreviewOpen = false
                    event.accepted = true
                } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                           && activeDownloadId === "") {
                    startOnlineDownload(onlinePreviewItem)
                    event.accepted = true
                }
            } else if (searching) {
                if (event.key === Qt.Key_Escape) {
                    searching = false
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    searching = false
                    if (currentTab === "online" && text.trim().length > 0) {
                        runOnlineSearch(text, 1)
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
                    currentTab = currentTab === "local" ? "online" : currentTab === "online" ? "live" : "local"
                    if (currentTab === "live") liveRoot.activate()
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
                            runOnlineSearch(lastOnlineQuery, currentPage)
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
                            runOnlineSearch(lastOnlineQuery, currentPage)
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
                        if (onlineModel.count > 0) selectOnlineItem(onlineSelected)
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_R) {
                    if (currentTab === "local") pickRandom()
                    else if (currentTab === "online") showRandomWallpapers()
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
            spacing: Metrics.dp(16)
            Repeater {
                model: [
                    { name: "local", label: L10n.tr("local", "Local") },
                    { name: "online", label: "Wallhaven" },
                    { name: "live", label: L10n.tr("live_wallpapers", "Live") }
                ]

                Rectangle {
                    width:  Metrics.dp(120)
height: Metrics.dp(32)
radius: brSm
                    color:  currentTab === modelData.name ? a(Colors.accent, 0.12) : a(Colors.bg, 0.4)
                    border.width: currentTab === modelData.name ? 1.5 : 1
                    border.color: currentTab === modelData.name ? Colors.accent : a(Colors.fg, 0.08)

                    Text {
                        anchors.centerIn: parent
                        text:  modelData.label
                        color: currentTab === modelData.name ? Colors.accent : a(Colors.fg, 0.6)
                        font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font"; bold: true }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            currentTab = modelData.name
                            if (currentTab === "live") liveRoot.activate()
                            else keyInput.forceActiveFocus()
                        }
                    }
                }
            }
        }

        Rectangle {
            id: onlineToolbar
            anchors {
                top: tabRow.bottom
                topMargin: 16
                horizontalCenter: parent.horizontalCenter
            }
            width: cardW
            height: Metrics.dp(52)
radius: brCard
            color: a(Colors.bg, UIState.transparencyEnabled ? 0.72 : 0.94)
            border.width: 1
            border.color: a(Colors.fg, 0.08)
            visible: currentTab === "online"
            z: 20

            Behavior on color { ColorAnimation { duration: Animations.slow } }

            Row {
                anchors.fill: parent
                anchors.margins: Metrics.dp(7)
spacing: Metrics.dp(8)
                Rectangle {
                    width: parent.width - randomButton.width - filterButton.width - resultCount.width - 24
                    height: parent.height
                    radius: brSm
                    color: onlineSearchMa.containsMouse || searching
                        ? a(Colors.fg, 0.075)
                        : a(Colors.fg, 0.035)
                    border.width: 1
                    border.color: searching ? a(Colors.accent, 0.65) : a(Colors.fg, 0.08)

                    Behavior on color { ColorAnimation { duration: Animations.fast } }
                    Behavior on border.color { ColorAnimation { duration: Animations.fast } }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Metrics.dp(12)
anchors.rightMargin: Metrics.dp(12)
spacing: Metrics.dp(9)
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰍉"
                            color: searching ? Colors.accent : a(Colors.fg, 0.45)
                            font { pixelSize: Metrics.sp(13); family: "JetBrainsMono Nerd Font" }
                        }

                        Text {
                            width: parent.width - 58
                            anchors.verticalCenter: parent.verticalCenter
                            text: keyInput.text.length > 0
                                ? keyInput.text
                                : L10n.tr("wallhaven_search_placeholder", "Search Wallhaven…")
                            color: keyInput.text.length > 0 ? Colors.fg : a(Colors.fg, 0.38)
                            font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font" }
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Metrics.dp(22)
height: Metrics.dp(20)
radius: Metrics.dp(4)
color: a(Colors.fg, 0.05)
                            border.width: 1
                            border.color: a(Colors.fg, 0.09)

                            Text {
                                anchors.centerIn: parent
                                text: searching ? "↵" : "/"
                                color: a(Colors.fg, 0.48)
                                font { pixelSize: Metrics.sp(9); family: "JetBrainsMono Nerd Font"; bold: true }
                            }
                        }
                    }

                    MouseArea {
                        id: onlineSearchMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.IBeamCursor
                        onClicked: {
                            searching = true
                            keyInput.forceActiveFocus()
                            keyInput.selectAll()
                        }
                    }
                }

                Rectangle {
                    id: randomButton
                    width: Metrics.dp(104)
height: parent.height
                    radius: brSm
                    color: randomMa.containsMouse || whSorting === "random"
                        ? a(Colors.accent, 0.18)
                        : a(Colors.fg, 0.045)
                    border.width: 1
                    border.color: whSorting === "random"
                        ? a(Colors.accent, 0.65)
                        : a(Colors.fg, 0.09)

                    Behavior on color { ColorAnimation { duration: Animations.fast } }
                    Behavior on border.color { ColorAnimation { duration: Animations.fast } }

                    Row {
                        anchors.centerIn: parent
                        spacing: Metrics.dp(7)
                        Text {
                            text: "󰇊"
                            color: whSorting === "random" ? Colors.accent : a(Colors.fg, 0.55)
                            font { pixelSize: Metrics.sp(12); family: "JetBrainsMono Nerd Font" }
                        }

                        Text {
                            text: L10n.tr("wallhaven_random", "Random")
                            color: whSorting === "random" ? Colors.accent : a(Colors.fg, 0.65)
                            font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font"; bold: true }
                        }
                    }

                    MouseArea {
                        id: randomMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: showRandomWallpapers()
                    }
                }

                Rectangle {
                    id: filterButton
                    width: Metrics.dp(116)
height: parent.height
                    radius: brSm
                    color: filterMa.containsMouse || showFilters
                        ? a(Colors.accent, 0.18)
                        : a(Colors.fg, 0.045)
                    border.width: 1
                    border.color: showFilters || activeFilterCount > 0
                        ? a(Colors.accent, 0.65)
                        : a(Colors.fg, 0.09)

                    Behavior on color { ColorAnimation { duration: Animations.fast } }
                    Behavior on border.color { ColorAnimation { duration: Animations.fast } }

                    Row {
                        anchors.centerIn: parent
                        spacing: Metrics.dp(7)
                        Text {
                            text: "󰈲"
                            color: showFilters || activeFilterCount > 0 ? Colors.accent : a(Colors.fg, 0.55)
                            font { pixelSize: Metrics.sp(12); family: "JetBrainsMono Nerd Font" }
                        }

                        Text {
                            text: activeFilterCount > 0
                                ? L10n.tr("wallhaven_filters_count", "Filters (%1)").replace("%1", activeFilterCount)
                                : L10n.tr("wallhaven_filters", "Filters")
                            color: showFilters || activeFilterCount > 0 ? Colors.accent : a(Colors.fg, 0.65)
                            font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font"; bold: true }
                        }
                    }

                    MouseArea {
                        id: filterMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: showFilters = !showFilters
                    }
                }

                Item {
                    id: resultCount
                    width: Metrics.dp(82)
height: parent.height

                    Column {
                        anchors.centerIn: parent
                        spacing: Metrics.dp(1)
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: totalResults > 0 ? totalResults.toLocaleString(Qt.locale()) : "—"
                            color: totalResults > 0 ? Colors.fg : a(Colors.fg, 0.35)
                            font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font"; bold: true }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: L10n.tr("wallhaven_results", "results")
                            color: a(Colors.fg, 0.35)
                            font { pixelSize: Metrics.sp(8); family: "JetBrainsMono Nerd Font" }
                        }
                    }
                }
            }
        }

        LiveWallpaperTab {
            id: liveRoot
            anchors.fill: parent
            screen: wallpaper.screen
            scriptPath: livewallpaperScript
            wallpaperDir: wallDir
            active: currentTab === "live"
            ready: wallpaper.ready
            panelWidth: cardW
            panelHeight: cardH
            targetWidth: largestScreenWidth()
            targetHeight: largestScreenHeight()
            onDownloaded: path => {
                var filename = path.substring(path.lastIndexOf("/") + 1)
                applyWallpaper({ name: filename, isVideo: true })
                currentWallProc.running = true
            }
            onTabRequested: tab => {
                currentTab = tab
                keyInput.forceActiveFocus()
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
                // Keep a fixed seven-card window around the selection. Using
                // the complete wallpaper list here decoded hundreds of images
                // even though only nearby cards could ever be visible.
                model: 7

                Item {
                    id: slotItem
                    required property int index

                    property int wallIndex: selected + index - 3
                    property bool valid: wallIndex >= 0 && wallIndex < filtered.length
                    property var wallData: valid
                        ? filtered[wallIndex]
                        : ({ name: "", isGif: false, isVideo: false })
                    property real offset:    wallIndex - smoothSelected
                    property real absOffset: Math.abs(offset)
                    property bool isCenter:  valid && wallIndex === selected

                    width:  cardW
                    height: cardH
                    x:      sceneRoot.slotX(offset)
                    y:      0
                    scale:  sceneRoot.slotScale(offset)
                    opacity: sceneRoot.slotOpacity(offset)
                    visible: valid && absOffset < 3.0
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

                        property bool isGif:   slotItem.isCenter && slotItem.wallData.isGif
                        property bool isVideo: slotItem.isCenter && slotItem.wallData.isVideo

                        Image {
                            anchors.fill: parent
                            source: !slotItem.valid
                                ? ""
                                : slotItem.isCenter && !slotRect.isGif && !slotRect.isVideo
                                ? (thumbVersion > 0
                                    ? "file://" + cachePath + "/" + slotItem.wallData.name + ".thumb.jpg"
                                    : "file://" + wallDir   + "/" + slotItem.wallData.name)
                                : (!slotItem.isCenter
                                    ? sceneRoot.thumbSource(slotItem.wallIndex)
                                    : "")
                            onStatusChanged: {
                                if (status === Image.Error && slotItem.isCenter && slotItem.valid)
                                    source = "file://" + wallDir + "/" + slotItem.wallData.name
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
                                source: "file://" + wallDir + "/" + slotItem.wallData.name
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
                                    source: "file://" + wallDir + "/" + slotItem.wallData.name
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
                            height: Metrics.dp(56)
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
                                spacing: Metrics.dp(10)
                                Text {
                                    text:  prettyName(slotItem.wallData.name)
                                    color: "#fff"
                                    font { pixelSize: Metrics.sp(12); family: "JetBrainsMono Nerd Font" }
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    visible: slotItem.wallData.name === currentWall
                                    text:    "●"
                                    color:   Colors.green
                                    font { pixelSize: Metrics.sp(8); family: "JetBrainsMono Nerd Font" }
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: br
                            color:  "transparent"
                            border.width: slotItem.isCenter ? 2 : slotItem.wallData.name === currentWall ? 1.5 : 0
                            border.color: slotItem.wallData.name === currentWall ? Colors.green : Colors.accent
                            Behavior on border.color { ColorAnimation  { duration: Animations.fast } }
                            Behavior on border.width { NumberAnimation { duration: Animations.fast } }
                            Behavior on radius       { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: slotItem.valid
                        cursorShape: slotItem.isCenter ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (slotItem.isCenter) applyWallpaper(slotItem.wallData)
                            else selected = slotItem.wallIndex
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
                spacing: Metrics.dp(18)
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text:  walls.length === 0 ? "󰏗" : "󰍉"
                    color: a(Colors.fg, 0.1)
                    font { pixelSize: Metrics.sp(48); family: "JetBrainsMono Nerd Font" }
                }

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Metrics.dp(8)
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text:  walls.length === 0 ? "Scanning wallpapers" : "No results"
                        color: a(Colors.fg, 0.4)
                        font { pixelSize: Metrics.sp(14); family: "JetBrainsMono Nerd Font" }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: query !== ""
                        text:    "\"" + query + "\""
                        color:   a(Colors.fg, 0.2)
                        font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font" }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Metrics.dp(8)
visible: filtered.length === 0 && query !== ""

                    Text {
                        text: "Press"
                        color: a(Colors.fg, 0.2)
                        font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font" }
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        width:  escLbl.width + 14
                        height: Metrics.dp(20)
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
                            font { pixelSize: Metrics.sp(9); family: "JetBrainsMono Nerd Font" }
                        }
                    }

                    Text {
                        text: "to clear"
                        color: a(Colors.fg, 0.2)
                        font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font" }
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
                        runOnlineSearch(lastOnlineQuery, currentPage)
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
                        radius: Metrics.dp(10)
color: Colors.accent
                        visible: onlineSelected === index
                        z: 999

                        Text {
                            anchors.centerIn: parent
                            text: "✓"
                            color: "#fff"
                            font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font"; bold: true }
                        }
                    }

                    Image {
                        anchors.fill: parent
                        source: thumbnail
                        sourceSize.width: Math.round(gridItem.width * 1.5)
                        sourceSize.height: Math.round(gridItem.height * 1.5)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                    }

                    // Resolution badge (top-right)
                    Rectangle {
                        anchors { top: parent.top; right: parent.right; margins: 6 }
                        width: resBadge.width + 10; height: 18
                        radius: Metrics.dp(4)
color: a("#000", 0.6)
                        visible: activeDownloadId !== id

                        Text {
                            id: resBadge
                            anchors.centerIn: parent
                            text: gridItem.resolution
                            color: "#fff"
                            font { pixelSize: Metrics.sp(8); family: "JetBrainsMono Nerd Font"; bold: true }
                        }
                    }

                    // File type badge (bottom-left)
                    Rectangle {
                        anchors { bottom: parent.bottom; left: parent.left; margins: 6 }
                        width: typeBadge.width + 8; height: 16
                        radius: Metrics.dp(3)
color: a(Colors.accent, 0.85)
                        visible: activeDownloadId !== id

                        Text {
                            id: typeBadge
                            anchors.centerIn: parent
                            text: gridItem.ext.replace(".", "").toUpperCase()
                            color: "#fff"
                            font { pixelSize: Metrics.sp(7); family: "JetBrainsMono Nerd Font"; bold: true }
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
                            spacing: Metrics.dp(5)
width: parent.width - 16

                            Text {
                                text: "󰔟"
                                color: Colors.accent
                                font { pixelSize: Metrics.sp(18); family: "JetBrainsMono Nerd Font" }
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Text {
                                text: gridItem.resolution
                                color: "#fff"
                                font { pixelSize: Metrics.sp(12); family: "JetBrainsMono Nerd Font"; bold: true }
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Text {
                                text: (gridItem.file_size / (1024 * 1024)).toFixed(1) + " MB • " + gridItem.ext.replace(".", "").toUpperCase()
                                color: a("#fff", 0.7)
                                font { pixelSize: Metrics.sp(9); family: "JetBrainsMono Nerd Font" }
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: Metrics.dp(4)
visible: gridItem.tags && gridItem.tags.length > 0
                                Repeater {
                                    model: Math.min((gridItem.tags || []).length, 3)
                                    Rectangle {
                                        width: tagLabel.width + 8; height: 16
                                        radius: Metrics.dp(3)
color: a(Colors.accent, 0.25)
                                        Text {
                                            id: tagLabel
                                            anchors.centerIn: parent
                                            text: (gridItem.tags || [])[index] || ""
                                            color: Colors.accent
                                            font { pixelSize: Metrics.sp(7); family: "JetBrainsMono Nerd Font" }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: enterHint.width + 12; height: 20
                                radius: Metrics.dp(4)
color: a(Colors.accent, 0.2)
                                border.width: 1
                                border.color: a(Colors.accent, 0.4)
                                anchors.horizontalCenter: parent.horizontalCenter

                                Text {
                                    id: enterHint
                                    anchors.centerIn: parent
                                    text: L10n.tr("wallhaven_preview", "Preview") + "  ⏎"
                                    color: Colors.accent
                                    font { pixelSize: Metrics.sp(8); family: "JetBrainsMono Nerd Font" }
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
                            spacing: Metrics.dp(10)
width: parent.width - 20

                            Text {
                                id: dlIcon
                                text: "󰔟"
                                color: Colors.accent
                                font { pixelSize: Metrics.sp(22); family: "JetBrainsMono Nerd Font" }
                                anchors.horizontalCenter: parent.horizontalCenter
                                RotationAnimation on rotation {
                                    running: activeDownloadId === gridItem.id && downloadPercent < 100
                                    from: 0; to: 360; duration: 800; loops: Animation.Infinite
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: Metrics.dp(5)
radius: Metrics.dp(3)
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
                                font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font"; bold: true }
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }

                    MouseArea {
                        id: gridMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: selectOnlineItem(index)
                    }
                }
            }
        }

        // Online Loading Indicator
        Rectangle {
            anchors.centerIn: parent
            width:  Metrics.dp(180)
height: Metrics.dp(110)
radius: brCard
            color:  a(Colors.bg, UIState.transparencyEnabled ? 0.72 : 0.9)
            border.width: 1
            border.color: a(Colors.fg, 0.08)
            visible: currentTab === "online" && loadingSearch

            Column {
                anchors.centerIn: parent
                spacing: Metrics.dp(14)
                Text {
                    text: "󰔟"
                    color: Colors.accent
                    font { pixelSize: Metrics.sp(28); family: "JetBrainsMono Nerd Font" }
                    anchors.horizontalCenter: parent.horizontalCenter
                    RotationAnimation on rotation {
                        running: currentTab === "online" && loadingSearch
                        from: 0; to: 360; duration: 800; loops: Animation.Infinite
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Metrics.dp(2)
                    Text {
                        text: "Searching"
                        color: Colors.fg
                        font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font"; bold: true }
                    }

                    Text {
                        id: loadingDots
                        text: ""
                        color: Colors.fg
                        font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font"; bold: true }
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
                    font { pixelSize: Metrics.sp(9); family: "JetBrainsMono Nerd Font" }
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        // Online Empty State
        Rectangle {
            anchors.centerIn: parent
            width: Math.min(cardW * 0.7, 580)
            height: Metrics.dp(270)
radius: brCard
            color: a(Colors.bg, UIState.transparencyEnabled ? 0.78 : 0.95)
            border.width: 1
            border.color: onlineSearchError !== "" ? a(Colors.red, 0.35) : a(Colors.fg, 0.08)
            visible: currentTab === "online" && onlineModel.count === 0 && !loadingSearch

            Column {
                anchors.centerIn: parent
                width: parent.width - 48
                spacing: Metrics.dp(15)
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: onlineSearchError !== "" ? "󰅚" : lastOnlineQuery === "" ? "󰍉" : "󰏗"
                    color: onlineSearchError !== "" ? a(Colors.red, 0.72) : a(Colors.accent, 0.72)
                    font { pixelSize: Metrics.sp(38); family: "JetBrainsMono Nerd Font" }
                }

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    spacing: Metrics.dp(7)
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: onlineSearchError !== ""
                            ? L10n.tr("wallhaven_unavailable", "Could not reach Wallhaven")
                            : lastOnlineQuery === ""
                                ? L10n.tr("wallhaven_discover", "Discover a new wallpaper")
                                : L10n.tr("wallhaven_no_results_for", "No results for “%1”").replace("%1", lastOnlineQuery)
                        color: a(Colors.fg, 0.82)
                        font { pixelSize: Metrics.sp(15); family: "JetBrainsMono Nerd Font"; bold: true }
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: onlineSearchError !== ""
                            ? L10n.tr("wallhaven_retry_hint", "Check your connection and try again")
                            : lastOnlineQuery === ""
                                ? L10n.tr("wallhaven_search_hint", "Search by theme, color or mood")
                                : L10n.tr("wallhaven_change_search", "Try another term or remove some filters")
                        color: a(Colors.fg, 0.42)
                        font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font" }
                        anchors.horizontalCenter: parent.horizontalCenter
                        elide: Text.ElideRight
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Metrics.dp(8)
visible: onlineSearchError === ""

                    Repeater {
                        model: ["nature", "space", "abstract", "city"]

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
                                font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font" }
                            }

                            MouseArea {
                                id: suggMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    keyInput.text = modelData
                                    searching = false
                                    runOnlineSearch(modelData, 1)
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: retryText.implicitWidth + 26
                    height: Metrics.dp(30)
radius: brSm
                    color: retryMa.containsMouse ? a(Colors.accent, 0.25) : a(Colors.accent, 0.13)
                    border.width: 1
                    border.color: a(Colors.accent, 0.45)
                    visible: onlineSearchError !== ""

                    Text {
                        id: retryText
                        anchors.centerIn: parent
                        text: L10n.tr("wallhaven_retry", "Try again")
                        color: Colors.accent
                        font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font"; bold: true }
                    }

                    MouseArea {
                        id: retryMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: runOnlineSearch(lastOnlineQuery, 1)
                    }
                }
            }
        }

        Rectangle {
            id: onlinePreview
            anchors.centerIn: parent
            width: Math.min(cardW * 0.9, 760)
            height: Math.min(cardH * 0.78, 420)
            radius: brCard
            color: a(Colors.bg, UIState.transparencyEnabled ? 0.96 : 1.0)
            border.width: 1.5
            border.color: a(Colors.accent, 0.5)
            visible: currentTab === "online" && onlinePreviewOpen && onlinePreviewItem !== null
            z: 80

            Behavior on color { ColorAnimation { duration: Animations.slow } }

            Row {
                anchors.fill: parent
                anchors.margins: Metrics.dp(14)
spacing: Metrics.dp(18)
                Rectangle {
                    width: parent.width * 0.62
                    height: parent.height
                    radius: brSm
                    color: a(Colors.surface, 0.7)
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: onlinePreviewItem ? onlinePreviewItem.thumbnail : ""
                        sourceSize.width: Math.round(parent.width * 1.5)
                        sourceSize.height: Math.round(parent.height * 1.5)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            gradient: Gradient {
                                GradientStop { position: 0.55; color: "transparent" }
                                GradientStop { position: 1.0; color: a("#000", 0.66) }
                            }
                        }
                    }

                    Rectangle {
                        anchors { left: parent.left; bottom: parent.bottom; margins: 12 }
                        width: previewResolution.implicitWidth + 16
                        height: Metrics.dp(24)
radius: Metrics.dp(6)
color: a("#000", 0.62)

                        Text {
                            id: previewResolution
                            anchors.centerIn: parent
                            text: onlinePreviewItem ? onlinePreviewItem.resolution : ""
                            color: "#ffffff"
                            font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font"; bold: true }
                        }
                    }
                }

                Item {
                    width: parent.width - parent.spacing - (parent.width * 0.62)
                    height: parent.height

                    Column {
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: Metrics.dp(13)
                        Text {
                            text: onlinePreviewItem
                                ? "wallhaven-" + onlinePreviewItem.id
                                : "Wallhaven"
                            color: Colors.fg
                            font { pixelSize: Metrics.sp(14); family: "JetBrainsMono Nerd Font"; bold: true }
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        Text {
                            text: onlinePreviewItem
                                ? onlinePreviewItem.resolution + "  •  "
                                  + (onlinePreviewItem.file_size / (1024 * 1024)).toFixed(1) + " MB  •  "
                                  + onlinePreviewItem.ext.replace(".", "").toUpperCase()
                                : ""
                            color: a(Colors.fg, 0.56)
                            font { pixelSize: Metrics.sp(9); family: "JetBrainsMono Nerd Font" }
                            width: parent.width
                            wrapMode: Text.Wrap
                        }

                        Row {
                            spacing: Metrics.dp(7)
                            Rectangle {
                                width: categoryText.implicitWidth + 14
                                height: Metrics.dp(24)
radius: brSm
                                color: a(Colors.accent, 0.14)
                                border.width: 1
                                border.color: a(Colors.accent, 0.28)

                                Text {
                                    id: categoryText
                                    anchors.centerIn: parent
                                    text: onlinePreviewItem ? onlinePreviewItem.category : ""
                                    color: Colors.accent
                                    font { pixelSize: Metrics.sp(9); family: "JetBrainsMono Nerd Font" }
                                }
                            }

                            Rectangle {
                                width: purityText.implicitWidth + 14
                                height: Metrics.dp(24)
radius: brSm
                                color: a(Colors.fg, 0.06)
                                border.width: 1
                                border.color: a(Colors.fg, 0.1)

                                Text {
                                    id: purityText
                                    anchors.centerIn: parent
                                    text: onlinePreviewItem ? onlinePreviewItem.purity.toUpperCase() : ""
                                    color: a(Colors.fg, 0.62)
                                    font { pixelSize: Metrics.sp(9); family: "JetBrainsMono Nerd Font"; bold: true }
                                }
                            }
                        }

                        Text {
                            width: parent.width
                            text: onlinePreviewItem && onlinePreviewItem.tags.length > 0
                                ? onlinePreviewItem.tags.join("  •  ")
                                : L10n.tr("wallhaven_no_tags", "No tags")
                            color: a(Colors.fg, 0.42)
                            font { pixelSize: Metrics.sp(9); family: "JetBrainsMono Nerd Font" }
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }

                        Text {
                            text: onlinePreviewItem
                                ? "󰇾 " + onlinePreviewItem.views + "    󰋑 " + onlinePreviewItem.favorites
                                : ""
                            color: a(Colors.fg, 0.46)
                            font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font" }
                        }

                        Rectangle {
                            width: parent.width
                            height: Metrics.dp(38)
radius: brSm
                            color: downloadPreviewMa.containsMouse
                                ? a(Colors.accent, 0.3)
                                : a(Colors.accent, 0.18)
                            border.width: 1.5
                            border.color: Colors.accent

                            Text {
                                anchors.centerIn: parent
                                text: activeDownloadId === ""
                                    ? L10n.tr("wallhaven_download_apply", "Download & Apply")
                                    : L10n.tr("wallhaven_download_busy", "Download in progress…")
                                color: Colors.accent
                                font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font"; bold: true }
                            }

                            MouseArea {
                                id: downloadPreviewMa
                                anchors.fill: parent
                                enabled: activeDownloadId === ""
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: startOnlineDownload(onlinePreviewItem)
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: Metrics.dp(30)
radius: brSm
                            color: closePreviewMa.containsMouse ? a(Colors.fg, 0.09) : a(Colors.fg, 0.045)
                            border.width: 1
                            border.color: a(Colors.fg, 0.09)

                            Text {
                                anchors.centerIn: parent
                                text: L10n.tr("close", "Close") + "  Esc"
                                color: a(Colors.fg, 0.62)
                                font { pixelSize: Metrics.sp(9); family: "JetBrainsMono Nerd Font" }
                            }

                            MouseArea {
                                id: closePreviewMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: onlinePreviewOpen = false
                            }
                        }
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
            width: Metrics.dp(140)
height: Metrics.dp(34)
radius: brSm
            color: a(Colors.bg, 0.8)
            border.width: 1
            border.color: a(Colors.fg, 0.08)
            visible: currentTab === "online" && onlineGrid._loadingMore

            Row {
                anchors.centerIn: parent
                spacing: Metrics.dp(8)
                Text {
                    text: "󰔟"
                    color: Colors.accent
                    font { pixelSize: Metrics.sp(14); family: "JetBrainsMono Nerd Font" }
                    RotationAnimation on rotation {
                        running: currentTab === "online" && onlineGrid._loadingMore
                        from: 0; to: 360; duration: 800; loops: Animation.Infinite
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Loading more..."
                    color: Colors.fg
                    font { pixelSize: Metrics.sp(9); family: "JetBrainsMono Nerd Font"; bold: true }
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
            width:  Metrics.dp(400)
height: Metrics.dp(42)
radius: brSm
            color:  a(Colors.bg, 0.35)
            border.width: 1
            border.color: searching ? a(Colors.accent, 0.3) : a(Colors.fg, 0.05)
            opacity: ready ? 1 : 0
            scale:   ready ? 1 : 0.95
            visible: currentTab === "local"

            Behavior on border.color { ColorAnimation  { duration: Animations.fast } }
            Behavior on radius       { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }
            Behavior on opacity      { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }
            Behavior on scale        { NumberAnimation { duration: Animations.slow;   easing.type: Easing.OutBack; easing.overshoot: Animations.springPower } }

            Row {
                anchors.fill: parent
                anchors.leftMargin:  Metrics.dp(12)
anchors.rightMargin: Metrics.dp(12)
spacing: Metrics.dp(8)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text:  ""
                    color: searching ? Colors.accent : a(Colors.fg, 0.3)
                    font { pixelSize: Metrics.sp(12); family: "JetBrainsMono Nerd Font" }
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
                    font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font" }
                    elide: Text.ElideRight
                }

                Rectangle {
                    visible: searching
                    width: escHint.width + 8; height: 18
                    radius: Metrics.dp(3)
color: a(Colors.fg, 0.05)
                    border.width: 1
                    border.color: a(Colors.fg, 0.08)
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        id: escHint
                        anchors.centerIn: parent
                        text: "Esc"
                        color: a(Colors.fg, 0.3)
                        font { pixelSize: Metrics.sp(8); family: "JetBrainsMono Nerd Font" }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text:    "󰅖"
                    color:   clrMa.containsMouse ? Colors.fg : a(Colors.fg, 0.3)
                    font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font" }
                    visible: keyInput.text.length > 0
                    Behavior on color { ColorAnimation { duration: Animations.fast } }

                    MouseArea {
                        id: clrMa
                        anchors.fill: parent
                        anchors.margins: Metrics.dp(-6)
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

        Rectangle {
            id: downloadStatus
            anchors {
                bottom: parent.bottom
                bottomMargin: 54
                horizontalCenter: parent.horizontalCenter
            }
            width: Math.min(statusRow.implicitWidth + 34, cardW)
            height: Metrics.dp(42)
radius: brSm
            color: a(Colors.bg, UIState.transparencyEnabled ? 0.92 : 1.0)
            border.width: 1
            border.color: downloadState === "error"
                ? a(Colors.red, 0.62)
                : downloadState === "success"
                    ? a(Colors.green, 0.62)
                    : a(Colors.accent, 0.62)
            visible: currentTab === "online" && downloadState !== "idle"
            z: 90

            Row {
                id: statusRow
                anchors.centerIn: parent
                spacing: Metrics.dp(10)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: downloadState === "error" ? "󰅚" : downloadState === "success" ? "󰄬" : "󰇚"
                    color: downloadState === "error" ? Colors.red : downloadState === "success" ? Colors.green : Colors.accent
                    font { pixelSize: Metrics.sp(14); family: "JetBrainsMono Nerd Font" }

                    RotationAnimation on rotation {
                        running: downloadState === "downloading"
                        from: 0
                        to: 360
                        duration: 850
                        loops: Animation.Infinite
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: downloadState === "downloading"
                        ? downloadMessage + "  " + downloadPercent + "%"
                        : downloadMessage
                    color: Colors.fg
                    font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font"; bold: true }
                    elide: Text.ElideRight
                    maximumLineCount: 1
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
            text: currentTab === "online"
                ? L10n.tr("wallhaven_help", "Arrows/HJKL: navigate • Enter: preview • F: filters • /: search")
                : L10n.tr("wallpaper_help", "Tab: switch tabs • /: search • HJKL: navigate • Enter: select • D: delete • R: random")
            color: a(Colors.fg, 0.25)
            font { pixelSize: Metrics.sp(9); family: "JetBrainsMono Nerd Font" }
        }

        // Delete confirmation popup
        Rectangle {
            id: deletePopup
            anchors.centerIn: parent
            width: Metrics.dp(280)
height: Metrics.dp(140)
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
                spacing: Metrics.dp(16)
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Metrics.dp(8)
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "󰩺"
                        color: Colors.red
                        font { pixelSize: Metrics.sp(28); family: "JetBrainsMono Nerd Font" }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Delete this wallpaper?"
                        color: Colors.fg
                        font { pixelSize: Metrics.sp(13); family: "JetBrainsMono Nerd Font"; bold: true }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: pendingDeleteWall ? prettyName(pendingDeleteWall.name) : ""
                        color: a(Colors.fg, 0.5)
                        font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font" }
                        elide: Text.ElideRight
                        width: Metrics.dp(240)
horizontalAlignment: Text.AlignHCenter
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Metrics.dp(12)
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
                            font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font"; bold: true }
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
                            font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font"; bold: true }
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
            width: Metrics.dp(340)
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
                spacing: Metrics.dp(14)
                // Header
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Metrics.dp(8)
                    Text {
                        text: ""
                        color: Colors.accent
                        font { pixelSize: Metrics.sp(16); family: "JetBrainsMono Nerd Font" }
                    }

                    Text {
                        text: "Keyboard Shortcuts"
                        color: Colors.fg
                        font { pixelSize: Metrics.sp(14); family: "JetBrainsMono Nerd Font"; bold: true }
                    }
                }

                // Separator
                Rectangle {
                    width: parent.width
                    height: Metrics.dp(1)
color: a(Colors.fg, 0.08)
                }

                // Common shortcuts section
                Text {
                    text: "Common"
                    color: Colors.accent
                    font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font"; bold: true }
                }

                Column {
                    width: parent.width
                    spacing: Metrics.dp(6)
                    Repeater {
                        model: [
                            { key: "Tab", desc: "Switch between Local / Wallhaven" },
                            { key: "/", desc: "Start search" },
                            { key: "Esc", desc: "Close popup / clear search" },
                            { key: "?", desc: "Toggle this help" }
                        ]

                        Row {
                            width: parent.width
                            spacing: Metrics.dp(12)
                            Rectangle {
                                width: 50; height: 20
                                radius: Metrics.dp(4)
color: a(Colors.accent, 0.12)
                                border.width: 1
                                border.color: a(Colors.accent, 0.25)

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.key
                                    color: Colors.accent
                                    font { pixelSize: Metrics.sp(9); family: "JetBrainsMono Nerd Font"; bold: true }
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.desc
                                color: a(Colors.fg, 0.7)
                                font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font" }
                            }
                        }
                    }
                }

                // Local tab shortcuts
                Text {
                    text: "Local Tab"
                    color: Colors.accent
                    font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font"; bold: true }
                    visible: currentTab === "local"
                }

                Column {
                    width: parent.width
                    spacing: Metrics.dp(6)
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
                            spacing: Metrics.dp(12)
                            Rectangle {
                                width: 50; height: 20
                                radius: Metrics.dp(4)
color: a(Colors.accent, 0.12)
                                border.width: 1
                                border.color: a(Colors.accent, 0.25)

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.key
                                    color: Colors.accent
                                    font { pixelSize: Metrics.sp(9); family: "JetBrainsMono Nerd Font"; bold: true }
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.desc
                                color: a(Colors.fg, 0.7)
                                font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font" }
                            }
                        }
                    }
                }

                // Online tab shortcuts
                Text {
                    text: "Wallhaven Tab"
                    color: Colors.accent
                    font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font"; bold: true }
                    visible: currentTab === "online"
                }

                Column {
                    width: parent.width
                    spacing: Metrics.dp(6)
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
                            spacing: Metrics.dp(12)
                            Rectangle {
                                width: 50; height: 20
                                radius: Metrics.dp(4)
color: a(Colors.accent, 0.12)
                                border.width: 1
                                border.color: a(Colors.accent, 0.25)

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.key
                                    color: Colors.accent
                                    font { pixelSize: Metrics.sp(9); family: "JetBrainsMono Nerd Font"; bold: true }
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.desc
                                color: a(Colors.fg, 0.7)
                                font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font" }
                            }
                        }
                    }
                }

                // Footer hint
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Press ? or Esc to close"
                    color: a(Colors.fg, 0.35)
                    font { pixelSize: Metrics.sp(9); family: "JetBrainsMono Nerd Font" }
                }
            }
        }

        // Filters panel
        Rectangle {
            id: filtersPopup
            anchors.centerIn: parent
            width: Metrics.dp(420)
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
                anchors.margins: Metrics.dp(20)
contentHeight: filtersColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: filtersColumn
                    width: parent.width
                    spacing: Metrics.dp(14)
                    // Header
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Metrics.dp(8)
                        Text {
                            text: ""
                            color: Colors.accent
                            font { pixelSize: Metrics.sp(16); family: "JetBrainsMono Nerd Font" }
                        }

                        Text {
                            text: "Search Filters"
                            color: Colors.fg
                            font { pixelSize: Metrics.sp(14); family: "JetBrainsMono Nerd Font"; bold: true }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: a(Colors.fg, 0.08) }

                    // Categories
                    Text { text: "Categories"; color: Colors.accent; font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font"; bold: true } }
                    Row {
                        spacing: Metrics.dp(8)
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
                                    font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font"; bold: true }
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
                    Text { text: "Sort By"; color: Colors.accent; font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font"; bold: true } }
                    Row {
                        spacing: Metrics.dp(6)
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
                                    font { pixelSize: Metrics.sp(9); family: "JetBrainsMono Nerd Font"; bold: true }
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
                        spacing: Metrics.dp(6)
width: parent.width

                        Text { text: "Top Range"; color: Colors.accent; font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font"; bold: true } }
                        Row {
                            spacing: Metrics.dp(6)
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
                                        font { pixelSize: Metrics.sp(8); family: "JetBrainsMono Nerd Font"; bold: true }
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
                    Text { text: "Min Resolution"; color: Colors.accent; font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font"; bold: true } }
                    Row {
                        spacing: Metrics.dp(6)
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
                                    font { pixelSize: Metrics.sp(9); family: "JetBrainsMono Nerd Font"; bold: true }
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
                    Text { text: "Aspect Ratio"; color: Colors.accent; font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font"; bold: true } }
                    Row {
                        spacing: Metrics.dp(6)
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
                                    font { pixelSize: Metrics.sp(9); family: "JetBrainsMono Nerd Font"; bold: true }
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
                    Text { text: "File Type"; color: Colors.accent; font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font"; bold: true } }
                    Row {
                        spacing: Metrics.dp(6)
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
                                    font { pixelSize: Metrics.sp(9); family: "JetBrainsMono Nerd Font"; bold: true }
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
                            font { pixelSize: Metrics.sp(11); family: "JetBrainsMono Nerd Font"; bold: true }
                        }

                        MouseArea {
                            id: applyFiltersMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                showFilters = false
                                if (keyInput.text.trim().length > 0) {
                                    runOnlineSearch(keyInput.text, 1)
                                }
                            }
                        }
                    }

                    // Footer
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Press F to toggle filters"
                        color: a(Colors.fg, 0.35)
                        font { pixelSize: Metrics.sp(9); family: "JetBrainsMono Nerd Font" }
                    }
                }
            }
        }
    }
}
