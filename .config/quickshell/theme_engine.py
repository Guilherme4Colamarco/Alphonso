#!/usr/bin/env python3
"""Resolve wallpaper and preset colors into Kamalen's effective palette."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import tempfile


def _palette(bg, surface, fg, dim, accent, red, green, yellow, dark):
    syntax = {
        "syntax_keyword": accent, "syntax_string": yellow, "syntax_func": green,
        "syntax_type": accent, "syntax_const": red, "syntax_comment": dim,
        "syntax_param": fg, "syntax_operator": accent,
    }
    return {
        "bg": bg, "surface": surface, "fg": fg, "dim": dim, "accent": accent,
        "red": red, "green": green, "yellow": yellow, **syntax,
        "dark": dark, "tone_l": 0.22 if dark else 0.82,
    }


PRESETS = {
    "catppuccin": {
        "dark": _palette("#1e1e2e", "#313244", "#cdd6f4", "#6c7086", "#89b4fa", "#f38ba8", "#a6e3a1", "#f9e2af", True),
        "light": _palette("#eff1f5", "#e6e9ef", "#4c4f69", "#8c8fa1", "#1e66f5", "#d20f39", "#40a02b", "#df8e1d", False),
    },
    "gruvbox": {
        "dark": _palette("#282828", "#3c3836", "#ebdbb2", "#928374", "#83a598", "#fb4934", "#b8bb26", "#fabd2f", True),
        "light": _palette("#fbf1c7", "#ebdbb2", "#3c3836", "#928374", "#076678", "#9d0006", "#79740e", "#b57614", False),
    },
    "nord": {
        "dark": _palette("#2e3440", "#3b4252", "#eceff4", "#7b88a1", "#88c0d0", "#bf616a", "#a3be8c", "#ebcb8b", True),
        "light": _palette("#eceff4", "#e5e9f0", "#2e3440", "#7b88a1", "#5e81ac", "#bf616a", "#4c7a5b", "#b48e3d", False),
    },
    "solarized": {
        "dark": _palette("#002b36", "#073642", "#eee8d5", "#657b83", "#268bd2", "#dc322f", "#859900", "#b58900", True),
        "light": _palette("#fdf6e3", "#eee8d5", "#073642", "#839496", "#268bd2", "#dc322f", "#859900", "#b58900", False),
    },
}

ACCENT_ROLES = (
    "accent", "red", "green", "yellow", "syntax_keyword", "syntax_string",
    "syntax_func", "syntax_type", "syntax_const", "syntax_comment",
    "syntax_param", "syntax_operator",
)


def resolve_palette(wallpaper: dict, mode: str, preset: str, dark: bool) -> dict:
    """Return a validated effective palette; unknown modes fall back to auto."""
    if mode not in {"auto", "adaptive-preset", "fixed-preset"}:
        mode = "auto"
    if mode == "auto":
        return dict(wallpaper)

    family = PRESETS.get(preset, PRESETS["catppuccin"])
    selected = dict(family["dark" if dark else "light"])
    if mode == "fixed-preset":
        return selected

    for role in ACCENT_ROLES:
        if role in wallpaper:
            selected[role] = wallpaper[role]
    selected["dark"] = bool(dark)
    selected["tone_l"] = 0.22 if dark else 0.82
    return selected


def _atomic_write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=f".{path.stem}.", dir=path.parent, text=True)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def publish_palette(path: Path, palette: dict) -> None:
    _atomic_write(path, json.dumps(palette, separators=(",", ":")))


def update_starship(path: Path, palette: dict) -> None:
    if not path.exists():
        return
    content = path.read_text(encoding="utf-8")
    values = {
        "color_bg": palette["bg"], "color1": palette["accent"],
        "color2": palette["surface"], "color3": palette["dim"],
        "color4": palette["fg"], "text_light": palette["fg"],
        "text_dark": palette["bg"],
    }
    for key, value in values.items():
        content = re.sub(rf"^{key} = .*", f"{key} = '{value}'", content, flags=re.MULTILINE)
    _atomic_write(path, content)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--wallpaper-json", required=True)
    parser.add_argument("--mode", default="auto")
    parser.add_argument("--preset", default="catppuccin")
    parser.add_argument("--dark", type=int, choices=(0, 1), required=True)
    parser.add_argument("--publish", type=Path)
    parser.add_argument("--starship", type=Path)
    args = parser.parse_args()
    palette = resolve_palette(json.loads(args.wallpaper_json), args.mode, args.preset, bool(args.dark))
    if args.publish:
        publish_palette(args.publish, palette)
    if args.starship:
        update_starship(args.starship, palette)
    print(json.dumps(palette))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
