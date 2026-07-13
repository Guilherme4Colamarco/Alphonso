#!/usr/bin/env python3
"""DesktopHut live-wallpaper search and download helper for Kamalen Shell."""

from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
from html.parser import HTMLParser
import json
import os
import random
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any, Mapping, Sequence

SITE_ROOT = "https://www.desktophut.com"
USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64) KamalenShellLiveWallpaper/3.0"
SAFE_ID = re.compile(r"^desktophut-[0-9a-f]{16}$")
RESOLUTION = re.compile(r"^(\d{2,5})x(\d{2,5})$")
ALLOWED_EXTENSIONS = {".mp4": "video/mp4", ".webm": "video/webm"}


def _classes(attrs: Mapping[str, str]) -> set[str]:
    return set(attrs.get("class", "").split())


class SearchPageParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.cards: list[dict[str, Any]] = []
        self.card: dict[str, Any] | None = None
        self.capture = ""
        self.has_more = False

    def handle_starttag(self, tag: str, raw_attrs: list[tuple[str, str | None]]) -> None:
        attrs = {key: value or "" for key, value in raw_attrs}
        classes = _classes(attrs)
        if tag == "a" and "wallpaper-card" in classes:
            slug = attrs.get("href", "").strip("/")
            if slug and "/" not in slug and not slug.startswith(("http:", "https:")):
                self.card = {"slug": slug, "title": "", "author": "DesktopHut", "thumbnail": "", "width": 0, "height": 0}
        elif tag == "a" and attrs.get("rel") == "next":
            self.has_more = True
        elif self.card is not None and tag == "img" and not self.card["thumbnail"]:
            self.card["thumbnail"] = attrs.get("src", "")
        elif self.card is not None and classes & {"badge-res", "card-title", "dev-name"}:
            self.capture = next(iter(classes & {"badge-res", "card-title", "dev-name"}))

    def handle_data(self, data: str) -> None:
        if self.card is None or not self.capture:
            return
        value = " ".join(data.split())
        if not value:
            return
        if self.capture == "badge-res":
            match = RESOLUTION.fullmatch(value)
            if match:
                self.card["width"], self.card["height"] = map(int, match.groups())
        elif self.capture == "card-title":
            self.card["title"] += value
        elif self.capture == "dev-name":
            self.card["author"] = value

    def handle_endtag(self, tag: str) -> None:
        if tag in ("span", "h3"):
            self.capture = ""
        if tag == "a" and self.card is not None:
            if self.card["title"] and self.card["width"] >= self.card["height"] > 0:
                self.cards.append(self.card)
            self.card = None
            self.capture = ""


class JsonLdParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.capture = False
        self.blocks: list[str] = []
        self.current: list[str] = []

    def handle_starttag(self, tag: str, raw_attrs: list[tuple[str, str | None]]) -> None:
        attrs = {key: value or "" for key, value in raw_attrs}
        if tag == "script" and attrs.get("type", "").lower() == "application/ld+json":
            self.capture = True
            self.current = []

    def handle_data(self, data: str) -> None:
        if self.capture:
            self.current.append(data)

    def handle_endtag(self, tag: str) -> None:
        if tag == "script" and self.capture:
            self.blocks.append("".join(self.current))
            self.capture = False


def fetch_text(url: str) -> str:
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != "https" or parsed.hostname not in ("www.desktophut.com", "desktophut.com"):
        raise ValueError("untrusted DesktopHut page URL")
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=20) as response:
        return response.read().decode("utf-8", errors="replace")


def parse_search_page(document: str) -> tuple[list[dict[str, Any]], bool]:
    parser = SearchPageParser()
    parser.feed(document)
    parser.close()
    return parser.cards, parser.has_more


def _terms(value: str) -> list[str]:
    return re.findall(r"[a-z0-9]+", value.casefold())


def filter_relevant(cards: Sequence[Mapping[str, Any]], query: str) -> list[dict[str, Any]]:
    wanted = _terms(query)
    if not wanted:
        return [dict(card) for card in cards]
    return [dict(card) for card in cards if all(term in _terms(str(card.get("title", ""))) for term in wanted)]


def validate_download_url(url: str) -> str:
    parsed = urllib.parse.urlparse(url)
    extension = Path(parsed.path).suffix.lower()
    if parsed.scheme != "https" or parsed.hostname != "www.desktophut.com" or not parsed.path.startswith("/files/"):
        raise ValueError("untrusted DesktopHut download URL")
    if extension not in ALLOWED_EXTENSIONS:
        raise ValueError("unsupported live-wallpaper format")
    return extension


def _video_object(document: str) -> Mapping[str, Any]:
    parser = JsonLdParser()
    parser.feed(document)
    parser.close()
    for block in parser.blocks:
        try:
            data = json.loads(block)
        except json.JSONDecodeError:
            continue
        nodes = data.get("@graph", []) if isinstance(data, Mapping) else []
        if isinstance(data, Mapping) and data.get("@type") == "VideoObject":
            nodes = [data]
        for node in nodes:
            if isinstance(node, Mapping) and node.get("@type") == "VideoObject":
                return node
    raise ValueError("DesktopHut video metadata was not found")


