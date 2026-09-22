#!/usr/bin/env bash
set -u
umask 077

JID="${1:-}"
case "$JID" in
    [0-9]*@*) ;;
    *)
        echo "usage: wa-messages.sh JID" >&2
        exit 2
        ;;
esac
JID_RE='^([0-9]+@(s\.whatsapp\.net|lid)|[0-9]+(-[0-9]+)?@g\.us)$'
if ! [[ $JID =~ $JID_RE ]]; then
    echo "usage: wa-messages.sh JID" >&2
    exit 2
fi

CACHE="$HOME/.cache/quickshell"
SAFE="$(printf '%s' "$JID" | tr -c 'A-Za-z0-9' '_')"
OUT="$CACHE/wa-messages-$SAFE.json"
MDIR="$CACHE/wa-media/$SAFE"
LOCK="$CACHE/wa-media.lock"

command -v wacli >/dev/null 2>&1 || export PATH="$PATH:$HOME/go/bin"
command -v jq >/dev/null 2>&1 || exit 1
command -v python3 >/dev/null 2>&1 || exit 1

mkdir -p "$CACHE" "$MDIR" || exit 1

exec 9>"$LOCK"
if ! flock -n 9; then
    exit 0
fi

TMP="$(mktemp "$OUT.tmp.XXXXXX")" || exit 1
cleanup() {
    rm -f -- "$TMP"
}
trap cleanup EXIT

wacli --json messages list --chat "$JID" --limit 100 2>/dev/null >"$TMP" || exit 1

# id<TAB>filename rows for media needing download. wacli keeps the
# original filename on download (e.g. wa-clip-*.png for clipboard sends),
# so a message counts as cached under either name.
MEDIA_ROWS="$(jq -r '.data.messages[]? | select(.MediaType == "image" or .MediaType == "audio" or .MediaType == "sticker") | [.MsgID, (.Filename // "")] | @tsv' "$TMP" 2>/dev/null | head -n 16)"

attempt=0
while IFS="$(printf '\t')" read -r id fname; do
    case "$id" in ''|*[!A-Za-z0-9_=-]*) continue ;; esac
    [ "${#id}" -le 128 ] || continue
    if ls "$MDIR"/message-"$id".* >/dev/null 2>&1; then
        continue
    fi
    case "$fname" in ''|*/*) ;;
        *) [ -f "$MDIR/$fname" ] && continue ;;
    esac
    if [ "$attempt" -ge 6 ]; then
        break
    fi
    attempt=$((attempt + 1))
    timeout 30 wacli media download --read-only --chat "$JID" --id "$id" --output "$MDIR" >/dev/null 2>&1 || true
done <<EOF
$MEDIA_ROWS
EOF

python3 - "$TMP" "$MDIR" "$JID" <<'PY'
import glob
import json
import os
import re
import sys

raw_path, mdir = sys.argv[1], sys.argv[2]
jid = sys.argv[3] if len(sys.argv) > 3 else ""
with open(raw_path) as f:
    env = json.load(f)
msgs = env.get("data", {}).get("messages", [])
real_mdir = os.path.realpath(mdir)
for m in msgs:
    m.pop("src", None)
    if m.get("MediaType") in ("image", "audio", "sticker"):
        mid = m.get("MsgID", "")
        if not isinstance(mid, str) or not re.fullmatch(r"[A-Za-z0-9_=-]{1,128}", mid):
            continue
        hits = glob.glob(os.path.join(mdir, "message-" + mid + ".*"))
        if not hits:
            # wacli preserves the sender's filename (clipboard sends land
            # as wa-clip-*.png); match on the reported basename instead.
            fn = m.get("Filename", "")
            if isinstance(fn, str) and fn and "/" not in fn and fn not in (".", ".."):
                cand = os.path.join(mdir, fn)
                if os.path.isfile(cand):
                    hits = [cand]
        if hits:
            p = os.path.realpath(hits[0])
            if p.startswith(real_mdir + os.sep) and os.path.isfile(p):
                m["src"] = p
            else:
                m.pop("src", None)
    else:
        m.pop("src", None)
out = {
    "jid": jid,
    "messages": msgs,
    "fts": bool(env.get("data", {}).get("fts", False)),
}
fd = os.open(raw_path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
with os.fdopen(fd, "w") as f:
    json.dump(out, f, ensure_ascii=False)
PY
status=$?

if [ "$status" -ne 0 ]; then
    exit 1
fi

mv "$TMP" "$OUT"
