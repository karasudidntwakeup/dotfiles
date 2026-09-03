#!/bin/sh
# Get currently playing media info via a single playerctl call.
# Output format: status|artist - title|pos|len|art

player="$(playerctl -l 2>/dev/null | head -1)"
if [ -z "$player" ]; then
    echo "none|"
    exit 0
fi

status="$(playerctl -p "$player" status 2>/dev/null)"
[ -z "$status" ] && status="stopped"

meta="$(playerctl -p "$player" metadata --format '{{artist}}|{{title}}|{{position}}|{{mpris:length}}|{{mpris:artUrl}}' 2>/dev/null)"

artist="$(echo "$meta" | cut -d'|' -f1)"
title="$(echo "$meta" | cut -d'|' -f2)"
pos="$(echo "$meta" | cut -d'|' -f3)"
len="$(echo "$meta" | cut -d'|' -f4)"
art="$(echo "$meta" | cut -d'|' -f5)"

if [ -n "$artist" ] && [ -n "$title" ]; then
    info="$artist - $title"
elif [ -n "$title" ]; then
    info="$title"
else
    info=""
fi
info=$(echo "$info" | cut -c1-40)

echo "$status|$info|$pos|$len|$art"
