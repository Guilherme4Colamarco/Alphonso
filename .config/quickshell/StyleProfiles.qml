pragma Singleton
import QtQuick

QtObject {
    readonly property var animationOrder: ["bubbly", "calm", "snappy", "extraslow", "none"]
    readonly property var blurOrder: ["frosted", "balanced", "subtle", "none"]

    readonly property var presets: [
        { id: "rounded-elastic", label: "Redondo Elástico", icon: "󰗣", radius: 16, animation: "bubbly", blur: "frosted" },
        { id: "balanced", label: "Equilibrado", icon: "󰔡", radius: 12, animation: "calm", blur: "balanced" },
        { id: "compact-fast", label: "Rápido Compacto", icon: "󱐋", radius: 8, animation: "snappy", blur: "subtle" },
        { id: "minimal", label: "Minimalista", icon: "󰘕", radius: 0, animation: "none", blur: "none" }
    ]

    readonly property var animations: ({
        "none": { enabled: 0, type: "slide", fade: 0, zoomInitial: 1.0, zoomEnd: 1.0,
            open: 0, close: 0, move: 0, tag: 0, focus: 0,
            curveOpen: "0.0,0.0,1.0,1.0", curveClose: "0.0,0.0,1.0,1.0", curveMove: "0.0,0.0,1.0,1.0", curveTag: "0.0,0.0,1.0,1.0", curveFocus: "0.0,0.0,1.0,1.0" },
        "snappy": { enabled: 1, type: "slide", fade: 1, zoomInitial: 0.94, zoomEnd: 1.0,
            open: 240, close: 180, move: 220, tag: 260, focus: 140,
            curveOpen: "0.25,0.1,0.25,1.0", curveClose: "0.5,0.0,0.75,1.0", curveMove: "0.3,0.0,0.3,1.0", curveTag: "0.25,0.1,0.25,1.0", curveFocus: "0.4,0.0,0.2,1.0" },
        "calm": { enabled: 1, type: "slide", fade: 1, zoomInitial: 0.90, zoomEnd: 1.0,
            open: 480, close: 300, move: 420, tag: 720, focus: 240,
            curveOpen: "0.16,1.0,0.3,1.0", curveClose: "0.4,0.0,0.2,1.0", curveMove: "0.2,1.0,0.3,1.0", curveTag: "0.18,1.0,0.3,1.0", curveFocus: "0.4,0.0,0.2,1.0" },
        "bubbly": { enabled: 1, type: "slide", fade: 1, zoomInitial: 0.82, zoomEnd: 1.02,
            open: 350, close: 220, move: 320, tag: 380, focus: 180,
            curveOpen: "0.05,1.15,0.15,1.0", curveClose: "0.0,0.0,0.15,1.0", curveMove: "0.08,1.12,0.18,1.02", curveTag: "0.05,1.15,0.15,1.02", curveFocus: "0.0,0.0,0.15,1.0" },
        "extraslow": { enabled: 1, type: "slide", fade: 1, zoomInitial: 0.92, zoomEnd: 1.0,
            open: 640, close: 480, move: 560, tag: 800, focus: 360,
            curveOpen: "0.4,0.0,0.2,1.0", curveClose: "0.4,0.0,0.6,1.0", curveMove: "0.4,0.0,0.2,1.0", curveTag: "0.4,0.0,0.2,1.0", curveFocus: "0.4,0.0,0.6,1.0" }
    })

    readonly property var blurs: ({
        "frosted": { enabled: 1, layer: 1, optimized: 0, passes: 4, radius: 14 },
        "balanced": { enabled: 1, layer: 1, optimized: 0, passes: 3, radius: 10 },
        "subtle": { enabled: 1, layer: 1, optimized: 0, passes: 2, radius: 8 },
        "none": { enabled: 1, layer: 1, optimized: 0, passes: 0, radius: 0 }
    })

    function preset(id) {
        for (var i = 0; i < presets.length; i++) if (presets[i].id === id) return presets[i]
        return null
    }

    function animationPairs(name) {
        var c = animations[name] || animations.bubbly
        return {
            animations: c.enabled, layer_animations: c.enabled,
            animation_fade_in: c.fade, animation_fade_out: c.fade,
            animation_type_open: c.type, animation_type_close: c.type,
            layer_animation_type_open: c.type, layer_animation_type_close: c.type,
            zoom_initial_ratio: c.zoomInitial, zoom_end_ratio: c.zoomEnd,
            animation_duration_open: c.open, animation_duration_close: c.close,
            animation_duration_move: c.move, animation_duration_tag: c.tag,
            animation_duration_focus: c.focus,
            animation_curve_open: c.curveOpen, animation_curve_close: c.curveClose,
            animation_curve_move: c.curveMove, animation_curve_tag: c.curveTag,
            animation_curve_focus: c.curveFocus,
            animation_curve_opafadein: c.curveOpen,
            animation_curve_opafadeout: c.curveClose
        }
    }

    function blurPairs(name) {
        var c = blurs[name] || blurs.balanced
        return {
            blur: c.enabled, blur_layer: c.layer, blur_optimized: c.optimized,
            blur_params_num_passes: c.passes, blur_params_radius: c.radius,
            blur_params_noise: 0.02, blur_params_brightness: 0.9,
            blur_params_contrast: 0.9, blur_params_saturation: 1.2
        }
    }

    function merge(target, source) {
        for (var key in source) target[key] = source[key]
        return target
    }

    function stylePairs(presetId) {
        var p = preset(presetId)
        if (!p) return null
        var pairs = { border_radius: p.radius }
        merge(pairs, animationPairs(p.animation))
        merge(pairs, blurPairs(p.blur))
        return pairs
    }

    function n(value, fallback) {
        var parsed = Number(value)
        return isNaN(parsed) ? fallback : parsed
    }

    function curveDistance(value, expected) {
        var a = String(value || "").split(",")
        var b = String(expected).split(",")
        if (a.length !== 4) return 200
        var score = 0
        for (var i = 0; i < 4; i++) score += Math.abs(n(a[i], 0) - n(b[i], 0)) * 50
        return score
    }

    function animationDistance(data, c) {
        var enabled = String(data.animations) === "0" || data.animations === false ? 0 : 1
        var score = Math.abs(enabled - c.enabled) * 1000
        score += String(data.animation_type_open || "slide") === c.type ? 0 : 250
        score += Math.abs(n(data.animation_duration_open, c.open) - c.open) / 4
        score += Math.abs(n(data.animation_duration_close, c.close) - c.close) / 4
        score += Math.abs(n(data.animation_duration_move, c.move) - c.move) / 5
        score += Math.abs(n(data.animation_duration_tag, c.tag) - c.tag) / 6
        score += Math.abs(n(data.animation_duration_focus, c.focus) - c.focus) / 3
        score += Math.abs(n(data.zoom_initial_ratio, c.zoomInitial) - c.zoomInitial) * 500
        score += Math.abs(n(data.zoom_end_ratio, c.zoomEnd) - c.zoomEnd) * 500
        score += curveDistance(data.animation_curve_open, c.curveOpen)
        score += curveDistance(data.animation_curve_move, c.curveMove)
        return score
    }

    function inferAnimation(data) {
        if (String(data.animations) === "0" || data.animations === false) return "none"
        var best = animationOrder[0]
        var bestScore = Number.MAX_VALUE
        for (var i = 0; i < animationOrder.length; i++) {
            var name = animationOrder[i]
            var score = animationDistance(data, animations[name])
            if (score < bestScore) { best = name; bestScore = score }
        }
        return best
    }

    function inferBlur(data) {
        var best = blurOrder[0]
        var bestScore = Number.MAX_VALUE
        for (var i = 0; i < blurOrder.length; i++) {
            var name = blurOrder[i]
            var c = blurs[name]
            var score = Math.abs(n(data.blur_params_num_passes, c.passes) - c.passes) * 100
                + Math.abs(n(data.blur_params_radius, c.radius) - c.radius) * 10
                + Math.abs((String(data.blur) === "0" ? 0 : 1) - c.enabled) * 500
            if (score < bestScore) { best = name; bestScore = score }
        }
        return best
    }

    function matchingPreset(radius, animation, blur) {
        for (var i = 0; i < presets.length; i++) {
            var p = presets[i]
            if (p.radius === Number(radius) && p.animation === animation && p.blur === blur) return p.id
        }
        return "custom"
    }
}
