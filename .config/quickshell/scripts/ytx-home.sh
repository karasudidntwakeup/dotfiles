#!/usr/bin/env bash
set -uo pipefail

CACHE="$HOME/.cache/quickshell"
SERVED_FILE="$CACHE/ytx-home-served"
PLAYS_DIR="$CACHE/ytx-music-playlists"
YTX_CONFIG="$HOME/.config/yt-x/config"

MAX_ITEMS="${YTX_HOME_MAX:-48}"
PAGE_SIZE="${YTX_HOME_PAGE_SIZE:-60}"
MAX_PAGES="${YTX_HOME_MAX_PAGES:-6}"
FRESH_SECS="${YTX_HOME_FRESH:-3600}"
SERVED_CAP="${YTX_HOME_SERVED_CAP:-300}"
MAX_AGE="${YTX_HOME_MAX_AGE:-120}"
BROWSER="${YTX_BROWSER:-}"
MODE="${1:-feed}"
FORCE="${2:-}"

case "$MODE" in
    music)
        OUT="$CACHE/ytx-music.json"
        PAGE_FILE="$CACHE/ytx-music-page"
        FEED_FLAG=music
        TARGET="${YTX_HOME_MUSIC_MAX:-24}"
        ;;
    feed | *)
        OUT="$CACHE/ytx-home.json"
        PAGE_FILE="$CACHE/ytx-home-page"
        FEED_FLAG=feed
        ;;
esac

TMP="$OUT.tmp"
CAND="$TMP.candidates"
RESOLVED="$TMP.resolved"
mkdir -p "$CACHE"
trap 'rm -f "$TMP" "$CAND" "$RESOLVED" "$SERVED_FILE.tmp"' EXIT

NOW=$(date +%s)

if [ -z "$BROWSER" ]; then
    BROWSER=$(sed -n 's/^CONFIG_BROWSER="\([^"]*\)".*/\1/p' "$YTX_CONFIG" 2>/dev/null | head -n 1)
fi

SERVED_JSON="$(cat "$SERVED_FILE" 2>/dev/null || printf '[]')"
printf '%s' "$SERVED_JSON" | jq -e 'type == "array"' >/dev/null 2>&1 || SERVED_JSON='[]'
printf '%s\n' "$SERVED_JSON" > "$SERVED_FILE"

