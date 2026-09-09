#!/usr/bin/env bash
# Fetch WhatsApp chat list (contacts + groups) into the quickshell cache.
CACHE="$HOME/.cache/quickshell"
OUT="$CACHE/wa-chats.json"
TMP="$OUT.tmp"

command -v wacli >/dev/null 2>&1 || export PATH="$PATH:$HOME/go/bin"

mkdir -p "$CACHE"

wacli --json chats list --limit 150 2>/dev/null \
    | jq -c '{chats: (.data // [])}' > "$TMP" \
    && mv "$TMP" "$OUT"