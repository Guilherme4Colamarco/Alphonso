pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: mangoConfig

    // -------------------------------------------------------------------------
    // Exposed properties (reactive, loaded from the Python backend on startup)
    // -------------------------------------------------------------------------

    // Gaps
    property int  mangoGappih: 6
    property int  mangoGappiv: 6
    property int  mangoGappoh: 8
    property int  mangoGappov: 8

    // Borders
    property int  mangoBorderPx: 1
    property int  mangoBorderRadius: 16
    property bool mangoNoBorderWhenSingle: true
    property bool mangoNoRadiusWhenSingle: false

    // Opacity
    property real mangoFocusedOpacity: 1.0
    property real mangoUnfocusedOpacity: 0.85

    // Blur
    property bool mangoBlur: true
    property bool mangoBlurLayer: true
    property bool mangoBlurOptimized: false
    property int  mangoBlurPasses: 4
    property int  mangoBlurRadius: 14

    // Shadows
    property bool mangoShadows: true
    property bool mangoShadowLayer: true
    property bool mangoShadowOnlyFloating: true
    property int  mangoShadowSize: 18
    property int  mangoShadowBlur: 15
    property int  mangoShadowPosX: 0
    property int  mangoShadowPosY: 6

    // Layout
    property bool mangoSmartGaps: false
    property real mangoDefaultMfact: 0.55
    property int  mangoDefaultNmaster: 1

    // Input
    property int  mangoRepeatRate: 50
    property int  mangoRepeatDelay: 300
    property bool mangoTapToClick: true
    property bool mangoTrackpadNaturalScroll: false

    // Focus
    property bool mangoFocusOnActivate: true
    property bool mangoSloppyFocus: true
    property bool mangoWarpCursor: true
    property bool mangoFocusCrossMonitor: false
    property bool mangoFocusCrossTag: false
    property bool mangoEnableFloatingSnap: true
    property int  mangoSnapDistance: 30
    property bool mangoDragTileToTile: true

    // Animations
    property bool mangoAnimations: true
    property bool mangoLayerAnimations: true
    property bool mangoAnimationFadeIn: true
    property bool mangoAnimationFadeOut: true
    property int  mangoAnimationDirection: 1
    property int  mangoAnimationDurationOpen: 350
    property int  mangoAnimationDurationClose: 220
    property int  mangoAnimationDurationMove: 320
    property int  mangoAnimationDurationTag: 380
    property int  mangoAnimationDurationFocus: 180
    property real mangoZoomInitialRatio: 0.82
    property real mangoZoomEndRatio: 1.02
    property real mangoFadeinBeginOpacity: 0.0
    property real mangoFadeoutBeginOpacity: 1.0
    property string mangoAnimationTypeOpen: "slide"
    property string mangoAnimationTypeClose: "slide"
    property string mangoLayerAnimationTypeOpen: "slide"
    property string mangoLayerAnimationTypeClose: "slide"

    // Colors (stored as MangoWM hex strings like "0xaabbccdd")
    property string mangoRootColor: "0x000000ff"
    property string mangoBorderColor: "0x75704aff"
    property string mangoFocusColor: "0xd0b883ff"
    property string mangoUrgentColor: "0xb68e54ff"
    property string mangoScratchpadColor: "0xd0b883ff"
    property string mangoGlobalColor: "0xd0b883ff"
    property string mangoOverlayColor: "0x84b654ff"
    property string mangoMaximizescreenColor: "0xb69f54ff"
    property string mangoShadowColor: "0x00000040"

    // -------------------------------------------------------------------------
    // Internal state
    // -------------------------------------------------------------------------

    property string _configPath: Quickshell.env("HOME") + "/.config/mango/mango_config.py"
    property var    _data: ({})        // grouped JSON payload from get-all
    property bool   _ready: false
    property var    _pendingSets: []
    property var    _activeSet: null
    property string _setOutput: ""
    property bool   applying: false
    property string lastError: ""
    property var    _pendingDirectives: []
    property var    _activeDirective: null
    property string _directiveOutput: ""
    property string lastDirectiveError: ""
    property var    _pendingStyles: []
    property var    _activeStyle: null
    property string _styleOutput: ""
    property bool   styleApplying: false
    property string lastStyleError: ""

    signal configurationApplied(string key, var value)
    signal configurationFailed(string key, string message)
    signal directiveApplied(string module, string action)
    signal directiveFailed(string module, string action, string message)
    signal configurationLoaded()
    signal styleApplied(var pairs)
    signal styleFailed(string message)

    property var keyToProperty: ({
        // gaps
        "gappih": "mangoGappih",
        "gappiv": "mangoGappiv",
        "gappoh": "mangoGappoh",
        "gappov": "mangoGappov",

        // borders
        "borderpx": "mangoBorderPx",
        "border_radius": "mangoBorderRadius",
        "no_border_when_single": "mangoNoBorderWhenSingle",
        "no_radius_when_single": "mangoNoRadiusWhenSingle",

        // opacity
        "focused_opacity": "mangoFocusedOpacity",
        "unfocused_opacity": "mangoUnfocusedOpacity",

        // blur
        "blur": "mangoBlur",
        "blur_layer": "mangoBlurLayer",
        "blur_optimized": "mangoBlurOptimized",
        "blur_params_num_passes": "mangoBlurPasses",
        "blur_params_radius": "mangoBlurRadius",

        // shadows
        "shadows": "mangoShadows",
        "layer_shadows": "mangoShadowLayer",
        "shadow_only_floating": "mangoShadowOnlyFloating",
        "shadows_size": "mangoShadowSize",
        "shadows_blur": "mangoShadowBlur",
        "shadows_position_x": "mangoShadowPosX",
        "shadows_position_y": "mangoShadowPosY",

        // layout
        "smartgaps": "mangoSmartGaps",
        "default_mfact": "mangoDefaultMfact",
        "default_nmaster": "mangoDefaultNmaster",

        // input-keyboard
        "repeat_rate": "mangoRepeatRate",
        "repeat_delay": "mangoRepeatDelay",

        // input-trackpad
        "tap_to_click": "mangoTapToClick",
        "trackpad_natural_scrolling": "mangoTrackpadNaturalScroll",

        // focus
        "focus_on_activate": "mangoFocusOnActivate",
        "sloppyfocus": "mangoSloppyFocus",
        "warpcursor": "mangoWarpCursor",
        "focus_cross_monitor": "mangoFocusCrossMonitor",
        "focus_cross_tag": "mangoFocusCrossTag",
        "enable_floating_snap": "mangoEnableFloatingSnap",
        "snap_distance": "mangoSnapDistance",
        "drag_tile_to_tile": "mangoDragTileToTile",

        // animations
        "animations": "mangoAnimations",
        "layer_animations": "mangoLayerAnimations",
        "animation_fade_in": "mangoAnimationFadeIn",
        "animation_fade_out": "mangoAnimationFadeOut",
        "tag_animation_direction": "mangoAnimationDirection",
        "animation_duration_open": "mangoAnimationDurationOpen",
        "animation_duration_close": "mangoAnimationDurationClose",
        "animation_duration_move": "mangoAnimationDurationMove",
        "animation_duration_tag": "mangoAnimationDurationTag",
        "animation_duration_focus": "mangoAnimationDurationFocus",
        "zoom_initial_ratio": "mangoZoomInitialRatio",
        "zoom_end_ratio": "mangoZoomEndRatio",
        "fadein_begin_opacity": "mangoFadeinBeginOpacity",
        "fadeout_begin_opacity": "mangoFadeoutBeginOpacity",
        "animation_type_open": "mangoAnimationTypeOpen",
        "animation_type_close": "mangoAnimationTypeClose",
        "layer_animation_type_open": "mangoLayerAnimationTypeOpen",
        "layer_animation_type_close": "mangoLayerAnimationTypeClose",

        // colors
        "rootcolor": "mangoRootColor",
        "bordercolor": "mangoBorderColor",
        "focuscolor": "mangoFocusColor",
        "urgentcolor": "mangoUrgentColor",
        "scratchpadcolor": "mangoScratchpadColor",
        "globalcolor": "mangoGlobalColor",
        "overlaycolor": "mangoOverlayColor",
        "maximizescreencolor": "mangoMaximizescreenColor",
        "shadowscolor": "mangoShadowColor"
    })

    property var propertyToKey: ({
        "mangoGappih": "gappih",
        "mangoGappiv": "gappiv",
        "mangoGappoh": "gappoh",
        "mangoGappov": "gappov",

        "mangoBorderPx": "borderpx",
        "mangoBorderRadius": "border_radius",
        "mangoNoBorderWhenSingle": "no_border_when_single",
        "mangoNoRadiusWhenSingle": "no_radius_when_single",

        "mangoFocusedOpacity": "focused_opacity",
        "mangoUnfocusedOpacity": "unfocused_opacity",

        "mangoBlur": "blur",
        "mangoBlurLayer": "blur_layer",
        "mangoBlurOptimized": "blur_optimized",
        "mangoBlurPasses": "blur_params_num_passes",
        "mangoBlurRadius": "blur_params_radius",

        "mangoShadows": "shadows",
        "mangoShadowLayer": "layer_shadows",
        "mangoShadowOnlyFloating": "shadow_only_floating",
        "mangoShadowSize": "shadows_size",
        "mangoShadowBlur": "shadows_blur",
        "mangoShadowPosX": "shadows_position_x",
        "mangoShadowPosY": "shadows_position_y",

        "mangoSmartGaps": "smartgaps",
        "mangoDefaultMfact": "default_mfact",
        "mangoDefaultNmaster": "default_nmaster",

        "mangoRepeatRate": "repeat_rate",
        "mangoRepeatDelay": "repeat_delay",

        "mangoTapToClick": "tap_to_click",
        "mangoTrackpadNaturalScroll": "trackpad_natural_scrolling",

        "mangoFocusOnActivate": "focus_on_activate",
        "mangoSloppyFocus": "sloppyfocus",
        "mangoWarpCursor": "warpcursor",
        "mangoFocusCrossMonitor": "focus_cross_monitor",
        "mangoFocusCrossTag": "focus_cross_tag",
        "mangoEnableFloatingSnap": "enable_floating_snap",
        "mangoSnapDistance": "snap_distance",
        "mangoDragTileToTile": "drag_tile_to_tile",

        "mangoAnimations": "animations",
        "mangoLayerAnimations": "layer_animations",
        "mangoAnimationFadeIn": "animation_fade_in",
        "mangoAnimationFadeOut": "animation_fade_out",
        "mangoAnimationDirection": "tag_animation_direction",
        "mangoAnimationDurationOpen": "animation_duration_open",
        "mangoAnimationDurationClose": "animation_duration_close",
        "mangoAnimationDurationMove": "animation_duration_move",
        "mangoAnimationDurationTag": "animation_duration_tag",
        "mangoAnimationDurationFocus": "animation_duration_focus",
        "mangoZoomInitialRatio": "zoom_initial_ratio",
        "mangoZoomEndRatio": "zoom_end_ratio",
        "mangoFadeinBeginOpacity": "fadein_begin_opacity",
        "mangoFadeoutBeginOpacity": "fadeout_begin_opacity",
        "mangoAnimationTypeOpen": "animation_type_open",
        "mangoAnimationTypeClose": "animation_type_close",
        "mangoLayerAnimationTypeOpen": "layer_animation_type_open",
        "mangoLayerAnimationTypeClose": "layer_animation_type_close",

        "mangoRootColor": "rootcolor",
        "mangoBorderColor": "bordercolor",
        "mangoFocusColor": "focuscolor",
        "mangoUrgentColor": "urgentcolor",
        "mangoScratchpadColor": "scratchpadcolor",
        "mangoGlobalColor": "globalcolor",
        "mangoOverlayColor": "overlaycolor",
        "mangoMaximizescreenColor": "maximizescreencolor",
        "mangoShadowColor": "shadowscolor"
    })

    property var keyToModule: ({
        "gappih": "gaps",
        "gappiv": "gaps",
        "gappoh": "gaps",
        "gappov": "gaps",

        "borderpx": "borders",
        "border_radius": "borders",
        "no_border_when_single": "borders",
        "no_radius_when_single": "borders",

        "focused_opacity": "opacity",
        "unfocused_opacity": "opacity",

        "blur": "blur",
        "blur_layer": "blur",
        "blur_optimized": "blur",
        "blur_params_num_passes": "blur",
        "blur_params_radius": "blur",
        "blur_params_noise": "blur",
        "blur_params_brightness": "blur",
        "blur_params_contrast": "blur",
        "blur_params_saturation": "blur",

        "shadows": "shadows",
        "layer_shadows": "shadows",
        "shadow_only_floating": "shadows",
        "shadows_size": "shadows",
        "shadows_blur": "shadows",
        "shadows_position_x": "shadows",
        "shadows_position_y": "shadows",

        "smartgaps": "layout",
        "default_mfact": "layout",
        "default_nmaster": "layout",

        "repeat_rate": "input-keyboard",
        "repeat_delay": "input-keyboard",

        "tap_to_click": "input-trackpad",
        "trackpad_natural_scrolling": "input-trackpad",

        "focus_on_activate": "focus",
        "sloppyfocus": "focus",
        "warpcursor": "focus",
        "focus_cross_monitor": "focus",
        "focus_cross_tag": "focus",
        "enable_floating_snap": "focus",
        "snap_distance": "focus",
        "drag_tile_to_tile": "focus",

        "animations": "animations",
        "layer_animations": "animations",
        "animation_fade_in": "animations",
        "animation_fade_out": "animations",
        "tag_animation_direction": "animations",
        "animation_duration_open": "animations",
        "animation_duration_close": "animations",
        "animation_duration_move": "animations",
        "animation_duration_tag": "animations",
        "animation_duration_focus": "animations",
        "zoom_initial_ratio": "animations",
        "zoom_end_ratio": "animations",
        "fadein_begin_opacity": "animations",
        "fadeout_begin_opacity": "animations",
        "animation_type_open": "animations",
        "animation_type_close": "animations",
        "layer_animation_type_open": "animations",
        "layer_animation_type_close": "animations",
        "animation_curve_open": "animations",
        "animation_curve_close": "animations",
        "animation_curve_move": "animations",
        "animation_curve_tag": "animations",
        "animation_curve_focus": "animations",
        "animation_curve_opafadein": "animations",
        "animation_curve_opafadeout": "animations",

        "rootcolor": "colors",
        "bordercolor": "colors",
        "focuscolor": "colors",
        "urgentcolor": "colors",
        "scratchpadcolor": "colors",
        "globalcolor": "colors",
        "overlaycolor": "colors",
        "maximizescreencolor": "colors",
        "shadowscolor": "colors"
    })

    property var _boolKeys: ({
        "no_border_when_single": true,
        "no_radius_when_single": true,
        "blur": true,
        "blur_layer": true,
        "blur_optimized": true,
        "shadows": true,
        "layer_shadows": true,
        "shadow_only_floating": true,
        "smartgaps": true,
        "tap_to_click": true,
        "trackpad_natural_scrolling": true,
        "focus_on_activate": true,
        "sloppyfocus": true,
        "warpcursor": true,
        "focus_cross_monitor": true,
        "focus_cross_tag": true,
        "enable_floating_snap": true,
        "drag_tile_to_tile": true,
        "animations": true,
        "layer_animations": true,
        "animation_fade_in": true,
        "animation_fade_out": true
    })

    // -------------------------------------------------------------------------
    // Public API
    // -------------------------------------------------------------------------

    function set(key, value) {
        var pending = _pendingSets.slice()
        pending.push({ key: key, value: value })
        _pendingSets = pending
        _startNextSet()
    }

    function setNoApply(key, value) {
        runCmd(["set", key, _toMangoValue(value)])
        _updateLocalProperty(key, value)
    }

    function apply(key, value) {
        runCmd(["apply", key, _toMangoValue(value)])
        _updateLocalProperty(key, value)
    }

    function get(key) {
        var module = keyToModule[key]
        if (!module || !_data[module]) return undefined
        return _data[module][key]
    }

    function getModule(module) {
        return _data[module] || {}
    }

    function reload() {
        runCmd(["reload"])
    }

    function setMany(pairs) {
        runCmd(["set-many", JSON.stringify(pairs)])
        for (var key in pairs) _updateLocalProperty(key, pairs[key])
    }

    function setModule(module, pairs) {
        runCmd(["set-module", module, JSON.stringify(pairs), "--reload"])
        for (var key in pairs) _updateLocalProperty(key, pairs[key])
    }

    function loadAll() {
        loadProc.running = false
        loadProc.running = true
    }

    function applyStyle(pairs) {
        var queue = _pendingStyles.slice()
        queue.push(pairs)
        _pendingStyles = queue
        _startNextStyle()
    }

    function _startNextStyle() {
        if (_activeStyle || _pendingStyles.length === 0) return
        var queue = _pendingStyles.slice()
        _activeStyle = queue.shift()
        _pendingStyles = queue
        _styleOutput = ""
        styleApplying = true
        styleProc.command = ["python3", _configPath, "apply-style", JSON.stringify(_activeStyle)]
        styleProc.running = true
    }

    function _finishStyle(exitCode) {
        var pairs = _activeStyle
        var response = null
        try { response = JSON.parse(_styleOutput) } catch (e) {}
        if (pairs && exitCode === 0 && response && response.ok) {
            for (var key in pairs) _updateLocalProperty(key, pairs[key])
            lastStyleError = ""
            styleApplied(pairs)
        } else {
            lastStyleError = response && response.error ? response.error : "Style was not applied"
            styleFailed(lastStyleError)
            loadAll()
        }
        _activeStyle = null
        styleApplying = false
        _startNextStyle()
    }

    function _startNextSet() {
        if (_activeSet || _pendingSets.length === 0) return

        var pending = _pendingSets.slice()
        var operation = pending.shift()
        _pendingSets = pending
        _activeSet = operation
        _setOutput = ""
        applying = true

        setProc.command = ["python3", _configPath, "set-apply",
                           operation.key, _toMangoValue(operation.value)]
        setProc.running = true
    }

    function _finishSet(exitCode) {
        var operation = _activeSet
        var response = null
        var message = ""

        try {
            response = JSON.parse(_setOutput)
        } catch (e) {
            message = "Mango backend returned an invalid response"
        }

        if (operation && exitCode === 0 && response && response.ok) {
            _updateLocalProperty(operation.key, operation.value)
            lastError = ""
            configurationApplied(operation.key, operation.value)
        } else if (operation) {
            if (message === "") {
                message = response && response.error
                    ? response.error
                    : "Mango configuration was not applied"
            }
            lastError = message
            configurationFailed(operation.key, message)
            loadAll()
        }

        _activeSet = null
        applying = false
        _startNextSet()
    }

    // -------------------------------------------------------------------------
    // Process helpers
    // -------------------------------------------------------------------------

    function runCmd(args) {
        var cmd = ["python3", _configPath].concat(args)
        cmdProc.command = cmd
        cmdProc.running = false
        cmdProc.running = true
    }

    function _toMangoValue(value) {
        if (typeof value === "boolean") return value ? "1" : "0"
        return String(value)
    }

    function _toQmlValue(key, raw) {
        if (_boolKeys[key]) {
            if (typeof raw === "boolean") return raw
            return String(raw) === "1"
        }

        var propName = keyToProperty[key]
        if (!propName) return raw

        var propType = typeof mangoConfig[propName]
        if (propType === "number") {
            var n = Number(raw)
            return isNaN(n) ? raw : n
        }
        return raw
    }

    function _updateLocalProperty(key, value) {
        var propName = keyToProperty[key]
        if (propName) mangoConfig[propName] = _toQmlValue(key, value)

        var module = keyToModule[key]
        if (module && _data[module]) {
            _data[module][key] = propName ? _toQmlValue(key, value) : value
        }
    }

    function _applyAll(data) {
        try {
            var parsed = JSON.parse(data)
            _data = parsed

            for (var key in keyToProperty) {
                var module = keyToModule[key]
                if (!module || !parsed[module]) continue

                var raw = parsed[module][key]
                if (raw === undefined || raw === null) continue

                var propName = keyToProperty[key]
                mangoConfig[propName] = _toQmlValue(key, raw)
            }

            _ready = true
            configurationLoaded()
        } catch (e) {
            console.log("MangoConfig: failed to parse get-all output:", e)
        }
    }

    // -------------------------------------------------------------------------
    // Directive API (binds, windowrules, monitors)
    // -------------------------------------------------------------------------

    function listDirectives(module, callback) {
        _enqueueDirective({ module: module, action: "list", callback: callback,
                            args: ["list-directives", module] })
    }

    function addDirective(module, prefix, value) {
        _enqueueDirective({ module: module, action: "add", callback: null,
                            args: ["add-directive", module, prefix, value] })
    }

    function removeDirective(module, index) {
        _enqueueDirective({ module: module, action: "remove", callback: null,
                            args: ["remove-directive", module, String(index)] })
    }

    function directiveBusy(module) {
        if (_activeDirective && _activeDirective.module === module) return true
        for (var i = 0; i < _pendingDirectives.length; i++) {
            if (_pendingDirectives[i].module === module) return true
        }
        return false
    }

    function _enqueueDirective(operation) {
        var pending = _pendingDirectives.slice()
        pending.push(operation)
        _pendingDirectives = pending
        _startNextDirective()
    }

    function _startNextDirective() {
        if (_activeDirective || _pendingDirectives.length === 0) return
        var pending = _pendingDirectives.slice()
        _activeDirective = pending.shift()
        _pendingDirectives = pending
        _directiveOutput = ""
        directiveProc.command = ["python3", _configPath].concat(_activeDirective.args)
        directiveProc.running = true
    }

    function _finishDirective(exitCode) {
        var operation = _activeDirective
        var response = null
        var message = ""
        try {
            response = JSON.parse(_directiveOutput)
        } catch (e) {
            message = "Mango backend returned an invalid response"
        }

        var ok = operation && exitCode === 0 && response !== null
        if (ok && operation.action !== "list") ok = response.ok === true

        if (ok) {
            lastDirectiveError = ""
            if (operation.action === "list" && operation.callback)
                operation.callback(response)
            directiveApplied(operation.module, operation.action)
        } else if (operation) {
            if (message === "")
                message = response && response.error ? response.error : "Mango directive was not applied"
            lastDirectiveError = message
            directiveFailed(operation.module, operation.action, message)
        }

        _activeDirective = null
        _startNextDirective()
    }

    // -------------------------------------------------------------------------
    // Processes
    // -------------------------------------------------------------------------

    Process {
        id: loadProc
        command: ["python3", mangoConfig._configPath, "get-all"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => mangoConfig._applyAll(data)
        }
        onExited: exitCode => {
            if (exitCode !== 0) {
                console.log("MangoConfig: get-all exited with code", exitCode)
            }
        }
    }

    Process {
        id: cmdProc
        onExited: exitCode => {
            if (exitCode !== 0) {
                console.log("MangoConfig: command exited with code", exitCode,
                            "command:", JSON.stringify(command))
            }
        }
    }

    Process {
        id: setProc
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => mangoConfig._setOutput += data
        }
        onExited: exitCode => mangoConfig._finishSet(exitCode)
    }

    Process {
        id: styleProc
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => mangoConfig._styleOutput += data
        }
        onExited: exitCode => mangoConfig._finishStyle(exitCode)
    }

    Process {
        id: directiveProc
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => mangoConfig._directiveOutput += data
        }
        onExited: exitCode => mangoConfig._finishDirective(exitCode)
    }

    // -------------------------------------------------------------------------
    // Lifecycle
    // -------------------------------------------------------------------------

    Component.onCompleted: loadAll()
}
