pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: colors

    property color bg:      "#11111b"
    property color fg:      "#cdd6f4"
    property color accent:  "#89b4fa"
    property color green:   "#a6e3a1"
    property color red:     "#f38ba8"
    property color yellow:  "#f9e2af"
    property color surface: "#1e1e2e"
    property color dim:     "#6c7086"

    property color _prevBg:      bg
    property color _prevFg:      fg
    property color _prevAccent:  accent
    property color _prevGreen:   green
    property color _prevRed:     red
    property color _prevYellow:  yellow
    property color _prevSurface: surface
    property color _prevDim:     dim

    Behavior on bg      { ColorAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on fg      { ColorAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on accent  { ColorAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on green   { ColorAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on red     { ColorAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on yellow  { ColorAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on surface { ColorAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on dim     { ColorAnimation { duration: 300; easing.type: Easing.OutCubic } }

    property bool darkMode: true
    property bool autoMode: true
    property int  revision: 0

    property string wallpaperPath:  Quickshell.env("HOME") + "/wallpapers/current"
    property string irisPath:       Quickshell.env("HOME") + "/.config/quickshell/iris/iris.py"
    property string nvimColorsPath: Quickshell.env("HOME") + "/.config/nvim/lua/colors.lua"
    property string gtkCssPath:     Quickshell.env("HOME") + "/.config/gtk-4.0/gtk.css"
    property string gtk3CssPath:    Quickshell.env("HOME") + "/.config/gtk-3.0/gtk.css"
    property string starshipPath:   Quickshell.env("HOME") + "/.config/starship.toml"
    property string gtkThemePath:   Quickshell.env("HOME") + "/.config/quickshell/gtk_theme.py"
    property string themeEnginePath: Quickshell.env("HOME") + "/.config/quickshell/theme_engine.py"
    property string paletteCachePath: Quickshell.env("HOME") + "/.cache/qs/current-palette.json"

    property var _lastParsedData: null
    property var wallpaperPalette: null

    signal colorsChanged()

    function a(c, o) { return Qt.rgba(c.r, c.g, c.b, o) }

    function toHex(c) {
        var r = Math.round(c.r * 255).toString(16).padStart(2, "0")
        var g = Math.round(c.g * 255).toString(16).padStart(2, "0")
        var b = Math.round(c.b * 255).toString(16).padStart(2, "0")
        return "#" + r + g + b
    }

    function applyFromJson(data) {
        try {
            var p = JSON.parse(data)

            if (UIState.colorMode !== "fixed-preset" && autoMode && !UIState.darkModeLocked) {
                var shouldBeDark
                if      (p.tone_l < 0.45) shouldBeDark = true
                else if (p.tone_l > 0.55) shouldBeDark = false
                else                      shouldBeDark = darkMode

                if (shouldBeDark !== darkMode) {
                    darkMode = shouldBeDark
                    UIState.darkMode = shouldBeDark
                    irisProc.running = false
                    irisProc.running = true
                    return
                }
            }

            wallpaperPalette = p
            resolvePalette(p)
        } catch(e) {
            UIState.colorError = "Não foi possível ler as cores do wallpaper"
            console.log("iris: failed to parse output:", e)
        }
    }

    function resolvePalette(p) {
        if (!p) return
        themeResolveProc.running = false
        themeResolveProc.command = [
            "python3", themeEnginePath,
            "--wallpaper-json", JSON.stringify(p),
            "--mode", UIState.colorMode,
            "--preset", UIState.colorPreset,
            "--dark", UIState.darkMode ? "1" : "0",
            "--publish", paletteCachePath,
            "--starship", starshipPath
        ]
        themeResolveProc.running = true
    }

    function applyEffectiveFromJson(data) {
        try {
            var p = JSON.parse(data)

            _prevBg      = bg
            _prevFg      = fg
            _prevAccent  = accent
            _prevGreen   = green
            _prevRed     = red
            _prevYellow  = yellow
            _prevSurface = surface
            _prevDim     = dim

            bg      = p.bg
            fg      = p.fg
            accent  = p.accent
            green   = p.green
            red     = p.red
            yellow  = p.yellow
            surface = p.surface
            dim     = p.dim
            
            _lastParsedData = p
            revision++
            colorsChanged()
            UIState.colorError = ""
            sddmSyncDelay.restart()
        } catch(e) {
            UIState.colorError = "A paleta efetiva é inválida; mantendo a anterior"
            console.log("theme resolver: failed to parse output:", e)
        }
    }

    function applyCurrentMode(dark) {
        darkMode = dark
        UIState.darkMode = dark
        autoMode = false
        if (UIState.colorMode === "fixed-preset") refreshColorSource()
        else runIris()
    }

    function runIris() {
        irisProc.running = false
        irisProc.running = true
    }

    function refreshColorSource() {
        if (wallpaperPalette) resolvePalette(wallpaperPalette)
        else runIris()
    }

    function writeNvimColors(p) {
        var lines = [
            'return {',
            '    bg             = "' + p.bg                             + '",',
            '    surface        = "' + p.surface                        + '",',
            '    fg             = "' + p.fg                             + '",',
            '    dim            = "' + p.dim                            + '",',
            '    accent         = "' + p.accent                         + '",',
            '    red            = "' + p.red                            + '",',
            '    green          = "' + p.green                          + '",',
            '    yellow         = "' + p.yellow                         + '",',
            '    syntax_keyword  = "' + (p.syntax_keyword  || p.accent) + '",',
            '    syntax_string   = "' + (p.syntax_string   || p.yellow) + '",',
            '    syntax_func     = "' + (p.syntax_func     || p.green)  + '",',
            '    syntax_type     = "' + (p.syntax_type     || p.accent) + '",',
            '    syntax_const    = "' + (p.syntax_const    || p.red)    + '",',
            '    syntax_comment  = "' + (p.syntax_comment  || p.dim)    + '",',
            '    syntax_param    = "' + (p.syntax_param    || p.fg)     + '",',
            '    syntax_operator = "' + (p.syntax_operator || p.accent) + '",',
            '    dark           = ' + (p.dark ? 'true' : 'false')       + ',',
            '}',
            ''
        ]

        var script = lines.map(function(line) {
            return "echo " + JSON.stringify(line)
        }).join("; ")

        nvimWriteProc.command = ["bash", "-c",
            "(" + script + ") > " + JSON.stringify(nvimColorsPath)]
        nvimWriteProc.running = true
    }

    function writeGtkColors(p) {
        if (!p) return
        var scheme  = darkMode ? "'prefer-dark'" : "'prefer-light'"
        var accent  = "'" + p.accent + "'"
        gtkWriteProc.command = ["python3", gtkThemePath,
            "--palette-json", JSON.stringify(p), "--skin", UIState.skinProfile]
        gtkWriteProc.running = true
        gtkSettingsProc.command = ["bash", "-c",
            "gsettings set org.gnome.desktop.interface color-scheme " + scheme + " " +
            "&& gsettings set org.gnome.desktop.interface accent-color " + accent + " " +
            "2>/dev/null || true"]
        gtkSettingsProc.running = true
    }

    function refreshGtkTheme() {
        writeGtkColors(_lastParsedData || {
            bg: toHex(bg), fg: toHex(fg), accent: toHex(accent), green: toHex(green),
            red: toHex(red), yellow: toHex(yellow), surface: toHex(surface), dim: toHex(dim)
        })
    }

    Process {
        id: irisProc
        command: [
            "python3", colors.irisPath,
            "--wallpaper", colors.wallpaperPath,
            "--dark",      colors.darkMode ? "1" : "0",
            "--glass",     UIState.transparencyEnabled ? "1" : "0"
        ]
        running: true
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => colors.applyFromJson(data)
        }
    }

    Process { id: nvimWriteProc }
    Process { id: gtkWriteProc }
    Process { id: gtkSettingsProc }
    Process {
        id: themeResolveProc
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => colors.applyEffectiveFromJson(data)
        }
        onExited: code => {
            if (code !== 0) UIState.colorError = "Falha ao resolver a paleta; mantendo as cores anteriores"
        }
    }

    Process {
        id: sddmSyncProc
        command: ["bash", "-c", "command -v kamalen-sddm-sync >/dev/null 2>&1 && kamalen-sddm-sync >/dev/null 2>&1 || true"]
    }

    Timer {
        id: sddmSyncDelay
        interval: 350
        onTriggered: sddmSyncProc.running = true
    }

    Process {
        id: wallWatch
        command: ["bash", "-c",
            "inotifywait -m -e close_write,moved_to,create '" + 
            Quickshell.env("HOME") + "/wallpapers' 2>/dev/null | " +
            "while read; do readlink -f '" + wallpaperPath + "' 2>/dev/null && sleep 0.1; done"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var path = data.trim()
                if (path && path !== _lastWallPath) {
                    _lastWallPath = path
                    reloadDelay.restart()
                }
            }
        }
        onExited: wallWatchRestart.start()
    }

    property string _lastWallPath: ""

    Timer { id: wallWatchRestart; interval: 2000; onTriggered: wallWatch.running = true }

    Timer {
        id: reloadDelay
        interval: 100
        onTriggered: {
            autoMode = true
            runIris()
        }
    }
}
