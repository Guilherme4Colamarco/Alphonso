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
        "purity": "100", # Restrict to SFW
        "sorting": args.sorting or "relevance",
        "order": "desc",
        "page": str(args.page or 1)
    }
    url = f"https://wallhaven.cc/api/v1/search?{urllib.parse.urlencode(params)}"
    req = urllib.request.Request(url, headers=get_headers(args.apikey))
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            results = []
            for item in data.get("data", []):
                ext = ""
                if item.get("path"):
                    _, ext = os.path.splitext(item.get("path"))
                results.append({
                    "id": item.get("id"),
                    "url": item.get("path"),  # Direct full-res link
                    "thumbnail": item.get("thumbs", {}).get("large"),
                    "resolution": item.get("resolution"),
                    "file_type": item.get("file_type"),
                    "file_size": item.get("file_size"),
                    "ext": ext
                })
            print(json.dumps(results))
    except Exception as e:
        print(json.dumps({"error": str(e)}), file=sys.stderr)
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
    search_parser.add_argument("--sorting", type=str, default="relevance", help="Sorting method")
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
