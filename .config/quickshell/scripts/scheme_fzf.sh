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

PICK="$(printf '%s\n' "${SCHEMES[@]}" | fzf \
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