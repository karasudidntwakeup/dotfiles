#!/usr/bin/env bash

WALLPAPER_DIR="$HOME/wallpaper"

SELECTED=$(find "$WALLPAPER_DIR" -type f ! -name ".*" \( -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" -o -name "*.webp" \) -printf '%T@ %p\n' \
  | sort -rn \
  | cut -d' ' -f2- \
  | while read -r img; do
      echo -en "$(basename "${img%.*}")\0icon\x1f$img\n"
    done \
  | rofi -dmenu -p "Wallpaper" -show-icons -theme "$HOME/.config/rofi/wallpaper-changer/theme.rasi")

# Reconstruct full path from selected name
FULL_PATH=$(find "$WALLPAPER_DIR" -type f ! -name ".*" \( -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" -o -name "*.webp" \) \
  | grep -F "/${SELECTED}.")

[ -z "$FULL_PATH" ] && exit 1

matugen image "$FULL_PATH" --prefer lightness

awww img "$FULL_PATH" --transition-type random --transition-duration 2.5

base=$(basename "$FULL_PATH")

sed -i 's|path = ~/wallpaper/.*|path = ~/wallpaper/'"$base"'|' ~/.config/hypr/hyprlock.conf
