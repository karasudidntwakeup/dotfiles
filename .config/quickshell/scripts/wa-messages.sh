#!/usr/bin/env bash
# Fetch recent messages for a chat JID into the quickshell cache, and
# download image + audio (voice note) media (read-only, no store lock) so the
# panel can show photos and play recordings.
JID="$1"
CACHE="$HOME/.cache/quickshell"
SAFE="$(printf '%s' "$JID" | tr -c 'A-Za-z0-9' '_')"
OUT="$CACHE/wa-messages-$SAFE.json"
MDIR="$CACHE/wa-media/$SAFE"
TMP="$OUT.tmp.$$"
RAW="$TMP.raw"

command -v wacli >/dev/null 2>&1 || export PATH="$PATH:$HOME/go/bin"

mkdir -p "$CACHE" "$MDIR"

wacli --json messages list --chat "$JID" --limit 100 2>/dev/null > "$RAW" || exit 1

for id in $(jq -r '.data.messages[] | select(.MediaType == "image" or .MediaType == "audio") | .MsgID' "$RAW" 2>/dev/null | head -n 16); do
    [ -n "$(ls "$MDIR"/message-$id.* 2>/dev/null)" ] && continue
    wacli media download --read-only --chat "$JID" --id "$id" --output "$MDIR" >/dev/null 2>&1
done

python3 - "$RAW" "$MDIR" <<'PY'
import json, sys, glob, os
raw_path, mdir = sys.argv[1], sys.argv[2]
with open(raw_path) as f:
    env = json.load(f)
msgs = env.get("data", {}).get("messages", [])
for m in msgs:
    if m.get("MediaType") in ("image", "audio"):
        hits = glob.glob(os.path.join(mdir, "message-" + m.get("MsgID", "") + ".*"))
        if hits:
            m["src"] = os.path.realpath(hits[0])
out = {
    "messages": msgs,
    "fts": bool(env.get("data", {}).get("fts", False)),
}
with open(raw_path + ".final", "w") as f:
    json.dump(out, f, ensure_ascii=False)
PY

mv "$RAW.final" "$TMP" && mv "$TMP" "$OUT"
rm -f "$RAW"