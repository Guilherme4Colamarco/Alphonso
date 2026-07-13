#!/usr/bin/env python3
"""Export a small, safe snapshot of Kamalen's visual state for SDDM."""

from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
import re
import stat
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageFilter, ImageOps, UnidentifiedImageError


DEFAULT_PALETTE = {
    "bg": "#11111b",
    "fg": "#cdd6f4",
    "accent": "#89b4fa",
    "green": "#a6e3a1",
    "red": "#f38ba8",
    "yellow": "#f9e2af",
    "surface": "#1e1e2e",
    "dim": "#6c7086",
}
PALETTE_KEYS = tuple(DEFAULT_PALETTE)
VIDEO_EXTENSIONS = {".mp4", ".webm", ".mkv", ".mov", ".avi"}
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".gif"}
BLUR_RADII = {"none": 0, "subtle": 14, "balanced": 24, "frosted": 32}
MAX_WIDTH, MAX_HEIGHT = 3840, 2160
MAX_INPUT_BYTES = 2 * 1024 * 1024 * 1024
Image.MAX_IMAGE_PIXELS = 100_000_000


class SyncError(RuntimeError):
    pass


@dataclass(frozen=True)
class SyncConfig:
    wallpaper: Path
    palette: Path
    settings: Path
    pfp_dir: Path
    thumb_dir: Path
    state_dir: Path
    owner_username: str = ""


def _regular_file(path: Path, label: str) -> Path:
    try:
        resolved = path.expanduser().resolve(strict=True)
        mode = resolved.stat().st_mode
    except (OSError, RuntimeError) as exc:
        raise SyncError(f"{label} is unavailable: {path}") from exc
    if not stat.S_ISREG(mode) or resolved.stat().st_size > MAX_INPUT_BYTES:
        raise SyncError(f"{label} must be a bounded regular file")
    return resolved


def _safe_state_dir(path: Path) -> Path:
    path = path.expanduser()
    if path.is_symlink():
        raise SyncError("state directory must not be a symlink")
    try:
        path.mkdir(parents=True, exist_ok=True, mode=0o755)
        resolved = path.resolve(strict=True)
    except OSError as exc:
        raise SyncError(f"cannot create state directory: {path}") from exc
    if not resolved.is_dir():
        raise SyncError("state path is not a directory")
    for name in ("state.json", "theme.conf.user", "background.jpg", "background-blurred.jpg", "owner-avatar.png"):
        if (resolved / name).is_symlink():
            raise SyncError(f"refusing symlink output: {name}")
    return resolved


def _read_json(path: Path) -> dict[str, Any]:
    try:
        resolved = _regular_file(path, "JSON input")
        value = json.loads(resolved.read_text(encoding="utf-8"))
        return value if isinstance(value, dict) else {}
    except (SyncError, OSError, UnicodeError, json.JSONDecodeError):
        return {}


def _valid_color(value: Any) -> bool:
    if not isinstance(value, str) or len(value) != 7 or value[0] != "#":
        return False
    try:
        int(value[1:], 16)
        return True
    except ValueError:
        return False


def load_palette(path: Path) -> dict[str, str]:
    raw = _read_json(path)
    if not all(_valid_color(raw.get(key)) for key in PALETTE_KEYS):
        return dict(DEFAULT_PALETTE)
    return {key: raw[key].lower() for key in PALETTE_KEYS}


def load_settings(path: Path) -> dict[str, Any]:
    raw = _read_json(path)
    dark = raw.get("darkMode")
    profile = raw.get("blurProfile")
    radius = raw.get("borderRadius")
    pfp_index = raw.get("pfpIndex")
    return {
        "darkMode": dark if isinstance(dark, bool) else True,
        "blurProfile": profile if profile in BLUR_RADII else "balanced",
        "borderRadius": radius if isinstance(radius, (int, float)) and 0 <= radius <= 64 else 16,
        "pfpIndex": pfp_index if isinstance(pfp_index, int) and not isinstance(pfp_index, bool) else 0,
    }


def _selected_avatar(directory: Path, index: int) -> Path | None:
    try:
        root = directory.expanduser().resolve(strict=True)
    except (OSError, RuntimeError):
        return None
    if not root.is_dir():
        return None
    candidates = []
    for child in sorted(root.iterdir(), key=lambda item: item.name.casefold()):
        if child.suffix.lower() not in IMAGE_EXTENSIONS or child.is_symlink():
            continue
        try:
            candidates.append(_regular_file(child, "avatar"))
        except SyncError:
            continue
    return candidates[index] if 0 <= index < len(candidates) else None


