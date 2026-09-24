#!/usr/bin/env python3
"""Scheme manifest generator for the QuickShell theme picker.

Single source of truth for scheme labels + order (edit here to add
schemes; palettes resolve via wallpaper_apply.sh aliases below):
  - labels come from SCHEMES below
  - fixed palettes come from the embedded dict in wallpaper_apply.sh
  - nvim extras come from nvim_themes.json (minus NV_SKIP)

Usage:
    scheme_list.py [cache_dir]
Writes scheme-list.json atomically. Instant (~300 small entries), so no
chunking/caching like color_extract.py — regenerate on every picker open.
"""
import json
import os
import re
import sys
from pathlib import Path

SCRIPTS = Path.home() / ".config/quickshell/scripts"
CACHE = Path(sys.argv[1]) if len(sys.argv) > 1 else (
    Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
    / "quickshell" / "wallpaper"
)

# Labels + order. Single source of truth (was scheme_fzf.sh).
SCHEMES = [
    ("tonal_spot", "Auto · Tonal Spot"),
    ("content", "Auto · Content"),
    ("expressive", "Auto · Expressive"),
    ("fidelity", "Auto · Fidelity"),
    ("vibrant", "Auto · Vibrant"),
    ("neutral", "Auto · Neutral"),
    ("monochrome", "Auto · Monochrome"),
    ("bw", "Auto · Black & White"),
    ("rainbow", "Auto · Rainbow"),
    ("fruit_salad", "Auto · Fruit Salad"),
    ("smart", "Auto · Smart"),
    ("nothing", "Nothing OS 5.0"),
    ("serpantinum", "Serpantinum"),
    ("catppuccin_frappe", "Catppuccin Frappe"),
    ("catppuccin_macchiato", "Catppuccin Macchiato"),
    ("catppuccin_latte", "Catppuccin Latte"),
    ("nord", "Nord"),
    ("tokyo", "Tokyo Night"),
    ("dracula", "Dracula"),
    ("gruvbox", "Gruvbox"),
    ("rosepine", "Rosé Pine"),
    ("kanagawa", "Kanagawa"),
    ("everforest", "Everforest"),
    ("solarized", "Solarized Dark"),
    ("onedark", "One Dark"),
    ("ayu", "Ayu"),
    ("horizon", "Horizon"),
    ("nightowl", "Night Owl"),
    ("material", "Material"),
    ("monokai", "Monokai"),
    ("palenight", "Palenight"),
    ("oceanic", "Oceanic Next"),
    ("snazzy", "Snazzy"),
    ("github_dark", "GitHub Dark"),
    ("nightfox", "Nightfox"),
    ("rosepine_moon", "Rosé Pine Moon"),
    ("rosepine_dawn", "Rosé Pine Dawn"),
    ("zenburn", "Zenburn"),
    ("synthwave", "Synthwave"),
    ("doom", "Doom One"),
    ("vscode_dark", "VSCode Dark"),
    ("moonfly", "Moonfly"),
    ("cobalt", "Cobalt2"),
    ("wombat", "Wombat"),
    ("shades_of_purple", "Shades of Purple"),
    ("solarized_light", "Solarized Light"),
    ("gruvbox_light", "Gruvbox Light"),
    ("tokyoday", "Tokyo Day"),
    ("everforest_light", "Everforest Light"),
    ("aetheria", "Aetheria"),
    ("ayaka", "Ayaka"),
    ("black_gold", "Black Gold"),
    ("felix", "Felix"),
    ("harbor_dark", "Harbor Dark"),
    ("hermarchy", "Hermarchy"),
    ("mars", "Mars"),
    ("mechanoonna", "Mechanoonna"),
    ("one_dark_pro", "One Dark Pro"),
    ("rainy_night", "Rainy Night"),
    ("retropc", "RetroPC"),
    ("void", "Void"),
    ("lumon", "Lumon"),
    ("akane", "Akane"),
    ("aamis", "Aamis"),
    ("copper_night", "Copper Night"),
    ("ibm", "IBM"),
    ("retro_fallout", "Retro Fallout"),
    ("solitude", "Solitude"),
    ("blackturq", "Black Turq"),
    ("miasma", "Miasma"),
    ("osaka_jade", "Osaka Jade"),
    ("giants", "Giants"),
    ("forest_night", "Forest Night"),
    ("evergreen", "Evergreen"),
    ("last_call", "Last Call"),
    ("city_783", "City-783"),
    ("ash", "Ash"),
    ("space_monkey", "Space Monkey"),
    ("midnight", "Midnight"),
    ("flexoki_dark", "Flexoki Dark"),
    ("spectra", "Spectra"),
    ("futurism", "Futurism"),
    ("batou", "Batou"),
    ("zonda_zoom", "Zonda Zoom"),
    ("sakura_mochi", "Sakura Mochi"),
    ("bauhaus", "Bauhaus"),
    ("gold_rush", "Gold Rush"),
    ("event_horizon", "Event Horizon"),
    ("lasthorizon", "Lasthorizon"),
]

