#!/usr/bin/env bash
# Fill missing upload timestamps in a ytx JSON file (ytx-home.json / ytx-results.json).
# Flat-playlist entries from YouTube have timestamp == null, so we fetch each
# missing video once and merge the result back. The launcher watches the file
# and refreshes automatically.
#
# Kept deliberately polite: max 2 parallel fetches, niced, with timeouts, so
# this never freezes the desktop. Tune with YTX_ENRICH_JOBS (0 = disable)
# and YTX_ENRICH_MAX.
set -uo pipefail

OUT="${1:-}"
[[ -n "$OUT" && -s "$OUT" ]] || exit 0
command -v jq >/dev/null 2>&1 || exit 0
command -v yt-dlp >/dev/null 2>&1 || exit 0
command -v xargs >/dev/null 2>&1 || exit 0

JOBS="${YTX_ENRICH_JOBS:-2}"
[[ "$JOBS" =~ ^[0-9]+$ ]] || JOBS=2
[[ "$JOBS" == "0" ]] && exit 0
(( JOBS >= 1 && JOBS <= 4 )) || JOBS=2

MAX="${YTX_ENRICH_MAX:-24}"
[[ "$MAX" =~ ^[0-9]+$ ]] || MAX=24
(( MAX >= 1 && MAX <= 48 )) || MAX=24

LOCK="$OUT.enrich.lock"
exec 8> "$LOCK" 2>/dev/null || exit 0
flock -n 8 || exit 0

# Collect ids with missing timestamp (cap to avoid hammering).
mapfile -t IDS < <(jq -r '.results[]? | select(.timestamp == null) | select(.id != null) | .id' "$OUT" 2>/dev/null | head -n "$MAX")
(( ${#IDS[@]} > 0 )) || exit 0

TSV="$(mktemp "${OUT}.enrich.XXXXXX")"
trap 'rm -f -- "$TSV"' EXIT

# Per-video lookup: id;timestamp;upload_date. Slow (~2-5s each) so only
# $JOBS run at once, niced to idle priority; failures print NA and are
# ignored on merge.
printf '%s\n' "${IDS[@]}" | timeout 240 xargs -P "$JOBS" -I{} \
    nice -n 10 yt-dlp --no-warnings --no-playlist --skip-download \
        --socket-timeout 15 --retries 1 \
        --print "%(id)s;%(timestamp)s;%(upload_date)s" \
        "https://www.youtube.com/watch?v={}" 2>/dev/null > "$TSV" || true
[[ -s "$TSV" ]] || exit 0

MERGED="$(mktemp "${OUT}.merged.XXXXXX")"
trap 'rm -f -- "$TSV" "$MERGED"' EXIT

# Build {id: timestamp} map; prefer timestamp, fall back to upload_date
# (YYYYMMDD -> epoch via strptime). NA / null entries are dropped.
jq -Rs --slurpfile data "$OUT" '
    (split("\n")
     | map(select(length > 0) | split(";"))
     | map(select(length >= 2))
     | reduce .[] as $row ({};
         ($row[0]) as $id
         | ($row[1] // "NA") as $ts
         | ($row[2] // "NA") as $ud
         | if ($ts | test("^[0-9]{9,10}$")) then .[$id] = ($ts | tonumber)
           elif ($ud | test("^[0-9]{8}$")) then
               (try ((($ud) | strptime("%Y%m%d") | mktime)) catch null) as $t
               | if ($t | type) == "number" then .[$id] = $t else . end
           else . end
       )
    ) as $tsmap
    | $data[0]
    | .results |= map(
        if (.timestamp | type) == "number" and .timestamp > 0 then .
        elif ($tsmap[.id] | type) == "number" then .timestamp = $tsmap[.id]
        else . end
      )
' "$TSV" > "$MERGED" 2>/dev/null || exit 0

# Only replace if we actually filled something and output is valid.
if jq -e '.results | type == "array" and length > 0' "$MERGED" >/dev/null 2>&1; then
    before=$(jq '[.results[] | select(.timestamp != null)] | length' "$OUT" 2>/dev/null || echo 0)
    after=$(jq '[.results[] | select(.timestamp != null)] | length' "$MERGED" 2>/dev/null || echo 0)
    if [[ "$after" =~ ^[0-9]+$ && "$before" =~ ^[0-9]+$ ]] && (( after > before )); then
        cat -- "$MERGED" > "$OUT.tmp.enrich" 2>/dev/null && mv -- "$OUT.tmp.enrich" "$OUT"
    fi
fi
