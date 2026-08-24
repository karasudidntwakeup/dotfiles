#!/bin/sh

HYPRLOCK="$HOME/.config/hypr/hyprlock.conf"
VARS="$HOME/.cache/matugen/hyprlock-vars.conf"

[ -f "$VARS" ] || exit 0

awk -v vars="$VARS" '
    /# MATUGEN-START/ {
        print
        while ((getline line < vars) > 0) print line
        close(vars)
        skip = 1
        next
    }
    /# MATUGEN-END/ { skip = 0 }
    !skip { print }
' "$HYPRLOCK" > "$HYPRLOCK.tmp" && mv "$HYPRLOCK.tmp" "$HYPRLOCK"
