#!/bin/bash

STATE_FILE="$HOME/.cache/monochrome_state"
CACHE_DIR="$HOME/.cache/wallpaper_monochrome"

mkdir -p "$CACHE_DIR"

# Toggle state
if [ -f "$STATE_FILE" ]; then
    ORIGINAL=$(tail -1 "$STATE_FILE")
    awww img "$ORIGINAL" --transition-type random --transition-duration 1.0
    rm -f "$STATE_FILE"
    exit 0
fi

# Get current wallpaper path
CURRENT=$(awww query 2>/dev/null | grep -oP 'image: \K.*')
[ -z "$CURRENT" ] && exit 1

BASENAME=$(basename "$CURRENT")
CACHED="$CACHE_DIR/$BASENAME"

# Store original path, generate monochrome if not cached
echo -e "monochrome\n$CURRENT" > "$STATE_FILE"
if [ ! -f "$CACHED" ]; then
    magick "$CURRENT" -colorspace Gray "$CACHED"
fi
awww img "$CACHED" --transition-type random --transition-duration 1.0
