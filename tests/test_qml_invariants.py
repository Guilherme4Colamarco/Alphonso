#!/usr/bin/env python3
"""Static regression checks for high-confidence QML integration bugs."""

from __future__ import annotations

import re
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
QML_DIR = REPO_ROOT / ".config" / "quickshell"


class QmlIntegrationTests(unittest.TestCase):
    def test_qml_does_not_hardcode_repository_owner_home(self) -> None:
        offenders = []
        for path in sorted(QML_DIR.rglob("*.qml")):
            if "/home/geko" in path.read_text(encoding="utf-8"):
                offenders.append(str(path.relative_to(REPO_ROOT)))

        self.assertEqual([], offenders, f"hardcoded user paths: {offenders}")

    def test_dropdown_state_uses_media_route_consistently(self) -> None:
        bar = (QML_DIR / "Bar.qml").read_text(encoding="utf-8")
        self.assertNotIn('activeDropdown === "music"', bar)

    def test_pill_is_the_default_bar_mode(self) -> None:
        state = (QML_DIR / "UIState.qml").read_text(encoding="utf-8")
        self.assertIn('property string barMode: "pill"', state)

    def test_mango_config_waits_for_backend_confirmation(self) -> None:
        bridge = (QML_DIR / "MangoConfig.qml").read_text(encoding="utf-8")
        self.assertIn("signal configurationApplied(string key, var value)", bridge)
        self.assertIn("signal configurationFailed(string key, string message)", bridge)
        self.assertIn("function _startNextSet()", bridge)
        self.assertIn("setProc.command = [\"python3\", _configPath, \"set-apply\"", bridge)
        self.assertIn("configurationApplied(operation.key, operation.value)", bridge)
        self.assertIn("configurationFailed(operation.key, message)", bridge)

    def test_settings_are_moved_to_one_normal_window(self) -> None:
        shell = (QML_DIR / "shell.qml").read_text(encoding="utf-8")
        dashboard = (QML_DIR / "Dashboard.qml").read_text(encoding="utf-8")
        settings = (QML_DIR / "SettingsWindow.qml").read_text(encoding="utf-8")

        self.assertIn("SettingsWindow {}", shell)
        self.assertIn("FloatingWindow", settings)
        self.assertIn("UIState.settingsVisible", settings)
        for tab in ("LookTab", "MangoTab", "BindsTab", "WindowRulesTab", "MonitorsTab"):
            self.assertIn(tab + " {", settings)
            self.assertNotIn(tab + " {", dashboard)
        self.assertNotIn("DisplayTab {", settings)
        self.assertIn("UIState.openSettings()", dashboard)

    def test_directive_operations_are_serial_and_confirmed(self) -> None:
        bridge = (QML_DIR / "MangoConfig.qml").read_text(encoding="utf-8")

        self.assertIn("signal directiveApplied(string module, string action)", bridge)
        self.assertIn("signal directiveFailed(string module, string action, string message)", bridge)
        self.assertIn("function _startNextDirective()", bridge)
        self.assertIn("directiveProc.command", bridge)
        self.assertNotIn("property var _dirCallback", bridge)

    def test_shared_style_profiles_have_four_canonical_presets(self) -> None:
        profiles = (QML_DIR / "StyleProfiles.qml").read_text(encoding="utf-8")
        qmldir = (QML_DIR / "qmldir").read_text(encoding="utf-8")

        for preset in ("rounded-elastic", "balanced", "compact-fast", "minimal"):
            self.assertIn('id: "' + preset + '"', profiles)
        self.assertIn("function inferAnimation", profiles)
        self.assertIn("function inferBlur", profiles)
        self.assertIn("function matchingPreset", profiles)
        self.assertIn("singleton StyleProfiles 1.0 StyleProfiles.qml", qmldir)

    def test_style_changes_use_confirmed_atomic_backend_path(self) -> None:
        bridge = (QML_DIR / "MangoConfig.qml").read_text(encoding="utf-8")
        state = (QML_DIR / "UIState.qml").read_text(encoding="utf-8")
        appearance = (QML_DIR / "tabs" / "LookTab.qml").read_text(encoding="utf-8")

        self.assertIn('styleProc.command = ["python3", _configPath, "apply-style"', bridge)
        self.assertIn("signal styleApplied(var pairs)", bridge)
        self.assertIn("function adoptMangoStyle()", state)
        self.assertIn("function applyStylePreset(presetId)", state)
        self.assertIn("MangoConfig.loadAll()", state)
        self.assertIn("UIState.applyStylePreset(modelData.id)", appearance)
        self.assertIn('property string activeStylePreset: "custom"', state)

    def test_global_ui_scale_uses_shared_metrics(self) -> None:
        metrics = (QML_DIR / "Metrics.qml").read_text(encoding="utf-8")
        state = (QML_DIR / "UIState.qml").read_text(encoding="utf-8")
        settings = (QML_DIR / "SettingsWindow.qml").read_text(encoding="utf-8")
        qmldir = (QML_DIR / "qmldir").read_text(encoding="utf-8")

        self.assertIn("function dp(value)", metrics)
        self.assertIn("function sp(value)", metrics)
        self.assertIn("UIState.uiScale", metrics)
        self.assertIn("property real uiScale: 1.15", state)
        self.assertIn("function setUiScale", state)
        self.assertIn("Metrics.dp(", settings)
        self.assertIn("Metrics.sp(", settings)
        self.assertIn("singleton Metrics 1.0 Metrics.qml", qmldir)

    def test_settings_has_five_gnome_like_panels(self) -> None:
        settings = (QML_DIR / "SettingsWindow.qml").read_text(encoding="utf-8")

        for component in ("LookTab", "MonitorsTab", "MangoTab", "BindsTab", "WindowRulesTab"):
            self.assertIn(component + " {", settings)
        self.assertNotIn("DisplayTab {", settings)
        self.assertIn("compactNavigation", settings)
        self.assertIn("UIState.vimNavigationEnabled", settings)
        self.assertIn("Keys.onPressed", settings)
        self.assertIn('event.text === "j"', settings)
        self.assertIn('event.text === "k"', settings)

    def test_monitor_panel_uses_discovery_diagram_and_safe_preview(self) -> None:
        monitors = (QML_DIR / "tabs" / "MonitorsTab.qml").read_text(encoding="utf-8")

        self.assertIn('"probe-monitors"', monitors)
        self.assertIn("id: arrangementCanvas", monitors)
        self.assertIn("Drag.active", monitors)
        self.assertIn("Parâmetros complexos", monitors)
        self.assertIn("preview-monitors", monitors)
        self.assertIn("confirm-monitor-preview", monitors)
        self.assertIn("revert-monitor-preview", monitors)
        self.assertNotIn("addMonitorFn", monitors)

    def test_aesthetic_profiles_are_independent_and_tokenized(self) -> None:
        aesthetics = (QML_DIR / "Aesthetics.qml").read_text(encoding="utf-8")
        state = (QML_DIR / "UIState.qml").read_text(encoding="utf-8")
        qmldir = (QML_DIR / "qmldir").read_text(encoding="utf-8")

        for profile in ("tui-style", "pills", "gnome-like"):
            self.assertIn('"' + profile + '"', aesthetics)
        for token in (
            "containerRadius", "controlRadius", "buttonRadius", "fieldRadius",
            "sliderTrackHeight", "sliderThumbSize", "progressHeight", "switchWidth",
        ):
            self.assertIn(token, aesthetics)
        self.assertIn('property string aestheticProfile: "pills"', state)
        self.assertIn("function applyAestheticProfile", state)
        self.assertIn("singleton Aesthetics 1.0 Aesthetics.qml", qmldir)

    def test_shared_controls_use_aesthetic_tokens(self) -> None:
        controls = "\n".join(
            (QML_DIR / "components" / name).read_text(encoding="utf-8")
            for name in ("ConfigToggle.qml", "ConfigSlider.qml", "ConfigSpinner.qml", "TileButton.qml")
        )

        self.assertIn("Aesthetics.controlRadius", controls)
        self.assertIn("Aesthetics.sliderTrackHeight", controls)
        self.assertIn("Aesthetics.sliderThumbSize", controls)
        self.assertIn("Aesthetics.switchWidth", controls)

    def test_appearance_exposes_three_aesthetic_previews(self) -> None:
        appearance = (QML_DIR / "tabs" / "LookTab.qml").read_text(encoding="utf-8")

        self.assertIn("Aesthetics.profiles", appearance)
        self.assertIn("UIState.applyAestheticProfile(modelData.id)", appearance)
        self.assertIn("AestheticPreview", appearance)

    def test_clipboard_row_children_do_not_use_horizontal_anchors(self) -> None:
        clipboard = (QML_DIR / "ClipboardMenu.qml").read_text(encoding="utf-8")
        image_row = re.search(
            r"// ── Image Row ──(?P<body>.*?)Rectangle \{\n\s+anchors\.fill",
            clipboard,
            flags=re.DOTALL,
        )

        self.assertIsNotNone(image_row, "clipboard image row was not found")
        body = image_row.group("body")
        self.assertNotIn("left: parent.left", body)

    def test_popups_use_current_anchor_api(self) -> None:
        for name in ("TrayPopup.qml", "BluetoothPopup.qml"):
            popup = (QML_DIR / name).read_text(encoding="utf-8")
            with self.subTest(name=name):
                self.assertNotRegex(popup, r"^\s*parentWindow:", msg=name)
                self.assertNotRegex(popup, r"^\s*relative[XY]:", msg=name)
                self.assertIn("anchor.window:", popup)

    def test_local_wallpaper_carousel_has_bounded_delegates(self) -> None:
        wallpaper = (QML_DIR / "Wallpaper.qml").read_text(encoding="utf-8")
        carousel = re.search(
            r"id: sceneRoot(?P<body>.*?)\n\s*MouseArea \{\n\s*anchors\.fill: parent",
            wallpaper,
            flags=re.DOTALL,
        )

        self.assertIsNotNone(carousel, "local wallpaper carousel was not found")
        body = carousel.group("body")
        self.assertNotIn("model: filtered", body)
        self.assertIn("model: 7", body)
        self.assertIn("property int wallIndex", body)

    def test_wallhaven_flow_requires_preview_before_download(self) -> None:
        wallpaper = (QML_DIR / "Wallpaper.qml").read_text(encoding="utf-8")

        self.assertIn("id: onlineToolbar", wallpaper)
        self.assertIn("id: onlinePreview", wallpaper)
        self.assertIn("function selectOnlineItem(index)", wallpaper)
        self.assertIn("function startOnlineDownload(item)", wallpaper)
        self.assertIn("onClicked: selectOnlineItem(index)", wallpaper)

    def test_wallhaven_has_distinct_error_and_download_feedback(self) -> None:
        wallpaper = (QML_DIR / "Wallpaper.qml").read_text(encoding="utf-8")

        self.assertIn('property string onlineSearchError: ""', wallpaper)
        self.assertIn('property string downloadState: "idle"', wallpaper)
        self.assertIn("id: downloadStatus", wallpaper)
        self.assertIn("if (currentPage === 1) onlineModel.clear()", wallpaper)

    def test_wallhaven_exposes_random_discovery(self) -> None:
        wallpaper = (QML_DIR / "Wallpaper.qml").read_text(encoding="utf-8")

        self.assertIn("function showRandomWallpapers()", wallpaper)
        self.assertIn("id: randomButton", wallpaper)
        self.assertIn("onClicked: showRandomWallpapers()", wallpaper)
        self.assertIn("runOnlineSearch(\"\", 1, true)", wallpaper)

    def test_wallhaven_backend_returns_search_errors_as_json(self) -> None:
        helper = (QML_DIR / "wallhaven" / "wallhaven.py").read_text(encoding="utf-8")

        self.assertIn('print(json.dumps({"error": str(e)}))', helper)

    def test_live_wallpaper_tab_has_secure_explicit_flow(self) -> None:
        wallpaper = (QML_DIR / "Wallpaper.qml").read_text(encoding="utf-8")
        live_tab = (QML_DIR / "LiveWallpaperTab.qml").read_text(encoding="utf-8")
        state = (QML_DIR / "UIState.qml").read_text(encoding="utf-8")
        qmldir = (QML_DIR / "qmldir").read_text(encoding="utf-8")
        live_sources = wallpaper + live_tab

        self.assertIn('property string livewallpaperScript:', wallpaper)
        self.assertIn('{ name: "live", label:', wallpaper)
        self.assertIn("id: liveRoot", wallpaper)
        self.assertIn("id: livePreviewLoader", live_sources)
        self.assertIn("function startLiveDownload(item)", live_sources)
        self.assertIn("LiveWallpaperTab 1.0 LiveWallpaperTab.qml", qmldir)
        self.assertNotIn("pexelsApiKey", state)

    def test_live_wallpaper_uses_desktophut_catalog_flow(self) -> None:
        live_tab = (QML_DIR / "LiveWallpaperTab.qml").read_text(encoding="utf-8")
        l10n = (QML_DIR / "L10n.qml").read_text(encoding="utf-8")
        helper = (QML_DIR / "livewallpaper" / "livewallpaper.py").read_text(encoding="utf-8")
        sources = live_tab + l10n + helper

        self.assertIn('runLiveListing("featured", "", 1)', live_tab)
        self.assertIn("nextPage", live_tab)
        self.assertIn("hasMore", live_tab)
        self.assertIn("item.license", live_tab)
        self.assertIn("item.license_url", live_tab)
        self.assertIn("item.attribution", live_tab)
        self.assertIn("DesktopHut", sources)
        self.assertIn("Destaques", l10n)
        self.assertIn("live_no_results", live_tab)
        self.assertIn("Nenhum vídeo correspondente", l10n)
        for obsolete in ("Pexels", "pexels", "Wikimedia Commons", "commons-", "PEXELS_API_KEY", 'command: ["python3", root.scriptPath, "status"]'):
            self.assertNotIn(obsolete, sources)

    def test_video_wallpaper_playback_is_optimized_and_lock_aware(self) -> None:
        wallpaper = (QML_DIR / "Wallpaper.qml").read_text(encoding="utf-8")
        shell = (QML_DIR / "shell.qml").read_text(encoding="utf-8")

        for source in (wallpaper, shell):
            self.assertIn("hwdec=auto-safe", source)
            self.assertIn("loop-file=inf", source)
        self.assertIn('locked ? "-STOP" : "-CONT"', shell)


if __name__ == "__main__":
    unittest.main()
