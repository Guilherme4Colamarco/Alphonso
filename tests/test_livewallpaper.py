#!/usr/bin/env python3
"""Tests for the DesktopHut live-wallpaper provider."""

from __future__ import annotations

import importlib.util
import io
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest import mock

REPO_ROOT = Path(__file__).resolve().parents[1]
HELPER_PATH = REPO_ROOT / ".config/quickshell/livewallpaper/livewallpaper.py"


def load_helper():
    spec = importlib.util.spec_from_file_location("livewallpaper", HELPER_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(module)
    return module


SEARCH_HTML = """
<div class="home-grid">
 <a href="/divine-dogs" class="wallpaper-card"><img src="https://www.desktophut.com/images/dogs.webp">
  <span class="badge-res">3840x2160</span><h3 class="card-title">Divine Dogs Wallpaper</h3><span class="dev-name">Guest</span></a>
 <a href="/watch-dogs-2" class="wallpaper-card"><img src="https://www.desktophut.com/images/watch.jpg">
  <span class="badge-res">1920x1080</span><h3 class="card-title">Watch Dogs 2 Live Wallpaper</h3><span class="dev-name">Ada</span></a>
</div><a class="dh-pager-btn" href="https://www.desktophut.com/search/watch%20dogs?page=3" rel="next">Next</a>
"""

DETAIL_HTML = """
<script type="application/ld+json">
{"@context":"https://schema.org","@graph":[{"@type":"VideoObject","name":"Watch Dogs 2 Live Wallpaper",
"thumbnailUrl":["https://www.desktophut.com/images/watch.jpg"],
"contentUrl":"https://www.desktophut.com/files/watch-dogs-2.mp4",
"creator":{"@type":"Person","name":"Ada"}}]}
</script>
"""


class DesktopHutProviderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.helper = load_helper()

    def test_search_cards_are_parsed_and_landscape_only(self):
        cards, has_more = self.helper.parse_search_page(SEARCH_HTML)
        self.assertEqual(2, len(cards))
        self.assertEqual("Watch Dogs 2 Live Wallpaper", cards[1]["title"])
        self.assertEqual((1920, 1080), (cards[1]["width"], cards[1]["height"]))
        self.assertTrue(has_more)

    def test_search_filters_titles_using_all_query_terms(self):
        cards, _ = self.helper.parse_search_page(SEARCH_HTML)
        filtered = self.helper.filter_relevant(cards, "watch dogs")
        self.assertEqual(["Watch Dogs 2 Live Wallpaper"], [item["title"] for item in filtered])

    def test_detail_json_ld_produces_stable_desktophut_contract(self):
        card = {"slug": "watch-dogs-2", "title": "Watch Dogs 2 Live Wallpaper", "author": "Ada",
                "thumbnail": "", "width": 1920, "height": 1080}
        item = self.helper.normalize_detail(card, DETAIL_HTML)
        self.assertTrue(item["id"].startswith("desktophut-"))
        self.assertEqual("desktophut", item["provider"])
        self.assertEqual("video/mp4", item["mime"])
        self.assertEqual(".mp4", item["ext"])
        self.assertEqual("DesktopHut", item["license"])
        self.assertEqual("Ada via DesktopHut", item["attribution"])
        self.assertEqual("https://www.desktophut.com/watch-dogs-2", item["source_url"])

    def test_detail_rejects_untrusted_or_non_video_content_urls(self):
        card = {"slug": "x", "title": "X", "author": "Guest", "thumbnail": "", "width": 1920, "height": 1080}
        for url in ("https://example.com/files/x.mp4", "http://www.desktophut.com/files/x.mp4", "https://www.desktophut.com/files/x.exe"):
            html = DETAIL_HTML.replace("https://www.desktophut.com/files/watch-dogs-2.mp4", url)
            with self.assertRaises(ValueError):
                self.helper.normalize_detail(card, html)

    def test_search_scans_later_pages_before_returning_no_results(self):
        args = SimpleNamespace(command="search", query="watch dogs", page=1, per_page=24)
        first = SEARCH_HTML.replace("Watch Dogs 2 Live Wallpaper", "Unrelated Cat").replace("/watch-dogs-2", "/cat")
        second = SEARCH_HTML
        with mock.patch.object(self.helper, "fetch_text", side_effect=[first, second, DETAIL_HTML]) as fetch:
            result = self.helper.fetch_listing(args)
        self.assertEqual(3, fetch.call_count)
        self.assertEqual(1, len(result["results"]))
        self.assertEqual("Watch Dogs 2 Live Wallpaper", result["results"][0]["title"])

    def test_download_filename_and_url_are_restricted(self):
        item_id = "desktophut-0123456789abcdef"
        self.assertEqual(f"{item_id}-1920x1080.mp4", self.helper.download_filename(item_id, 1920, 1080, ".mp4"))
        self.helper.validate_download_url("https://www.desktophut.com/files/a.mp4")
        with self.assertRaises(ValueError):
            self.helper.validate_download_url("https://desktophut.com.evil.test/files/a.mp4")

    def test_download_reports_progress_reuses_and_cleans_partial(self):
        args = SimpleNamespace(url="https://www.desktophut.com/files/a.mp4", id="desktophut-0123456789abcdef",
                               width=1920, height=1080, ext=".mp4")
        response = mock.MagicMock(); response.headers = {"Content-Length": "6"}; response.read.side_effect = [b"abc", b"def", b""]
        response.__enter__.return_value = response
        with tempfile.TemporaryDirectory() as directory:
            args.out_dir = directory
            with mock.patch.object(self.helper.urllib.request, "urlopen", return_value=response), \
                 mock.patch.object(self.helper.subprocess, "run"), mock.patch("sys.stdout", new_callable=io.StringIO) as stdout:
                destination = self.helper.download_video(args)
            self.assertEqual(b"abcdef", destination.read_bytes())
            self.assertIn("PROGRESS:100:6:6", stdout.getvalue())
            with mock.patch.object(self.helper.urllib.request, "urlopen") as request:
                self.helper.download_video(args)
            request.assert_not_called()


if __name__ == "__main__":
    unittest.main()
