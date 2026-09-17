#!/usr/bin/env bash
set -u
umask 077

JID="${1:-}"
TEXT="${2-}"

JID_RE='^([0-9]+@(s\.whatsapp\.net|lid)|[0-9]+(-[0-9]+)?@g\.us)$'
if ! [[ $JID =~ $JID_RE ]]; then
    echo "usage: wa-send.sh JID TEXT (JID: numeric@s.whatsapp.net|numeric@lid|numeric[-numeric]@g.us)" >&2
    exit 2
fi

command -v wacli >/dev/null 2>&1 || export PATH="$PATH:$HOME/go/bin"
command -v wacli >/dev/null 2>&1 || exit 1

exec wacli send text --to "$JID" --message "$TEXT" --post-send-wait 0 >/dev/null 2>&1
