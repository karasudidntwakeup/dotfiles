#!/usr/bin/env bash

set -u

CACHE="$HOME/.cache/quickshell"
OUT="$CACHE/ytx-home.json"
TMP="$OUT.tmp"
LINES="$OUT.lines"
RECENT="$HOME/.config/yt-x/recent.json"
MAX_CHANNELS="${YTX_HOME_CHANNELS:-6}"
PER_CHANNEL="${YTX_HOME_PER_CHANNEL:-8}"
MAX_ITEMS="${YTX_HOME_MAX:-48}"
FRESH_SECS="${YTX_HOME_FRESH:-600}"
FORCE="${1:-}"

mkdir -p "$CACHE"

NOW=$(date +%s)

if [ "$FORCE" != "force" ] && [ -f "$OUT" ]; then
    TS=$(jq -r '.ts // 0' "$OUT" 2>/dev/null)
    if [ -n "$TS" ] && [ "$TS" -gt 0 ] && [ $((NOW - TS)) -lt "$FRESH_SECS" ]; then
        exit 0
    fi
fi

rm -f "$LINES"
touch "$LINES"

jq -rn --argjson max "$MAX_CHANNELS" '
  [ (input.entries // [])[]? | select(.channel_id != null) | { id: .channel_id, name: (.channel // .uploader // "") } ]
  | unique_by(.id) | .[0:$max] | .[] | "\(.id)\t\(.name)"
' "$RECENT" 2>/dev/null | while IFS=$'\t' read -r cid name; do
    [ -z "$cid" ] && continue

    yt-dlp --flat-playlist --no-warnings --dump-single-json \
        "https://www.youtube.com/channel/${cid}/videos" 2>/dev/null \
        | jq -c --argjson per "$PER_CHANNEL" --arg cname "$name" \
            '[.entries[]?
              | select(.id != null and .url != null)
              | select((.id | test("^(PL|RD|UU|VL|FL|LL|TL|OLAK5uy_)")) | not)
              | { title: (.title // ""), url: .url, id: .id, channel: (.channel // .uploader // $cname) }]
              | .[0:$per]' >> "$LINES" 2>/dev/null || true
done

if [ ! -s "$LINES" ]; then
    printf '{"ts": %s, "results": []}\n' "$(date +%s)" > "$TMP" && mv "$TMP" "$OUT"
    rm -f "$LINES"
    exit 0
fi

jq -s --argjson max "$MAX_ITEMS" '
  def interleave:
    . as $l
    | (map(length) | max) as $m
    | [ range(0; $m) as $r | range(0; $l | length) as $c | $l[$c][$r]? | select(. != null) ];
  { ts: (now | floor), results: (interleave | unique_by(.id) | .[0:$max]) }
' "$LINES" > "$TMP" 2>/dev/null && mv "$TMP" "$OUT"
rm -f "$LINES"