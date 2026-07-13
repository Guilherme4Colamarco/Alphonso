#!/usr/bin/env python3
"""Regression checks for the pill bar connectivity controls."""

from __future__ import annotations

import re
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
BAR_PATH = REPO_ROOT / ".config" / "quickshell" / "Bar.qml"


class PillConnectivityButtonTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.bar = BAR_PATH.read_text(encoding="utf-8")
        match = re.search(
            r"component PillBarContent: Item \{(?P<body>.*?)\n\s*Variants \{",
            cls.bar,
            flags=re.DOTALL,
        )
        if match is None:
            raise AssertionError("PillBarContent was not found")
        cls.pill = match.group("body")

    def test_connectivity_managers_are_available_to_the_bar(self) -> None:
        self.assertIn(
            'id: wifiManager; command: ["nm-connection-editor"]', self.bar
        )
        self.assertIn('id: btManager; command: ["blueman-manager"]', self.bar)

    def test_pill_left_click_opens_connectivity_managers(self) -> None:
        self.assertIn("onClicked: wifiManager.running = true", self.pill)
        self.assertIn("onClicked: btManager.running = true", self.pill)

    def test_pill_right_click_toggles_connectivity_radios(self) -> None:
        self.assertIn("onRightClicked: wifiToggle.running = true", self.pill)
        self.assertIn("onRightClicked: btToggle.running = true", self.pill)

    def test_connected_wifi_keeps_a_visible_icon(self) -> None:
        self.assertIn('icon: wifi ? "󰤨" : "󰤭"', self.pill)
        self.assertNotIn('icon: wifi ? "" : "󰤭"', self.pill)


if __name__ == "__main__":
    unittest.main()
