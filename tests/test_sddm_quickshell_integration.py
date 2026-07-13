#!/usr/bin/env python3
"""Regression tests for the Quickshell to SDDM state bridge."""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

from PIL import Image


REPO_ROOT = Path(__file__).resolve().parents[1]
QML_DIR = REPO_ROOT / ".config" / "quickshell"
IRIS = QML_DIR / "iris" / "iris.py"


class SddmQuickshellIntegrationTests(unittest.TestCase):
    def test_iris_publishes_canonical_palette_atomically(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            wallpaper = home / "wallpaper.png"
            Image.new("RGB", (32, 18), "#335577").save(wallpaper)
            result = subprocess.run(
                [
                    "python3",
                    str(IRIS),
                    "--wallpaper",
                    str(wallpaper),
                    "--dark",
                    "1",
                    "--glass",
                    "0",
                ],
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env={**os.environ, "HOME": str(home)},
                check=False,
            )

            self.assertEqual(0, result.returncode, result.stderr)
            palette = json.loads(result.stdout)
            canonical = home / ".cache" / "qs" / "current-palette.json"
            self.assertEqual(palette, json.loads(canonical.read_text(encoding="utf-8")))
            self.assertEqual([], list(canonical.parent.glob(".current-palette.*")))

    def test_color_updates_debounce_sddm_sync(self) -> None:
        colors = (QML_DIR / "Colors.qml").read_text(encoding="utf-8")
        self.assertIn("id: sddmSyncDelay", colors)
        self.assertIn("sddmSyncDelay.restart()", colors)
        self.assertIn("kamalen-sddm-sync", colors)

    def test_visual_settings_updates_debounce_sddm_sync(self) -> None:
        ui_state = (QML_DIR / "UIState.qml").read_text(encoding="utf-8")
        self.assertIn("id: sddmSyncDelay", ui_state)
        self.assertIn("kamalen-sddm-sync", ui_state)
        self.assertRegex(ui_state, r"id:\s*saveProc[\s\S]*onExited:[\s\S]*sddmSyncDelay\.restart\(\)")


if __name__ == "__main__":
    unittest.main()