def normalize_detail(card: Mapping[str, Any], document: str) -> dict[str, Any]:
    video = _video_object(document)
    download_url = str(video.get("contentUrl") or "")
    extension = validate_download_url(download_url)
    slug = str(card["slug"])
    source_url = f"{SITE_ROOT}/{urllib.parse.quote(slug, safe='-')}"
    creator = video.get("creator") or {}
    author = str(creator.get("name") or card.get("author") or "DesktopHut") if isinstance(creator, Mapping) else str(card.get("author") or "DesktopHut")
    thumbnails = video.get("thumbnailUrl") or []
    thumbnail = str(thumbnails[0] if isinstance(thumbnails, list) and thumbnails else card.get("thumbnail") or "")
    width, height = int(card["width"]), int(card["height"])
    item_id = "desktophut-" + hashlib.sha256(slug.encode("utf-8")).hexdigest()[:16]
    return {
        "id": item_id, "provider": "desktophut", "title": str(video.get("name") or card["title"]),
        "author": author, "author_url": "", "license": "DesktopHut", "license_url": source_url,
        "attribution": f"{author} via DesktopHut", "source_url": source_url,
        "thumbnail": thumbnail, "download_url": download_url, "resolution": f"{width}x{height}",
        "width": width, "height": height, "fps": 0, "duration": 0,
        "mime": ALLOWED_EXTENSIONS[extension], "ext": extension, "is_video": True,
    }


def _hydrate(cards: Sequence[Mapping[str, Any]]) -> list[dict[str, Any]]:
    def hydrate(card: Mapping[str, Any]) -> dict[str, Any] | None:
        try:
            document = fetch_text(f"{SITE_ROOT}/{urllib.parse.quote(str(card['slug']), safe='-')}")
            return normalize_detail(card, document)
        except (OSError, TypeError, ValueError):
            return None

    with ThreadPoolExecutor(max_workers=min(6, max(1, len(cards)))) as executor:
        hydrated = executor.map(hydrate, cards)
        return [item for item in hydrated if item is not None]


def fetch_listing(args: argparse.Namespace) -> dict[str, Any]:
    page = max(1, int(args.page))
    if args.command == "search":
        encoded = urllib.parse.quote(args.query.strip(), safe="")
        relevant: list[dict[str, Any]] = []
        has_more = False
        scans = 0
        while scans < 4 and len(relevant) < args.per_page:
            document = fetch_text(f"{SITE_ROOT}/search/{encoded}?page={page}")
            cards, has_more = parse_search_page(document)
            relevant.extend(filter_relevant(cards, args.query))
            scans += 1
            if relevant or not has_more:
                break
            page += 1
        selected = relevant[: args.per_page]
    else:
        document = fetch_text(SITE_ROOT + ("/" if page == 1 else f"/?page={page}"))
        selected, has_more = parse_search_page(document)
        if args.command == "random":
            random.SystemRandom().shuffle(selected)
            selected = selected[: args.per_page]
            has_more = False
        else:
            selected = selected[: args.per_page]
    results = _hydrate(selected)
    return {"results": results, "total": len(results), "next_page": page + 1 if has_more else None, "has_more": has_more, "error": ""}


def download_filename(item_id: str, width: int, height: int, extension: str) -> str:
    if not SAFE_ID.fullmatch(item_id) or extension not in ALLOWED_EXTENSIONS:
        raise ValueError("invalid DesktopHut item")
    width, height = int(width), int(height)
    if not 1 <= width <= 16384 or not 1 <= height <= 16384:
        raise ValueError("invalid video dimensions")
    return f"{item_id}-{width}x{height}{extension}"


def download_video(args: argparse.Namespace) -> Path:
    extension = validate_download_url(args.url)
    if args.ext != extension:
        raise ValueError("download extension mismatch")
    filename = download_filename(args.id, args.width, args.height, extension)
    output_dir = Path(args.out_dir).expanduser().resolve(); output_dir.mkdir(parents=True, exist_ok=True)
    destination = output_dir / filename; partial = output_dir / (filename + ".part")
    if destination.exists() and destination.stat().st_size > 0:
        print(f"SUCCESS:{destination}", flush=True); return destination
    request = urllib.request.Request(args.url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=30) as response, partial.open("wb") as handle:
            total = int(response.headers.get("Content-Length") or 0); downloaded = 0
            while True:
                block = response.read(64 * 1024)
                if not block: break
                handle.write(block); downloaded += len(block)
                print(f"PROGRESS:{int(downloaded * 100 / total) if total else 0}:{downloaded}:{total}", flush=True)
        os.replace(partial, destination)
    except Exception:
        partial.unlink(missing_ok=True); raise
    thumbnail_dir = Path.home() / ".cache/wallpaper-thumbs"; thumbnail_dir.mkdir(parents=True, exist_ok=True)
    subprocess.run(["ffmpeg", "-y", "-i", str(destination), "-ss", "00:00:01", "-vframes", "1", "-vf", "scale=600:-1", str(thumbnail_dir / f"{filename}.thumb.jpg")], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print(f"SUCCESS:{destination}", flush=True); return destination


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="DesktopHut live-wallpaper helper")
    commands = parser.add_subparsers(dest="command", required=True)
    for name in ("search", "featured", "random"):
        command = commands.add_parser(name)
        if name == "search": command.add_argument("--query", required=True)
        command.add_argument("--page", type=int, default=1); command.add_argument("--per-page", type=int, default=24)
    download = commands.add_parser("download")
    for name in ("url", "id", "ext", "out-dir"): download.add_argument(f"--{name}", required=True)
    download.add_argument("--width", type=int, required=True); download.add_argument("--height", type=int, required=True)
    return parser


def output_error(message: str) -> None:
    print(json.dumps({"results": [], "error": message}), flush=True)


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.command == "download":
        try: download_video(args); return 0
        except Exception as error: print(f"ERROR:{error}", flush=True); return 1
    try: print(json.dumps(fetch_listing(args), ensure_ascii=False), flush=True); return 0
    except urllib.error.HTTPError as error: output_error(f"DesktopHut request failed ({error.code})"); return 1
    except (OSError, ValueError): output_error("Could not reach DesktopHut"); return 1


if __name__ == "__main__":
    raise SystemExit(main())
