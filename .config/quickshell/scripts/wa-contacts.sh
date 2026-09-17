#!/usr/bin/env bash
# Fetch WhatsApp chat list (contacts + groups) into the quickshell cache.
set -o pipefail
CACHE="$HOME/.cache/quickshell"
OUT="$CACHE/wa-chats.json"

command -v wacli >/dev/null 2>&1 || export PATH="$PATH:$HOME/go/bin"

mkdir -p "$CACHE" || exit 1
TMP="$(mktemp "$OUT.tmp.XXXXXX")" || exit 1
trap 'rm -f -- "$TMP"' EXIT

wacli --json chats list --limit 150 2>/dev/null \
    | jq -ce '{chats: (.data // [])}' > "$TMP" \
    && mv "$TMP" "$OUT"