def _hash_file(digest: Any, path: Path | None) -> None:
    if path is None:
        digest.update(b"missing")
        return
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)


def _safe_username(value: str) -> str:
    return value if re.fullmatch(r"[A-Za-z0-9_.-]{1,64}", value or "") else ""


def _fingerprint(
    wallpaper: Path,
    palette: dict[str, str],
    settings: dict[str, Any],
    avatar: Path | None,
    owner_username: str,
) -> str:
    digest = hashlib.sha256()
    _hash_file(digest, wallpaper)
    _hash_file(digest, avatar)
    digest.update(json.dumps(palette, sort_keys=True, separators=(",", ":")).encode())
    digest.update(json.dumps(settings, sort_keys=True, separators=(",", ":")).encode())
    digest.update(owner_username.encode())
    return digest.hexdigest()


def _video_frame(wallpaper: Path, thumb_dir: Path, work_dir: Path) -> Path:
    thumb = thumb_dir.expanduser() / f"{wallpaper.name}.thumb.jpg"
    try:
        return _regular_file(thumb, "video thumbnail")
    except SyncError:
        pass
    frame = work_dir / "video-frame.png"
    try:
        subprocess.run(
            ["ffmpeg", "-v", "error", "-nostdin", "-ss", "1", "-i", str(wallpaper),
             "-frames:v", "1", "-y", str(frame)],
            check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=30,
        )
    except (OSError, subprocess.SubprocessError) as exc:
        raise SyncError("could not extract a frame from the video wallpaper") from exc
    return _regular_file(frame, "extracted video frame")


def _open_source(wallpaper: Path, thumb_dir: Path, work_dir: Path) -> Image.Image:
    suffix = wallpaper.suffix.lower()
    if suffix in VIDEO_EXTENSIONS:
        source = _video_frame(wallpaper, thumb_dir, work_dir)
    elif suffix in IMAGE_EXTENSIONS:
        source = wallpaper
    else:
        raise SyncError(f"unsupported wallpaper format: {suffix or 'unknown'}")
    try:
        with Image.open(source) as opened:
            opened.seek(0)
            image = ImageOps.exif_transpose(opened).convert("RGB")
    except (OSError, ValueError, UnidentifiedImageError, Image.DecompressionBombError) as exc:
        raise SyncError("wallpaper image could not be decoded safely") from exc
    image.thumbnail((MAX_WIDTH, MAX_HEIGHT), Image.Resampling.LANCZOS)
    return image


def _atomic_image(image: Image.Image, destination: Path, image_format: str, **save_options: Any) -> None:
    fd, temporary = tempfile.mkstemp(prefix=".tmp-", dir=destination.parent)
    os.close(fd)
    temporary_path = Path(temporary)
    try:
        image.save(temporary_path, format=image_format, **save_options)
        os.chmod(temporary_path, 0o644)
        os.replace(temporary_path, destination)
    finally:
        temporary_path.unlink(missing_ok=True)


def _atomic_json(value: dict[str, Any], destination: Path) -> None:
    fd, temporary = tempfile.mkstemp(prefix=".tmp-", dir=destination.parent, text=True)
    temporary_path = Path(temporary)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(value, handle, sort_keys=True, separators=(",", ":"))
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temporary_path, 0o644)
        os.replace(temporary_path, destination)
    finally:
        temporary_path.unlink(missing_ok=True)


def _atomic_text(value: str, destination: Path) -> None:
    fd, temporary = tempfile.mkstemp(prefix=".tmp-", dir=destination.parent, text=True)
    temporary_path = Path(temporary)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(value)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temporary_path, 0o644)
        os.replace(temporary_path, destination)
    finally:
        temporary_path.unlink(missing_ok=True)


def _circular_avatar(image: Image.Image) -> Image.Image:
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).ellipse((0, 0, image.width - 1, image.height - 1), fill=255)
    result = image.convert("RGBA")
    result.putalpha(mask)
    return result


