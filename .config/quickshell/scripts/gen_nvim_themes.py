#!/usr/bin/env python3
"""Generate nvim_themes.json from NvChad base46 theme files.

Each base46 theme defines M.base_16 (base16 ramp + accents) and M.base_30
(extended colors). We convert each theme into the serpantinum-style palette
dict used by wallpaper_apply.sh (keys: base, mantle, crust, surface0-2,
overlay0-2, text, subtext0-1 + accent roles).

Output: <scripts>/nvim_themes.json  -- { "theme_name": {21 colors}, ... }
"""
import json
import re
import sys
from pathlib import Path

THEMES_DIR = Path.home() / ".local/share/nvim/lazy/base46/lua/base46/themes"
OUT = Path(__file__).parent / "nvim_themes.json"
if len(sys.argv) > 1:
    THEMES_DIR = Path(sys.argv[1])
if len(sys.argv) > 2:
    OUT = Path(sys.argv[2])


def parse_table_raw(text, name):
    m = re.search(r"M\.%s\s*=\s*\{(.*?)^\}" % re.escape(name), text, re.M | re.S)
    if not m:
        return {}
    out = {}
    for line in m.group(1).splitlines():
        line = re.sub(r"--.*$", "", line).strip()
        mm = re.match(r"(\w+)\s*=\s*(.*?),\s*$", line) or re.match(r"(\w+)\s*=\s*(.*)$", line)
        if mm:
            out[mm.group(1)] = mm.group(2).strip().strip('"').strip("'")
    return out


def resolve(raw, locals_map, tables):
    for _ in range(6):
        if raw.startswith("#"):
            return raw
        if raw in locals_map:
            raw = locals_map[raw]
            continue
        if raw.startswith("M.base_30."):
            raw = tables["b30"].get(raw[len("M.base_30."):]) or raw
            continue
        if raw.startswith("M.base_16."):
            raw = tables["b16"].get(raw[len("M.base_16."):]) or raw
            continue
        break
    return None


palettes = {}
for f in sorted(THEMES_DIR.glob("*.lua")):
    text = f.read_text()
    locals_map = dict(re.findall(r"^local\s+(\w+)\s*=\s*\"(#[0-9A-Fa-f]{6})\"", text, re.M))
    raw30 = parse_table_raw(text, "base_30")
    raw16 = parse_table_raw(text, "base_16")
    tables = {"b30": {}, "b16": {}}
    b30, b16 = tables["b30"], tables["b16"]
    for k, v in raw30.items():
        r = resolve(v, locals_map, tables)
        if r:
            b30[k] = r
    for k, v in raw16.items():
        r = resolve(v, locals_map, tables)
        if r:
            b16[k] = r
    if not b30 or not b16:
        continue

    def g(*order):
        for src_name, key in order:
            src = b30 if src_name == "b30" else b16
            if src.get(key):
                return src[key]
        return None

    c = {
        "crust":     g(("b30", "darker_black"), ("b16", "base00")),
        "base":      g(("b30", "black"), ("b16", "base00")),
        "mantle":    g(("b30", "statusline_bg"), ("b30", "black2"), ("b16", "base01")),
        "surface0":  g(("b30", "one_bg"), ("b16", "base02")),
        "surface1":  g(("b30", "one_bg2"), ("b16", "base03")),
        "surface2":  g(("b30", "one_bg3"), ("b30", "one_bg2"), ("b16", "base04")),
        "overlay0":  g(("b30", "grey"), ("b16", "base03")),
        "overlay1":  g(("b30", "grey_fg"), ("b16", "base04")),
        "overlay2":  g(("b30", "grey_fg2"), ("b30", "light_grey"), ("b16", "base05")),
        "text":      g(("b16", "base05"), ("b30", "white")),
        "subtext0":  g(("b16", "base06"), ("b30", "white")),
        "subtext1":  g(("b16", "base04"), ("b30", "light_grey"), ("b16", "base05")),
        "red":       g(("b30", "red"), ("b16", "base08")),
        "peach":     g(("b30", "orange"), ("b16", "base09")),
        "yellow":    g(("b30", "yellow"), ("b16", "base0A")),
        "green":     g(("b30", "green"), ("b16", "base0B")),
        "sapphire":  g(("b30", "cyan"), ("b16", "base0C")),
        "blue":      g(("b30", "blue"), ("b16", "base0D")),
        "mauve":     g(("b30", "purple"), ("b16", "base0E")),
        "pink":      g(("b30", "pink"), ("b30", "baby_pink"), ("b16", "base0E")),
        "maroon":    g(("b16", "base0F"), ("b30", "red"), ("b16", "base08")),
    }
    if not c["base"] or not c["text"]:
        print(f"skip {f.name}: missing base/text", file=sys.stderr)
        continue
    palettes[f.stem] = {k: v for k, v in c.items() if v}

OUT.write_text(json.dumps(palettes, indent=2) + "\n")
print(f"wrote {len(palettes)} themes -> {OUT}")