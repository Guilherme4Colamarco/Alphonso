#!/usr/bin/env python3
"""Smoke tests for the non-Arch installer entrypoints."""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


class CrossDistroInstallerTests(unittest.TestCase):
    def run_installer(self, script: str, os_release: str, *args: str) -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            release = root / "os-release"
            release.write_text(os_release, encoding="utf-8")
            home = root / "home"
            home.mkdir()
            return subprocess.run(
                [str(REPO_ROOT / script), *args],
                cwd=REPO_ROOT,
                text=True,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                env={**os.environ, "HOME": str(home), "KAMALEN_OS_RELEASE": str(release)},
                check=False,
            )

    def test_entrypoints_are_executable_and_parse_as_bash(self) -> None:
        for script in ("install-fedora.sh", "install-opensuse.sh", "install-pacman.sh", "install-void.sh"):
            path = REPO_ROOT / script
            with self.subTest(script=script):
                self.assertTrue(path.is_file())
                self.assertTrue(os.access(path, os.X_OK))
                result = subprocess.run(["bash", "-n", str(path)], text=True, capture_output=True, check=False)
                self.assertEqual(0, result.returncode, result.stderr)

    def test_fedora_dry_run_uses_dnf_without_mutating(self) -> None:
        result = self.run_installer("install-fedora.sh", "ID=fedora\nID_LIKE='fedora rhel'\n", "--dry-run", "deps")
        self.assertEqual(0, result.returncode, result.stdout)
        self.assertIn("dry-run: sudo dnf install", result.stdout)
        self.assertIn("Fedora", result.stdout)

    def test_opensuse_dry_run_uses_zypper_without_third_party_repos(self) -> None:
        result = self.run_installer("install-opensuse.sh", "ID=opensuse-tumbleweed\nID_LIKE=suse\n", "--dry-run", "deps")
        self.assertEqual(0, result.returncode, result.stdout)
        self.assertIn("dry-run: sudo zypper install", result.stdout)
        self.assertNotIn("repo add", result.stdout)

    def test_biglinux_uses_pacman_and_keeps_aur_opt_in(self) -> None:
        result = self.run_installer("install-pacman.sh", "ID=biglinux\nID_LIKE='arch manjaro'\n", "--dry-run", "deps")
        self.assertEqual(0, result.returncode, result.stdout)
        self.assertIn("dry-run: sudo pacman -S --needed", result.stdout)
        self.assertIn("AUR is disabled", result.stdout)

    def test_void_config_dry_run_is_available_without_systemd_assumptions(self) -> None:
        result = self.run_installer("install-void.sh", "ID=void\nID_LIKE=void\n", "--dry-run", "configs")
        self.assertEqual(0, result.returncode, result.stdout)
        self.assertIn("Void Linux", result.stdout)
        self.assertNotIn("systemctl enable", result.stdout)


if __name__ == "__main__":
    unittest.main()
