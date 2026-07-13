#!/usr/bin/env python3
"""Tests for generated Kamalen GTK color and aesthetic styles."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = REPO_ROOT / ".config" / "quickshell" / "gtk_theme.py"


def load_helper():
    spec = importlib.util.spec_from_file_location("kamalen_gtk_theme", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot import {MODULE_PATH}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class GtkThemeTests(unittest.TestCase):
    def setUp(self) -> None:
        self.helper = load_helper()
        self.palette = {
            "accent": "#cba6f7", "bg": "#1e1e2e", "fg": "#cdd6f4",
            "surface": "#313244", "dim": "#6c7086", "red": "#f38ba8",
            "green": "#a6e3a1", "yellow": "#f9e2af",
        }

    def test_profile_css_has_distinct_widget_geometry(self) -> None:
        tui = self.helper.aesthetic_css("tui-style", 4)
        pills = self.helper.aesthetic_css("pills", 4)
        gnome = self.helper.aesthetic_css("gnome-like", 4)

        self.assertIn("border-radius: 0px", tui)
        self.assertIn("border-radius: 999px", pills)
        self.assertIn("border-radius: 8px", gnome)
        for css in (tui, pills, gnome):
            self.assertIn("progressbar", css)
            self.assertIn("scale slider", css)
            self.assertIn("switch slider", css)

    def test_write_theme_preserves_user_css_and_imports_once(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            for version in (3, 4):
                folder = base / f"gtk-{version}.0"
                folder.mkdir()
                (folder / "gtk.css").write_text("/* user rule */\nbutton.custom { color: red; }\n")

            self.helper.write_theme(base, self.palette, "pills")
            self.helper.write_theme(base, self.palette, "pills")

            for version in (3, 4):
                folder = base / f"gtk-{version}.0"
                root = (folder / "gtk.css").read_text()
                self.assertIn("button.custom", root)
                self.assertEqual(1, root.count('kamalen-colors.css'))
                self.assertEqual(1, root.count('kamalen-aesthetic.css'))
                self.assertTrue((folder / "kamalen-colors.css").exists())
                self.assertIn("border-radius: 999px", (folder / "kamalen-aesthetic.css").read_text())


if __name__ == "__main__":
    unittest.main()
