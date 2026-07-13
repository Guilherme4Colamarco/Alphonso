#!/usr/bin/env python3
"""Integration tests for the shared, distro-neutral SDDM installer."""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
INSTALLER = REPO_ROOT / "scripts" / "install" / "sddm-theme.sh"


class SddmInstallerTests(unittest.TestCase):
    def run_installer(
        self, root: Path, *args: str, stdin: str | None = None, present: str = "1"
    ) -> subprocess.CompletedProcess[str]:
        env = os.environ.copy()
        env.update(
            {
                "KAMALEN_SDDM_PRESENT": present,
                "KAMALEN_SDDM_THEME_SOURCE": str(root / "source" / "kamalen"),
                "KAMALEN_SDDM_SYNC_SOURCE": str(root / "source" / "kamalen-sddm-sync"),
                "KAMALEN_SDDM_THEME_DIR": str(root / "usr/share/sddm/themes/kamalen"),
                "KAMALEN_SDDM_STATE_DIR": str(root / "var/lib/kamalen-sddm"),
                "KAMALEN_SDDM_CONFIG": str(root / "etc/sddm.conf.d/99-kamalen-theme.conf"),
                "KAMALEN_SDDM_BIN": str(root / "usr/local/bin/kamalen-sddm-sync"),
                "KAMALEN_SDDM_TEST_MODE": "1",
            }
        )
        return subprocess.run(
            ["bash", str(INSTALLER), *args],
            text=True,
            input=stdin,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            env=env,
            check=False,
        )

    @staticmethod
    def make_source(root: Path) -> None:
        theme = root / "source" / "kamalen"
        theme.mkdir(parents=True)
        (theme / "Main.qml").write_text("import QtQuick\nItem {}\n", encoding="utf-8")
        sync = root / "source" / "kamalen-sddm-sync"
        sync.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
        sync.chmod(0o755)

    def test_absent_sddm_is_a_successful_noop(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            result = self.run_installer(root, "install", present="0")
            self.assertEqual(0, result.returncode, result.stdout)
            self.assertIn("SDDM is not installed", result.stdout)
            self.assertFalse((root / "usr").exists())

    def test_dry_run_never_mutates_or_prompts(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.make_source(root)
            result = self.run_installer(root, "--dry-run", "install")
            self.assertEqual(0, result.returncode, result.stdout)
            self.assertIn("dry-run", result.stdout)
            self.assertFalse((root / "usr").exists())
            self.assertFalse((root / "var").exists())
            self.assertFalse((root / "etc").exists())

    def test_install_copies_assets_but_does_not_activate_by_default(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.make_source(root)
            result = self.run_installer(root, "install", stdin="\n")
            self.assertEqual(0, result.returncode, result.stdout)
            self.assertTrue((root / "usr/share/sddm/themes/kamalen/Main.qml").is_file())
            theme_user = root / "usr/share/sddm/themes/kamalen/theme.conf.user"
            self.assertTrue(theme_user.is_symlink())
            self.assertEqual(
                str(root / "var/lib/kamalen-sddm/theme.conf.user"), os.readlink(theme_user)
            )
            self.assertTrue((root / "usr/local/bin/kamalen-sddm-sync").is_file())
            self.assertTrue((root / "var/lib/kamalen-sddm").is_dir())
            self.assertEqual(0o750, (root / "var/lib/kamalen-sddm").stat().st_mode & 0o777)
            self.assertFalse((root / "etc/sddm.conf.d/99-kamalen-theme.conf").exists())
            self.assertNotIn("systemctl restart", result.stdout)

    def test_verify_rejects_a_wrong_theme_user_link(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.make_source(root)
            self.assertEqual(0, self.run_installer(root, "install", stdin="\n").returncode)
            theme_user = root / "usr/share/sddm/themes/kamalen/theme.conf.user"
            theme_user.unlink()
            theme_user.symlink_to(root / "tmp/untrusted.conf")
            result = self.run_installer(root, "verify")
            self.assertNotEqual(0, result.returncode)
            self.assertIn("invalid theme.conf.user symlink", result.stdout)

    def test_explicit_confirmation_creates_only_the_owned_dropin(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.make_source(root)
            previous = root / "etc/sddm.conf.d/10-existing.conf"
            previous.parent.mkdir(parents=True)
            previous.write_text("[Theme]\nCurrent=other\n", encoding="utf-8")
            result = self.run_installer(root, "install", stdin="y\n")
            self.assertEqual(0, result.returncode, result.stdout)
            dropin = root / "etc/sddm.conf.d/99-kamalen-theme.conf"
            self.assertEqual("[Theme]\nCurrent=kamalen\n", dropin.read_text(encoding="utf-8"))
            self.assertEqual("[Theme]\nCurrent=other\n", previous.read_text(encoding="utf-8"))

    def test_verify_and_scoped_uninstall(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.make_source(root)
            self.assertEqual(0, self.run_installer(root, "--yes", "install").returncode)
            self.assertEqual(0, self.run_installer(root, "verify").returncode)
            unrelated = root / "etc/sddm.conf.d/10-existing.conf"
            unrelated.write_text("[Theme]\nCurrent=other\n", encoding="utf-8")
            result = self.run_installer(root, "uninstall")
            self.assertEqual(0, result.returncode, result.stdout)
            self.assertTrue(unrelated.is_file())
            self.assertFalse((root / "usr/share/sddm/themes/kamalen").exists())
            self.assertFalse((root / "usr/local/bin/kamalen-sddm-sync").exists())
            self.assertFalse((root / "etc/sddm.conf.d/99-kamalen-theme.conf").exists())

    def test_primary_installers_expose_sddm_command(self) -> None:
        for name in ("install.sh", "install-debian.sh"):
            text = (REPO_ROOT / name).read_text(encoding="utf-8")
            self.assertIn("sddm", text)
            self.assertIn("install_sddm_theme", text)

        experimental = (REPO_ROOT / "scripts/install/experimental-installer.sh").read_text(
            encoding="utf-8"
        )
        self.assertIn("sddm", experimental)

    def test_repository_sources_and_no_restart_policy(self) -> None:
        self.assertTrue((REPO_ROOT / "sddm/kamalen/Main.qml").is_file())
        self.assertTrue((REPO_ROOT / "scripts/sddm/sync-kamalen-sddm.py").is_file())
        installer = INSTALLER.read_text(encoding="utf-8")
        self.assertNotIn("systemctl restart sddm", installer)
        self.assertIn("99-kamalen-theme.conf", installer)


if __name__ == "__main__":
    unittest.main()
