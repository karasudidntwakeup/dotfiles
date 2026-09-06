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

read_page() {
    local f="$1" p=0
    [ -f "$f" ] && p=$(cat "$f" 2>/dev/null || printf '0')
    case "$p" in *[!0-9]*) p=0 ;; esac
    printf '%s\n' "$p"
}

fetch_page() {
    local start=$1 end=$2
    yt-dlp "https://youtube.com/" \
        --flat-playlist --dump-single-json --no-warnings \
        --playlist-start "$start" --playlist-end "$end" \
        --extractor-args youtubetab:approximate_date \
        ${BROWSER:+--cookies-from-browser "$BROWSER"} 2>/dev/null
}

if [ "$MODE" = "music" ]; then
    PAGE="$(read_page "$PAGE_FILE")"
    TARGET="${YTX_HOME_MUSIC_MAX:-24}"
    : > "$TMP.cand"
    SCAN_PAGE="$PAGE"
    SCANNED=0
    while [ "$SCANNED" -lt "$MAX_PAGES" ]; do
        START=$((SCAN_PAGE * PAGE_SIZE + 1))
        END=$((START + PAGE_SIZE - 1))
        RAW="$(fetch_page "$START" "$END")"
        if [ -z "$RAW" ]; then
            break
        fi
        printf '%s' "$RAW" | jq -c --argjson max_age "$MAX_AGE" '
          (.entries // [])[]
          | select(.id != null and .url != null)
          | select((.id | test("^RD")) or (.title | startswith("Mix - ")))
          | select( if $max_age > 0 and (.timestamp // -1) > 0 then (now - .timestamp) / 86400 <= $max_age else true end )
          | { title: (.title // ""), url: .url, id: .id, channel: (.channel // .uploader // ""),
              duration: (.duration // 0), view_count: (.view_count // 0) }
        ' >> "$TMP.cand" 2>/dev/null
        SCANNED=$((SCANNED + 1))
        if [ "$(wc -l < "$TMP.cand" 2>/dev/null || printf 0)" -ge "$TARGET" ]; then
            break
        fi
        SCAN_PAGE=$(( (SCAN_PAGE + 1) % MAX_PAGES ))
    done
    printf '%s\n' "$(( (SCAN_PAGE + 1) % MAX_PAGES ))" > "$PAGE_FILE"

    if [ -s "$TMP.cand" ]; then
        PLAYS_DIR="$CACHE/ytx-music-playlists"
        rm -rf "$PLAYS_DIR"
        mkdir -p "$PLAYS_DIR"
        : > "$TMP.results"

        resolve_pseudo() {
        local id="$1" title="$2" base url P first
        base="${id#RD}"
        url="https://www.youtube.com/watch?v=${base}&list=${id}"
        P="$PLAYS_DIR/$id.m3u"
        timeout 40 yt-dlp --flat-playlist --no-warnings --playlist-end 25 --get-id "$url" \
            ${BROWSER:+--cookies-from-browser "$BROWSER"} 2>/dev/null \
            | grep -Ex '[A-Za-z0-9_-]{11}' | sed 's#^#https://www.youtube.com/watch?v=#' > "$P" || return 1
        [ -s "$P" ] || return 1
        first="$(sed -n 's#.*v=\([A-Za-z0-9_-]\{11\}\)$#\1#p' "$P" | head -n 1)"
        [ -n "$first" ] || return 1
        jq -nc --arg title "$title" --arg url "$P" --arg id "$first" \
            --argjson duration -1 --argjson view_count -1 \
            '{title:$title, url:$url, id:$id, channel:"", duration:$duration, view_count:$view_count, mix:true}'
    }

    while IFS= read -r c; do
        [ -n "$c" ] || continue
        id="$(printf '%s' "$c" | jq -r '.id // ""')"
        title="$(printf '%s' "$c" | jq -r '.title // ""')"
        out="$c"
        if [[ "$id" == RD* ]] && ! [[ "$id" =~ ^RD[A-Za-z0-9_-]{11}$ ]]; then
            out="$(resolve_pseudo "$id" "$title")"
        elif ! [[ "$id" == RD* ]]; then
            out="$(printf '%s' "$c" | jq -c '{title, url, id, channel, duration, view_count}')"
        fi
        [ -n "$out" ] || continue
        printf '%s\n' "$out" >> "$TMP.results"
    done < <(cat "$TMP.cand" 2>/dev/null)

    ENTS="$(jq -s '.' "$TMP.results" 2>/dev/null || printf '[]')"
    printf '%s' "$ENTS" | jq -c --argjson max "$MAX_ITEMS" --argjson served "$SERVED_JSON" \
        --argjson cap "$SERVED_CAP" '
      . as $entries
      | [ $entries[] | select(.id as $i | ($served | index($i)) | not) ] as $fresh
      | [ $entries[] | select(.id as $i | ($served | index($i))) ] as $used
      | { ts: (now | floor), results: (($fresh + $used) | unique_by(.id) | .[0:$max]) }
    ' > "$TMP" 2>/dev/null

    rm -f "$TMP.cand" "$TMP.results"
    else
        printf '{"ts": %s}\n' "$(date +%s)" > "$TMP" && mv "$TMP" "$OUT"
        rm -f "$TMP.cand" "$TMP.results"
        exit 0
    fi
else
    PAGE="$(read_page "$PAGE_FILE")"
    START=$((PAGE * PAGE_SIZE + 1))
    END=$((START + PAGE_SIZE - 1))
    RAW="$(fetch_page "$START" "$END")"

    if [ -z "$RAW" ]; then
        printf '{"ts": %s}\n' "$(date +%s)" > "$TMP" && mv "$TMP" "$OUT"
        exit 0
    fi

    NEXT=$(( (PAGE + 1) % MAX_PAGES ))
    printf '%s\n' "$NEXT" > "$PAGE_FILE"

    printf '%s' "$RAW" | jq -c --argjson max "$MAX_ITEMS" --argjson served "$SERVED_JSON" \
        --argjson cap "$SERVED_CAP" --argjson max_age "$MAX_AGE" '
      [ (.entries // [])[]
        | select(.id != null and .url != null)
        | select(.url | contains("/watch?v="))
        | select((.id | test("^(PL|RD|UU|VL|FL|LL|TL|OLAK5uy_)")) | not)
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
fi

if [ -s "$TMP" ]; then
    mv "$TMP" "$OUT"
    NEW_IDS="$(jq -c '[.results[].id]' "$OUT" 2>/dev/null || echo '[]')"
    jq -c --argjson new "$NEW_IDS" --argjson cap "$SERVED_CAP" '
      . as $old | (($new + $old) | unique | .[0:$cap])
    ' "$SERVED" > "$SERVED.tmp" 2>/dev/null && mv "$SERVED.tmp" "$SERVED" || rm -f "$SERVED.tmp"
fi
rm -f "$TMP"