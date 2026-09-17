#!/usr/bin/env bash
# Send the image currently in the clipboard (if any) via wacli.
set -euo pipefail
JID="$1"
command -v wacli >/dev/null 2>&1 || export PATH="$PATH:$HOME/go/bin"

IMG="$(mktemp "${TMPDIR:-/tmp}/wa-clip-XXXXXX.png")" || exit 1
trap 'rm -f -- "$IMG"' EXIT
if ! wl-paste --type image --no-newline >"$IMG" 2>/dev/null || [ ! -s "$IMG" ]; then
    rm -f "$IMG"
    exit 1 # nothing image-like in the clipboard
fi

wacli send file --to "$JID" --file "$IMG"
rc=$?
rm -f "$IMG"
exit $rc