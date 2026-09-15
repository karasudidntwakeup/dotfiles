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
  "serpantinum|Serpantinum (Catppuccin Mocha)"
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
  "solarized|Solarized (Dark)"
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
  "vscode_dark|VSCode Dark+"
  "moonfly|Moonfly"
  "cobalt|Cobalt2"
  "wombat|Wombat"
  "shades_of_purple|Shades of Purple"
  "solarized_light|Solarized (Light)"
  "gruvbox_light|Gruvbox (Light)"
  "tokyoday|Tokyo Night (Day)"
  "everforest_light|Everforest (Light)"
)

# Current wallpaper is used for the awww step. Fall back to the first image
# in ~/wallpaper if none was applied yet.
IMG="$(cat "$CACHE/current.txt" 2>/dev/null || true)"
if [ -z "$IMG" ] || [ ! -f "$IMG" ]; then
  IMG="$(find "$HOME/wallpaper" -maxdepth 1 -type f \
           -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' | head -1 || true)"
fi

# qs-theme.json stores the QuickShell pill mode, which is the opposite of the
# matugen --prefer we tell wallpaper_apply to use.
MODE="dark"
if [ -f "$QS_THEME" ]; then
  QM="$(sed -n 's/.*"mode"[[:space:]]*:[[:space:]]*"\([a-z]*\)".*/\1/p' "$QS_THEME")"
  [ "$QM" = "dark" ] && MODE="light" || MODE="dark"
fi

PREVIEW_PY="$SCRIPT_DIR/scheme_preview.py"

# NvChad base46 themes (nvim). Skip ones already covered by the list above.
NV_SKIP=" catppuccin nord tokyonight gruvbox gruvbox_light rosepine rosepine-dawn kanagawa everforest everforest_light solarized_dark solarized_light onedark ayu_dark horizon nightowl palenight oceanic-next github_dark nightfox zenburn vscode_dark wombat "
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
    print(f"nv_{name}|{pretty(name)} (nvim)")
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