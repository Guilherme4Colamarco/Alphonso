#!/usr/bin/env python3
"""Behavioral tests for the MangoWM configuration backend."""

from __future__ import annotations

import importlib.util
import json
import os
import tempfile
import unittest
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
from unittest import mock


REPO_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = REPO_ROOT / ".config" / "mango" / "mango_config.py"


def load_backend():
    spec = importlib.util.spec_from_file_location("kamalen_mango_config", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot import {MODULE_PATH}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class AtomicWriteTests(unittest.TestCase):
    def setUp(self) -> None:
        self.backend = load_backend()

    def test_atomic_write_preserves_original_if_replace_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "settings.conf"
            target.write_text("original\n", encoding="utf-8")

            with mock.patch.object(os, "replace", side_effect=OSError("replace failed")):
                with self.assertRaises(OSError):
                    self.backend.atomic_write_text(target, "replacement\n")

            self.assertEqual("original\n", target.read_text(encoding="utf-8"))
            self.assertEqual([target], list(Path(tmp).iterdir()))


class BatchWriteTests(unittest.TestCase):
    def setUp(self) -> None:
        self.backend = load_backend()
        self.tempdir = tempfile.TemporaryDirectory()
        self.config_dir = Path(self.tempdir.name)
        self.conf_dir = self.config_dir / "conf.d"
        self.conf_dir.mkdir()
        (self.config_dir / "config.conf").write_text(
            "source=./conf.d/gaps.conf\n", encoding="utf-8"
        )
        (self.conf_dir / "gaps.conf").write_text(
            "gappih=6\ngappiv=6\n", encoding="utf-8"
        )
        self.backend.CONFIG_DIR = self.config_dir
        self.backend.CONFIG_FILE = self.config_dir / "config.conf"
        self.backend.CONF_D_DIR = self.conf_dir

    def tearDown(self) -> None:
        self.tempdir.cleanup()

    def test_set_many_persists_all_values_in_one_batch_write(self) -> None:
        original_write_modules = self.backend.write_modules
        with mock.patch.object(
            self.backend, "write_modules", wraps=original_write_modules
        ) as write_modules:
            output = StringIO()
            with redirect_stdout(output):
                self.backend.cmd_set_many(
                    json.dumps({"gappih": 12, "gappiv": 14}),
                    reload_after=False,
                    apply_after=False,
                )

        self.assertEqual(1, write_modules.call_count)
        self.assertIn("gappih=12", (self.conf_dir / "gaps.conf").read_text())
        self.assertIn("gappiv=14", (self.conf_dir / "gaps.conf").read_text())
        self.assertTrue(json.loads(output.getvalue())["ok"])

    def test_write_modules_emits_mango_relative_source_syntax(self) -> None:
        self.backend.write_modules(
            {"gaps": ["gappih=6"], "borders": ["borderpx=2"]},
            ["source=./conf.d/gaps.conf"],
        )

        main = (self.config_dir / "config.conf").read_text(encoding="utf-8")
        self.assertIn("source=./conf.d/borders.conf", main)


class PersistentApplyTests(BatchWriteTests):
    def test_set_apply_persists_validates_and_reloads(self) -> None:
        output = StringIO()
        with (
            mock.patch.object(self.backend, "validate_config") as validate,
            mock.patch.object(self.backend, "mmsg_dispatch") as dispatch,
            redirect_stdout(output),
        ):
            self.backend.cmd_set_apply("gappih", "12")

        self.assertIn("gappih=12", (self.conf_dir / "gaps.conf").read_text())
        validate.assert_called_once_with()
        dispatch.assert_called_once_with(["reload_config"])
        result = json.loads(output.getvalue())
        self.assertTrue(result["ok"])
        self.assertTrue(result["persisted"])
        self.assertTrue(result["reloaded"])

    def test_set_apply_restores_persisted_value_when_reload_fails(self) -> None:
        original = (self.conf_dir / "gaps.conf").read_text(encoding="utf-8")
        output = StringIO()
        with (
            mock.patch.object(self.backend, "validate_config"),
            mock.patch.object(
                self.backend,
                "mmsg_dispatch",
                side_effect=RuntimeError("reload failed"),
            ) as dispatch,
            redirect_stdout(output),
            self.assertRaises(SystemExit),
        ):
            self.backend.cmd_set_apply("gappih", "12")

        self.assertEqual(original, (self.conf_dir / "gaps.conf").read_text())
        self.assertEqual(2, dispatch.call_count)
        self.assertIn("reload failed", json.loads(output.getvalue())["error"])


class DirectiveTransactionTests(BatchWriteTests):
    def setUp(self) -> None:
        super().setUp()
        (self.config_dir / "config.conf").write_text(
            "source=./conf.d/gaps.conf\nsource=./conf.d/binds.conf\n",
            encoding="utf-8",
        )
        (self.conf_dir / "binds.conf").write_text(
            "# keep this comment\nbind=SUPER,Return,spawn,kitty\n",
            encoding="utf-8",
        )

    def test_add_directive_validates_and_reloads_before_success(self) -> None:
        output = StringIO()
        with (
            mock.patch.object(self.backend, "validate_config") as validate,
            mock.patch.object(self.backend, "mmsg_dispatch") as dispatch,
            redirect_stdout(output),
        ):
            self.backend.cmd_add_directive("binds", "bind", "SUPER,b,spawn,firefox")

        validate.assert_called_once_with()
        dispatch.assert_called_once_with(["reload_config"])
        self.assertIn("bind=SUPER,b,spawn,firefox", (self.conf_dir / "binds.conf").read_text())
        self.assertTrue(json.loads(output.getvalue())["ok"])

    def test_add_directive_rolls_back_when_validation_fails(self) -> None:
        target = self.conf_dir / "binds.conf"
        original = target.read_text(encoding="utf-8")
        output = StringIO()
        with (
            mock.patch.object(
                self.backend, "validate_config", side_effect=RuntimeError("invalid bind")
            ),
            mock.patch.object(self.backend, "mmsg_dispatch") as dispatch,
            redirect_stdout(output),
            self.assertRaises(SystemExit),
        ):
            self.backend.cmd_add_directive("binds", "bind", "BROKEN")

        self.assertEqual(original, target.read_text(encoding="utf-8"))
        dispatch.assert_called_once_with(["reload_config"])
        self.assertIn("invalid bind", json.loads(output.getvalue())["error"])

    def test_remove_directive_rolls_back_when_reload_fails(self) -> None:
        target = self.conf_dir / "binds.conf"
        original = target.read_text(encoding="utf-8")
        output = StringIO()
        with (
            mock.patch.object(self.backend, "validate_config"),
            mock.patch.object(
                self.backend,
                "mmsg_dispatch",
                side_effect=[RuntimeError("reload failed"), None],
            ) as dispatch,
            redirect_stdout(output),
            self.assertRaises(SystemExit),
        ):
            self.backend.cmd_remove_directive("binds", 0)

        self.assertEqual(original, target.read_text(encoding="utf-8"))
        self.assertEqual(2, dispatch.call_count)
        self.assertIn("reload failed", json.loads(output.getvalue())["error"])


class StyleTransactionTests(BatchWriteTests):
    def setUp(self) -> None:
        super().setUp()
        (self.config_dir / "config.conf").write_text(
            "source=./conf.d/borders.conf\nsource=./conf.d/animations.conf\nsource=./conf.d/blur.conf\n",
            encoding="utf-8",
        )
        (self.conf_dir / "borders.conf").write_text("border_radius=8\n", encoding="utf-8")
        (self.conf_dir / "animations.conf").write_text("animations=1\nanimation_duration_open=240\n", encoding="utf-8")
        (self.conf_dir / "blur.conf").write_text("blur=1\nblur_params_radius=8\n", encoding="utf-8")

    def test_apply_style_updates_multiple_modules_atomically(self) -> None:
        output = StringIO()
        pairs = {"border_radius": 16, "animation_duration_open": 350, "blur_params_radius": 14}
        with (
            mock.patch.object(self.backend, "validate_config") as validate,
            mock.patch.object(self.backend, "mmsg_dispatch") as dispatch,
            redirect_stdout(output),
        ):
            self.backend.cmd_apply_style(json.dumps(pairs))

        validate.assert_called_once_with()
        dispatch.assert_called_once_with(["reload_config"])
        self.assertIn("border_radius=16", (self.conf_dir / "borders.conf").read_text())
        self.assertIn("animation_duration_open=350", (self.conf_dir / "animations.conf").read_text())
        self.assertIn("blur_params_radius=14", (self.conf_dir / "blur.conf").read_text())
        self.assertEqual(3, len(json.loads(output.getvalue())["modules"]))

    def test_apply_style_restores_all_modules_when_reload_fails(self) -> None:
        paths = [self.conf_dir / name for name in ("borders.conf", "animations.conf", "blur.conf")]
        originals = {path: path.read_text(encoding="utf-8") for path in paths}
        output = StringIO()
        with (
            mock.patch.object(self.backend, "validate_config"),
            mock.patch.object(
                self.backend, "mmsg_dispatch", side_effect=[RuntimeError("reload failed"), None]
            ) as dispatch,
            redirect_stdout(output),
            self.assertRaises(SystemExit),
        ):
            self.backend.cmd_apply_style(json.dumps({
                "border_radius": 0,
                "animation_duration_open": 0,
                "blur_params_radius": 0,
            }))

        for path, original in originals.items():
            self.assertEqual(original, path.read_text(encoding="utf-8"))
        self.assertEqual(2, dispatch.call_count)
        self.assertIn("reload failed", json.loads(output.getvalue())["error"])


class MonitorConfigurationTests(BatchWriteTests):
    def test_normalize_monitor_layout_moves_every_output_to_positive_origin(self) -> None:
        monitors = [
            {"name": "DP-1", "x": -1920, "y": 120, "width": 1920, "height": 1080},
            {"name": "HDMI-A-1", "x": 0, "y": -40, "width": 2560, "height": 1440},
        ]

        normalized = self.backend.normalize_monitor_layout(monitors)

        self.assertEqual(0, min(item["x"] for item in normalized))
        self.assertEqual(0, min(item["y"] for item in normalized))
        self.assertEqual(1920, normalized[1]["x"])

    def test_wlr_command_uses_mode_transform_scale_and_vrr(self) -> None:
        command = self.backend.wlr_command_for({
            "name": "DP-1", "width": 1920, "height": 1080,
            "refresh": 165.003, "x": 0, "y": 0, "scale": 1.25,
            "rr": 1, "vrr": 1, "custom": 0,
        })

        self.assertIn("1920x1080@165.003Hz", command)
        self.assertIn("90", command)
        self.assertIn("enabled", command)

    def test_probe_merges_live_outputs_with_persisted_monitor_rules(self) -> None:
        (self.conf_dir / "monitors.conf").write_text(
            "monitorrule=name:^DP-1$,width:1920,height:1080,refresh:165,x:0,y:0,scale:1,vrr:1,rr:0\n",
            encoding="utf-8",
        )
        wlr = [{
            "name": "DP-1", "description": "AOC Panel", "enabled": True,
            "position": {"x": 0, "y": 0}, "scale": 1.0,
            "transform": "normal", "adaptive_sync": True,
            "modes": [{"width": 1920, "height": 1080, "refresh": 165.003, "current": True}],
        }]
        # Mango IPC reports logical dimensions after output scaling. Physical
        # mode dimensions must continue to come from wlr-randr.
        mango = {"monitors": [{"name": "DP-1", "active": True, "x": 0, "y": 0, "width": 1536, "height": 864, "scale": 1.25}]}

        result = self.backend.merge_monitor_sources(wlr, mango)

        self.assertEqual("AOC Panel", result[0]["description"])
        self.assertEqual(1920, result[0]["width"])
        self.assertEqual(1080, result[0]["height"])
        self.assertEqual(165.003, result[0]["refresh"])
        self.assertEqual(1, result[0]["vrr"])
        self.assertTrue(result[0]["configured"])


if __name__ == "__main__":
    unittest.main()
