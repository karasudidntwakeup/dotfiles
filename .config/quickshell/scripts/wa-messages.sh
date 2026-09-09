#!/usr/bin/env bash
# Fetch recent messages for a chat JID into the quickshell cache.
JID="$1"
CACHE="$HOME/.cache/quickshell"
OUT="$CACHE/wa-messages-$(printf '%s' "$JID" | tr -c 'A-Za-z0-9' '_').json"
TMP="$OUT.tmp"

command -v wacli >/dev/null 2>&1 || export PATH="$PATH:$HOME/go/bin"

mkdir -p "$CACHE"

wacli --json messages list --chat "$JID" --limit 100 2>/dev/null \
    | jq -c '{messages: (.data.messages // []), fts: (.data.fts // false)}' > "$TMP" \
    && mv "$TMP" "$OUT"