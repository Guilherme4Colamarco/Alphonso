#!/usr/bin/env python3
"""Security regressions for the convenience lockscreen integration."""

from __future__ import annotations

import importlib.util
import re
import unittest
from pathlib import Path
from unittest import mock


REPO_ROOT = Path(__file__).resolve().parents[1]
QML_DIR = REPO_ROOT / ".config" / "quickshell"
AUTH_HELPER = QML_DIR / "lockscreen_auth.py"


class LockscreenSecurityTests(unittest.TestCase):
    def test_pam_configuration_never_allows_null_passwords(self) -> None:
        offenders = []
        for name in ("install.sh", "install-debian.sh"):
            script = (REPO_ROOT / name).read_text(encoding="utf-8")
            if re.search(r"auth required pam_unix\.so[^\n]*\bnullok\b", script):
                offenders.append(name)
        self.assertEqual([], offenders)

    def test_lock_closes_sensitive_overlays(self) -> None:
        ui_state = (QML_DIR / "UIState.qml").read_text(encoding="utf-8")
        lock_body = re.search(
            r"function lock\(\) \{(?P<body>.*?)\n\s*\}", ui_state, re.DOTALL
        )
        self.assertIsNotNone(lock_body)
        body = lock_body.group("body")
        self.assertIn("closeTransientSurfaces()", body)
        close_body = re.search(
            r"function closeTransientSurfaces\(\) \{(?P<body>.*?)\n\s*\}",
            ui_state,
            re.DOTALL,
        )
        self.assertIsNotNone(close_body)
        body = close_body.group("body")
        for expected in (
            'activeDropdown = ""',
            "powerMenuVisible = false",
            "layoutMenuVisible = false",
            "clipboardMenuVisible = false",
        ):
            self.assertIn(expected, body)

    def test_external_overlay_watchers_are_ignored_while_locked(self) -> None:
        shell = (QML_DIR / "shell.qml").read_text(encoding="utf-8")
        self.assertIn('if (route !== "lock" && UIState.locked) return', shell)
        self.assertGreaterEqual(shell.count("case \""), 9)
        self.assertIn('case "lock": UIState.lock(); break', shell)

    def test_password_is_sent_to_fixed_helper_over_stdin(self) -> None:
        lockscreen = (QML_DIR / "Lockscreen.qml").read_text(encoding="utf-8")
        self.assertIn("lockscreen_auth.py", lockscreen)
        self.assertNotIn('"python3", "-u", "-c"', lockscreen)
        self.assertRegex(lockscreen, r"authProc\.write\(password \+ \"\\n\"\)")

    def test_auth_helper_forwards_special_password_as_data(self) -> None:
        self.assertTrue(AUTH_HELPER.is_file(), "missing fixed PAM helper")
        spec = importlib.util.spec_from_file_location("lockscreen_auth", AUTH_HELPER)
        self.assertIsNotNone(spec)
        self.assertIsNotNone(spec.loader)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        pam_client = mock.Mock()
        pam_client.authenticate.return_value = True
        password = "quote' unicode-ç symbols-$()"

        result = module.authenticate(pam_client, "geko", password)

        self.assertTrue(result)
        pam_client.authenticate.assert_called_once_with(
            "geko", password, service="lockscreen"
        )


if __name__ == "__main__":
    unittest.main()
