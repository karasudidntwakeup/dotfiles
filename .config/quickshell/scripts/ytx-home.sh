#!/usr/bin/env bash
set -euo pipefail

CACHE="$HOME/.cache/quickshell"
OUT="$CACHE/ytx-home.json"
YTX_CONFIG="$HOME/.config/yt-x/config"
MAX_ITEMS="${YTX_HOME_MAX:-48}"
PAGE_SIZE="${YTX_HOME_PAGE_SIZE:-60}"
FRESH_SECS="${YTX_HOME_FRESH:-300}"
BROWSER="${YTX_BROWSER:-}"
FORCE="${2:-${1:-}}"

for value in "$MAX_ITEMS" "$PAGE_SIZE" "$FRESH_SECS"; do
    [[ "$value" =~ ^(0|[1-9][0-9]{0,5})$ ]] || exit 1
done
(( MAX_ITEMS > 0 && PAGE_SIZE > 0 )) || exit 1

mkdir -p "$CACHE"
exec 9> "$CACHE/ytx-home.lock"
flock -w 95 9 || exit 1

if [[ "$FORCE" != force && -s "$OUT" ]] && jq -e --argjson fresh "$FRESH_SECS" '
    (.results | type == "array" and length > 0)
    and (.ts | type == "number")
    and (now - .ts >= 0 and now - .ts < $fresh)
' "$OUT" >/dev/null 2>&1; then
    exit 0
fi

if [[ -z "$BROWSER" && -r "$YTX_CONFIG" ]]; then
    while IFS= read -r line; do
        if [[ "$line" =~ ^CONFIG_BROWSER=\"([^\"]*)\" ]]; then
            BROWSER="${BASH_REMATCH[1]}"
            break
        fi
    done < "$YTX_CONFIG"
fi

args=(--ignore-config --flat-playlist --dump-single-json --no-warnings
    --playlist-start 1 --playlist-end "$PAGE_SIZE" --socket-timeout 15 --retries 1)
if [[ -n "$BROWSER" ]]; then
    args+=(--cookies-from-browser "$BROWSER")
fi

TMP="$(mktemp "$OUT.tmp.XXXXXX")"
trap 'rm -f -- "$TMP"' EXIT

timeout 90 yt-dlp "${args[@]}" "https://youtube.com/" 2>/dev/null |
    jq -ce --argjson max "$MAX_ITEMS" '
        reduce ((.entries // [])[]
            | select((.id | type) == "string" and (.url | type) == "string")
            | select(.id | test("^[A-Za-z0-9_-]{11}$"))
            | select(.url | test("^https://(www\\.)?youtube\\.com/(watch\\?|shorts/|live/)"))
        ) as $entry ({seen: {}, results: []};
            if .seen[$entry.id] or (.results | length) >= $max then .
            else
                .seen[$entry.id] = true
                | .results += [{
                    title: ($entry.title // ""), url: $entry.url, id: $entry.id,
                    channel: ($entry.channel // $entry.uploader // ""),
                    duration: ($entry.duration // 0), view_count: ($entry.view_count // 0)
                }]
            end)
        | select(.results | length > 0)
        | {ts: (now | floor), results: .results}
    ' > "$TMP"

mv -- "$TMP" "$OUT"
