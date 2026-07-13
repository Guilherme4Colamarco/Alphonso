import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "scripts/sddm/sync-kamalen-sddm.py"


def load_module():
    spec = importlib.util.spec_from_file_location("kamalen_sddm_sync", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


class SddmSyncTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.wallpapers = self.root / "wallpapers"
        self.cache = self.root / "cache"
        self.pfps = self.root / "pfps"
        self.state_dir = self.root / "sddm-state"
        self.settings = self.root / "settings.json"
        self.palette = self.cache / "current-palette.json"
        for directory in (self.wallpapers, self.cache, self.pfps):
            directory.mkdir(parents=True)
        self.wall = self.wallpapers / "lake.png"
        Image.new("RGB", (5000, 2500), "#345678").save(self.wall)
        (self.wallpapers / "current").symlink_to(self.wall.name)
        Image.new("RGB", (128, 128), "#abcdef").save(self.pfps / "01-first.png")
        Image.new("RGB", (128, 128), "#123456").save(self.pfps / "02-second.png")
        self.settings.write_text(json.dumps({
            "darkMode": False,
            "blurProfile": "balanced",
            "borderRadius": 18,
            "pfpIndex": 1,
        }))
        self.palette.write_text(json.dumps({
            "bg": "#101820", "fg": "#f0f4f8", "accent": "#00aaff",
            "green": "#33cc66", "red": "#ee3355", "yellow": "#ffcc33",
            "surface": "#182430", "dim": "#708090", "tone_l": 0.2,
        }))
        self.mod = load_module()

    def tearDown(self):
        self.tmp.cleanup()

    def args(self, **overrides):
        values = dict(
            wallpaper=self.wallpapers / "current",
            palette=self.palette,
            settings=self.settings,
            pfp_dir=self.pfps,
            thumb_dir=self.cache / "wallpaper-thumbs",
            state_dir=self.state_dir,
            owner_username="alice",
        )
        values.update(overrides)
        return self.mod.SyncConfig(**values)

    def test_static_sync_resizes_to_4k_and_exports_valid_state(self):
        changed = self.mod.sync(self.args())
        self.assertTrue(changed)
        with Image.open(self.state_dir / "background.jpg") as image:
            self.assertEqual(image.size, (3840, 1920))
        with Image.open(self.state_dir / "background-blurred.jpg") as image:
            self.assertEqual(image.size, (3840, 1920))
        with Image.open(self.state_dir / "owner-avatar.png") as avatar:
            self.assertEqual(avatar.getpixel((0, 0))[:3], (18, 52, 86))
            self.assertEqual(0, avatar.getpixel((0, 0))[3])
            self.assertEqual(255, avatar.getpixel((128, 128))[3])
        state = json.loads((self.state_dir / "state.json").read_text())
        self.assertEqual(state["palette"]["accent"], "#00aaff")
        self.assertFalse(state["darkMode"])
        self.assertEqual(state["blurProfile"], "balanced")
        self.assertEqual(state["borderRadius"], 18)
        self.assertNotIn(str(self.root), json.dumps(state))

        theme = (self.state_dir / "theme.conf.user").read_text()
        self.assertIn("[General]\n", theme)
        self.assertIn("Accent=#00aaff\n", theme)
        self.assertIn("DarkMode=false\n", theme)
        self.assertIn("BlurProfile=balanced\n", theme)
        self.assertIn("BorderRadius=18\n", theme)
        self.assertIn("OwnerUsername=alice\n", theme)
        self.assertIn("Background=/var/lib/kamalen-sddm/background.jpg\n", theme)
        self.assertIn("BlurredBackground=/var/lib/kamalen-sddm/background-blurred.jpg\n", theme)
        self.assertIn("Avatar=/var/lib/kamalen-sddm/owner-avatar.png\n", theme)

    def test_invalid_palette_and_settings_use_bounded_fallbacks(self):
        self.palette.write_text('{"accent":"javascript:bad","bg":"#fff"}')
        self.settings.write_text(json.dumps({
            "darkMode": "yes", "blurProfile": "arbitrary", "borderRadius": 999,
            "pfpIndex": "../../etc/passwd",
        }))
        self.mod.sync(self.args(owner_username="bad\nInjected=true"))
        state = json.loads((self.state_dir / "state.json").read_text())
        self.assertEqual(state["palette"], self.mod.DEFAULT_PALETTE)
        self.assertTrue(state["darkMode"])
        self.assertEqual(state["blurProfile"], "balanced")
        self.assertEqual(state["borderRadius"], 16)
        self.assertEqual(state["ownerUsername"], "")
        self.assertIn("OwnerUsername=\n", (self.state_dir / "theme.conf.user").read_text())
        self.assertNotIn("Injected", (self.state_dir / "theme.conf.user").read_text())

    def test_rejects_non_file_wallpaper_and_output_symlink(self):
        bad_wall = self.wallpapers / "bad"
        bad_wall.symlink_to("/dev/null")
        with self.assertRaises(self.mod.SyncError):
            self.mod.sync(self.args(wallpaper=bad_wall))

        outside = self.root / "outside"
        outside.mkdir()
        symlink_state = self.root / "symlink-state"
        symlink_state.symlink_to(outside, target_is_directory=True)
        with self.assertRaises(self.mod.SyncError):
            self.mod.sync(self.args(state_dir=symlink_state))
        self.assertEqual(list(outside.iterdir()), [])

    def test_video_uses_existing_thumbnail_without_calling_ffmpeg(self):
        video = self.wallpapers / "forest.webm"
        video.write_bytes(b"mock-webm")
        (self.wallpapers / "current").unlink()
        (self.wallpapers / "current").symlink_to(video.name)
        thumbs = self.cache / "wallpaper-thumbs"
        thumbs.mkdir()
        Image.new("RGB", (1920, 1080), "#334455").save(thumbs / "forest.webm.thumb.jpg")
        with mock.patch.object(self.mod.subprocess, "run") as run:
            self.mod.sync(self.args())
            run.assert_not_called()
        with Image.open(self.state_dir / "background.jpg") as image:
            self.assertTrue(all(abs(a - b) <= 1 for a, b in zip(image.getpixel((0, 0)), (51, 68, 85))))

    def test_video_falls_back_to_safe_ffmpeg_invocation(self):
        video = self.wallpapers / "movie.mp4"
        video.write_bytes(b"mock-mp4")
        (self.wallpapers / "current").unlink()
        (self.wallpapers / "current").symlink_to(video.name)

        def fake_run(command, **kwargs):
            self.assertIsInstance(command, list)
            self.assertNotIn("shell", kwargs)
            Image.new("RGB", (1280, 720), "#556677").save(command[-1], "PNG")
            return subprocess.CompletedProcess(command, 0, "", "")

        with mock.patch.object(self.mod.subprocess, "run", side_effect=fake_run) as run:
            self.mod.sync(self.args())
            self.assertEqual(run.call_args.args[0][0], "ffmpeg")

    def test_unchanged_fingerprint_is_idempotent_and_atomic(self):
        self.assertTrue(self.mod.sync(self.args()))
        outputs = [self.state_dir / name for name in (
            "state.json", "theme.conf.user", "background.jpg", "background-blurred.jpg", "owner-avatar.png"
        )]
        mtimes = {path: path.stat().st_mtime_ns for path in outputs}
        time.sleep(0.01)
        self.assertFalse(self.mod.sync(self.args()))
        self.assertEqual(mtimes, {path: path.stat().st_mtime_ns for path in outputs})
        self.assertFalse(any(path.name.startswith(".tmp-") for path in self.state_dir.iterdir()))

    def test_lock_contention_returns_without_partial_writes(self):
        self.state_dir.mkdir()
        lock_path = self.state_dir / ".sync.lock"
        lock_path.write_text("")
        with lock_path.open("r+") as lock:
            import fcntl
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.assertFalse(self.mod.sync(self.args()))
        self.assertFalse((self.state_dir / "state.json").exists())


if __name__ == "__main__":
    unittest.main()
