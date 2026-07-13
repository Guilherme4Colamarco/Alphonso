import QtQuick
import ".."

Flickable {
    width: parent.width
    height: parent.height
    contentHeight: col.height + 20
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    property var animationTypes: ["slide", "zoom", "fade", "none"]
    property var directionLabels: ["Vertical", "Horizontal"]

    Column {
        id: col
        width: parent.width
        spacing: Metrics.dp(10)
        Rectangle {
            visible: MangoConfig.lastError !== ""
            width: parent.width
            height: visible ? errorText.implicitHeight + 16 : 0
            radius: UIState.borderRadius * 0.625
            color: Colors.a(Colors.red, 0.12)
            border.width: 1
            border.color: Colors.a(Colors.red, 0.35)

            Text {
                id: errorText
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                anchors { leftMargin: 10; rightMargin: 10 }
                text: L10n.tr("mango_apply_failed", "Mango configuration was not applied") + ": " + MangoConfig.lastError
                color: Colors.a(Colors.fg, 0.9)
                font { pixelSize: Metrics.sp(10); family: "JetBrainsMono Nerd Font" }
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: MangoConfig.lastError = ""
            }
        }

        // ── Tiling ───────────────────────────────────────────────────────────
        ConfigSection {
            title: L10n.tr("tiling", "Tiling")
            icon: "󰙀"
            expanded: false
            width: parent.width

            ConfigSlider {
                label: L10n.tr("inner_gap_h", "Inner gap (horizontal)")
                value: MangoConfig.mangoGappih
                minValue: 0; maxValue: 64; stepSize: 1; unit: "px"
                onValueModified: v => MangoConfig.set("gappih", v)
            }
            ConfigSlider {
                label: L10n.tr("inner_gap_v", "Inner gap (vertical)")
                value: MangoConfig.mangoGappiv
                minValue: 0; maxValue: 64; stepSize: 1; unit: "px"
                onValueModified: v => MangoConfig.set("gappiv", v)
            }
            ConfigSlider {
                label: L10n.tr("outer_gap_h", "Outer gap (horizontal)")
                value: MangoConfig.mangoGappoh
                minValue: 0; maxValue: 64; stepSize: 1; unit: "px"
                onValueModified: v => MangoConfig.set("gappoh", v)
            }
            ConfigSlider {
                label: L10n.tr("outer_gap_v", "Outer gap (vertical)")
                value: MangoConfig.mangoGappov
                minValue: 0; maxValue: 64; stepSize: 1; unit: "px"
                onValueModified: v => MangoConfig.set("gappov", v)
            }
            ConfigSlider {
                label: L10n.tr("border_width", "Border width")
                value: MangoConfig.mangoBorderPx
                minValue: 0; maxValue: 8; stepSize: 1; unit: "px"
                onValueModified: v => MangoConfig.set("borderpx", v)
            }
            ConfigSlider {
                label: L10n.tr("border_radius", "Border radius")
                value: MangoConfig.mangoBorderRadius
                minValue: 0; maxValue: 32; stepSize: 1; unit: "px"
                onValueModified: v => MangoConfig.set("border_radius", v)
            }
            ConfigToggle {
                label: L10n.tr("no_border_single", "No border when single")
                checked: MangoConfig.mangoNoBorderWhenSingle
                onToggled: c => MangoConfig.set("no_border_when_single", c)
            }
            ConfigToggle {
                label: L10n.tr("no_radius_single", "No radius when single")
                checked: MangoConfig.mangoNoRadiusWhenSingle
                onToggled: c => MangoConfig.set("no_radius_when_single", c)
            }
            ConfigToggle {
                label: L10n.tr("smart_gaps", "Smart gaps")
                checked: MangoConfig.mangoSmartGaps
                onToggled: c => MangoConfig.set("smartgaps", c)
            }
            ConfigSlider {
                label: L10n.tr("master_factor", "Master factor")
                value: MangoConfig.mangoDefaultMfact
                minValue: 0.1; maxValue: 0.9; stepSize: 0.05
                onValueModified: v => MangoConfig.set("default_mfact", v)
            }
            ConfigSlider {
                label: L10n.tr("master_count", "Master count")
                value: MangoConfig.mangoDefaultNmaster
                minValue: 1; maxValue: 5; stepSize: 1
                onValueModified: v => MangoConfig.set("default_nmaster", v)
            }
        }

        // ── Blur ─────────────────────────────────────────────────────────────
        ConfigSection {
            title: L10n.tr("blur", "Blur")
            icon: "󰂵"
            expanded: false
            width: parent.width

            ConfigToggle {
                label: L10n.tr("blur", "Blur")
                checked: MangoConfig.mangoBlur
                onToggled: c => MangoConfig.set("blur", c)
            }
            ConfigToggle {
                label: L10n.tr("blur_layer", "Blur layer surfaces")
                checked: MangoConfig.mangoBlurLayer
                onToggled: c => MangoConfig.set("blur_layer", c)
            }
            ConfigToggle {
                label: L10n.tr("blur_optimized", "Optimized blur")
                checked: MangoConfig.mangoBlurOptimized
                onToggled: c => MangoConfig.set("blur_optimized", c)
            }
            ConfigSlider {
                label: L10n.tr("blur_passes", "Blur passes")
                value: MangoConfig.mangoBlurPasses
                minValue: 0; maxValue: 8; stepSize: 1
                onValueModified: v => MangoConfig.set("blur_params_num_passes", v)
            }
            ConfigSlider {
                label: L10n.tr("blur_radius", "Blur radius")
                value: MangoConfig.mangoBlurRadius
                minValue: 0; maxValue: 30; stepSize: 1; unit: "px"
                onValueModified: v => MangoConfig.set("blur_params_radius", v)
            }
        }

        // ── Shadows ──────────────────────────────────────────────────────────
        ConfigSection {
            title: L10n.tr("shadows", "Shadows")
            icon: "󰧑"
            expanded: false
            width: parent.width

            ConfigToggle {
                label: L10n.tr("shadows", "Shadows")
                checked: MangoConfig.mangoShadows
                onToggled: c => MangoConfig.set("shadows", c)
            }
            ConfigToggle {
                label: L10n.tr("layer_shadows", "Layer shadows")
                checked: MangoConfig.mangoShadowLayer
                onToggled: c => MangoConfig.set("layer_shadows", c)
            }
            ConfigToggle {
                label: L10n.tr("shadow_float", "Shadow only on floating")
                checked: MangoConfig.mangoShadowOnlyFloating
                onToggled: c => MangoConfig.set("shadow_only_floating", c)
            }
            ConfigSlider {
                label: L10n.tr("shadow_size", "Shadow size")
                value: MangoConfig.mangoShadowSize
                minValue: 0; maxValue: 48; stepSize: 1; unit: "px"
                onValueModified: v => MangoConfig.set("shadows_size", v)
            }
            ConfigSlider {
                label: L10n.tr("shadow_blur", "Shadow blur")
                value: MangoConfig.mangoShadowBlur
                minValue: 0; maxValue: 40; stepSize: 1; unit: "px"
                onValueModified: v => MangoConfig.set("shadows_blur", v)
            }
            ConfigSlider {
                label: L10n.tr("shadow_x", "Shadow offset X")
                value: MangoConfig.mangoShadowPosX
                minValue: -20; maxValue: 20; stepSize: 1; unit: "px"
                onValueModified: v => MangoConfig.set("shadows_position_x", v)
            }
            ConfigSlider {
                label: L10n.tr("shadow_y", "Shadow offset Y")
                value: MangoConfig.mangoShadowPosY
                minValue: -20; maxValue: 20; stepSize: 1; unit: "px"
                onValueModified: v => MangoConfig.set("shadows_position_y", v)
            }
        }

        // ── Opacity ──────────────────────────────────────────────────────────
        ConfigSection {
            title: L10n.tr("opacity", "Opacity")
            icon: "󰌁"
            expanded: false
            width: parent.width

            ConfigSlider {
                label: L10n.tr("focus_opacity", "Focused opacity")
                value: MangoConfig.mangoFocusedOpacity
                minValue: 0.2; maxValue: 1.0; stepSize: 0.05
                onValueModified: v => MangoConfig.set("focused_opacity", v)
            }
            ConfigSlider {
                label: L10n.tr("unfocus_opacity", "Unfocused opacity")
                value: MangoConfig.mangoUnfocusedOpacity
                minValue: 0.2; maxValue: 1.0; stepSize: 0.05
                onValueModified: v => MangoConfig.set("unfocused_opacity", v)
            }
        }

        // ── Input ────────────────────────────────────────────────────────────
        ConfigSection {
            title: L10n.tr("input", "Input")
            icon: "󰌌"
            expanded: false
            width: parent.width

            ConfigSlider {
                label: L10n.tr("repeat_rate", "Repeat rate")
                value: MangoConfig.mangoRepeatRate
                minValue: 10; maxValue: 100; stepSize: 5
                onValueModified: v => MangoConfig.set("repeat_rate", v)
            }
            ConfigSlider {
                label: L10n.tr("repeat_delay", "Repeat delay")
                value: MangoConfig.mangoRepeatDelay
                minValue: 100; maxValue: 1000; stepSize: 50; unit: "ms"
                onValueModified: v => MangoConfig.set("repeat_delay", v)
            }
            ConfigToggle {
                label: L10n.tr("tap_click", "Tap to click")
                checked: MangoConfig.mangoTapToClick
                onToggled: c => MangoConfig.set("tap_to_click", c)
            }
            ConfigToggle {
                label: L10n.tr("natural_scroll", "Natural scrolling")
                checked: MangoConfig.mangoTrackpadNaturalScroll
                onToggled: c => MangoConfig.set("trackpad_natural_scrolling", c)
            }
        }

        // ── Focus ────────────────────────────────────────────────────────────
        ConfigSection {
            title: L10n.tr("focus", "Focus")
            icon: "󰁥"
            expanded: false
            width: parent.width

            ConfigToggle {
                label: L10n.tr("focus_activate", "Focus on activate")
                checked: MangoConfig.mangoFocusOnActivate
                onToggled: c => MangoConfig.set("focus_on_activate", c)
            }
            ConfigToggle {
                label: L10n.tr("sloppy_focus", "Sloppy focus")
                checked: MangoConfig.mangoSloppyFocus
                onToggled: c => MangoConfig.set("sloppyfocus", c)
            }
            ConfigToggle {
                label: L10n.tr("warp_cursor", "Warp cursor")
                checked: MangoConfig.mangoWarpCursor
                onToggled: c => MangoConfig.set("warpcursor", c)
            }
            ConfigToggle {
                label: L10n.tr("focus_monitor", "Focus cross monitor")
                checked: MangoConfig.mangoFocusCrossMonitor
                onToggled: c => MangoConfig.set("focus_cross_monitor", c)
            }
            ConfigToggle {
                label: L10n.tr("focus_tag", "Focus cross tag")
                checked: MangoConfig.mangoFocusCrossTag
                onToggled: c => MangoConfig.set("focus_cross_tag", c)
            }
            ConfigToggle {
                label: L10n.tr("float_snap", "Floating snap")
                checked: MangoConfig.mangoEnableFloatingSnap
                onToggled: c => MangoConfig.set("enable_floating_snap", c)
            }
            ConfigToggle {
                label: L10n.tr("drag_tile", "Drag tile to tile")
                checked: MangoConfig.mangoDragTileToTile
                onToggled: c => MangoConfig.set("drag_tile_to_tile", c)
            }
            ConfigSlider {
                label: L10n.tr("snap_distance", "Snap distance")
                value: MangoConfig.mangoSnapDistance
                minValue: 0; maxValue: 100; stepSize: 1; unit: "px"
                onValueModified: v => MangoConfig.set("snap_distance", v)
            }
        }

        // ── Animations ───────────────────────────────────────────────────────
        ConfigSection {
            title: L10n.tr("animations", "Animations")
            icon: "󰔵"
            expanded: false
            width: parent.width

            ConfigToggle {
                label: L10n.tr("animations", "Animations")
                checked: MangoConfig.mangoAnimations
                onToggled: c => MangoConfig.set("animations", c)
            }
            ConfigToggle {
                label: L10n.tr("layer_anim", "Layer animations")
                checked: MangoConfig.mangoLayerAnimations
                onToggled: c => MangoConfig.set("layer_animations", c)
            }
            ConfigToggle {
                label: L10n.tr("fade_in", "Fade in")
                checked: MangoConfig.mangoAnimationFadeIn
                onToggled: c => MangoConfig.set("animation_fade_in", c)
            }
            ConfigToggle {
                label: L10n.tr("fade_out", "Fade out")
                checked: MangoConfig.mangoAnimationFadeOut
                onToggled: c => MangoConfig.set("animation_fade_out", c)
            }
            ConfigSpinner {
                label: L10n.tr("open_anim", "Open animation")
                model: animationTypes
                currentIndex: animationTypes.indexOf(MangoConfig.mangoAnimationTypeOpen)
                onActivated: idx => MangoConfig.set("animation_type_open", animationTypes[idx])
            }
            ConfigSpinner {
                label: L10n.tr("close_anim", "Close animation")
                model: animationTypes
                currentIndex: animationTypes.indexOf(MangoConfig.mangoAnimationTypeClose)
                onActivated: idx => MangoConfig.set("animation_type_close", animationTypes[idx])
            }
            ConfigSpinner {
                label: L10n.tr("layer_open", "Layer open animation")
                model: animationTypes
                currentIndex: animationTypes.indexOf(MangoConfig.mangoLayerAnimationTypeOpen)
                onActivated: idx => MangoConfig.set("layer_animation_type_open", animationTypes[idx])
            }
            ConfigSpinner {
                label: L10n.tr("layer_close", "Layer close animation")
                model: animationTypes
                currentIndex: animationTypes.indexOf(MangoConfig.mangoLayerAnimationTypeClose)
                onActivated: idx => MangoConfig.set("layer_animation_type_close", animationTypes[idx])
            }
            ConfigSpinner {
                label: L10n.tr("tag_dir", "Tag animation direction")
                model: directionLabels
                currentIndex: MangoConfig.mangoAnimationDirection
                onActivated: idx => MangoConfig.set("tag_animation_direction", idx)
            }
            ConfigSlider {
                label: L10n.tr("open_dur", "Open duration")
                value: MangoConfig.mangoAnimationDurationOpen
                minValue: 0; maxValue: 1000; stepSize: 20; unit: "ms"
                onValueModified: v => MangoConfig.set("animation_duration_open", v)
            }
            ConfigSlider {
                label: L10n.tr("close_dur", "Close duration")
                value: MangoConfig.mangoAnimationDurationClose
                minValue: 0; maxValue: 1000; stepSize: 20; unit: "ms"
                onValueModified: v => MangoConfig.set("animation_duration_close", v)
            }
            ConfigSlider {
                label: L10n.tr("move_dur", "Move duration")
                value: MangoConfig.mangoAnimationDurationMove
                minValue: 0; maxValue: 1000; stepSize: 20; unit: "ms"
                onValueModified: v => MangoConfig.set("animation_duration_move", v)
            }
            ConfigSlider {
                label: L10n.tr("tag_dur", "Tag duration")
                value: MangoConfig.mangoAnimationDurationTag
                minValue: 0; maxValue: 1000; stepSize: 20; unit: "ms"
                onValueModified: v => MangoConfig.set("animation_duration_tag", v)
            }
            ConfigSlider {
                label: L10n.tr("focus_dur", "Focus duration")
                value: MangoConfig.mangoAnimationDurationFocus
                minValue: 0; maxValue: 1000; stepSize: 20; unit: "ms"
                onValueModified: v => MangoConfig.set("animation_duration_focus", v)
            }
            ConfigSlider {
                label: L10n.tr("zoom_init", "Zoom initial ratio")
                value: MangoConfig.mangoZoomInitialRatio
                minValue: 0.1; maxValue: 1.0; stepSize: 0.02
                onValueModified: v => MangoConfig.set("zoom_initial_ratio", v)
            }
            ConfigSlider {
                label: L10n.tr("zoom_end", "Zoom end ratio")
                value: MangoConfig.mangoZoomEndRatio
                minValue: 1.0; maxValue: 1.2; stepSize: 0.02
                onValueModified: v => MangoConfig.set("zoom_end_ratio", v)
            }
            ConfigSlider {
                label: L10n.tr("fade_in_begin", "Fade-in begin opacity")
                value: MangoConfig.mangoFadeinBeginOpacity
                minValue: 0.0; maxValue: 1.0; stepSize: 0.05
                onValueModified: v => MangoConfig.set("fadein_begin_opacity", v)
            }
            ConfigSlider {
                label: L10n.tr("fade_out_begin", "Fade-out begin opacity")
                value: MangoConfig.mangoFadeoutBeginOpacity
                minValue: 0.0; maxValue: 1.0; stepSize: 0.05
                onValueModified: v => MangoConfig.set("fadeout_begin_opacity", v)
            }
        }

        // ── Colors ───────────────────────────────────────────────────────────
        ConfigSection {
            title: L10n.tr("colors", "Colors")
            icon: "󰏘"
            expanded: false
            width: parent.width

            ConfigColorRow {
                label: L10n.tr("color_root", "Root")
                colorValue: MangoConfig.mangoRootColor
                onColorChanged: c => MangoConfig.set("rootcolor", c)
            }
            ConfigColorRow {
                label: L10n.tr("color_border", "Border")
                colorValue: MangoConfig.mangoBorderColor
                onColorChanged: c => MangoConfig.set("bordercolor", c)
            }
            ConfigColorRow {
                label: L10n.tr("color_focus", "Focus")
                colorValue: MangoConfig.mangoFocusColor
                onColorChanged: c => MangoConfig.set("focuscolor", c)
            }
            ConfigColorRow {
                label: L10n.tr("color_urgent", "Urgent")
                colorValue: MangoConfig.mangoUrgentColor
                onColorChanged: c => MangoConfig.set("urgentcolor", c)
            }
            ConfigColorRow {
                label: L10n.tr("color_scratchpad", "Scratchpad")
                colorValue: MangoConfig.mangoScratchpadColor
                onColorChanged: c => MangoConfig.set("scratchpadcolor", c)
            }
            ConfigColorRow {
                label: L10n.tr("color_global", "Global")
                colorValue: MangoConfig.mangoGlobalColor
                onColorChanged: c => MangoConfig.set("globalcolor", c)
            }
            ConfigColorRow {
                label: L10n.tr("color_overlay", "Overlay")
                colorValue: MangoConfig.mangoOverlayColor
                onColorChanged: c => MangoConfig.set("overlaycolor", c)
            }
            ConfigColorRow {
                label: L10n.tr("color_maximize", "Maximized screen")
                colorValue: MangoConfig.mangoMaximizescreenColor
                onColorChanged: c => MangoConfig.set("maximizescreencolor", c)
            }
            ConfigColorRow {
                label: L10n.tr("color_shadows", "Shadows")
                colorValue: MangoConfig.mangoShadowColor
                onColorChanged: c => MangoConfig.set("shadowscolor", c)
            }
        }
    }
}
