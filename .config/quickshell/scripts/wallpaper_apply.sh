#!/usr/bin/env bash
# Apply a wallpaper with full matugen customization — Drop-in replacement
# for ~/.config/rofi/wallpaper-changer/launcher.sh.
#
# usage:
#   wallpaper_apply.sh <image_path> <mode:dark|light> <scheme> [hex]=RRGGBB
#
# mode:   dark | light         (matugen --prefer + QuickShell qs-theme.json)
# scheme: content|expressive|fidelity|fruit_salad|monochrome|neutral|
#         rainbow|smart|vibrant|wallpaper_color
#   wallpaper_color requires a 4th arg: the RGB hex to generate from.

set -e

IMG="$1"
MODE="${2:-dark}"
SCHEME="${3:-content}"
HEX="$4"

QUICK_THEME_FILE="$HOME/.config/quickshell/qs-theme.json"

[ -f "$IMG" ] || { echo "wallpaper_apply: not found: $IMG" >&2; exit 1; }

# matugen prefer
case "$MODE" in
  light|Light) PREFER="lightness"; QUICK='{"mode": "light"}' ;;
  *)           PREFER="darkness";  QUICK='{"mode": "dark"}'  ;;
esac

# Build matugen source + optional --type
MATUGEN_SRC=(image "$IMG")
TYPE=""
case "$SCHEME" in
  wallpaper_color|wallpaper-color|color)
      HEX="${HEX//#/}"
      [ ${#HEX} -eq 6 ] || { echo "wallpaper_apply: color scheme needs hex" >&2; exit 1; }
      MATUGEN_SRC=(color hex "$HEX")
      ;;
  content)      TYPE="scheme-content" ;;
  expressive)   TYPE="scheme-expressive" ;;
  fidelity)     TYPE="scheme-fidelity" ;;
  fruit_salad)  TYPE="scheme-fruit-salad" ;;
  monochrome)   TYPE="scheme-monochrome" ;;
  neutral)      TYPE="scheme-neutral" ;;
  rainbow)      TYPE="scheme-rainbow" ;;
  smart)        TYPE="scheme-smart" ;;
  vibrant)      TYPE="scheme-vibrant" ;;
  *)            TYPE="scheme-content" ;;
esac

MATUGEN_ARGS=("${MATUGEN_SRC[@]}" --prefer "$PREFER")
[ -n "$TYPE" ] && MATUGEN_ARGS+=(--type "$TYPE")
matugen "${MATUGEN_ARGS[@]}"

# awww re-reads every cached sprite-sheet on each `img` call; clear the cache
# so applying stays instant.
awww clear-cache 2>/dev/null || true
awww img "$IMG" --transition-type random --transition-duration 2.0

# QuickShell only: write the chosen light/dark mode for the bar to read.
# Matugen stays dark/light per PREFER but qs-theme only affects QuickShell's
# pill coloring (the rest of the system follows the matugen run above).
printf '%s\n' "$QUICK" > "$QUICK_THEME_FILE"

# Remember the last applied wallpaper so the picker can preselect it.
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/wallpaper"
mkdir -p "$CACHE"
printf '%s\n' "$IMG" > "$CACHE/current.txt"

exit 0