read_page() {
    local f=$1 p=0
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

CANDIDATE_JQ='
    (.entries // [])[]
    | select(.id != null and .url != null)
    | select(if $max_age > 0 and (.timestamp // -1) > 0 then (now - .timestamp) / 86400 <= $max_age else true end)
    | { title: (.title // ""), url: .url, id: .id,
        channel: (.channel // .uploader // ""),
        duration: (.duration // 0), view_count: (.view_count // 0),
        ts: (.timestamp // 0) }
'

fetch_candidates() {
    local start=$1 end=$2 mode=$3 raw
    raw="$(fetch_page "$start" "$end")" || return 1
    if [ "$mode" = music ]; then
        printf '%s' "$raw" | jq -c --argjson max_age "$MAX_AGE" '
            (.entries // [])[]
            | select(.id != null and .url != null)
            | select((.id | test("^RD")) or (.title // "" | startswith("Mix - ")))
            | select(if $max_age > 0 and (.timestamp // -1) > 0 then (now - .timestamp) / 86400 <= $max_age else true end)
            | { title: (.title // ""), url: .url, id: .id,
                channel: (.channel // .uploader // ""),
                duration: (.duration // 0), view_count: (.view_count // 0),
                ts: (.timestamp // 0) }
        ' 2>/dev/null >> "$CAND"
    else
        printf '%s' "$raw" | jq -c --argjson max_age "$MAX_AGE" '
            (.entries // [])[]
            | select(.id != null and .url != null)
            | select(.url | contains("/watch?v="))
            | select((.id | test("^(PL|RD|UU|VL|FL|LL|TL|OLAK5uy_)")) | not)
            | select(if $max_age > 0 and (.timestamp // -1) > 0 then (now - .timestamp) / 86400 <= $max_age else true end)
            | { title: (.title // ""), url: .url, id: .id,
                channel: (.channel // .uploader // ""),
                duration: (.duration // 0), view_count: (.view_count // 0),
                ts: (.timestamp // 0) }
        ' 2>/dev/null >> "$CAND"
    fi
}

assemble_results() {
    jq -s --argjson max "$MAX_ITEMS" --argjson served "$SERVED_JSON" '
        . as $cand
        | ( $cand | sort_by(-(.ts // 0)) ) as $sorted
        | ( $sorted | map(select(.id as $i | ($served | index($i)) | not)) ) as $fresh
        | ( $sorted | map(select(.id as $i | ($served | index($i)))) ) as $used
        | { ts: (now | floor),
            results: (($fresh + $used) | unique_by(.id) | .[0:$max] | map(del(.ts))) }
    ' "$CAND" 2>/dev/null
}

resolve_mix() {
    local id=$1 title=$2 dir=$3 base url playlist first
    base="${id#RD}"
    url="https://www.youtube.com/watch?v=${base}&list=${id}"
    playlist="$dir/$id.m3u"
    if ! timeout 40 yt-dlp --flat-playlist --no-warnings --playlist-end 25 --get-id "$url" \
        ${BROWSER:+--cookies-from-browser "$BROWSER"} 2>/dev/null \
        | grep -Ex '[A-Za-z0-9_-]{11}' \
        | sed 's#^#https://www.youtube.com/watch?v=#' > "$playlist"; then
        return 1
    fi
    [ -s "$playlist" ] || return 1
    first="$(sed -n 's#.*v=\([A-Za-z0-9_-]\{11\}\)$#\1#p' "$playlist" | head -n 1)"
    [ -n "$first" ] || return 1
    jq -nc --arg title "$title" --arg url "$playlist" --arg id "$first" \
        --argjson duration -1 --argjson view_count -1 \
        '{title:$title, url:$url, id:$id, channel:"", duration:$duration, view_count:$view_count, mix:true}'
}

resolve_candidates() {
    local c id title out
    while IFS= read -r c; do
        [ -n "$c" ] || continue
        id="$(printf '%s' "$c" | jq -r '.id // ""')"
        title="$(printf '%s' "$c" | jq -r '.title // ""')"
        out="$c"
        if [[ "$id" == RD* ]] && ! [[ "$id" =~ ^RD[A-Za-z0-9_-]{11}$ ]]; then
            out="$(resolve_mix "$id" "$title" "$PLAYS_DIR")" || continue
        fi
        printf '%s\n' "$out"
    done < "$1"
}

publish() {
    local new_ids
    [ -s "$TMP" ] || return 0
    mv "$TMP" "$OUT"
    new_ids="$(jq -c '[.results[].id // empty]' "$OUT" 2>/dev/null || printf '[]')"
    case "$new_ids" in "" | null) new_ids='[]' ;; esac
    jq -c --argjson new "$new_ids" --argjson cap "$SERVED_CAP" \
        '. as $old | (($new + $old) | unique | .[0:$cap])' "$SERVED_FILE" \
        > "$SERVED_FILE.tmp" 2>/dev/null && mv "$SERVED_FILE.tmp" "$SERVED_FILE" \
        || rm -f "$SERVED_FILE.tmp"
}

publish_ts_only() {
    if [ -s "$OUT" ]; then
        jq -c --argjson ts "$NOW" '.ts = $ts' "$OUT" > "$TMP" 2>/dev/null && mv "$TMP" "$OUT"
    else
        printf '{"ts": %s, "results": []}\n' "$NOW" > "$TMP" && mv "$TMP" "$OUT"
    fi
    exit 0
}

cache_fresh() {
    [ "$MODE" = feed ] && [ "$FORCE" != force ] || return 1
    [ -f "$OUT" ] || return 1
    local ts
    ts="$(jq -r '.ts // 0' "$OUT" 2>/dev/null || printf '0')"
    [ "$ts" -gt 0 ] && [ $((NOW - ts)) -lt "$FRESH_SECS" ]
}

if cache_fresh; then
    exit 0
fi

if [ "$MODE" = music ]; then
    : > "$CAND"
    page="$(read_page "$PAGE_FILE")"
    scanned=0
    while [ "$scanned" -lt "$MAX_PAGES" ]; do
        start=$((page * PAGE_SIZE + 1))
        end=$((start + PAGE_SIZE - 1))
        if ! fetch_candidates "$start" "$end" music; then
            break
        fi
        scanned=$((scanned + 1))
        if [ "$(wc -l < "$CAND")" -ge "$TARGET" ]; then
            break
        fi
        page=$(( (page + 1) % MAX_PAGES ))
    done
    printf '%s\n' "$(( (page + 1) % MAX_PAGES ))" > "$PAGE_FILE"

    [ -s "$CAND" ] || publish_ts_only

    rm -rf "$PLAYS_DIR"
    mkdir -p "$PLAYS_DIR"
    resolve_candidates "$CAND" > "$RESOLVED"
    mv "$RESOLVED" "$CAND"

    [ -s "$CAND" ] || publish_ts_only
    assemble_results > "$TMP"
    publish
    exit 0
fi

page="$(read_page "$PAGE_FILE")"
start=$((page * PAGE_SIZE + 1))
end=$((start + PAGE_SIZE - 1))
if fetch_candidates "$start" "$end" feed && [ -s "$CAND" ]; then
    printf '%s\n' "$(( (page + 1) % MAX_PAGES ))" > "$PAGE_FILE"
    assemble_results > "$TMP"
    publish
else
    publish_ts_only
fi
exit 0