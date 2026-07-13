#!/usr/bin/env python3
"""Static contract tests for the root-owned Kamalen SDDM theme source."""

from __future__ import annotations

import re
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
THEME_DIR = REPO_ROOT / "sddm" / "kamalen"


class SddmThemeTests(unittest.TestCase):
    def setUp(self) -> None:
        self.main = (THEME_DIR / "Main.qml").read_text(encoding="utf-8")

    def test_theme_has_sddm_metadata_and_safe_fallbacks(self) -> None:
        metadata = (THEME_DIR / "metadata.desktop").read_text(encoding="utf-8")
        config = (THEME_DIR / "theme.conf").read_text(encoding="utf-8")

        self.assertIn("[SddmGreeterTheme]", metadata)
        self.assertIn("MainScript=Main.qml", metadata)
        self.assertIn("Theme-API=2.0", metadata)
        self.assertIn("QtVersion=6", metadata)
        self.assertIn("[General]", config)
        self.assertRegex(config, r"(?m)^Background=assets/fallback-background\.svg$")
        self.assertRegex(config, r"(?m)^Avatar=assets/fallback-avatar\.svg$")

        for relative in ("assets/fallback-background.svg", "assets/fallback-avatar.svg"):
            self.assertTrue((THEME_DIR / relative).is_file(), relative)

        for key in ("Screenshot", "TranslationsDirectory"):
            match = re.search(rf"(?m)^{key}=(.*)$", metadata)
            if match and match.group(1):
                self.assertTrue((THEME_DIR / match.group(1)).exists(), f"missing {key}")

    def test_qml_uses_qt6_imports_without_optional_effect_modules(self) -> None:
        imports = re.findall(r"(?m)^import\s+(.+)$", self.main)

        self.assertIn("QtQuick", imports)
        self.assertIn("QtQuick.Controls.Basic", imports)
        self.assertFalse(any(re.search(r"\s\d+(?:\.\d+)*$", item) for item in imports))
        self.assertNotIn("Qt5Compat", self.main)
        self.assertNotIn("GraphicalEffects", self.main)
        self.assertNotIn("MultiEffect", self.main)
        self.assertNotIn("ShaderEffect", self.main)

    def test_runtime_state_uses_official_config_object_and_fixed_assets(self) -> None:
        self.assertIn('readonly property string assetRoot: "file:///var/lib/kamalen-sddm/"', self.main)
        self.assertIn('readonly property string dynamicBackground: assetRoot + "background-blurred.jpg"', self.main)
        self.assertIn('readonly property string dynamicAvatar: assetRoot + "owner-avatar.png"', self.main)
        self.assertIn("function configColor", self.main)
        self.assertIn("function configBoolean", self.main)
        self.assertIn("function configuredAsset", self.main)
        self.assertIn("config.Bg", self.main)
        self.assertIn("config.BlurredBackground", self.main)
        self.assertIn("config.OwnerUsername", self.main)
        self.assertNotIn("Qt.createComponent", self.main)
        self.assertNotIn("XMLHttpRequest", self.main)
        self.assertNotIn("JSON.parse", self.main)
        self.assertNotRegex(self.main, r"(?:source|loader)\s*:\s*config\.")
        self.assertNotRegex(self.main, r"(?:/home/|file://\$?HOME|\.config/quickshell)")
        self.assertNotIn("importPath", self.main)

    def test_theme_implements_authentication_and_keyboard_flow(self) -> None:
        for token in (
            "sddm.login(",
            "function onLoginFailed()",
            "function onLoginSucceeded()",
            "TextInput.Password",
            "Qt.Key_Return",
            "Qt.Key_Enter",
            "Qt.Key_Escape",
            "Qt.Key_Left",
            "Qt.Key_Right",
            "KeyNavigation.tab",
            "shakeAnimation",
        ):
            self.assertIn(token, self.main)

    def test_theme_supports_users_sessions_and_power_actions(self) -> None:
        for token in (
            "userModel",
            "sessionModel",
            "ownerAvatar",
            "userIcon",
            "selectPreviousUser",
            "selectNextUser",
            "sddm.suspend()",
            "sddm.reboot()",
            "sddm.powerOff()",
        ):
            self.assertIn(token, self.main)

    def test_theme_matches_lock_visual_contract_and_primary_screen(self) -> None:
        for token in (
            "Screen.primaryOrientation",
            "background-blurred",
            "timeText",
            "dateText",
            "passwordDots",
            "powerActions",
            "JetBrainsMono Nerd Font",
        ):
            self.assertIn(token, self.main)


if __name__ == "__main__":
    unittest.main()
