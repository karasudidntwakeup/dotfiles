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

FILE="$(zenity --file-selection --title="Send to ${JID%%@*}" --ok-label=Send \
    --file-filter='Images | *.png *.jpg *.jpeg *.webp *.gif *.jfif' \
    --file-filter='All files | *.*' 2>/dev/null)"
status=$?
if [ "$status" -ne 0 ] || [ -z "$FILE" ]; then
    exit 2
fi

if [ ! -f "$FILE" ] || [ ! -r "$FILE" ] || [ ! -s "$FILE" ]; then
    echo "cannot read selected file" >&2
    exit 1
fi

exec wacli send file --to "$JID" --file "$FILE" --post-send-wait 0 >/dev/null 2>&1
