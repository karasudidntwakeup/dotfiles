#!/usr/bin/env bash

set -o pipefail
QUERY="$1"
COUNT="${YTX_SEARCH_COUNT:-24}"
CACHE="$HOME/.cache/quickshell"
OUT="$CACHE/ytx-results.json"

mkdir -p "$CACHE" || exit 1
TMP="$(mktemp "$OUT.tmp.XXXXXX")" || exit 1
trap 'rm -f -- "$TMP"' EXIT

yt-dlp --flat-playlist --no-warnings --dump-single-json "ytsearch${COUNT}:${QUERY}" 2>/dev/null \
    | jq -ce '{results: [.entries[] | select(.id != null) | {title: (.title // ""), url: (.url // ""), id: .id, channel: (.channel // .uploader // "")}]}' > "$TMP" \
    && mv "$TMP" "$OUT"