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


if __name__ == "__main__":
    unittest.main()
