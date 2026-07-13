#!/usr/bin/env python3
"""Regression tests for Debian/Ubuntu installer dry-run behavior."""

from __future__ import annotations

import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
INSTALL_SCRIPT = REPO_ROOT / "install-debian.sh"


class DebianInstallDryRunTests(unittest.TestCase):
    def run_installer(
        self, *args: str, stdin: str | None = None
    ) -> subprocess.CompletedProcess[str]:
        script = INSTALL_SCRIPT.read_text(encoding="utf-8")
        main_guard = 'if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then\n    main "$@"\nfi'
        self.assertTrue(script.rstrip().endswith(main_guard))
        script = script.rstrip()[: -len(main_guard)]
        quoted_args = " ".join(f"'{arg}'" for arg in args)
        harness = f"""{script}
preflight() {{ :; }}
main {quoted_args}
"""
        with tempfile.TemporaryDirectory() as home:
            harness_path = Path(home) / "install-harness.sh"
            harness_path.write_text(harness, encoding="utf-8")
            return subprocess.run(
                ["bash", str(harness_path)],
                text=True,
                input=stdin,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                env={"HOME": home, "PATH": "/usr/bin:/bin"},
                check=False,
            )

    def test_full_dry_run_does_not_prompt_or_fail_without_stdin(self) -> None:
        result = self.run_installer("--dry-run")
        self.assertEqual(0, result.returncode, result.stdout)
        self.assertIn("DRY RUN MODE", result.stdout)

    def test_config_dry_run_handles_an_empty_home_directory(self) -> None:
        result = self.run_installer("--dry-run", "configs")
        self.assertEqual(0, result.returncode, result.stdout)
        self.assertNotIn("Installation failed", result.stdout)

    def test_dry_run_never_rewrites_an_existing_fish_config(self) -> None:
        script = INSTALL_SCRIPT.read_text(encoding="utf-8")
        main_guard = 'if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then\n    main "$@"\nfi'
        script = script.rstrip()[: -len(main_guard)]
        harness = f"""{script}
preflight() {{ :; }}
main --dry-run
"""
        original_config = "set -gx STARSHIP_CONFIG ~/.config/starship.toml\n"

        with tempfile.TemporaryDirectory() as home:
            fish_config = Path(home) / ".config" / "fish" / "config.fish"
            fish_config.parent.mkdir(parents=True)
            fish_config.write_text(original_config, encoding="utf-8")
            harness_path = Path(home) / "install-harness.sh"
            harness_path.write_text(harness, encoding="utf-8")
            result = subprocess.run(
                ["bash", str(harness_path)],
                text=True,
                input="1\n",
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                env={"HOME": home, "PATH": "/usr/bin:/bin"},
                check=False,
            )

            self.assertEqual(0, result.returncode, result.stdout)
            self.assertEqual(original_config, fish_config.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
