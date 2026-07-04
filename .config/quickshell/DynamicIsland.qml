import QtQml.Models
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.UPower

Scope {
    id: root

    property string mode: "idle"
    property string appName: "Kamalen Shell"
    property string title: "Pronto"
    property string body: "Aguardando sinal..."
    property string artist: ""
    property string artUrl: ""
    property int volume: UIState.volume
    property bool muted: UIState.muted
    property bool volumeIndicatorVisible: false
    property bool playing: UIState.mediaState === "playing"
    property bool pointerInside: false
    property bool pinnedOpen: false
    property bool mediaHoverSuppressed: false
    property date currentDateTime: new Date()
    property string handleStyle: "bump"
    
    // Bindings de Mídia baseados no UIState do Kamalen
    readonly property bool mediaAvailable: UIState.hasMedia && UIState.mediaState !== "stopped"
    readonly property bool mediaCanGoPrevious: true
    readonly property bool mediaCanTogglePlaying: true
    readonly property bool mediaCanGoNext: true
    readonly property real mediaPosition: UIState.mediaPos
    readonly property real mediaLength: UIState.mediaLen
    readonly property bool mediaShuffleSupported: false
    readonly property bool mediaShuffleActive: false
    readonly property bool mediaLoopSupported: false
    readonly property string mediaLoopStateText: "OFF"
    readonly property bool mediaLoopActive: false
    readonly property bool mediaCanSeek: UIState.mediaLen > 0

    // WiFi
    property string wifiSsid: ""
    property int wifiSignal: 0
    readonly property bool wifiConnected: wifiSsid !== "" && wifiSsid !== "--"

    // Bluetooth
    property string btDeviceName: ""
    property int btBattery: -1
    readonly property bool btEnabled: true
    readonly property bool btConnected: btDeviceName !== ""

    // Workspace
    property int workspace: 1
    property var workspaceOccupied: [false,false,false,false,false]
    property string focusedApp: ""

    // Launcher
    property string launcherQuery: ""
    property int launcherSelected: 0
    property var launcherApps: []
    property var launcherFiltered: []
    property var _launcherAppsBuild: []

    readonly property bool interactionOpen: root.mode === "idle" && (root.pointerInside || root.pinnedOpen)
    readonly property bool trayVisible: root.handleStyle === "bump" && !root.interactionOpen && root.visualMode === "idle"
    readonly property bool hoverMediaMode: root.mode === "idle" && root.interactionOpen && !root.mediaHoverSuppressed && root.mediaAvailable
    readonly property string visualMode: root.hoverMediaMode ? "media" : root.mode

    readonly property int reservedZone: root.handleStyle === "strip" ? 0 : 24
    readonly property int windowHeight: 136
    readonly property int bumpWidth: 304
    readonly property int bumpHeight: 44
    readonly property int launcherWidth: 520
    readonly property int launcherHeight: 380
    readonly property int stripWidth: 98
    readonly property int stripHeight: 4
    readonly property int peekWidth: 442
    readonly property int peekHeight: 172
    readonly property int notifyWidth: 438
    readonly property int notifyHeight: 74
    readonly property int mediaWidth: 380
    readonly property int mediaHeight: 132
    readonly property string fontFamily: "JetBrainsMono Nerd Font"

    readonly property string batteryHoverText: root.batteryAvailable() ? (root.batteryPluggedIn() ? "CHG " : "BAT ") + root.batteryLevel() + "%" : ""
    readonly property string hoverTimeText: root.formatClockTime(root.currentDateTime)
    readonly property string hoverDateText: root.formatClockDate(root.currentDateTime)

    function a(c, o) { return Qt.rgba(c.r, c.g, c.b, o) }

    function targetWidth() {
        switch (root.visualMode) {
        case "notify":
            return root.notifyWidth;
        case "media":
            return root.mediaWidth;
        case "launcher":
            return root.launcherWidth;
        default:
            if (root.interactionOpen)
                return root.peekWidth;
            return root.handleStyle === "strip" ? root.stripWidth : root.bumpWidth;
        }
    }

    function targetHeight() {
        switch (root.visualMode) {
        case "notify":
            return root.notifyHeight;
        case "media":
            return root.mediaHeight;
        case "launcher":
            return root.launcherHeight;
        default:
            if (root.interactionOpen)
                return root.peekHeight;
            return root.handleStyle === "strip" ? root.stripHeight : root.bumpHeight;
        }
    }

    function targetY() {
        return root.visualMode === "idle" && !root.interactionOpen ? 0 : 0;
    }

    function hold(milliseconds) {
        collapseTimer.interval = milliseconds;
        collapseTimer.restart();
    }

    function keepInteractionOpen() {
        hoverLeaveTimer.stop();
        root.pointerInside = true;
        if (root.mediaAvailable) {
            root.artist = UIState.mediaArtist;
            root.title = UIState.mediaTitle;
            root.artUrl = UIState.mediaArtUrl;
        }
    }

    function scheduleInteractionClose() {
        if (!root.pinnedOpen)
            hoverLeaveTimer.restart();
    }

    function boolFromIpc(value) {
        return value === true || value === "true" || value === "1" || value === "on" || value === "yes";
    }

    function pad2(value) {
        return value < 10 ? "0" + value : String(value);
    }

    function formatClockTime(value) {
        const date = new Date(value);
        return root.pad2(date.getHours()) + ":" + root.pad2(date.getMinutes());
    }

    function formatClockDate(value) {
        const date = new Date(value);
        const shortDays = ["DOM", "SEG", "TER", "QUA", "QUI", "SEX", "SAB"];
        const day = date.getDay();
        return root.pad2(date.getDate()) + "." + root.pad2(date.getMonth() + 1) + "." + date.getFullYear() + ", " + shortDays[day];
    }

    function showIdle() {
        collapseTimer.stop();
        root.mode = "idle";
        root.pinnedOpen = false;
        root.title = "Pronto";
        root.body = "Aguardando sinal...";
    }

    function setHandleStyle(style) {
        if (style === "strip" || style === "bump")
            root.handleStyle = style;
    }

    function toggleHandleStyle() {
        root.handleStyle = root.handleStyle === "strip" ? "bump" : "strip";
    }

    function showNotification(summary, message, app) {
        root.appName = app || "Notificação";
        root.title = summary || "Nova notificação";
        root.body = message || "";
        root.artUrl = "";
        root.mode = "notify";
        root.hold(5200);
    }

    function showMedia(trackTitle, trackArtist, isPlaying, trackArtUrl) {
        root.title = trackTitle || "Faixa Desconhecida";
        root.artist = trackArtist || "Artista Desconhecido";
        root.artUrl = trackArtUrl || "";
        root.playing = isPlaying;
        root.mode = "media";
        root.hold(6200);
    }

    function showVolume(level, isMuted) {
        root.volume = Math.max(0, Math.min(100, Number(level)));
        root.muted = isMuted;
        root.title = root.muted ? "Mudo" : "Volume";
        root.volumeIndicatorVisible = true;
        volumeIndicatorTimer.restart();
        if (root.mode !== "media" && root.mode !== "notify" && !root.interactionOpen) {
            root.mode = "idle";
            root.hold(2000);
        }
    }

    function showBrightness(level) {
        root.volume = Math.max(0, Math.min(100, Number(level)));
        root.muted = false;
        root.title = "Brilho";
        root.volumeIndicatorVisible = true;
        volumeIndicatorTimer.restart();
        if (root.mode !== "media" && root.mode !== "notify" && !root.interactionOpen) {
            root.mode = "idle";
            root.hold(2000);
        }
    }

    // ── Launcher ──────────────────────────────────────────────────────
    function openLauncher() {
        root.mode = "launcher";
        root.pinnedOpen = false;
        root.launcherQuery = "";
        root.launcherSelected = 0;
        if (root.launcherApps.length === 0)
            launcherAppsProc.running = true;
        else {
            root.updateLauncherTopApps();
            root.filterLauncherApps();
        }
    }

    function closeLauncher() {
        if (root.mode === "launcher") {
            root.launcherQuery = "";
            root.mode = "idle";
        }
    }

    function updateLauncherTopApps() {
        var sorted = root.launcherApps.slice().sort((a, b) => {
            return UIState.getAppScore(b.id) - UIState.getAppScore(a.id);
        });
        root.launcherTopApps = sorted.slice(0, 8);
    }

    function filterLauncherApps() {
        if (root.launcherQuery === "") {
            root.updateLauncherTopApps();
            root.launcherFiltered = [];
        } else {
            var q = root.launcherQuery.toLowerCase();
            var matches = root.launcherApps.filter(function(app) {
                var name = (app.name || "").toLowerCase();
                var desc = (app.desc || "").toLowerCase();
                return name.includes(q) || desc.includes(q);
            });
            matches.sort(function(a, b) {
                var sa = UIState.getAppScore(a.id);
                var sb = UIState.getAppScore(b.id);
                var na = a.name.toLowerCase();
                var nb = b.name.toLowerCase();
                var startsA = na.startsWith(q) ? 1000 : 0;
                var startsB = nb.startsWith(q) ? 1000 : 0;
                return (sb + startsB) - (sa + startsA);
            });
            root.launcherFiltered = matches;
        }
        root.launcherSelected = 0;
    }

    function launchLauncherApp(app) {
        if (!app) return;
        UIState.recordAppLaunch(app.id);
        launcherLaunchProc.command = ["bash", "-c", app.exec + " &"];
        launcherLaunchProc.running = true;
        UIState.closeDropdowns();
    }

    function moveLauncherSelection(delta) {
        if (root.launcherQuery === "") {
            var max = root.launcherTopApps.length;
            if (delta === 1 && root.launcherSelected < max - 1) root.launcherSelected++;
            else if (delta === -1 && root.launcherSelected > 0) root.launcherSelected--;
            else if (delta === 4 && root.launcherSelected + 4 < max) root.launcherSelected += 4;
            else if (delta === -4 && root.launcherSelected - 4 >= 0) root.launcherSelected -= 4;
        } else {
            var len = root.launcherFiltered.length;
            if (len === 0) return;
            var newSel = root.launcherSelected + delta;
            if (newSel < 0) newSel = 0;
            if (newSel >= len) newSel = len - 1;
            root.launcherSelected = newSel;
        }
    }

    Process {
        id: launcherAppsProc
        command: ["bash", "-c", [
            "shopt -s nullglob",
            "for f in /usr/share/applications/*.desktop \"$HOME\"/.local/share/applications/*.desktop /var/lib/flatpak/exports/share/applications/*.desktop; do",
            "  grep -q '^NoDisplay=true' \"$f\" && continue",
            "  grep -q '^Hidden=true' \"$f\" && continue",
            "  grep -q '^Type=Application' \"$f\" || continue",
            "  name=$(grep -m1 '^Name=' \"$f\" | cut -d= -f2-)",
            "  exec=$(grep -m1 '^Exec=' \"$f\" | cut -d= -f2- | sed 's/ %[fFuUdDnNickvm]//g')",
            "  icon=$(grep -m1 '^Icon=' \"$f\" | cut -d= -f2-)",
            "  desc=$(grep -m1 '^Comment=' \"$f\" | cut -d= -f2-)",
            "  id=$(basename \"$f\")",
            "  [ -z \"$name\" ] && continue",
            "  [ -z \"$exec\" ] && continue",
            "  printf '%s\\t%s\\t%s\\t%s\\t%s\\n' \"$id\" \"$name\" \"$exec\" \"$icon\" \"$desc\"",
            "done"
        ].join("\n")]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (line.length === 0) return;
                var p = line.split("\t");
                if (p.length >= 3) {
                    root._launcherAppsBuild.push({
                        id:   p[0],
                        name: p[1],
                        exec: p[2],
                        icon: p[3] || "",
                        desc: p[4] || ""
                    });
                }
            }
        }
        onExited: {
            var seen = {};
            var result = [];
            for (var i = 0; i < root._launcherAppsBuild.length; i++) {
                if (!seen[root._launcherAppsBuild[i].name]) {
                    seen[root._launcherAppsBuild[i].name] = true;
                    result.push(root._launcherAppsBuild[i]);
                }
            }
            root.launcherApps = result;
            root._launcherAppsBuild = [];
            root.updateLauncherTopApps();
            root.filterLauncherApps();
        }
    }

    Process { id: launcherLaunchProc }

    function batteryAvailable() {
        return UPower.displayDevice?.isLaptopBattery ?? false;
    }

    function batteryLevel() {
        return Math.max(0, Math.min(100, Math.round((UPower.displayDevice?.percentage ?? 1) * 100)));
    }

    function batteryPluggedIn() {
        const chargeState = UPower.displayDevice?.state;
        return chargeState === UPowerDeviceState.Charging || chargeState === UPowerDeviceState.PendingCharge;
    }

    function focusedScreen() {
        const focusedMonitor = Hyprland.focusedMonitor;
        if (focusedMonitor) {
            for (let i = 0; i < Quickshell.screens.length; i += 1) {
                if (Quickshell.screens[i].name === focusedMonitor.name)
                    return Quickshell.screens[i];
            }
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    Timer {
        id: collapseTimer
        repeat: false
        onTriggered: root.showIdle()
    }

    Timer {
        id: hoverLeaveTimer
        interval: 140
        repeat: false
        onTriggered: root.pointerInside = false
    }

    Timer {
        id: volumeIndicatorTimer
        interval: 1800
        repeat: false
        onTriggered: root.volumeIndicatorVisible = false
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.currentDateTime = new Date()
    }

    // Polling de rede Wifi e Bluetooth leve
    Timer {
        interval: 3000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!wifiPollProc.running)
                wifiPollProc.exec(["sh", "-c", "if nmcli -t -f active,ssid dev wifi 2>/dev/null | grep -q '^yes:'; then nmcli -t -f active,ssid,signal dev wifi 2>/dev/null | grep '^yes:' | head -1 | awk -F: '{printf \"%s\\t%s\\n\", $2, $3}'; elif nmcli -t -f type,state dev 2>/dev/null | grep -q '^ethernet:conectado\\|^ethernet:connected'; then echo -e \"Ethernet\\t100\"; else echo -e \"\\t0\"; fi"]);
            if (!btPollProc.running)
                btPollProc.exec(["sh", "-c", "dev=$(bluetoothctl devices Connected 2>/dev/null | head -1 | cut -d' ' -f3-); [ -z \"$dev\" ] && printf '\\t\\n' && exit 0; bat=$(bluetoothctl info 2>/dev/null | sed -n 's/.*Battery Percentage: 0x[0-9a-f]* (\\([0-9]*\\)).*/\\1/p'); printf '%s\\t%s\\n' \"$dev\" \"$bat\""]);
        }
    }

    Process {
        id: wifiPollProc
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split("\t");
                root.wifiSsid = parts[0] === "" || parts[0] === "--" ? "" : parts[0];
                root.wifiSignal = parts.length > 1 ? parseInt(parts[1]) || 0 : 0;
            }
        }
    }

    Process {
        id: btPollProc
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split("\t");
                root.btDeviceName = parts[0] || "";
                root.btBattery = parts.length > 1 ? parseInt(parts[1]) || -1 : -1;
            }
        }
    }

    // ── Workspace & Focused Window Tracking ──────────────────────────
    function parseTagOutput(data) {
        if (!data || data.trim() === "") return;
        try {
            var json = JSON.parse(data.trim());
            if (json.all_tags && json.all_tags.length > 0) {
                var tags = json.all_tags[0].tags;
                var newOcc = [false,false,false,false,false];
                for (var i = 0; i < tags.length; i++) {
                    var t = tags[i];
                    var n = t.index;
                    if (n >= 1 && n <= 5) {
                        if (t.is_active) root.workspace = n;
                        newOcc[n - 1] = t.client_count > 0;
                    }
                }
                root.workspaceOccupied = newOcc;
            }
        } catch (e) {
            console.error("DI: Failed to parse tag output:", e);
        }
    }

    function parseFocusOutput(data) {
        if (!data || data.trim() === "") return;
        try {
            var json = JSON.parse(data.trim());
            if (json.app_id) root.focusedApp = json.app_id;
            else if (json.name) root.focusedApp = json.name;
        } catch (e) {}
    }

    Process {
        id: tagWatch
        command: ["mmsg", "watch", "all-tags"]
        running: true
        stdout: SplitParser { splitMarker: "\n"; onRead: data => parseTagOutput(data) }
        onExited: tagWatchRestart.start()
    }
    Timer { id: tagWatchRestart; interval: 1000; onTriggered: tagWatch.running = true }

    Process {
        id: tagGet
        command: ["mmsg", "get", "all-tags"]
        running: true
        stdout: SplitParser { splitMarker: "\n"; onRead: data => parseTagOutput(data) }
    }

    Process { id: tagSet }

    Process {
        id: focusWatch
        command: ["mmsg", "watch", "focused-window"]
        running: true
        stdout: SplitParser { splitMarker: "\n"; onRead: data => parseFocusOutput(data) }
        onExited: focusWatchRestart.start()
    }
    Timer { id: focusWatchRestart; interval: 1000; onTriggered: focusWatch.running = true }

    Process {
        id: focusGet
        command: ["mmsg", "get", "focused-window"]
        running: true
        stdout: SplitParser { splitMarker: "\n"; onRead: data => parseFocusOutput(data) }
    }

    // Conectores de Sistema Reativos do Kamalen
    Connections {
        target: UIState

        function onActiveDropdownChanged() {
            if (UIState.activeDropdown === "launcher" && root.mode !== "launcher")
                root.openLauncher();
            else if (UIState.activeDropdown !== "launcher" && root.mode === "launcher")
                root.closeLauncher();
        }

        function onVolumeChanged() {
            root.showVolume(UIState.volume, UIState.muted);
        }
        
        function onMutedChanged() {
            root.showVolume(UIState.volume, UIState.muted);
        }
        
        function onBrightnessChanged() {
            root.showBrightness(UIState.brightness);
        }

        function onNotificationReceived(nid, app, title, body) {
            root.showNotification(title, body, app);
        }

        function onMediaStateChanged() {
            if (UIState.mediaState === "playing") {
                root.showMedia(UIState.mediaTitle, UIState.mediaArtist, true, UIState.mediaArtUrl);
            }
        }

        function onMediaTitleChanged() {
            if (UIState.mediaState === "playing") {
                root.showMedia(UIState.mediaTitle, UIState.mediaArtist, true, UIState.mediaArtUrl);
            }
        }
    }

    PanelWindow {
        id: islandWindow

        screen: root.focusedScreen()
        color: "transparent"
        exclusiveZone: root.visualMode === "launcher" ? root.launcherHeight + 8 : root.reservedZone
        exclusionMode: ExclusionMode.Normal
        implicitHeight: root.visualMode === "launcher" ? root.launcherHeight + 8 : root.windowHeight
        visible: UIState.activeDropdown !== "dashboard" && !UIState.lockedState

        WlrLayershell.namespace: "kamalen-island"
        WlrLayershell.layer: root.visualMode === "launcher" ? WlrLayer.Overlay : WlrLayer.Top
        WlrLayershell.keyboardFocus: root.visualMode === "launcher" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        anchors {
            top: true
            left: true
            right: true
        }

        mask: Region {
            item: interactionMask
        }

        Item {
            anchors.fill: parent

            Item {
                id: interactionMask

                readonly property real maskPadding: 8
                readonly property real islandRightEdge: island.x + island.width
                readonly property real islandBottomEdge: island.y + island.height
                readonly property real leftEdge: island.x
                readonly property real rightEdge: islandRightEdge
                readonly property real bottomEdge: islandBottomEdge

                x: Math.max(0, leftEdge - maskPadding)
                y: Math.max(0, island.y - maskPadding)
                width: Math.min(parent.width - x, rightEdge - x + maskPadding)
                height: Math.min(parent.height - y, bottomEdge - y + maskPadding)
            }

            IslandSurface {
                id: island

                anchors.horizontalCenter: parent.horizontalCenter
                y: root.targetY()
                width: root.targetWidth()
                height: root.targetHeight()
                mode: root.visualMode
                handleStyle: root.handleStyle
                forceExpanded: root.interactionOpen
                appName: root.appName
                title: root.title
                body: root.body
                artist: root.artist
                artUrl: root.artUrl
                volume: root.volume
                muted: root.muted
                volumeIndicatorVisible: root.volumeIndicatorVisible
                playing: root.playing
                canGoPrevious: root.mediaCanGoPrevious
                canTogglePlaying: root.mediaCanTogglePlaying
                canGoNext: root.mediaCanGoNext
                canSeek: root.mediaCanSeek
                shuffleActive: root.mediaShuffleActive
                shuffleSupported: root.mediaShuffleSupported
                loopStateText: root.mediaLoopStateText
                loopActive: root.mediaLoopActive
                loopSupported: root.mediaLoopSupported
                mediaPosition: root.mediaPosition
                mediaLength: root.mediaLength
                mediaAvailable: root.mediaAvailable
                fontFamily: root.fontFamily
                batteryHoverText: root.batteryHoverText
                batteryCharging: root.batteryPluggedIn()
                batteryLevel: root.batteryLevel()
                wifiConnected: root.wifiConnected
                wifiSsid: root.wifiSsid
                wifiSignal: root.wifiSignal
                btEnabled: root.btEnabled
                btConnected: root.btConnected
                btDeviceName: root.btDeviceName
                btBattery: root.btBattery
                workspace: root.workspace
                workspaceOccupied: root.workspaceOccupied
                focusedApp: root.focusedApp
                timeText: root.hoverTimeText
                dateText: root.hoverDateText
                launcherQuery: root.launcherQuery
                launcherSelected: root.launcherSelected
                launcherTopApps: root.launcherTopApps
                launcherFiltered: root.launcherFiltered

                onPreviousRequested: UIState.doMedia("previous")
                onPlayPauseRequested: UIState.doMedia("play-pause")
                onNextRequested: UIState.doMedia("next")
                onShuffleRequested: UIState.doMedia("shuffle") // Se suportado pelo player
                onLoopRequested: UIState.doMedia("loop-cycle")
                onFavoriteRequested: {
                    // Feedback de favoritar
                }
                onDismissRequested: {
                    root.mediaHoverSuppressed = true;
                    root.showIdle();
                }
                onWifiSettingsRequested: wifiSettingsProc.exec(["sh", "-c", "kitty --title 'WiFi Settings' nmtui-connect &"])
                onBtSettingsRequested: btSettingsProc.exec(["sh", "-c", "bluedevil-wizard &"])
                onSeekRequested: position => UIState.seekMedia(position)
                onHandleStyleRequested: style => root.setHandleStyle(style)
                onLauncherSearchChanged: query => {
                    root.launcherQuery = query;
                    root.filterLauncherApps();
                }
                onLauncherCloseRequested: root.closeLauncher()
                onLauncherAppLaunchRequested: app => root.launchLauncherApp(app)
                onLauncherMoveSelectionRequested: delta => root.moveLauncherSelection(delta)
                onWorkspaceSwitchRequested: index => {
                    tagSet.command = ["mmsg", "set", "focused-tag", String(index)]
                    tagSet.running = true
                }
            }

            Process { id: wifiSettingsProc }
            Process { id: btSettingsProc }

            MouseArea {
                id: islandHitbox

                z: 20
                anchors.horizontalCenter: island.horizontalCenter
                y: island.y
                width: island.width
                height: root.mode === "idle" && !root.interactionOpen ? Math.max(root.reservedZone, island.height) : island.height
                hoverEnabled: true
                acceptedButtons: root.visualMode === "media" || root.interactionOpen ? Qt.NoButton : Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                onEntered: root.keepInteractionOpen()
                onExited: {
                    root.mediaHoverSuppressed = false;
                    root.scheduleInteractionClose();
                }
                onClicked: {
                    if (root.mode === "idle")
                        root.pinnedOpen = !root.pinnedOpen;
                    else
                        root.showIdle();
                }
            }
        }
    }

    IpcHandler {
        target: "dynamicIsland"

        function idle(): void {
            root.showIdle();
        }

        function handle(style: string): void {
            root.setHandleStyle(style);
        }

        function toggleHandle(): void {
            root.toggleHandleStyle();
        }

        function notify(summary: string, message: string, app: string): void {
            root.showNotification(summary, message, app);
        }

        function media(trackTitle: string, trackArtist: string, isPlaying: string, artUrl: string): void {
            root.showMedia(trackTitle, trackArtist, root.boolFromIpc(isPlaying), artUrl);
        }

        function volume(level: int, isMuted: string): void {
            root.showVolume(level, isMuted === "true" || isMuted === "muted" || isMuted === "1");
        }

        function brightness(level: int): void {
            root.showBrightness(level);
        }
    }
}
