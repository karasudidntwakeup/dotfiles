#!/usr/bin/env bash

RECENT_JSON="$HOME/.config/yt-x/recent.json"
CACHE_DIR="$HOME/.cache/rofi-youtube"
THEME="$HOME/.config/rofi/youtube/theme.rasi"
MAX_ITEMS="${ROFI_YT_LIMIT:-36}"

mkdir -p "$CACHE_DIR"

[ -s "$RECENT_JSON" ] || { rofi -e "No yt-x history found at $RECENT_JSON"; exit 1; }

declare -A URLS

# url, id, title
mapfile -t ENTRIES < <(jq -r --argjson max "$MAX_ITEMS" \
  '.entries[:$max][] | [.url, .id, (.title | gsub("[\\n\\r\\t]"; " "))] | @tsv' "$RECENT_JSON")

MENU=""
for entry in "${ENTRIES[@]}"; do
    IFS=$'\t' read -r url id title <<<"$entry"
    [ -z "$id" ] || [ -z "$title" ] && continue
    URLS["$title"]="$url"

    thumb="$CACHE_DIR/$id.jpg"
    if [ ! -s "$thumb" ]; then
        curl -sfL --max-time 10 "https://i.ytimg.com/vi/${id}/mqdefault.jpg" -o "$thumb.part" \
            && mv "$thumb.part" "$thumb" &
    fi
done
wait

INDEX=0
for entry in "${ENTRIES[@]}"; do
    IFS=$'\t' read -r url id title <<<"$entry"
    thumb="$CACHE_DIR/$id.jpg"
    [ -s "$thumb" ] || thumb=""
    MENU+="${title}\0icon\x1f${thumb}\n"
    INDEX=$((INDEX + 1))
done

if [ -n "$ROFI_YT_DRYRUN" ]; then
    printf '%b' "$MENU"
    exit 0
fi

SELECTED=$(printf '%b' "$MENU" | rofi -dmenu -p "YouTube" -show-icons -theme "$THEME")
[ -z "$SELECTED" ] && exit 1

URL="${URLS[$SELECTED]}"
[ -z "$URL" ] && exit 1

setsid -f mpv --force-media-title="$SELECTED" "$URL" >/dev/null 2>&1
