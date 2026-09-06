#!/usr/bin/env bash

set -u

CACHE="$HOME/.cache/quickshell"
SERVED="$CACHE/ytx-home-served"
YTX_CONFIG="$HOME/.config/yt-x/config"

MAX_ITEMS="${YTX_HOME_MAX:-48}"
PAGE_SIZE="${YTX_HOME_PAGE_SIZE:-60}"
MAX_PAGES="${YTX_HOME_MAX_PAGES:-6}"
FRESH_SECS="${YTX_HOME_FRESH:-600}"
SERVED_CAP="${YTX_HOME_SERVED_CAP:-300}"
MAX_AGE="${YTX_HOME_MAX_AGE:-120}"
BROWSER="${YTX_BROWSER:-}"
MODE="${1:-feed}"
FORCE="${2:-}"

case "$MODE" in
    music) OUT="$CACHE/ytx-music.json"; PAGE_FILE="$CACHE/ytx-music-page" ;;
    *)     OUT="$CACHE/ytx-home.json";  PAGE_FILE="$CACHE/ytx-home-page" ;;
esac
TMP="$OUT.tmp"

mkdir -p "$CACHE"

NOW=$(date +%s)

if [ "$MODE" = "feed" ] && [ "$FORCE" != "force" ] && [ -f "$OUT" ]; then
    TS=$(jq -r '.ts // 0' "$OUT" 2>/dev/null)
    if [ -n "$TS" ] && [ "$TS" -gt 0 ] && [ $((NOW - TS)) -lt "$FRESH_SECS" ]; then
        exit 0
    fi
fi

[ -n "$BROWSER" ] || BROWSER=$(sed -n 's/^CONFIG_BROWSER="\([^"]*\)".*/\1/p' "$YTX_CONFIG" 2>/dev/null | head -n 1)

if [ ! -s "$SERVED" ]; then
    printf '[]\n' > "$SERVED"
fi
SERVED_JSON="$(cat "$SERVED" 2>/dev/null || printf '[]')"
case "$SERVED_JSON" in
    "" | "null") SERVED_JSON="[]" ;;
esac

PAGE=0
[ -f "$PAGE_FILE" ] && PAGE=$(cat "$PAGE_FILE" 2>/dev/null || printf '0')
case "$PAGE" in *[!0-9]*) PAGE=0 ;; esac
START=$((PAGE * PAGE_SIZE + 1))
END=$((START + PAGE_SIZE - 1))

RAW="$(yt-dlp "https://youtube.com/" \
    --flat-playlist --dump-single-json --no-warnings \
    --playlist-start "$START" --playlist-end "$END" \
    --extractor-args youtubetab:approximate_date \
    ${BROWSER:+--cookies-from-browser "$BROWSER"} 2>/dev/null)"

if [ -z "$RAW" ]; then
    printf '{"ts": %s}\n' "$(date +%s)" > "$TMP" && mv "$TMP" "$OUT"
    exit 0
fi

NEXT=$(( (PAGE + 1) % MAX_PAGES ))
printf '%s\n' "$NEXT" > "$PAGE_FILE"

printf '%s' "$RAW" | jq -c --argjson music "$([ "$MODE" = "music" ] && echo true || echo false)" \
    --argjson max "$MAX_ITEMS" --argjson served "$SERVED_JSON" \
    --argjson cap "$SERVED_CAP" --argjson max_age "$MAX_AGE" '
  [ (.entries // [])[]
    | select(.id != null and .url != null)
    | if $music then
          select((.id | test("^RD")) or (.title | startswith("Mix - ")))
      else
          select(.url | contains("/watch?v="))
          | select((.id | test("^(PL|RD|UU|VL|FL|LL|TL|OLAK5uy_)")) | not)
      end
    | select( if $max_age > 0 and (.timestamp // -1) > 0 then (now - .timestamp) / 86400 <= $max_age else true end )
    | { title: (.title // ""), url: .url, id: .id, channel: (.channel // .uploader // ""),
        duration: (.duration // 0), view_count: (.view_count // 0) } ] as $cand
  | ( $cand | map(select(.id as $i | ($served | index($i)) | not)) ) as $fresh
  | ( $cand | map(select(.id as $i | ($served | index($i)))) ) as $used
  | ( ($fresh + $used) | unique_by(.id) | .[0:$max] ) as $res
  | { ts: (now | floor),
      results: ($res | map({ title: .title, url: .url, id: .id, channel: .channel,
                             duration: .duration, view_count: .view_count })) }
' > "$TMP" 2>/dev/null

if [ -s "$TMP" ]; then
    mv "$TMP" "$OUT"
    NEW_IDS="$(jq -c '[.results[].id]' "$OUT" 2>/dev/null || echo '[]')"
    jq -c --argjson new "$NEW_IDS" --argjson cap "$SERVED_CAP" '
      . as $old | (($new + $old) | unique | .[0:$cap])
    ' "$SERVED" > "$SERVED.tmp" 2>/dev/null && mv "$SERVED.tmp" "$SERVED" || rm -f "$SERVED.tmp"
fi
rm -f "$TMP"