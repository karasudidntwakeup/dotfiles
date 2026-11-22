#!/bin/sh
# Use a non-whitespace separator so empty metadata fields retain their slots.
separator="$(printf '\037')"
format="{{status}}${separator}{{position}}${separator}{{mpris:length}}${separator}{{artist}}${separator}{{title}}${separator}{{mpris:artUrl}}"
if ! metadata="$(playerctl metadata --format "$format" 2>/dev/null)"; then
    printf 'none%s0%s0%s%s%s\n' "$separator" "$separator" "$separator" "$separator" "$separator"
    exit 0
fi

metadata="$(printf '%s' "$metadata" | tr '\r\n' '  ')"
IFS="$separator" read -r status position length artist title art <<DATA
$metadata
DATA

case "$art" in
    http://*|https://*)
        case "$art" in
            https://i[1-9].ytimg.com/*) art="https://i.ytimg.com/${art#https://i?.ytimg.com/}" ;;
        esac
        art_dir="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/media"
        art_file="$art_dir/art-$(printf '%s' "$art" | md5sum | cut -c1-12).jpg"
        if [ ! -s "$art_file" ] && mkdir -p -- "$art_dir"; then
            if temp_file="$(mktemp "$art_dir/.art-XXXXXXXX")"; then
                if command -v curl >/dev/null 2>&1; then
                    curl -sfL --max-time 8 -o "$temp_file" -- "$art" || : > "$temp_file"
                elif command -v wget >/dev/null 2>&1; then
                    wget -q -T 8 -O "$temp_file" -- "$art" || : > "$temp_file"
                fi
                [ ! -s "$temp_file" ] || mv -f -- "$temp_file" "$art_file"
                rm -f -- "$temp_file"
            fi
        fi
        art=""
        [ ! -s "$art_file" ] || art="file://$art_file"
        ;;
esac

printf '%s%s%s%s%s%s%s%s%s%s%s\n' \
    "${status:-Stopped}" "$separator" "${position:-0}" "$separator" "${length:-0}" "$separator" \
    "$artist" "$separator" "$title" "$separator" "$art"
