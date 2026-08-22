#!/usr/bin/env bash

WALLPAPER_DIR="$HOME/wallpaper"

CURRENT=$(awww query 2>/dev/null | grep -oP 'image: \K.*')
CURRENT_NAME=$(basename "${CURRENT%.*}")

WALLPAPER_LIST=$(find "$WALLPAPER_DIR" -type f ! -name ".*" \( -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" -o -name "*.webp" \) -printf '%T@ %p\n' \
  | sort -rn \
  | cut -d' ' -f2-)

SELECTED_ROW=0
INDEX=0
MENU_ITEMS=""
while IFS= read -r img; do
    NAME=$(basename "${img%.*}")
    MENU_ITEMS+="${NAME}\0icon\x1f${img}\n"
    if [ "$NAME" = "$CURRENT_NAME" ]; then
        SELECTED_ROW=$INDEX
    fi
    INDEX=$((INDEX + 1))
done <<< "$WALLPAPER_LIST"

SELECTED=$(echo -en "$MENU_ITEMS" \
  | rofi -dmenu -p "Wallpaper" -show-icons -theme "$HOME/.config/rofi/wallpaper-changer/theme.rasi" -selected-row "$SELECTED_ROW")

# Reconstruct full path from selected name
FULL_PATH=$(find "$WALLPAPER_DIR" -type f ! -name ".*" \( -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" -o -name "*.webp" \) \
  | grep -F "/${SELECTED}.")

[ -z "$FULL_PATH" ] && exit 1

BG=$(sed -n 's/^[[:space:]]*background:[[:space:]]*\([^;]*\);.*/\1/p' "$HOME/.config/rofi/colors.rasi" | head -1)

SCHEME_CHOICE=$(printf '%s\n' "Monochrome" "Vibrant" "Expressive" "Content" "Neutral" "Rainbow" "Fruit Salad" "Tonal Spot" \
  | rofi -dmenu -p "Scheme" \
      -theme-str "window { background-color: ${BG:-#111318}; border-radius: 20px; padding: 18px; }")

[ -z "$SCHEME_CHOICE" ] && exit 1

case "$SCHEME_CHOICE" in
  Monochrome)  SCHEME_TYPE="scheme-monochrome" ;;
  Vibrant)     SCHEME_TYPE="scheme-vibrant" ;;
  Expressive)  SCHEME_TYPE="scheme-expressive" ;;
  Content)     SCHEME_TYPE="scheme-content" ;;
  Neutral)     SCHEME_TYPE="scheme-neutral" ;;
  Rainbow)     SCHEME_TYPE="scheme-rainbow" ;;
  "Fruit Salad") SCHEME_TYPE="scheme-fruit-salad" ;;
  "Tonal Spot")  SCHEME_TYPE="scheme-tonal-spot" ;;
  *) exit 1 ;;
esac

matugen image "$FULL_PATH" --prefer darkness --type "$SCHEME_TYPE"

awww img "$FULL_PATH" --transition-type random --transition-duration 2.0

base=$(basename "$FULL_PATH")

sed -i 's|path = ~/wallpaper/.*|path = ~/wallpaper/'"$base"'|' ~/.config/hypr/hyprlock.conf 2>/dev/null
