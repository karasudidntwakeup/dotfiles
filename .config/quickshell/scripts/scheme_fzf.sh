#!/usr/bin/env bash
# Pick one of the fixed color palettes with fzf, then apply it system-wide
# (matugen + wallpaper). Run inside a terminal, e.g.:
#   foot -e ~/.config/quickshell/scripts/scheme_fzf.sh
#
# The palettes live in the apply script; this just lists them and reuses the
# currently applied wallpaper + mode.

set -e

# Launched from a hotkey (no TTY)? Pull up a terminal first.
if [ ! -t 1 ]; then
  exec foot -e "$0"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/wallpaper"
QS_THEME="$HOME/.config/quickshell/qs-theme.json"
mkdir -p "$CACHE"

SCHEMES=(
  # From wallpaper (material schemes via matugen --type).
  "tonal_spot|Auto · Tonal Spot"
  "content|Auto · Content"
  "expressive|Auto · Expressive"
  "fidelity|Auto · Fidelity"
  "vibrant|Auto · Vibrant"
  "neutral|Auto · Neutral"
  "monochrome|Auto · Monochrome"
  "bw|Auto · Black & White"
  "rainbow|Auto · Rainbow"
  "fruit_salad|Auto · Fruit Salad"
  "smart|Auto · Smart"
  # Fixed palettes.
  "nothing|Nothing OS 5.0"
  "serpantinum|Serpantinum"
  "catppuccin_frappe|Catppuccin Frappe"
  "catppuccin_macchiato|Catppuccin Macchiato"
  "catppuccin_latte|Catppuccin Latte"
  "nord|Nord"
  "tokyo|Tokyo Night"
  "dracula|Dracula"
  "gruvbox|Gruvbox"
  "rosepine|Rosé Pine"
  "kanagawa|Kanagawa"
  "everforest|Everforest"
  "solarized|Solarized Dark"
  "onedark|One Dark"
  "ayu|Ayu"
  "horizon|Horizon"
  "nightowl|Night Owl"
  "material|Material"
  "monokai|Monokai"
  "palenight|Palenight"
  "oceanic|Oceanic Next"
  "snazzy|Snazzy"
  "github_dark|GitHub Dark"
  "nightfox|Nightfox"
  "rosepine_moon|Rosé Pine Moon"
  "rosepine_dawn|Rosé Pine Dawn"
  "zenburn|Zenburn"
  "synthwave|Synthwave"
  "doom|Doom One"
  "vscode_dark|VSCode Dark"
  "moonfly|Moonfly"
  "cobalt|Cobalt2"
  "wombat|Wombat"
  "shades_of_purple|Shades of Purple"
  "solarized_light|Solarized Light"
  "gruvbox_light|Gruvbox Light"
  "tokyoday|Tokyo Day"
  "everforest_light|Everforest Light"
  # Omarchy community themes (https://omarchy.org/themes).
  "aetheria|Aetheria"
  "amberbyte|Amberbyte"
  "arc_blueberry|Arc Blueberry"
  "archwave|Archwave"
  "ash|Ash"
  "artzen|Artzen"
  "aura|Aura"
  "all_hallows_eve|All Hallow's Eve"
  "atelier|Atelier"
  "ayaka|Ayaka"
  "azure_glow|Azure Glow"
  "batman|Batman"
  "batou|Batou"
  "bauhaus|Bauhaus"
  "biscuit_de_mar_dark|Biscuit de Mar Dark"
  "black_arch|Black Arch"
  "black_gold|Black Gold"
  "black_sand|Black Sand"
  "bluedotrb|bluedotrb"
  "blue_ridge_dark|Blue Ridge Dark"
  "castle_on_a_lake|Castle on a Lake"
  "catppuccin_mocha_dark|Catppuccin Mocha Dark"
  "cincinnati|Cincinnati"
  "citrus_cynapse|Citrus Cynapse"
  "city_783|City-783"
  "cobalt2|Cobalt2"
  "coffee|Coffee"
  "coffee_latte|Coffee Latte"
  "commit|Commit"
  "cpunk|CpUnk"
  "crimson_gold|Crimson Gold"
  "darcula|Darcula"
  "demon|Demon"
  "dotrb|Dotrb"
  "dos_moos|Dos Moos"
  "drac|Drac"
  "eldritch|Eldritch"
  "event_horizon|Event Horizon"
  "evergarden|Evergarden"
  "felix|Felix"
  "fireside|Fireside"
  "flat_dracula|Flat Dracula"
  "flexoki_dark|Flexoki Dark"
  "forest_green|Forest Green"
  "frost|Frost"
  "fuchsblau|fuchsblau"
  "futurism|Futurism"
  "futurist|Futurist"
  "gand|Gand"
  "ghost_pastel|Ghost Pastel"
  "gold_rush|Gold Rush"
  "golden_brown|Golden Brown"
  "the_greek|The Greek"
  "greek_noir|Greek Noir"
  "green_garden|Green Garden"
  "gruvbox_material|Gruvbox Material"
  "harbor|Harbor"
  "harbor_dark|Harbor Dark"
  "hermarchy|Hermarchy"
  "hinterlands|Hinterlands"
  "infernium|Infernium"
  "inky_pinky|Inky Pinky"
  "japan_night|Japan Night"
  "lamplight|Lamplight"
  "lawson_night|Lawson Night"
  "map_quest|Map Quest"
  "mars|Mars"
  "matrix|Matrix"
  "mechanoonna|Mechanoonna"
  "midnight|Midnight"
  "milky_matcha|Milky Matcha"
  "mini_jcw|Mini Jcw"
  "moodpeak|Moodpeak"
  "nagai_poolside|Nagai Poolside"
  "naysayer|Naysayer"
  "neo_sploosh|Neo Sploosh"
  "neon_dusk|Neon Dusk"
  "neovoid|Neovoid"
  "neptune_blue|Neptune Blue"
  "nes|NES"
  "noir|Noir"
  "oligarchy|Oligarchy"
  "nujabes|Nujabes"
  "omacarchy|Omacarchy"
  "omaled|OmaLED"
  "one_dark|One Dark"
  "one_dark_pro|One Dark Pro"
  "oxo_carbon|Oxo Carbon"
  "pagan|Pagan"
  "pandora|Pandora"
  "periphery|Periphery"
  "pina|Pina"
  "pink_blood|Pink Blood"
  "pulsar|Pulsar"
  "purple_moon|Purple Moon"
  "purplewave|Purplewave"
  "quattrocento_light|Quattrocento Light"
  "rainy_night|Rainy Night"
  "red_monarch|Red Monarch"
  "red_pill|Red Pill"
  "retropc|RetroPC"
  "ristretto_light|Ristretto Light"
  "robzee84|RobZee84"
  "rose_pine_dark|Rose Pine Dark"
  "rose_pine_moon|Rose Pine Moon"
  "rose_of_dune|Rose of Dune"
  "ryu|Ryu"
  "sakura|Sakura"
  "sakura_mochi|Sakura Mochi"
  "saga|Saga"
  "sapphire|Sapphire"
  "shades_of_jade|Shades of Jade"
  "space_monkey|Space Monkey"
  "snow|Snow"
  "snow_black|Snow Black"
  "solarized_osaka|Solarized Osaka"
  "starry_night|Starry Night"
  "starsend|Starsend"
  "sunset|Sunset"
  "sunset_drive|Sunset Drive"
  "super_game_bro|Super Game Bro"
  "synthwave_84|Synthwave '84"
  "temerald|Temerald"
  "terminus|Terminus"
  "tokyo_night_oled|Tokyo Night OLED"
  "tycho|Tycho"
  "waffle_cat|Waffle Cat"
  "waveform_dark|Waveform Dark"
  "white_gold|White Gold"
  "windows_dark_mode|Windows Dark Mode"
  "winslow|Winslow"
  "van_gogh|Van Gogh"
  "vault|Vault"
  "velvet_night|Velvet Night"
  "venice_from_above|Venice from Above"
  "vesper|Vesper"
  "vhs_80|VHS 80"
  "void|Void"
  "vulkanite|Vulkanite"
  "lumon|Lumon"
  "akane|Akane"
  "aamis|Aamis"
  "copper_night|Copper Night"
  "ibm|IBM"
  "retro_fallout|Retro Fallout"
  "solitude|Solitude"
  "blackturq|Black Turq"
)

