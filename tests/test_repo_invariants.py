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

    def test_relative_sources_use_mango_supported_prefix(self) -> None:
        """Mango only resolves relative includes when they start with ./ ."""
        sources = [
            line.split("=", 1)[1].strip()
            for line in active_lines(MAIN_CONFIG)
            if line.startswith("source=")
        ]

        invalid = [source for source in sources if not source.startswith("./")]
        self.assertEqual([], invalid, f"non-portable relative sources: {invalid}")

    def test_sources_are_unique(self) -> None:
        """A module must not be loaded more than once."""
        sources = [
            line.split("=", 1)[1].strip()
            for line in active_lines(MAIN_CONFIG)
            if line.startswith("source=")
        ]

        self.assertEqual(len(sources), len(set(sources)), "duplicate source= entries")


class RepositoryHygieneTests(unittest.TestCase):
    def test_temporary_patch_and_backup_artifacts_are_not_kept(self) -> None:
        forbidden = [
            REPO_ROOT / "patch.diff",
            REPO_ROOT / ".config" / "quickshell" / "DynamicIsland.qml.bak",
        ]
        present = [str(path.relative_to(REPO_ROOT)) for path in forbidden if path.exists()]
        self.assertEqual([], present, f"temporary artifacts still present: {present}")

    def test_repository_documentation_has_clear_homes(self) -> None:
        expected = [
            REPO_ROOT / "LICENSE",
            REPO_ROOT / "docs" / "architecture.md",
            REPO_ROOT / "docs" / "platform-support.md",
            REPO_ROOT / "docs" / "README.md",
            REPO_ROOT / "docs" / "archive" / "specs" / "project-improvements.md",
            REPO_ROOT / "docs" / "archive" / "reviews" / "bar-review.md",
            REPO_ROOT / "CONTRIBUTING.md",
        ]
        missing = [str(path.relative_to(REPO_ROOT)) for path in expected if not path.is_file()]
        self.assertEqual([], missing, f"documentation missing: {missing}")
        self.assertFalse((REPO_ROOT / "SPEC.md").exists())
        self.assertFalse((REPO_ROOT / "REVIEW-BAR.md").exists())

    def test_historical_documents_are_archived_outside_current_docs(self) -> None:
        archived = REPO_ROOT / "docs" / "archive"
        for relative in (
            "plans/dynamic-island-roadmap.md",
            "plans/wallhaven-downloader.md",
            "quickshell/island-concepts.md",
            "quickshell/island-plan.md",
            "quickshell/island-references.md",
            "reviews/bar-review.md",
            "specs/dynamic-island-refinements.md",
            "specs/project-improvements.md",
            "specs/wallhaven-downloader.md",
        ):
            with self.subTest(relative=relative):
                self.assertTrue((archived / relative).is_file())
        self.assertFalse((REPO_ROOT / "docs" / "plans").exists())
        self.assertFalse((REPO_ROOT / "docs" / "specs").exists())
        self.assertFalse((REPO_ROOT / "docs" / "quickshell").exists())
        self.assertFalse((REPO_ROOT / "docs" / "reviews").exists())

    def test_generated_development_artifacts_are_ignored(self) -> None:
        ignored = (REPO_ROOT / ".gitignore").read_text(encoding="utf-8")
        self.assertIn("__pycache__/", ignored)
        self.assertIn(".ruff_cache/", ignored)
        self.assertIn("graphify-out/", ignored)

    def test_license_and_contribution_terms_are_linked(self) -> None:
        license_text = (REPO_ROOT / "LICENSE").read_text(encoding="utf-8")
        contributing = (REPO_ROOT / "CONTRIBUTING.md").read_text(encoding="utf-8")
        self.assertTrue(license_text.startswith("MIT License"))
        self.assertIn("MIT License", contributing)
        self.assertIn("pkill quickshell", contributing)
        self.assertIn("nohup quickshell", contributing)

    def test_experimental_nix_port_is_documented_in_its_existing_checkout(self) -> None:
        nix_dir = REPO_ROOT / "nix port tests"
        self.assertTrue((nix_dir / "flake.nix").is_file())
        self.assertTrue((nix_dir / "README.md").is_file())
        package = (nix_dir / "pkgs" / "kamalen-python" / "default.nix").read_text(encoding="utf-8")
        self.assertIn("path = ./../../..;", package)

    def test_readmes_explain_the_supported_entrypoints(self) -> None:
        for name in ("README.md", "README.pt-BR.md"):
            content = (REPO_ROOT / name).read_text(encoding="utf-8")
            with self.subTest(name=name):
                self.assertIn("./install.sh --dry-run", content)
                self.assertIn("./install.sh verify", content)
                self.assertIn("docs/architecture.md", content)
                self.assertIn("nix port tests/", content)

    def test_platform_support_document_matches_installer_entrypoints(self) -> None:
        support = (REPO_ROOT / "docs" / "platform-support.md").read_text(encoding="utf-8")
        for script in ("install-fedora.sh", "install-opensuse.sh", "install-pacman.sh", "install-void.sh"):
            with self.subTest(script=script):
                self.assertTrue((REPO_ROOT / script).is_file())
                self.assertIn(script, support)
        self.assertIn("Linux Mint", support)
        self.assertIn("Zorin OS", support)
        self.assertIn("BigLinux", support)
        self.assertIn("Gentoo", support)
        self.assertIn("NixOS", support)


if __name__ == "__main__":
    unittest.main()