# scheme key -> preset flavor, from wallpaper_apply.sh's case statement.
ALIAS = {}
try:
    apply = (SCRIPTS / "wallpaper_apply.sh").read_text()
    for m in re.finditer(
        r"^  ([a-z0-9_*|.+\-]+)\)\s+PRESET=\"([a-z0-9_]+)\"\s*;;",
        apply, re.M,
    ):
        for name in m.group(1).split("|"):
            name = name.strip()
            if name and "*" not in name:
                ALIAS[name] = m.group(2)
except Exception:
    pass

# Fixed palettes: exec the embedded python dict from wallpaper_apply.sh so
# there is a single source of truth for preset colors.
PALETTES = {}
try:
    body = apply.split("<<'PY'", 1)[1].split("\nPY", 1)[0]
    ns, argv = {}, sys.argv
    sys.argv = ["_", "mocha", "/tmp/scheme_list_dummy.json",
                str(SCRIPTS / "nvim_themes.json")]
    try:
        exec(body, ns)
    finally:
        sys.argv = argv
    PALETTES = dict(ns.get("p", {}))
except Exception:
    pass

try:
    PALETTES.update(json.load(open(SCRIPTS / "nvim_themes.json")))
except OSError:
    pass

# NvChad extras, same skip list as fzf (avoid double-listing).
NV_SKIP = set(
    "catppuccin catppuccin-latte nord tokyonight gruvbox gruvbox_light "
    "rosepine rosepine-dawn kanagawa everforest everforest_light "
    "solarized_dark solarized_light solarized_osaka onedark ayu_dark "
    "horizon nightowl palenight oceanic-next github_dark nightfox zenburn "
    "vscode_dark wombat nothing monochrome eldritch vesper oxocarbon".split()
)

AUTO_KEYS = {"tonal_spot", "content", "expressive", "fidelity", "vibrant",
             "neutral", "monochrome", "bw", "rainbow", "fruit_salad", "smart",
             "wallpaper_color"}


def pretty(name):
    return " ".join(
        w for w in name.replace("-", " ").replace("_", " ").title().split()
        if w
    )


def swatches(flavor):
    """Compact preview colors: [base, surface0, text, blue, green, red,
    yellow, mauve, pink]. Empty for auto schemes (generated from wallpaper)."""
    c = PALETTES.get(flavor)
    if not c:
        return []
    return [c.get(k, "#808080") for k in
            ("base", "surface0", "text", "blue", "green",
             "red", "yellow", "mauve", "pink")]


items, seen = [], set()
for key, label in SCHEMES:
    seen.add(key)
    flavor = ALIAS.get(key)
    kind = "auto" if key in AUTO_KEYS else "fixed"
    items.append({"key": key, "label": label, "kind": kind,
                  "colors": swatches(flavor) if flavor else []})

# NvChad themes not already listed.
nv_names = sorted(
    n for n in PALETTES
    if n not in NV_SKIP and n not in ALIAS.values() and f"nv_{n}" not in seen
)
for name in nv_names:
    items.append({"key": f"nv_{name}", "label": pretty(name), "kind": "nv",
                  "colors": swatches(name)})

try:
    current = (CACHE / "scheme.txt").read_text().split()[0].strip()
except Exception:
    current = ""

CACHE.mkdir(parents=True, exist_ok=True)
out, tmp = CACHE / "scheme-list.json", CACHE / "scheme-list.json.tmp"
with open(tmp, "w") as f:
    json.dump({"current": current, "items": items}, f)
os.replace(tmp, out)
print(json.dumps({"total": len(items), "current": current}))
