#!/usr/bin/env bash
set -u
umask 077

JID="${1:-}"

JID_RE='^([0-9]+@(s\.whatsapp\.net|lid)|[0-9]+(-[0-9]+)?@g\.us)$'
if ! [[ $JID =~ $JID_RE ]]; then
    echo "usage: wa-send-file.sh JID (JID: numeric@s.whatsapp.net|numeric@lid|numeric[-numeric]@g.us)" >&2
    exit 2
fi

command -v wacli >/dev/null 2>&1 || export PATH="$PATH:$HOME/go/bin"
command -v wacli >/dev/null 2>&1 || exit 1
command -v zenity >/dev/null 2>&1 || exit 1

LOG="$HOME/.cache/quickshell/wa-send-file.log"
log() {
    printf '%s %s\n' "$(date '+%F %T')" "$*" >>"$LOG" 2>/dev/null
    tail -n 50 "$LOG" >"$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG" 2>/dev/null
}
fail() {
    log "FAIL to=$JID :: $1"
    printf 'ERROR: %s\n' "$1"
    exit 1
}

# Classic GTK chooser: the xdg-desktop-portal file picker returns
# /run/.../doc paths that only the picker itself may open, so wacli
# could never read the chosen photo.
export GTK_USE_PORTAL=0

FILE="$(zenity --file-selection --title="Send to ${JID%%@*}" --ok-label=Send \
    --file-filter='Images | *.png *.jpg *.jpeg *.webp *.gif *.jfif' \
    --file-filter='All files | *.*' 2>/dev/null)"
status=$?
if [ "$status" -ne 0 ] || [ -z "$FILE" ]; then
    exit 2
fi

if [ ! -f "$FILE" ] || [ ! -r "$FILE" ] || [ ! -s "$FILE" ]; then
    fail "cannot read selected file"
fi

ERR="$(wacli send file --to "$JID" --file "$FILE" --post-send-wait 0 2>&1 >/dev/null)"
rc=$?
if [ "$rc" -ne 0 ]; then
    fail "${ERR:-wacli exited $rc}"
fi
log "OK to=$JID file=$FILE"
exit 0
