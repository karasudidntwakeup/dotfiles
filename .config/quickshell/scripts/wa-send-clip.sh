#!/usr/bin/env bash
# Send the photo currently in the clipboard via wacli.
# Accepts image data (screenshot/app copy) or a copied image file
# (file-manager copy arrives as text/uri-list, not pixels).
set -uo pipefail
umask 077

JID="${1:-}"
JID_RE='^([0-9]+@(s\.whatsapp\.net|lid)|[0-9]+(-[0-9]+)?@g\.us)$'
if ! [[ $JID =~ $JID_RE ]]; then
    echo "usage: wa-send-clip.sh JID" >&2
    exit 2
fi

command -v wacli >/dev/null 2>&1 || export PATH="$PATH:$HOME/go/bin"
command -v wacli >/dev/null 2>&1 || { echo "wacli missing"; exit 1; }

fail() {
    printf '%s\n' "$1"
    exit 1
}

TMPIMG="$(mktemp "${TMPDIR:-/tmp}/wa-clip-XXXXXX.png")" || exit 1
trap 'rm -f -- "$TMPIMG"' EXIT

FILE=""
if wl-paste --type image --no-newline >"$TMPIMG" 2>/dev/null && [ -s "$TMPIMG" ]; then
    FILE="$TMPIMG"
else
    # File copy: first file:// URI or absolute path on the clipboard.
    CAND="$(wl-paste --no-newline 2>/dev/null | head -c 4096 | grep -m1 -E '^(file://|/)' | tr -d '\r')"
    case "$CAND" in
        file://*) CAND="$(python3 -c 'import sys,urllib.parse; print(urllib.parse.unquote(sys.argv[1][7:]))' "$CAND" 2>/dev/null)" ;;
    esac
    case "$CAND" in
        *.png|*.PNG|*.jpg|*.JPG|*.jpeg|*.JPEG|*.webp|*.WEBP|*.gif|*.GIF|*.jfif|*.JFIF)
            if [ -f "$CAND" ] && [ -r "$CAND" ] && [ -s "$CAND" ]; then
                FILE="$CAND"
            fi
            ;;
    esac
    [ -n "$FILE" ] || fail "No photo in clipboard"
fi

ERR="$(wacli send file --to "$JID" --file "$FILE" --post-send-wait 0 2>&1 >/dev/null)"
rc=$?
[ "$rc" -ne 0 ] && fail "${ERR:-send failed (rc=$rc)}"
exit 0
