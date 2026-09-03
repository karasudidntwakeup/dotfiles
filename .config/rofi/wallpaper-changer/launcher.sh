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

MODE=$(sed -n 's/.*"mode"[[:space:]]*:[[:space:]]*"\([a-z]*\)".*/\1/p' "$HOME/.config/quickshell/qs-theme.json" 2>/dev/null)
if [ "$MODE" = "light" ]; then
    BG=$(sed -n 's/^[[:space:]]*backgroundl:[[:space:]]*\([^;]*\);.*/\1/p' "$HOME/.config/rofi/colors.rasi" | head -1)
else
    BG=$(sed -n 's/^[[:space:]]*background:[[:space:]]*\([^;]*\);.*/\1/p' "$HOME/.config/rofi/colors.rasi" | head -1)
fi

MODE_CHOICE=$(printf '%s\n' "Dark" "Light" \
  | rofi -dmenu -p "Mode" \
      -theme-str "window { background-color: ${BG:-#111318}; border-radius: 20px; padding: 18px; }")

[ -z "$MODE_CHOICE" ] && exit 1

case "$MODE_CHOICE" in
  "Dark"|"dark") MATUGEN_PREFER="darkness"
                 QUICK_THEME='{"mode": "dark"}'
                 cat > "$HOME/.config/rofi/mode.rasi" <<'EOF'
* {
    window-bg:         @background;
    pill:              @surface;
    pill-selected:     @accent;
    pill-text:         @onsurface;
    pill-text-sel:     @onprimary;
    pill-placeholder:  rgba(255, 255, 255, 0.4);
    mode-pill:         @surface;

    panel-text:        @foreground;
    panel-accent:      @accent;
}
EOF
                 ;;
  "Light"|"light") MATUGEN_PREFER="lightness"
                 QUICK_THEME='{"mode": "light"}'
                 cat > "$HOME/.config/rofi/mode.rasi" <<'EOF'
* {
    window-bg:         @backgroundl;
    pill:              @surfacel;
    pill-selected:     @accentl;
    pill-text:         @onsurfacel;
    pill-text-sel:     @onprimaryl;
    pill-placeholder:  rgba(0, 0, 0, 0.4);
    mode-pill:         @surfacel;

    panel-text:        @foregroundl;
    panel-accent:      @accentl;
}
EOF
                 ;;
  *) exit 1 ;;
esac

SCHEME_CHOICE=$(printf '%s\n' "Wallpaper Colors" "Content" "Expressive" "Fidelity" "Fruit Salad" "Monochrome" "Neutral" "Rainbow" "Smart" "Vibrant" \
  | rofi -dmenu -p "Scheme" \
      -theme-str "window { background-color: ${BG:-#111318}; border-radius: 20px; padding: 18px; }")

[ -z "$SCHEME_CHOICE" ] && exit 1

case "$SCHEME_CHOICE" in
  "Wallpaper Colors")
      COLOR_MENU=""
      while IFS= read -r line; do
          HEX=$(sed -nE 's/.*#([0-9A-Fa-f]{6}).*/\1/p' <<< "$line" | tr '[:lower:]' '[:upper:]')
          [ -z "$HEX" ] && continue
          COLOR_MENU+="<span background='#${HEX}' foreground='#${HEX}'>██</span>  #${HEX}\n"
      done < <(magick "$FULL_PATH" -auto-orient -thumbnail 120x120^ -colors 8 -depth 8 -format '%c' histogram:info:- 2>/dev/null | sort -rn)
      COLOR_CHOICE=$(printf '%b' "$COLOR_MENU" \
          | rofi -dmenu -markup-rows -p "Color" \
              -theme-str "window { background-color: ${BG:-#111318}; border-radius: 20px; padding: 18px; }")
      [ -z "$COLOR_CHOICE" ] && exit 1
      COLOR_HEX=$(grep -oP '#[0-9A-Fa-f]{6}' <<< "$COLOR_CHOICE" | tail -1 | tr '[:lower:]' '[:upper:]')
      [ -z "$COLOR_HEX" ] && exit 1
      MATUGEN_SRC=(color hex "$COLOR_HEX")
      ;;
  Content)       SCHEME_TYPE="scheme-content"
                 MATUGEN_SRC=(image "$FULL_PATH") ;;
  Expressive)    SCHEME_TYPE="scheme-expressive"
                 MATUGEN_SRC=(image "$FULL_PATH") ;;
  Fidelity)      SCHEME_TYPE="scheme-fidelity"
                 MATUGEN_SRC=(image "$FULL_PATH") ;;
  "Fruit Salad") SCHEME_TYPE="scheme-fruit-salad"
                 MATUGEN_SRC=(image "$FULL_PATH") ;;
  Monochrome)    SCHEME_TYPE="scheme-monochrome"
                 MATUGEN_SRC=(image "$FULL_PATH") ;;
  Neutral)       SCHEME_TYPE="scheme-neutral"
                 MATUGEN_SRC=(image "$FULL_PATH") ;;
  Rainbow)       SCHEME_TYPE="scheme-rainbow"
                 MATUGEN_SRC=(image "$FULL_PATH") ;;
  Smart)         SCHEME_TYPE="scheme-smart"
                 MATUGEN_SRC=(image "$FULL_PATH") ;;
  Vibrant)       SCHEME_TYPE="scheme-vibrant"
                 MATUGEN_SRC=(image "$FULL_PATH") ;;
  *) exit 1 ;;
esac

# awww re-reads every cached sprite-sheet on each `img` call, so a bloated
# cache (~GBs of rendered frames) makes applying take tens of seconds.
# Clearing it before setting the wallpaper keeps `awww img` instant.
awww clear-cache 2>/dev/null || true

MATUGEN_ARGS=("${MATUGEN_SRC[@]}" --prefer "$MATUGEN_PREFER")
[ -n "$SCHEME_TYPE" ] && MATUGEN_ARGS+=(--type "$SCHEME_TYPE")
matugen "${MATUGEN_ARGS[@]}"

awww img "$FULL_PATH" --transition-type random --transition-duration 2.0

# Quick Shell only: write the chosen light/dark mode for the bar to read.
# Matugen stays in dark mode above, so ONLY Quick Shell is affected — no
# GTK/Qt/terminal/system-wide light theme is applied.
printf '%s\n' "$QUICK_THEME" > "$HOME/.config/quickshell/qs-theme.json"

STATIC_CACHE="$HOME/.cache/wallpaper-static"

# If the selected wallpaper is a live/animated one, keep the old static in hyprlock.
if [[ "$FULL_PATH" == *"/video_webp/"* ]]; then
    if [ -f "$STATIC_CACHE" ]; then
        STATIC=$(cat "$STATIC_CACHE")
        rel=${STATIC#"$HOME/"}
        sed -i "s|^\$wallpaper[[:space:]]*=.*|\$wallpaper                  = ~/$rel|" ~/.config/hypr/hyprlock.conf 2>/dev/null
    fi
else
    # Static image: cache it and sync hyprlock to it.
    echo "$FULL_PATH" > "$STATIC_CACHE"
    rel=${FULL_PATH#"$HOME/"}
    sed -i "s|^\$wallpaper[[:space:]]*=.*|\$wallpaper                  = ~/$rel|" ~/.config/hypr/hyprlock.conf 2>/dev/null
fi
