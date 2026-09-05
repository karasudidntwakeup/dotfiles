#!/usr/bin/env python3
"""
Incremental wallpaper color extractor + thumbnail generator for the
QuickShell wallpaper picker.

Scans the wallpaper directory and, for every image, generates a small
thumbnail and extracts a dominant-color bucket. Results are cached (keyed by
file size + mtime) so only new/changed images are re-processed.

Usage:
    color_extract.py <wallpaper_dir> <cache_dir>
"""

import os
import sys
import json
import hashlib
import colorsys
import time

try:
    from PIL import Image
except Exception:
    Image = None

BUCKETS = [
    ("Red",      (345, 15)),
    ("Orange",   (15, 45)),
    ("Yellow",   (45, 70)),
    ("Green",    (70, 160)),
    ("Blue",     (160, 260)),
    ("Purple",   (260, 300)),
    ("Pink",     (300, 345)),
]

IMAGE_EXT = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp", ".heic",
             ".JPG", ".JPEG", ".PNG", ".WEBP", ".GIF", ".BMP", ".HEIC"}

THUMB_HEIGHT = 420
# Hard cap so a huge first run doesn't block the shell; large dirs are
# processed across several invocations.
CHUNK_MAX = 80


def bucket_from_hsl(h, s):
    if s < 0.15:
        return "Monochrome"
    if h >= 345 or h < 15:
        return "Red"
    for name, (lo, hi) in BUCKETS:
        if lo <= h < hi:
            return name
    return "Red"


def dominant_color(path):
    if Image is None:
        return (128, 128, 128)
    try:
        with Image.open(path) as im:
            im = im.convert("RGB")
            im.thumbnail((200, 200))
            im = im.quantize(colors=16, method=Image.MEDIANCUT)
            palette = im.getpalette()
            counts = sorted(im.getcolors(), reverse=True)
            best = None
            best_score = -1
            for count, idx in counts[:6]:
                r, g, b = palette[idx * 3], palette[idx * 3 + 1], palette[idx * 3 + 2]
                if count > best_score:
                    best_score = count
                    best = (r, g, b)
            return best or (128, 128, 128)
    except Exception:
        return (128, 128, 128)


def color_palette(path, limit=6):
    """Return up to `limit` distinct hex colors (top palette swabs)."""
    if Image is None:
        return []
    out = []
    try:
        with Image.open(path) as im:
            im = im.convert("RGB")
            im.thumbnail((120, 120))
            im = im.quantize(colors=10, method=Image.MEDIANCUT)
            palette = im.getpalette()
            counts = sorted(im.getcolors(), reverse=True)
        seen = set()
        for count, idx in counts:
            r, g, b = palette[idx * 3], palette[idx * 3 + 1], palette[idx * 3 + 2]
            if (r < 20 and g < 20 and b < 20) or (r > 235 and g > 235 and b > 235):
                continue
            key = "{}:{}:{}".format(r // 16, g // 16, b // 16)
            if key in seen:
                continue
            seen.add(key)
            out.append("#{:02x}{:02x}{:02x}".format(r, g, b))
            if len(out) >= limit:
                break
    except Exception:
        pass
    return out


def make_thumbnail(src, dst):
    if Image is None:
        return False
    try:
        with Image.open(src) as im:
            im = im.convert("RGB")
            im.thumbnail((10000, THUMB_HEIGHT))
            im.save(dst, "JPEG", quality=82)
            return True
    except Exception:
        return False


def file_sig(path):
    """Return a signature that changes when a file is created/edited."""
    try:
        st = os.stat(path)
        return "{}:{}:{}".format(st.st_size, int(st.st_mtime), st.st_ino)
    except Exception:
        return ""


def load_cache(cache_dir):
    path = os.path.join(cache_dir, "wallpaper-cache.json")
    if os.path.isfile(path):
        try:
            with open(path) as f:
                return json.load(f)
        except Exception:
            return {}
    return {}


def save_cache(cache_dir, cache):
    path = os.path.join(cache_dir, "wallpaper-cache.json")
    try:
        with open(path, "w") as f:
            json.dump(cache, f)
    except Exception:
        pass


def main():
    if len(sys.argv) < 3:
        print(json.dumps({"error": "usage: color_extract.py <dir> <cache_dir>"}))
        sys.exit(1)

    src_dir = os.path.abspath(sys.argv[1])
    cache_dir = os.path.abspath(sys.argv[2])
    os.makedirs(cache_dir, exist_ok=True)
    thumb_dir = os.path.join(cache_dir, "thumbs")
    os.makedirs(thumb_dir, exist_ok=True)

    cache = load_cache(cache_dir)

    # Collect candidate files, track current files for pruning.
    files = []
    try:
        names = sorted(os.listdir(src_dir))
    except Exception:
        names = []
    for name in names:
        path = os.path.join(src_dir, name)
        if os.path.isfile(path) and os.path.splitext(name)[1] in IMAGE_EXT:
            files.append((name, path))

    cur_names = set()
    processed = 0
    has_new = False
    items = []

    for name, path in files:
        cur_names.add(name)
        sig = file_sig(path)
        cached = cache.get(name)

        # Reuse cached result if the file is unchanged and the thumb exists.
        if cached and cached.get("sig") == sig and \
           os.path.isfile(cached.get("thumbPath", "")):
            items.append(cached)
            continue

        if processed >= CHUNK_MAX:
            # Reached this run's budget; carry remaining names forward from
            # cache when available (they'll be resolved next run).
            if cached:
                items.append(cached)
            continue

        r, g, b = dominant_color(path)
        h, s, _ = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
        bucket = bucket_from_hsl(h * 360.0, s)
        hexcolor = "#{:02x}{:02x}{:02x}".format(r, g, b)

        digest = hashlib.md5(name.encode("utf-8")).hexdigest()[:12]
        thumb_name = "thumb_" + digest + ".jpg"
        thumb_path = os.path.join(thumb_dir, thumb_name)
        if not os.path.exists(thumb_path):
            make_thumbnail(path, thumb_path)
        # Fall back to the original file if a thumbnail can't be generated
        # (e.g. HEIC / corrupt files). Using the existing source path also
        # stops these from being reprocessed every run.
        if not os.path.isfile(thumb_path):
            thumb_path = path

        entry = {
            "fileName": name,
            "filePath": path,
            "thumbUrl": "file://" + thumb_path,
            "thumbPath": thumb_path,
            "hex": hexcolor,
            "colors": color_palette(path),
            "bucket": bucket,
            "sig": sig,
        }
        cache[name] = entry
        items.append(entry)
        processed += 1
        has_new = True

    # Drop entries for deleted files.
    for old in list(cache.keys()):
        if old not in cur_names:
            del cache[old]

    save_cache(cache_dir, cache)

    # Preserve a stable order: Filenames (works with unicode/中文 names).
    items.sort(key=lambda e: e["fileName"])
    manifest = {
        "srcDir": src_dir,
        "done": processed == 0 or processed < CHUNK_MAX,
        "items": items,
    }

    out_path = os.path.join(cache_dir, "wallpaper-list.json")
    out_tmp = out_path + ".tmp"

    try:
        with open(out_tmp, "w") as f:
            json.dump(manifest, f)
        # Atomic rename never exposes a truncated file to readers.
        os.replace(out_tmp, out_path)
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

    print(json.dumps({"processed": processed, "total": len(files)}))


if __name__ == "__main__":
    main()
