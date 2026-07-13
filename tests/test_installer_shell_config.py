#!/usr/bin/env python3
"""Behavior tests for shell configuration offered by the installers."""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
INSTALLERS = ("install.sh", "install-debian.sh")


class InstallerShellConfigTests(unittest.TestCase):
    def configure(
        self, installer: str, choice: int, initial_file: str, repetitions: int = 1
    ) -> tuple[subprocess.CompletedProcess[str], str]:
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            config_path = {
                1: home / ".config" / "fish" / "config.fish",
                2: home / ".zshrc",
                3: home / ".bashrc",
            }[choice]
            config_path.parent.mkdir(parents=True, exist_ok=True)
            config_path.write_text(initial_file, encoding="utf-8")

            shell_name = {1: "fish", 2: "zsh", 3: "bash"}[choice]
            harness = f"""
source {REPO_ROOT / installer!s}
DRY_RUN=false
command_exists() {{ return 0; }}
which() {{ printf '/usr/bin/%s\\n' "$1"; }}
sudo() {{ :; }}
chsh() {{ :; }}
for ((run = 0; run < {repetitions}; run++)); do
    configure_user_shell
done
"""
            result = subprocess.run(
                ["bash", "-c", harness],
                text=True,
                input=f"{choice}\n" * repetitions,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                env={
                    **os.environ,
                    "HOME": str(home),
                    "USER": "kamalen-test",
                    "SHELL": f"/usr/bin/{shell_name}",
                },
                check=False,
            )
            return result, config_path.read_text(encoding="utf-8")

    def test_fish_preserves_existing_config_and_enables_starship_and_vi_mode(self) -> None:
        for installer in INSTALLERS:
            with self.subTest(installer=installer):
                result, config = self.configure(installer, 1, "# user customization\n")
                self.assertEqual(0, result.returncode, result.stdout)
                self.assertIn("# user customization", config)
                self.assertIn("fish_vi_key_bindings", config)
                self.assertIn("starship init fish | source", config)

    def test_zsh_enables_starship_and_vi_mode(self) -> None:
        for installer in INSTALLERS:
            with self.subTest(installer=installer):
                result, config = self.configure(installer, 2, "# user customization\n")
                self.assertEqual(0, result.returncode, result.stdout)
                self.assertIn("# user customization", config)
                self.assertIn("bindkey -v", config)
                self.assertIn("starship init zsh", config)

    def test_bash_enables_starship_and_vi_mode(self) -> None:
        for installer in INSTALLERS:
            with self.subTest(installer=installer):
                result, config = self.configure(installer, 3, "# user customization\n")
                self.assertEqual(0, result.returncode, result.stdout)
                self.assertIn("# user customization", config)
                self.assertIn("set -o vi", config)
                self.assertIn("starship init bash", config)

    def test_configuration_is_idempotent(self) -> None:
        expected_markers = {
            1: ("fish_vi_key_bindings", "starship init fish"),
            2: ("bindkey -v", "starship init zsh"),
            3: ("set -o vi", "starship init bash"),
        }
        for installer in INSTALLERS:
            for choice, markers in expected_markers.items():
                with self.subTest(installer=installer, choice=choice):
                    result, config = self.configure(
                        installer, choice, "# user customization\n", repetitions=2
                    )
                    self.assertEqual(0, result.returncode, result.stdout)
                    for marker in markers:
                        self.assertEqual(1, config.count(marker), marker)


if __name__ == "__main__":
    unittest.main()
