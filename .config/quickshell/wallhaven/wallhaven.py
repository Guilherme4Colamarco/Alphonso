#!/usr/bin/env python3
import sys
import json
import os
import argparse
import urllib.request
import urllib.parse
from PIL import Image

def get_headers(apikey=None):
    headers = {"User-Agent": "KamalenShellWallhavenDownloader/1.0"}
    if apikey:
        headers["X-API-Key"] = apikey
    return headers

def search(args):
    params = {
        "q": args.query or "",
        "categories": args.categories or "111",
        "purity": args.purity or "100",
        "sorting": args.sorting or "relevance",
        "order": "desc",
        "page": str(args.page or 1)
    }
    # Optional filters
    if args.atleast:
        params["atleast"] = args.atleast
    if args.ratios:
        params["ratios"] = args.ratios
    if args.types:
        params["types"] = args.types
    if args.topRange:
        params["topRange"] = args.topRange
    
    url = f"https://wallhaven.cc/api/v1/search?{urllib.parse.urlencode(params)}"
    req = urllib.request.Request(url, headers=get_headers(args.apikey))
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            meta = data.get("meta", {})
            results = []
            for item in data.get("data", []):
                ext = ""
                if item.get("path"):
                    _, ext = os.path.splitext(item.get("path"))
                results.append({
                    "id": item.get("id"),
                    "url": item.get("path"),
                    "thumbnail": item.get("thumbs", {}).get("large"),
                    "resolution": item.get("resolution"),
                    "file_type": item.get("file_type"),
                    "file_size": item.get("file_size"),
                    "ext": ext,
                    "tags": [t.get("name") for t in (item.get("tags") or [])[:4]],
                    "colors": (item.get("colors") or [])[:3],
                    "views": item.get("views", 0),
                    "favorites": item.get("favorites", 0),
                    "purity": item.get("purity", "sfw"),
                    "category": item.get("category", "general")
                })
            # Return results with meta info
            output = {
                "results": results,
                "total": meta.get("total", 0),
                "last_page": meta.get("last_page", 1),
                "current_page": meta.get("current_page", 1)
            }
            print(json.dumps(output))
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

def download(args):
    out_dir = os.path.expanduser(args.out_dir)
    os.makedirs(out_dir, exist_ok=True)
    filename = f"wallhaven-{args.id}{args.ext}"
    dest_path = os.path.join(out_dir, filename)
    
    req = urllib.request.Request(args.url, headers=get_headers())
    try:
        with urllib.request.urlopen(req) as resp:
            total_size = int(resp.info().get('Content-Length', 0))
            downloaded = 0
            block_size = 1024 * 64
            
            with open(dest_path, "wb") as f:
                while True:
                    buffer = resp.read(block_size)
                    if not buffer:
                        break
                    f.write(buffer)
                    downloaded += len(buffer)
                    if total_size:
                        percent = int((downloaded / total_size) * 100)
                        print(f"PROGRESS:{percent}")
                        sys.stdout.flush()
                        
            # Generate thumbnail immediately
            thumb_dir = os.path.expanduser("~/.cache/wallpaper-thumbs")
            os.makedirs(thumb_dir, exist_ok=True)
            thumb_path = os.path.join(thumb_dir, f"{filename}.thumb.jpg")
            try:
                img = Image.open(dest_path)
                img.thumbnail((600, 600))
                img.convert("RGB").save(thumb_path, "JPEG", quality=85)
            except Exception as thumb_err:
                print(f"WARN: Failed to create thumbnail: {thumb_err}", file=sys.stderr)
                
            print(f"SUCCESS:{dest_path}")
    except Exception as e:
        print(f"ERROR:{str(e)}")
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description="Wallhaven API Helper for Kamalen Shell")
    subparsers = parser.add_subparsers(dest="command", help="Sub-commands")
    
    # Search command
    search_parser = subparsers.add_parser("search", help="Search Wallhaven")
    search_parser.add_argument("--query", type=str, default="", help="Search query")
    search_parser.add_argument("--categories", type=str, default="111", help="Categories bitmask (General/Anime/People)")
    search_parser.add_argument("--purity", type=str, default="100", help="Purity bitmask (SFW/Sketchy/NSFW)")
    search_parser.add_argument("--sorting", type=str, default="relevance", help="Sorting method")
    search_parser.add_argument("--atleast", type=str, default=None, help="Minimum resolution (e.g. 1920x1080)")
    search_parser.add_argument("--ratios", type=str, default=None, help="Aspect ratios (e.g. 16x9,16x10)")
    search_parser.add_argument("--types", type=str, default=None, help="File types (png,jpg)")
    search_parser.add_argument("--topRange", type=str, default=None, help="Top range for toplist (1d,3d,1w,1M,3M,6M,1y)")
    search_parser.add_argument("--page", type=int, default=1, help="Page number")
    search_parser.add_argument("--apikey", type=str, default=None, help="Wallhaven API key")
    
    # Download command
    download_parser = subparsers.add_parser("download", help="Download a wallpaper")
    download_parser.add_argument("--url", type=str, required=True, help="Full resolution direct wallpaper URL")
    download_parser.add_argument("--id", type=str, required=True, help="Wallpaper ID")
    download_parser.add_argument("--ext", type=str, required=True, help="File extension (e.g. .jpg, .png)")
    download_parser.add_argument("--out-dir", type=str, required=True, help="Output wallpapers directory")
    
    args = parser.parse_args()
    
    if args.command == "search":
        search(args)
    elif args.command == "download":
        download(args)
    else:
        parser.print_help()
        sys.exit(1)

if __name__ == "__main__":
    main()
