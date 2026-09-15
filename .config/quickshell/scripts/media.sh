#!/bin/sh
# Get currently playing media info via a single playerctl call.
# Output format: status|artist␞title|pos|len|art
#
# The artist/title are free text and may contain "|" (common in YouTube
# titles). To keep the numeric fields reliable, they are emitted FIRST in the
# playerctl format (tab-delimited); the free text can then never shift them.
# Consumers should right-anchor the trailing pos|len|art fields.
#
# Artist and title are joined with the ASCII Record Separator byte (0x1E) so
# they also survive literal "|" characters; the consumer splits on 0x1E.

player="$(playerctl -l 2>/dev/null | head -1)"
if [ -z "$player" ]; then
    echo "none|␞|0|0|"
    exit 0
fi

status="$(playerctl -p "$player" status 2>/dev/null)"
[ -z "$status" ] && status="stopped"

# Numbers and art first (position/length in microseconds), text last.
# playerctl does not interpret "\t" in its format, so insert a literal tab.
TAB="$(printf '\t')"
RS="$(printf '\036')"

meta="$(playerctl -p "$player" metadata --format "{{position}}${TAB}{{mpris:length}}${TAB}{{artist}}${TAB}{{title}}${TAB}{{mpris:artUrl}}" 2>/dev/null)"

IFS="$TAB" read -r pos len artist title art <<EOF
$meta
EOF

artist=$(printf '%s' "$artist" | cut -c1-32)
title=$(printf '%s' "$title" | cut -c1-44)

# Album art: prefer a local file thumbnail so QML never has to load over the
# network itself. Downloads http(s) art once per URL into a cache dir and
# returns a file:// path; empty art stays empty (UI falls back to a glyph).
artdir="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/media"
artfile=""
if [ -n "$art" ]; then
    case "$art" in
        file://*)
            artfile="$art"
            ;;
http://*|https://*)
                # YouTube thumbnail mirrors (i1.i2.i3.ytimg.com) can resolve to
                # null addresses on some machines; canonical i.ytimg.com serves
                # the same image.
                case "$art" in
                    https://i[1-9].ytimg.com/*) art="https://i.ytimg.com/${art#https://i?.ytimg.com/}" ;;
                esac
                artfile="$artdir/art-$(printf '%s' "$art" | md5sum | cut -c1-12).jpg"
            if [ ! -f "$artfile" ]; then
                mkdir -p "$artdir" 2>/dev/null
                if command -v curl >/dev/null 2>&1; then
                    curl -sfL --max-time 8 -o "$artfile".tmp "$art" && mv "$artfile".tmp "$artfile"
                elif command -v wget >/dev/null 2>&1; then
                    wget -q -T 8 -O "$artfile".tmp "$art" && mv "$artfile".tmp "$artfile"
                fi
                [ -f "$artfile" ] || rm -f "$artfile".tmp
            fi
            [ -f "$artfile" ] && artfile="file://$artfile"
            ;;
        *)
            artfile="$art"
            ;;
    esac
fi

if [ -n "$artist" ] && [ -n "$title" ]; then
    info="${artist}${RS}${title}"
elif [ -n "$title" ]; then
    info="${RS}${title}"
else
    info="${RS}"
fi

echo "$status|$info|$pos|$len|$artfile"