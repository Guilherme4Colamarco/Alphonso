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


if __name__ == "__main__":
    unittest.main()
