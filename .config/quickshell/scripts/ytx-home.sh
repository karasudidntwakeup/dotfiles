#!/usr/bin/env bash

set -u

CACHE="$HOME/.cache/quickshell"
OUT="$CACHE/ytx-home.json"
TMP="$OUT.tmp"
LINES="$OUT.lines"
SERVED="$CACHE/ytx-home-served"
RECENT="$HOME/.config/yt-x/recent.json"
MAX_CHANNELS="${YTX_HOME_CHANNELS:-6}"
PER_CHANNEL="${YTX_HOME_PER_CHANNEL:-8}"
MAX_ITEMS="${YTX_HOME_MAX:-48}"
FRESH_SECS="${YTX_HOME_FRESH:-600}"
SERVED_CAP="${YTX_HOME_SERVED_CAP:-300}"
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

if [ ! -s "$SERVED" ]; then
    printf '[]\n' > "$SERVED"
fi
SERVED_JSON="$(cat "$SERVED" 2>/dev/null || printf '[]')"
case "$SERVED_JSON" in
    "" | "null") SERVED_JSON="[]" ;;
esac

jq -rn --argjson max "$MAX_CHANNELS" '
  [ (input.entries // [])[]? | select(.channel_id != null) | { id: .channel_id, name: (.channel // .uploader // "") } ]
  | unique_by(.id) | .[0:$max] | .[] | "\(.id)\t\(.name)"
' "$RECENT" 2>/dev/null | while IFS=$'\t' read -r cid name; do
    [ -z "$cid" ] && continue

    SEED="$RANDOM$RANDOM"

    yt-dlp --flat-playlist --no-warnings --dump-single-json \
        "https://www.youtube.com/channel/${cid}/videos" 2>/dev/null \
        | jq -c --argjson per "$PER_CHANNEL" --argjson served "$SERVED_JSON" \
              --argjson seed "$SEED" --arg cname "$name" '
            [ .entries[]?
              | select(.id != null and .url != null)
              | select((.id | test("^(PL|RD|UU|VL|FL|LL|TL|OLAK5uy_)")) | not)
              | { title: (.title // ""), url: .url, id: .id, channel: (.channel // .uploader // $cname) } ] as $all
          | ( $all | map(select(.id as $i | ($served | index($i)) | not)) ) as $fresh
          | ( $all | map(select(.id as $i | ($served | index($i)))) ) as $used
          | ( if ($fresh | length) >= $per
              then ( (($seed % (($fresh | length) - $per + 1))) as $s | $fresh[$s: ($s + $per)] )
              elif ( ($fresh | length) + ($used | length) ) <= $per
              then ( $fresh + $used )
              else ( ((($seed * 13) % ( (($used | length) - ($per - ($fresh | length))) + 1 ))) as $s
                      | ( $fresh + $used[$s: ($s + ($per - ($fresh | length)))] ) )
              end ) as $chosen
          | $chosen' >> "$LINES" 2>/dev/null || true
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
' "$LINES" > "$TMP" 2>/dev/null

if [ -s "$TMP" ]; then
    mv "$TMP" "$OUT"
    NEW_IDS="$(jq -c '[.results[].id]' "$OUT" 2>/dev/null || echo '[]')"
    jq -c --argjson new "$NEW_IDS" --argjson cap "$SERVED_CAP" '
      . as $old | (($new + $old) | unique | .[0:$cap])
    ' "$SERVED" > "$SERVED.tmp" 2>/dev/null && mv "$SERVED.tmp" "$SERVED" || rm -f "$SERVED.tmp"
fi
rm -f "$LINES"