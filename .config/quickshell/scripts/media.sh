#!/bin/sh
# Get currently playing media info via a single playerctl call.
# Output format: status|artist - title|pos|len|art
#
# The artist/title are free text and may contain "|" (common in YouTube
# titles). To keep the numeric fields reliable, they are emitted FIRST in the
# playerctl format (tab-delimited); the free text can then never shift them.
# Consumers should right-anchor the trailing pos|len|art fields.

player="$(playerctl -l 2>/dev/null | head -1)"
if [ -z "$player" ]; then
    echo "none||0|0|"
    exit 0
fi

status="$(playerctl -p "$player" status 2>/dev/null)"
[ -z "$status" ] && status="stopped"

# Numbers first (position/length in microseconds), text last. playerctl does not
# interpret "\t" in its format, so insert a literal tab.
TAB="$(printf '\t')"

meta="$(playerctl -p "$player" metadata --format "{{position}}${TAB}{{mpris:length}}${TAB}{{artist}}${TAB}{{title}}" 2>/dev/null)"

pos="$(printf '%s\n' "$meta" | cut -f1)"
len="$(printf '%s\n' "$meta" | cut -f2)"
text="$(printf '%s\n' "$meta" | cut -f3-)"
artist="$(printf '%s\n' "$text" | cut -f1)"
title="$(printf '%s\n' "$text" | cut -f2-)"

if [ -n "$artist" ] && [ -n "$title" ]; then
    info="$artist - $title"
elif [ -n "$title" ]; then
    info="$title"
else
    info=""
fi
info=$(echo "$info" | cut -c1-40)

echo "$status|$info|$pos|$len|"