def _theme_config(palette: dict[str, str], settings: dict[str, Any], owner_username: str) -> str:
    lines = ["[General]"]
    lines.extend(f"{key.title()}={palette[key]}" for key in PALETTE_KEYS)
    lines.extend((
        f"DarkMode={'true' if settings['darkMode'] else 'false'}",
        f"BlurProfile={settings['blurProfile']}",
        f"BorderRadius={settings['borderRadius']}",
        f"OwnerUsername={owner_username}",
        "Background=/var/lib/kamalen-sddm/background.jpg",
        "BlurredBackground=/var/lib/kamalen-sddm/background-blurred.jpg",
        "Avatar=/var/lib/kamalen-sddm/owner-avatar.png",
    ))
    return "\n".join(lines) + "\n"


def sync(config: SyncConfig) -> bool:
    # Validate the primary untrusted input before creating any output or lock.
    wallpaper = _regular_file(Path(config.wallpaper), "wallpaper")
    state_dir = _safe_state_dir(Path(config.state_dir))
    lock_path = state_dir / ".sync.lock"
    with lock_path.open("a+") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return False

        palette = load_palette(Path(config.palette))
        settings = load_settings(Path(config.settings))
        avatar = _selected_avatar(Path(config.pfp_dir), settings["pfpIndex"])
        owner_username = _safe_username(config.owner_username)
        fingerprint = _fingerprint(wallpaper, palette, settings, avatar, owner_username)
        state_path = state_dir / "state.json"
        current = _read_json(state_path)
        required = ("theme.conf.user", "background.jpg", "background-blurred.jpg", "owner-avatar.png")
        if current.get("fingerprint") == fingerprint and all((state_dir / name).is_file() for name in required):
            return False

        with tempfile.TemporaryDirectory(prefix="kamalen-sddm-") as work:
            image = _open_source(wallpaper, Path(config.thumb_dir), Path(work))
            blurred = image.filter(ImageFilter.GaussianBlur(BLUR_RADII[settings["blurProfile"]]))
            if avatar is not None:
                try:
                    with Image.open(avatar) as opened:
                        avatar_image = ImageOps.fit(
                            ImageOps.exif_transpose(opened).convert("RGBA"), (256, 256),
                            method=Image.Resampling.LANCZOS,
                        )
                except (OSError, ValueError, UnidentifiedImageError):
                    avatar_image = Image.new("RGBA", (256, 256), palette["surface"])
            else:
                avatar_image = Image.new("RGBA", (256, 256), palette["surface"])

            _atomic_image(image, state_dir / "background.jpg", "JPEG", quality=90, optimize=True)
            _atomic_image(blurred, state_dir / "background-blurred.jpg", "JPEG", quality=86, optimize=True)
            _atomic_image(_circular_avatar(avatar_image), state_dir / "owner-avatar.png", "PNG", optimize=True)
            _atomic_text(_theme_config(palette, settings, owner_username), state_dir / "theme.conf.user")
            exported = {
                "version": 1,
                "fingerprint": fingerprint,
                "palette": palette,
                "darkMode": settings["darkMode"],
                "blurProfile": settings["blurProfile"],
                "borderRadius": settings["borderRadius"],
                "ownerUsername": owner_username,
                "background": "background.jpg",
                "backgroundBlurred": "background-blurred.jpg",
                "avatar": "owner-avatar.png",
            }
            _atomic_json(exported, state_path)
        return True


def parse_args(argv: list[str] | None = None) -> SyncConfig:
    home = Path.home()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--wallpaper", type=Path, default=home / "wallpapers/current")
    parser.add_argument("--palette", type=Path, default=home / ".cache/qs/current-palette.json")
    parser.add_argument("--settings", type=Path, default=home / ".config/quickshell/state/settings.json")
    parser.add_argument("--pfp-dir", type=Path, default=home / ".config/quickshell/assets/pfps")
    parser.add_argument("--thumb-dir", type=Path, default=home / ".cache/wallpaper-thumbs")
    parser.add_argument("--state-dir", type=Path, default=Path("/var/lib/kamalen-sddm"))
    parser.add_argument("--owner-username", default=os.environ.get("SUDO_USER") or os.environ.get("USER", ""))
    args = parser.parse_args(argv)
    return SyncConfig(
        args.wallpaper, args.palette, args.settings, args.pfp_dir, args.thumb_dir,
        args.state_dir, args.owner_username,
    )


def main(argv: list[str] | None = None) -> int:
    try:
        changed = sync(parse_args(argv))
        print("updated" if changed else "unchanged")
        return 0
    except SyncError as exc:
        print(f"kamalen-sddm-sync: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
