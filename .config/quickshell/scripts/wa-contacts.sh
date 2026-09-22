#!/usr/bin/env bash
set -o pipefail
umask 077

CACHE="$HOME/.cache/quickshell"
OUT="$CACHE/wa-chats.json"

command -v wacli >/dev/null 2>&1 || export PATH="$PATH:$HOME/go/bin"
command -v wacli >/dev/null 2>&1 || exit 1
command -v jq >/dev/null 2>&1 || exit 1

mkdir -p "$CACHE" || exit 1
TMP="$(mktemp "$OUT.tmp.XXXXXX")" || exit 1
trap 'rm -f -- "$TMP"' EXIT

chmod 600 "$TMP" 2>/dev/null

wacli --read-only --json chats list --limit 150 2>/dev/null \
    | jq -ce '{chats: (.data // [])}' >"$TMP" \
    && chmod 600 "$TMP" && mv "$TMP" "$OUT"
