#!/usr/bin/env bash

QUERY="$1"
COUNT="${YTX_SEARCH_COUNT:-24}"
CACHE="$HOME/.cache/quickshell"
OUT="$CACHE/ytx-results.json"
TMP="$OUT.tmp"

mkdir -p "$CACHE"

yt-dlp --flat-playlist --no-warnings --dump-single-json "ytsearch${COUNT}:${QUERY}" 2>/dev/null \
    | jq -c '{results: [.entries[] | select(.id != null) | {title: (.title // ""), url: (.url // ""), id: .id, channel: (.channel // .uploader // "")}]}' > "$TMP" \
    && mv "$TMP" "$OUT"