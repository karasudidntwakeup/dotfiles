#!/usr/bin/env python3
"""fzf preview for scheme_fzf.sh — render a color scheme as swatches.

Reads the fixed palettes from wallpaper_apply.sh (embedded python) plus the
nvim base46 themes (nvim_themes.json), so there is a single source of truth.
Auto schemes (generated from the wallpaper) get a short text note instead.
"""
import json
import re
import sys
from pathlib import Path

SCRIPTS = Path.home() / ".config/quickshell/scripts"

if len(sys.argv) >= 3:
    KEY, LABEL = sys.argv[1], sys.argv[2]
else:
    KEY, _, LABEL = sys.argv[1].partition("|")

apply = SCRIPTS / "wallpaper_apply.sh"
text = apply.read_text()

# Derive scheme-name -> preset mapping from wallpaper_apply.sh's case
# statement so new presets don't require touching this file.
ALIAS = {}
for m in re.finditer(r"^  ([a-z0-9_|.+\-]+)\)\s+PRESET=\"([a-z0-9_]+)\"\s*;;", text, re.M):
    for name in m.group(1).split("|"):
        ALIAS[name.strip()] = m.group(2)

body = text.split("<<'PY'", 1)[1].split("\nPY", 1)[0]
ns = {}
argv = sys.argv
sys.argv = ["_", "mocha", "/tmp/scheme_preview_dummy.json", str(SCRIPTS / "nvim_themes.json")]
try:
    exec(body, ns)
finally:
    sys.argv = argv
PALETTES = dict(ns["p"])
try:
    PALETTES.update(json.load(open(SCRIPTS / "nvim_themes.json")))
except OSError:
    pass

if KEY.startswith("nv_"):
    flavor = KEY[3:]
else:
    flavor = ALIAS.get(KEY)
if not flavor or flavor not in PALETTES:
    print(f"◆ {LABEL or KEY}")
    print()
    print("Auto scheme — colors are generated from the")
    print("current wallpaper by matugen, so there is no")
    print("fixed palette to preview.")
    sys.exit(0)

c = PALETTES[flavor]


def swatch(name, h):
    r, g, b = (int(h[i:i + 2], 16) for i in (1, 3, 5))
    return f"\x1b[48;2;{r};{g};{b}m    \x1b[0m {name:<14} {h}"


print(f"◆ {LABEL} ({flavor})")
print()
for name in ("base", "mantle", "crust", "surface0", "surface1", "surface2"):
    print(swatch(name, c[name]))
print()
for name in ("text", "subtext0", "subtext1"):
    print(swatch(name, c[name]))
print()
for name in ("blue", "sapphire", "green", "peach",
             "yellow", "red", "maroon", "mauve", "pink"):
    print(swatch(name, c[name]))