#!/bin/sh
# Get currently playing media info via playerctl.
# Output format: status|artist - title
# Status: playing, paused, stopped, or none (no player)

status=$(playerctl status 2>/dev/null)
if [ -z "$status" ] || [ "$status" = "No players found" ]; then
    echo "none|"
    exit 0
fi

artist=$(playerctl metadata artist 2>/dev/null)
title=$(playerctl metadata title 2>/dev/null)

if [ -n "$artist" ] && [ -n "$title" ]; then
    info="$artist - $title"
elif [ -n "$title" ]; then
    info="$title"
else
    info=""
fi

# Truncate to 40 chars
info=$(echo "$info" | cut -c1-40)

echo "$status|$info"
