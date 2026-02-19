#!/bin/sh

FILE="$1"

# Check file
if [ -z "$FILE" ]; then
    echo "Usage: set-wallpaper <file>"
    exit 1
fi

# Convert ~ to full path
FILE=$(realpath "$FILE")

# Full path to swww binary
SWWW_BIN="/usr/bin/swww"   # replace with the output of `which swww` in your terminal

# Start daemon if not running
"$SWWW_BIN" query >/dev/null 2>&1 || "$SWWW_BIN"-daemon & sleep 0.5

# Set wallpaper
"$SWWW_BIN" img "$FILE" --transition-type wipe --transition-duration 1

