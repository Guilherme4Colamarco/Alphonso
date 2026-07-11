#!/usr/bin/env python3
"""Repository-level regression tests for Kamalen Shell configuration."""

from __future__ import annotations

import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
MANGO_DIR = REPO_ROOT / ".config" / "mango"
MAIN_CONFIG = MANGO_DIR / "config.conf"


def active_lines(path: Path) -> list[str]:
    """Return non-empty, non-comment configuration lines."""
    return [
        line.strip()
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]


class MangoConfigLayoutTests(unittest.TestCase):
    def test_main_config_is_source_only(self) -> None:
        """The root config must not duplicate options owned by conf.d."""
        lines = active_lines(MAIN_CONFIG)

        self.assertTrue(lines, "config.conf must source at least one module")
        self.assertTrue(
            all(line.startswith("source=") for line in lines),
            "config.conf must contain only source= directives",
        )

    def test_every_source_target_exists(self) -> None:
        """Every source declared by config.conf must resolve inside mango/."""
        sources = [
            line.split("=", 1)[1].strip()
            for line in active_lines(MAIN_CONFIG)
            if line.startswith("source=")
        ]

        missing = [source for source in sources if not (MANGO_DIR / source).is_file()]
        self.assertEqual([], missing, f"missing sourced modules: {missing}")

    def test_sources_are_unique(self) -> None:
        """A module must not be loaded more than once."""
        sources = [
            line.split("=", 1)[1].strip()
            for line in active_lines(MAIN_CONFIG)
            if line.startswith("source=")
        ]

        self.assertEqual(len(sources), len(set(sources)), "duplicate source= entries")


if __name__ == "__main__":
    unittest.main()