# Current wallpaper is used for the awww step. Fall back to the first image
# in ~/wallpaper if none was applied yet.
IMG="$(cat "$CACHE/current.txt" 2>/dev/null || true)"
if [ -z "$IMG" ] || [ ! -f "$IMG" ]; then
  IMG="$(find "$HOME/wallpaper" -maxdepth 1 -type f \
           -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' | head -1 || true)"
fi

MODE="dark"
if [ -f "$QS_THEME" ]; then
  QM="$(sed -n 's/.*"mode"[[:space:]]*:[[:space:]]*"\([a-z]*\)".*/\1/p' "$QS_THEME")"
  [ "$QM" = "light" ] && MODE="light" || MODE="dark"
fi

PREVIEW_PY="$SCRIPT_DIR/scheme_preview.py"

# NvChad base46 themes (nvim). Skip ones already covered by the list above:
# fixed palettes, Omarchy picks and auto schemes that would otherwise
# show up twice.
NV_SKIP=" catppuccin catppuccin-latte nord tokyonight gruvbox gruvbox_light rosepine rosepine-dawn kanagawa everforest everforest_light solarized_dark solarized_light solarized_osaka onedark ayu_dark horizon nightowl palenight oceanic-next github_dark nightfox zenburn vscode_dark wombat nothing monochrome eldritch vesper oxocarbon "
mapfile -t NV_SCHEMES < <(python3 - "$SCRIPT_DIR/nvim_themes.json" "$NV_SKIP" <<'PY'
import json, sys
path, skip = sys.argv[1:3]
skip = set(skip.split())
data = json.load(open(path))
def pretty(name):
    return " ".join(w for w in name.replace("-", " ").replace("_", " ").title().split() if w)
for name in sorted(data):
    if name in skip:
        continue
    print(f"nv_{name}|{pretty(name)}")
PY
)

ALL_SCHEMES=("${SCHEMES[@]}" "${NV_SCHEMES[@]}")

PICK="$(printf '%s\n' "${ALL_SCHEMES[@]}" | fzf \
    --prompt="scheme > " \
    --delimiter='|' --with-nth=2 \
    --preview="python3 '$PREVIEW_PY' {1} {2}" \
    --preview-window=right:30%:wrap)" || exit 0

KEY="${PICK%%|*}"
[ -n "$KEY" ] || exit 0

[ -n "$IMG" ] && [ -f "$IMG" ] || { echo "wallpaper_apply: no wallpaper image found" >&2; exit 1; }

echo ""
echo "Applying ${PICK#*|} ($KEY, mode=$MODE) ..."
"$SCRIPT_DIR/wallpaper_apply.sh" "$IMG" "$MODE" "$KEY" "" "1"
echo "Done."