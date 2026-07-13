import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes

Item {
    id: root

    property string mode: "idle"
    property string appName: ""
    property string title: ""
    property string body: ""
    property string artist: ""
    property string artUrl: ""
    property int volume: 0
    property bool muted: false
    property bool volumeIndicatorVisible: false
    property int indicatorLevel: 0
    property bool indicatorMuted: false
    property bool playing: false
    property bool canGoPrevious: false
    property bool canTogglePlaying: false
    property bool canGoNext: false
    property bool canSeek: false
    property bool shuffleActive: false
    property bool shuffleSupported: false
    property string loopStateText: "OFF"
    property bool loopActive: false
    property bool loopSupported: false
    property real mediaPosition: 0
    property real mediaLength: 0
    property bool forceExpanded: false
    property bool mediaAvailable: false
    property string handleStyle: "bump"
    property string batteryHoverText: ""
    property bool batteryCharging: false
    property int batteryLevel: 0
    property bool wifiConnected: false
    property string wifiSsid: ""
    property int wifiSignal: 0
    property bool btEnabled: false
    property bool btConnected: false
    property string btDeviceName: ""
    property int btBattery: -1
    property int workspace: 1
    property var workspaceOccupied: [false,false,false,false,false]
    property string focusedApp: ""
    property string timeText: ""
    property string dateText: ""
    property string fontFamily: "JetBrainsMono Nerd Font"
    property string launcherQuery: ""
    property int launcherSelected: 0
    property var launcherTopApps: []
    property var launcherFiltered: []
    
    readonly property bool expanded: mode !== "idle" || forceExpanded
    
    // Modulado com a opacidade/cor do sistema
    function a(c, o) { return Qt.rgba(c.r, c.g, c.b, o) }
    
    readonly property real bottomRadius: Math.max(1, Math.min(height / 2, expanded ? Math.min(height * 0.28, UIState.borderRadius) : Math.min(height * 0.42, 8)))
    readonly property color surfaceColor: a(Colors.bg, UIState.transparencyEnabled ? (expanded ? 0.94 : 0.88) : 1.0)
    readonly property real antiCornerRadius: root.expanded || handleStyle === "strip" ? Math.min(3, height * 0.6) : Math.min(2.5, height * 0.12)

    signal previousRequested
    signal playPauseRequested
    signal nextRequested
    signal shuffleRequested
    signal loopRequested
    signal favoriteRequested
    signal dismissRequested
    signal wifiSettingsRequested
    signal btSettingsRequested
    signal seekRequested(real position)
    signal handleStyleRequested(string style)
    signal launcherSearchChanged(string query)
    signal launcherCloseRequested
    signal launcherAppLaunchRequested(var app)
    signal launcherMoveSelectionRequested(int delta)
    signal workspaceSwitchRequested(int index)

    transformOrigin: Item.Top

    // Shoulder size scales with surface height for proportional look
    readonly property real shoulderW: Math.max(8, Math.min(width * 0.06, 20))
    readonly property real shoulderH: Math.max(6, Math.min(height * 0.4, 13))

    // Anti-corner left: concave shoulder merging island into screen edge.
    // Size scales dynamically with island dimensions (DPI/scale-safe).
    Shape {
        id: antiCornerLeft

        x: -antiCornerLeft.width
        y: 0
        width: root.shoulderW
        height: root.shoulderH
        opacity: root.antiCornerRadius > 0 ? 1 : 0
        visible: opacity > 0
        antialiasing: true

        ShapePath {
            fillColor: root.surfaceColor
            strokeColor: "transparent"
            startX: antiCornerLeft.width
            startY: 0
            PathLine {
                x: antiCornerLeft.width
                y: antiCornerLeft.height
            }
            PathCubic {
                x: 0; y: 0
                control1X: antiCornerLeft.width * 0.45
                control1Y: antiCornerLeft.height
                control2X: 0
                control2Y: antiCornerLeft.height * 0.3
            }
        }

        Behavior on opacity {
            NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic }
        }
        Behavior on width {
            NumberAnimation { duration: 330; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
        }
        Behavior on height {
            NumberAnimation { duration: 330; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
        }
    }

    // Anti-corner right: mirror of left
    Shape {
        id: antiCornerRight

        x: root.width
        y: 0
        width: root.shoulderW
        height: root.shoulderH
        opacity: root.antiCornerRadius > 0 ? 1 : 0
        visible: opacity > 0
        antialiasing: true

        ShapePath {
            fillColor: root.surfaceColor
            strokeColor: "transparent"
            startX: 0
            startY: 0
            PathLine {
                x: 0
                y: antiCornerRight.height
            }
            PathCubic {
                x: antiCornerRight.width; y: 0
                control1X: antiCornerRight.width * 0.55
                control1Y: antiCornerRight.height
                control2X: antiCornerRight.width
                control2Y: antiCornerRight.height * 0.3
            }
        }

        Behavior on opacity {
            NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic }
        }
        Behavior on width {
            NumberAnimation { duration: 330; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
        }
        Behavior on height {
            NumberAnimation { duration: 330; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
        }
    }

    Rectangle {
        id: shadow

        anchors.fill: bodyShape
        anchors.topMargin: Metrics.dp(8)
radius: root.bottomRadius
        color: "#000000"
        opacity: root.expanded ? 0.35 : 0
        scale: 1

        Behavior on opacity {
            NumberAnimation {
                duration: Animations.medium
                easing.type: Easing.OutCubic
            }
        }
    }

    Rectangle {
        id: outerGlow

        anchors.fill: bodyShape
        anchors.margins: Metrics.dp(-1)
radius: root.bottomRadius + 1
        color: "transparent"
        border.width: 1
        border.color: a(Colors.accent, root.expanded ? 0.25 : 0.08)
        opacity: 1

        Behavior on border.color { ColorAnimation { duration: Animations.fast } }
    }

    Item {
        id: bodyShape

        anchors.fill: parent
        clip: true

        Rectangle {
            z: 1
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }
            height: Math.ceil(parent.height / 2)
            color: root.surfaceColor
        }

        Rectangle {
            z: 0
            anchors.fill: parent
            radius: root.bottomRadius
            color: root.surfaceColor
        }

        // Sheen que se adapta à cor de destaque (Colors.accent)
        Rectangle {
            id: coldSheen

            x: parent.width * 0.08
            y: 3
            width: parent.width * 0.84
            height: Math.max(6, parent.height * 0.32)
            radius: height / 2
            opacity: root.expanded ? 0.15 : 0.04

            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop {
                    position: 0
                    color: "transparent"
                }

                GradientStop {
                    position: 0.4
                    color: a(Colors.accent, 0.4)
                }

                GradientStop {
                    position: 0.6
                    color: a(Colors.fg, 0.2)
                }

                GradientStop {
                    position: 1
                    color: "transparent"
                }
            }
            
            Behavior on opacity { NumberAnimation { duration: Animations.medium } }
        }

        Canvas {
            id: volumeTrace

            z: 8
            anchors.fill: parent
            opacity: root.volumeIndicatorVisible ? 1 : 0

            function perimeterPoints() {
                const inset = Math.max(1.5, Math.min(4, height * 0.22, width * 0.08));
                const left = inset;
                const right = Math.max(left + 1, width - inset);
                const openTop = Math.min(height - inset - 1, Math.max(inset + 1, height * 0.18));
                const bottom = Math.max(openTop + 1, height - inset);
                const radius = Math.max(0, Math.min(root.bottomRadius - inset, (right - left) / 2));
                const arcSteps = 10;
                const points = [
                    {
                        x: left,
                        y: openTop
                    },
                    {
                        x: left,
                        y: bottom - radius
                    }
                ];

                for (let i = 0; i <= arcSteps; i += 1) {
                    const angle = Math.PI - i / arcSteps * Math.PI / 2;
                    points.push({
                        x: left + radius + Math.cos(angle) * radius,
                        y: bottom - radius + Math.sin(angle) * radius
                    });
                }

                points.push({
                    x: right - radius,
                    y: bottom
                });

                for (let i = 0; i <= arcSteps; i += 1) {
                    const angle = Math.PI / 2 - i / arcSteps * Math.PI / 2;
                    points.push({
                        x: right - radius + Math.cos(angle) * radius,
                        y: bottom - radius + Math.sin(angle) * radius
                    });
                }

                points.push({
                    x: right,
                    y: openTop
                });
                return points;
            }

            function distance(a, b) {
                const dx = b.x - a.x;
                const dy = b.y - a.y;

                return Math.sqrt(dx * dx + dy * dy);
            }

            function tracePath(ctx, progress) {
                const points = perimeterPoints();
                let total = 0;

                for (let i = 1; i < points.length; i += 1)
                    total += distance(points[i - 1], points[i]);

                ctx.beginPath();
                ctx.moveTo(points[0].x, points[0].y);

                if (total <= 0 || progress <= 0)
                    return;

                const target = total * Math.max(0, Math.min(1, progress));
                let walked = 0;

                for (let i = 1; i < points.length; i += 1) {
                    const previous = points[i - 1];
                    const current = points[i];
                    const segment = distance(previous, current);

                    if (walked + segment >= target) {
                        const t = segment === 0 ? 0 : (target - walked) / segment;

                        ctx.lineTo(previous.x + (current.x - previous.x) * t, previous.y + (current.y - previous.y) * t);
                        return;
                    }

                    ctx.lineTo(current.x, current.y);
                    walked += segment;
                }
            }

            onPaint: {
                const ctx = getContext("2d");
                const progress = root.indicatorMuted ? 0 : Math.max(0, Math.min(1, root.indicatorLevel / 100));

                ctx.reset();
                ctx.clearRect(0, 0, width, height);
                ctx.lineWidth = 2;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";

                // Borda de fundo do trace
                ctx.strokeStyle = a(Colors.accent, 0.15);
                tracePath(ctx, 1);
                ctx.stroke();

                // Borda ativa de volume com a cor de destaque (Colors.accent)
                if (progress > 0) {
                    ctx.strokeStyle = a(Colors.accent, 0.90);
                    tracePath(ctx, progress);
                    ctx.stroke();
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Animations.fast
                    easing.type: Easing.OutCubic
                }
            }

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onVisibleChanged: requestPaint()
            Connections {
                target: root

                function onIndicatorLevelChanged() {
                    volumeTrace.requestPaint();
                }

                function onIndicatorMutedChanged() {
                    volumeTrace.requestPaint();
                }

                function onVolumeIndicatorVisibleChanged() {
                    volumeTrace.requestPaint();
                }
            }
        }

        IslandContent {
            z: 10
            anchors.fill: parent
            anchors.margins: root.expanded ? (root.mode === "media" ? 10 : 12) : 0
            mode: root.mode
            handleStyle: root.handleStyle
            forceExpanded: root.forceExpanded
            appName: root.appName
            title: root.title
            body: root.body
            artist: root.artist
            artUrl: root.artUrl
            volume: root.volume
            muted: root.muted
            playing: root.playing
            canGoPrevious: root.canGoPrevious
            canTogglePlaying: root.canTogglePlaying
            canGoNext: root.canGoNext
            canSeek: root.canSeek
            shuffleActive: root.shuffleActive
            shuffleSupported: root.shuffleSupported
            loopStateText: root.loopStateText
            loopActive: root.loopActive
            loopSupported: root.loopSupported
            mediaPosition: root.mediaPosition
            mediaLength: root.mediaLength
            mediaAvailable: root.mediaAvailable
            fontFamily: root.fontFamily
            batteryHoverText: root.batteryHoverText
            batteryCharging: root.batteryCharging
            batteryLevel: root.batteryLevel
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
            timeText: root.timeText
            dateText: root.dateText
            onPreviousRequested: root.previousRequested()
            onPlayPauseRequested: root.playPauseRequested()
            onNextRequested: root.nextRequested()
            onShuffleRequested: root.shuffleRequested()
            onLoopRequested: root.loopRequested()
            onFavoriteRequested: root.favoriteRequested()
            onDismissRequested: root.dismissRequested()
            onWifiSettingsRequested: root.wifiSettingsRequested()
            onBtSettingsRequested: root.btSettingsRequested()
            onSeekRequested: position => root.seekRequested(position)
            onHandleStyleRequested: style => root.handleStyleRequested(style)
            launcherQuery: root.launcherQuery
            launcherSelected: root.launcherSelected
            launcherTopApps: root.launcherTopApps
            launcherFiltered: root.launcherFiltered
            onLauncherSearchChanged: query => root.launcherSearchChanged(query)
            onLauncherCloseRequested: root.launcherCloseRequested()
            onLauncherAppLaunchRequested: app => root.launcherAppLaunchRequested(app)
            onLauncherMoveSelectionRequested: delta => root.launcherMoveSelectionRequested(delta)
            onWorkspaceSwitchRequested: index => root.workspaceSwitchRequested(index)
        }
    }

    // ── Goey morph curve (reference: [0.34, 1.22, 0.64, 1]) ──────────
    // OutBack overshoot gives the "gooey"/bouncy feel like patheonsceo/end-4.
    Behavior on width {
        NumberAnimation {
            duration: 330
            easing.type: Easing.OutBack
            easing.overshoot: 1.1
        }
    }

    Behavior on height {
        NumberAnimation {
            duration: 330
            easing.type: Easing.OutBack
            easing.overshoot: 1.1
        }
    }

    Behavior on y {
        NumberAnimation {
            duration: 280
            easing.type: Easing.OutCubic
        }
    }
}
