#!/usr/bin/env python3
"""fzf preview for scheme_fzf.sh — render a color scheme as swatches.

Reads the fixed palettes from wallpaper_apply.sh (embedded python), so there
is a single source of truth. Auto schemes (generated from the wallpaper) get
a short text note instead.
"""
import sys
from pathlib import Path

if len(sys.argv) >= 3:
    KEY, LABEL = sys.argv[1], sys.argv[2]
else:
    KEY, _, LABEL = sys.argv[1].partition("|")

ALIAS = {
    "serpantinum": "mocha", "catppuccin": "mocha", "mocha": "mocha",
    "catppuccin_frappe": "frappe", "frappe": "frappe",
    "catppuccin_latte": "latte", "latte": "latte",
    "catppuccin_macchiato": "macchiato", "macchiato": "macchiato",
    "nord": "nord",
    "tokyo": "tokyo", "tokyonight": "tokyo", "tokyo_night": "tokyo",
    "dracula": "dracula",
    "gruvbox": "gruvbox",
    "rosepine": "rosepine", "rose_pine": "rosepine",
    "kanagawa": "kanagawa",
    "everforest": "everforest",
    "solarized": "solarized",
    "onedark": "onedark", "one_dark": "onedark",
    "ayu": "ayu",
    "horizon": "horizon",
    "nightowl": "nightowl", "night_owl": "nightowl",
    "material": "material",
    "monokai": "monokai",
    "palenight": "palenight",
    "oceanic": "oceanic",
    "snazzy": "snazzy",
    "github_dark": "github_dark", "github-dark": "github_dark",
    "nightfox": "nightfox",
    "rosepine_moon": "rosepine_moon", "rose_pine_moon": "rosepine_moon",
    "rosepine_dawn": "rosepine_dawn", "rose_pine_dawn": "rosepine_dawn",
    "zenburn": "zenburn",
    "synthwave": "synthwave",
    "doom": "doom",
    "vscode_dark": "vscode_dark", "vscode-dark": "vscode_dark",
    "moonfly": "moonfly",
    "cobalt": "cobalt", "cobalt2": "cobalt",
    "wombat": "wombat",
    "shades_of_purple": "shades_of_purple", "shades-of-purple": "shades_of_purple",
    "solarized_light": "solarized_light",
    "gruvbox_light": "gruvbox_light",
    "tokyoday": "tokyoday",
    "everforest_light": "everforest_light",
}

apply = Path.home() / ".config/quickshell/scripts/wallpaper_apply.sh"
raw = apply.read_text()
body = raw.split("<<'PY'", 1)[1].split("\nPY", 1)[0]
ns = {}
argv = sys.argv
sys.argv = ["_", "mocha", "/tmp/scheme_preview_dummy.json"]
try:
    exec(body, ns)
finally:
    sys.argv = argv
PALETTES = ns["p"]

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